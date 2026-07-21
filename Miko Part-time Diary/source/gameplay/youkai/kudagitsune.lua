-- source/gameplay/youkai/kudagitsune.lua
-- Data-driven blueprint for the Kudagitsune (pipe fox spirit) youkai.
-- [StrictLua] Stat constants declared with typed syntax before the table.

-- ── Stat declarations ────────────────────────────────────────────────────────
string YOUKAI_ID     = "kudagitsune"
string YOUKAI_NAME   = "Kudagitsune"
integer YOUKAI_MAX_HP = 80
integer YOUKAI_ATK    = 8
integer YOUKAI_DEF    = 4
integer YOUKAI_SPD    = 10
string YOUKAI_SPRITE  = "assets/images/youkai/kudagitsune.png"

-- ── Blueprint table ──────────────────────────────────────────────────────────
local kudagitsune = {
    id     = YOUKAI_ID,
    name   = YOUKAI_NAME,
    max_hp = YOUKAI_MAX_HP,
    atk    = YOUKAI_ATK,
    def    = YOUKAI_DEF,
    spd    = YOUKAI_SPD,
    sprite = YOUKAI_SPRITE,

    -- Act commands available against this youkai
    acts = {
        {
            id = "check",
            label = "Check",
            description = "Examine the enemy.",
            spare_add = 0,
            dialogue = "* Kudagitsune - a small fox spirit bound to a pipe.\n* ATK " .. YOUKAI_ATK .. " DEF " .. YOUKAI_DEF .. ".",
        },
        {
            id = "spare",
            label = "Spare",
            description = "Let the enemy go.",
            spare_add = 0,
            dialogue = "* You offer a peaceful gesture...",
        },
        {
            id = "talk",
            label = "Talk",
            description = "Try to calm the spirit.",
            spare_add = 25,
            dialogue = "* You speak softly to the fox spirit.\n* Its tail stops bristling.",
        },
    },

    -- Battle dialogue strings (overridden if data/dialogue/youkai/kudagitsune.lua exists)
    dialogues = {
        intro = "* " .. YOUKAI_NAME .. " scurries out from a bamboo pipe!",
        spareable = "* " .. YOUKAI_NAME .. " seems ready to listen.",
        turn_quotes = {
            "* " .. YOUKAI_NAME .. "'s tail flickers nervously.",
            "* The pipe spirit chitters softly.",
            "* A faint warmth drifts from the bamboo pipe.",
        },
    },

    -- Bullet-hell pattern callbacks
    -- Signature: function(M, bullets, box_bounds, soul_pos)
    -- M is the battle module table, providing helpers like M._spawn_bullet.
    patterns = {
        normal = function(M, bullets, box, soul)
            for i = 1, 20 do
                local bx = box.box_x + math.random() * box.box_w
                local by = box.box_y - 20 - math.random() * 100
                M._spawn_bullet(bx, by, 0, 80 + math.random() * 60, 6, 6, M.BULLET_NORMAL, 5)
            end
        end,

        homing = function(M, bullets, box, soul)
            for i = 1, 12 do
                local angle = (i / 12) * math.pi * 2
                local bx = soul.x + math.cos(angle) * 120
                local by = soul.y + math.sin(angle) * 120
                M._spawn_bullet(bx, by, 0, 0, 8, 8, M.BULLET_HOMING, 8)
            end
        end,

        wave = function(M, bullets, box, soul)
            for i = 1, 30 do
                local bx = box.box_x + (i / 30) * box.box_w
                local by = box.box_y + math.sin(i * 0.5) * 30
                M._spawn_bullet(bx, by, -40, 0, 5, 5, M.BULLET_WAVE, 4)
            end
        end,
    },

    -- AI: pick the next bullet-hell pattern based on battle state
    select_next_pattern = function(self, current_hp, spare_meter)
        float hp_pct = current_hp / self.max_hp
        if spare_meter >= 100 then
            return self.patterns.wave
        elseif hp_pct > 0.7 then
            return self.patterns.normal
        elseif hp_pct > 0.4 then
            return self.patterns.homing
        else
            return self.patterns.wave
        end
    end,
}

return kudagitsune
