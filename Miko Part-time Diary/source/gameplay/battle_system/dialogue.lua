-- battle_system/dialogue.lua
-- In-battle dialogue queue and advancement

return function(M)
    local structs = require("source.gameplay.battle_system.structs")
    local state   = require("source.gameplay.battle_system.state")
    local config  = require("source.gameplay.battle_system.config")

    function M._push_dialogue(text)
        table.insert(state._dialogue_queue, text)
        if structs.state.phase ~= config.PHASE_DIALOGUE then
            state._dialogue_index = #state._dialogue_queue
            state._dialogue_timer = 0
        end
    end

    function M._update_dialogue(dt)
        state._dialogue_timer = state._dialogue_timer + dt
        local ctrl = controller
        if ctrl and (ctrl.isDown("confirm") or ctrl.isDown("attack")) then
            if state._dialogue_timer > 0.3 then
                state._dialogue_index = state._dialogue_index + 1
                state._dialogue_timer = 0
                if state._dialogue_index > #state._dialogue_queue then
                    state._dialogue_queue = {}
                    state._dialogue_index = 0
                    if not structs.state.battle_ended then
                        M._set_phase(config.PHASE_COMMAND)
                    end
                end
            end
        end
    end
end
