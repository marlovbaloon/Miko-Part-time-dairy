-- source/maps/map_manager.lua
local MapManager = {}
MapManager.__index = MapManager

function MapManager.new(config)
    local self = setmetatable({}, MapManager)

    -- Config Data
    self.bg_path    = config.bg_path
    self.bgm_path   = config.bgm_path
    self.bgm_volume = config.bgm_volume or 0.5
    self.zoom_level = config.zoom_level or 1.5
    self.player_ref = config.player_ref
    self.spawn_pos  = config.spawn or { x = 0, y = 0 }
    self.build_colliders_fn = config.build_colliders
    self.portals    = config.portals or {}

    -- State Values
    self.bgm         = nil
    self.bg_image    = nil
    self.map_width   = config.default_width or 190
    self.map_height  = config.default_height or 160
    self.colliders   = {}
    self.is_loaded   = false
    self.debug_mode  = config.debug or false

    self.load = function()
        if self.is_loaded then return end

        if self.bgm_path then
            self.bgm = love.audio.newSource(self.bgm_path, "stream")
            self.bgm:setLooping(true)
            self.bgm:setVolume(self.bgm_volume)
            self.bgm:play()
        end

        if self.bg_path then
            self.bg_image = love.graphics.newImage(self.bg_path)
            self.bg_image:setFilter("nearest", "nearest")
            self.map_width = self.bg_image:getWidth()
            self.map_height = self.bg_image:getHeight()
        end

        -- โหลด Colliders ปกติ
        if type(self.build_colliders_fn) == "function" then
            self.colliders = self.build_colliders_fn(self.map_width, self.map_height)
        else
            self.colliders = {}
        end

        -- รวม Portals เข้าไปใน Colliders เพื่อให้ interact เช็กเจอ
        if self.portals then
            for i = 1, #self.portals do
                table.insert(self.colliders, self.portals[i])
            end
        end

        self.is_loaded = true
    end

    self.init = function()
        if _G.myCamera and _G.myCamera.setZoom then
            _G.myCamera:setZoom(self.zoom_level)
        end

        self.load()

        if self.player_ref then
            self.player_ref.x = self.spawn_pos.x
            self.player_ref.y = self.spawn_pos.y
        end
    end

    self.destroy = function()
        if self.bgm then
            self.bgm:stop()
            self.bgm = nil
        end
        self.bg_image = nil
        self.colliders = {}
        self.is_loaded = false
    end

    self.draw = function()
        if not self.is_loaded then self.load() end

        local cam = _G.myCamera
        local zoom = (cam and cam.zoom) or self.zoom_level

        love.graphics.clear(0.15, 0.12, 0.10)

        -- 1. วาดรูปแมพ
        love.graphics.setColor(1, 1, 1, 1)
        if self.bg_image then
            local map_pos = cam and cam:toScreen(0, 0, 0) or { x = 0, y = 0 }
            love.graphics.draw(self.bg_image, map_pos.x, map_pos.y, 0, zoom, zoom)
        end

        -- 2. วาดกรอบห้อง
        if cam then
            love.graphics.setColor(0.05, 0.05, 0.07)
            local tl = cam:toScreen(0, 0, 0)
            local br = cam:toScreen(self.map_width, self.map_height, 0)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", tl.x, tl.y, br.x - tl.x, br.y - tl.y)
            love.graphics.setLineWidth(1)
        end

        -- 3. Debug Hitbox
        if self.debug_mode and cam then
            love.graphics.setColor(1, 0, 0, 0.6)
            for i = 1, #self.colliders do
                local box = self.colliders[i]
                local box_screen = cam:toScreen(box.x, box.y, 0)
                love.graphics.rectangle("line", box_screen.x, box_screen.y, box.width * zoom, box.height * zoom)
            end
        end

        -- 4. วาดตัวละคร
        love.graphics.setColor(1, 1, 1, 1)
        if self.player_ref and self.player_ref.draw then
            self.player_ref:draw(cam)
        end

        love.graphics.setColor(1, 1, 1, 1)
    end

    return self
end

return MapManager