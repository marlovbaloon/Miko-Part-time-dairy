-- battle_system/battle.lua
-- Scene interface: load, update, draw, exit, plus public API

return function(M)
    local structs = require("source.gameplay.battle_system.structs")
    local state   = require("source.gameplay.battle_system.state")
    local config  = require("source.gameplay.battle_system.config")
    local enemy_loader = require("source.gameplay.youkai.enemy_loader")
    local states_manager = require("source.states_manager")

    local box        = structs.state
    local player     = structs.player
    local enemy      = structs.enemy
    local player_atb = structs.player_atb
    local enemy_atb  = structs.enemy_atb
    local soul       = structs.soul
    local v          = state._visuals

    function M.start(enemy_id)
        enemy_id = enemy_id or "kudagitsune"

        box.phase = config.PHASE_IDLE
        box.turn_count = 0
        box.paused = 0
        box.dialogue_active = 0
        box.perfect_dodge = 0
        box.perfect_dodge_count = 0
        box.enemy_spare_meter = 0
        box.battle_ended = 0
        box.pacifist_end = 0

        box.side_flipped = (math.random() < config.CONFIG.FLIP_CHANCE) and 1 or 0

        player.max_hp     = 100
        player.current_hp = 100
        player.atk        = 10
        player.def        = 5
        player.spd        = 12
        player.sp         = 20
        player.max_sp     = 20

        M._reset_atb(player_atb)
        M._reset_atb(enemy_atb)
        player_atb.speed = config.CONFIG.ATB_BASE_SPEED * (1.0 + player.spd * 0.05)
        -- Enemy speed is injected by enemy_loader below

        soul.x = 0; soul.y = 0
        soul.speed = config.CONFIG.SOUL_SPEED
        soul.hitbox_r = 4
        soul.invincible = 0
        soul.iframes = 0.0

        M._clear_bullets()

        v.cmd_cursor = 1
        v.submenu_cursor = 1
        v.show_submenu = false
        v.shake_timer = 0
        v.miss_text_timer = 0
        v.enemy_damage_flash = 0

        state._dialogue_queue = {}
        state._dialogue_index = 0
        state._dialogue_timer = 0

        -- Load youkai blueprint and inject stats / acts / dialogue / sprite into battle state
        local enemy_data = enemy_loader.load(enemy_id)
        enemy_loader.inject_to_battle(enemy_data, state, structs)
        enemy_atb.speed = config.CONFIG.ATB_BASE_SPEED * (1.0 + enemy.spd * 0.05)

        local sw = love.graphics.getWidth()
        local sh = love.graphics.getHeight()
        M._calc_layout(sw, sh)
        v.player_x = v.player_target_x
        v.enemy_x  = v.enemy_target_x

        M._trigger("on_battle_start", {}, enemy_data)

        M._set_phase(config.PHASE_COMMAND)
        box.turn_count = 1
    end

    function M.load(saveData, enemy_id)
        -- Deprecated compatibility wrapper.
        -- Old callers passed battle.load(saveData, enemy_id); new code uses battle.start(enemy_id).
        if type(saveData) == "string" and enemy_id == nil then
            enemy_id = saveData
        end
        print("[battle_system] M.load is deprecated; use M.start(enemy_id) instead")
        M.start(enemy_id)
    end

    function M.update(dt)
        if box.battle_ended == 1 then return end
        if box.phase == config.PHASE_IDLE then return end

        if v.shake_timer > 0 then
            v.shake_timer = v.shake_timer - dt
            v.shake_x = (math.random() - 0.5) * 8
            v.shake_y = (math.random() - 0.5) * 8
            if v.shake_timer <= 0 then
                v.shake_x = 0; v.shake_y = 0
            end
        end

        if v.enemy_damage_flash and v.enemy_damage_flash > 0 then
            v.enemy_damage_flash = v.enemy_damage_flash - dt
            if v.enemy_damage_flash < 0 then v.enemy_damage_flash = 0 end
        end

        if v.miss_text_timer > 0 then
            v.miss_text_timer = v.miss_text_timer - dt
        end

        if box.phase == config.PHASE_COMMAND then
            if player_atb.ready == 0 then
                local spd = M._get_atb_speed(player_atb)
                player_atb.current = player_atb.current + spd * dt
                if player_atb.current >= config.CONFIG.ATB_MAX then
                    player_atb.current = config.CONFIG.ATB_MAX
                    player_atb.ready = 1
                end
            end

            if enemy_atb.ready == 0 then
                enemy_atb.current = enemy_atb.current + enemy_atb.speed * dt
                if enemy_atb.current >= config.CONFIG.ATB_MAX then
                    enemy_atb.current = config.CONFIG.ATB_MAX
                    enemy_atb.ready = 1
                    M._start_enemy_turn()
                    return
                end
            end

            M._handle_command_input()

        elseif box.phase == config.PHASE_SUBMENU then
            M._handle_submenu_input()

        elseif box.phase == config.PHASE_BULLET_HELL then
            M._update_bullet_hell(dt)

        elseif box.phase == config.PHASE_DIALOGUE then
            M._update_dialogue(dt)

        elseif box.phase == config.PHASE_RESULT then
            if controller and controller.isDown then
                if controller.isDown("confirm") or controller.isDown("attack") then
                    M._exit_battle()
                end
            end
        end
    end

    function M.draw()
        if box.phase == config.PHASE_IDLE then return end

        local sw = love.graphics.getWidth()
        local sh = love.graphics.getHeight()

        love.graphics.push()
        love.graphics.translate(v.shake_x, v.shake_y)

        love.graphics.setColor(0.08, 0.08, 0.12, 1)
        love.graphics.rectangle("fill", 0, 0, sw, sh)

        love.graphics.setColor(0.4, 0.7, 1.0, 1)
        love.graphics.rectangle("fill", v.player_x, v.player_y, 80, 120)
        M._draw_enemy_sprite()

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("PLAYER", v.player_x, v.player_y - 20)
        if state._enemy_data then
            love.graphics.print(state._enemy_data.name:upper(), v.enemy_x - 20, v.enemy_y - 20)
        else
            love.graphics.print("ENEMY", v.enemy_x, v.enemy_y - 20)
        end

        if box.phase == config.PHASE_COMMAND or box.phase == config.PHASE_SUBMENU then
            M._draw_command_ui()
            M._draw_atb_gauges()
            M._draw_hp_bar()
        elseif box.phase == config.PHASE_BULLET_HELL then
            M._draw_bullet_hell()
        elseif box.phase == config.PHASE_DIALOGUE then
            M._draw_dialogue()
        elseif box.phase == config.PHASE_RESULT then
            M._draw_result()
        end

        if v.miss_text_timer > 0 then
            love.graphics.setColor(1, 1, 0.2, v.miss_text_timer * 2)
            local mx = v.player_x + 40
            local my = v.player_y - 40
            love.graphics.print("MISS!", mx, my)
        end

        love.graphics.pop()
    end

    function M.exit()
        M._set_phase(config.PHASE_IDLE)
        M._clear_bullets()
        M._trigger("on_battle_end", box.pacifist_end == 1)
    end

    function M._exit_battle()
        M.exit()
        if StateManager and StateManager.switch then
            StateManager.switch("world", M.serialize_result())
        end
    end

    function M.serialize_result()
        return {
            player_hp = player.current_hp,
            player_sp = player.sp,
            pacifist = box.pacifist_end == 1,
            turns = box.turn_count,
            enemy_spare_meter = box.enemy_spare_meter,
        }
    end

    function M.force_bullet_hell()
        M._start_enemy_turn()
    end

    function M.force_end(pacifist)
        box.battle_ended = 1
        box.pacifist_end = pacifist and 1 or 0
        M._set_phase(config.PHASE_RESULT)
    end

    function M.get_state()
        return box
    end

    function M.get_player_stats()
        return player
    end

    function M.get_enemy_stats()
        return enemy
    end

    function M.on(event, fn)
        if not state._callbacks[event] then state._callbacks[event] = {} end
        table.insert(state._callbacks[event], fn)
    end

    function M.off(event, fn)
        local cbs = state._callbacks[event]
        if not cbs then return end
        for i = #cbs, 1, -1 do
            if cbs[i] == fn then table.remove(cbs, i) end
        end
    end
end
