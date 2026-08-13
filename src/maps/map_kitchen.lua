-- src/maps/map_kitchem.lua
local MapManager = require("src.maps.map_manager")

local map_bedroom = MapManager.new({
    bg_path   = "assets/images/backgrounds/bedroom.png",
    mask_path = "assets/mask/bedroom_mask.png",
    bgm_name  = "Kaoru_Home",
    spawn     = { x = 45, y = 50 },
    grid_size = 8, -- Precision scanning (8x8 px)
    debug     = true, -- Turn to true to visualize mask colliders
    
    portals   = {
        { name = "door_to_kitchen", target = "kitchen", x = 64 + 64, y = 160 - 24, w = 16, h = 8 }
    }
})

return map_bedroom