-- battle_system/draw.lua
-- All rendering helpers for the battle scene
-- [StrictLua] Uses typed float declarations for ratio/fill calculations.

return function(M)
    local structs = require("source.gameplay.battle_system.structs")
    local state   = require("source.gameplay.battle_system.state")
    local config  = require("source.gameplay.battle_system.config")

    local box        = structs.state
    local player     = structs.player
    local enemy      = structs.enemy
    local player_atb = structs.player_atb
    local enemy_atb  = structs.enemy_atb
    local soul       = structs.soul
    local bullets    = structs.bullets
    local v          = state._visuals
    local enemy_data = state._enemy_data

    function M._draw_command_ui()
        float sw = love.graphics.getWidth()
        float sh = love.graphics.getHeight()
        float cx = sw * 0.5
        float cy = sh - 90

        for i, item in ipairs(state._command_menu) do
            local ox, oy = 0, 0
            if i == 1 then oy = -40
            elseif i == 2 then oy = 40
            elseif i == 3 then ox = 50
            elseif i == 4 then ox = -50
            end

            local selected = (v.cmd_cursor == i)
            if selected then
                love.graphics.setColor(1, 0.8, 0.2, 1)
                love.graphics.rectangle("line", cx + ox - 35, cy + oy - 15, 70, 30)
            else
                love.graphics.setColor(0.5, 0.5, 0.5, 0.6)
            end
            love.graphics.print(item.label, cx + ox - 20, cy + oy - 6)
        end

        if v.show_submenu then
            float sx = cx + 60
            float sy = cy - 20
            love.graphics.setColor(0.1, 0.1, 0.15, 0.95)
            love.graphics.rectangle("fill", sx, sy, 160, 80)
            love.graphics.setColor(0.6, 0.6, 0.7, 1)
            love.graphics.rectangle("line", sx, sy, 160, 80)

            for i, item in ipairs(state._act_submenu) do
                if v.submenu_cursor == i then
                    love.graphics.setColor(1, 0.9, 0.3, 1)
                    love.graphics.print("> " .. item.label, sx + 10, sy + 8 + (i - 1) * 22)
                else
                    love.graphics.setColor(0.8, 0.8, 0.8, 1)
                    love.graphics.print("  " .. item.label, sx + 10, sy + 8 + (i - 1) * 22)
                end
            end
        end
    end

    function M._draw_atb_gauges()
        local function draw_gauge(x, y, w, h, gauge, label, color)
            love.graphics.setColor(0.2, 0.2, 0.25, 1)
            love.graphics.rectangle("fill", x, y, w, h)
            float fill = (gauge.current / config.CONFIG.ATB_MAX) * w
            love.graphics.setColor(color[1], color[2], color[3], 1)
            love.graphics.rectangle("fill", x, y, fill, h)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(label .. " " .. math.floor(gauge.current) .. "%", x, y - 14)
        end

        float sw = love.graphics.getWidth()
        draw_gauge(20, 20, 150, 12, player_atb, "PLAYER", {0.2, 0.8, 0.3})
        draw_gauge(20, 42, 150, 12, enemy_atb,  "ENEMY",  {0.9, 0.2, 0.2})
    end

    function M._draw_hp_bar()
        local x, y = v.hp_bar_x, v.hp_bar_y
        integer w = 140
        integer h = 16
        float hp_pct = player.current_hp / player.max_hp

        love.graphics.setColor(0.2, 0.2, 0.2, 1)
        love.graphics.rectangle("fill", x, y, w, h)
        love.graphics.setColor(0.9, 0.2, 0.2, 1)
        love.graphics.rectangle("fill", x, y, w * hp_pct, h)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("HP: " .. player.current_hp .. "/" .. player.max_hp, x, y - 16)

        float sp_pct = player.sp / player.max_sp
        love.graphics.setColor(0.15, 0.15, 0.2, 1)
        love.graphics.rectangle("fill", x, y + 22, w, 10)
        love.graphics.setColor(0.3, 0.5, 1.0, 1)
        love.graphics.rectangle("fill", x, y + 22, w * sp_pct, 10)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("SP: " .. player.sp, x, y + 22)
    end

    function M._draw_bullet_hell()
        love.graphics.setColor(0.05, 0.05, 0.08, 0.9)
        love.graphics.rectangle("fill", box.box_x, box.box_y, box.box_w, box.box_h)
        love.graphics.setColor(0.8, 0.8, 0.9, 1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", box.box_x, box.box_y, box.box_w, box.box_h)
        love.graphics.setLineWidth(1)

        if soul.iframes > 0 and math.floor(love.timer.getTime() * 10) % 2 == 0 then
            love.graphics.setColor(1, 1, 1, 0.4)
        else
            love.graphics.setColor(1, 0.2, 0.5, 1)
        end
        love.graphics.circle("fill", soul.x, soul.y, soul.hitbox_r)

        integer pool_size = config.CONFIG.BULLET_POOL_SIZE
        for i = 0, pool_size - 1 do
            local b = bullets[i]
            if b.active == 1 then
                if b.type == config.BULLET_NORMAL then
                    love.graphics.setColor(1, 0.4, 0.4, 1)
                elseif b.type == config.BULLET_HOMING then
                    love.graphics.setColor(0.9, 0.2, 0.9, 1)
                else
                    love.graphics.setColor(0.4, 0.8, 1.0, 1)
                end
                love.graphics.rectangle("fill", b.x - b.w * 0.5, b.y - b.h * 0.5, b.w, b.h)
            end
        end

        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.print(string.format("%.1f", box.bullet_hell_timer), box.box_x + 5, box.box_y - 18)
    end

    function M._draw_dialogue()
        float sw = love.graphics.getWidth()
        float sh = love.graphics.getHeight()
        integer box_h = 100

        love.graphics.setColor(0.05, 0.05, 0.08, 0.92)
        love.graphics.rectangle("fill", 20, sh - box_h - 20, sw - 40, box_h)
        love.graphics.setColor(0.6, 0.6, 0.7, 1)
        love.graphics.rectangle("line", 20, sh - box_h - 20, sw - 40, box_h)

        if state._dialogue_index > 0 and state._dialogue_index <= #state._dialogue_queue then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(state._dialogue_queue[state._dialogue_index], 35, sh - box_h + 5)
        end

        if math.floor(love.timer.getTime() * 3) % 2 == 0 then
            love.graphics.setColor(1, 1, 1, 0.6)
            love.graphics.print("▼", sw - 50, sh - 40)
        end
    end

    function M._draw_enemy_sprite()
        if v.enemy_sprite then
            float x = v.enemy_x
            float y = v.enemy_y

            -- Apply shake offset from the shared shake timer
            if v.shake_timer > 0 then
                x = x + (math.random() - 0.5) * 4
                y = y + (math.random() - 0.5) * 4
            end

            -- Damage flash: brighten the sprite briefly when the enemy is hurt
            local r, g, b = 1, 1, 1
            if v.enemy_damage_flash and v.enemy_damage_flash > 0 then
                float flash = v.enemy_damage_flash * 2
                r = 1 + flash
                g = 1 + flash
                b = 1 + flash
            end
            love.graphics.setColor(r, g, b, 1)

            float ox = v.enemy_sprite:getWidth()  * 0.5
            float oy = v.enemy_sprite:getHeight() * 0.5
            love.graphics.draw(v.enemy_sprite, x, y, 0, 1, 1, ox, oy)
        else
            -- Fallback: colored rectangle if no sprite is available
            love.graphics.setColor(1.0, 0.3, 0.3, 1)
            love.graphics.rectangle("fill", v.enemy_x, v.enemy_y, 80, 120)
        end
    end

    function M._draw_result()
        float sw = love.graphics.getWidth()
        float sh = love.graphics.getHeight()

        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, 0, sw, sh)

        love.graphics.setColor(1, 1, 1, 1)
        local msg
        if box.pacifist_end == 1 then
            msg = "* You won peacefully!"
        elseif player.current_hp <= 0 then
            msg = "* You were defeated..."
        else
            msg = "* Battle ended."
        end
        love.graphics.print(msg, sw * 0.5 - 60, sh * 0.5 - 10)
        love.graphics.print("Press CONFIRM to continue", sw * 0.5 - 80, sh * 0.5 + 20)
    end
end
