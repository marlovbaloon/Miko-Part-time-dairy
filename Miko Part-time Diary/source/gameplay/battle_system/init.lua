-- battle_system/init.lua
-- Main entry: wires all submodules together into one battle module

local battle_system = {}

-- Shared data
local structs = require("source.gameplay.battle_system.structs")
local state   = require("source.gameplay.battle_system.state")
local config  = require("source.gameplay.battle_system.config")

-- Expose constants so the external API matches the original flat module
for k, v in pairs(config) do
    battle_system[k] = v
end

-- Each submodule returns a function(M) that adds its functions to the main table
local submodules = {
    "source.gameplay.battle_system.utils",
    "source.gameplay.battle_system.layout",
    "source.gameplay.battle_system.battle",
    "source.gameplay.battle_system.input",
    "source.gameplay.battle_system.commands",
    "source.gameplay.battle_system.bullet_hell",
    "source.gameplay.battle_system.dialogue",
    "source.gameplay.battle_system.draw",
}

for _, path in ipairs(submodules) do
    local mod = require(path)
    mod(battle_system)
end

-- Expose internal references for debugging/testing
battle_system._structs = structs
battle_system._state = state
battle_system._config = config

return battle_system
