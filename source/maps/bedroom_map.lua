local bedroom_map = {}
local kaoru = require("source.kaoru")
local Tiles = require("source.libs.tiles_maps")

local bedroomBGM = nil
local current_held_brush = nil
local is_loaded = false local floor_mesh = nil -- ประกาศตัวแปรเก็บโครงสร้าง Mesh ถาวรไว้ด้านบนสุดของไฟล์

function bedroom_map.load()
    if is_loaded then return end

    bedroomBGM = love.audio.newSource("soundtracks/ost/Kaoru_Home.mp3", "stream")
    bedroomBGM:setLooping(true)
    bedroomBGM:setVolume(0.5)
    bedroomBGM:play()
    
    current_held_brush = Tiles.selectTileFromSheet("assets/images/kaoru_home.png", 32, 32, 0, 4)
    local tile_type_name = "bedroom_wood_floor"
    
    for gx = 0, 9 do
        for gy = 0, 9 do
            Tiles.placeTileToMap(gx, gy, tile_type_name, current_held_brush)
        end
    end

    -- 🎯 [สร้าง Mesh สแตนด์บาย]: สร้างจุดหลอกไว้ 4 จุดเพื่อจองพื้นที่ในแรมมือถือ
    local dummy_vertices = {
        {0,0, 0,0}, {0,0, 1,0}, {0,0, 1,1}, {0,0, 0,1}
    }
    floor_mesh = love.graphics.newMesh(dummy_vertices, "fan", "dynamic") -- dynamic คือบอกเครื่องว่าเราจะขอเปลี่ยนพิกัดบ่อย ๆ นะ

    if myCamera then
        myCamera.x = 160 
        myCamera.y = 160
        myCamera:setAngle(45)
        myCamera:setZoom(1.0)
    end

    is_loaded = true
end


function bedroom_map.init()
    bedroom_map.load()
end

function bedroom_map.draw()
    if not is_loaded then bedroom_map.load() end

    -- 1. ล้างจอเป็นสีเพดาน/ผนังด้านหลังก่อน
    love.graphics.clear(0.69, 0.71, 0.73)
    
    local room_width_tiles = 10
    local room_depth_tiles = 10
    local tile_size = 32
    local max_coord = room_width_tiles * tile_size -- 320 พิกัดโลก
    
    -- กำหนดความสูงจริงของกำแพงในโลก 3D
    local wall_h = 160 

    -- =======================================================
    -- [แก้บั๊กดึงค่า Pool]: แกะค่าใส่ตัวแปรดิบทันทีเพื่อกันโดนเขียนทับ
    -- =======================================================
    local cam
    
    -- [พิกัดพื้นห้อง Z = 0]
    cam = myCamera:toScreen(0, 0, 0);                  local f_fl_x, f_fl_y = cam.x, cam.y
    cam = myCamera:toScreen(max_coord, 0, 0);          local f_fr_x, f_fr_y = cam.x, cam.y
    cam = myCamera:toScreen(0, max_coord, 0);          local f_bl_x, f_bl_y = cam.x, cam.y
    cam = myCamera:toScreen(max_coord, max_coord, 0); local f_br_x, f_br_y = cam.x, cam.y

    -- [พิกัดเพดานห้อง Z = wall_h]
    cam = myCamera:toScreen(0, 0, wall_h);                  local c_fl_x, c_fl_y = cam.x, cam.y
    cam = myCamera:toScreen(max_coord, 0, wall_h);          local c_fr_x, c_fr_y = cam.x, cam.y
    cam = myCamera:toScreen(0, max_coord, wall_h);          local c_bl_x, c_bl_y = cam.x, cam.y
    cam = myCamera:toScreen(max_coord, max_coord, wall_h); local c_br_x, c_br_y = cam.x, cam.y

    -- ==========================================
    -- วาดผนังกล่องด้วยพิกัดใหม่ที่ไม่โดนแทรกแซง
    -- ==========================================
    -- ผนังซ้าย
    love.graphics.setColor(0.12, 0.12, 0.15)
    love.graphics.polygon("fill", f_fl_x, f_fl_y, f_bl_x, f_bl_y, c_bl_x, c_bl_y, c_fl_x, c_fl_y)
    
    -- ผนังขวา
    love.graphics.setColor(0.16, 0.16, 0.20)
    love.graphics.polygon("fill", f_fr_x, f_fr_y, f_br_x, f_br_y, c_br_x, c_br_y, c_fr_x, c_fr_y)

    -- ผนังด้านหลัง (ตรงหน้าเรา)
    love.graphics.setColor(0.10, 0.10, 0.12)
    love.graphics.polygon("fill", f_bl_x, f_bl_y, f_br_x, f_br_y, c_br_x, c_br_y, c_bl_x, c_bl_y)

    -- เพดานห้อง
    love.graphics.setColor(0.05, 0.05, 0.07)
    love.graphics.polygon("fill", c_fl_x, c_fl_y, c_fr_x, c_fr_y, c_br_x, c_br_y, c_bl_x, c_bl_y)

    -- =======================================================
    -- 2. วาดระบบสไปรต์พื้นไม้ (ยัดลูปวาดแบบสเกลตื้นลึกแทนตารางสีเทาตัวเก่า)
    -- =======================================================
    -- =======================================================
    -- 2. วาดระบบสไปรต์พื้นไม้บิดมุมนอนราบ (ทำงานร่วมกับ Polygon ของกล้อง โดยไม่กินแรม)
    -- =======================================================
    love.graphics.setColor(1, 1, 1, 1) -- สีขาวเคลียร์เพื่อให้สไปรต์สีตรงสีจริง
    local sprite = Tiles.sprites["bedroom_wood_floor"]

    if sprite and sprite.image and sprite.quad and floor_mesh then
        -- สั่งให้ Mesh ตัวนี้ดึงภาพสไปรต์ชีตของมึงมาแปะสแตนด์บายไว้
        floor_mesh:setTexture(sprite.image)

        -- แกะพิกัด UV (จุดตัดพิกเซลบนสไปรต์ชีต) จาก Quad ของไทล์ไม้
        local qx, qy, qw, qh = sprite.quad:getViewport()
        local iw, ih = sprite.image:getDimensions()
        
        local u1, v1 = qx / iw,       qy / ih
        local u2, v2 = (qx + qw) / iw, qy / ih
        local u3, v3 = (qx + qw) / iw, (qy + qh) / ih
        local u4, v4 = qx / iw,       (qy + qh) / ih

        for tileX = 0, room_width_tiles - 1 do
            for tileY = 0, room_depth_tiles - 1 do
                -- 1. พิกัดโลกจริงตามตรรกะคณิตศาสตร์เดิมของมึง
                local x1, y1 = tileX * tile_size,       (room_depth_tiles - tileY) * tile_size
                local x2, y2 = (tileX + 1) * tile_size, (room_depth_tiles - tileY) * tile_size
                local x3, y3 = (tileX + 1) * tile_size, (room_depth_tiles - (tileY + 1)) * tile_size
                local x4, y4 = tileX * tile_size,       (room_depth_tiles - (tileY + 1)) * tile_size

                -- 2. แปลงพิกัดโลกเข้ากล้อง ดึงค่าดิบจาก Pool ของมึงออกมารวดเดียว 4 มุมหน้าจอ
                local p1 = myCamera:toScreen(x1, y1, 0); local p1x, p1y = p1.x, p1.y
                local p2 = myCamera:toScreen(x2, y2, 0); local p2x, p2y = p2.x, p2.y
                local p3 = myCamera:toScreen(x3, y3, 0); local p3x, p3y = p3.x, p3.y
                local p4 = myCamera:toScreen(x4, y4, 0); local p4x, p4y = p4.x, p4.y

                -- 3. 🎯 ทีเด็ดสายประหยัดแรม: แก้ไขพิกัดในหน่วยความจำ Mesh ชิ้นเดิมตรง ๆ (ไม่สร้างขยะใหม่!)
                floor_mesh:setVertex(1, p1x, p1y, u1, v1)
                floor_mesh:setVertex(2, p2x, p2y, u2, v2)
                floor_mesh:setVertex(3, p3x, p3y, u3, v3)
                floor_mesh:setVertex(4, p4x, p4y, u4, v4)

                -- 4. สั่งวาดตัวแปร Mesh ที่โดนดัดร่างแล้วลงหน้าจอทันที
                love.graphics.draw(floor_mesh)
            end
        end
    else
        -- Fallback ถมสีหมากรุกกันตายดั้งเดิมของมึง (กรณีหาภาพสไปรต์ไม่เจอ)
        for tileX = 0, room_width_tiles - 1 do
            for tileY = 0, room_depth_tiles - 1 do
                if (tileX + tileY) % 2 == 0 then love.graphics.setColor(0.18, 0.18, 0.2) else love.graphics.setColor(0.22, 0.22, 0.24) end
                local x1, y1 = tileX * tile_size,       (room_depth_tiles - tileY) * tile_size
                local x2, y2 = (tileX + 1) * tile_size, (room_depth_tiles - tileY) * tile_size
                local x3, y3 = (tileX + 1) * tile_size, (room_depth_tiles - (tileY + 1)) * tile_size
                local x4, y4 = tileX * tile_size,       (room_depth_tiles - (tileY + 1)) * tile_size
                
                local p1 = myCamera:toScreen(x1, y1, 0); local p1x, p1y = p1.x, p1.y
                local p2 = myCamera:toScreen(x2, y2, 0); local p2x, p2y = p2.x, p2.y
                local p3 = myCamera:toScreen(x3, y3, 0); local p3x, p3y = p3.x, p3.y
                local p4 = myCamera:toScreen(x4, y4, 0); local p4x, p4y = p4.x, p4.y
                
                love.graphics.polygon("fill", p1x, p1y, p2x, p2y, p3x, p3y, p4x, p4y)
            end
        end
    end

    -- ==========================================
    -- 4. วาดตัวละครคาโอรุ
    -- ==========================================
    love.graphics.setColor(1, 1, 1, 1)
    if kaoru and kaoru.draw then
        kaoru:draw(myCamera)
    end

    -- DEBUG TEXT
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("SCENE: KAORU'S BEDROOM", 10, 10)
    love.graphics.print("Kaoru X: " .. (kaoru and math.floor(kaoru.x) or 0) .. " Y: " .. (kaoru and math.floor(kaoru.y) or 0), 10, 30)
    love.graphics.print("Cam X: " .. math.floor(myCamera.x) .. " Y: " .. math.floor(myCamera.y), 10, 50)
end

return bedroom_map