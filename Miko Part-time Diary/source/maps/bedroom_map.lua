-- source/maps/bedroom_map.lua
local MapManager = require("source.maps.map_manager")
local kaoru = require("source.entities.kaoru")
local scene_kitchen = require("source.maps.kitchen_map")
integer x = 0
integer y = 0
local bedroom_map = MapManager.new({
    bg_path    = "assets/images/kaoru_bedroom.png",
    bgm_path   = "assets/audio/Kaoru_Home.mp3",
    bgm_volume = 0.5,
    zoom_level = 1.5,
    player_ref = kaoru,
    spawn      = { x = 45, y = 50 },
    debug      = true, -- เปลี่ยนเป็น true ถ้าต้องการเปิดดู Hitbox สีแดง

    portals = {
            {
                id = "exit_to_kitchen", 
                x = 64 + 64, 
                y = 160 - 24, 
                width = 16, 
                height = 8,
                target_scene = "kitchen" -- 👈 สั่งตรงนี้เลยว่ากดแล้วจะ switch ไปฉากชื่ออะไร!
            }
        },
    
    -- Factory Function สำหรับสร้าง Colliders ตามขนาดแมพ
    build_colliders = function(map_w, map_h)
        return {
            -- กำแพงบน
            { x = 0, y = 32, width = map_w, height = 8 },
            -- เตียง
            { id = "bed", x = 16, y = 48, width = 32, height = 32 },
            -- ตู้เสื้อผ้า
            { id = "wardrobe", x = 80, y = 48, width = 46, height = 16 },
            -- โต๊ะเก้าอี้
            { id = "desk", x = 140, y = 48, width = 48, height = 16 },
            -- กำแพงล่าง
            { x = 0, y = map_h - 16, width = map_w, height = 8 },
            
            -- Fuma push
            { id = "fuma_push", x = 4, y = 98, width = 16, height = 32 },
            -- กำแพงซ้าย
            { x = 0, y = 0, width = 2, height = map_h },
            -- กำแพงขวา
            { x = map_w - 4, y = 4, width = 2, height = map_h },
        }
    end
})

return bedroom_map