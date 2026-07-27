-- source/states_manager.lua
local StateManager = {}

StateManager.scenes = {}
StateManager.currentScene = nil
StateManager.currentName = ""
StateManager.saveData = {} -- เก็บค่าเซฟเกมข้ามด่าน

function StateManager.register(name, scene_module)
    StateManager.scenes[name] = scene_module
end

function StateManager.switch(name, ...)
    if not StateManager.scenes[name] then
        error("Scene with that name was not found: " .. tostring(name))
    end

    if StateManager.currentScene and StateManager.currentScene.exit then
        StateManager.currentScene.exit()
    end

    StateManager.currentName = name
    StateManager.currentScene = StateManager.scenes[name]

    if StateManager.currentScene.load then
        StateManager.currentScene.load(StateManager.saveData, ...)
    end
end

function StateManager.update(dt)
    if StateManager.currentScene and StateManager.currentScene.update then
        StateManager.currentScene.update(dt)
    end
end

function StateManager.draw()
    if StateManager.currentScene and StateManager.currentScene.draw then
        StateManager.currentScene.draw()
    end
end

function StateManager.keypressed(key)
    if StateManager.currentScene and StateManager.currentScene.keypressed then
        StateManager.currentScene.keypressed(key)
    end
end

return StateManager