-- src/scenes/scene_title.lua
local core = require("src.core.engine")

local SceneTitle = {}

function SceneTitle:enter()
    self.options = {
        { 
            label = "START GAME", 
            action = function() 
                core:changeScene(require("src.scenes.scene_01_bedroom")) 
            end 
        },
        { 
            label = "EXIT", 
            action = function() 
                love.event.quit() 
            end 
        }
    }
    self.selected_index = 1

    -- Load Visual Assets
    local bg_path = "assets/images/backgrounds/shrine_grounds.png"
    local overlay_path = "assets/images/ui/crt_overlay.png"

    if love.filesystem.getInfo(bg_path) then
        self.bg = love.graphics.newImage(bg_path)
    end

    if love.filesystem.getInfo(overlay_path) then
        self.crt_overlay = love.graphics.newImage(overlay_path)
    end

    -- Fonts & Audio
    self.font_title = love.graphics.newFont(24)
    self.font_menu  = love.graphics.newFont(14)

    core.sound:playBGM("Title_Theme")
end

function SceneTitle:update(dt)
    -- Reserved for menu animations / background parallax
end

function SceneTitle:keypressed(key)
    if key == "up" or key == "w" then
        self.selected_index = self.selected_index - 1
        if self.selected_index < 1 then
            self.selected_index = #self.options
        end
        core.sound:playSFX("Click")

    elseif key == "down" or key == "s" then
        self.selected_index = self.selected_index + 1
        if self.selected_index > #self.options then
            self.selected_index = 1
        end
        core.sound:playSFX("Click")

    elseif key == "return" or key == "space" or key == "z" then
        core.sound:playSFX("Click")
        self.options[self.selected_index].action()
    end
end

function SceneTitle:drawUI()
    local screen_w = love.graphics.getWidth()
    local screen_h = love.graphics.getHeight()

    -- 1. Draw Background
    love.graphics.setColor(1, 1, 1, 1)
    if self.bg then
        local scale_x = screen_w / self.bg:getWidth()
        local scale_y = screen_h / self.bg:getHeight()
        love.graphics.draw(self.bg, 0, 0, 0, scale_x, scale_y)
    else
        love.graphics.clear(0.1, 0.1, 0.12)
    end

    -- Darken filter for readability
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", 0, 0, screen_w, screen_h)

    -- 2. Draw Title Text
    love.graphics.setFont(self.font_title)
    love.graphics.setColor(1, 0.9, 0.8, 1)
    love.graphics.printf("MIKO PART-TIME DIARY", 0, screen_h * 0.25, screen_w, "center")

    -- 3. Draw Menu Options
    love.graphics.setFont(self.font_menu)
    local start_y = screen_h * 0.55
    local spacing = 28

    for i, option in ipairs(self.options) do
        local y = start_y + (i - 1) * spacing

        if i == self.selected_index then
            love.graphics.setColor(1, 0.85, 0.3, 1)
            love.graphics.printf(">  " .. option.label .. "  <", 0, y, screen_w, "center")
        else
            love.graphics.setColor(0.7, 0.7, 0.75, 0.8)
            love.graphics.printf(option.label, 0, y, screen_w, "center")
        end
    end

    -- 4. CRT Overlay Layer
    if self.crt_overlay then
        love.graphics.setColor(1, 1, 1, 0.25)
        local scale_x = screen_w / self.crt_overlay:getWidth()
        local scale_y = screen_h / self.crt_overlay:getHeight()
        love.graphics.draw(self.crt_overlay, 0, 0, 0, scale_x, scale_y)
    end
end

function SceneTitle:unload()
    core.sound:stopBGM()
end

return SceneTitle