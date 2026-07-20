-- camera.lua (2D Top-Down)
-- กล้อง 2D แบบมองดิ่งตรงๆ จากด้านบน + ระบบซูมสำหรับผู้พัฒนา
-- คง interface เดิมไว้ทั้งหมด ไฟล์อื่นเรียกใช้งานได้ทันทีไม่พังแน่นอน

local Camera = {}
Camera.__index = Camera

function Camera.new(screen_w, screen_h)
    return setmetatable({
        x = 0,
        y = 0,
        screen_width  = screen_w or 320,
        screen_height = screen_h or 320,
        lerp_speed    = 3,
        -- =======================================================
        -- [🎯 DEV CONF]: ปรับระยะซูมเริ่มต้นตรงนี้ได้เลยสุมึง!
        -- 1.0 = ปกติ | 2.0 = ซูมเข้าขยายใหญ่ 2 เท่า | 0.5 = ซูมออกมุมมองกว้างขึ้น
        -- =======================================================
        zoom          = 1.0, 
    }, Camera)
end

-- ลากกล้องตามเป้าหมายแบบ Lerp (เหมือนเดิม)
function Camera:follow(target_x, target_y, dt)
    self.x = self.x + (target_x - self.x) * self.lerp_speed * dt
    self.y = self.y + (target_y - self.y) * self.lerp_speed * dt
end

-- แปลงพิกัดโลก → พิกัดหน้าจอ 2D (คิดคำนวณสเกลซูมจากจุดศูนย์กลางจอ)
function Camera:toScreen(world_x, world_y, world_z)
    local cx = self.screen_width  / 2
    local cy = self.screen_height / 2

    -- คำนวณระยะห่างดิบจากกล้อง แล้วคูณด้วยแรงซูม ก่อนตบเข้าจุดกึ่งกลางหน้าจอ
    local screen_x = (world_x - self.x) * self.zoom + cx
    local screen_y = (world_y - self.y) * self.zoom + cy

    return {
        x     = screen_x,
        y     = screen_y,
        scale = self.zoom -- ส่งค่าซูมกลับไปให้พวกฟังก์ชันวาดรูปเอาไปคูณสเกลภาพให้ใหญ่ตาม
    }
end

-- เช็คขอบเขตหน้าจอ (Frustum Culling) ปรับตามขนาดวัตถุที่โดนซูมจริง
function Camera:isBoundsIn(world_x, world_y, width, height)
    local p = self:toScreen(world_x, world_y)
    -- ขยายขนาดชนตามแรงซูมของกล้องเพื่อให้การตัดขอบจอยังแม่นยำ ของไม่หายวาบขอบจอ
    local scaled_w = width * self.zoom
    local scaled_h = height * self.zoom

    return p.x + scaled_w  >= 0 and
           p.x - scaled_w  <= self.screen_width and
           p.y + height >= 0 and  -- แก้ไขกันภาพหลุดขอบบน-ล่าง
           p.y - scaled_h  <= self.screen_height
end

-- เปิดใช้งานให้ผู้พัฒนาสั่งเปลี่ยนระดับซูมผ่านโค้ดในไฟล์อื่นได้สะดวก ๆ
function Camera:setZoom(scale)
    self.zoom = scale or 1.0
end

-- No-op: คงไว้เผื่อมีโค้ดเก่าเรียกใช้ ไม่ให้ error
function Camera:setAngle(degrees) end
function Camera:updateMatrix()    end

return Camera