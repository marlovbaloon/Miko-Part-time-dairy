-- =============================================================================
-- source/systems/dialogue/dialogue_data.lua
-- =============================================================================
-- Dialogue Data Manager
-- รับผิดชอบ: โหลดไฟล์บทสนทนา, cache, hot-reload
-- ไม่มี logic ไม่มี state เป็น pure loader
-- =============================================================================

local M = {}

-- Cache ไฟล์ที่โหลดแล้ว {path = data_table}
local _cache = {}

--- โหลดไฟล์บทสนทนา
-- @param path string เช่น "source/data/dialogues/npc_merchant"
-- @param use_cache boolean [default=true] ใช้ cache ถ้าโหลดแล้ว
-- @return table หรือ nil ถ้าไม่พบ
function M.load(path, use_cache)
    use_cache = (use_cache ~= false)

    if use_cache and _cache[path] then
        return _cache[path]
    end

    local chunk, err = love.filesystem.load(path .. ".lua")
    if not chunk then
        print("[dialogue_data] Failed to load: " .. path .. " - " .. tostring(err))
        return nil
    end

    local ok, data = pcall(chunk)
    if not ok or type(data) ~= "table" then
        print("[dialogue_data] Invalid data in: " .. path)
        return nil
    end

    -- Validate: ตรวจสอบว่าเป็น array of nodes
    if #data == 0 then
        print("[dialogue_data] Empty dialogue: " .. path)
        return nil
    end

    if use_cache then
        _cache[path] = data
    end

    return data
end

--- โหลดหลายไฟล์พร้อมกัน
-- @param paths table {name1="path1", name2="path2"}
-- @return table {name1=data1, name2=data2}
function M.load_batch(paths)
    local result = {}
    for name, path in pairs(paths) do
        result[name] = M.load(path)
    end
    return result
end

--- ล้าง cache ทั้งหมดหรือเฉพาะ path
function M.clear_cache(path)
    if path then
        _cache[path] = nil
    else
        _cache = {}
    end
end

--- ดึงรายการ path ที่ cache อยู่
function M.get_cached_paths()
    local list = {}
    for path, _ in pairs(_cache) do
        table.insert(list, path)
    end
    return list
end

return M
