-- date_time_system.lua
-- ============================================================
-- ระบบเวลาและวันในเกม (Game Date & Time System)
-- สไตล์ Stardew Valley - ใช้ LuaJIT FFI เพื่อประสิทธิภาพสูง
-- 
-- กฎของระบบ:
--   - มีทั้งหมด 14 วันในเกม
--   - ไม่มีระบบฤดูกาล
--   - เวลาในแต่ละวัน: 07:00 น. ถึง 22:00 น. (4 ทุ่ม)
--   - ใช้ LuaJIT FFI จัดการข้อมูลในรูปแบบ C Struct (Zero-GC)
-- ============================================================

local ffi = require("ffi")
local os = os
local tonumber = tonumber
local tostring = tostring
local string = string
local math = math

-- ============================================================
-- 1. นิยามโครงสร้างข้อมูลภาษา C (C Struct Definitions)
-- ============================================================
ffi.cdef[[
    typedef struct {
        int    day;            // วันที่ปัจจุบัน (1 - 14)
        int    hour;           // ชั่วโมง (7 - 22)
        int    minute;         // นาที (0 - 59)
        float  second;         // วินาที (0.0 - 59.999)
        float  time_scale;     // อัตราเร็วเวลา (1.0 = ปกติ)
        int    is_running;     // สถานะกำลังเดิน (1 = รัน, 0 = หยุด)
        int    is_paused;      // สถานะหยุดชั่วคราว (1 = หยุด, 0 = รัน)
        float  day_progress;   // ความคืบหน้าของวัน 0.0 (07:00) -> 1.0 (22:00)
        int    total_days;     // จำนวนวันทั้งหมดของเกม (14)
        int    start_hour;     // ชั่วโมงเริ่มต้นของวัน (7)
        int    end_hour;       // ชั่วโมงสิ้นสุดของวัน (22)
        int    hour_changed;   // flag: มีการเปลี่ยนชั่วโมงในเฟรมนี้ (1 = ใช่)
        int    day_changed;    // flag: มีการเปลี่ยนวันในเฟรมนี้ (1 = ใช่)
        int    game_over;      // flag: จบเกมแล้ว (1 = จบ, 0 = ยังไม่จบ)
    } GameTime;
]]

-- ============================================================
-- 2. สร้างอินสแตนซ์ข้อมูล C (Allocate C Struct in Memory)
--    ข้อมูลนี้อยู่นอก Lua GC -> ไม่สร้างขยะ -> ไม่กระตุก
-- ============================================================
local gt = ffi.new("GameTime")

-- ============================================================
-- 3. ตัวแปรภายใน (Internal State)
-- ============================================================
local callbacks = {
    on_hour_change = {},
    on_day_change  = {},
    on_game_over   = {},
    on_time_start  = {},
    on_time_end    = {},
}

-- ค่าคงที่
local REAL_SECONDS_PER_GAME_MINUTE = 0.7  -- 1 นาทีในเกม = 0.7 วินาทีจริง (ปรับได้)

-- ============================================================
-- 4. ฟังก์ชันหลักของระบบ (Core Functions)
-- ============================================================

local M = {}

--- เริ่มต้นระบบเวลาใหม่ (Reset / Init)
function M.init()
    gt.day          = 1
    gt.hour         = 7
    gt.minute       = 0
    gt.second       = 0.0
    gt.time_scale   = 1.0
    gt.is_running   = 1
    gt.is_paused    = 0
    gt.day_progress = 0.0
    gt.total_days   = 14
    gt.start_hour   = 7
    gt.end_hour     = 22
    gt.hour_changed = 0
    gt.day_changed  = 0
    gt.game_over    = 0
end

--- อัปเดตเวลาในแต่ละเฟรม (เรียกใน love.update)
-- @param dt float - Delta Time จาก Love2D
function M.update(dt)
    -- รีเซ็ต flag การเปลี่ยนแปลงทุกเฟรม
    gt.hour_changed = 0
    gt.day_changed  = 0

    -- ถ้าหยุดหรือจบเกมแล้ว ไม่ต้องอัปเดต
    if gt.is_running == 0 or gt.is_paused == 1 or gt.game_over == 1 then
        return
    end

    -- คำนวณเวลาที่ผ่านไปในเกม (C-style arithmetic on struct)
    local game_minutes_passed = (dt * gt.time_scale) / REAL_SECONDS_PER_GAME_MINUTE
    gt.second = gt.second + (game_minutes_passed * 60.0)

    -- ปัดเศษวินาที -> นาที -> ชั่วโมง -> วัน (C-style loop)
    while gt.second >= 60.0 do
        gt.second = gt.second - 60.0
        gt.minute = gt.minute + 1

        if gt.minute >= 60 then
            gt.minute = 0
            gt.hour   = gt.hour + 1
            gt.hour_changed = 1

            -- เรียก Callback เมื่อเปลี่ยนชั่วโมง
            M._trigger("on_hour_change", gt.hour, gt.day)

            if gt.hour >= gt.end_hour then
                -- สิ้นสุดวัน (ถึง 22:00 แล้ว)
                gt.hour = gt.start_hour
                gt.minute = 0
                gt.second = 0.0
                gt.day = gt.day + 1
                gt.day_changed = 1

                -- เรียก Callback เมื่อเปลี่ยนวัน
                M._trigger("on_day_change", gt.day - 1, gt.day)

                if gt.day > gt.total_days then
                    -- จบเกม (ครบ 14 วันแล้ว)
                    gt.day = gt.total_days
                    gt.is_running = 0
                    gt.game_over = 1
                    M._trigger("on_game_over")
                    return
                end
            end
        end
    end

    -- คำนวณ day_progress (0.0 ที่ 07:00, 1.0 ที่ 22:00)
    local total_day_minutes = (gt.end_hour - gt.start_hour) * 60
    local current_minutes   = (gt.hour - gt.start_hour) * 60 + gt.minute + (gt.second / 60.0)
    gt.day_progress = current_minutes / total_day_minutes
    if gt.day_progress < 0 then gt.day_progress = 0 end
    if gt.day_progress > 1 then gt.day_progress = 1 end
end

--- หยุดเวลาชั่วคราว (Pause)
function M.pause()
    gt.is_paused = 1
end

--- เริ่มเวลาต่อ (Resume)
function M.resume()
    gt.is_paused = 0
end

--- สลับสถานะหยุด/เล่น (Toggle Pause)
function M.toggle_pause()
    gt.is_paused = 1 - gt.is_paused
end

--- ตั้งค่าความเร็วเวลา
-- @param scale float - ค่าความเร็ว (1.0 = ปกติ, 2.0 = เร็ว 2 เท่า, 0.5 = ช้าครึ่ง)
function M.set_time_scale(scale)
    gt.time_scale = tonumber(scale) or 1.0
end

--- ดึงค่าความเร็วเวลาปัจจุบัน
function M.get_time_scale()
    return gt.time_scale
end

--- ข้ามไปยังเวลาที่กำหนดในวันปัจจุบัน
-- @param h int - ชั่วโมง (7-22)
-- @param m int - นาที (0-59) [optional]
function M.set_time(h, m)
    h = tonumber(h) or 7
    m = tonumber(m) or 0
    if h < gt.start_hour then h = gt.start_hour end
    if h >= gt.end_hour then h = gt.end_hour; m = 0 end
    if m < 0 then m = 0 end
    if m > 59 then m = 59 end
    gt.hour = h
    gt.minute = m
    gt.second = 0.0
end

--- ข้ามไปยังวันที่กำหนด
-- @param day int - วันที่ (1-14)
function M.set_day(day)
    day = tonumber(day) or 1
    if day < 1 then day = 1 end
    if day > gt.total_days then day = gt.total_days end
    gt.day = day
    gt.hour = gt.start_hour
    gt.minute = 0
    gt.second = 0.0
    gt.game_over = 0
    if day >= gt.total_days then
        gt.is_running = 0
    else
        gt.is_running = 1
    end
end

-- ============================================================
-- 5. ฟังก์ชันดึงข้อมูล (Getters)
-- ============================================================

--- ดึงวันที่ปัจจุบัน (1-14)
function M.get_day()
    return gt.day
end

--- ดึงชั่วโมงปัจจุบัน (7-22)
function M.get_hour()
    return gt.hour
end

--- ดึงนาทีปัจจุบัน (0-59)
function M.get_minute()
    return gt.minute
end

--- ดึงวินาทีปัจจุบัน (0.0-59.9)
function M.get_second()
    return gt.second
end

--- ดึงความคืบหน้าของวัน (0.0 - 1.0)
function M.get_day_progress()
    return gt.day_progress
end

--- ดึงจำนวนวันทั้งหมด (14)
function M.get_total_days()
    return gt.total_days
end

--- ดึงชั่วโมงเริ่มต้น (7)
function M.get_start_hour()
    return gt.start_hour
end

--- ดึงชั่วโมงสิ้นสุด (22)
function M.get_end_hour()
    return gt.end_hour
end

--- ตรวจสอบว่าจบเกมแล้วหรือไม่
function M.is_game_over()
    return gt.game_over == 1
end

--- ตรวจสอบว่ากำลังหยุดอยู่หรือไม่
function M.is_paused()
    return gt.is_paused == 1
end

--- ตรวจสอบว่าเวลากำลังเดินอยู่หรือไม่
function M.is_running()
    return gt.is_running == 1
end

--- ตรวจสอบว่ามีการเปลี่ยนชั่วโมงในเฟรมนี้หรือไม่
function M.hour_changed()
    return gt.hour_changed == 1
end

--- ตรวจสอบว่ามีการเปลี่ยนวันในเฟรมนี้หรือไม่
function M.day_changed()
    return gt.day_changed == 1
end

-- ============================================================
-- 6. ฟังก์ชันแสดงผลเวลา (Formatting)
-- ============================================================

--- แปลงเวลาเป็นสตริงรูปแบบ "HH:MM"
-- @param h int [optional] - ชั่วโมง (default = ปัจจุบัน)
-- @param m int [optional] - นาที (default = ปัจจุบัน)
function M.format_time(h, m)
    h = h or gt.hour
    m = m or gt.minute
    return string.format("%02d:%02d", h, m)
end

--- แปลงเวลาเป็นสตริงรูปแบบ "HH:MM:SS"
function M.format_time_full()
    return string.format("%02d:%02d:%02d", gt.hour, gt.minute, math.floor(gt.second))
end

--- แปลงวันที่เป็นสตริง "Day X / 14"
function M.format_day()
    return string.format("Day %d / %d", gt.day, gt.total_days)
end

--- แปลงเวลาเป็นสตริงแบบ 12 ชั่วโมง พร้อม AM/PM
function M.format_time_12h()
    local h = gt.hour
    local ampm = "AM"
    if h >= 12 then
        ampm = "PM"
        if h > 12 then h = h - 12 end
    elseif h == 0 then
        h = 12
    end
    return string.format("%02d:%02d %s", h, gt.minute, ampm)
end

--- ดึงข้อความสถานะเวลา (สำหรับ Debug)
function M.get_debug_string()
    local status = "RUNNING"
    if gt.game_over == 1 then status = "GAME OVER"
    elseif gt.is_paused == 1 then status = "PAUSED"
    elseif gt.is_running == 0 then status = "STOPPED"
    end
    return string.format(
        "[%s] Day %d/%d | %02d:%02d:%05.2f | Progress: %.1f%% | Scale: %.1fx",
        status, gt.day, gt.total_days, gt.hour, gt.minute, gt.second,
        gt.day_progress * 100, gt.time_scale
    )
end

-- ============================================================
-- 7. ระบบ Callback (Event System)
-- ============================================================

--- ลงทะเบียน Callback
-- @param event string - ชื่อเหตุการณ์
-- @param fn function - ฟังก์ชันที่จะเรียก
-- @return int - id สำหรับยกเลิก
function M.on(event, fn)
    if not callbacks[event] then
        callbacks[event] = {}
    end
    local id = #callbacks[event] + 1
    callbacks[event][id] = fn
    return id
end

--- ยกเลิก Callback
-- @param event string - ชื่อเหตุการณ์
-- @param id int - id ที่ได้จาก M.on()
function M.off(event, id)
    if callbacks[event] then
        callbacks[event][id] = nil
    end
end

--- เรียก Callback ภายใน (Internal)
function M._trigger(event, ...)
    if callbacks[event] then
        for _, fn in pairs(callbacks[event]) do
            local ok, err = pcall(fn, ...)
            if not ok then
                print("[date_time_system] Callback error (" .. event .. "): " .. tostring(err))
            end
        end
    end
end

-- ============================================================
-- 8. ฟังก์ชันช่วยเหลือสำหรับระบบแสง/กราฟิก (Light & Graphics Helpers)
-- ============================================================

--- คำนวณค่าความสว่างของบรรยากาศตามเวลา (0.0 = มืด, 1.0 = สว่าง)
-- เหมาะสำหรับใช้กับ Shader หรือ Canvas ความมืด
function M.get_ambient_light()
    local h = gt.hour + gt.minute / 60.0 + gt.second / 3600.0

    if h < 7 then
        return 0.1
    elseif h < 9 then
        -- 07:00 - 09:00 : มืด -> สว่าง (พระอาทิตย์ขึ้น)
        return 0.1 + 0.9 * ((h - 7) / 2.0)
    elseif h < 17 then
        -- 09:00 - 17:00 : สว่างเต็มที่
        return 1.0
    elseif h < 20 then
        -- 17:00 - 20:00 : สว่าง -> มืด (พระอาทิตย์ตก)
        return 1.0 - 0.9 * ((h - 17) / 3.0)
    else
        -- 20:00 - 22:00 : มืด
        return 0.1
    end
end

--- คำนวณสีบรรยากาศตามเวลา (คืนค่า r, g, b)
-- ค่าสีเหมาะสำหรับใช้กับ love.graphics.setColor หรือ Shader
function M.get_ambient_color()
    local h = gt.hour + gt.minute / 60.0
    local r, g, b

    if h < 6 then
        -- กลางดึก: น้ำเงินเข้ม
        r, g, b = 0.1, 0.1, 0.3
    elseif h < 7 then
        -- 05:00 - 07:00 : อินดิโก้ -> ส้มอมชมพู
        local t = h - 6
        r = 0.1 + 0.8 * t
        g = 0.1 + 0.4 * t
        b = 0.3 + 0.1 * t
    elseif h < 9 then
        -- 07:00 - 09:00 : ส้มอมชมพู -> ขาวฟ้า
        local t = (h - 7) / 2.0
        r = 0.9 + 0.1 * t
        g = 0.5 + 0.5 * t
        b = 0.4 + 0.6 * t
    elseif h < 16 then
        -- 09:00 - 16:00 : ขาวฟ้า (กลางวัน)
        r, g, b = 1.0, 1.0, 1.0
    elseif h < 18 then
        -- 16:00 - 18:00 : ขาวฟ้า -> ส้มทอง (เย็น)
        local t = (h - 16) / 2.0
        r = 1.0
        g = 1.0 - 0.2 * t
        b = 1.0 - 0.5 * t
    elseif h < 20 then
        -- 18:00 - 20:00 : ส้มทอง -> ม่วงน้ำเงิน
        local t = (h - 18) / 2.0
        r = 1.0 - 0.7 * t
        g = 0.8 - 0.6 * t
        b = 0.5 + 0.1 * t
    else
        -- 20:00 - 22:00 : ม่วงน้ำเงิน -> น้ำเงินเข้ม
        local t = (h - 20) / 2.0
        r = 0.3 - 0.2 * t
        g = 0.2 - 0.1 * t
        b = 0.6 - 0.3 * t
    end

    -- จำกัดค่าสีให้อยู่ในช่วง 0-1
    r = math.max(0, math.min(1, r))
    g = math.max(0, math.min(1, g))
    b = math.max(0, math.min(1, b))

    return r, g, b
end

--- คำนวณค่าความมืดสำหรับวาดทับหน้าจอ (0.0 = ไม่มืด, 1.0 = มืดสนิท)
function M.get_darkness_overlay()
    local light = M.get_ambient_light()
    return 1.0 - light
end

-- ============================================================
-- 9. ฟังก์ชันสำหรับบันทึก/โหลด (Save / Load)
-- ============================================================

--- แปลงสถานะปัจจุบันเป็นตาราง Lua (สำหรับบันทึก)
function M.serialize()
    return {
        day          = gt.day,
        hour         = gt.hour,
        minute       = gt.minute,
        second       = gt.second,
        time_scale   = gt.time_scale,
        is_running   = gt.is_running,
        is_paused    = gt.is_paused,
        game_over    = gt.game_over,
    }
end

--- โหลดสถานะจากตาราง Lua
-- @param data table - ข้อมูลที่ได้จาก serialize()
function M.deserialize(data)
    if not data then return end
    gt.day        = tonumber(data.day) or 1
    gt.hour       = tonumber(data.hour) or 7
    gt.minute     = tonumber(data.minute) or 0
    gt.second     = tonumber(data.second) or 0.0
    gt.time_scale = tonumber(data.time_scale) or 1.0
    gt.is_running = data.is_running and 1 or 0
    gt.is_paused  = data.is_paused and 1 or 0
    gt.game_over  = data.game_over and 1 or 0

    -- รีคำนวณ day_progress
    local total_day_minutes = (gt.end_hour - gt.start_hour) * 60
    local current_minutes   = (gt.hour - gt.start_hour) * 60 + gt.minute + (gt.second / 60.0)
    gt.day_progress = current_minutes / total_day_minutes
end

-- ============================================================
-- 10. ฟังก์ชันสำหรับ Love2D (Draw Helpers)
-- ============================================================

--- วาด UI แสดงเวลาและวัน (ตัวอย่าง)
-- @param x float - ตำแหน่ง X
-- @param y float - ตำแหน่ง Y
-- @param font love.Font [optional] - ฟอนต์ที่ใช้วาด
function M.draw_ui(x, y, font)
    if font then
        love.graphics.setFont(font)
    end

    local r, g, b = M.get_ambient_color()
    love.graphics.setColor(r, g, b, 1)

    -- วาดเวลา
    love.graphics.print(M.format_time(), x, y)

    -- วาดวัน
    love.graphics.print(M.format_day(), x, y + 20)

    -- วาดแถบความคืบหน้าของวัน
    local bar_w = 100
    local bar_h = 8
    love.graphics.setColor(0.3, 0.3, 0.3, 0.8)
    love.graphics.rectangle("fill", x, y + 45, bar_w, bar_h)
    love.graphics.setColor(r * 0.8, g * 0.8, b * 0.8, 1)
    love.graphics.rectangle("fill", x, y + 45, bar_w * gt.day_progress, bar_h)

    -- รีเซ็ตสี
    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================
-- 11. C Source Code (สำหรับคอมไพล์เป็น .dll / .so ในอนาทีต่อไป)
-- ============================================================
-- หากต้องการยกระดับประสิทธิภาพให้สูงสุด สามารถคอมไพล์ C โค้ดด้านล่าง
-- เป็นไลบรารีแยกแล้วโหลดผ่าน FFI ได้

M.C_SOURCE = [[
/* date_time_system.c - ฝั่ง C สำหรับคอมไพล์เป็นไลบรารี */
#include <stdio.h>
#include <string.h>

#ifdef _WIN32
  #define EXPORT __declspec(dllexport)
#else
  #define EXPORT __attribute__((visibility("default")))
#endif

typedef struct {
    int    day;
    int    hour;
    int    minute;
    float  second;
    float  time_scale;
    int    is_running;
    int    is_paused;
    float  day_progress;
    int    total_days;
    int    start_hour;
    int    end_hour;
    int    hour_changed;
    int    day_changed;
    int    game_over;
} GameTime;

static const float REAL_SECONDS_PER_GAME_MINUTE = 0.7f;

EXPORT void game_time_init(GameTime* gt) {
    gt->day = 1;
    gt->hour = 7;
    gt->minute = 0;
    gt->second = 0.0f;
    gt->time_scale = 1.0f;
    gt->is_running = 1;
    gt->is_paused = 0;
    gt->day_progress = 0.0f;
    gt->total_days = 14;
    gt->start_hour = 7;
    gt->end_hour = 22;
    gt->hour_changed = 0;
    gt->day_changed = 0;
    gt->game_over = 0;
}

EXPORT void game_time_update(GameTime* gt, float dt) {
    gt->hour_changed = 0;
    gt->day_changed = 0;

    if (gt->is_running == 0 || gt->is_paused == 1 || gt->game_over == 1) return;

    float game_minutes_passed = (dt * gt->time_scale) / REAL_SECONDS_PER_GAME_MINUTE;
    gt->second += game_minutes_passed * 60.0f;

    while (gt->second >= 60.0f) {
        gt->second -= 60.0f;
        gt->minute++;

        if (gt->minute >= 60) {
            gt->minute = 0;
            gt->hour++;
            gt->hour_changed = 1;

            if (gt->hour >= gt->end_hour) {
                gt->hour = gt->start_hour;
                gt->minute = 0;
                gt->second = 0.0f;
                gt->day++;
                gt->day_changed = 1;

                if (gt->day > gt->total_days) {
                    gt->day = gt->total_days;
                    gt->is_running = 0;
                    gt->game_over = 1;
                    return;
                }
            }
        }
    }

    float total_day_minutes = (float)(gt->end_hour - gt->start_hour) * 60.0f;
    float current_minutes = (float)(gt->hour - gt->start_hour) * 60.0f
                          + (float)gt->minute
                          + gt->second / 60.0f;
    gt->day_progress = current_minutes / total_day_minutes;
    if (gt->day_progress < 0.0f) gt->day_progress = 0.0f;
    if (gt->day_progress > 1.0f) gt->day_progress = 1.0f;
}

EXPORT int game_time_is_over(const GameTime* gt) {
    return gt->game_over;
}

EXPORT float game_time_get_day_progress(const GameTime* gt) {
    return gt->day_progress;
}

EXPORT void game_time_format(const GameTime* gt, char* buf, size_t len) {
    snprintf(buf, len, "Day %d/%d | %02d:%02d", gt->day, gt->total_days, gt->hour, gt->minute);
}
]]

--- คอมไพล์ C Source เป็นไลบรารี (ต้องมี gcc/clang ติดตั้ง)
-- @param output_name string - ชื่อไฟล์ output (ไม่ต้องใส่นามสกุล)
function M.compile_c_library(output_name)
    output_name = output_name or "date_time_system"
    local c_file = output_name .. ".c"
    local lib_file
    local cmd

    -- เขียนไฟล์ C
    local f = io.open(c_file, "w")
    f:write(M.C_SOURCE)
    f:close()

    -- ตรวจจับ OS และสร้างคำสั่งคอมไพล์
    if jit.os == "Windows" then
        lib_file = output_name .. ".dll"
        cmd = string.format("gcc -shared -O3 -o %s %s", lib_file, c_file)
    elseif jit.os == "OSX" then
        lib_file = output_name .. ".dylib"
        cmd = string.format("gcc -dynamiclib -O3 -o %s %s", lib_file, c_file)
    else
        lib_file = output_name .. ".so"
        cmd = string.format("gcc -shared -fPIC -O3 -o %s %s", lib_file, c_file)
    end

    print("[date_time_system] Compiling C library...")
    print("[date_time_system] Command: " .. cmd)
    local result = os.execute(cmd)

    if result == 0 then
        print("[date_time_system] Success: " .. lib_file)
        return lib_file
    else
        print("[date_time_system] Compile failed. Make sure gcc is installed.")
        return nil
    end
end

-- ============================================================
-- 12. เริ่มต้นระบบอัตโนมัติ (Auto-init)
-- ============================================================
M.init()

return M