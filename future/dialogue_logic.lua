-- =============================================================================
-- source/systems/dialogue/dialogue_logic.lua
-- =============================================================================
-- Dialogue State Machine & Logic
-- รับผิดชอบ: จัดการ flow บทสนทนา, evaluate เงื่อนไข, queue pages, choices
-- ไม่รู้จัก rendering ไม่รู้จัก input handling โดยตรง
-- =============================================================================

local parser = require("source.utils.dialogue_parser")
local M = {}

-- =============================================================================
-- Internal State
-- =============================================================================
local _current_data = nil      -- ตารางบทสนทนาปัจจุบัน (loaded from file)
local _current_node = nil      -- node ปัจจุบันที่กำลังแสดง
local _node_map = {}           -- map id -> node (สร้างตอน load)
local _page_queue = {}         -- คิวหน้าข้อความ (สำหรับ multi-page)
local _page_index = 0          -- หน้าปัจจุบันใน queue
local _context = {}            -- context สำหรับ evaluate เงื่อนไข
local _history = {}            -- ประวัติ node ที่เคยผ่าน (สำหรับตรวจสอบเงื่อนไขซ้ำ)

-- State flags
local _is_active = false
local _is_waiting_choice = false
local _current_choices = nil
local _choice_index = 1

-- Callbacks
local _callbacks = {
    on_node_enter = {},
    on_page_advance = {},
    on_choice_present = {},
    on_choice_select = {},
    on_action = {},
    on_dialogue_end = {},
}

-- =============================================================================
-- Private Helpers
-- =============================================================================

local function _trigger(event, ...)
    local cbs = _callbacks[event]
    if not cbs then return end
    for i = 1, #cbs do
        if cbs[i] then
            local ok, err = pcall(cbs[i], ...)
            if not ok then
                print("[dialogue_logic] Callback error (" .. event .. "): " .. tostring(err))
            end
        end
    end
end

local function _build_node_map(data)
    _node_map = {}
    for i = 1, #data do
        local node = data[i]
        if node.id then
            _node_map[node.id] = node
        end
    end
end

local function _resolve_condition(node)
    if not node.condition then
        return true, node
    end

    local passed = parser.evaluate(node.condition, _context)
    if passed then
        return true, node
    end

    -- ถ้ามี condition_fail ให้ไป node นั้น
    if node.condition_fail then
        local fallback = _node_map[node.condition_fail]
        if fallback then
            return true, fallback
        end
    end

    return false, nil
end

local function _build_page_queue(node)
    _page_queue = {}
    _page_index = 0

    if node.pages and #node.pages > 0 then
        -- Multi-page node
        for i = 1, #node.pages do
            _page_queue[i] = node.pages[i]
        end
    elseif node.text then
        -- Single text node
        _page_queue[1] = node.text
    else
        -- Empty node
        _page_queue[1] = "..."
    end
end

local function _execute_action(node, choice)
    local action = choice and choice.action or node.action
    local params = choice and choice.params or node.params

    if action then
        _trigger("on_action", action, params or {}, node, choice)
    end

    -- ตรวจสอบ action พิเศษ
    if action == "end_dialogue" then
        M.end_dialogue()
        return false  -- ไม่ต้องไปต่อ
    end

    return true
end

-- =============================================================================
-- Public API
-- =============================================================================

--- เริ่มบทสนทนาใหม่
-- @param data table ตารางบทสนทนาที่โหลดจากไฟล์
-- @param ctx table context สำหรับ evaluate เงื่อนไข {time=..., inventory=..., quests=...}
-- @param start_id string [optional] node id เริ่มต้น (default: ใช้ node แรก)
function M.start(data, ctx, start_id)
    if not data or #data == 0 then
        print("[dialogue_logic] No dialogue data provided.")
        return false
    end

    _current_data = data
    _context = ctx or {}
    _history = {}
    _is_active = true
    _is_waiting_choice = false
    _current_choices = nil
    _choice_index = 1

    _build_node_map(data)

    -- หา node เริ่มต้น
    local entry_node
    if start_id then
        entry_node = _node_map[start_id]
    end
    if not entry_node then
        entry_node = data[1]
    end

    return M._enter_node(entry_node)
end

--- เข้าสู่ node ใหม่ (internal แต่ expose สำหรับระบบภายนอกที่ต้องการ jump)
function M._enter_node(node)
    if not node then
        M.end_dialogue()
        return false
    end

    -- Evaluate condition
    local ok, resolved = _resolve_condition(node)
    if not ok or not resolved then
        -- ถ้า condition ไม่ผ่านและไม่มี fallback -> จบ
        M.end_dialogue()
        return false
    end

    node = resolved
    _current_node = node
    table.insert(_history, node.id or "unknown")

    _trigger("on_node_enter", node)

    -- ถ้ามี action ให้ execute ก่อน
    if not _execute_action(node, nil) then
        return false
    end

    -- ถ้ามี choices -> รอผู้เล่นเลือก
    if node.choices and #node.choices > 0 then
        _is_waiting_choice = true
        _current_choices = node.choices
        _choice_index = 1
        _trigger("on_choice_present", node.choices, node)
        return true
    end

    -- ไม่มี choices -> สร้าง page queue แล้วเริ่มแสดง
    _is_waiting_choice = false
    _current_choices = nil
    _build_page_queue(node)
    _page_index = 1

    _trigger("on_page_advance", _page_queue[_page_index], _page_index, #_page_queue)
    return true
end

--- ไปหน้าถัดไป (กด confirm ตอนอ่านข้อความ)
-- @return boolean ยังมีหน้าถัดไปหรือไม่
function M.advance_page()
    if not _is_active then return false end
    if _is_waiting_choice then return false end

    if _page_index < #_page_queue then
        _page_index = _page_index + 1
        _trigger("on_page_advance", _page_queue[_page_index], _page_index, #_page_queue)
        return true
    else
        -- หมดหน้าแล้ว -> ไป next node
        if _current_node and _current_node.next then
            local next_node = _node_map[_current_node.next]
            return M._enter_node(next_node)
        else
            -- ไม่มี next -> จบ
            M.end_dialogue()
            return false
        end
    end
end

--- ข้ามไปหน้าสุดท้าย (speed up / skip)
function M.skip_to_end()
    if not _is_active or _is_waiting_choice then return end
    _page_index = #_page_queue
    _trigger("on_page_advance", _page_queue[_page_index], _page_index, #_page_queue)
end

--- เลือกตัวเลือก (choices)
-- @param index int ลำดับตัวเลือก (1-based)
function M.select_choice(index)
    if not _is_active or not _is_waiting_choice then return false end
    if not _current_choices or index < 1 or index > #_current_choices then
        return false
    end

    local choice = _current_choices[index]
    _choice_index = index
    _trigger("on_choice_select", choice, index)

    -- Execute choice action
    if not _execute_action(nil, choice) then
        return false
    end

    -- ไป next node ของ choice
    if choice.next then
        _is_waiting_choice = false
        local next_node = _node_map[choice.next]
        return M._enter_node(next_node)
    else
        -- ไม่มี next -> จบ
        M.end_dialogue()
        return false
    end
end

--- นำทาง choices (ขึ้น/ลง)
function M.navigate_choice(direction)
    if not _is_waiting_choice or not _current_choices then return end
    if direction == "up" then
        _choice_index = _choice_index - 1
        if _choice_index < 1 then _choice_index = #_current_choices end
    elseif direction == "down" then
        _choice_index = _choice_index + 1
        if _choice_index > #_current_choices then _choice_index = 1 end
    end
end

--- จบบทสนทนา
function M.end_dialogue()
    _is_active = false
    _is_waiting_choice = false
    _current_node = nil
    _current_choices = nil
    _page_queue = {}
    _trigger("on_dialogue_end")
end

--- ข้ามไป node ใด node หนึ่งโดยตรง (สำหรับ event หรือ debug)
function M.jump_to(node_id)
    if not _current_data then return false end
    local node = _node_map[node_id]
    if node then
        return M._enter_node(node)
    end
    return false
end

-- =============================================================================
-- Getters (Read-only state access)
-- =============================================================================

function M.is_active()           return _is_active end
function M.is_waiting_choice()   return _is_waiting_choice end
function M.get_current_text()    return _page_queue[_page_index] or "" end
function M.get_current_node()    return _current_node end
function M.get_choices()         return _current_choices end
function M.get_choice_index()    return _choice_index end
function M.get_page_progress()   return _page_index, #_page_queue end
function M.get_history()         return _history end
function M.get_context()         return _context end

-- =============================================================================
-- Event Registration
-- =============================================================================

function M.on(event, fn)
    if not _callbacks[event] then _callbacks[event] = {} end
    table.insert(_callbacks[event], fn)
    return #_callbacks[event]
end

function M.off(event, id)
    local cbs = _callbacks[event]
    if cbs and cbs[id] then cbs[id] = nil end
end

return M
