-- battle_system/layout.lua
-- Positioning and screen layout

return function(M)
    local structs = require("source.gameplay.battle_system.structs")
    local state   = require("source.gameplay.battle_system.state")

    local box = structs.state
    local v   = state._visuals

    function M._calc_layout(screen_w, screen_h)
        local margin = 80
        local center_y = screen_h * 0.45

        if box.side_flipped == 0 then
            v.player_target_x = screen_w - margin - 120
            v.enemy_target_x  = margin + 60
        else
            v.player_target_x = margin + 60
            v.enemy_target_x  = screen_w - margin - 120
        end

        v.player_y = center_y
        v.enemy_y  = center_y

        box.box_w = 280
        box.box_h = 200
        box.box_x = (screen_w - box.box_w) * 0.5
        box.box_y = (screen_h - box.box_h) * 0.5 - 40

        v.hp_bar_x = screen_w - 180
        v.hp_bar_y = screen_h - 80
    end
end
