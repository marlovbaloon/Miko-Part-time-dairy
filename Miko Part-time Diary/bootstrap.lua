-- bootstrap.lua
-- StrictLua LÖVE2D runtime bootstrap.
-- Require this at the very top of main.lua BEFORE any other require().
--
-- What it does:
--   1. Loads the transpiler (source/strict_lua_transpiler.lua).
--   2. Wraps the global require() so that any module under source/ or data/
--      is read via love.filesystem, transpiled in-memory, and compiled with
--      load() before execution.
--   3. Results are cached in package.loaded — each module is only transpiled once.
--
-- Usage:
--   require("bootstrap")   ← line 1 of main.lua
--   local state = require("source.states_manager")  ← works transparently

-- ──────────────────────────────────────────────────────────────────────────────
-- Guard: only install once.
-- ──────────────────────────────────────────────────────────────────────────────
if _G.__strictlua_installed then return end
_G.__strictlua_installed = true

-- ──────────────────────────────────────────────────────────────────────────────
-- Load the transpiler before we override require.
-- Use the raw LÖVE filesystem read + load directly so we don't recurse.
-- ──────────────────────────────────────────────────────────────────────────────
local transpiler_src = love.filesystem.read("source/core/strict_lua_transpiler.lua")
if not transpiler_src then
    error("[StrictLua] Cannot read source/core/strict_lua_transpiler.lua")
end
local transpiler_chunk, err = load(transpiler_src, "@source/core/strict_lua_transpiler.lua")
if not transpiler_chunk then
    error("[StrictLua] Failed to compile transpiler: " .. tostring(err))
end
local transpiler = transpiler_chunk()

-- ──────────────────────────────────────────────────────────────────────────────
-- Module-name → filesystem path resolver
-- ──────────────────────────────────────────────────────────────────────────────
local function module_to_paths(mod_name)
    local base = mod_name:gsub("%.", "/")
    return { base .. ".lua", base .. "/init.lua" }
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Core transpiling loader
-- Returns (true, module_value) on success or (false, error_string) on failure.
-- ──────────────────────────────────────────────────────────────────────────────
local function strictlua_load(mod_name)
    for _, filepath in ipairs(module_to_paths(mod_name)) do
        local ok_read, raw = pcall(love.filesystem.read, filepath)
        if ok_read and type(raw) == "string" then
            local transpiled   = transpiler.transpile_string(raw)
            local chunk, c_err = load(transpiled, "@" .. filepath)
            if not chunk then
                return false, string.format(
                    "[StrictLua] Compile error in '%s':\n%s\n\n--- Transpiled (first 600 chars) ---\n%s",
                    filepath, tostring(c_err), transpiled:sub(1, 600)
                )
            end
            local ok_run, result = pcall(chunk, mod_name)
            if not ok_run then
                return false, string.format(
                    "[StrictLua] Runtime error in '%s':\n%s", filepath, tostring(result)
                )
            end
            -- Lua modules return the module value; nil means "true" by convention.
            if result == nil then result = true end
            return true, result
        end
    end
    return false, nil   -- nil = not found (let original require handle it)
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Wrap the global require()
-- For source.* and data.* modules: transpile then execute.
-- For everything else: fall through to the original require unchanged.
-- ──────────────────────────────────────────────────────────────────────────────
local _orig_require = require
_G.require = function(mod_name)
    local cached = package.loaded[mod_name]
    if cached ~= nil then return cached end

    
    if (mod_name:match("^source%.") or mod_name:match("^data%."))
        and mod_name ~= "source.core.strict_lua_transpiler"
    then
        local ok, result = strictlua_load(mod_name)
        if ok then
            package.loaded[mod_name] = result
            return result
        elseif result then
            error(result, 2)
        end
    end

    return _orig_require(mod_name)
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Expose global StrictLua table for introspection.
-- ──────────────────────────────────────────────────────────────────────────────
_G.StrictLua = {
    version    = "1.0.0",
    active     = true,
    transpiler = transpiler,
}

print("[StrictLua] Bootstrap installed — typed declarations are active.")
