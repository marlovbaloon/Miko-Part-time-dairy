-- date_time_system/structs.lua
-- FFI C struct definition + GameTime instance

local ffi = require("ffi")

ffi.cdef[[
    typedef struct {
        int    day;
        int    hour;
        int    minute;
        float  second;
        float  time_scale;
        int    is_running;
        int    is_paused;
        float  day_progress;
        int    total_days;
        int    start_hour;
        int    end_hour;
        int    hour_changed;
        int    day_changed;
        int    game_over;
    } GameTime;
]]

local gt = ffi.new("GameTime")

return {
    gt = gt,
    ffi = ffi,
}
