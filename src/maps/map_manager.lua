-- src/maps/map_manager.lua
local core = require("src.core.engine")

local MapManager = {}
MapManager.__index = MapManager

function MapManager.new(config)
    local self = setmetatable({}, MapManager)

    self.bg_path     = config.bg_path
    self.mask_path   = config.mask_path
    self.bgm_name    = config.bgm_name
    self.spawn_pos   = config.spawn or { x = 0, y = 0 }
    self.portals     = config.portals or {}
    self.debug_mode  = config.debug or false
    self.grid_size   = config.grid_size or 8

    self.bg_image    = nil
    self.mask_data   = nil
    self.width       = config.width or 320
    self.height      = config.height or 240
    self.added_items = {}
    self.is_loaded   = false

    return self
end

function MapManager:load()
    if self.is_loaded then return end

    if self.bg_path and love.filesystem.getInfo(self.bg_path) then
        self.bg_image = love.graphics.newImage(self.bg_path)
        self.width = self.bg_image:getWidth()
        self.height = self.bg_image:getHeight()
    end

    if self.mask_path and love.filesystem.getInfo(self.mask_path) then
        self.mask_data = love.image.newImageData(self.mask_path)
        self:_parseMaskToColliders()
    end

    -- Register Portals/Triggers
    if core.world then
        for _, portal in ipairs(self.portals) do
            local item = { 
                is_trigger = true, 
                name = portal.name, 
                target = portal.target, 
                x = portal.x, y = portal.y, w = portal.w, h = portal.h 
            }
            core.world:add(item, portal.x, portal.y, portal.w, portal.h)
            table.insert(self.added_items, item)
        end
    end

    if core.camera and core.camera.setBounds then
        core.camera:setBounds(0, 0, self.width, self.height)
    end

    if self.bgm_name and core.sound then
        core.sound:playBGM(self.bgm_name)
    end

    self.is_loaded = true
end

function MapManager:_parseMaskToColliders()
    if not self.mask_data or not core.world then return end

    local cell = self.grid_size
    local cols = math.ceil(self.width / cell)
    local rows = math.ceil(self.height / cell)

    for gy = 0, rows - 1 do
        local start_x = nil
        local current_w = 0

        for gx = 0, cols - 1 do
            local px = math.min(gx * cell + math.floor(cell / 2), self.width - 1)
            local py = math.min(gy * cell + math.floor(cell / 2), self.height - 1)

            local r, g, b, a = self.mask_data:getPixel(px, py)
            local is_solid = (a > 0.5 and (r > 0.5 or g < 0.2))

            if is_solid then
                if not start_x then
                    start_x = gx * cell
                end
                current_w = current_w + cell
            else
                if start_x then
                    self:_addObstacleBox(start_x, gy * cell, current_w, cell)
                    start_x = nil
                    current_w = 0
                end
            end
        end

        if start_x then
            self:_addObstacleBox(start_x, gy * cell, current_w, cell)
        end
    end
end

function MapManager:_addObstacleBox(x, y, w, h)
    local item = { is_obstacle = true, x = x, y = y, w = w, h = h }
    core.world:add(item, x, y, w, h)
    table.insert(self.added_items, item)
end

function MapManager:draw()
    if not self.is_loaded then self:load() end

    love.graphics.setColor(1, 1, 1, 1)
    if self.bg_image then
        love.graphics.draw(self.bg_image, 0, 0)
    end

    if self.debug_mode and core.world then
        for _, item in ipairs(self.added_items) do
            if item.is_obstacle then
                love.graphics.setColor(1, 0, 0, 0.4)
            elseif item.is_trigger then
                love.graphics.setColor(0, 1, 0, 0.4)
            end
            love.graphics.rectangle("line", item.x, item.y, item.w, item.h)
        end
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function MapManager:unload()
    if core.world then
        for _, item in ipairs(self.added_items) do
            if core.world:hasItem(item) then
                core.world:remove(item)
            end
        end
    end
    self.added_items = {}
    self.bg_image = nil
    self.mask_data = nil
    self.is_loaded = false
end

return MapManager