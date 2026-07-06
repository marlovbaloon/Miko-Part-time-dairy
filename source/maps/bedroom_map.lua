-- source/maps/bedroom_map.lua
-- 2D Top-Down view: วาดห้องจากมุมมองดิ่งตรงๆ ไม่มี perspective/3D
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

    -- เตรียมสไปรต์พื้นไม้ผ่านระบบ Tiles
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

    -- พื้นหลังกรณีไม่มีสไปรต์
    love.graphics.clear(0.15, 0.12, 0.10)

    local sprite = Tiles.sprites["bedroom_wood_floor"]

    -- วาดพื้นทุกช่องในตาราง 2D
    for tileX = 0, ROOM_W - 1 do
        for tileY = 0, ROOM_H - 1 do
            local wx = tileX * TILE_SIZE
            local wy = tileY * TILE_SIZE
            local p  = myCamera:toScreen(wx, wy, 0)

            if sprite and sprite.image and sprite.quad then
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(sprite.image, sprite.quad, p.x, p.y)
            else
                -- Fallback หมากรุก
                if (tileX + tileY) % 2 == 0 then
                    love.graphics.setColor(0.18, 0.18, 0.20)
                else
                    love.graphics.setColor(0.22, 0.22, 0.24)
                end
                love.graphics.rectangle("fill", p.x, p.y, TILE_SIZE, TILE_SIZE)
            end
        end
    end

    -- วาดเส้นกรอบผนังห้อง (border)
    love.graphics.setColor(0.05, 0.05, 0.07)
    local tl = myCamera:toScreen(0,                  0,                  0)
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

    -- DEBUG
    love.graphics.setColor(1, 1, 0, 1)
    love.graphics.print("SCENE: KAORU'S BEDROOM", 4, 4)
    love.graphics.print(
        "Kaoru  X:" .. (kaoru and math.floor(kaoru.x) or 0) ..
        "  Y:"      .. (kaoru and math.floor(kaoru.y) or 0), 4, 16)
    love.graphics.print(
        "Cam  X:" .. math.floor(myCamera.x) ..
        "  Y:"    .. math.floor(myCamera.y), 4, 28)
end

return bedroom_map
