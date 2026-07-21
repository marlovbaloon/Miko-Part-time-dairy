-- battle_system/bullet_hell.lua
-- Bullet-hell phase logic: start, update, end

return function(M)
    local structs = require("source.gameplay.battle_system.structs")
    local state   = require("source.gameplay.battle_system.state")
    local config  = require("source.gameplay.battle_system.config")

    local box        = structs.state
    local player     = structs.player
    local player_atb = structs.player_atb
    local enemy_atb  = structs.enemy_atb
    local soul       = structs.soul
    local bullets    = structs.bullets
    local v          = state._visuals

    function M._start_enemy_turn()
        M._set_phase(config.PHASE_BULLET_HELL)
        box.paused = 1
        box.perfect_dodge = 1

        soul.x = box.box_x + box.box_w * 0.5
        soul.y = box.box_y + box.box_h * 0.5
        soul.invincible = 0
        soul.iframes = 0.0

        M._clear_bullets()

        -- Ask the enemy blueprint which pattern to run, then execute it.
        local enemy_data = state._enemy_data
        if enemy_data and enemy_data.select_next_pattern then
            local pattern = enemy_data:select_next_pattern(enemy.current_hp, box.enemy_spare_meter)
            if pattern then
                pattern(M, bullets, box, soul)
            end
        else
            -- Fallback: simple downward rain if no enemy data is loaded
            for i = 1, 20 do
                local bx = box.box_x + math.random() * box.box_w
                local by = box.box_y - 20 - math.random() * 100
                M._spawn_bullet(bx, by, 0, 80 + math.random() * 60, 6, 6, config.BULLET_NORMAL, 5)
            end
        end

        box.bullet_hell_timer = config.CONFIG.BULLET_HELL_DURATION
    end

    function M._update_bullet_hell(dt)
        local ctrl = controller

        local move_x, move_y = 0, 0
        if ctrl then
            if ctrl.isDown("left")  then move_x = move_x - 1 end
            if ctrl.isDown("right") then move_x = move_x + 1 end
            if ctrl.isDown("up")    then move_y = move_y - 1 end
            if ctrl.isDown("down")  then move_y = move_y + 1 end
            local ax, ay = ctrl.getAxis and ctrl.getAxis() or 0, 0
            if math.abs(ax) > 0.2 then move_x = ax end
            if math.abs(ay) > 0.2 then move_y = ay end
        end

        local len = math.sqrt(move_x * move_x + move_y * move_y)
        if len > 1 then
            move_x = move_x / len
            move_y = move_y / len
        end

        soul.x = soul.x + move_x * soul.speed * dt
        soul.y = soul.y + move_y * soul.speed * dt

        local margin = soul.hitbox_r
        soul.x = M._clamp(soul.x, box.box_x + margin, box.box_x + box.box_w - margin)
        soul.y = M._clamp(soul.y, box.box_y + margin, box.box_y + box.box_h - margin)

        if soul.iframes > 0 then
            soul.iframes = soul.iframes - dt
            if soul.iframes <= 0 then
                soul.invincible = 0
                soul.iframes = 0
            end
        end

        local hit = false
        for i = 0, config.CONFIG.BULLET_POOL_SIZE - 1 do
            local b = bullets[i]
            if b.active == 1 then
                if b.type == config.BULLET_HOMING then
                    state._tmp_dx = soul.x - b.x
                    state._tmp_dy = soul.y - b.y
                    state._tmp_dist = math.sqrt(state._tmp_dx * state._tmp_dx + state._tmp_dy * state._tmp_dy)
                    if state._tmp_dist > 0.1 then
                        b.vx = (state._tmp_dx / state._tmp_dist) * 90
                        b.vy = (state._tmp_dy / state._tmp_dist) * 90
                    end
                elseif b.type == config.BULLET_WAVE then
                    b.vy = math.sin(love.timer.getTime() * 4 + i) * 60
                end

                b.x = b.x + b.vx * dt
                b.y = b.y + b.vy * dt
                b.lifetime = b.lifetime - dt

                if soul.invincible == 0 then
                    state._tmp_dx = soul.x - b.x
                    state._tmp_dy = soul.y - b.y
                    state._tmp_dist = math.sqrt(state._tmp_dx * state._tmp_dx + state._tmp_dy * state._tmp_dy)
                    if state._tmp_dist < (soul.hitbox_r + b.w * 0.5) then
                        hit = true
                        box.perfect_dodge = 0
                        local dmg = math.max(1, b.damage - player.def)
                        player.current_hp = player.current_hp - dmg
                        soul.invincible = 1
                        soul.iframes = config.CONFIG.SOUL_IFRAMES
                        v.shake_timer = 0.15

                        if player.current_hp <= 0 then
                            player.current_hp = 0
                            box.battle_ended = 1
                            box.pacifist_end = 0
                            M._set_phase(config.PHASE_RESULT)
                            return
                        end
                    end
                end

                if b.lifetime <= 0
                   or b.x < box.box_x - 50 or b.x > box.box_x + box.box_w + 50
                   or b.y < box.box_y - 50 or b.y > box.box_y + box.box_h + 50 then
                    b.active = 0
                end
            end
        end

        box.bullet_hell_timer = box.bullet_hell_timer - dt
        if box.bullet_hell_timer <= 0 then
            M._end_bullet_hell()
        end
    end

    function M._end_bullet_hell()
        M._clear_bullets()
        box.paused = 0

        if box.perfect_dodge == 1 then
            box.perfect_dodge_count = box.perfect_dodge_count + 1
            if box.perfect_dodge_count <= config.CONFIG.MAX_PERFECT_DODGES then
                -- Perfect Dodge reward: full ATB, capped at 3 uses per battle
                player_atb.current = config.CONFIG.ATB_MAX
                player_atb.ready = 1
                v.miss_text_timer = 1.5
                M._push_dialogue("* Perfect Dodge! ATB fully charged! (" .. box.perfect_dodge_count .. "/" .. config.CONFIG.MAX_PERFECT_DODGES .. ")")
                M._set_phase(config.PHASE_DIALOGUE)
            else
                -- Limit reached: no full-ATB reward, but still no damage taken
                M._push_dialogue("* Perfect dodge, but the Performance-Reward limit has been reached.")
                M._set_phase(config.PHASE_DIALOGUE)
            end
        else
            -- Survived: grant Haste for the next player turn
            player_atb.bonus_speed = config.CONFIG.ATB_HASTE_MULT
            player_atb.bonus_timer = config.CONFIG.ATB_HASTE_TURNS
            local haste_pct = math.floor((config.CONFIG.ATB_HASTE_MULT - 1) * 100)
            M._push_dialogue("* You took some damage. Haste buff: +" .. haste_pct .. "% ATB speed for the next turn!")
            M._set_phase(config.PHASE_DIALOGUE)
        end

        M._reset_atb(enemy_atb)
        box.turn_count = box.turn_count + 1
        M._trigger("on_turn_end", box.turn_count)
    end
end
