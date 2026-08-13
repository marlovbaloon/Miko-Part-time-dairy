-- main.lua
local core = require("src.core.engine")

function love.load()
    core:init()
    core:changeScene(require("src.scences.scene_title"))
end

function 
    love.update(dt) 
    core:update(dt) 
end
function 
    love.draw() 
    core:draw() 
end
function 
    love.keypressed(k) 
    core:keypressed(k) 
end
function 
    love.keyreleased(k) 
    core:keyreleased(k) 
end