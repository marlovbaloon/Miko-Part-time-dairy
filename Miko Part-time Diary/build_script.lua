-- build_script.lua
-- StrictLua build script — run with:  lua build_script.lua
-- Scans source/ (and data/) for .lua files, transpiles them to build/.
-- Usage from shell:  lua build_script.lua [--verbose] [--check]

local transpiler = require("source.strict_lua_transpiler")

-- ──────────────────────────────────────────────────────────────────────────────
-- Config
-- ──────────────────────────────────────────────────────────────────────────────
local INPUT_DIRS  = { "source", "data" }
local OUTPUT_DIR  = "build"
local VERBOSE     = false
local CHECK_ONLY  = false   -- if true: report but don't write

-- Parse CLI flags
for _, arg in ipairs(arg or {}) do
    if arg == "--verbose" then VERBOSE = true end
    if arg == "--check"   then CHECK_ONLY = true end
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Portable file helpers (pure Lua, no LÖVE)
-- ──────────────────────────────────────────────────────────────────────────────

local function read_file(path)
    local f, err = io.open(path, "r")
    if not f then return nil, err end
    local content = f:read("*a")
    f:close()
    return content
end

local function write_file(path, content)
    -- Ensure parent directory exists by making it via os.execute
    local dir = path:match("^(.*)/[^/]+$")
    if dir and dir ~= "" then
        os.execute("mkdir -p " .. dir)
    end
    local f, err = io.open(path, "w")
    if not f then return false, err end
    f:write(content)
    f:close()
    return true
end

--- Recursively list all .lua files under a directory.
local function list_lua_files(dir, results)
    results = results or {}
    -- Use `find` for simplicity (works on Linux/macOS/NixOS)
    local handle = io.popen("find " .. dir .. " -type f -name '*.lua' 2>/dev/null")
    if not handle then return results end
    for line in handle:lines() do
        table.insert(results, line)
    end
    handle:close()
    return results
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Main build loop
-- ──────────────────────────────────────────────────────────────────────────────

local total    = 0
local changed  = 0
local warnings_all = {}
local errors   = {}

print("╔══════════════════════════════════════╗")
print("║  StrictLua Build Script              ║")
print("╚══════════════════════════════════════╝")

local all_files = {}
for _, dir in ipairs(INPUT_DIRS) do
    list_lua_files(dir, all_files)
end

for _, filepath in ipairs(all_files) do
    -- Skip files that are already in build/ or are the build script itself
    if filepath:match("^build/") or filepath == "build_script.lua" then
        goto continue
    end
    -- Skip the bootstrap itself to avoid infinite recursion
    if filepath:match("bootstrap%.lua$") then
        goto continue
    end

    total = total + 1
    local source, read_err = read_file(filepath)
    if not source then
        table.insert(errors, "  ERROR reading " .. filepath .. ": " .. tostring(read_err))
        goto continue
    end

    local transpiled, file_warnings, file_changed = transpiler.transpile(source, filepath)

    -- Collect warnings
    if #file_warnings > 0 then
        table.insert(warnings_all, "  [" .. filepath .. "]")
        for _, w in ipairs(file_warnings) do
            table.insert(warnings_all, w)
        end
    end

    -- Determine output path:  source/foo/bar.lua  →  build/source/foo/bar.lua
    local out_path = OUTPUT_DIR .. "/" .. filepath

    if file_changed then
        changed = changed + 1
        if VERBOSE then
            print("  ✓ transpiled: " .. filepath .. " → " .. out_path)
        end
    else
        if VERBOSE then
            print("  · unchanged: " .. filepath)
        end
    end

    if not CHECK_ONLY then
        local ok, write_err = write_file(out_path, transpiled)
        if not ok then
            table.insert(errors, "  ERROR writing " .. out_path .. ": " .. tostring(write_err))
        end
    end

    ::continue::
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Also copy non-.lua assets referenced by build/ (none needed here; placeholders)
-- ──────────────────────────────────────────────────────────────────────────────

-- ──────────────────────────────────────────────────────────────────────────────
-- Report
-- ──────────────────────────────────────────────────────────────────────────────
print(string.format("\n  Files scanned : %d", total))
print(string.format("  Files changed : %d", changed))

if #warnings_all > 0 then
    print("\n  ⚠ Const reassignment warnings:")
    for _, w in ipairs(warnings_all) do print(w) end
end

if #errors > 0 then
    print("\n  ✗ Errors:")
    for _, e in ipairs(errors) do print(e) end
    os.exit(1)
end

if CHECK_ONLY then
    print("\n  (check-only mode — no files written)")
else
    print("\n  Build complete → " .. OUTPUT_DIR .. "/")
    print("  Tip: run  love build/" .. "  to launch transpiled build.")
end
