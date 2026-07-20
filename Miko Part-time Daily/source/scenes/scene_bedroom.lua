-- source/scenes/scene_bedroom.lua
local bedroom = {}
local kaoru = require("source.kaoru")
local bedroom_map = require("source.maps.bedroom_map") 
local saveRef = nil 
local is_map_initialized = false -- ตัวกันบั๊กรันโหลดแมปซ้ำซ้อน

function bedroom.load(saveData)
    saveRef = saveData 
    
    -- =======================================================
    -- [🎯 FIXED]: สั่งให้ไฟล์ Map รันระบบโหลดภาพพื้นไม้และเล่นเพลงทันที!
    -- =======================================================
    if bedroom_map.init and not is_map_initialized then
        bedroom_map.init()
        is_map_initialized = true
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

function bedroom.update(dt)
    if kaoru and kaoru.update then
        kaoru:update(dt, bedroom_map)
    end
    
    -- ลากกล้องวิ่งไล่ตามคาโอรุแบบสมูท
    if myCamera and myCamera.follow then
        myCamera:follow(kaoru.x, kaoru.y, dt)
    end 
end

function bedroom.draw()
    -- ดึงโครงสร้างกราฟิกและฟังก์ชันวาดพื้น/ผนังทั้งหมดมาแสดงผล
    bedroom_map.draw()
end

function bedroom.keypressed(key)
    if kaoru.keypressed then
        kaoru:keypressed(key)
    end
end

function bedroom.exit()
    -- หยุดเพลงเวลาเปลี่ยนฉากย้ายออกจากห้องนอน
    if bedroom_map.destroy then
        bedroom_map.destroy()
    end
    is_map_initialized = false
end

return bedroom