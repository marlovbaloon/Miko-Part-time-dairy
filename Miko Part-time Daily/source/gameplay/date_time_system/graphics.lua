-- date_time_system/graphics.lua
-- Light/ambient helpers and example UI draw

local structs = require("source.gameplay.date_time_system.structs")
local format = require("source.gameplay.date_time_system.format")

local gt = structs.gt

local graphics = {}

function graphics.get_ambient_light()
    local h = gt.hour + gt.minute / 60.0 + gt.second / 3600.0

    if h < 7 then
        return 0.1
    elseif h < 9 then
        return 0.1 + 0.9 * ((h - 7) / 2.0)
    elseif h < 17 then
        return 1.0
    elseif h < 20 then
        return 1.0 - 0.9 * ((h - 17) / 3.0)
    else
        return 0.1
    end
end

function graphics.get_ambient_color()
    local h = gt.hour + gt.minute / 60.0
    local r, g, b

    if h < 6 then
        r, g, b = 0.1, 0.1, 0.3
    elseif h < 7 then
        local t = h - 6
        r = 0.1 + 0.8 * t
        g = 0.1 + 0.4 * t
        b = 0.3 + 0.1 * t
    elseif h < 9 then
        local t = (h - 7) / 2.0
        r = 0.9 + 0.1 * t
        g = 0.5 + 0.5 * t
        b = 0.4 + 0.6 * t
    elseif h < 16 then
        r, g, b = 1.0, 1.0, 1.0
    elseif h < 18 then
        local t = (h - 16) / 2.0
        r = 1.0
        g = 1.0 - 0.2 * t
        b = 1.0 - 0.5 * t
    elseif h < 20 then
        local t = (h - 18) / 2.0
        r = 1.0 - 0.7 * t
        g = 0.8 - 0.6 * t
        b = 0.5 + 0.1 * t
    else
        local t = (h - 20) / 2.0
        r = 0.3 - 0.2 * t
        g = 0.2 - 0.1 * t
        b = 0.6 - 0.3 * t
    end

    r = math.max(0, math.min(1, r))
    g = math.max(0, math.min(1, g))
    b = math.max(0, math.min(1, b))

    return r, g, b
end

function graphics.get_darkness_overlay()
    return 1.0 - graphics.get_ambient_light()
end

function graphics.draw_ui(x, y, font)
    if font then
        love.graphics.setFont(font)
    end

    local r, g, b = graphics.get_ambient_color()
    love.graphics.setColor(r, g, b, 1)

    love.graphics.print(format.format_time(), x, y)
    love.graphics.print(format.format_day(), x, y + 20)

    local bar_w = 100
    local bar_h = 8
    love.graphics.setColor(0.3, 0.3, 0.3, 0.8)
    love.graphics.rectangle("fill", x, y + 45, bar_w, bar_h)
    love.graphics.setColor(r * 0.8, g * 0.8, b * 0.8, 1)
    love.graphics.rectangle("fill", x, y + 45, bar_w * gt.day_progress, bar_h)

    love.graphics.setColor(1, 1, 1, 1)
end

return graphics
