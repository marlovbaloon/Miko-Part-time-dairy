-- source/interact.lua
local interact = {}

local text_box = require("source.ui.text_box")
local controller = require("source.libs.controller")
local StateManager = require("source.states_manager")

interact.dialogueData = {} 
interact.currentJsonPath = "" 
interact.activeCollider = nil 
interact.range = 8 

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
    local cleanContent = string.gsub(content, "[\r\n%s]+", " ")

    for key, arrayStr in string.gmatch(cleanContent, '"([%w_]+)"%s*:%s*%[%s*(.-)%s*%]') do
        local pages = {}
        for str in string.gmatch(arrayStr, '"([^"]+)"') do
            table.insert(pages, str)
        end
        interact.dialogueData[key] = pages
    end

    for key, valStr in string.gmatch(cleanContent, '"([%w_]+)"%s*:%s*"([^"]+)"') do
        if not interact.dialogueData[key] then
            interact.dialogueData[key] = { valStr }
        end
    end

    if not interact.dialogueData then
        interact.dialogueData = {}
    end
end

-- 🎯 [ฟังก์ชันที่หายไป]: getInteractBox
local function getInteractBox(player)
    local col = player.collider or { x_offset = 0, y_offset = 0, width = 16, height = 16 }
    local px = player.x + (col.x_offset or 0)
    local py = player.y + (col.y_offset or 0)
    local pw = col.width or 16
    local ph = col.height or 16

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

-- 🎯 [ฟังก์ชันที่หายไป]: checkAABB
local function checkAABB(x1, y1, w1, h1, x2, y2, w2, h2)
    return x1 < x2 + w2 and x2 < x1 + w1 and y1 < y2 + h2 and y2 < y1 + w1
end

function interact.update(dt, player, map)
    if not player or not player.collider then 
        return 
    end
    if not interact.dialogueData then interact.dialogueData = {} end

    text_box.update(dt)

    local bPressed = false
    if love.keyboard.isDown("z") then bPressed = true end
    if controller and controller.isDown and controller.isDown("b") then bPressed = true end

    -- ค้นหาวัตถุชน
    if map and map.colliders and not text_box.isOpen then
        interact.activeCollider = nil
        local ix, iy, iw, ih = getInteractBox(player)
        for i = 1, #map.colliders do
            local obstacle = map.colliders[i]
            if obstacle.id or obstacle.target_scene then
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
            if not text_box.isTextComplete then
                text_box.currentCharCount = text_box.totalChars
                text_box.isTextComplete = true
            else
                if interact.queueIndex < #interact.currentQueue then
                    interact.queueIndex = interact.queueIndex + 1
                    text_box.show(interact.currentQueue[interact.queueIndex])
                else
                    text_box.close()
                    if player then player.is_moving = true end
                end
            end

        elseif interact.activeCollider then
            local obj = interact.activeCollider

            -- 🎯 เช็กย้ายฉากแบบ Dynamic จาก target_scene ของ Map
            if obj.target_scene then
                StateManager.switch(obj.target_scene)
            else
                local objectId = obj.id
                local rawData = interact.dialogueData[objectId] or { ("..." .. objectId .. "...") }

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