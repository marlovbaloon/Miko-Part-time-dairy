-- date_time_system/getters.lua
-- Read-only accessors for the current game time

local structs = require("source.gameplay.date_time_system.structs")
local gt = structs.gt

local getters = {}

function getters.get_day()         return gt.day          end
function getters.get_hour()        return gt.hour         end
function getters.get_minute()      return gt.minute       end
function getters.get_second()      return gt.second       end
function getters.get_day_progress() return gt.day_progress end
function getters.get_total_days()  return gt.total_days   end
function getters.get_start_hour()  return gt.start_hour   end
function getters.get_end_hour()    return gt.end_hour     end
function getters.is_game_over()    return gt.game_over == 1 end
function getters.is_paused()       return gt.is_paused == 1 end
function getters.is_running()      return gt.is_running == 1 end
function getters.hour_changed()    return gt.hour_changed == 1 end
function getters.day_changed()     return gt.day_changed == 1 end

return getters
