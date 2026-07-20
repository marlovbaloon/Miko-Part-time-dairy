-- date_time_system/format.lua
-- Time/date formatting helpers

local structs = require("source.gameplay.date_time_system.structs")
local gt = structs.gt

local format = {}

function format.format_time(h, m)
    h = h or gt.hour
    m = m or gt.minute
    return string.format("%02d:%02d", h, m)
end

function format.format_time_full()
    return string.format("%02d:%02d:%02d", gt.hour, gt.minute, math.floor(gt.second))
end

function format.format_day()
    return string.format("Day %d / %d", gt.day, gt.total_days)
end

function format.format_time_12h()
    local h = gt.hour
    local ampm = "AM"
    if h >= 12 then
        ampm = "PM"
        if h > 12 then h = h - 12 end
    elseif h == 0 then
        h = 12
    end
    return string.format("%02d:%02d %s", h, gt.minute, ampm)
end

function format.get_debug_string()
    local status = "RUNNING"
    if gt.game_over == 1 then status = "GAME OVER"
    elseif gt.is_paused == 1 then status = "PAUSED"
    elseif gt.is_running == 0 then status = "STOPPED"
    end
    return string.format(
        "[%s] Day %d/%d | %02d:%02d:%05.2f | Progress: %.1f%% | Scale: %.1fx",
        status, gt.day, gt.total_days, gt.hour, gt.minute, gt.second,
        gt.day_progress * 100, gt.time_scale
    )
end

return format
