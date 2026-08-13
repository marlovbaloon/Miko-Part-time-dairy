-- src/entities/kaoru.lua
local anim = require("lib.anim8")
local core = require("src.core.engine")

local kaoru = {
    x = 100, y = 100,
    width = 32, height = 32,
    speed = 120,
    direction = "down",
    is_moving = false
}

local function playerFilter(item, other)
    return other.is_trigger and "cross" or "slide"
end

function kaoru:load()
    self.sheet = love.graphics.newImage("assets/images/sprites/kaoru_sheet.png")
    local g = anim.newGrid(32, 32, self.sheet:getWidth(), self.sheet:getHeight())
    
    self.anims = {
        idle_down  = anim.newAnimation(g(1, 1), 1),
        idle_up    = anim.newAnimation(g(3, 1), 1),
        idle_left  = anim.newAnimation(g(4, 1), 1),
        idle_right = anim.newAnimation(g(2, 1), 1),
        walk_down  = anim.newAnimation(g(1, '1-4'), 0.10),
        walk_up    = anim.newAnimation(g(3, '1-4'), 0.10),
        walk_left  = anim.newAnimation(g(4, '1-4'), 0.10),
        walk_right = anim.newAnimation(g(2, '1-4'), 0.10)
    }
    self.current_anim = self.anims.idle_down

    if core.world and not core.world:hasItem(self) then
        core.world:add(self, self.x, self.y, self.width, self.height)
    end
end

function kaoru:update(dt)
    local dx, dy = core.input:getAxis()
    self.is_moving = (dx ~= 0 or dy ~= 0)

    if self.is_moving then
        if math.abs(dx) > math.abs(dy) then
            self.direction = dx > 0 and "right" or "left"
        else
            self.direction = dy > 0 and "down" or "up"
        end

        local len = math.sqrt(dx * dx + dy * dy)
        local goalX = self.x + (dx / len * self.speed * dt)
        local goalY = self.y + (dy / len * self.speed * dt)

        self.x, self.y = core.world:move(self, goalX, goalY, playerFilter)
        self.current_anim = self.anims["walk_" .. self.direction]
    else
        self.current_anim = self.anims["idle_" .. self.direction]
    end

    self.current_anim:update(dt)
end

function kaoru:draw()
    love.graphics.setColor(1, 1, 1, 1)
    if self.current_anim then
        self.current_anim:draw(self.sheet, math.floor(self.x), math.floor(self.y))
    end
end

return kaoru