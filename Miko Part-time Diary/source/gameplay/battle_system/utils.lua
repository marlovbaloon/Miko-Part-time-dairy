-- battle_system/utils.lua
-- Private helpers and the callback trigger system

return function(M)
    local structs = require("source.gameplay.battle_system.structs")
    local state   = require("source.gameplay.battle_system.state")
    local config  = require("source.gameplay.battle_system.config")

    local _callbacks = state._callbacks
    local bullets    = structs.bullets

    function M._trigger(event, ...)
        local cbs = _callbacks[event]
        if not cbs then return end
        for i = 1, #cbs do
            local ok, err = pcall(cbs[i], ...)
            if not ok then
                print("[battle_system] Callback error (" .. event .. "): " .. tostring(err))
            end
        end
    end

    function M._set_phase(new_phase)
        if structs.state.phase == new_phase then return end
        structs.state.phase = new_phase
        M._trigger("on_phase_change", new_phase)
    end

    function M._reset_atb(gauge)
        gauge.current = 0.0
        gauge.ready = 0
        gauge.bonus_speed = 0.0
        gauge.bonus_timer = 0.0
    end

    function M._get_atb_speed(gauge)
        local s = gauge.speed
        -- Haste: applies the stored multiplier (30% by default) while the buff has turns remaining
        if gauge.bonus_timer > 0 and gauge.bonus_speed > 0 then
            s = s * gauge.bonus_speed
        end
        return s
    end

    function M._spawn_bullet(bx, by, bvx, bvy, bw, bh, btype, dmg)
        for i = 0, config.CONFIG.BULLET_POOL_SIZE - 1 do
            local b = bullets[i]
            if b.active == 0 then
                b.x = bx; b.y = by
                b.vx = bvx; b.vy = bvy
                b.w = bw; b.h = bh
                b.type = btype or config.BULLET_NORMAL
                b.damage = dmg or 1
                b.lifetime = config.CONFIG.BULLET_HELL_DURATION + 2.0
                b.active = 1
                return i
            end
        end
        return -1
    end

    function M._clear_bullets()
        for i = 0, config.CONFIG.BULLET_POOL_SIZE - 1 do
            bullets[i].active = 0
        end
    end

    function M._clamp(val, min, max)
        if val < min then return min end
        if val > max then return max end
        return val
    end

    function M._rect_overlap(ax, ay, aw, ah, bx, by, bw, bh)
        return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by
    end
end
