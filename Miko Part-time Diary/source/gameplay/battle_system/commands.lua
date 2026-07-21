-- battle_system/commands.lua
-- Attack, Item, Act, SP execution

return function(M)
    local structs = require("source.gameplay.battle_system.structs")
    local state   = require("source.gameplay.battle_system.state")
    local config  = require("source.gameplay.battle_system.config")

    local player = structs.player
    local enemy  = structs.enemy
    local player_atb = structs.player_atb
    local box = structs.state
    local v   = state._visuals

    function M._execute_command(cmd)
        if cmd == config.CMD_ATTACK then
            M._cmd_attack()
        elseif cmd == config.CMD_ITEM then
            M._cmd_item()
        elseif cmd == config.CMD_ACT then
            v.show_submenu = true
            v.submenu_cursor = 1
            M._set_phase(config.PHASE_SUBMENU)
            return
        elseif cmd == config.CMD_SP then
            M._cmd_sp()
        end
    end

    function M._cmd_attack()
        local weapon_atk = 5
        local dmg = math.max(1, player.atk + weapon_atk - enemy.def)
        enemy.current_hp = enemy.current_hp - dmg

        v.shake_timer = 0.2
        v.enemy_damage_flash = 0.2

        if enemy.current_hp <= 0 then
            enemy.current_hp = 0
            box.battle_ended = 1
            box.pacifist_end = 0
            M._set_phase(config.PHASE_RESULT)
            return
        end

        M._reset_atb(player_atb)
        M._set_phase(config.PHASE_COMMAND)
        box.turn_count = box.turn_count + 1
        M._trigger("on_turn_end", box.turn_count)
    end

    function M._cmd_item()
        M._reset_atb(player_atb)
        M._set_phase(config.PHASE_COMMAND)
        box.turn_count = box.turn_count + 1
    end

    function M._execute_act(act_cmd)
        -- Find the act definition injected by enemy_loader
        local act = nil
        for _, a in ipairs(state._act_submenu) do
            if a.cmd == act_cmd or a.id == act_cmd then
                act = a
                break
            end
        end
        if not act then return end

        -- Spare is a special win condition gated by the spare meter
        if act.is_spare or act.id == "spare" then
            if box.enemy_spare_meter >= config.CONFIG.SPARE_METER_MAX then
                M._push_dialogue(act.dialogue or "* You spared the enemy peacefully.")
                box.battle_ended = 1
                box.pacifist_end = 1
                M._set_phase(config.PHASE_RESULT)
            else
                M._push_dialogue("* The enemy is not ready to be spared yet.")
                M._set_phase(config.PHASE_DIALOGUE)
            end
            return
        end

        -- Generic act: modify spare meter and show the enemy-specific dialogue
        box.enemy_spare_meter = box.enemy_spare_meter + (act.spare_add or 0)
        if box.enemy_spare_meter > config.CONFIG.SPARE_METER_MAX then
            box.enemy_spare_meter = config.CONFIG.SPARE_METER_MAX
        end

        if act.dialogue then
            M._push_dialogue(act.dialogue)
        end
        M._set_phase(config.PHASE_DIALOGUE)
    end

    function M._cmd_sp()
        if player.sp >= 5 then
            player.sp = player.sp - 5
            local dmg = math.max(1, player.atk * 2 - enemy.def)
            enemy.current_hp = enemy.current_hp - dmg
            v.shake_timer = 0.3
            v.enemy_damage_flash = 0.3
            M._push_dialogue("* You cast a spell!")
            M._set_phase(config.PHASE_DIALOGUE)
        else
            M._push_dialogue("* Not enough SP!")
            M._set_phase(config.PHASE_DIALOGUE)
        end
    end
end
