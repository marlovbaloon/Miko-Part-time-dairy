-- source/kaoru.lua
local anim8 = require("source.libs.anim8") -- ดึงไลบรารีจัดการอนิเมชันมาใช้

local kaoru = {
    x = 64,
    y = 160,
    width = 32,
    height = 32,
    speed = 1, -- ความเร็วในการเดิน
    
    -- ตัวแปรทิศทางและเช็กการขยับ (Zelda GBA Style)
    direction = "down",     -- "up", "down", "left", "right"
    is_moving = false,      -- เฟรมนี้ขยับอยู่หรือไม่
    
    -- ตัวแปรเก็บแผ่นสไปรตและตารางอนิเมชัน
    sheet = nil,
    grid = nil,
    animations = {}
}

function kaoru:load()
    -- 1. โหลดรูปแผ่นสไปรตใหญ่ของคาโอรุ
    self.sheet = love.graphics.newImage("assets/character_playable/kaoru_sheet.png")
    
    -- 2. ตั้งค่า Grid บล็อกละ 32x32 พิกเซล ตามสเกลเกม GBA/NDS
    self.grid = anim8.newGrid(32, 32, self.sheet:getWidth(), self.sheet:getHeight())
    
-- 3. มัดรวมเฟรมอนิเมชัน [แก้ไข]: เปลี่ยนจากนับตามแถว (แนวนอน) เป็นนับตามคอลัมน์ (แนวตั้ง)
    self.animations = {
        -- ท่ายืนนิ่ง (Idle): ดึงจาก แถวที่ 1 (ตัวหลังคือ 1) ของแต่ละคอลัมน์
        ["idle_down"]  = anim8.newAnimation(self.grid(1, 1), 1), -- คอลัมน์ 1, แถว 1
        ["idle_up"]    = anim8.newAnimation(self.grid(3, 1), 1), -- คอลัมน์ 2, แถว 1
        ["idle_left"]  = anim8.newAnimation(self.grid(4, 1), 1), -- คอลัมน์ 3, แถว 1
        ["idle_right"] = anim8.newAnimation(self.grid(2, 1), 1), -- คอลัมน์ 4, แถว 1

        -- ท่าเดิน (Walk): ล็อกคอลัมน์ไว้ (ตัวหน้า) แล้วให้เฟรมวิ่งสับลงมาในแนวตั้ง แถวที่ 1 ถึง 4 (ตัวหลังคือ '1-4')
        ["walk_down"]  = anim8.newAnimation(self.grid(1, '1-4'), 0.10), -- คอลัมน์ 1, แถว 1 ถึง 4
        ["walk_up"]    = anim8.newAnimation(self.grid(3, '1-4'), 0.10), -- คอลัมน์ 2, แถว 1 ถึง 4
        ["walk_left"]  = anim8.newAnimation(self.grid(4, '1-4'), 0.10), -- คอลัมน์ 3, แถว 1 ถึง 4
        ["walk_right"] = anim8.newAnimation(self.grid(2, '1-4'), 0.10)  -- คอลัมน์ 4, แถว 1 ถึง 4
    }
    
end

function kaoru:update(dt)
    self:handleInput(dt)
    
    local anim_key = (self.is_moving and "walk_" or "idle_") .. self.direction
    
    -- ตรวจสอบให้มั่นใจว่ามีคีย์นี้อยู่ในระบบอนิเมชันที่เราประกาศไว้จริงไหม
    if self.animations[anim_key] then
        self.animations[anim_key]:update(dt)
    else
        -- ถ้าไม่เจอคีย์ (ป้องกันบั๊กคีย์หลุด) ให้ถอยกลับไปท่า Idle ทิศทางล่าสุดแทนการสั่งดึงเฟรมดื้อๆ
        local fallback_key = "idle_" .. self.direction
        if self.animations[fallback_key] then
            self.animations[fallback_key]:gotoFrame(1)
        end
    end
end

function kaoru:handleInput(dt)
    self.is_moving = false
    
    local move_x = 0
    local move_y = 0
    
    -- 1. ดึงค่าจากระบบ คีย์บอร์ดคอมพิวเตอร์ (สำหรับ Test บน PC)
    if love.keyboard.isDown("left")  then move_x = -1 end
    if love.keyboard.isDown("right") then move_x = 1  end
    if love.keyboard.isDown("up")    then move_y = -1 end
    if love.keyboard.isDown("down")  then move_y = 1  end
    
    -- 2. [จุดแก้มหาบั๊ก] ดึงค่าจากอนาล็อกจอยสติ๊กล่องหน (ถ้ามี)
    if type(controller) == "table" and controller.getAxis then
        local joy_x, joy_y = controller.getAxis()
        -- ถ้ามีการโยกอนาล็อกจริง (ค่าไม่เป็น 0) ให้เอาค่าจอยมาทับค่าคีย์บอร์ดเลย
        if math.abs(joy_x) > 0.1 or math.abs(joy_y) > 0.1 then
            move_x = joy_x
            move_y = joy_y
        end
    end
    
    -- 3. คำนวณทิศทางอนิเมชันสี่ทิศ (Up, Down, Left, Right) อิงจากน้ำหนักเวกเตอร์ที่โยกไป
    if math.abs(move_x) > 0.1 or math.abs(move_y) > 0.1 then
        self.is_moving = true
        
        -- ดูว่าเอียงไปทางแกนไหนมากกว่ากัน เพื่อหันหน้าอนิเมชันให้ถูกทิศ
        if math.abs(move_x) > math.abs(move_y) then
            if move_x < 0 then self.direction = "left" else self.direction = "right" end
        else
            if move_y < 0 then self.direction = "up" else self.direction = "down" end
        end
        
        -- 4. Normalize เวกเตอร์ป้องกันการเดินเฉลียงแล้วความเร็วทะลุหลอด
        local length = math.sqrt(move_x * move_x + move_y * move_y)
        if length > 0 then
            move_x = move_x / length
            move_y = move_y / length
        end
        
        -- สปีดความเร็วตัวละคร (คูณค่าความแรงตามการโยก)
        local current_speed = self.speed * 80 
        self.x = self.x + (move_x * current_speed * dt)
        self.y = self.y + (move_y * current_speed * dt)
    end
end

function kaoru:draw(camera_obj)
    local anim_key = (self.is_moving and "walk_" or "idle_") .. self.direction
    
    local draw_x = self.x
    local draw_y = self.y 
    local current_scale = 1.0
    
    if camera_obj and camera_obj.toScreen then
        local screen_pos = camera_obj:toScreen(self.x, self.y, self.z or 0)
        
        -- [จุดตัดบั๊กแบน]: บังคับดึงค่าแตกย่อยออกมาเป็นตัวเลขตรงๆ (Primitive Value) ไม่ดึงมาเป็นตารางอ้างอิง
        draw_x = screen_pos.x
        draw_y = screen_pos.y
        current_scale = screen_pos.scale or 1.0
    end
    
    if self.animations[anim_key] then
        self.animations[anim_key]:draw(self.sheet, draw_x, draw_y, 0, current_scale, current_scale)
    end
end

return kaoru