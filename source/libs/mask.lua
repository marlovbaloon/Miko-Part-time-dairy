-- mask.lua
-- ไลบรารีเช็คหน้าสัมผัสวัตถุระดับพิกเซล (Bitmask Collision Detection)
-- ออกแบบมาเพื่อวัตถุรูปทรงเฉียง โค้ง หรือสิ่งปลูกสร้างรูปทรงประหลาดในแผนที่ 3D

local Mask = {}
Mask.__index = Mask

-- ฟังก์ชันสร้างตาราง Bitmask จากข้อมูลภาพดิบ (สร้างครั้งเดียวตอนโหลดด่าน)
-- imageData: ข้อมูลพิกเซลสีของ LÖVE2D (love.image.newImageData)
-- alpha_threshold: ค่าความโปร่งแสงที่จะให้กั้นการชน (ช่วง 0 ถึง 1, เช่น 0.5 คือกึ่งโปร่งแสง)
function Mask.new(imageData, alpha_threshold)
    local width = imageData:getWidth()
    local height = imageData:getHeight()
    local threshold = alpha_threshold or 0.1

    -- สร้างโครงสร้างที่จัดเก็บแบบแบนราบ (1D Table) เพื่อให้ CPU วิ่งอ่านค่าได้เร็วที่สุด
    local bits = {}

    -- วิ่งแกะพิกเซลรูปภาพแนวตั้งและแนวนอน
    for y = 0, height - 1 do
        for x = 0, width - 1 do
            -- ดึงข้อมูลสีพิกเซลตรงพิกัดนั้น (ดึงเฉพาะค่า Alpha หรือความโปร่งใส)
            local _, _, _, a = imageData:getPixel(x, y)
            
            -- ดัชนีตำแหน่งหน่วยความจำแบบแบน
            local index = y * width + x + 1
            
            -- ตรรกะแปลงสถานะพิกเซล:
            -- ถ้าพิกเซลสีตรงนั้นมีความทึบแสงเกินเกณฑ์ = เป็นเนื้อวัตถุ (1) ชนได้
            -- ถ้าโปร่งแสงหรือว่างเปล่า = ช่องว่าง (0) ตัวละครเดินผ่านได้
            if a >= threshold then
                bits[index] = 1
            else
                bits[index] = 0
            end
        end
    end

    local instance = setmetatable({
        width = width,
        height = height,
        bits = bits
    }, Mask)
    
    return instance
end

-- ลorิกการเช็คหน้าสัมผัสการชนระหว่าง Mask สองตัว (Overlap Collision Logic)
-- self: Mask ตัวที่หนึ่ง (เช่น โขดหินประหลาดในฉาก) , x1, y1: พิกัดโลก 2D ของมัน
-- other: Mask ตัวที่สอง (เช่น หน้าสัมผัสเท้าตัวละคร) , x2, y2: พิกัดโลก 2D ของมัน
function Mask:overlap(x1, y1, other, x2, y2)
    -- คำนวณหาขอบเขตสี่เหลี่ยมจุดที่เกิดการทับซ้อนกันในแผนที่ (Bounding Box Overlap)
    local x_overlap_start = math.max(x1, x2)
    local x_overlap_end = math.min(x1 + self.width, x2 + other.width)
    local y_overlap_start = math.max(y1, y2)
    local y_overlap_end = math.min(y1 + self.height, y2 + other.height)

    -- ตรวจสอบเงื่อนไขแรก: ถ้าขอบเขตสี่เหลี่ยมด้านนอกไม่ทับกันเลย แปลว่าห่างไกลกันมาก ให้ตัดจบการทำงานทันที
    if x_overlap_start >= x_overlap_end or y_overlap_start >= y_overlap_end then
        return false
    end

    -- ขั้นตอนลงลึกระดับบิต (Deep Pixel Scan):
    -- วิ่งลูปตรวจสอบเฉพาะพื้นที่ภายในกรอบสี่เหลี่ยมที่เกิดการทับซ้อนกันจริงเท่านั้น
    for y = y_overlap_start, y_overlap_end - 1 do
        -- แปลงพิกัดโลกให้กลายเป็นพิกัดท้องถิ่นภายในรูปภาพของแต่ละวัตถุ
        local local_y1 = math.floor(y - y1)
        local local_y2 = math.floor(y - y2)

        for x = x_overlap_start, x_overlap_end - 1 do
            local local_x1 = math.floor(x - x1)
            local local_x2 = math.floor(x - x2)

            -- คำนวณหาตำแหน่งดัชนีในตารางข้อมูลแบนราบ 1D
            local idx1 = local_y1 * self.width + local_x1 + 1
            local idx2 = local_y2 * other.width + local_x2 + 1

            -- ตรรกะสัมผัสร่วมทางกายภาพ:
            -- ถ้าตำแหน่งพิกเซลเดียวกันนั้น ทั้งวัตถุที่ 1 และวัตถุที่ 2 มีค่าเป็น 1 ทั้งคู่ (เนื้อชนเนื้อ)
            -- ส่งสัญญาณกลับไปทันทีว่า "เกิดการชนกันระดับพิกเซลจริง!"
            if self.bits[idx1] == 1 and other.bits[idx2] == 1 then
                return true
            end
        end
    end

    -- วิ่งลูปตรวจสอบครบแล้วไม่เจอเนื้อวัตถุชนกันเลย แปลว่าผ่านฉลุย
    return false
end

return Mask