-- src/maps/map_manager.lua
local MapManager = {}
MapManager.__index = MapManager

function MapManager.new(config)
    local self = setmetatable({}, MapManager)

    -- Configuration
    self.bg_path         = config.bg_path
    self.mask_path       = config.mask_path
    self.bgm_path        = config.bgm_path
    self.bgm_volume      = config.bgm_volume or 0.5
    self.zoom_level      = config.zoom_level or 1.5
    self.player_ref      = config.player_ref
    self.spawn_pos       = config.spawn or { x = 0, y = 0 }
    self.build_colliders = config.build_colliders
    self.portals         = config.portals or {}
    self.debug_mode      = config.debug or false

    -- Map Data & Resources
    self.bgm             = nil
    self.bg_image        = nil
    self.mask_data       = nil -- ImageData for pixel collision reading
    self.map_width       = config.default_width or 190
    self.map_height      = config.default_height or 160
    self.colliders       = {}
    self.render_queue    = {}
    self.is_loaded       = false

    return self
end

function MapManager:load()
    if self.is_loaded then return end

    -- Audio Initialization
    if self.bgm_path then
        self.bgm = love.audio.newSource(self.bgm_path, "stream")
        self.bgm:setLooping(true)
        self.bgm:setVolume(self.bgm_volume)
        self.bgm:play()
    end

    -- Background Visual Image
    if self.bg_path then
        self.bg_image = love.graphics.newImage(self.bg_path)
        self.bg_image:setFilter("nearest", "nearest")
        self.map_width = self.bg_image:getWidth()
        self.map_height = self.bg_image:getHeight()
    end

    -- Collision Mask (Loaded into CPU memory as ImageData)
    if self.mask_path then
        self.mask_data = love.image.newImageData(self.mask_path)
    end

    -- Bounding Box Colliders Setup
    if type(self.build_colliders) == "function" then
        self.colliders = self.build_colliders(self.map_width, self.map_height)
    end

    for _, portal in ipairs(self.portals) do
        table.insert(self.colliders, portal)
    end

    self.is_loaded = true
end

function MapManager:init()
    if _G.myCamera and _G.myCamera.setZoom then
        _G.myCamera:setZoom(self.zoom_level)
    end

    self:load()

    if self.player_ref then
        self.player_ref.x = self.spawn_pos.x
        self.player_ref.y = self.spawn_pos.y
    end
end

-- Pixel Collision Detection using loaded Mask
function MapManager:isPixelSolid(x, y)
    if not self.mask_data then return false end

    local ix = math.floor(x)
    local iy = math.floor(y)

    -- Bounds check
    if ix < 0 or ix >= self.map_width or iy < 0 or iy >= self.map_height then
        return true
    end

    local r, g, b, a = self.mask_data:getPixel(ix, iy)
    
    -- Returns true if pixel alpha > 0.5 or matches solid condition (e.g. Red channel > 0.5)
    return a > 0.5
end

-- Retrieve Color values (R, G, B, A) at specific map position
function MapManager:getMaskColor(x, y)
    if not self.mask_data then return 0, 0, 0, 0 end

    local ix = math.floor(x)
    local iy = math.floor(y)

    if ix < 0 or ix >= self.map_width or iy < 0 or iy >= self.map_height then
        return 0, 0, 0, 0
    end

    return self.mask_data:getPixel(ix, iy)
end

function MapManager:update(dt)
    -- Reserved for dynamic map objects updating
end

function MapManager:draw()
    if not self.is_loaded then self:load() end

    local cam = _G.myCamera
    local zoom = (cam and cam.zoom) or self.zoom_level

    love.graphics.clear(0.15, 0.12, 0.10)

    -- 1. Draw Map Background
    love.graphics.setColor(1, 1, 1, 1)
    if self.bg_image then
        local map_pos = cam and cam:toScreen(0, 0, 0) or { x = 0, y = 0 }
        love.graphics.draw(self.bg_image, map_pos.x, map_pos.y, 0, zoom, zoom)
    end

    -- 2. Map Outer Boundary Line
    if cam then
        love.graphics.setColor(0.05, 0.05, 0.07)
        local tl = cam:toScreen(0, 0, 0)
        local br = cam:toScreen(self.map_width, self.map_height, 0)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", tl.x, tl.y, br.x - tl.x, br.y - tl.y)
        love.graphics.setLineWidth(1)
    end

    -- 3. Render Objects using Y-Sorting
    self.render_queue = {}
    if self.player_ref then
        table.insert(self.render_queue, self.player_ref)
    end

    -- Sort elements based on Y position (Depth Sorting)
    table.sort(self.render_queue, function(a, b)
        return (a.y or 0) < (b.y or 0)
    end)

    love.graphics.setColor(1, 1, 1, 1)
    for _, drawable in ipairs(self.render_queue) do
        if drawable.draw then
            drawable:draw(cam)
        end
    end

    -- 4. Debug Render Colliders
    if self.debug_mode and cam then
        love.graphics.setColor(1, 0, 0, 0.6)
        for _, box in ipairs(self.colliders) do
            local box_screen = cam:toScreen(box.x, box.y, 0)
            love.graphics.rectangle("line", box_screen.x, box_screen.y, box.width * zoom, box.height * zoom)
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function MapManager:destroy()
    if self.bgm then
        self.bgm:stop()
        self.bgm = nil
    end
    self.bg_image = nil
    self.mask_data = nil
    self.colliders = {}
    self.render_queue = {}
    self.is_loaded = false
end

return MapManager