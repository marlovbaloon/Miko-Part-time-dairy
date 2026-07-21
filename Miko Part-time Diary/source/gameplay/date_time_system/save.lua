-- date_time_system/save.lua
-- Save/load serialization

local structs = require("source.gameplay.date_time_system.structs")
local gt = structs.gt

local save = {}

function save.serialize()
    return {
        day        = gt.day,
        hour       = gt.hour,
        minute     = gt.minute,
        second     = gt.second,
        time_scale = gt.time_scale,
        is_running = gt.is_running,
        is_paused  = gt.is_paused,
        game_over  = gt.game_over,
    }
end

function save.deserialize(data)
    if not data then return end
    gt.day        = tonumber(data.day) or 1
    gt.hour       = tonumber(data.hour) or 7
    gt.minute     = tonumber(data.minute) or 0
    gt.second     = tonumber(data.second) or 0.0
    gt.time_scale = tonumber(data.time_scale) or 1.0
    gt.is_running = data.is_running and 1 or 0
    gt.is_paused  = data.is_paused and 1 or 0
    gt.game_over  = data.game_over and 1 or 0

    local total_day_minutes = (gt.end_hour - gt.start_hour) * 60
    local current_minutes   = (gt.hour - gt.start_hour) * 60 + gt.minute + (gt.second / 60.0)
    gt.day_progress = current_minutes / total_day_minutes
end

return save
