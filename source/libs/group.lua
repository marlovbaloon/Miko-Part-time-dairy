-- group.lua
-- ไลบรารีจัดการกลุ่มเอนทิตี (Entity Group Manager)
-- ควบคุมการไหลของลูป อัปเดตตรรกะ และจัดเรียงลำดับเลเยอร์ภาพตื้นลึก (Y-Sorting)

local Group = {}
Group.__index = Group

-- สร้างกลุ่มขึ้นมาใหม่ (เก็บโครงสร้างตารางข้อมูลเอนทิตี)
function Group.new()
    local instance = setmetatable({
        entities = {},       -- ตารางหลักเก็บวัตถุทั้งหมดในกลุ่มนี้
        count = 0           -- ตัวนับจำนวนวัตถุ เพื่อเลี่ยงการใช้เครื่องหมาย # ค้นหาความยาวตาราง
    }, Group)
    return instance
end

-- เพิ่มวัตถุเข้ามาในระบบควบคุมดูแล
function Group:add(entity)
    if not entity then return end
    self.count = self.count + 1
    self.entities[self.count] = entity
end

-- ลอจิกการเคลียร์กลุ่มให้ว่างเปล่า โดยไม่ทำลายโครงสร้างตาราง (ป้องกันขยะในแรม)
function Group:clear()
    for i = 1, self.count do
        self.entities[i] = nil
    end
    self.count = 0
end

-- ลอจิกการสั่งอัปเดตสถานะเอนทิตีทั้งหมดในกลุ่มพร้อมกันในบรรทัดเดียว
-- dt: Delta Time เวลาที่ต่างกันระหว่างเฟรม
function Group:update(dt)
    for i = 1, self.count do
        local ent = self.entities[i]
        -- ตรวจสอบว่าวัตถุมีฟังก์ชันอัปเดตตรรกะของตัวเองหรือไม่
        if ent and ent.update then
            ent:update(dt)
        end
    end
end

-- ตรรกะเปรียบเทียบความลึกกายภาพ (ฟังก์ชันเสริมภายในสำหรับระบบจัดเรียงลำดับ)
-- วัตถุประสงค์: วัตถุที่ค่า y น้อย (อยู่ด้านบนของจอ/อยู่ลึกเข้าไปในฉาก) ต้องถูกวาดก่อนวัตถุที่ค่า y มาก
local function sortByDepth(a, b)
    return (a.y or 0) < (b.y or 0)
end

-- ลอจิกการเรนเดอร์ภาพลงหน้าจอ (Draw Call Manager) พร้อมจัดระเบียบมิติลึก
-- camera: อ็อบเจกต์กล้อง เพื่อนำมาเช็คขอบเขตการมองเห็น (Frustum Culling)
function Group:draw(camera)
    -- ขั้นตอนที่ 1: จัดเรียงลำดับแถววัตถุตามพิกเซลแกน Y ดึงลอจิกความลึกจากหลังมาหน้า
    -- ทำให้ตัวละคร 3D Billboard สามารถเดินอ้อมหลังต้นไม้ หรือบังกำแพงได้อย่างสมเหตุสมผล
    table.sort(self.entities, sortByDepth)

    -- ขั้นตอนที่ 2: วิ่งลูปวาดภาพวัตถุที่ผ่านการเรียงมิติแล้ว
    for i = 1, self.count do
        local ent = self.entities[i]
        if ent and ent.draw then
            -- ตรรกะ Frustum Culling (คัดกรองขอบเขตสายตา):
            -- ถ้าระบบกล้องระบุว่าวัตถุนี้อยู่นอกพื้นที่หน้าจอ มือถือจะไม่ต้องแบกรับภาระส่งข้อมูลไปการ์ดจอ
            local in_view = true
            if camera and camera.isBoundsIn and ent.x and ent.y then
                in_view = camera:isBoundsIn(ent.x, ent.y, ent.width or 32, ent.height or 32)
            end

            -- ส่งคำสั่งลงชั้นฮาร์ดแวร์เพื่อพ่นพิกเซลสีลงจอ เฉพาะวัตถุที่อยู่ในสายตาเท่านั้น
            if in_view then
                ent:draw()
            end
        end
    end
end

return Group