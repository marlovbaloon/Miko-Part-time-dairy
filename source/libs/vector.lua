-- vector.lua
-- ไลบรารีคำนวณเวกเตอร์ 2D/3D แบบ Zero-Allocation 
-- ออกแบบมาเพื่อคุมขยะในแรม (Garbage Collector) ให้เป็น 0% ในลูปเกม

local Vector = {}

-- จองพื้นที่หน่วยความจำถาวร (Static Memory Pool) สำหรับการคำนวณภายใน
-- วัตถุประสงค์: เพื่อไม่ให้เกิดการสร้าง Table ใหม่ชั่วคราวในลูปอัปเดตเฟรม
local Pool = {
    temp2_A = {x = 0, y = 0},
    temp2_B = {x = 0, y = 0},
    temp3_A = {x = 0, y = 0, z = 0},
    temp3_B = {x = 0, y = 0, z = 0}
}

----------------------------------------------------
-- สถาปัตยกรรมเวกเตอร์ 2 มิติ (2D Vector Logic)
----------------------------------------------------

-- ฟังก์ชันสร้างเวกเตอร์ 2D ถาวร (ใช้ตอนโหลดเกมเท่านั้น ห้ามใช้ในลูปอัปเดต)
function Vector.new2D(x, y)
    return {x = x or 0, y = y or 0}
end

-- ลอจิกการหาความยาว (Magnitude) ของเวกเตอร์ 2D ตามทฤษฎีพีทาโกรัส
function Vector.length2D(v)
    return math.sqrt(v.x * v.x + v.y * v.y)
end

-- ลอจิกการปรับความยาวเวกเตอร์ให้เหลือ 1 หน่วย (Normalize) เพื่อหาทิศทางเดิน
-- target: เวกเตอร์ผลลัพธ์ที่จะเอาไปเขียนทับ (ลดการสร้างขยะ)
function Vector.normalize2D(v, target)
    local len = math.sqrt(v.x * v.x + v.y * v.y)
    if len > 0 then
        target.x = v.x / len
        target.y = v.y / len
    else
        target.x = 0
        target.y = 0
    end
end

-- ลอจิกการบวกเวกเตอร์ 2D: เอาค่าทางกายภาพมาบวกกันตรง ๆ แล้วบันทึกใส่ target
function Vector.add2D(v1, v2, target)
    target.x = v1.x + v2.x
    target.y = v1.y + v2.y
end

-- ลorิกการหา ระยะห่างทางกายภาพจริง ระหว่างสองพิกเซล 2D
function Vector.distance2D(v1, v2)
    local dx = v2.x - v1.x
    local dy = v2.y - v1.y
    return math.sqrt(dx * dx + dy * dy)
end

----------------------------------------------------
-- สถาปัตยกรรมเวกเตอร์ 3 มิติ (3D Vector Logic)
----------------------------------------------------

-- ฟังก์ชันสร้างเวกเตอร์ 3D ถาวร (ใช้สำหรับพิกเซล x, y และมิติลึก z ของระบบ Billboard)
function Vector.new3D(x, y, z)
    return {x = x or 0, y = y or 0, z = z or 0}
end

-- ลorิกการหาความยาวเวกเตอร์ 3D ในพื้นที่สามมิติ
function Vector.length3D(v)
    return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
end

-- ลอจิกการปรับทิศทางเวกเตอร์ 3D ให้เหลือ 1 หน่วย (สำหรับทิศทางมุมกล้อง)
function Vector.normalize3D(v, target)
    local len = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
    if len > 0 then
        target.x = v.x / len
        target.y = v.y / len
        target.z = v.z / len
    else
        target.x = 0
        target.y = 0
        target.z = 0
    end
end

-- ลอจิกการบวกเวกเตอร์ 3D แตกตัวแปรเข้าแกน x, y, z ตรง ๆ บนชิปประมวลผล
function Vector.add3D(v1, v2, target)
    target.x = v1.x + v2.x
    target.y = v1.y + v2.y
    target.z = v1.z + v2.z
end

-- เปิดพื้นที่ Static Pool ให้ระบบภายนอกดึงไปใช้อ้างอิงชั่วคราวได้
function Vector.getPool()
    return Pool
end

return Vector