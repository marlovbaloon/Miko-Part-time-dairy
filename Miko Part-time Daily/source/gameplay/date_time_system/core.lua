-- date_time_system/core.lua
-- Core time logic: init, update, pause, time scale, set time/day

local structs = require("source.gameplay.date_time_system.structs")
local state   = require("source.gameplay.date_time_system.state")
local callbacks = require("source.gameplay.date_time_system.callbacks")

local gt = structs.gt
local REAL_SECONDS_PER_GAME_MINUTE = state.REAL_SECONDS_PER_GAME_MINUTE

local core = {}

function core.init()
    gt.day          = 1
    gt.hour         = 7
    gt.minute       = 0
    gt.second       = 0.0
    gt.time_scale   = 1.0
    gt.is_running   = 1
    gt.is_paused    = 0
    gt.day_progress = 0.0
    gt.total_days   = 14
    gt.start_hour   = 7
    gt.end_hour     = 22
    gt.hour_changed = 0
    gt.day_changed  = 0
    gt.game_over    = 0
end

function core.update(dt)
    gt.hour_changed = 0
    gt.day_changed  = 0

    if gt.is_running == 0 or gt.is_paused == 1 or gt.game_over == 1 then
        return
    end

    local game_minutes_passed = (dt * gt.time_scale) / REAL_SECONDS_PER_GAME_MINUTE
    gt.second = gt.second + (game_minutes_passed * 60.0)

    while gt.second >= 60.0 do
        gt.second = gt.second - 60.0
        gt.minute = gt.minute + 1

        if gt.minute >= 60 then
            gt.minute = 0
            gt.hour   = gt.hour + 1
            gt.hour_changed = 1

            callbacks._trigger("on_hour_change", gt.hour, gt.day)

            if gt.hour >= gt.end_hour then
                gt.hour = gt.start_hour
                gt.minute = 0
                gt.second = 0.0
                gt.day = gt.day + 1
                gt.day_changed = 1

                callbacks._trigger("on_day_change", gt.day - 1, gt.day)

                if gt.day > gt.total_days then
                    gt.day = gt.total_days
                    gt.is_running = 0
                    gt.game_over = 1
                    callbacks._trigger("on_game_over")
                    return
                end
            end
        end
    end

    local total_day_minutes = (gt.end_hour - gt.start_hour) * 60
    local current_minutes   = (gt.hour - gt.start_hour) * 60 + gt.minute + (gt.second / 60.0)
    gt.day_progress = current_minutes / total_day_minutes
    if gt.day_progress < 0 then gt.day_progress = 0 end
    if gt.day_progress > 1 then gt.day_progress = 1 end
end

function core.pause()
    gt.is_paused = 1
end

function core.resume()
    gt.is_paused = 0
end

function core.toggle_pause()
    gt.is_paused = 1 - gt.is_paused
end

function core.set_time_scale(scale)
    gt.time_scale = tonumber(scale) or 1.0
end

function core.get_time_scale()
    return gt.time_scale
end

function core.set_time(h, m)
    h = tonumber(h) or 7
    m = tonumber(m) or 0
    if h < gt.start_hour then h = gt.start_hour end
    if h >= gt.end_hour then h = gt.end_hour; m = 0 end
    if m < 0 then m = 0 end
    if m > 59 then m = 59 end
    gt.hour = h
    gt.minute = m
    gt.second = 0.0
end

function core.set_day(day)
    day = tonumber(day) or 1
    if day < 1 then day = 1 end
    if day > gt.total_days then day = gt.total_days end
    gt.day = day
    gt.hour = gt.start_hour
    gt.minute = 0
    gt.second = 0.0
    gt.game_over = 0
    if day >= gt.total_days then
        gt.is_running = 0
    else
        gt.is_running = 1
    end
end

return core
