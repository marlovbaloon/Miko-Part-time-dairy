-- date_time_system/callbacks.lua
-- Event subscription system

local state = require("source.gameplay.date_time_system.state")
local callbacks_table = state.callbacks

local callbacks = {}

function callbacks.on(event, fn)
    if not callbacks_table[event] then
        callbacks_table[event] = {}
    end
    local id = #callbacks_table[event] + 1
    callbacks_table[event][id] = fn
    return id
end

function callbacks.off(event, id)
    if callbacks_table[event] then
        callbacks_table[event][id] = nil
    end
end

function callbacks._trigger(event, ...)
    if callbacks_table[event] then
        for _, fn in pairs(callbacks_table[event]) do
            local ok, err = pcall(fn, ...)
            if not ok then
                print("[date_time_system] Callback error (" .. event .. "): " .. tostring(err))
            end
        end
    end
end

return callbacks
