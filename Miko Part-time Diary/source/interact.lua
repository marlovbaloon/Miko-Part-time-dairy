local interact = {}

local text_box = require("source.ui.text_box")
local controller = require("source.libs.controller")

-- [🎯 INITIAL STATES]
interact.dialogueData = {} 
interact.currentJsonPath = "" 
interact.activeCollider = nil 
interact.range = 8 

-- ระบบจัดการคิวข้อความหลายหน้า
interact.currentQueue = {}
interact.queueIndex = 1

local bWasPressed = false 

function interact.loadDatabase(jsonPath)
    if interact.currentJsonPath == jsonPath then return end

    interact.dialogueData = {}
    interact.currentJsonPath = jsonPath

    if not love.filesystem.getInfo(jsonPath) then
        print("[Warning] Interact Database not found: " .. jsonPath)
        return
    end

    local content, size = love.filesystem.read(jsonPath)

    -- [🎯 NEW HARDCORE PARSER]: ลบช่องว่างภายนอกทั้งหมดเพื่อให้ Parse ง่ายขึ้น
    -- วิธีนี้จะทนทานต่อการเคาะ Spacebar, Tab และการขึ้นบรรทัดใหม่ใน JSON บนมือถือ
    local cleanContent = string.gsub(content, "[\r\n%s]+", " ")

    -- ค้นหา Pattern ของ "key" : [ "page1", "page2" ]
    for key, arrayStr in string.gmatch(cleanContent, '"([%w_]+)"%s*:%s*%[%s*(.-)%s*%]') do
        local pages = {}
        -- ดึงเฉพาะข้อความที่อยู่ในเครื่องหมายคำพูดสลับกันออกมารวมเป็น Array
        for str in string.gmatch(arrayStr, '"([^"]+)"') do
            table.insert(pages, str)
        end
        interact.dialogueData[key] = pages
    end

    -- ค้นหาคีย์ที่เป็นข้อความบรรทัดเดียวธรรมดา (เผื่อไว้) เผื่อไม่ได้ใช้เครื่องหมาย [ ]
    for key, valStr in string.gmatch(cleanContent, '"([%w_]+)"%s*:%s*"([^"]+)"') do
        if not interact.dialogueData[key] then
            interact.dialogueData[key] = { valStr }
        end
    end

    if not interact.dialogueData then
        interact.dialogueData = {}
    end
end

local function getInteractBox(player)
    local col = player.collider
    local px = player.x + col.x_offset
    local py = player.y + col.y_offset
    local pw = col.width
    local ph = col.height

    if player.direction == "up" then
        py = py - interact.range
        ph = ph + interact.range
    elseif player.direction == "down" then
        ph = ph + interact.range
    elseif player.direction == "left" then
        px = px - interact.range
        pw = pw + interact.range
    elseif player.direction == "right" then
        pw = pw + interact.range
    end

    return px, py, pw, ph
end

local function checkAABB(x1, y1, w1, h1, x2, y2, w2, h2)
    return x1 < x2 + w2 and x2 < x1 + w1 and y1 < y2 + h2 and y2 < y1 + w1
end

function interact.update(dt, player, map)
    if not interact.dialogueData then 
        interact.dialogueData = {} 
    end

    text_box.update(dt)

    local bPressed = false
    if love.keyboard.isDown("z") then bPressed = true end
    if controller and controller.isDown and controller.isDown("b") then bPressed = true end

    -- ค้นหาวัตถุชน (หาเฉพาะตอนที่ยังไม่ได้เปิดกล่องคุย)
    if map and map.colliders and not text_box.isOpen then
        interact.activeCollider = nil
        local ix, iy, iw, ih = getInteractBox(player)
        for i = 1, #map.colliders do
            local obstacle = map.colliders[i]
            if obstacle.id then
                if checkAABB(ix, iy, iw, ih, obstacle.x, obstacle.y, obstacle.width, obstacle.height) then
                    interact.activeCollider = obstacle
                    break 
                end
            end
        end
    end

    -- STATE CONTROL
    if bPressed and not bWasPressed then
        if text_box.isOpen then
            -- จังหวะที่ 1: ตัวอักษรยังวิ่งไม่จบหน้า -> เร่งความเร็วตัวอักษรให้เต็มหน้า
            if not text_box.isTextComplete then
                text_box.currentCharCount = text_box.totalChars
                text_box.isTextComplete = true

            -- จังหวะที่ 2: ตัวอักษรเต็มหน้าแล้ว -> ขยับไปหน้าถัดไปในตารางคิว
            else
                if interact.queueIndex < #interact.currentQueue then
                    interact.queueIndex = interact.queueIndex + 1
                    text_box.show(interact.currentQueue[interact.queueIndex])
                else
                    -- จังหวะที่ 3: หน้าสุดท้ายแล้วจริงๆ -> กดปิดกล่องข้อความ
                    text_box.close()
                    if player then player.is_moving = true end
                end
            end

        elseif interact.activeCollider then
            local objectId = interact.activeCollider.id
            -- ดึงอาเรย์ออกมาตรงๆ ถ้าไม่มีให้ใส่ข้อความแจ้งเตือนไว้
            local rawData = interact.dialogueData[objectId] or { ("..." .. objectId .. "...") }

            -- บังคับว่าข้อมูลที่ดึงมาต้องเก็บเป็น Queue ในรูปแบบ Table เสมอ
            if type(rawData) == "table" then
                interact.currentQueue = rawData
            else
                interact.currentQueue = { rawData }
            end

            interact.queueIndex = 1
            text_box.show(interact.currentQueue[1])
            if player then player.is_moving = false end 
        end
    end
    bWasPressed = bPressed

    if text_box.isOpen and player then
        player.is_moving = false
    end
end

function interact.draw(virtualWidth, virtualHeight)
    text_box.draw(virtualWidth, virtualHeight)
end

return interact