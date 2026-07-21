-- source/strict_lua_transpiler.lua
-- StrictLua transpiler: converts typed declarations into standard Lua with runtime assertions.
--
-- Supported syntax:
--   integer  var = expr     → local var = expr  +  assert(type == "number")
--   float    var = expr     → local var = expr  +  assert(type == "number")
--   string   var = expr     → local var = expr  +  assert(type == "string")
--   boolean  var = expr     → local var = expr  +  assert(type == "boolean")
--   const integer  var = expr  → same + const-reassignment guard
--   const float    var = expr
--   const string   var = expr
--   const boolean  var = expr
--
-- Source-map: every injected assert carries a comment  -- [StrictLua L<N>]
-- so runtime errors point back to the original line number.

local transpiler = {}

-- ──────────────────────────────────────────────────────────────────────────────
-- Type mapping
-- ──────────────────────────────────────────────────────────────────────────────
local STRICT_TO_LUA_TYPE = {
    integer = "number",
    float   = "number",
    string  = "string",
    boolean = "boolean",
}

-- Keyword set used to skip lines that already start with Lua keywords.
local LUA_KEYWORDS = {
    ["local"]    = true, ["function"] = true, ["return"] = true,
    ["if"]       = true, ["then"]     = true, ["else"]   = true,
    ["elseif"]   = true, ["end"]      = true, ["for"]    = true,
    ["while"]    = true, ["do"]       = true, ["repeat"] = true,
    ["until"]    = true, ["not"]      = true, ["and"]    = true,
    ["or"]       = true, ["in"]       = true, ["break"]  = true,
    ["require"]  = true, ["print"]    = true, ["error"]  = true,
}

-- ──────────────────────────────────────────────────────────────────────────────
-- Helpers
-- ──────────────────────────────────────────────────────────────────────────────

--- Escape a variable name so it is safe to embed in an error string.
local function esc(s) return s:gsub("[^%w_]", "") end

--- Build the assert statement for a typed declaration.
-- @param var_name  string  Lua variable name
-- @param lua_type  string  expected Lua type (e.g. "number")
-- @param strict_kw string  original StrictLua keyword (e.g. "integer")
-- @param line_n    number  original source line number
local function make_assert(var_name, lua_type, strict_kw, line_n)
    return string.format(
        'assert(type(%s) == "%s", "[StrictLua] Type mismatch: \'%s\' expected %s, got " .. type(%s)) -- [StrictLua L%d]',
        var_name, lua_type, esc(var_name), strict_kw, var_name, line_n
    )
end

--- Build the const guard: a no-op upvalue trick that prints an error if the
--- const is reassigned elsewhere in the same chunk.  Because Lua has no true
--- compile-time const, we wrap the value in a read-only proxy table and
--- shadow the plain name so any = assignment to it triggers __newindex.
-- NOTE: the const *value* is always readable as a plain number/string via
-- the __index metamethod, but arithmetic on a table won't work.
-- For simple numeric constants in config files we therefore use a simpler
-- strategy: just emit the assert + a strongly-worded comment.
-- Callers that truly need write-protection should use the proxy variant.
local function make_const_comment(var_name, line_n)
    return string.format(
        '-- [StrictLua CONST L%d] Do NOT reassign "%s" after this line.',
        line_n, esc(var_name)
    )
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Line-level transpilation
-- ──────────────────────────────────────────────────────────────────────────────

--- Try to match a StrictLua typed declaration on a single line.
--- Returns (transformed_line, is_const) or nil if the line is not a declaration.
--
-- Matched patterns:
--   [const ]  <type>  <identifier>  =  <rest>
local function match_declaration(line, line_n)
    -- Strip leading whitespace for analysis (preserve it for indentation).
    local indent, rest = line:match("^(%s*)(.*)")
    if not rest then return nil end

    -- Check for const prefix
    local is_const = false
    local maybe_const = rest:match("^const%s+(.*)")
    if maybe_const then
        is_const = true
        rest = maybe_const
    end

    -- Match: <strict_type>  <identifier>  =  <expr>
    -- NOTE: Lua patterns do NOT support | alternation, so we match the keyword
    -- token first and validate it against the known type set.
    local strict_kw = rest:match("^(%a+)")
    if not strict_kw or not STRICT_TO_LUA_TYPE[strict_kw] then return nil end
    local after_kw = rest:sub(#strict_kw + 1)
    local var_name, expr = after_kw:match("^%s+([%a_][%w_]*)%s*=%s*(.+)$")
    if not var_name then return nil end

    -- Guard: if the identifier itself is a Lua keyword, skip.
    if LUA_KEYWORDS[var_name] then return nil end

    local lua_type = STRICT_TO_LUA_TYPE[strict_kw]
    if not lua_type then return nil end

    -- Strip trailing comment from expr to avoid double-commenting.
    local clean_expr = expr:match("^(.-)%s*%-%-.*$") or expr
    clean_expr = clean_expr:match("^(.-)%s*$") -- rtrim

    -- Build output lines
    local decl   = indent .. "local " .. var_name .. " = " .. clean_expr
    local assert_line = indent .. make_assert(var_name, lua_type, strict_kw, line_n)

    local lines = { decl, assert_line }

    if is_const then
        table.insert(lines, indent .. make_const_comment(var_name, line_n))
    end

    return table.concat(lines, "\n"), is_const
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Const reassignment checker (build-time only)
-- ──────────────────────────────────────────────────────────────────────────────

--- After transpiling, scan the OUTPUT for any bare assignment to a const name.
--- Returns a list of warning strings.
local function check_const_reassignment(source_lines, const_names)
    local warnings = {}
    for i, line in ipairs(source_lines) do
        -- Skip the declaration line and assert lines
        if not line:match("%[StrictLua") then
            for _, name in ipairs(const_names) do
                -- Look for: <name> = (but NOT == or ~=)
                local pattern = "%f[%w_]" .. name .. "%f[^%w_]%s*=[^=]"
                if line:match(pattern) then
                    table.insert(warnings, string.format(
                        "  WARNING: Possible reassignment of const '%s' at output line %d", name, i
                    ))
                end
            end
        end
    end
    return warnings
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Public API
-- ──────────────────────────────────────────────────────────────────────────────

--- Transpile a string of StrictLua source into standard Lua source.
-- @param  source   string  full source text
-- @param  filename string  (optional) used in header comment
-- @return string   transpiled Lua source
-- @return table    list of warning strings (const reassignment hints)
function transpiler.transpile(source, filename)
    local in_lines  = {}
    for line in (source .. "\n"):gmatch("([^\n]*)\n") do
        table.insert(in_lines, line)
    end

    local out_lines  = {}
    local const_names = {}
    local changed    = false

    -- Header comment so the build/ file is clearly machine-generated.
    if filename then
        table.insert(out_lines, "-- [StrictLua] Auto-generated from: " .. filename)
        table.insert(out_lines, "-- Do NOT edit this file directly — edit the .slua source instead.")
        table.insert(out_lines, "")
    end

    for n, line in ipairs(in_lines) do
        local transformed, is_const = match_declaration(line, n)
        if transformed then
            changed = true
            -- Preserve any original line comment from the source as a reference
            local src_comment = line:match("%s*%-%-(.+)$")
            if src_comment then
                table.insert(out_lines, "-- [src L" .. n .. "] " .. src_comment:match("^%s*(.-)%s*$"))
            else
                table.insert(out_lines, "-- [src L" .. n .. "] " .. line:match("^%s*(.-)%s*$"))
            end
            for piece_line in (transformed .. "\n"):gmatch("([^\n]*)\n") do
                table.insert(out_lines, piece_line)
            end
            if is_const then
                local var_name = line:match("[%a_][%w_]*%s+([%a_][%w_]*)%s*=")
                if var_name then table.insert(const_names, var_name) end
            end
        else
            table.insert(out_lines, line)
        end
    end

    local out_source = table.concat(out_lines, "\n")

    -- Const reassignment check on the output
    local warnings = check_const_reassignment(out_lines, const_names)

    return out_source, warnings, changed
end

--- Transpile in-memory (no file I/O). Used by the LÖVE2D bootstrap hook.
-- @param  source   string  StrictLua source
-- @return string   plain Lua source ready for load()
function transpiler.transpile_string(source)
    local out, _, _ = transpiler.transpile(source, nil)
    return out
end

return transpiler
