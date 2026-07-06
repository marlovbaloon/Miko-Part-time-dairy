-- camera.lua

local Vector = require("source.libs.vector")
local Camera = {}
Camera.__index = Camera

-- ดึง Pool หน่วยความจำถาวรมาจากระบบเวกเตอร์เพื่อใช้ส่งพิกัดออกหน้าจอ
local math_pool = Vector.getPool()
-- เพิ่มช่องสแตนด์บายพิกัดหน้าจอใน Pool เพื่อไม่ให้สร้างตารางใหม่ตอนคำนวณ
math_pool.screen_out = { x = 0, y = 0 }

function Camera.new(screen_w, screen_h)
    local instance = setmetatable({
        -- พิกัดโลกจริง 3 มิติของกล้อง (ตำแหน่งกึ่งกลางหน้าจอ)
        x = 0,
        y = 0,
        z = 0,
        
        -- มิติการแสดงผลของหน้าต่างเกม
        screen_width = screen_w or 800,
        screen_height = screen_h or 600,
        
        -- พารามิเตอร์มุมกล้อง
        theta = 0,       -- องศากล้องแนวเซต้า (0 = Top-down มองดิ่ง, 90 = Front มองตรงหน้า)
        zoom = 1.0,      -- อัตราการขยายเข้า-ออก (Zoom In / Out)
        
        -- ระบบ Follower ตัวดึงตามนุ่มนวล (Lerp)
        lerp_speed = 3,  -- ความเร็วในการเลื่อนตามวัตถุ (ยิ่งมากยิ่งไว)
        
        -- ตัวแปรแคชตรีโกณมิติ (Matrix Cache) เพื่อประหยัด CPU ไม่ต้องคำนวณใหม่ทุกเฟรม
        cos_t = 1.0,
        sin_t = 0.0
    }, Camera)
    
    -- คำนวณแคชรอบแรกสุดตอนสร้างตัวกล้อง
    instance:updateMatrix()
    return instance
end

-- [INTERNAL PERFORMANCE]: ฟังก์ชันอัปเดตแคชตรีโกณมิติ 
-- จะถูกเรียกทำงานเฉพาะตอนที่ผู้เล่นมีการหมุนปรับองศาเซต้าเท่านั้น
function Camera:updateMatrix()
    -- แปลงหน่วยองศาเป็นเรเดียนเพื่อป้อนให้คณิตศาสตร์ของเครื่องคอมพิวเตอร์
    local rad = math.rad(self.theta)
    self.cos_t = math.cos(rad)
    self.sin_t = math.sin(rad)
end

-- ฟังก์ชันปรับเปลี่ยนองศามุมกล้องเซต้า (Y-Axis Angle)
function Camera:setAngle(degrees)
    -- ล็อคองศากล้องไม่ให้หลุดเกินขอบเขตทางฟิสิกส์ (0 ถึง 90 องศา)
    local target_angle = math.max(0, math.min(90, degrees))
    if self.theta ~= target_angle then
        self.theta = target_angle
        self:updateMatrix() -- คำนวณแคชตัวแปรใหม่ทันทีเมื่อองศาเปลี่ยน
    end
end

-- ฟังก์ชันปรับระยะซูมภาพ (Zoom Factor)
function Camera:setZoom(scale)
    self.zoom = math.max(0.1, scale) -- ล็อคไม่ให้ซูมจนภาพกลับด้าน
end

-- 🎯 [CAMERA FOLLOWER]: ฟังก์ชันลากกล้องตามเป้าหมายแบบนุ่มนวล
-- target_x, target_y: พิกัดโลกของตัวละครที่กล้องต้องวิ่งไปหา
-- dt: เวลา Delta Time เพื่อให้ความสมูทเท่ากันทุกสเปคคอมพิวเตอร์
function Camera:follow(target_x, target_y, dt)
    -- ใช้ตรรกะคณิตศาสตร์ Linear Interpolation (Lerp) คำนวณระยะเคลื่อนแปรผันตามระยะทาง
    self.x = self.x + (target_x - self.x) * self.lerp_speed * dt
    self.y = self.y + (target_y - self.y) * self.lerp_speed * dt
end

-- 📐 [PROJECTION LAYER]: ฟังก์ชันแปลงพิกัดโลก 3 มิติ เป็นพิกัดหน้าจอ 2 มิติ
-- ฟังก์ชันนี้จะดึงค่าจาก Cache มาคำนวณทแยงมุม บีบแกน Y และดึงแกน Z ขึ้นมาเป็น Billboard 3D
-- ส่งผลลัพธ์ผ่าน Static Pool ไร้ขยะขัดขวางแรม  100%
math_pool.screen_out = {x = 0,y = 0, scale = 1.0}

-- ปรับให้สเกลความลึกคุมทั้งระนาบพื้นและความสูงวัตถุ
function Camera:toScreen(world_x, world_y, world_z)
    local wz = world_z or 0

    -- 1. ระยะห่างดิบในโลกเกม (เทียบกับตำแหน่งกล้อง)
    local dx = world_x - self.x
    local dy = world_y - self.y

    -- 2. สมการทอนสเกลตามระยะลึก
    local depth_base = 250
    local perspective_scale = depth_base / (depth_base - dy)

    if perspective_scale < 0.1 then perspective_scale = 0.1 end
    if perspective_scale > 3.0 then perspective_scale = 3.0 end
    local depth_base = 250
    
    -- [แก้ไข]: ป้องกันตัวหารเป็นศูนย์หรือติดลบ (Near-Plane Clipping)
    -- ล็อกตัวหารไม่ให้ต่ำกว่า 50 พิกเซลเด็ดขาด ภาพจะได้ไม่ระเบิดเวลาวิ่งไปสุดขอบ
    local divisor = depth_base - dy
    if divisor < 50 then divisor = 50 end
    
    local perspective_scale = depth_base / divisor

    -- ป้องกันค่าสเกลโดยรวมหลุดขอบ
    if perspective_scale < 0.1 then perspective_scale = 0.1 end
    if perspective_scale > 3.0 then perspective_scale = 3.0 end
    -- 3. คำนวณพิกัดหน้าจอจริง
    local center_x = self.screen_width / 2
    local center_y = self.screen_height / 2

    -- แกน X หน้าจอ: หดเข้าศูนย์กลางตามระยะลึก
    local screen_x = center_x + (dx * self.zoom * perspective_scale)
    
    -- แกน Y หน้าจอ: [แก้ไข] เอา perspective_scale มาคูณควบพจน์ความสูง wz ด้านหลังด้วย!
    -- เพื่อให้ยอดกำแพงหรือหัวตัวละคร หดเล็กลงตามระยะทางลึก-ตื้นสอดคล้องกับพื้นล่าง
    local screen_y = center_y + (dy * self.cos_t * self.zoom * perspective_scale) - (wz * self.sin_t * self.zoom * perspective_scale)

    -- 4. ส่งค่ากลับผ่าน Static Pool
    local out = math_pool.screen_out
    out.x = screen_x
    out.y = screen_y
    out.scale = perspective_scale * self.zoom
    
    return out
end
-- 👁️ [FRUSTUM CULLING]: ฟังก์ชันเช็คว่าขอบเขตวัตถุหลุดนอกจอหรือไม่
-- ช่วยกั้นไม่ให้การ์ดจอต้องแบกภาระเรนเดอร์สิ่งของที่อยู่ข้างหลังหรือนอกระยะมองเห็น
function Camera:isBoundsIn(world_x, world_y, width, height, world_z)
    local pos = self:toScreen(world_x, world_y, world_z)
    
    -- เช็คระยะขอบเขตกล่องปะทะกับพิกัดหน้าจอเกมจริง
    return pos.x + width >= 0 and
           pos.x - width <= self.screen_width and
           pos.y + height >= 0 and
           pos.y - height <= self.screen_height
end

return Camera