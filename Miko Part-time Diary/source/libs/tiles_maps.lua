-- source/libs/tiles_maps.lua
local anim8 = require("source.libs.anim8")
local Tiles = {}

Tiles.sprites = {}
Tiles.animations = {} 
Tiles.grid_size = 32

Tiles.current_map = {}
Tiles.collision_types = {}
Tiles.loaded_images = {}
Tiles.properties = {}

-- จองพื้นที่ตารางไว้ล่วงหน้าครั้งเดียว 0% Garbage
local collider_pool = {}
for i = 1, 25 do
    collider_pool[i] = { x = 0, y = 0, width = 0, height = 0, active = false, mask = nil }
end

local function getImage(path)
    if not Tiles.loaded_images[path] then
        Tiles.loaded_images[path] = love.graphics.newImage(path)
    end
    return Tiles.loaded_images[path]
end

function Tiles.loadTileset(image_path, tile_types)
    local image = getImage(image_path)
    local img_w, img_h = image:getDimensions()

    local index = 0
    for y = 0, (img_h / Tiles.grid_size) - 1 do
        for x = 0, (img_w / Tiles.grid_size) - 1 do
            local name = tile_types[index] or ("tile_" .. index)
            Tiles.sprites[name] = {
                image = image,
                quad = love.graphics.newQuad(
                    x * Tiles.grid_size, y * Tiles.grid_size, 
                    Tiles.grid_size, Tiles.grid_size, img_w, img_h
                )
            }
            index = index + 1
        end
    end
end 

function Tiles.createAnimation(name, image_path, frame_width, frame_height, frame_setting, duration)
    local image = getImage(image_path)
    local img_w, img_h = image:getDimensions()
    local grid = anim8.newGrid(frame_width, frame_height, img_w, img_h)
    local frames = grid(unpack(frame_setting))
    Tiles.animations[name] = { image = image, anim = anim8.newAnimation(frames, duration) }
end

function Tiles.defineTile(tile_type, is_collidable, mask_obj)
    Tiles.properties[tile_type] = {
        mask = mask_obj or nil
    }
    if is_collidable then
        Tiles.collision_types[tile_type] = true
    end
end

function Tiles.setTile(x, y, tile_type)
    if not Tiles.current_map[x] then Tiles.current_map[x] = {} end

    local props = Tiles.properties[tile_type] or {}
    local world_x = x * Tiles.grid_size
    local world_y = y * Tiles.grid_size

    Tiles.current_map[x][y] = {
        type = tile_type,
        x = world_x,
        y = world_y,
        width = Tiles.grid_size,
        height = Tiles.grid_size,
        mask = props.mask,
        draw = function(self, camera)
            Tiles.draw(self.type, self.x, self.y, camera)
        end
    }
end

-- วาด 2D แท้ ส่งพิกัดโลกเข้า camera:toScreen ตรง ๆ ไม่เยื้องจุดศูนย์ถ่วง
function Tiles.draw(tile_type, world_x, world_y, camera)
    if not camera then
        if Tiles.animations[tile_type] then
            local anim_obj = Tiles.animations[tile_type]
            anim_obj.anim:draw(anim_obj.image, world_x, world_y)
        elseif Tiles.sprites[tile_type] then
            local sprite = Tiles.sprites[tile_type]
            love.graphics.draw(sprite.image, sprite.quad, world_x, world_y)
        end
        return
    end

    local screen_pos = camera:toScreen(world_x, world_y, 0)
    local scale = screen_pos.scale or 1.0 -- ดึงค่าซูมกล้องมาใช้ ถ้าไม่มีให้เป็น 1.0

    if Tiles.animations[tile_type] then
        local anim_obj = Tiles.animations[tile_type]
        -- [🎯 FIXED]: ยัดค่าสเกลซูมลงในตัวแอนิเมชัน (องศาหมุน = 0, scaleX, scaleY)
        anim_obj.anim:draw(anim_obj.image, screen_pos.x, screen_pos.y, 0, scale, scale)
    elseif Tiles.sprites[tile_type] then
        local sprite = Tiles.sprites[tile_type]
        -- [🎯 FIXED]: ยัดค่าสเกลซูมลงในรูปภาพสไปรท์ธรรมดา (องศาหมุน = 0, scaleX, scaleY)
        love.graphics.draw(sprite.image, sprite.quad, screen_pos.x, screen_pos.y, 0, scale, scale)
    end
end

function Tiles.update(dt)
    for _, anim_obj in pairs(Tiles.animations) do
        anim_obj.anim:update(dt)
    end
end

function Tiles.getNearbyColliders(player_x, player_y)
    for i = 1, 25 do collider_pool[i].active = false end

    local center_x = math.floor(player_x / Tiles.grid_size)
    local center_y = math.floor(player_y / Tiles.grid_size)
    local pool_index = 1

    for y = center_y - 2, center_y + 2 do
        for x = center_x - 2, center_x + 2 do
            if Tiles.current_map[x] and Tiles.current_map[x][y] then
                local tile = Tiles.current_map[x][y]

                if tile and Tiles.collision_types[tile.type] then
                    local col = collider_pool[pool_index]
                    col.x = tile.x
                    col.y = tile.y
                    col.width = tile.width
                    col.height = tile.height
                    col.mask = tile.mask
                    col.active = true

                    pool_index = pool_index + 1
                    if pool_index > 25 then break end
                end
            end
        end
    end
    return collider_pool
end

-- =======================================================
-- ระบบ Selector & Drop สไตล์ 2D แท้
-- =======================================================
function Tiles.selectTileFromSheet(image_path, tile_w, tile_h, grid_x, grid_y)
    local image = getImage(image_path)
    local img_w, img_h = image:getDimensions()

    local qx = grid_x * tile_w
    local qy = grid_y * tile_h
    local quad = love.graphics.newQuad(qx, qy, tile_w, tile_h, img_w, img_h)

    return {
        image = image,
        quad = quad,
        width = tile_w,
        height = tile_h
    }
end

function Tiles.placeTileToMap(gx, gy, unique_tile_type, brush_obj)
    if not brush_obj then return end

    Tiles.properties[unique_tile_type] = {
        mask = nil
    }

    Tiles.sprites[unique_tile_type] = {
        image = brush_obj.image,
        quad = brush_obj.quad
    }

    if not Tiles.current_map[gx] then Tiles.current_map[gx] = {} end

    local world_x = gx * Tiles.grid_size
    local world_y = gy * Tiles.grid_size

    Tiles.current_map[gx][gy] = {
        type = unique_tile_type,
        x = world_x,
        y = world_y,
        width = Tiles.grid_size,
        height = Tiles.grid_size,
        mask = nil,
        draw = function(self, camera)
            Tiles.draw(self.type, self.x, self.y, camera)
        end
    }
end
-- =======================================================
-- [NEW]: ฟังก์ชันโหลดแมปแบบอาเรย์ 2 มิติทีเดียวทั้งแผนที่
-- =======================================================
function Tiles.loadFullMap(map_matrix, brush_mapping)
    if not map_matrix or type(map_matrix) ~= "table" then return end

    -- แกะความกว้าง/สูงของ Matrix อัตโนมัติ
    local room_h = #map_matrix
    local room_w = map_matrix[1] and #map_matrix[1] or 0

    -- วิ่งลูปสลับแกน (Row/Col -> X/Y ของระบบพิกัดโลก)
    for row = 1, room_h do
        for col = 1, room_w do
            local tile_id = map_matrix[row][col]

            -- หาพิกัดในระบบ Grid (เริ่มจาก 0)
            local gx = col - 1
            local gy = row - 1

            -- ดึง Brush ที่ผูกไว้กับ ID ออกมาวาง
            local brush = brush_mapping[tile_id]
            if brush then
                local unique_name = "autogen_" .. tostring(tile_id)
                Tiles.placeTileToMap(gx, gy, unique_name, brush)
            end
        end
    end
end
return Tiles