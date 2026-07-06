-- source/title_menu.lua
local menu = {}
local state = require("source.states_manager")

menu.selectedOption = 1 -- 1 = start, 2 = quit 
menu.menuBGM = nil
menu.bgImage = nil

local moveThisFrame = false
local actionThisFrame = false

function menu.load()
    menu.menuBGM = love.audio.newSource("soundtracks/ost/Title_Theme.mp3", "stream")
    menu.menuBGM:setLooping(true)
    menu.menuBGM:setVolume(0.5)
    menu.menuBGM:play()
    menu.bgImage = love.graphics.newImage("assets/images/kigen_shrine_menu_title_background.png")
    menu.bgImage:setFilter("nearest", "nearest")
end

function menu.update(dt)
    local _, joy_y = 0, 0
    if type(controller) == "table" and controller.getAxis then
        _, joy_y = controller.getAxis()
    end

    if joy_y < -0.5 or love.keyboard.isDown("up") then 
        if not moveThisFrame then
            menu.selectedOption = 1
            moveThisFrame = true 
        end
    elseif joy_y > 0.5 or love.keyboard.isDown("down") then
        if not moveThisFrame then
            menu.selectedOption = 2
            moveThisFrame = true 
        end
    else 
        if math.abs(joy_y) < 0.1 and not love.keyboard.isDown("up") and not love.keyboard.isDown("down") then
            moveThisFrame = false 
        end
    end
    
    local a_pressed = false
    if type(controller) == "table" and controller.isDown then
        a_pressed = controller.isDown("a")
    end

    if a_pressed or love.keyboard.isDown("return") or love.keyboard.isDown("z") then 
        if not actionThisFrame then
            actionThisFrame = true 
            
            if menu.selectedOption == 1 then
                if menu.menuBGM then menu.menuBGM:stop() end
                -- [แก้ไข]: เรียกสลับเข้าห้องนอนผ่านระบบกลางอย่างปลอดภัย
                state.switch("bedroom") 
            elseif menu.selectedOption == 2 then
                love.event.quit()
            end
        end
    else
        actionThisFrame = false 
    end
end

function menu.draw()
    if menu.bgImage then
        love.graphics.draw(menu.bgImage, 40, 0, 0, 3.75, 3.75)
    end
    
    if menu.selectedOption == 1 then
        love.graphics.print("> START", 130, 100)
        love.graphics.print("  QUIT", 130, 140)
    else
        love.graphics.print("  START", 130, 100)
        love.graphics.print("> QUIT", 130, 140)
    end
end

function menu.keypressed(key)
    if key == "up" then
        menu.selectedOption = 1
    elseif key == "down" then
        menu.selectedOption = 2
    elseif key == "return" or key == "z" then
        if menu.selectedOption == 1 then
            if menu.menuBGM then menu.menuBGM:stop() end
            state.switch("bedroom")
        elseif menu.selectedOption == 2 then
            love.event.quit() 
        end
    end
end

return menu