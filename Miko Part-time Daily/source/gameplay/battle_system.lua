-- =============================================================================
-- source/gameplay/battle/battle_system.lua
-- =============================================================================
-- ระบบต่อสู้ผสมผสาน (Hybrid Battle System)
-- แนวคิด: Deltarune + Final Fantasy VI ATB + Undertale Bullet-Hell Box
--
-- สถาปัตยกรรม: Zero-GC / High Performance / Modular / State-Independent
-- สถานะ: เตรียมพร้อมสำหรับ Demo (ยังไม่ผูกกับลูปหลักโดยอัตโนมัติ)
-- =============================================================================

local ffi = require("ffi")

-- =============================================================================
-- 0. FFI C Struct Definitions (Zero-GC Data Layer)
-- =============================================================================
ffi.cdef[[
    typedef struct {
        float x, y;           // ตำแหน่ง
        float vx, vy;         // ความเร็ว
        float w, h;           // ขนาด
        int   active;         // 1 = ใช้งานอยู่, 0 = ว่าง
        int   type;           // ประเภทกระสุน
        float damage;         // ดาเมจ
        float lifetime;       // อายุเหลือ
    } Bullet;

    typedef struct {
        float x, y;           // ตำแหน่งมินิสไปรท์
        float speed;          // ความเร็วการเคลื่อนที่
        float hitbox_r;       // รัศมี hitbox
        int   invincible;     // 1 = อมตะชั่วคราว
        float iframes;        // เฟรมอมตะเหลือ
    } PlayerSoul;

    typedef struct {
        float current;        // ค่าปัจจุบัน 0.0 - 100.0
        float speed;          // ความเร็วเติมต่อวินาที
        float bonus_speed;    // โบนัสความเร็ว (หลังหลบได้บางส่วน)
        float bonus_timer;    // เวลาโบนัสเหลือ
        int   ready;          // 1 = พร้อมใช้คำสั่ง
    } ATBGauge;

    typedef struct {
        int   max_hp;
        int   current_hp;
        int   atk;
        int   def;
        int   spd;
        int   sp;             // SP สำหรับทักษะพิเศษ
        int   max_sp;
    } BattleStats;

    typedef struct {
        int   phase;          // 0=IDLE, 1=COMMAND, 2=BULLET_HELL, 3=DIALOGUE, 4=RESULT
        int   turn_count;     // จำนวนเทิร์นที่ผ่านไป
        int   side_flipped;   // 1 = สลับฝั่ง (ผู้เล่นซ้าย, ศัตรูขวา)
        int   paused;         // 1 = หยุดเวลา ATB
        int   dialogue_active;// 1 = กำลังแสดงบทสนทนา
        float box_x, box_y;   // ตำแหน่งกล่อง Bullet-Hell
        float box_w, box_h;   // ขนาดกล่อง
        int   perfect_dodge;  // 1 = หลบได้สมบูรณ์ในเทิร์นนี้
        int   enemy_spare_meter; // 0-100 ความพึงพอใจของศัตรู
        int   battle_ended;   // 1 = จบการต่อสู้แล้ว
        int   pacifist_end;   // 1 = จบแบบสันติ
    } BattleState;
]]

-- =============================================================================
-- 1. Constants & Configuration
-- =============================================================================
local M = {}

-- Phases
M.PHASE_IDLE         = 0
M.PHASE_COMMAND      = 1  -- เลือกคำสั่ง D-Pad
M.PHASE_SUBMENU      = 2  -- เลือกจากเมนูย่อย
M.PHASE_BULLET_HELL  = 3  -- กล่องหลบกระสุน
M.PHASE_DIALOGUE     = 4  -- แสดงบทสนทนา
M.PHASE_RESULT       = 5  -- ผลลัพธ์ (ชนะ/จบ)

-- D-Pad Commands
M.CMD_ATTACK = 1
M.CMD_ITEM   = 2
M.CMD_ACT    = 3
M.CMD_SP     = 4

-- Act Sub-commands
M.ACT_CHECK = 1
M.ACT_SPARE = 2
M.ACT_TALK  = 3

-- Bullet Types
M.BULLET_NORMAL = 1
M.BULLET_HOMING = 2
M.BULLET_WAVE   = 3

-- Config
M.CONFIG = {
    ATB_MAX             = 100.0,
    ATB_BASE_SPEED      = 15.0,   -- ค่าเติมต่อวินาที
    ATB_BONUS_MULT      = 2.5,    -- โบนัสความเร็ว ATB เมื่อหลบบางส่วน
    ATB_BONUS_DURATION  = 3.0,    -- วินาทีที่โบนัสอยู่
    BULLET_POOL_SIZE    = 256,    -- จำนวนกระสุนสูงสุดใน pool
    BULLET_HELL_DURATION= 8.0,    -- วินาทีต่อเฟสกระสุน
    BOX_MARGIN          = 60,     -- ระยะขอบกล่องจากขอบจอ
    SOUL_SPEED          = 220.0,  -- ความเร็วมินิสไปรท์
    SOUL_IFRAMES        = 1.0,    -- วินาทีอมตะหลังโดนตี
    SPARE_METER_MAX     = 100,
    FLIP_CHANCE         = 0.15,   -- 15% ที่จะสลับฝั่ง
}

-- =============================================================================
-- 2. Internal State (Zero-GC Allocated Once)
-- =============================================================================

-- C Structs (allocated once, never GC'd)
local state   = ffi.new("BattleState")
local player  = ffi.new("BattleStats")
local enemy   = ffi.new("BattleStats")
local player_atb = ffi.new("ATBGauge")
local enemy_atb  = ffi.new("ATBGauge")
local soul    = ffi.new("PlayerSoul")

-- Bullet Pool (pre-allocated array of C structs)
local bullets = ffi.new("Bullet[?]", M.CONFIG.BULLET_POOL_SIZE)

-- Static Lua tables (pre-allocated, reused)
local _bullets_active = {}  -- index mapping สำหรับ loop เร็ว
local _command_menu = {
    { key = "up",    cmd = M.CMD_ATTACK, label = "Attack", icon = "sword" },
    { key = "down",  cmd = M.CMD_ITEM,   label = "Item",   icon = "potion" },
    { key = "right", cmd = M.CMD_ACT,    label = "Act",    icon = "hand" },
    { key = "left",  cmd = M.CMD_SP,     label = "SP",     icon = "star" },
}
local _act_submenu = {
    { cmd = M.ACT_CHECK, label = "Check", desc = "Examine the enemy." },
    { cmd = M.ACT_SPARE, label = "Spare", desc = "Let the enemy go." },
    { cmd = M.ACT_TALK,  label = "Talk",  desc = "Talk to the enemy." },
}

-- Dialogue Queue (static array ไม่สร้าง table ใหม่ใน loop)
local _dialogue_queue = {}
local _dialogue_index = 0
local _dialogue_timer = 0

-- Visual State (สำหรับ draw, ไม่ใช่ logic)
local _visuals = {
    player_x = 0, player_y = 0,
    enemy_x  = 0, enemy_y  = 0,
    player_target_x = 0, enemy_target_x = 0,
    shake_x = 0, shake_y = 0, shake_timer = 0,
    miss_text_timer = 0,
    cmd_cursor = 1,   -- 1=Up, 2=Down, 3=Right, 4=Left
    submenu_cursor = 1,
    show_submenu = false,
}

-- Callbacks (Event System)
local _callbacks = {
    on_battle_start = {},
    on_turn_end     = {},
    on_phase_change = {},
    on_dialogue     = {},
    on_battle_end   = {},
}

-- ตัวแปรชั่วคราวสำหรับคำนวณ (reuse)
local _tmp_dx, _tmp_dy, _tmp_dist

-- =============================================================================
-- 3. Private Helper Functions
-- =============================================================================

local function _trigger(event, ...)
    local cbs = _callbacks[event]
    if not cbs then return end
    for i = 1, #cbs do
        local ok, err = pcall(cbs[i], ...)
        if not ok then
            print("[battle_system] Callback error (" .. event .. "): " .. tostring(err))
        end
    end
end

local function _set_phase(new_phase)
    if state.phase == new_phase then return end
    state.phase = new_phase
    _trigger("on_phase_change", new_phase)
end

local function _reset_atb(gauge)
    gauge.current = 0.0
    gauge.ready = 0
    gauge.bonus_speed = 0.0
    gauge.bonus_timer = 0.0
end

local function _get_atb_speed(gauge)
    local s = gauge.speed
    if gauge.bonus_timer > 0 then
        s = s * M.CONFIG.ATB_BONUS_MULT
    end
    return s
end

local function _spawn_bullet(bx, by, bvx, bvy, bw, bh, btype, dmg)
    -- หาช่องว่างใน pool (linear scan - เร็วพอสำหรับ 256 ชิ้น)
    for i = 0, M.CONFIG.BULLET_POOL_SIZE - 1 do
        local b = bullets[i]
        if b.active == 0 then
            b.x = bx; b.y = by
            b.vx = bvx; b.vy = bvy
            b.w = bw; b.h = bh
            b.type = btype or M.BULLET_NORMAL
            b.damage = dmg or 1
            b.lifetime = M.CONFIG.BULLET_HELL_DURATION + 2.0
            b.active = 1
            return i
        end
    end
    return -1 -- pool full
end

local function _clear_bullets()
    for i = 0, M.CONFIG.BULLET_POOL_SIZE - 1 do
        bullets[i].active = 0
    end
end

local function _clamp(val, min, max)
    if val < min then return min end
    if val > max then return max end
    return val
end

local function _rect_overlap(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by
end

-- =============================================================================
-- 4. Positioning & Layout Logic
-- =============================================================================

function M._calc_layout(screen_w, screen_h)
    local v = _visuals
    local margin = 80
    local center_y = screen_h * 0.45

    if state.side_flipped == 0 then
        -- ปกติ: ผู้เล่นขวา, ศัตรูซ้าย
        v.player_target_x = screen_w - margin - 120
        v.enemy_target_x  = margin + 60
    else
        -- สลับ: ผู้เล่นซ้าย, ศัตรูขวา
        v.player_target_x = margin + 60
        v.enemy_target_x  = screen_w - margin - 120
    end

    v.player_y = center_y
    v.enemy_y  = center_y

    -- กล่อง Bullet-Hell อยู่ตรงกลางจอ
    state.box_w = 280
    state.box_h = 200
    state.box_x = (screen_w - state.box_w) * 0.5
    state.box_y = (screen_h - state.box_h) * 0.5 - 40

    -- HP Bar อยู่ฝั่งขวาสุดเสมอ
    v.hp_bar_x = screen_w - 180
    v.hp_bar_y = screen_h - 80
end

-- =============================================================================
-- 5. Scene Interface (สำหรับ StateManager)
-- =============================================================================

--- เริ่มต้นระบบต่อสู้
-- @param saveData table  ข้อมูลเซฟ (HP, SP, อาวุธ, ไอเทม, ฯลฯ)
-- @param enemyData table ข้อมูลศัตรู (ชื่อ, stats, pattern, dialogue)
function M.load(saveData, enemyData)
    saveData = saveData or {}
    enemyData = enemyData or {}

    -- รีเซ็ตสถานะทั้งหมด
    state.phase = M.PHASE_IDLE
    state.turn_count = 0
    state.paused = 0
    state.dialogue_active = 0
    state.perfect_dodge = 0
    state.enemy_spare_meter = 0
    state.battle_ended = 0
    state.pacifist_end = 0

    -- สุ่มสลับฝั่ง (15%)
    state.side_flipped = (math.random() < M.CONFIG.FLIP_CHANCE) and 1 or 0

    -- โหลดสถิติผู้เล่น
    player.max_hp    = saveData.max_hp or 100
    player.current_hp = saveData.current_hp or player.max_hp
    player.atk       = saveData.atk or 10
    player.def       = saveData.def or 5
    player.spd       = saveData.spd or 12
    player.sp        = saveData.sp or 20
    player.max_sp    = saveData.max_sp or 20

    -- โหลดสถิติศัตรู
    enemy.max_hp     = enemyData.max_hp or 80
    enemy.current_hp  = enemyData.current_hp or enemy.max_hp
    enemy.atk        = enemyData.atk or 8
    enemy.def        = enemyData.def or 4
    enemy.spd        = enemyData.spd or 10
    enemy.sp         = 0
    enemy.max_sp     = 0

    -- เริ่ม ATB
    _reset_atb(player_atb)
    _reset_atb(enemy_atb)
    player_atb.speed = M.CONFIG.ATB_BASE_SPEED * (1.0 + player.spd * 0.05)
    enemy_atb.speed  = M.CONFIG.ATB_BASE_SPEED * (1.0 + enemy.spd * 0.05)

    -- รีเซ็ต Soul
    soul.x = 0; soul.y = 0
    soul.speed = M.CONFIG.SOUL_SPEED
    soul.hitbox_r = 4
    soul.invincible = 0
    soul.iframes = 0.0

    -- รีเซ็ตกระสุน
    _clear_bullets()

    -- รีเซ็ต Visuals
    _visuals.cmd_cursor = 1
    _visuals.submenu_cursor = 1
    _visuals.show_submenu = false
    _visuals.shake_timer = 0
    _visuals.miss_text_timer = 0

    -- รีเซ็ต Dialogue
    _dialogue_queue = enemyData.dialogues or {}
    _dialogue_index = 0
    _dialogue_timer = 0

    -- คำนวณตำแหน่งเริ่มต้น
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    M._calc_layout(sw, sh)
    _visuals.player_x = _visuals.player_target_x
    _visuals.enemy_x  = _visuals.enemy_target_x

    _trigger("on_battle_start", saveData, enemyData)

    -- เริ่มเทิร์นแรก -> เข้าสู่ PHASE_COMMAND
    _set_phase(M.PHASE_COMMAND)
    state.turn_count = 1
end

--- อัปเดตลอจิกต่อสู้ (เรียกจาก love.update ผ่าน StateManager)
function M.update(dt)
    if state.battle_ended == 1 then return end
    if state.phase == M.PHASE_IDLE then return end

    local v = _visuals

    -- อัปเดต shake effect
    if v.shake_timer > 0 then
        v.shake_timer = v.shake_timer - dt
        v.shake_x = (math.random() - 0.5) * 8
        v.shake_y = (math.random() - 0.5) * 8
        if v.shake_timer <= 0 then
            v.shake_x = 0; v.shake_y = 0
        end
    end

    -- อัปเดต miss text
    if v.miss_text_timer > 0 then
        v.miss_text_timer = v.miss_text_timer - dt
    end

    -- =====================================================================
    -- PHASE: COMMAND SELECT (เลือกคำสั่ง D-Pad)
    -- =====================================================================
    if state.phase == M.PHASE_COMMAND then
        -- ATB ของผู้เล่นเติมถ้ายังไม่พร้อม
        if player_atb.ready == 0 then
            local spd = _get_atb_speed(player_atb)
            player_atb.current = player_atb.current + spd * dt
            if player_atb.current >= M.CONFIG.ATB_MAX then
                player_atb.current = M.CONFIG.ATB_MAX
                player_atb.ready = 1
            end
        end

        -- ATB ศัตรูเติมไปเรื่อย ๆ (รอเทิร์นโจมตี)
        if enemy_atb.ready == 0 then
            enemy_atb.current = enemy_atb.current + enemy_atb.speed * dt
            if enemy_atb.current >= M.CONFIG.ATB_MAX then
                enemy_atb.current = M.CONFIG.ATB_MAX
                enemy_atb.ready = 1
                -- ศัตรูพร้อมโจมตี -> เข้าสู่ Bullet-Hell
                M._start_enemy_turn()
                return
            end
        end

        -- รับอินพุต D-Pad (ตรวจสอบผ่าน controller หรือ keyboard)
        M._handle_command_input()

    -- =====================================================================
    -- PHASE: SUBMENU (เลือกจาก Act / Item / SP)
    -- =====================================================================
    elseif state.phase == M.PHASE_SUBMENU then
        M._handle_submenu_input()

    -- =====================================================================
    -- PHASE: BULLET HELL (กล่องหลบกระสุน)
    -- =====================================================================
    elseif state.phase == M.PHASE_BULLET_HELL then
        M._update_bullet_hell(dt)

    -- =====================================================================
    -- PHASE: DIALOGUE (แสดงบทสนทนา)
    -- =====================================================================
    elseif state.phase == M.PHASE_DIALOGUE then
        M._update_dialogue(dt)

    -- =====================================================================
    -- PHASE: RESULT (จบการต่อสู้)
    -- =====================================================================
    elseif state.phase == M.PHASE_RESULT then
        -- รออินพุตเพื่อกลับไปฉากโลก
        if controller and controller.isDown then
            if controller.isDown("confirm") or controller.isDown("attack") then
                M._exit_battle()
            end
        end
    end
end

--- วาดภาพต่อสู้ (เรียกจาก love.draw ผ่าน StateManager)
function M.draw()
    if state.phase == M.PHASE_IDLE then return end

    local v = _visuals
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()

    love.graphics.push()
    love.graphics.translate(v.shake_x, v.shake_y)

    -- พื้นหลัง (placeholder)
    love.graphics.setColor(0.08, 0.08, 0.12, 1)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    -- วาดสไปรท์ผู้เล่นและศัตรู (placeholder positions)
    love.graphics.setColor(0.4, 0.7, 1.0, 1)
    love.graphics.rectangle("fill", v.player_x, v.player_y, 80, 120)
    love.graphics.setColor(1.0, 0.3, 0.3, 1)
    love.graphics.rectangle("fill", v.enemy_x, v.enemy_y, 80, 120)

    -- วาดชื่อ
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("PLAYER", v.player_x, v.player_y - 20)
    love.graphics.print("ENEMY", v.enemy_x, v.enemy_y - 20)

    -- =====================================================================
    -- วาดตาม Phase
    -- =====================================================================
    if state.phase == M.PHASE_COMMAND or state.phase == M.PHASE_SUBMENU then
        M._draw_command_ui()
        M._draw_atb_gauges()
        M._draw_hp_bar()
    elseif state.phase == M.PHASE_BULLET_HELL then
        M._draw_bullet_hell()
    elseif state.phase == M.PHASE_DIALOGUE then
        M._draw_dialogue()
    elseif state.phase == M.PHASE_RESULT then
        M._draw_result()
    end

    -- วาด "MISS" ถ้าหลบได้สมบูรณ์
    if v.miss_text_timer > 0 then
        love.graphics.setColor(1, 1, 0.2, v.miss_text_timer * 2)
        local mx = v.player_x + 40
        local my = v.player_y - 40
        love.graphics.print("MISS!", mx, my)
    end

    love.graphics.pop()
end

--- ปิดระบบต่อสู้ (เรียกจาก StateManager เมื่อสลับฉาก)
function M.exit()
    _set_phase(M.PHASE_IDLE)
    _clear_bullets()
    _trigger("on_battle_end", state.pacifist_end == 1)
end

-- =============================================================================
-- 6. Input Handling (D-Pad & Submenu)
-- =============================================================================

function M._handle_command_input()
    local ctrl = controller
    if not ctrl then return end

    local v = _visuals

    -- นำทาง D-Pad (วนลูป 4 ทิศ)
    if ctrl.isDown("up") then
        v.cmd_cursor = 1
    elseif ctrl.isDown("down") then
        v.cmd_cursor = 2
    elseif ctrl.isDown("right") then
        v.cmd_cursor = 3
    elseif ctrl.isDown("left") then
        v.cmd_cursor = 4
    end

    -- ยืนยันคำสั่ง
    if ctrl.isDown("confirm") or ctrl.isDown("attack") then
        local sel = _command_menu[v.cmd_cursor]
        if sel then
            M._execute_command(sel.cmd)
        end
    end
end

function M._handle_submenu_input()
    local ctrl = controller
    if not ctrl then return end

    local v = _visuals

    if ctrl.isDown("up") then
        v.submenu_cursor = v.submenu_cursor - 1
        if v.submenu_cursor < 1 then v.submenu_cursor = #_act_submenu end
    elseif ctrl.isDown("down") then
        v.submenu_cursor = v.submenu_cursor + 1
        if v.submenu_cursor > #_act_submenu then v.submenu_cursor = 1 end
    end

    if ctrl.isDown("confirm") then
        local sel = _act_submenu[v.submenu_cursor]
        M._execute_act(sel.cmd)
        v.show_submenu = false
        _set_phase(M.PHASE_COMMAND)
    end

    if ctrl.isDown("cancel") then
        v.show_submenu = false
        _set_phase(M.PHASE_COMMAND)
    end
end

-- =============================================================================
-- 7. Command Execution Logic
-- =============================================================================

function M._execute_command(cmd)
    if cmd == M.CMD_ATTACK then
        M._cmd_attack()
    elseif cmd == M.CMD_ITEM then
        M._cmd_item()
    elseif cmd == M.CMD_ACT then
        -- เปิด submenu
        _visuals.show_submenu = true
        _visuals.submenu_cursor = 1
        _set_phase(M.PHASE_SUBMENU)
        return
    elseif cmd == M.CMD_SP then
        M._cmd_sp()
    end
end

function M._cmd_attack()
    -- คำนวณดาเมจจากอาวุธที่สวมใส่ (placeholder)
    local weapon_atk = 5  -- ดึงจาก equipment system จริง
    local dmg = math.max(1, player.atk + weapon_atk - enemy.def)
    enemy.current_hp = enemy.current_hp - dmg

    -- Shake effect
    _visuals.shake_timer = 0.2

    -- ตรวจสอบจบการต่อสู้ (แบบไม่สันติ)
    if enemy.current_hp <= 0 then
        enemy.current_hp = 0
        state.battle_ended = 1
        state.pacifist_end = 0
        _set_phase(M.PHASE_RESULT)
        return
    end

    -- จบเทิร์นผู้เล่น -> รีเซ็ต ATB แล้วรอศัตรู
    _reset_atb(player_atb)
    _set_phase(M.PHASE_COMMAND)
    state.turn_count = state.turn_count + 1
    _trigger("on_turn_end", state.turn_count)
end

function M._cmd_item()
    -- Placeholder: เปิด inventory หรือใช้ไอเทมเร่งด่วน
    -- ใน demo ให้ข้ามไปรอศัตรูโจมตี
    _reset_atb(player_atb)
    _set_phase(M.PHASE_COMMAND)
    state.turn_count = state.turn_count + 1
end

function M._execute_act(act_cmd)
    if act_cmd == M.ACT_CHECK then
        M._push_dialogue("* Enemy looks determined.
* ATK " .. enemy.atk .. " DEF " .. enemy.def .. ".")
        _set_phase(M.PHASE_DIALOGUE)

    elseif act_cmd == M.ACT_SPARE then
        if state.enemy_spare_meter >= M.CONFIG.SPARE_METER_MAX then
            M._push_dialogue("* You spared the enemy peacefully.")
            state.battle_ended = 1
            state.pacifist_end = 1
            _set_phase(M.PHASE_RESULT)
        else
            M._push_dialogue("* The enemy is not ready to be spared yet.")
            _set_phase(M.PHASE_DIALOGUE)
        end

    elseif act_cmd == M.ACT_TALK then
        state.enemy_spare_meter = state.enemy_spare_meter + 25
        if state.enemy_spare_meter > M.CONFIG.SPARE_METER_MAX then
            state.enemy_spare_meter = M.CONFIG.SPARE_METER_MAX
        end
        M._push_dialogue("* You tried to talk to the enemy.
* Their willingness increased!")
        _set_phase(M.PHASE_DIALOGUE)
    end
end

function M._cmd_sp()
    -- Placeholder: ใช้ SP Skill / Magic
    if player.sp >= 5 then
        player.sp = player.sp - 5
        local dmg = math.max(1, player.atk * 2 - enemy.def)
        enemy.current_hp = enemy.current_hp - dmg
        _visuals.shake_timer = 0.3
        M._push_dialogue("* You cast a spell!")
        _set_phase(M.PHASE_DIALOGUE)
    else
        M._push_dialogue("* Not enough SP!")
        _set_phase(M.PHASE_DIALOGUE)
    end
end

-- =============================================================================
-- 8. Bullet-Hell Phase Logic
-- =============================================================================

function M._start_enemy_turn()
    _set_phase(M.PHASE_BULLET_HELL)
    state.paused = 1  -- หยุด ATB ทั้งหมด
    state.perfect_dodge = 1  -- สมมติว่าหลบได้จนกว่าจะโดน

    -- วาง Soul ตรงกลางกล่อง
    soul.x = state.box_x + state.box_w * 0.5
    soul.y = state.box_y + state.box_h * 0.5
    soul.invincible = 0
    soul.iframes = 0.0

    -- สร้างกระสุนตาม pattern (placeholder: สุ่ม)
    _clear_bullets()
    local pattern = state.turn_count % 3
    if pattern == 1 then
        -- Pattern A: กระสุนตกลงมา
        for i = 1, 20 do
            local bx = state.box_x + math.random() * state.box_w
            local by = state.box_y - 20 - math.random() * 100
            _spawn_bullet(bx, by, 0, 80 + math.random() * 60, 6, 6, M.BULLET_NORMAL, 5)
        end
    elseif pattern == 2 then
        -- Pattern B: กระสุนโฮมมิ่ง
        for i = 1, 12 do
            local angle = (i / 12) * math.pi * 2
            local bx = soul.x + math.cos(angle) * 120
            local by = soul.y + math.sin(angle) * 120
            _spawn_bullet(bx, by, 0, 0, 8, 8, M.BULLET_HOMING, 8)
        end
    else
        -- Pattern C: คลื่นกระสุน
        for i = 1, 30 do
            local bx = state.box_x + (i / 30) * state.box_w
            local by = state.box_y + math.sin(i * 0.5) * 30
            _spawn_bullet(bx, by, -40, 0, 5, 5, M.BULLET_WAVE, 4)
        end
    end

    -- ตั้งเวลาอัตโนมัติสำหรับเฟสนี้
    state.bullet_hell_timer = M.CONFIG.BULLET_HELL_DURATION
end

function M._update_bullet_hell(dt)
    local ctrl = controller
    local box = state

    -- ควบคุม Soul ด้วย D-Pad / Analog
    local move_x, move_y = 0, 0
    if ctrl then
        if ctrl.isDown("left")  then move_x = move_x - 1 end
        if ctrl.isDown("right") then move_x = move_x + 1 end
        if ctrl.isDown("up")    then move_y = move_y - 1 end
        if ctrl.isDown("down")  then move_y = move_y + 1 end
        -- Analog support
        local ax, ay = ctrl.getAxis and ctrl.getAxis() or 0, 0
        if math.abs(ax) > 0.2 then move_x = ax end
        if math.abs(ay) > 0.2 then move_y = ay end
    end

    -- Normalize
    local len = math.sqrt(move_x * move_x + move_y * move_y)
    if len > 1 then
        move_x = move_x / len
        move_y = move_y / len
    end

    -- อัปเดตตำแหน่ง Soul
    soul.x = soul.x + move_x * soul.speed * dt
    soul.y = soul.y + move_y * soul.speed * dt

    -- Clamp ในกล่อง
    local margin = soul.hitbox_r
    soul.x = _clamp(soul.x, box.box_x + margin, box.box_x + box.box_w - margin)
    soul.y = _clamp(soul.y, box.box_y + margin, box.box_y + box.box_h - margin)

    -- อัปเดต iframes
    if soul.iframes > 0 then
        soul.iframes = soul.iframes - dt
        if soul.iframes <= 0 then
            soul.invincible = 0
            soul.iframes = 0
        end
    end

    -- อัปเดตกระสุนทั้งหมด
    local hit = false
    for i = 0, M.CONFIG.BULLET_POOL_SIZE - 1 do
        local b = bullets[i]
        if b.active == 1 then
            -- อัปเดตตำแหน่งกระสุน
            if b.type == M.BULLET_HOMING then
                -- Homing: มุ่งหน้าไปหา Soul
                _tmp_dx = soul.x - b.x
                _tmp_dy = soul.y - b.y
                _tmp_dist = math.sqrt(_tmp_dx * _tmp_dx + _tmp_dy * _tmp_dy)
                if _tmp_dist > 0.1 then
                    b.vx = (_tmp_dx / _tmp_dist) * 90
                    b.vy = (_tmp_dy / _tmp_dist) * 90
                end
            elseif b.type == M.BULLET_WAVE then
                b.vy = math.sin(love.timer.getTime() * 4 + i) * 60
            end

            b.x = b.x + b.vx * dt
            b.y = b.y + b.vy * dt
            b.lifetime = b.lifetime - dt

            -- ตรวจสอบชนกับ Soul
            if soul.invincible == 0 then
                _tmp_dx = soul.x - b.x
                _tmp_dy = soul.y - b.y
                _tmp_dist = math.sqrt(_tmp_dx * _tmp_dx + _tmp_dy * _tmp_dy)
                if _tmp_dist < (soul.hitbox_r + b.w * 0.5) then
                    -- โดนกระสุน!
                    hit = true
                    state.perfect_dodge = 0
                    local dmg = math.max(1, b.damage - player.def)
                    player.current_hp = player.current_hp - dmg
                    soul.invincible = 1
                    soul.iframes = M.CONFIG.SOUL_IFRAMES
                    _visuals.shake_timer = 0.15

                    -- ตรวจสอบ Game Over
                    if player.current_hp <= 0 then
                        player.current_hp = 0
                        state.battle_ended = 1
                        state.pacifist_end = 0
                        _set_phase(M.PHASE_RESULT)
                        return
                    end
                end
            end

            -- ปิดใช้งานกระสุนที่หมดอายุหรือออกนอกกล่อง
            if b.lifetime <= 0
               or b.x < box.box_x - 50 or b.x > box.box_x + box.box_w + 50
               or b.y < box.box_y - 50 or b.y > box.box_y + box.box_h + 50 then
                b.active = 0
            end
        end
    end

    -- นับถอยหลังเฟสกระสุน
    state.bullet_hell_timer = state.bullet_hell_timer - dt
    if state.bullet_hell_timer <= 0 then
        M._end_bullet_hell()
    end
end

function M._end_bullet_hell()
    _clear_bullets()
    state.paused = 0

    if state.perfect_dodge == 1 then
        -- Perfect Dodge: เติม ATB เต็มทันที + แสดง "MISS"
        player_atb.current = M.CONFIG.ATB_MAX
        player_atb.ready = 1
        _visuals.miss_text_timer = 1.5
        M._push_dialogue("* You dodged flawlessly! ATB fully charged!")
        _set_phase(M.PHASE_DIALOGUE)
    else
        -- Partial/Hit: โบนัสความเร็ว ATB
        player_atb.bonus_speed = 1.0
        player_atb.bonus_timer = M.CONFIG.ATB_BONUS_DURATION
        M._push_dialogue("* You took some damage. ATB recovering faster!")
        _set_phase(M.PHASE_DIALOGUE)
    end

    _reset_atb(enemy_atb)
    state.turn_count = state.turn_count + 1
    _trigger("on_turn_end", state.turn_count)
end

-- =============================================================================
-- 9. Dialogue System (In-Battle)
-- =============================================================================

function M._push_dialogue(text)
    table.insert(_dialogue_queue, text)
    if state.phase ~= M.PHASE_DIALOGUE then
        _dialogue_index = #_dialogue_queue
        _dialogue_timer = 0
    end
end

function M._update_dialogue(dt)
    _dialogue_timer = _dialogue_timer + dt
    -- รออินพุตเพื่อไปข้อความถัดไป หรือกลับไป COMMAND
    local ctrl = controller
    if ctrl and (ctrl.isDown("confirm") or ctrl.isDown("attack")) then
        if _dialogue_timer > 0.3 then
            _dialogue_index = _dialogue_index + 1
            _dialogue_timer = 0
            if _dialogue_index > #_dialogue_queue then
                -- หมดคิว -> กลับไป COMMAND
                _dialogue_queue = {}
                _dialogue_index = 0
                if not state.battle_ended then
                    _set_phase(M.PHASE_COMMAND)
                end
            end
        end
    end
end

-- =============================================================================
-- 10. Drawing Functions
-- =============================================================================

function M._draw_command_ui()
    local v = _visuals
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    local cx = sw * 0.5
    local cy = sh - 90

    -- วาด D-Pad 4 ทิศทาง
    for i, item in ipairs(_command_menu) do
        local ox, oy = 0, 0
        if i == 1 then oy = -40      -- Up
        elseif i == 2 then oy = 40   -- Down
        elseif i == 3 then ox = 50   -- Right
        elseif i == 4 then ox = -50  -- Left
        end

        local selected = (v.cmd_cursor == i)
        if selected then
            love.graphics.setColor(1, 0.8, 0.2, 1)
            love.graphics.rectangle("line", cx + ox - 35, cy + oy - 15, 70, 30)
        else
            love.graphics.setColor(0.5, 0.5, 0.5, 0.6)
        end
        love.graphics.print(item.label, cx + ox - 20, cy + oy - 6)
    end

    -- วาด Submenu (ถ้าเปิด)
    if v.show_submenu then
        local sx = cx + 60
        local sy = cy - 20
        love.graphics.setColor(0.1, 0.1, 0.15, 0.95)
        love.graphics.rectangle("fill", sx, sy, 160, 80)
        love.graphics.setColor(0.6, 0.6, 0.7, 1)
        love.graphics.rectangle("line", sx, sy, 160, 80)

        for i, item in ipairs(_act_submenu) do
            if v.submenu_cursor == i then
                love.graphics.setColor(1, 0.9, 0.3, 1)
                love.graphics.print("> " .. item.label, sx + 10, sy + 8 + (i - 1) * 22)
            else
                love.graphics.setColor(0.8, 0.8, 0.8, 1)
                love.graphics.print("  " .. item.label, sx + 10, sy + 8 + (i - 1) * 22)
            end
        end
    end
end

function M._draw_atb_gauges()
    local function draw_gauge(x, y, w, h, gauge, label, color)
        love.graphics.setColor(0.2, 0.2, 0.25, 1)
        love.graphics.rectangle("fill", x, y, w, h)
        local fill = (gauge.current / M.CONFIG.ATB_MAX) * w
        love.graphics.setColor(color[1], color[2], color[3], 1)
        love.graphics.rectangle("fill", x, y, fill, h)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(label .. " " .. math.floor(gauge.current) .. "%", x, y - 14)
    end

    local sw = love.graphics.getWidth()
    draw_gauge(20, 20, 150, 12, player_atb, "PLAYER", {0.2, 0.8, 0.3})
    draw_gauge(20, 42, 150, 12, enemy_atb,  "ENEMY",  {0.9, 0.2, 0.2})
end

function M._draw_hp_bar()
    local v = _visuals
    local x, y = v.hp_bar_x, v.hp_bar_y
    local w, h = 140, 16
    local hp_pct = player.current_hp / player.max_hp

    love.graphics.setColor(0.2, 0.2, 0.2, 1)
    love.graphics.rectangle("fill", x, y, w, h)
    love.graphics.setColor(0.9, 0.2, 0.2, 1)
    love.graphics.rectangle("fill", x, y, w * hp_pct, h)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("HP: " .. player.current_hp .. "/" .. player.max_hp, x, y - 16)

    -- SP Bar (ใต้ HP)
    local sp_pct = player.sp / player.max_sp
    love.graphics.setColor(0.15, 0.15, 0.2, 1)
    love.graphics.rectangle("fill", x, y + 22, w, 10)
    love.graphics.setColor(0.3, 0.5, 1.0, 1)
    love.graphics.rectangle("fill", x, y + 22, w * sp_pct, 10)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("SP: " .. player.sp, x, y + 22)
end

function M._draw_bullet_hell()
    local box = state

    -- วาดกล่อง
    love.graphics.setColor(0.05, 0.05, 0.08, 0.9)
    love.graphics.rectangle("fill", box.box_x, box.box_y, box.box_w, box.box_h)
    love.graphics.setColor(0.8, 0.8, 0.9, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", box.box_x, box.box_y, box.box_w, box.box_h)
    love.graphics.setLineWidth(1)

    -- วาด Soul
    if soul.iframes > 0 and math.floor(love.timer.getTime() * 10) % 2 == 0 then
        -- กระพริบตอนอมตะ
        love.graphics.setColor(1, 1, 1, 0.4)
    else
        love.graphics.setColor(1, 0.2, 0.5, 1)
    end
    love.graphics.circle("fill", soul.x, soul.y, soul.hitbox_r)

    -- วาดกระสุน
    for i = 0, M.CONFIG.BULLET_POOL_SIZE - 1 do
        local b = bullets[i]
        if b.active == 1 then
            if b.type == M.BULLET_NORMAL then
                love.graphics.setColor(1, 0.4, 0.4, 1)
            elseif b.type == M.BULLET_HOMING then
                love.graphics.setColor(0.9, 0.2, 0.9, 1)
            else
                love.graphics.setColor(0.4, 0.8, 1.0, 1)
            end
            love.graphics.rectangle("fill", b.x - b.w * 0.5, b.y - b.h * 0.5, b.w, b.h)
        end
    end

    -- วาดเวลาที่เหลือ
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.print(string.format("%.1f", box.bullet_hell_timer), box.box_x + 5, box.box_y - 18)
end

function M._draw_dialogue()
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    local box_h = 100

    -- กล่องข้อความ
    love.graphics.setColor(0.05, 0.05, 0.08, 0.92)
    love.graphics.rectangle("fill", 20, sh - box_h - 20, sw - 40, box_h)
    love.graphics.setColor(0.6, 0.6, 0.7, 1)
    love.graphics.rectangle("line", 20, sh - box_h - 20, sw - 40, box_h)

    -- ข้อความปัจจุบัน
    if _dialogue_index > 0 and _dialogue_index <= #_dialogue_queue then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(_dialogue_queue[_dialogue_index], 35, sh - box_h + 5)
    end

    -- ไอคอนกระพริบบอกให้กด
    if math.floor(love.timer.getTime() * 3) % 2 == 0 then
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.print("▼", sw - 50, sh - 40)
    end
end

function M._draw_result()
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()

    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    love.graphics.setColor(1, 1, 1, 1)
    local msg
    if state.pacifist_end == 1 then
        msg = "* You won peacefully!"
    elseif player.current_hp <= 0 then
        msg = "* You were defeated..."
    else
        msg = "* Battle ended."
    end
    love.graphics.print(msg, sw * 0.5 - 60, sh * 0.5 - 10)
    love.graphics.print("Press CONFIRM to continue", sw * 0.5 - 80, sh * 0.5 + 20)
end

-- =============================================================================
-- 11. Exit & Cleanup
-- =============================================================================

function M._exit_battle()
    M.exit()
    -- ส่งสัญญาณให้ StateManager สลับกลับไปฉากโลก
    if StateManager and StateManager.switch then
        StateManager.switch("world", M.serialize_result())
    end
end

function M.serialize_result()
    return {
        player_hp = player.current_hp,
        player_sp = player.sp,
        pacifist = state.pacifist_end == 1,
        turns = state.turn_count,
        enemy_spare_meter = state.enemy_spare_meter,
    }
end

-- =============================================================================
-- 12. Public API for External Systems
-- =============================================================================

--- ลงทะเบียน Callback
function M.on(event, fn)
    if not _callbacks[event] then _callbacks[event] = {} end
    table.insert(_callbacks[event], fn)
end

--- ยกเลิก Callback
function M.off(event, fn)
    local cbs = _callbacks[event]
    if not cbs then return end
    for i = #cbs, 1, -1 do
        if cbs[i] == fn then table.remove(cbs, i) end
    end
end

--- บังคับเข้าสู่ Bullet-Hell (สำหรับทดสอบหรือ Event)
function M.force_bullet_hell()
    M._start_enemy_turn()
end

--- บังคับจบการต่อสู้
function M.force_end(pacifist)
    state.battle_ended = 1
    state.pacifist_end = pacifist and 1 or 0
    _set_phase(M.PHASE_RESULT)
end

--- ดึงสถานะปัจจุบัน (read-only reference)
function M.get_state()
    return state
end

function M.get_player_stats()
    return player
end

function M.get_enemy_stats()
    return enemy
end

-- =============================================================================
-- 13. Return Module
-- =============================================================================
return M
