local text_wrap = {}

function text_wrap.wrap(text, font, limit)
    local lines = {}

    -- 1. รองรับการขึ้นบรรทัดใหม่ (\n) ที่ระบุไว้ใน JSON โดยการหั่นเป็นย่อหน้า (Paragraph) ก่อน
    for paragraph in string.gmatch(text .. "\n", "([^\n]*)\n") do
        local currentLine = ""

        -- 2. ดึงคำศัพท์ภาษาอังกฤษทีละคำอิงตามเว้นวรรค (%S+ ดึงอักขระที่ไม่ใช่ช่องว่าง)
        for word in string.gmatch(paragraph, "%S+") do
            if currentLine == "" then
                -- หากเป็นคำแรกของบรรทัดใหม่
                local wordWidth = font:getWidth(word)
                if wordWidth <= limit then
                    currentLine = word
                else
                    -- เคสพิเศษ: คำศัพท์คำเดียวเสือกยาวเกินขนาดกล่องข้อความ! 
                    -- จำเป็นต้องหั่นทีละตัวอักษรเพื่อป้องกันไม่ให้ข้อความล้นทะลุจอ
                    local temp = ""
                    for i = 1, #word do
                        local char = string.sub(word, i, i)
                        if font:getWidth(temp .. char) > limit then
                            table.insert(lines, temp)
                            temp = char
                        else
                            temp = temp .. char
                        end
                    end
                    currentLine = temp
                end
            else
                -- ทดสอบเอาคำใหม่มาต่อท้ายประโยคเดิม (เว้นช่องว่าง 1 เคาะ)
                local testLine = currentLine .. " " .. word
                if font:getWidth(testLine) <= limit then
                    -- ถ้าความกว้างยังไหว ให้ต่อประโยคยาวไปได้เลย
                    currentLine = testLine
                else
                    -- ถ้าเกินขีดจำกัด ให้โยนประโยคเดิมเข้าตารางบรรทัด แล้วเริ่มบรรทัดใหม่ด้วยคำศัพท์คำนี้
                    table.insert(lines, currentLine)

                    local wordWidth = font:getWidth(word)
                    if wordWidth <= limit then
                        currentLine = word
                    else
                        -- เคสพิเศษสำหรับคำยาวจัดในบรรดาย่อยถัดไป
                        local temp = ""
                        for i = 1, #word do
                            local char = string.sub(word, i, i)
                            if font:getWidth(temp .. char) > limit then
                                table.insert(lines, temp)
                                temp = char
                            else
                                temp = temp .. char
                            end
                        end
                        currentLine = temp
                    end
                end
            end
        end

        -- 3. เก็บตกคำบรรทัดสุดท้ายของย่อหน้านั้น ๆ เข้าสู่ตารางแสดงผล
        if currentLine ~= "" or paragraph == "" then
            table.insert(lines, currentLine)
        end
    end

    return lines
end

return text_wrap