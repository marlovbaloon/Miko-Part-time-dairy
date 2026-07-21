-- date_time_system/state.lua
-- Shared constants and callback registry

return {
    REAL_SECONDS_PER_GAME_MINUTE = 0.7,
    callbacks = {
        on_hour_change = {},
        on_day_change  = {},
        on_game_over   = {},
        on_time_start  = {},
        on_time_end    = {},
    },
}
