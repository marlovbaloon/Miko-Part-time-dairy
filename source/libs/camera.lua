-- camera.lua (2D Top-Down)
-- กล้อง 2D แบบมองดิ่งตรงๆ จากด้านบน
-- คง interface เดิม (toScreen, follow, isBoundsIn) ไว้เพื่อให้ไฟล์อื่นทำงานได้โดยไม่ต้องแก้

local Camera = {}
Camera.__index = Camera

function Camera.new(screen_w, screen_h)
    return setmetatable({
        x = 0,
        y = 0,
        screen_width  = screen_w or 320,
        screen_height = screen_h or 320,
        lerp_speed    = 3,
    }, Camera)
end

-- ลากกล้องตามเป้าหมายแบบ Lerp (เหมือนเดิม)
function Camera:follow(target_x, target_y, dt)
    self.x = self.x + (target_x - self.x) * self.lerp_speed * dt
    self.y = self.y + (target_y - self.y) * self.lerp_speed * dt
end

-- แปลงพิกัดโลก → พิกัดหน้าจอ 2D (world_z ไม่ใช้แล้ว รับไว้เพื่อ compatibility)
-- ส่งคืน table {x, y, scale} เหมือนเดิมเพื่อไม่ให้โค้ดที่เรียกใช้พัง
function Camera:toScreen(world_x, world_y, world_z)
    local cx = self.screen_width  / 2
    local cy = self.screen_height / 2
    return {
        x     = world_x - self.x + cx,
        y     = world_y - self.y + cy,
        scale = 1.0
    }
end

-- เช็คว่าวัตถุอยู่ในขอบหน้าจอหรือไม่ (Frustum Culling แบบ 2D)
function Camera:isBoundsIn(world_x, world_y, width, height)
    local p = self:toScreen(world_x, world_y)
    return p.x + width  >= 0 and
           p.x - width  <= self.screen_width and
           p.y + height >= 0 and
           p.y - height <= self.screen_height
end

-- No-op: คงไว้เผื่อมีโค้ดเก่าเรียกใช้ ไม่ให้ error
function Camera:setAngle(degrees) end
function Camera:setZoom(scale)    end
function Camera:updateMatrix()    end

return Camera
