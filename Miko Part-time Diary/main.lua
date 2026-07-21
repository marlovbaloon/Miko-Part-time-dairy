-- main.lua
local state = require("source.states_manager")
controller = require("source.libs.controller")

local virtualWidth = 320
local virtualHeight = 320
local gameCanvas = nil
local Camera = require("source.libs.camera")
myCamera = nil 

local scale = 1
local offsetX = 0
local offsetY = 0

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    gameCanvas = love.graphics.newCanvas(virtualWidth, virtualHeight)
    controller.init(love.graphics.getWidth(), love.graphics.getHeight()) 
    
    myCamera = Camera.new(virtualWidth, virtualHeight)
    
    -- =======================================================
    -- [แก้ไข]: โหลดและลงทะเบียนฉากตรงนี้ เพื่อให้ StateManager รู้จักครบทุกฉากก่อนเริ่มเกม
    -- =======================================================
    state.register("menu", require("source.title_menu"))
    state.register("bedroom", require("source.scenes.scene_bedroom"))
    
    -- พอระบบรู้จักฉากครบแล้ว ค่อยสั่งเปิดหน้าจอแรกที่หน้าเมนู!
    state.switch("menu")
    
    love.resize(love.graphics.getWidth(), love.graphics.getHeight())
end

function love.resize(w, h)
    local scaleX = w / virtualWidth
    local scaleY = h / virtualHeight
    scale = math.min(scaleX, scaleY)
    
    offsetX = (w - (virtualWidth * scale)) / 2
    offsetY = (h - (virtualHeight * scale)) / 2
    
    controller.init(w, h)
end

function love.update(dt)
    state.update(dt)
end

function love.draw()
    love.graphics.setCanvas(gameCanvas)
    love.graphics.clear()
    
    state.draw()
    
    love.graphics.setCanvas()
    love.graphics.draw(gameCanvas, offsetX, offsetY, 0, scale, scale)
    controller.draw() 
    
end

function love.quit()
    love.window.setFullscreen(false)
end

function love.keypressed(key)
    state.keypressed(key)
end