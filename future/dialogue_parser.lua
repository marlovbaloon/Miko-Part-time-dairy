-- =============================================================================
-- source/utils/dialogue_parser.lua
-- =============================================================================
-- Parser สำหรับแปลงเงื่อนไขบทสนทนา (condition string -> Lua function)
-- รองรับ syntax พื้นฐาน: ctx.time.hour < 18, ctx.inventory.has_item('xxx')
-- ใช้ load() อย่างปลอดภัย (sandbox) เพื่อป้องกัน code injection
-- =============================================================================

local M = {}

-- Cache  compiled functions เพื่อไม่ต้อง compile ซ้ำ
local _condition_cache = {}

--- แปลง condition string เป็น function
-- @param condition_str string เช่น "ctx.time.hour < 18"
-- @return function หรือ nil ถ้า error
function M.compile_condition(condition_str)
    if not condition_str or condition_str == "" then
        return function() return true end
    end

    -- Check cache
    if _condition_cache[condition_str] then
        return _condition_cache[condition_str]
    end

    -- Sandbox: อนุญาตแค่ ctx.* และ operators พื้นฐาน
    local src = "return function(ctx) return " .. condition_str .. " end"
    local chunk, err = load(src, "condition:" .. condition_str, "t", {})

    if not chunk then
        print("[dialogue_parser] Compile error: " .. tostring(err))
        return nil
    end

    local ok, fn = pcall(chunk)
    if not ok or type(fn) ~= "function" then
        print("[dialogue_parser] Runtime error compiling: " .. condition_str)
        return nil
    end

    _condition_cache[condition_str] = fn
    return fn
end

--- ตรวจสอบเงื่อนไขกับ context
-- @param condition_str string
-- @param ctx table context object
-- @return boolean
function M.evaluate(condition_str, ctx)
    local fn = M.compile_condition(condition_str)
    if not fn then return false end

    local ok, result = pcall(fn, ctx)
    if not ok then
        print("[dialogue_parser] Eval error: " .. tostring(result))
        return false
    end
    return not not result
end

--- ล้าง cache (ใช้เมื่อ hot-reload หรือ debug)
function M.clear_cache()
    _condition_cache = {}
end

return M
