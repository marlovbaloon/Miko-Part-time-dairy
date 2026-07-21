-- source/status_menu.lua
local status_menu = {}

-- 1. ค่าสถานะเริ่มต้น
status_menu.isOpen = false
status_menu.currentY = -110   -- พิกัดเริ่มต้น (ซ่อนอยู่บนขอบจอ)
status_menu.targetY = -110    -- พิกัดเป้าหมาย
status_menu.speed = 10        -- ความเร็วในการสไลด์ (ค่า Lerp)

-- ข้อมูลจำลองตามที่มึงสั่ง
status_menu.data = {
    age = 14,
    affection = 100,           -- ค่าความชอบที่มีต่อผู้เล่น
    fatigue = 0,              -- ค่าความเหนื่อยล้า(ยิ่งเลขมากยิ่งหนื่อยมาก) (ไม่มี HP)
    quests = {                 -- Note quest (อนาคตดึงจาก SaveData ได้)
        "No quests active currently."
    },
    items = {"Black Pen", "Wallet"},
    equipment = "Casual Clothes"
}

-- ตัวแปรดักปุ่มกดเพื่อป้องกันหน้าจอสไลด์รัวๆ ตอนกดค้าง
local lbWasPressed = false

function status_menu.update(dt)
    -- ดึงค่าจากคอนโทรลเลอร์ (เช็คปุ่ม LB) และคีย์บอร์ด (ปุ่ม L)
    local lbPressed = false
    if type(controller) == "table" and controller.isDown then
        lbPressed = controller.isDown("lb")
    end
    if love.keyboard.isDown("l") then
        lbPressed = true
    end

    -- ตรรกะ Toggle: กดแล้วสลับสถานะเปิด/ปิด (Trigger ครั้งเดียวต่อการกด)
    if lbPressed and not lbWasPressed then
        status_menu.isOpen = not status_menu.isOpen
        if status_menu.isOpen then
            status_menu.targetY = 0 -- สไลด์ลงมาชนขอบบนจอ
        else
            status_menu.targetY = -110 -- สไลด์เก็บขึ้นข้างบน
        end
    end
    lbWasPressed = lbPressed

    -- ระบบ Linear Interpolation (Lerp) ทำให้หน้าจอสไลด์แบบนุ่มๆ สมูทๆ
    status_menu.currentY = status_menu.currentY + (status_menu.targetY - status_menu.currentY) * status_menu.speed * dt
end

function status_menu.draw(virtualWidth, virtualHeight)
    -- ถ้ายู่ในจุดที่ซ่อนสนิทและปิดอยู่ ไม่ต้องวาดเพื่อประหยัดการประมวลผล GPU
    if not status_menu.isOpen and status_menu.currentY <= -109 then return end

    -- บังคับวาดภายใต้สเกลหน้าจอเกมเสมือน (320x320)
    local menuH = math.floor(virtualHeight / 3) -- กินพื้นที่ 1/3 ของจอเกมเป๊ะๆ

    love.graphics.push("all")

    -- 1. วาดกล่องพื้นหลังเมนู (สีดำโปร่งแสงสไตล์ Retro RPG)
    love.graphics.setColor(0.05, 0.05, 0.08, 0.9)
    love.graphics.rectangle("fill", 0, status_menu.currentY, virtualWidth, menuH)

    -- 2. วาดเส้นขอบล่างเมนู (สีขาวเทาให้ตัดกับฉากหลัง)
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.setLineWidth(1)
    love.graphics.line(0, status_menu.currentY + menuH, virtualWidth, status_menu.currentY + menuH)

    -- 3. เขียนข้อมูล Status (จัดวางตำแหน่งแบบแบ่งคอลัมน์)
    love.graphics.setColor(1, 1, 1, 1)
    
    -- คอลัมน์ 1: ข้อมูลทั่วไป (Status)
    local startY = status_menu.currentY + 6
    love.graphics.print("[ STATUS ]", 10, startY)
    love.graphics.print("Age: " .. status_menu.data.age, 15, startY + 16)
    love.graphics.print("Affection: " .. status_menu.data.affection, 15, startY + 28)
    love.graphics.print("Fatigue: " .. status_menu.data.fatigue .. "%", 15, startY + 40)
    love.graphics.print("Equip: " .. status_menu.data.equipment, 15, startY + 52)

    -- คอลัมน์ 2: ไอเทม (Items)
    love.graphics.print("[ ITEMS ]", 140, startY)
    for i, item in ipairs(status_menu.data.items) do
        love.graphics.print("- " .. item, 145, startY + 4 + (i * 12))
    end

    -- คอลัมน์ 3: บันทึกเควส (Quest Note)
    love.graphics.print("[ QUESTS ]", 230, startY)
    for i, quest in ipairs(status_menu.data.quests) do
        -- ใช้ printf เพื่อให้ข้อความตัดขึ้นบรรทัดใหม่เองอัตโนมัติถ้าความยาวเกินช่อง
        love.graphics.printf(quest, 235, startY + 16, 80, "left")
    end

    love.graphics.pop()
end

return status_menu