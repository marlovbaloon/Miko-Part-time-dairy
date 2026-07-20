-- source/maps/bedroom_map.lua
local bedroom_map = {}
local kaoru = require("source.kaoru")

local bedroomBGM   = nil
local is_loaded   = false

local bg_image     = nil 
local MAP_WIDTH    = 190   
local MAP_HEIGHT   = 160   

-- [🎯 STEP 1]: เตรียมตารางสำหรับเก็บกล่องชนสิ่งกีดขวางภายในบ้าน
bedroom_map.colliders = {}

function bedroom_map.load()
    if is_loaded then return end

    -- 1. โหลด BGM
    bedroomBGM = love.audio.newSource("soundtracks/ost/Kaoru_Home.mp3", "stream")
    bedroomBGM:setLooping(true)
    bedroomBGM:setVolume(0.5)
    bedroomBGM:play()

    -- 2. โหลดรูปภาพแผนที่เต็มฉาก
    bg_image = love.graphics.newImage("assets/images/kaoru_bedroom.png")
    bg_image:setFilter("nearest", "nearest") 

    MAP_WIDTH = bg_image:getWidth()
    MAP_HEIGHT = bg_image:getHeight()

    bedroom_map.colliders = {
        --  กำแพงล่องหนกั้นขอบบน (กั้นตรงพิกัดที่สิ้นสุดแนววาดกำแพงในใจมึง)
        { x = 0, y = 32, width = MAP_WIDTH, height = 8 }, 
        -- bed 
        { x = 32 -16 , y = 32 + 16 , width = 32, height = 32 }, 
        -- wardrobe
        { x = 32 + 16 + 32 , y = 32 + 16 , width = 32 + 14 , height = 32 - 16}, 
        -- โต๊ะเก้าอี้
        { x = 32 + 16 + 32 + 60 , y = 32 + 16 + 16 - 16, width = 32 + 16 , height = 32 - 16}, 
    --  กำแพงล่องหนกั้นขอบล่าง (กั้นเหนือนอกพิกัดรูปภาพขยับขึ้นมา)
       { x = 0, y = MAP_HEIGHT - 16, width = MAP_WIDTH, height = 8 },
        -- Fuma
        { x = 32 - 28 , y = 64 + 32 + 16 , width = 16, height = 32 }, 
        { x = 32 - 28 , y = 64 + 32 + 16 - 14, width = 16, height = 32 }, 
    --  กำแพงล่องหนกั้นฝั่งซ้าย
    { x = 0, y = 0, width = 2, height = MAP_HEIGHT },

    --  กำแพงล่องหนกั้นฝั่งขวา
    { x = MAP_WIDTH - 4 , y = 4, width = 2, height = MAP_HEIGHT },
    }

    is_loaded = true
end

function bedroom_map.init()
    myCamera:setZoom(1.5)
    bedroom_map.load()
    if kaoru then
        -- จุดเกิดของคาโอรุ (เลี่ยงไม่ให้เกิดทับกล่องสิ่งกีดขวาง)
        kaoru.x = 45
        kaoru.y = 50
    end
end

function bedroom_map.destroy()
    if bedroomBGM then
        bedroomBGM:stop()
        bedroomBGM = nil
    end
    bg_image = nil 
    bedroom_map.colliders = {} -- ล้างค่ากล่องชนเมื่อย้ายฉาก
    is_loaded = false
end

function bedroom_map.draw()
    if not is_loaded then bedroom_map.load() end

    love.graphics.clear(0.15, 0.12, 0.10)
    love.graphics.setColor(1, 1, 1, 1)

    if bg_image then
        local map_pos = myCamera:toScreen(0, 0, 0)
        local zoom = myCamera.zoom or 1.5 
        love.graphics.draw(bg_image, map_pos.x, map_pos.y, 0, zoom, zoom)
    end

    -- วาดเส้นกรอบขอบเขตห้อง (Border)
    love.graphics.setColor(0.05, 0.05, 0.07)
    local tl = myCamera:toScreen(0, 0, 0)
    local br = myCamera:toScreen(MAP_WIDTH, MAP_HEIGHT, 0)
    local room_px_w = br.x - tl.x
    local room_px_h = br.y - tl.y
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", tl.x, tl.y, room_px_w, room_px_h)
    love.graphics.setLineWidth(1)

    -- =======================================================
    -- [🎯 STEP 3/DEV ONLY]: วาดเส้นไกด์ไลน์สีแดงเพื่อเช็กตำแหน่งกล่องชน (เอาไว้เปิดดูตอนเทสเกม)
    -- พอทำเกมเสร็จหรือตำแหน่งเป๊ะแล้ว ให้คอมเมนต์ก้อนนี้ทิ้งได้เลยมึง
    -- =======================================================
    love.graphics.setColor(1, 0, 0, 0.6) -- สีแดงโปร่งแสง
    local zoom = myCamera.zoom or 1.5
    for i = 1, #bedroom_map.colliders do
        local box = bedroom_map.colliders[i]
        -- แปลงพิกัดกล่องชนในเกมให้เคลื่อนที่และซูมตามกล้อง
        local box_screen = myCamera:toScreen(box.x, box.y, 0)
        love.graphics.rectangle("line", box_screen.x, box_screen.y, box.width * zoom, box.height * zoom)
    end

    -- วาดตัวละครคาโอรุ
    love.graphics.setColor(1, 1, 1, 1)
    if kaoru and kaoru.draw then
        kaoru:draw(myCamera)
    end

    -- DEBUG TEXT
    love.graphics.setColor(1, 1, 0, 1)
    --[[
    love.graphics.print("SCENE: KAORU'S BEDROOM", 4, 4)
    love.graphics.print(
        "Kaoru  X:" .. (kaoru and math.floor(kaoru.x) or 0) ..]]
        --"  Y:"      .. (kaoru and math.floor(kaoru.y) or 0), 4, 16)
    --[[
    love.graphics.print(
        "Cam  X:" .. math.floor(myCamera.x) ..
        "  Y:"    .. math.floor(myCamera.y), 4, 28)]]
    love.graphics.setColor(1, 1, 1, 1)
end

return bedroom_map