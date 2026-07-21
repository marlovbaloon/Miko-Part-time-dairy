-- source/ui/text_box.lua
local text_box = {}
local text_wrap = require("source.ui.text_wrap")
local controller = require("source.libs.controller") -- ดึงมาเช็คปุ่ม B สำหรับเร่งความเร็วพิมพ์

text_box.isOpen = false
text_box.scale = 0 
text_box.targetScale = 0 
text_box.speed = 12 
text_box.rawText = "" 
text_box.wrappedLines = {} 

-- [🎯 NEW VARIABLES FOR TYPEWRITER EFFECT]
text_box.textTimer = 0          -- ตัวนับเวลาสะสมสำหรับพิมพ์อักษร
text_box.typeSpeed = 0.03       -- ความเร็วปกติ (0.03 วินาทีต่อ 1 ตัวอักษร)
text_box.currentCharCount = 0  -- จำนวนตัวอักษรที่กำลังแสดงผลอยู่ปัจจุบัน
text_box.totalChars = 0        -- จำนวนตัวอักษรทั้งหมดของข้อความชุดนี้
text_box.isTextComplete = false -- สถานะเช็คว่าพิมพ์ข้อความเสร็จสมบูรณ์หรือยัง

function text_box.show(text)
    text_box.rawText = text
    text_box.isOpen = true
    text_box.targetScale = 1
    text_box.wrappedLines = {} 

    -- รีเซ็ตค่าระบบพิมพ์อักษรใหม่ทุกครั้งที่เปลี่ยนหน้าข้อความ
    text_box.textTimer = 0
    text_box.currentCharCount = 0
    text_box.totalChars = string.len(text) -- นับจำนวนความยาวอักษรดิบทั้งหมด
    text_box.isTextComplete = false
end

function text_box.close()
    text_box.targetScale = 0
    text_box.isOpen = false   
    text_box.isTextComplete = false
end

function text_box.update(dt)
    -- 1. อัปเดตสเกลแอนิเมชันของตัวกล่องข้อความตามปกติ
    text_box.scale = text_box.scale + (text_box.targetScale - text_box.scale) * text_box.speed * dt

    if text_box.targetScale == 0 and text_box.scale < 0.01 then
        text_box.scale = 0
        return
    end

    -- 🎯 [CONDITION 1]: ตัวอักษรจะยังไม่พิมพ์จนกว่าตัวกล่องจะกางออกจนเกือบสุด (Scale >= 0.95)
    if text_box.isOpen and text_box.scale >= 0.95 then
        if not text_box.isTextComplete then

            -- เช็คว่ามีการกดปุ่ม B ค้างไว้เพื่อเร่งความเร็วในการพิมพ์หรือไม่ (รองรับทั้ง Keyboard และ Controller)
            local isBDown = love.keyboard.isDown("b") or (controller and controller.action and controller.action.b and controller.action.b.pressed)

            -- ปรับสปีด: ถ้ากด B ค้างจะพิมพ์เร็วขึ้น 5 เท่า (0.006s) ถ้าไม่กดก็สปีดปกติ (0.03s)
            local currentSpeed = isBDown and (text_box.typeSpeed / 5) or text_box.typeSpeed

            text_box.textTimer = text_box.textTimer + dt
            if text_box.textTimer >= currentSpeed then
                -- คำนวณจำนวนตัวอักษรที่จะเพิ่มขึ้นตามเวลาสะสม
                local charsToAdd = math.floor(text_box.textTimer / currentSpeed)
                text_box.currentCharCount = math.min(text_box.currentCharCount + charsToAdd, text_box.totalChars)
                text_box.textTimer = text_box.textTimer % currentSpeed
            end

            -- ตรวจสอบว่าตัวอักษรวิ่งแสดงผลออกมาครบถ้วนหรือยัง
            if text_box.currentCharCount >= text_box.totalChars then
                text_box.isTextComplete = true
            end
        end
    end
end

function text_box.draw(virtualWidth, virtualHeight)
    if text_box.scale <= 0.005 and text_box.targetScale == 0 then return end

    -- =======================================================
    -- [🎯 FIXED]: ปรับลอจิกขนาดกล่องให้กว้างสมดุล และ สูงเป็น 1/3 ของความสูงหน้าจอชิดขอบล่าง
    -- =======================================================
    local boxW = math.floor(virtualWidth * 0.94)    -- ขยับความกว้างให้เต็มตาขึ้นในสเกลจอจัตุรัส
    local boxH = math.floor(virtualHeight / 3)      -- ขนาดความสูง 1/3 ของความสูงหน้าจอเป๊ะๆ
    local boxX = math.floor((virtualWidth - boxW) / 2)
    local boxY = math.floor(virtualHeight - boxH - 6) -- แปะติดขอบล่าง (เว้น Gap เซฟตี้ไว้แค่ 6 พิกเซลเพื่อความเนี๊ยบ)

    love.graphics.push("all")

    local centerX = boxX + (boxW / 2)
    local centerY = boxY + (boxH / 2)
    love.graphics.translate(centerX, centerY)
    love.graphics.scale(text_box.scale, text_box.scale)
    love.graphics.translate(-centerX, -centerY)

    -- วาดกล่องพื้นหลังและเส้นขอบ UI
    love.graphics.setColor(0.05, 0.05, 0.08, 0.9)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 4)
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", boxX, boxY, boxW, boxH, 4)

    love.graphics.setColor(1, 1, 1, 1)

    local currentFont = love.graphics.getFont()
    local textPadding = 8 -- ปรับ Padding ให้กระชับขึ้นเพื่อให้เหมาะกับพื้นที่แนวตั้งที่มีจำกัด
    local maxWidth = boxW - (textPadding * 2)

    -- คำนวณตัดคำจากประโยคดิบเต็มรูปแบบก่อน เพื่อให้ตำแหน่งการเว้นบรรทัดคงที่ ไม่ขยับขยายแบบเอ๋อๆ ตอนพิมพ์
    if #text_box.wrappedLines == 0 and text_box.rawText ~= "" then
        text_box.wrappedLines = text_wrap.wrap(text_box.rawText, currentFont, maxWidth)
    end

    -- 🎯 [TYPEWRITER RENDERING ENGINE]: ตัด String แสดงผลเฉพาะจำนวนตัวอักษรที่พิมพ์เสร็จแล้ว
    local lineHeight = currentFont:getHeight() + 2
    local charsLeftToDraw = text_box.currentCharCount

    for i, line in ipairs(text_box.wrappedLines) do
        if charsLeftToDraw <= 0 then break end

        -- ใช้ UTF-8 Safe string length เพื่อป้องกันภาษาอังกฤษและอักขระพิเศษพัง
        local lineLength = string.len(line)

        if charsLeftToDraw >= lineLength then
            -- ถ้าในโควต้าตัวนับยังมีค่ามากกว่าความยาวบรรทัดนี้ ให้พิมพ์ประโยคในบรรทัดนี้เต็มๆ ได้เลย
            love.graphics.print(line, boxX + textPadding, boxY + textPadding + ((i - 1) * lineHeight))
            charsLeftToDraw = charsLeftToDraw - lineLength
        else
            -- ถ้าโควต้าพิมพ์เหลือไม่ถึงความยาวบรรทัด ให้ทำการหั่น String โชว์แค่เท่าที่มี
            local subLine = string.sub(line, 1, charsLeftToDraw)
            love.graphics.print(subLine, boxX + textPadding, boxY + textPadding + ((i - 1) * lineHeight))
            charsLeftToDraw = 0
        end
    end

    love.graphics.pop()
end

return text_box