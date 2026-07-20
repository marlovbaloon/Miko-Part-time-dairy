-- battle_system/input.lua
-- D-Pad command and submenu input handling

return function(M)
    local state  = require("source.gameplay.battle_system.state")
    local config = require("source.gameplay.battle_system.config")

    local v = state._visuals

    function M._handle_command_input()
        local ctrl = controller
        if not ctrl then return end

        if ctrl.isDown("up") then
            v.cmd_cursor = 1
        elseif ctrl.isDown("down") then
            v.cmd_cursor = 2
        elseif ctrl.isDown("right") then
            v.cmd_cursor = 3
        elseif ctrl.isDown("left") then
            v.cmd_cursor = 4
        end

        if ctrl.isDown("confirm") or ctrl.isDown("attack") then
            local sel = state._command_menu[v.cmd_cursor]
            if sel then
                M._execute_command(sel.cmd)
            end
        end
    end

    function M._handle_submenu_input()
        local ctrl = controller
        if not ctrl then return end

        if ctrl.isDown("up") then
            v.submenu_cursor = v.submenu_cursor - 1
            if v.submenu_cursor < 1 then v.submenu_cursor = #state._act_submenu end
        elseif ctrl.isDown("down") then
            v.submenu_cursor = v.submenu_cursor + 1
            if v.submenu_cursor > #state._act_submenu then v.submenu_cursor = 1 end
        end

        if ctrl.isDown("confirm") then
            local sel = state._act_submenu[v.submenu_cursor]
            M._execute_act(sel.cmd)
            v.show_submenu = false
            M._set_phase(config.PHASE_COMMAND)
        end

        if ctrl.isDown("cancel") then
            v.show_submenu = false
            M._set_phase(config.PHASE_COMMAND)
        end
    end
end
