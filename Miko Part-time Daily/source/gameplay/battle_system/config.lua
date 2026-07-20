-- battle_system/config.lua
-- Phase / command / bullet constants and tuning values

local config = {}

config.PHASE_IDLE        = 0
config.PHASE_COMMAND     = 1
config.PHASE_SUBMENU     = 2
config.PHASE_BULLET_HELL = 3
config.PHASE_DIALOGUE    = 4
config.PHASE_RESULT      = 5

config.CMD_ATTACK = 1
config.CMD_ITEM   = 2
config.CMD_ACT    = 3
config.CMD_SP     = 4

config.ACT_CHECK = 1
config.ACT_SPARE = 2
config.ACT_TALK  = 3

config.BULLET_NORMAL = 1
config.BULLET_HOMING = 2
config.BULLET_WAVE   = 3

config.CONFIG = {
    ATB_MAX              = 100.0,
    ATB_BASE_SPEED       = 15.0,
    ATB_BONUS_MULT       = 2.5,
    ATB_BONUS_DURATION   = 3.0,
    BULLET_POOL_SIZE     = 256,
    BULLET_HELL_DURATION = 8.0,
    BOX_MARGIN           = 60,
    SOUL_SPEED           = 220.0,
    SOUL_IFRAMES         = 1.0,
    SPARE_METER_MAX      = 100,
    FLIP_CHANCE          = 0.15,
}

return config
