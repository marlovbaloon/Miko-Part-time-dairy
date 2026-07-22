-- battle_system/state.lua
-- Internal Lua tables, menus, callbacks, and temp variables
local anim8 = require("lib.anim8")
state._visuals.chibi_image = love.graphics.newImage("assets/images/player_chibi.png")
local g = anim8.newGrid(32, 32, state._visuals.chibi_image:getWidth(), state._visuals.chibi_image:getHeight())
state._visuals.chibi_anim = anim8.newAnimation(g('1-4', 1), 0.1)
state._visuals.chibi_ox = 16 -- จุดหมุน/จุดศูนย์กลาง Offset X
state._visuals.chibi_oy = 16 -- จุดหมุน/จุดศูนย์กลาง Offset Y
local config = require("source.gameplay.battle_system.config")

return {
    _bullets_active = {},

    _command_menu = {
        { key = "up",    cmd = config.CMD_ATTACK, label = "Attack", icon = "sword" },
        { key = "down",  cmd = config.CMD_ITEM,   label = "Item",   icon = "potion" },
        { key = "right", cmd = config.CMD_ACT,    label = "Act",    icon = "hand" },
        { key = "left",  cmd = config.CMD_SP,     label = "SP",     icon = "star" },
    },

    _act_submenu = {
        { cmd = config.ACT_CHECK, label = "Check", desc = "check" },
        { cmd = config.ACT_SPARE, label = "Spare", desc = "you spare them" },
        { cmd = config.ACT_TALK,  label = "Talk",  desc = "talk" },
    },

    _dialogue_queue = {},
    _dialogue_index = 0,
    _dialogue_timer = 0,

    _visuals = {
        player_x = 0, player_y = 0,
        enemy_x  = 0, enemy_y  = 0,
        player_target_x = 0, enemy_target_x = 0,
        shake_x = 0, shake_y = 0, shake_timer = 0,
        miss_text_timer = 0,
        cmd_cursor = 1,
        submenu_cursor = 1,
        show_submenu = false,
        hp_bar_x = 0,
        hp_bar_y = 0,
        enemy_sprite = nil,
        enemy_damage_flash = 0,
    },

    _callbacks = {
        on_battle_start = {},
        on_turn_end     = {},
        on_phase_change = {},
        on_dialogue     = {},
        on_battle_end   = {},
    },

    _tmp_dx = 0,
    _tmp_dy = 0,
    _tmp_dist = 0,
}
