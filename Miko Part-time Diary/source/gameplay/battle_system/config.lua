-- battle_system/config.lua
-- Phase / command / bullet constants and tuning values
-- [StrictLua] All phase/command constants use typed `const integer` declarations.

-- ── Phase IDs ────────────────────────────────────────────────────────────────
const integer PHASE_IDLE        = 0
const integer PHASE_COMMAND     = 1
const integer PHASE_SUBMENU     = 2
const integer PHASE_BULLET_HELL = 3
const integer PHASE_DIALOGUE    = 4
const integer PHASE_RESULT      = 5

-- ── Top-level command IDs ────────────────────────────────────────────────────
const integer CMD_ATTACK = 1
const integer CMD_ITEM   = 2
const integer CMD_ACT    = 3
const integer CMD_SP     = 4

-- ── ACT sub-command IDs ──────────────────────────────────────────────────────
const integer ACT_CHECK = 1
const integer ACT_SPARE = 2
const integer ACT_TALK  = 3

-- ── Bullet type IDs ──────────────────────────────────────────────────────────
const integer BULLET_NORMAL = 1
const integer BULLET_HOMING = 2
const integer BULLET_WAVE   = 3

-- ── Assemble exported table ───────────────────────────────────────────────────
local config = {
    PHASE_IDLE        = PHASE_IDLE,
    PHASE_COMMAND     = PHASE_COMMAND,
    PHASE_SUBMENU     = PHASE_SUBMENU,
    PHASE_BULLET_HELL = PHASE_BULLET_HELL,
    PHASE_DIALOGUE    = PHASE_DIALOGUE,
    PHASE_RESULT      = PHASE_RESULT,

    CMD_ATTACK = CMD_ATTACK,
    CMD_ITEM   = CMD_ITEM,
    CMD_ACT    = CMD_ACT,
    CMD_SP     = CMD_SP,

    ACT_CHECK  = ACT_CHECK,
    ACT_SPARE  = ACT_SPARE,
    ACT_TALK   = ACT_TALK,

    BULLET_NORMAL = BULLET_NORMAL,
    BULLET_HOMING = BULLET_HOMING,
    BULLET_WAVE   = BULLET_WAVE,

    CONFIG = {
        ATB_MAX              = 100.0,
        ATB_BASE_SPEED       = 15.0,
        ATB_HASTE_MULT       = 1.3,   -- 30% temporary ATB speed boost after being hit
        ATB_HASTE_TURNS      = 1,     -- Haste lasts exactly 1 player turn
        BULLET_POOL_SIZE     = 256,
        BULLET_HELL_DURATION = 8.0,
        BOX_MARGIN           = 60,
        SOUL_SPEED           = 220.0,
        SOUL_IFRAMES         = 1.0,
        SPARE_METER_MAX      = 100,
        FLIP_CHANCE          = 0.15,
        MAX_PERFECT_DODGES   = 3,     -- cap on Perfect-Dodge full-ATB rewards per battle
    },
}

-- Backward compatibility aliases (kept so external API stays the same)
config.ATB_BONUS_MULT     = config.CONFIG.ATB_HASTE_MULT
config.ATB_BONUS_DURATION = config.CONFIG.ATB_HASTE_TURNS

return config
