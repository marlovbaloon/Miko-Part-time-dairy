-- date_time_system/c_library.lua
-- C source code and optional native compilation helper

local c_library = {}

c_library.C_SOURCE = [[
/* date_time_system.c - ฝั่ง C สำหรับคอมไพล์เป็นไลบรารี */
#include <stdio.h>
#include <string.h>

#ifdef _WIN32
  #define EXPORT __declspec(dllexport)
#else
  #define EXPORT __attribute__((visibility("default")))
#endif

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

static const float REAL_SECONDS_PER_GAME_MINUTE = 0.7f;

EXPORT void game_time_init(GameTime* gt) {
    gt->day = 1;
    gt->hour = 7;
    gt->minute = 0;
    gt->second = 0.0f;
    gt->time_scale = 1.0f;
    gt->is_running = 1;
    gt->is_paused = 0;
    gt->day_progress = 0.0f;
    gt->total_days = 14;
    gt->start_hour = 7;
    gt->end_hour = 22;
    gt->hour_changed = 0;
    gt->day_changed = 0;
    gt->game_over = 0;
}

EXPORT void game_time_update(GameTime* gt, float dt) {
    gt->hour_changed = 0;
    gt->day_changed = 0;

    if (gt->is_running == 0 || gt->is_paused == 1 || gt->game_over == 1) return;

    float game_minutes_passed = (dt * gt->time_scale) / REAL_SECONDS_PER_GAME_MINUTE;
    gt->second += game_minutes_passed * 60.0f;

    while (gt->second >= 60.0f) {
        gt->second -= 60.0f;
        gt->minute++;

        if (gt->minute >= 60) {
            gt->minute = 0;
            gt->hour++;
            gt->hour_changed = 1;

            if (gt->hour >= gt->end_hour) {
                gt->hour = gt->start_hour;
                gt->minute = 0;
                gt->second = 0.0f;
                gt->day++;
                gt->day_changed = 1;

                if (gt->day > gt->total_days) {
                    gt->day = gt->total_days;
                    gt->is_running = 0;
                    gt->game_over = 1;
                    return;
                }
            }
        }
    }

    float total_day_minutes = (float)(gt->end_hour - gt->start_hour) * 60.0f;
    float current_minutes = (float)(gt->hour - gt->start_hour) * 60.0f
                          + (float)gt->minute
                          + gt->second / 60.0f;
    gt->day_progress = current_minutes / total_day_minutes;
    if (gt->day_progress < 0.0f) gt->day_progress = 0.0f;
    if (gt->day_progress > 1.0f) gt->day_progress = 1.0f;
}

EXPORT int game_time_is_over(const GameTime* gt) {
    return gt->game_over;
}

EXPORT float game_time_get_day_progress(const GameTime* gt) {
    return gt->day_progress;
}

EXPORT void game_time_format(const GameTime* gt, char* buf, size_t len) {
    snprintf(buf, len, "Day %d/%d | %02d:%02d", gt->day, gt->total_days, gt->hour, gt->minute);
}
]]

function c_library.compile_c_library(output_name)
    output_name = output_name or "date_time_system"
    local c_file = output_name .. ".c"
    local lib_file
    local cmd

    local f = io.open(c_file, "w")
    f:write(c_library.C_SOURCE)
    f:close()

    if jit.os == "Windows" then
        lib_file = output_name .. ".dll"
        cmd = string.format("gcc -shared -O3 -o %s %s", lib_file, c_file)
    elseif jit.os == "OSX" then
        lib_file = output_name .. ".dylib"
        cmd = string.format("gcc -dynamiclib -O3 -o %s %s", lib_file, c_file)
    else
        lib_file = output_name .. ".so"
        cmd = string.format("gcc -shared -fPIC -O3 -o %s %s", lib_file, c_file)
    end

    print("[date_time_system] Compiling C library...")
    print("[date_time_system] Command: " .. cmd)
    local result = os.execute(cmd)

    if result == 0 then
        print("[date_time_system] Success: " .. lib_file)
        return lib_file
    else
        print("[date_time_system] Compile failed. Make sure gcc is installed.")
        return nil
    end
end

return c_library
