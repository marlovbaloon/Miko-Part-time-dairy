-- battle_system/structs.lua
-- FFI C struct definitions and one-time allocations

local ffi = require("ffi")
local config = require("source.gameplay.battle_system.config")

ffi.cdef[[
    typedef struct {
        float x, y;
        float vx, vy;
        float w, h;
        int   active;
        int   type;
        float damage;
        float lifetime;
    } Bullet;

    typedef struct {
        float x, y;
        float speed;
        float hitbox_r;
        int   invincible;
        float iframes;
    } PlayerSoul;

    typedef struct {
        float current;
        float speed;
        float bonus_speed;
        float bonus_timer;
        int   ready;
    } ATBGauge;

    typedef struct {
        int   max_hp;
        int   current_hp;
        int   atk;
        int   def;
        int   spd;
        int   sp;
        int   max_sp;
    } BattleStats;

    typedef struct {
        int   phase;
        int   turn_count;
        int   side_flipped;
        int   paused;
        int   dialogue_active;
        float box_x, box_y;
        float box_w, box_h;
        int   perfect_dodge;
        int   enemy_spare_meter;
        int   battle_ended;
        int   pacifist_end;
    } BattleState;
]]

return {
    state      = ffi.new("BattleState"),
    player     = ffi.new("BattleStats"),
    enemy      = ffi.new("BattleStats"),
    player_atb = ffi.new("ATBGauge"),
    enemy_atb  = ffi.new("ATBGauge"),
    soul       = ffi.new("PlayerSoul"),
    bullets    = ffi.new("Bullet[?]", config.CONFIG.BULLET_POOL_SIZE),
}
