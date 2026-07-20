# Miko Part-time Dairy

A 2D top-down LÖVE2D (Lua) game featuring Kaoru navigating her bedroom.

## Stack

- **Engine**: LÖVE2D (love2d) — Lua game framework
- **Language**: Lua
- **Audio**: MP3 via LÖVE2D audio system

## How to run

The workflow `Start application` runs the game automatically.  
Command: `love 'Miko Part-time Daily'`  
Output type: **VNC** — the game appears in the VNC preview pane (not a browser tab).

To start manually from the shell:
```bash
love 'Miko Part-time Dairy'
```

> **Note:** Audio warnings (`XDG_RUNTIME_DIR`, `PipeWire`) are harmless — the game still runs correctly.

## Project structure

```
Miko Part-time Dairy/
├── main.lua                   # Entry point
├── conf.lua                   # Window config (320×320, resizable)
├── assets/
│   ├── character_playable/    # Kaoru sprite sheet
│   └── images/                # Tilesets (kaoru_home.png, etc.)
├── soundtracks/
│   └── ost/                   # BGM (MP3)
├── source/
│   ├── kaoru.lua              # Player character logic & animation
│   ├── states_manager.lua     # Scene/state machine
│   ├── title_menu.lua         # Title screen
│   ├── input.lua              # Input handling
│   ├── libs/
│   │   ├── camera.lua         # 2D top-down camera (lerp follow)
│   │   ├── anim8.lua          # Animation library
│   │   ├── tiles_maps.lua     # Tile/map system
│   │   └── group.lua          # Entity group / Y-sort renderer
│   ├── maps/
│   │   └── bedroom_map.lua    # Bedroom tile layout & draw
│   └── scenes/
│       └── scene_bedroom.lua  # Bedroom scene logic
└── data/
    └── dialogue/              # JSON dialogue files
```

## User preferences

- Camera: pure 2D top-down (no isometric/perspective projection)
