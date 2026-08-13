--src/entities/kaoru.lua
local anim = require("lib.anim8")
local bump = require("lib.bump")
local controller = require("lib.controller")

local kaoru = {
    x = 100,
    y = 100,
    width = 32,
    height = 32,
    speed = 120,
    is_player = true,
    direction = "down",
    is_moving = false,
    current_anim = nil
}

function kaoru:load(world)
    self.sheet = love.graphics.newImage("assets/images/sprites/kaoru_sheet.png")
    self.grid = anim.newGrid(32, 32, self.sheet:getWidth(), self.sheet:getHeight())
    
    self.animations = {
        ["idle_down"]  = anim.newAnimation(self.grid(1, 1), 1),
        ["idle_up"]    = anim.newAnimation(self.grid(3, 1), 1),
        ["idle_left"]  = anim.newAnimation(self.grid(4, 1), 1),
        ["idle_right"] = anim.newAnimation(self.grid(2, 1), 1),

        ["walk_down"]  = anim.newAnimation(self.grid(1, '1-4'), 0.10),
        ["walk_up"]    = anim.newAnimation(self.grid(3, '1-4'), 0.10),
        ["walk_left"]  = anim.newAnimation(self.grid(4, '1-4'), 0.10),
        ["walk_right"] = anim.newAnimation(self.grid(2, '1-4'), 0.10)
    }
    self.current_anim = self.animations["idle_down"]
    if world and not world:hasItem(self) then
        world:add(self, self.x, self.y, self.width, self.height)
    end
end

local function playerFilter(item, other)
    if other.is_trigger then return "cross" end
    return "slide"
end

function kaoru:update(dt, world, ctrl)
    local input_ctrl = ctrl or controller
    local dx, dy = 0, 0

    if input_ctrl and input_ctrl.getAxis then
        dx, dy = input_ctrl.getAxis()
    end

    if dx == 0 and dy == 0 then
        if love.keyboard.isDown("right") or love.keyboard.isDown("d") then dx = dx + 1 end
        if love.keyboard.isDown("left")  or love.keyboard.isDown("a") then dx = dx - 1 end
        if love.keyboard.isDown("down")  or love.keyboard.isDown("s") then dy = dy + 1 end
        if love.keyboard.isDown("up")    or love.keyboard.isDown("w") then dy = dy - 1 end
    end

    self.is_moving = (dx ~= 0 or dy ~= 0)

    if self.is_moving then
        if math.abs(dx) > math.abs(dy) then
            self.direction = (dx > 0) and "right" or "left"
        else
            self.direction = (dy > 0) and "down" or "up"
        end
        self.current_anim = self.animations["walk_" .. self.direction]
    else
        self.current_anim = self.animations["idle_" .. self.direction]
    end

    self.current_anim:update(dt)

    if self.is_moving then
        local len = math.sqrt(dx * dx + dy * dy)
        if len > 0 then
            dx = dx / len
            dy = dy / len
        end

        local goalX = self.x + (dx * self.speed * dt)
        local goalY = self.y + (dy * self.speed * dt)
        if world then
            local actualX, actualY, cols, lenCols = world:move(self, goalX, goalY, playerFilter)
            self.x = actualX
            self.y = actualY
        else
            self.x = goalX
            self.y = goalY
        end
    end
end

function kaoru:draw()
    love.graphics.setColor(1, 1, 1, 1)
    if self.current_anim then
        self.current_anim:draw(self.sheet, math.floor(self.x), math.floor(self.y))
    end
end

return kaoru