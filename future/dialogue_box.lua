-- =============================================================================
-- source/ui/dialogue/dialogue_box.lua
-- =============================================================================
-- Dialogue Box UI Renderer
-- แยกจาก text_box.lua เดิมแต่ใช้ร่วมกันได้
-- รับผิดชอบ: วาดกล่องข้อความ, choices, cursor, effects
-- ไม่มี logic ไม่มี state ของบทสนทนา รับค่าจาก dialogue_logic ผ่าน facade
-- =============================================================================

local text_wrap = require("source.ui.text_wrap")
local dialogue = require("source.systems.dialogue.dialogue_system")

local M = {}

-- Visual config
M.CONFIG = {
    box_w_ratio      = 0.94,   -- 94% ของความกว้างจอ
    box_h_ratio      = 0.33,   -- 1/3 ของความสูงจอ
    box_bottom_pad   = 6,      -- ระยะห่างจากขอบล่าง
    text_padding     = 12,
    line_spacing     = 4,
    choice_indent    = 20,
    cursor_blink_rate= 0.5,
    typewriter_speed = 0.03,   -- วินาทีต่อตัวอักษร
    fast_mult        = 5,      -- เร็วขึ้น 5 เท่าเมื่อกด B
}

-- Internal visual state
local _scale = 0
local _target_scale = 0
local _scale_speed = 12
local _typewriter_timer = 0
local _char_count = 0
local _total_chars = 0
local _wrapped_lines = {}
local _text_dirty = true

-- =============================================================================
-- Private Helpers
-- =============================================================================

local function _count_chars(lines)
    local count = 0
    for i = 1, #lines do
        count = count + string.len(lines[i])
    end
    return count
end

local function _wrap_text(text, font, max_w)
    if not text or text == "" then return {} end
    return text_wrap.wrap(text, font, max_w)
end

local function _get_box_rect(vw, vh)
    local w = math.floor(vw * M.CONFIG.box_w_ratio)
    local h = math.floor(vh * M.CONFIG.box_h_ratio)
    local x = math.floor((vw - w) / 2)
    local y = math.floor(vh - h - M.CONFIG.box_bottom_pad)
    return x, y, w, h
end

-- =============================================================================
-- Update
-- =============================================================================

function M.update(dt)
    -- อัปเดต scale animation
    _scale = _scale + (_target_scale - _scale) * _scale_speed * dt
    if _target_scale == 0 and _scale < 0.01 then
        _scale = 0
        return
    end

    -- ถ้าไม่มีบทสนทนากำลังแสดง ไม่ต้องทำอะไรต่อ
    if not dialogue.is_active() then
        _target_scale = 0
        return
    end

    _target_scale = 1

    -- Typewriter effect
    if _scale >= 0.95 then
        local is_fast = love.keyboard.isDown("b") or love.keyboard.isDown("lshift")
        local speed = is_fast and (M.CONFIG.typewriter_speed / M.CONFIG.fast_mult) or M.CONFIG.typewriter_speed

        _typewriter_timer = _typewriter_timer + dt
        if _typewriter_timer >= speed then
            local chars_to_add = math.floor(_typewriter_timer / speed)
            _char_count = math.min(_char_count + chars_to_add, _total_chars)
            _typewriter_timer = _typewriter_timer % speed
        end
    end
end

-- =============================================================================
-- Draw
-- =============================================================================

function M.draw(vw, vh)
    if _scale <= 0.005 and _target_scale == 0 then return end

    local bx, by, bw, bh = _get_box_rect(vw, vh)
    local font = love.graphics.getFont()
    local pad = M.CONFIG.text_padding
    local max_text_w = bw - pad * 2

    love.graphics.push("all")

    -- Scale animation
    local cx = bx + bw / 2
    local cy = by + bh / 2
    love.graphics.translate(cx, cy)
    love.graphics.scale(_scale, _scale)
    love.graphics.translate(-cx, -cy)

    -- Box background
    love.graphics.setColor(0.05, 0.05, 0.08, 0.92)
    love.graphics.rectangle("fill", bx, by, bw, bh, 4)
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", bx, by, bw, bh, 4)

    -- ถื่อยังไม่เปิดเต็ม ไม่วาดข้อความ
    if _scale < 0.95 then
        love.graphics.pop()
        return
    end

    -- ดึงข้อมูลจาก dialogue system
    local text = dialogue.get_current_text()
    local is_choice = dialogue.is_waiting_choice()
    local choices = dialogue.get_choices()
    local choice_idx = dialogue.get_choice_index()

    -- Re-wrap ถ้าข้อความเปลี่ยน
    if _text_dirty or text ~= _last_text then
        _wrapped_lines = _wrap_text(text, font, max_text_w)
        _total_chars = _count_chars(_wrapped_lines)
        _char_count = 0
        _typewriter_timer = 0
        _last_text = text
        _text_dirty = false
    end

    -- Draw text (typewriter)
    love.graphics.setColor(1, 1, 1, 1)
    local line_h = font:getHeight() + M.CONFIG.line_spacing
    local chars_left = _char_count
    local text_y = by + pad

    for i = 1, #_wrapped_lines do
        if chars_left <= 0 then break end
        local line = _wrapped_lines[i]
        local line_len = string.len(line)

        if chars_left >= line_len then
            love.graphics.print(line, bx + pad, text_y)
            chars_left = chars_left - line_len
        else
            love.graphics.print(string.sub(line, 1, chars_left), bx + pad, text_y)
            chars_left = 0
        end
        text_y = text_y + line_h
    end

    -- Draw choices (ถ้ามี)
    if is_choice and choices then
        local choice_y = text_y + 10
        for i = 1, #choices do
            local c = choices[i]
            if i == choice_idx then
                love.graphics.setColor(1, 0.9, 0.3, 1)
                love.graphics.print("> " .. c.text, bx + pad + M.CONFIG.choice_indent, choice_y)
            else
                love.graphics.setColor(0.7, 0.7, 0.7, 1)
                love.graphics.print("  " .. c.text, bx + pad + M.CONFIG.choice_indent, choice_y)
            end
            choice_y = choice_y + line_h
        end
    end

    -- ไอคอนกระพริบ (next page indicator)
    if not is_choice and _char_count >= _total_chars then
        if math.floor(love.timer.getTime() * 3) % 2 == 0 then
            love.graphics.setColor(1, 1, 1, 0.6)
            love.graphics.print("▼", bx + bw - 30, by + bh - 25)
        end
    end

    love.graphics.pop()
end

-- =============================================================================
-- Control (called from input handler)
-- =============================================================================

function M.on_confirm()
    if _char_count < _total_chars then
        -- ข้อความยังไม่พิมพ์จบ -> เร่งให้จบ
        _char_count = _total_chars
        return true
    end
    return dialogue.on_confirm()
end

function M.on_cancel()
    if _char_count < _total_chars then
        _char_count = _total_chars
        return true
    end
    return dialogue.on_cancel()
end

function M.navigate(direction)
    return dialogue.navigate(direction)
end

-- =============================================================================
-- State Sync
-- =============================================================================

function M.open()
    _target_scale = 1
    _text_dirty = true
end

function M.close()
    _target_scale = 0
    _text_dirty = true
    _char_count = 0
    _total_chars = 0
    _wrapped_lines = {}
end

function M.is_open()
    return _target_scale > 0 or _scale > 0
end

return M
