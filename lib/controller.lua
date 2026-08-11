-- ==========================================
-- File: controller.lua (Extended Invisible Joystick Edition)
-- ==========================================
local controller = {}

-- 1. โครงสร้างข้อมูลปุ่มและอนาล็อก (ล็อกพื้นที่หน่วยความจำถาวร)
controller.joystick = {
    x = 0, y = 0, radius = 0,        -- ตำแหน่งศูนย์กลางของฐานจอย (ที่แสดงผล)
    stickX = 0, stickY = 0,          -- ตำแหน่งปุ่มตรงกลางที่ขยับจริง
    stickRadius = 0,
    dx = 0, dy = 0,                  -- ค่าเวกเตอร์ทิศทางส่งออก (-1 ถึง 1)
    activeTouchId = nil,             -- ล็อก ID นิ้วที่กำลังควบคุมจอย
    
    -- [ระบบแผงล่องหนพิกัดซ้ายล่าง]
    zoneW = 0, zoneH = 0             -- ขอบเขตพื้นที่เปิดรับการสัมผัสจอยสติ๊ก
}

controller.action = {
    a = {x = 0, y = 0, radius = 0, pressed = false},
    b = {x = 0, y = 0, radius = 0, pressed = false},
    x = {x = 0, y = 0, radius = 0, pressed = false},
    y = {x = 0, y = 0, radius = 0, pressed = false},
    lb = {x = 0, y = 0, radius = 0, pressed = false}
}

-- ==========================================
-- 2. ระบบคำนวณตำแหน่งและอาณาเขตล่องหน (Dynamic Scaling)
-- ==========================================
function controller.init(screenWidth, screenHeight)
    local baseSize = screenHeight * 0.15

    -- จัดวางอนาล็อกฝั่งซ้าย
    local joy = controller.joystick
    joy.x = baseSize * 2.5
    joy.y = screenHeight - (baseSize * 2.5)
    joy.radius = baseSize * 1.5
    joy.stickRadius = baseSize * 0.6
    joy.stickX = joy.x
    joy.stickY = joy.y
    joy.dx = 0
    joy.dy = 0
    joy.activeTouchId = nil

    -- [สูตร PPSSPP ล็อกพื้นที่] กำหนดให้พื้นที่ 40% ของจอฝั่งซ้ายล่างทั้งหมด คืออาณาเขตของจอยสติ๊ก
    joy.zoneW = screenWidth * 0.40
    joy.zoneH = screenHeight * 0.50

    -- จัดวางแผงปุ่ม ABXY ฝั่งขวา (Xbox Style)
    local actionRadius = baseSize * 0.55
    local panelCenterX = screenWidth - (baseSize * 2.5)
    local panelCenterY = screenHeight - (baseSize * 2.5)
    local offset = baseSize * 0.9

    controller.action.a = { x = panelCenterX, y = panelCenterY + offset, radius = actionRadius, pressed = false }
    controller.action.y = { x = panelCenterX, y = panelCenterY - offset, radius = actionRadius, pressed = false }
    controller.action.x = { x = panelCenterX - offset, y = panelCenterY, radius = actionRadius, pressed = false }
    controller.action.b = { x = panelCenterX + offset, y = panelCenterY, radius = actionRadius, pressed = false }
    controller.action.lb = { x = panelCenterX, y = panelCenterY - (offset * 2.2), radius = actionRadius * 0.6, pressed = false }
end

-- ==========================================
-- 3. ตรรกะคณิตศาสตร์ขั้นสูง (ขยายขอบล่องหน + คำนวณแรงลากแบบ Dynamic)
-- ==========================================
local function resetButtons()
    for _, btn in pairs(controller.action) do btn.pressed = false end
end

local function processTouch(tx, ty, id)
    local joy = controller.joystick

    -- เช็คเงื่อนไขที่ 1: ถ้านิ้วนี้เป็นนิ้วเดิมที่กำลังลากจอยอยู่แล้ว (ต่อให้ลากทะลุไปสุดขอบจอ ก็ยังคุมอยู่)
    -- เช็คเงื่อนไขที่ 2: ถ้าเป็นนิ้วใหม่ แต่กดลงในอาณาเขตล่องหนฝั่งซ้ายล่าง (tx < zoneW และ ty > จอส่วนล่าง)
    if joy.activeTouchId == id or 
       (joy.activeTouchId == nil and tx <= joy.zoneW and ty >= (love.graphics.getHeight() - joy.zoneH)) then
        
        joy.activeTouchId = id
        
        -- คำนวณระยะห่างระหว่างนิ้วจริง กับจุดศูนย์กลางของจอยสติ๊ก
        local angle = math.atan2(ty - joy.y, tx - joy.x)
        local distance = math.sqrt((tx - joy.x)^2 + (ty - joy.y)^2)

        -- ถ้านิ้วลากอยู่ภายในรัศมีจอย ตัวปุ่มวงกลมเล็กจะขยับตามนิ้วตรงๆ
        if distance <= joy.radius then
            joy.stickX = tx
            joy.stickY = ty
            -- ค่าเวกเตอร์ทิศทางเคลื่อนที่ตามสัดส่วนจริง (0.0 ถึง 1.0)
            joy.dx = (tx - joy.x) / joy.radius
            joy.dy = (ty - joy.y) / joy.radius
        else
            -- [จุดเปลี่ยนแบบ PPSSPP] ถ้านิ้วลากทะลุรัศมีจอยออกไป ปุ่มตรงกลางจะล็อกค้างไว้ที่ขอบนอกสุด
            joy.stickX = joy.x + math.cos(angle) * joy.radius
            joy.stickY = joy.y + math.sin(angle) * joy.radius
            -- ล็อกค่าความแรงให้เป็นสูงสุด (1.0 หรือ -1.0) ตามองศาที่นิ้วชี้ไปทันที ไม่หลุดไม่เอ๋อ!
            joy.dx = math.cos(angle)
            joy.dy = math.sin(angle)
        end
        return
    end

    -- เช็คชนแผงปุ่มแอคชันขวาตามปกติ
    for _, btn in pairs(controller.action) do
        local distance = math.sqrt((tx - btn.x)^2 + (ty - btn.y)^2)
        if distance <= btn.radius then
            btn.pressed = true
        end
    end
end

-- ==========================================
-- 4. ระบบรันวงจร Multi-touch และ PC Test
-- ==========================================

local function processTouch(tx, ty, id)
    local joy = controller.joystick

    -- ตัดเรื่องแกล้งตายออก เพื่อให้หน้าเมนูสามารถดึงค่าอนาล็อกและปุ่ม A ไปใช้ได้
    if joy.activeTouchId == id or 
       (joy.activeTouchId == nil and tx <= joy.zoneW and ty >= (love.graphics.getHeight() - joy.zoneH)) then
        
        joy.activeTouchId = id
        
        local angle = math.atan2(ty - joy.y, tx - joy.x)
        local distance = math.sqrt((tx - joy.x)^2 + (ty - joy.y)^2)

        if distance <= joy.radius then
            joy.stickX = tx
            joy.stickY = ty
            joy.dx = (tx - joy.x) / joy.radius
            joy.dy = (ty - joy.y) / joy.radius
        else
            joy.stickX = joy.x + math.cos(angle) * joy.radius
            joy.stickY = joy.y + math.sin(angle) * joy.radius
            joy.dx = math.cos(angle)
            joy.dy = math.sin(angle)
        end
        return 
    end

    -- เช็คปุ่มแอคชัน (ABXY + LB) ตามปกติ 
    for _, btn in pairs(controller.action) do
        local distance = math.sqrt((tx - btn.x)^2 + (ty - btn.y)^2)
        if distance <= btn.radius then
            btn.pressed = true
        end
    end
end
local function processRelease(id)
    local joy = controller.joystick

    -- ถ้านิ้วที่ปล่อยคือตัวที่คุมจอยสติ๊ก ให้รีเซ็ตจอยกลับมาตรงกลาง
    if joy.activeTouchId == id then
        joy.activeTouchId = nil
        joy.stickX = joy.x
        joy.stickY = joy.y
        joy.dx = 0
        joy.dy = 0
    end

    -- [จุดตาย] ปล่อยนิ้วแล้ว ต้องเซ็ตให้ pressed เป็น false ด้วย!
    -- แต่เนื่องจาก Touch Event บนจอระบุพิกัดตอนปล่อยยาก เราจะใช้ระบบเช็ก ID หรือเคลียร์แผงปุ่มแอคชันทั้งหมดที่เคยจิ้มไว้
    for _, btn in pairs(controller.action) do
        btn.pressed = false
    end
end
-- ==========================================
-- 5. ระบบเรนเดอร์ UI
-- ==========================================
function controller.draw()
    -- วาดกรอบพื้นที่รับสัมผัสล่องหน (เปิดเอาไว้เช็คตอนทดสอบ/ถ้าทำเสร็จให้ลบออกได้)
    -- love.graphics.setColor(0, 1, 0, 0.05)
    -- love.graphics.rectangle("fill", 0, love.graphics.getHeight() - controller.joystick.zoneH, controller.joystick.zoneW, controller.joystick.zoneH)

    love.graphics.setColor(1, 1, 1, 0.4)

    -- วาดจอยอนาล็อกฐานและปุ่มโยก
    local joy = controller.joystick
    love.graphics.circle("line", joy.x, joy.y, joy.radius)
    love.graphics.circle(joy.activeTouchId and "fill" or "line", joy.stickX, joy.stickY, joy.stickRadius)

    -- วาดปุ่มแอคชันขวาทั้งหมด
    for key, btn in pairs(controller.action) do
        local mode = btn.pressed and "fill" or "line"
        love.graphics.circle(mode, btn.x, btn.y, btn.radius)
        
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.print(string.upper(key), btn.x - 6, btn.y - 7)
        love.graphics.setColor(1, 1, 1, 0.4) 
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

function controller.isDown(btnName)
    if controller.action[btnName] then
        return controller.action[btnName].pressed
    end
    return false
end

function controller.getAxis()
    return controller.joystick.dx, controller.joystick.dy
end
function love.touchpressed(id, x, y, dx, dy, pressure)
    processTouch(x, y, id)
end

function love.touchmoved(id, x, y, dx, dy, pressure)
    processTouch(x, y, id)
end

function love.touchreleased(id, x, y, dx, dy, pressure)
    processRelease(id) -- เรียกตัวเคลียร์ค่าปุ่มเมื่อปล่อยนิ้ว
end

-- สำหรับเทสบนคอม (ถ้ามึงใช้เมาส์คลิกจอยเทส)
function love.mousepressed(x, y, button, istouch)
    if not istouch then processTouch(x, y, "mouse") end
end

function love.mousereleased(x, y, button, istouch)
    if not istouch then processRelease("mouse") end
end
return controller