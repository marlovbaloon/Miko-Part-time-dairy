--conf.lua
function love.conf(t)
    t.window.title = "Miko Part-time Dairy"          -- ชื่อโปรเจกต์/ชื่อเกมมึง
    t.window.width = 320                      -- ความกว้างเริ่มต้น (ตรงกับ Virtual Width)
    t.window.height = 320                  -- ความสูงเริ่มต้น (ตรงกับ Virtual Height)
    t.window.resizable = true                 -- เปิดให้หน้าจอยืดหดปรับขนาดได้ (สำคัญมากสำหรับการทำ Letterbox)
    t.window.minwidth = 320                   -- จำกัดขนาดหน้าจอขั้นต่ำไม่ให้เล็กกว่านี้
    t.window.minheight = 320
    
    -- [[ คำแนะนำสำหรับมือถือ ]] 
    -- ในอนาคตถ้าจะบังคับให้จอมือถือล็อกเป็นแนวนอนอย่างเดียว สามารถเพิ่มบรรทัดนี้ได้:
    t.window.fullscreen = true
end