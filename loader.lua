--!nocheck
--[[ GardenPro X — loader (suregiga/GardenScripts)
     ลิงก์ใช้งาน:
     loadstring(game:HttpGet('https://raw.githubusercontent.com/suregiga/GardenScripts/main/loader.lua'))()
]]

local NAME = "GardenPro X"
local VER  = "2.1"
local BASE = "https://raw.githubusercontent.com/suregiga/GardenScripts/main/"
local FILES = {
	BASE .. "GardenProX.lua?t=" .. tostring(os.time()),                              -- หลัก (กันแคช)
	"https://cdn.jsdelivr.net/gh/suregiga/GardenScripts@main/GardenProX.lua",        -- สำรอง (CDN)
	"https://raw.githubusercontent.com/suregiga/GardenScripts/main/GardenProX.lua",  -- สำรอง 2
}

local function notify(text)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = NAME, Text = text, Duration = 4,
		})
	end)
	print("[" .. NAME .. "] " .. text)
end

if _G.GardenProX then
	notify("สคริปต์โหลดอยู่แล้ว")
	return
end

notify("กำลังดาวน์โหลด " .. VER .. " ...")

local source
for _, url in ipairs(FILES) do
	local ok, body = pcall(function() return game:HttpGet(url, true) end)
	if ok and type(body) == "string" and #body > 100 then
		source = body
		break
	end
	task.wait(0.5)
end

if not source then
	notify("โหลดไม่สำเร็จ — ตรวจว่า repo เป็น Public และลิงก์ถูก")
	return
end

local chunk, err = loadstring(source, NAME)
if not chunk then
	notify("โค้ดมีปัญหา: " .. tostring(err))
	return
end

local ok, runErr = pcall(chunk)
if ok then
	notify("พร้อมใช้งาน " .. VER .. " • กดปุ่ม GP หรือ RightShift")
else
	notify("รันแล้ว error: " .. tostring(runErr))
end
