-- source/maps/bedroom_map.lua
local bedroom_map = {}
local kaoru = require("source.kaoru")
local Tiles = require("source.libs.tiles_maps")

local bedroomBGM  = nil
local is_loaded   = false

local ROOM_W      = 10   -- จำนวนช่องแนวนอน
local ROOM_H      = 10   -- จำนวนช่องแนวตั้ง
local TILE_SIZE   = 32   -- พิกเซลต่อช่อง

function bedroom_map.load()
    if is_loaded then return end

    -- โหลด BGM
    bedroomBGM = love.audio.newSource("soundtracks/ost/Kaoru_Home.mp3", "stream")
    bedroomBGM:setLooping(true)
    bedroomBGM:setVolume(0.5)
    bedroomBGM:play()

    -- เตรียมสไปรต์พื้นไม้ผ่านระบบ Grid Selector ดึงแผ่นภาพขนาด 32x32 ช่องคอลัมน์ 0 แถว 4
    local brush = Tiles.selectTileFromSheet("assets/images/kaoru_home.png", 32, 32, 0, 4)
    for gx = 0, ROOM_W - 1 do
        for gy = 0, ROOM_H - 1 do
            Tiles.placeTileToMap(gx, gy, "bedroom_wood_floor", brush)
        end
    end

    is_loaded = true
end

function bedroom_map.init()
    bedroom_map.load()
end

function bedroom_map.destroy()
    if bedroomBGM then
        bedroomBGM:stop()
        bedroomBGM = nil
    end
    is_loaded = false
end

function bedroom_map.draw()
    if not is_loaded then bedroom_map.load() end

    -- เติมพื้นหลังสีเข้มดั้งเดิมกันจอโล่ง
    love.graphics.clear(0.15, 0.12, 0.10)

    -- วาดพื้นตาราง 2D ด้วยระบบอาเรย์แผนที่แท้จริง คัดขอบจอนอกระยะออก (Culling)
    love.graphics.setColor(1, 1, 1, 1)
    for tileX = 0, ROOM_W - 1 do
        if Tiles.current_map[tileX] then
            for tileY = 0, ROOM_H - 1 do
                local tile = Tiles.current_map[tileX][tileY]
                if tile then
                    -- ตรวจสอบและเรนเดอร์เฉพาะตัวที่อยู่ในหน้าจอ
                    if myCamera:isBoundsIn(tile.x, tile.y, tile.width, tile.height) then
                        tile:draw(myCamera)
                    end
                end
            end
        end
    end

    -- วาดเส้นกรอบขอบเขตห้อง (Border)
    love.graphics.setColor(0.05, 0.05, 0.07)
    local tl = myCamera:toScreen(0, 0, 0)
    local br = myCamera:toScreen(ROOM_W * TILE_SIZE, ROOM_H * TILE_SIZE, 0)
    local room_px_w = br.x - tl.x
    local room_px_h = br.y - tl.y
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", tl.x, tl.y, room_px_w, room_px_h)
    love.graphics.setLineWidth(1)

    -- วาดตัวละครคาโอรุ
    love.graphics.setColor(1, 1, 1, 1)
    if kaoru and kaoru.draw then
        kaoru:draw(myCamera)
    end

    -- DEBUG TEXT
    love.graphics.setColor(1, 1, 0, 1)
    love.graphics.print("SCENE: KAORU'S BEDROOM (2D TOP-DOWN)", 4, 4)
    love.graphics.print(
        "Kaoru  X:" .. (kaoru and math.floor(kaoru.x) or 0) ..
        "  Y:"      .. (kaoru and math.floor(kaoru.y) or 0), 4, 16)
    love.graphics.print(
        "Cam  X:" .. math.floor(myCamera.x) ..
        "  Y:"    .. math.floor(myCamera.y), 4, 28)
end

return bedroom_map