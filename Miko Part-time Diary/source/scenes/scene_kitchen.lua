-- source/scenes/scene_kitchen.lua
local kitchen = {}
local kaoru = require("source.kaoru")
local kitchen_map = require("source.maps.kitchen_map") 
local interact = require("source.interact") --ดึงโมดูลระบบปฏิสัมพันธ์เข้ามาใช้งาน
local saveRef = nil 
local is_map_initialized = false -- ตัวกันบั๊กรันโหลดแมปซ้ำซ้อน

function kitchen.load(saveData)
    saveRef = saveData 

    -- =======================================================
    -- [🎯 FIXED]: สั่งให้ไฟล์ Map รันระบบโหลดภาพพื้นไม้และเล่นเพลงทันที!
    -- =======================================================
    if kitchen_map.init and not is_map_initialized then
        kitchen_map.init()
        is_map_initialized = true
    end

    -- [🎯 NEW]: โหลดฐานข้อมูลบทสนทนาประจำด่านห้องนอนเข้ามาเตรียมพร้อม
    if interact.loadDatabase then
        interact.loadDatabase("data/dialogue/kitchen_table.json")
    end

    -- โหลดข้อมูลสไปรต์ตัวละครคาโอรุ
    if kaoru.load then
        kaoru:load() 
    end

    -- =======================================================
    -- [🎯 FIXED]: ปรับพิกัดกล้องเซฟตี้ ถอยระยะออกมาให้เห็นระนาบพื้นโลก 2.5D
    -- =======================================================
    if myCamera then
        myCamera.x = 160  -- จุดเริ่มต้นกล้องกึ่งกลางห้อง
        myCamera.y = 160
    end
end

function kitchen.update(dt)
    -- [🎯 NEW]: อัปเดตระบบตรวจสอบการชนวัตถุสำรวจ และอัปเดตแอนิเมชันพิมพ์ตัวอักษรของกล่องข้อความ
    -- ส่งค่า dt, table ของตัวละคร kaoru, และ table ของ kitchen_map เข้าไปคำนวณ
    if interact and interact.update then
        interact.update(dt, kaoru, kitchen_map)
    end

    if kaoru and kaoru.update then
        kaoru:update(dt, kitchen_map)
    end

    -- ลากกล้องวิ่งไล่ตามคาโอรุแบบสมูท
    if myCamera and myCamera.follow then
        myCamera:follow(kaoru.x, kaoru.y, dt)
    end 
end

function kitchen.draw()
    -- ดึงโครงสร้างกราฟิกและฟังก์ชันวาดพื้น/ผนังทั้งหมดมาแสดงผล
    kitchen_map.draw()

    -- [🎯 NEW]: วาดกล่องข้อความ UI (Interact) ไว้บรรทัดล่างสุดเพื่อให้อยู่เลเยอร์บนสุดของจอ
    -- ส่งขนาดหน้าจอ Virtual Resolution (สมมติว่าใช้ 320x240 หรือตามสเกลโปรเจกต์เดิมของมึง)
    -- ถ้าโปรเจกต์มึงใช้ขนาดอื่น สามารถเปลี่ยนตัวเลขพิกัดตรงนี้ได้เลย (เช่น 320, 240)
    if interact and interact.draw then
        interact.draw(320, 320) 
    end
end

function kitchen.keypressed(key)
    if kaoru.keypressed then
        kaoru:keypressed(key)
    end
end

function kitchen.exit()
    -- หยุดเพลงเวลาเปลี่ยนฉากย้ายออกจากห้องนอน
    if kitchen_map.destroy then
        kitchen_map.destroy()
    end
    is_map_initialized = false
end

return kitchen