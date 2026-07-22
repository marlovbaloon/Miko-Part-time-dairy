-- =============================================================================
-- source/systems/dialogue/dialogue_system.lua
-- =============================================================================
-- Dialogue System Facade
-- รวม dialogue_data + dialogue_logic + จัดการ context
-- Entry point เดียวสำหรับทุกระบบบทสนทนา
-- =============================================================================

local data_mgr  = require("source.systems.dialogue.dialogue_data")
local logic     = require("source.systems.dialogue.dialogue_logic")
local time_sys  = require("source.systems.time.time_system")  -- สำหรับ context.time

local M = {}

-- Default context builders
local _context_builders = {
    time = function()
        return {
            hour = time_sys.get_hour(),
            minute = time_sys.get_minute(),
            day = time_sys.get_day(),
            day_progress = time_sys.get_day_progress(),
        }
    end,
    inventory = function()
        -- Placeholder: ดึงจากระบบ inventory จริง
        return {
            has_item = function(name) return false end,
            count = function(name) return 0 end,
        }
    end,
    quests = function()
        -- Placeholder: ดึงจากระบบ quest จริง
        return {
            is_active = function(id) return false end,
            is_complete = function(id) return false end,
            get_progress = function(id) return 0 end,
        }
    end,
    player = function()
        -- Placeholder: ดึงจากระบบ player จริง
        return { hp = 100, max_hp = 100, level = 1 }
    end,
}

-- =============================================================================
-- Context Management
-- =============================================================================

function M.set_context_builder(key, fn)
    _context_builders[key] = fn
end

function M.build_context(extra)
    local ctx = {}
    for key, builder in pairs(_context_builders) do
        ctx[key] = builder()
    end
    -- Merge extra context ถ้ามี
    if extra then
        for k, v in pairs(extra) do
            ctx[k] = v
        end
    end
    return ctx
end

-- =============================================================================
-- Main API
-- =============================================================================

--- เริ่มบทสนทนากับ NPC
-- @param npc_id string เช่น "npc_merchant"
-- @param start_node string [optional] node id เริ่มต้น
-- @param extra_ctx table [optional] context เพิ่มเติม
function M.start_dialogue(npc_id, start_node, extra_ctx)
    local path = "source/data/dialogues/" .. npc_id
    local data = data_mgr.load(path)
    if not data then
        print("[dialogue_system] Dialogue not found: " .. npc_id)
        return false
    end

    local ctx = M.build_context(extra_ctx)
    return logic.start(data, ctx, start_node)
end

--- อัปเดต (เรียกจาก love.update)
function M.update(dt)
    -- Logic ไม่ต้อง update ทุกเฟรม (event-driven)
    -- แต่ถ้ามีระบบ auto-advance หรือ timer จะใส่ตรงนี้
end

--- กดปุ่มยืนยัน (A/Confirm)
function M.on_confirm()
    if not logic.is_active() then return false end

    if logic.is_waiting_choice() then
        return logic.select_choice(logic.get_choice_index())
    else
        return logic.advance_page()
    end
end

--- กดปุ่มยกเลิก (B/Cancel) - ข้าม/เร่ง
function M.on_cancel()
    if not logic.is_active() then return false end
    logic.skip_to_end()
    return true
end

--- นำทาง choices (ขึ้น/ลง)
function M.navigate(direction)
    if not logic.is_active() then return false end
    if not logic.is_waiting_choice() then return false end
    logic.navigate_choice(direction)
    return true
end

--- จบบทสนทนาด้วยตนเอง
function M.end_dialogue()
    logic.end_dialogue()
end

--- ข้ามไป node ใด node หนึ่ง (สำหรับ event)
function M.jump_to(node_id)
    return logic.jump_to(node_id)
end

-- =============================================================================
-- Delegation (Getters)
-- =============================================================================

function M.is_active()           return logic.is_active() end
function M.is_waiting_choice()   return logic.is_waiting_choice() end
function M.get_current_text()    return logic.get_current_text() end
function M.get_choices()         return logic.get_choices() end
function M.get_choice_index()    return logic.get_choice_index() end
function M.get_page_progress()   return logic.get_page_progress() end
function M.get_history()         return logic.get_history() end

-- =============================================================================
-- Event Delegation
-- =============================================================================

function M.on(event, fn)
    return logic.on(event, fn)
end

function M.off(event, id)
    logic.off(event, id)
end

-- =============================================================================
-- Data Management
-- =============================================================================

function M.load_data(npc_id)
    local path = "source/data/dialogues/" .. npc_id
    return data_mgr.load(path)
end

function M.reload(npc_id)
    local path = "source/data/dialogues/" .. npc_id
    data_mgr.clear_cache(path)
    return data_mgr.load(path)
end

function M.clear_all_cache()
    data_mgr.clear_cache()
end

return M
