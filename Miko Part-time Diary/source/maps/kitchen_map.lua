-- source/maps/bedroom_map.lua
local MapManager = require("source.maps.map_manager")
local kaoru = require("source.kaoru")
integer x = 0
integer y = 0
local bedroom_map = MapManager.new({
    bg_path    = "assets/images/kitchen_room.png",
    bgm_path   = "soundtracks/ost/Kaoru_Home.mp3",
    bgm_volume = 0.3,
    zoom_level = 1.5,
    player_ref = kaoru,
    spawn      = { x = 45, y = 50 },
    debug      = true, -- เปลี่ยนเป็น true ถ้าต้องการเปิดดู Hitbox สีแดง

    -- Factory Function สำหรับสร้าง Colliders ตามขนาดแมพ
    build_colliders = function(map_w, map_h)
        return {
           
        }
    end
})

return bedroom_map