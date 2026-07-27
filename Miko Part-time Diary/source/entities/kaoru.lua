-- source/kaoru.lua
local anim8 = require("source.libs.anim8") 
local Vector = require("source.libs.vector") -- [ดึงไลบรารีเวกเตอร์มาใช้]

local kaoru = {
    x = 64,
    y = 160,
    width = 32,
    height = 32,
    speed = 1, 
    
    -- ตัวแปรตำแหน่งในรูปแบบเวกเตอร์ (Zero-Allocation)
    pos = Vector.new2D(64, 160),
    
    -- [กำหนดขอบเขตชนจริงบริเวณเท้า] (เพื่อให้หัวตัวละครเยื้องทับกำแพงด้านหลังได้)
    collider = {
        x_offset = 8,   -- ขยับมาตรงกลางตัวละคร
        y_offset = 8,  -- ขยับลงมาที่เท้า
        width = 16,     -- ความกว้างกล่องชน
        height = 12     -- ความสูงกล่องชน
    },

    direction = "down",     
    is_moving = false,      
    
    sheet = nil,
    grid = nil,
    animations = {},

    -- เก็บ Reference ของ status_menu ไว้ในตัวละครเลย ไม่ต้องไปยุ่งกับ main
    status_menu = nil
}

function kaoru:load()
    self.sheet = love.graphics.newImage("assets/character_playable/kaoru_sheet.png")
    self.grid = anim8.newGrid(32, 32, self.sheet:getWidth(), self.sheet:getHeight())
    
    self.animations = {
        ["idle_down"]  = anim8.newAnimation(self.grid(1, 1), 1),
        ["idle_up"]    = anim8.newAnimation(self.grid(3, 1), 1),
        ["idle_left"]  = anim8.newAnimation(self.grid(4, 1), 1),
        ["idle_right"] = anim8.newAnimation(self.grid(2, 1), 1),

        ["walk_down"]  = anim8.newAnimation(self.grid(1, '1-4'), 0.10),
        ["walk_up"]    = anim8.newAnimation(self.grid(3, '1-4'), 0.10),
        ["walk_left"]  = anim8.newAnimation(self.grid(4, '1-4'), 0.10),
        ["walk_right"] = anim8.newAnimation(self.grid(2, '1-4'), 0.10)
    }

    -- โหลด Status Menu เข้ามาตรงนี้ที่เดียวจบ!
    self.status_menu = require("source.status_menu")
end

-- map_data: ส่งข้อมูลแอปพลิเคชันแผนที่เข้ามาคำนวณการชน
function kaoru:update(dt, map_data)
    -- 1. อัปเดตระบบเมนูสเตตัส (เช็คกดปุ่มสไลด์ เปิด-ปิด เมนู)
    if self.status_menu then
        self.status_menu.update(dt)
    end

    -- 2. ถ้าเปิดเมนูอยู่ ให้ล็อกตัวละครไม่ให้เดินกระดุกกระดิก (ฟีลแบบหยุดเกมชั่วคราว)
    -- ถ้ามึงอยากให้สไลด์เมนูลงมาแล้วยังเดินได้อยู่ ก็ลบคอนดิชัน if นี้ออกได้เลย
    if self.status_menu and self.status_menu.isOpen then
        self.is_moving = false
        local anim_key = "idle_" .. self.direction
        if self.animations[anim_key] then
            self.animations[anim_key]:update(dt)
        end
        return -- จบลูป update ตรงนี้ ไม่ต้องรับ Input การเดิน
    end

    -- ดึงค่า X, Y ล่าสุดที่อาจถูกเปลี่ยนจากภายนอก (เช่น ตอน Spawn) มาเข้าเวกเตอร์
    self.pos.x = self.x
    self.pos.y = self.y

    self:handleInput(dt)
    
    -- ตรวจจับและแก้ไขพิกัดการชน (Collision Resolution)
    if map_data then
        self:resolveCollisions(map_data)
    end

    -- บันทึกพิกัดเวกเตอร์กลับไปเป็นค่า x, y ดั้งเดิมของตัวละคร
    self.x = self.pos.x
    self.y = self.pos.y

    local anim_key = (self.is_moving and "walk_" or "idle_") .. self.direction
    if self.animations[anim_key] then
        self.animations[anim_key]:update(dt)
    else
        local fallback_key = "idle_" .. self.direction
        if self.animations[fallback_key] then
            self.animations[fallback_key]:gotoFrame(1)
        end
    end
end

function kaoru:handleInput(dt)
    self.is_moving = false
    
    -- ดึง Pool สำรองจากระบบเวกเตอร์เพื่อลด GC ในลูปอัปเดต
    local pool = Vector.getPool()
    local move_vec = pool.temp2_A
    move_vec.x = 0
    move_vec.y = 0
    
    -- 1. รับค่าปุ่มกด
    if love.keyboard.isDown("left")  then move_vec.x = -1 end
    if love.keyboard.isDown("right") then move_vec.x = 1  end
    if love.keyboard.isDown("up")    then move_vec.y = -1 end
    if love.keyboard.isDown("down")  then move_vec.y = 1  end
    
    -- 2. ดึงค่าจากคอนโทรลเลอร์อนาล็อก
    if type(controller) == "table" and controller.getAxis then
        local joy_x, joy_y = controller.getAxis()
        if math.abs(joy_x) > 0.1 or math.abs(joy_y) > 0.1 then
            move_vec.x = joy_x
            move_vec.y = joy_y
        end
    end
    
    -- คำนวณการเคลื่อนที่เมื่อมีการรับค่าปุ่ม
    local move_len = Vector.length2D(move_vec)
    if move_len > 0.1 then
        self.is_moving = true
        
        -- ปรับอนิเมชันตามน้ำหนักแกนที่เคลื่อนไหวหลัก
        if math.abs(move_vec.x) > math.abs(move_vec.y) then
            if move_vec.x < 0 then self.direction = "left" else self.direction = "right" end
        else
            if move_vec.y < 0 then self.direction = "up" else self.direction = "down" end
        end
        
        -- Normalize เวกเตอร์การเคลื่อนที่เพื่อป้องกันการเดินทแยงแล้วเร็วเกินไป
        Vector.normalize2D(move_vec, move_vec)
        
        -- ดึงเวกเตอร์ผลลัพธ์มาคำนวณทิศทางการเคลื่อนที่ตามเวลา (Zero-Allocation)
        local speed_vec = pool.temp2_B
        local current_speed = self.speed * 80 
        speed_vec.x = move_vec.x * current_speed * dt
        speed_vec.y = move_vec.y * current_speed * dt
        
        -- บวกตำแหน่งเวกเตอร์ใหม่
        Vector.add2D(self.pos, speed_vec, self.pos)
    end
end

-- ฟังก์ชันจัดการการชนขอบแผนที่และชนสิ่งกีดขวาง
function kaoru:resolveCollisions(map)
    local col = self.collider
    local pos = self.pos

    -- 1. ป้องกันหลุดขอบแผนที่ (Map Boundaries)
    local map_w = (map.MAP_WIDTH or 160) + 500  
    local map_h = (map.MAP_HEIGHT or 160) + 500

    local min_x = -500 
    local max_x = map_w - col.x_offset - col.width
    local min_y = -500
    local max_y = map_h - col.y_offset - col.height

    if pos.x < min_x then pos.x = min_x end
    if pos.x > max_x then pos.x = max_x end
    if pos.y < min_y then pos.y = min_y end
    if pos.y > max_y then pos.y = max_y end

    -- 2. ตรวจสอบการชนกับกล่องสิ่งกีดขวาง (Obstacles) ในห้องนอน
    local obstacles = map.colliders
    if not obstacles then return end

    for i = 1, #obstacles do
        local wall = obstacles[i]
        
        -- พิกัดกล่องชนของคาโอรุ
        local p_left = pos.x + col.x_offset
        local p_right = p_left + col.width
        local p_top = pos.y + col.y_offset
        local p_bottom = p_top + col.height

        -- พิกัดกล่องชนของสิ่งกีดขวาง
        local w_left = wall.x
        local w_right = wall.x + wall.width
        local w_top = wall.y
        local w_bottom = wall.y + wall.height

        -- ตรวจสอบการซ้อนทับ (AABB Overlap)
        if p_right > w_left and p_left < w_right and p_bottom > w_top and p_top < w_bottom then
            local overlap_x = 0
            local overlap_y = 0

            if (p_left + p_right) / 2 < (w_left + w_right) / 2 then
                overlap_x = p_right - w_left 
            else
                overlap_x = p_left - w_right 
            end

            if (p_top + p_bottom) / 2 < (w_top + w_bottom) / 2 then
                overlap_y = p_bottom - w_top 
            else
                overlap_y = p_top - w_bottom 
            end

            if math.abs(overlap_x) < math.abs(overlap_y) then
                pos.x = pos.x - overlap_x
            else
                pos.y = pos.y - overlap_y
            end
        end
    end
end

-- รับค่า virtualWidth, virtualHeight เพิ่มเติมมาเพื่อนำไปใช้วาดเมนู
function kaoru:draw(camera_obj, virtualWidth, virtualHeight)
    local anim_key = (self.is_moving and "walk_" or "idle_") .. self.direction
    
    local draw_x = self.x
    local draw_y = self.y 
    local current_scale = 1.0
    
    if camera_obj and camera_obj.toScreen then
        local screen_pos = camera_obj:toScreen(self.x, self.y, self.z or 0)
        draw_x = screen_pos.x
        draw_y = screen_pos.y
        current_scale = screen_pos.scale or 1.0
    end
    
    if self.animations[anim_key] then
        self.animations[anim_key]:draw(self.sheet, draw_x, draw_y, 0, current_scale, current_scale)
    end

    -- [สายพัฒนาเกม] เส้นแสดงขอบเขตกล่องชนสีเขียว
    love.graphics.setColor(0, 1, 0, 0.5)
    --love.graphics.rectangle("line", draw_x + self.collider.x_offset * current_scale, draw_y + self.collider.y_offset * current_scale, self.collider.width * current_scale, self.collider.height * current_scale)

    -- วาดสเตตัสเมนูทับเลเยอร์ตัวละคร เพื่อให้อยู่ด้านบนสุดเสมอ
    -- ส่งค่าขนาดหน้าจอเสมือนจริง (ค่า Default คือ 320x320 ตามสเปคของมึง)
    if self.status_menu then
        self.status_menu.draw(virtualWidth or 320, virtualHeight or 320)
    end
end

return kaoru