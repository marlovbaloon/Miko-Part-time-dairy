-- source/libs/tiles_maps.lua
local anim8 = require("source.libs.anim8")
local mask = require("source.libs.mask")
local Tiles = {}

Tiles.sprites = {}
Tiles.animations = {} 
Tiles.grid_size = 32

Tiles.current_map = {}
Tiles.collision_types = {}
Tiles.loaded_images = {}

-- คลังเก็บคุณสมบัติพิเศษของแต่ละบล็อก (3D, Mask)
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

function Tiles.defineTile(tile_type, is_collidable, is_3d, mask_obj)
    Tiles.properties[tile_type] = {
        is_3d = is_3d or false,
        mask = mask_obj or nil
    }
    if is_collidable then
        Tiles.collision_types[tile_type] = true
    end
end

-- [CLEANED]: ลบเวอร์ชันซ้ำออก และเก็บค่าพิกัดมุมซ้ายบนแท้จริง (Grid Origin) ไว้ในตัวแปร
function Tiles.setTile(x, y, tile_type)
    if not Tiles.current_map[x] then Tiles.current_map[x] = {} end
    
    local props = Tiles.properties[tile_type] or {}
    
    -- พิกัดมุมซ้ายบนดั้งเดิม (สำหรับใช้คิดระบบชนและอ้างอิงตำแหน่งโลก)
    local world_x = x * Tiles.grid_size
    local world_y = y * Tiles.grid_size
    
    Tiles.current_map[x][y] = {
        type = tile_type,
        x = world_x,
        y = world_y,
        width = Tiles.grid_size,
        height = Tiles.grid_size,
        is_3d = props.is_3d,
        mask = props.mask,
        -- ส่งกล้องเข้าไปประมวลผลทัศนมิติตอนสั่งวาด
        draw = function(self, camera)
            Tiles.draw(self.type, self.x, self.y, camera)
        end
    }
end

-- [FIXED]: ปรับระบบวาดให้รับพิกัดซ้ายบน แล้วไปเยื้องศูนย์กลางภายในตัวเอง ภาพกับกล่องชนจะได้ตรงกัน
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

    -- แปลงจุดอ้างอิงฐาน (กึ่งกลางล่างบล็อก) เข้าสู่โลกมุมมองลึก 3D
    local base_x = world_x + (Tiles.grid_size / 2)
    local base_y = world_y + Tiles.grid_size

    local screen_pos = camera:toScreen(base_x, base_y, 0)
    local sx = screen_pos.x
    local sy = screen_pos.y
    local scale = screen_pos.scale

    if Tiles.animations[tile_type] then
        local anim_obj = Tiles.animations[tile_type]
        anim_obj.anim:draw(anim_obj.image, sx, sy, 0, scale, scale, Tiles.grid_size / 2, Tiles.grid_size)
    elseif Tiles.sprites[tile_type] then
        local sprite = Tiles.sprites[tile_type]
        love.graphics.draw(sprite.image, sprite.quad, sx, sy, 0, scale, scale, Tiles.grid_size / 2, Tiles.grid_size)
    end
end

function Tiles.update(dt)
    for _, anim_obj in pairs(Tiles.animations) do
        anim_obj.anim:update(dt)
    end
end

function Tiles.registerToRenderGroup(render_group)
    for x, column in pairs(Tiles.current_map) do
        for y, tile in pairs(column) do
            if tile.is_3d then
                render_group:add(tile)
            end
        end
    end
end

-- [FIXED]: ระบบชนกลับมาทำงานแม่นยำ 100% เพราะค่า tile.x/y เป็นพิกัดหัวมุมสี่เหลี่ยมที่ถูกต้องแล้ว
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
function Tiles.draw(tile_type, world_x, world_y, camera, custom_size)
    local current_size = custom_size or Tiles.grid_size

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

    -- =======================================================
    -- [🎯 FIXED]: ส่งพิกัดหัวมุมซ้ายบน (world_x, world_y) เข้ากล้องตรง ๆ 
    -- เพื่อให้กล้องตบภาพให้นอนราบไปกับระนาบพื้นโลก 2.5D เองเลย ไม่ต้องแปลงฐานล่าง!
    -- =======================================================
    local screen_pos = camera:toScreen(world_x, world_y, 0)
    local sx = screen_pos.x
    local sy = screen_pos.y
    local scale = screen_pos.scale

    if Tiles.animations[tile_type] then
        local anim_obj = Tiles.animations[tile_type]
        -- ลบตัว Offset (Origin) ด้านหลังออกให้หมด ปล่อยให้มันวาดแนบไปกับพิกัดกล้องเลย
        anim_obj.anim:draw(anim_obj.image, sx, sy, 0, scale, scale)
    elseif Tiles.sprites[tile_type] then
        local sprite = Tiles.sprites[tile_type]
        -- ลบตัว Offset ด้านหลังออกเช่นกัน ภาพจะนอนราบปูเป็นพรมพื้นไม้ทันทีมึง!
        love.graphics.draw(sprite.image, sprite.quad, sx, sy, 0, scale, scale)
    end
end
-- =============================
-- ระบบ Selector & Drop สำหรับสร้าง/แก้ไขแผนที่ (Map Editor Engine)
-- =============================

-- 1. ฟังก์ชันตัดแบ่งและเลือกแปรงไทล์จาก Tileset Sheet
-- ปรับแก้ตัวสะกดตามที่มึงเรียกใช้ใน bedroom_map (จาก Form เป็น From)
function Tiles.selectTileFromSheet(image_path, tile_w, tile_h, grid_x, grid_y)
    local image = getImage(image_path)
    local img_w, img_h = image:getDimensions()
    
    -- สร้าง Quad เฉพาะกิจสำหรับไทล์หน้านั้น ๆ ที่เลือกจากพิกัดตารางบนรูป
    local qx = grid_x * tile_w
    local qy = grid_y * tile_h
    local quad = love.graphics.newQuad(qx, qy, tile_w, tile_h, img_w, img_h)
    
    -- คืนค่ากลับไปเป็นก้อน Object แปรง (Brush) ที่พร้อมเอาไปหยอดลง Map
    return {
        image = image,
        quad = quad,
        width = tile_w,
        height = tile_h
    }
end

-- 2. ฟังก์ชัน Drop / Place แปรงไทล์ลงในตารางแผนที่ 2.5D
function Tiles.placeTileToMap(gx, gy, unique_tile_type, brush_obj)
    if not brush_obj then return end
    
    -- ลงทะเบียนคุณสมบัติของไทล์ใหม่เข้าสู่ระบบ Properties
    Tiles.properties[unique_tile_type] = {
        is_3d = false, -- พื้นห้องนอนเป็นระนาบ 2D นอนราบกับพื้นโลก
        mask = nil
    }
    
    -- ยัดก้อนข้อมูลรูปภาพเข้าไปในสไปรท์หลักของเอนจินเพื่อเตรียมเรนเดอร์
    Tiles.sprites[unique_tile_type] = {
        image = brush_obj.image,
        quad = brush_obj.quad
    }
    
    -- สั่งผูกข้อมูลลงพิกัดตาราง Grid และคำนวณพิกัดโลก (World Coordinates) 
    -- โดยสเกลตามขนาดจริงของตัวแปลงแปรง (Brush) เพื่อป้องกันตัวตนคลาดเคลื่อน
    if not Tiles.current_map[gx] then Tiles.current_map[gx] = {} end
    
    local world_x = gx * Tiles.grid_size
    local world_y = gy * Tiles.grid_size
    
    Tiles.current_map[gx][gy] = {
        type = unique_tile_type,
        x = world_x,
        y = world_y,
        width = Tiles.grid_size,
        height = Tiles.grid_size,
        is_3d = false,
        mask = nil,
        draw = function(self, camera)
            -- ส่งขนาดจริงของแปรงเข้าตัวคุมทัศนมิติในระบบวาด (Overload Size)
            Tiles.draw(self.type, self.x, self.y, camera, brush_obj.width * (Tiles.grid_size / brush_obj.width))
        end
    }
end
return Tiles