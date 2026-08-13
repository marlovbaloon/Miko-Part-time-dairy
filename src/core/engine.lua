-- src/core/engine.lua
local bump      = require("lib.bump")
local camera    = require("lib.stalker-x")
local talkies   = require("lib.talkies")
local input     = require("src.core.input")
local sound     = require("src.core.sound")
local map_mgr   = require("src.maps.map_manager")

local Engine = {
    world        = nil,
    camera       = nil,
    input        = input,
    sound        = sound,
    map          = map_mgr,
    dialogue     = talkies,

    -- State
    current_scene = nil,
    next_scene    = nil,
    scene_args    = nil,
    is_running    = true
}

----------------------------------------------------------------
-- Core Lifecycle
----------------------------------------------------------------

function Engine:init()
    -- 1. Initialize Subsystems
    self.world  = bump.newWorld(32)
    self.camera = camera()

    -- Talkies setup
    self.dialogue.inlineOptions = true

    -- Initialize Core Modules
    self.input:init()
    self.sound:init()

    -- Pixel-art scaling configuration
    love.graphics.setDefaultFilter("nearest", "nearest")
end

function Engine:update(dt)
    -- Handle Pending Scene Transitions (Deferred Switch)
    if self.next_scene then
        self:_performSceneSwitch()
    end

    -- 1. Subsystems Update
    self.input:update(dt)
    self.sound:update(dt)
    self.camera:update(dt)

    -- 2. Scene Update
    if self.current_scene and self.current_scene.update then
        self.current_scene:update(dt)
    end

    -- 3. UI / Dialogue System Update
    self.dialogue.update(dt)
end

function Engine:draw()
    -- Render World/Game Layer (With Camera)
    self.camera:attach()
        if self.current_scene and self.current_scene.draw then
            self.current_scene:draw()
        end
    self.camera:detach()

    -- Render Screen/UI Layer (Post-Camera / HUD / Dialogue)
    if self.current_scene and self.current_scene.drawUI then
        self.current_scene:drawUI()
    end

    self.dialogue.draw()
end

----------------------------------------------------------------
-- Scene Management (bn::scene-like abstraction)
----------------------------------------------------------------

function Engine:changeScene(new_scene_table, ...)
    -- Queue transition for next update to prevent breaking current frame loop
    self.next_scene = new_scene_table
    self.scene_args = { ... }
end

function Engine:_performSceneSwitch()
    -- Unload current scene
    if self.current_scene then
        if self.current_scene.unload then
            self.current_scene:unload()
        end
        -- Reset/Clean Bump World items if scene changes
        self:_clearWorld()
    end

    -- Switch
    self.current_scene = self.next_scene
    self.next_scene = nil

    -- Initialize new scene
    if self.current_scene and self.current_scene.enter then
        self.current_scene:enter(unpack(self.scene_args or {}))
    end
    self.scene_args = nil
end

function Engine:_clearWorld()
    local items, len = self.world:getItems()
    for i = 1, len do
        self.world:remove(items[i])
    end
end

----------------------------------------------------------------
-- Input Handlers Bridging
----------------------------------------------------------------

function Engine:keypressed(key)
    self.input:keypressed(key)
    self.dialogue.onKeyPressed(key)
    
    if self.current_scene and self.current_scene.keypressed then
        self.current_scene:keypressed(key)
    end
end

function Engine:keyreleased(key)
    self.input:keyreleased(key)
    if self.current_scene and self.current_scene.keyreleased then
        self.current_scene:keyreleased(key)
    end
end

return Engine