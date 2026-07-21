-- source/gameplay/youkai/enemy_loader.lua
-- Central loader for data-driven youkai blueprints.

local enemy_loader = {}

-- Map string act ids to numeric command constants used by the engine.
local ACT_CMD_MAP = {
    check = 1,
    spare = 2,
    talk  = 3,
}

-- Asset / dialogue directories used by the engine
enemy_loader.ASSET_DIR = "assets/images/youkai"
enemy_loader.DIALOGUE_DIR = "data/dialogue/youkai"

function enemy_loader.load(enemy_id)
    if not enemy_id or type(enemy_id) ~= "string" then
        error("enemy_loader.load expects a string enemy_id, got: " .. tostring(enemy_id))
    end

    local path = "source.gameplay.youkai." .. enemy_id
    local ok, enemy_data = pcall(require, path)
    if not ok then
        error("Failed to load enemy '" .. enemy_id .. "': " .. tostring(enemy_data))
    end

    -- Ensure required identifiers exist
    enemy_data.id = enemy_data.id or enemy_id
    enemy_data.name = enemy_data.name or enemy_id

    -- Resolve sprite path (explicit field or default to assets/images/youkai/<id>.png)
    local sprite_path = enemy_data.sprite or (enemy_loader.ASSET_DIR .. "/" .. enemy_id .. ".png")
    enemy_data.sprite = sprite_path

    -- Pre-load sprite texture
    local sprite_ok, sprite = pcall(love.graphics.newImage, sprite_path)
    if sprite_ok then
        enemy_data._sprite = sprite
    else
        print("[enemy_loader] Sprite load failed for '" .. sprite_path .. "': " .. tostring(sprite))
        enemy_data._sprite = nil
    end

    -- Optional external dialogue file: data/dialogue/youkai/<enemy_id>.lua
    local dialogue_path = "data.dialogue.youkai." .. enemy_id
    local d_ok, dialogue_data = pcall(require, dialogue_path)
    if d_ok and type(dialogue_data) == "table" then
        enemy_data.dialogues = dialogue_data
    end

    return enemy_data
end

function enemy_loader.inject_to_battle(enemy_data, state, structs)
    if not enemy_data then
        error("enemy_loader.inject_to_battle requires enemy_data")
    end

    -- 1. Inject stats into the FFI enemy struct
    local enemy = structs.enemy
    enemy.max_hp     = enemy_data.max_hp or 80
    enemy.current_hp = enemy_data.current_hp or enemy.max_hp
    enemy.atk        = enemy_data.atk or 8
    enemy.def        = enemy_data.def or 4
    enemy.spd        = enemy_data.spd or 10
    enemy.sp         = 0
    enemy.max_sp     = 0

    -- 2. Transform youkai acts into the engine's ACT submenu format
    state._act_submenu = {}
    for _, act in ipairs(enemy_data.acts or {}) do
        table.insert(state._act_submenu, {
            id = act.id,
            cmd = act.cmd or ACT_CMD_MAP[act.id] or act.id,
            label = act.label,
            desc = act.description,
            spare_add = act.spare_add or 0,
            dialogue = act.dialogue,
            is_spare = act.id == "spare",
        })
    end

    -- 3. Clear dialogue queue and push intro text
    state._dialogue_queue = {}
    if enemy_data.dialogues and enemy_data.dialogues.intro then
        table.insert(state._dialogue_queue, enemy_data.dialogues.intro)
    end

    -- 4. Store blueprint and sprite on the battle state for rendering/patterns
    state._enemy_data = enemy_data
    state._visuals.enemy_sprite = enemy_data._sprite
end

return enemy_loader
