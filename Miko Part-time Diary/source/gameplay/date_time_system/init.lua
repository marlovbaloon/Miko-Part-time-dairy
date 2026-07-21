-- date_time_system/init.lua
-- Main entry point: merges all submodules and auto-initializes

local date_time_system = {}

-- Shared data
local structs = require("source.gameplay.date_time_system.structs")
local state   = require("source.gameplay.date_time_system.state")

-- Functional modules
local core      = require("source.gameplay.date_time_system.core")
local getters   = require("source.gameplay.date_time_system.getters")
local format    = require("source.gameplay.date_time_system.format")
local callbacks = require("source.gameplay.date_time_system.callbacks")
local graphics  = require("source.gameplay.date_time_system.graphics")
local save      = require("source.gameplay.date_time_system.save")
local c_library = require("source.gameplay.date_time_system.c_library")

-- Merge all exported functions into the main module
local modules = { core, getters, format, callbacks, graphics, save, c_library }
for _, mod in ipairs(modules) do
    for k, v in pairs(mod) do
        date_time_system[k] = v
    end
end

-- Expose internal references for debugging/testing
date_time_system._gt = structs.gt
date_time_system._state = state

-- Auto-init
date_time_system.init()

return date_time_system
