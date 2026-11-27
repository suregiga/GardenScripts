--!nocheck
--[[ ============================================================
     GardenProX  v6.0  —  Universal Client Helper
     ทำงานได้ "ทุกแมพ" โดยไม่ต้องมีสคริปต์เซิร์ฟเวอร์ และไม่ต้องรู้ชื่อ Remote
     ------------------------------------------------------------
     หลักการ: เกมเกือบทั้งหมดทำปุ่มโต้ตอบด้วย ProximityPrompt / ClickDetector / Tool
              สคริปต์นี้จะ "เดินไปหาแล้วกดให้" เหมือนคนเล่นเอง
        • ค้นหา ProximityPrompt ทั้งแมพ แล้วจัดหมวดด้วยคำใน ActionText/ObjectText/ชื่อ
        • เดินไปถึงระยะที่กดได้ → ยิง prompt (fireproximityprompt) หรือกดค้างเอง
        • ถ้าหมวดไหนไม่มี prompt → ใช้ไอเทม (ขวาน/พลั่ว/เบ็ด) หรือแตะวัตถุแทน
        • ESP + เรดาร์: เห็นว่ามีอะไรให้กด อยู่ไกลเท่าไร
        • เคลื่อนที่: เร็ว/กระโดด/ลอย/ทะลุของ/วาร์ป
        • ไทม์เมอร์ + สถิติ + ตรวจแมพ (คัดลอกรายงานได้)
     ปุ่ม: RightShift ซ่อน/แสดง • RightCtrl ปิด • ปุ่ม GP ลากได้
     ============================================================ ]]

if _G.GardenProX and _G.GardenProX.Destroy then pcall(_G.GardenProX.Destroy) end

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local Workspace        = game:GetService("Workspace")
local Stats            = game:GetService("Stats")
local VirtualUser      = game:GetService("VirtualUser")

local LP = Players.LocalPlayer
local VERSION = "6.0"
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local P = {
	State = {}, Conns = {}, Actions = {}, Cool = {}, Pages = {}, Nav = {},
	Stats = { actions = 0, sells = 0, items = 0, start = os.clock() },
	Cfg = {}, W = { parts = {}, prompts = {}, t = 0, pt = 0 }, LastWarn = {},
}
_G.GardenProX = P

--------------------------------------------------------------------------------
-- ตั้งค่า
--------------------------------------------------------------------------------
local Cfg = {
	Speed = 55, Jump = 120, FlySpeed = 90, Range = 4000,
	Reach = 8, Delay = 0.05, Humanize = true, Jitter = 0.25, Turbo = false,
	ESP = false, Radar = true, AntiAfk = true, LowPower = false,
	SellEvery = 4, PromptCd = 0.6, ReachExtra = 0,
}
P.Cfg = Cfg

--------------------------------------------------------------------------------
-- หมวด prompt (อังกฤษ + ไทย)
--------------------------------------------------------------------------------
local CAT = {
	harvest = { label = "เก็บเกี่ยว", words = { "harvest", "pick", "collect", "gather", "reap", "เก็บ", "เกี่ยว" }, col = Color3.fromRGB(110, 230, 150) },
	plant   = { label = "ปลูก",      words = { "plant", "sow", "ปลูก", "seed" }, col = Color3.fromRGB(150, 220, 110) },
	water   = { label = "รดน้ำ",     words = { "water", "รด" }, col = Color3.fromRGB(110, 190, 255) },
	mine    = { label = "ขุด/เหมือง", words = { "mine", "dig", "ขุด", "ore", "rock" }, col = Color3.fromRGB(170, 200, 230) },
	chop    = { label = "ตัดไม้",    words = { "chop", "cut", "ตัด", "wood", "log", "tree" }, col = Color3.fromRGB(200, 160, 100) },
	fish    = { label = "ตกปลา",     words = { "fish", "cast", "reel", "ตกปลา" }, col = Color3.fromRGB(110, 210, 230) },
	egg     = { label = "ฟักไข่",     words = { "hatch", "egg", "ฟัก" }, col = Color3.fromRGB(250, 220, 130) },
	pet     = { label = "สัตว์เลี้ยง", words = { "feed", "pet", "ให้อาหาร", "เลี้ยง" }, col = Color3.fromRGB(255, 170, 210) },
	sell    = { label = "ขายของ",    words = { "sell", "ขาย" }, col = Color3.fromRGB(255, 200, 90) },
	buy     = { label = "ซื้อของ",    words = { "buy", "purchase", "ซื้อ" }, col = Color3.fromRGB(255, 150, 120) },
	claim   = { label = "รับรางวัล",  words = { "claim", "reward", "daily", "gift", "spin", "รับ", "รางวัล" }, col = Color3.fromRGB(190, 150, 255) },
	craft   = { label = "คราฟ/อัปเกรด", words = { "craft", "forge", "upgrade", "enchant", "คราฟ", "อัปเกรด" }, col = Color3.fromRGB(150, 190, 255) },
	talk    = { label = "คุย/NPC",   words = { "talk", "speak", "คุย", "dialog" }, col = Color3.fromRGB(200, 200, 210) },
}
local CAT_ORDER = { "harvest", "plant", "water", "mine", "chop", "fish", "egg", "pet", "sell", "buy", "claim", "craft", "talk" }

-- คำไว้หาวัตถุเมื่อหมวดนั้นไม่มี prompt (ใช้ไอเทม/แตะแทน)
local PART_WORDS = {
	mine = { "ore", "rock", "stone", "crystal", "node", "vein", "gem", "แร่", "หิน" },
	chop = { "tree", "log", "wood", "trunk", "stump", "ต้นไม้", "ไม้" },
	fish = { "fish", "pond", "lake", "sea", "water", "spot", "ตกปลา", "น้ำ" },
	harvest = { "crop", "fruit", "ready", "grown", "harvest", "ripe", "ผล", "สุก" },
	egg = { "egg", "nest", "ไข่", "รัง" },
}
local TOOL_WORDS = {
	mine = { "pickaxe", "pick", "พลั่ว" },
	chop = { "axe", "hatchet", "ขวาน" },
	fish = { "rod", "เบ็ด" },
}
local LOOT_WORDS = { "coin", "cash", "orb", "gem", "drop", "loot", "chest", "token", "money", "เหรียญ" }

--------------------------------------------------------------------------------
-- utility
--------------------------------------------------------------------------------
local T = {
	bg = Color3.fromRGB(15, 17, 23), card = Color3.fromRGB(28, 32, 42), card2 = Color3.fromRGB(37, 42, 55),
	well = Color3.fromRGB(21, 24, 32), stroke = Color3.fromRGB(56, 63, 80), text = Color3.fromRGB(236, 242, 252),
	sub = Color3.fromRGB(152, 164, 184), muted = Color3.fromRGB(110, 120, 140),
	accent = Color3.fromRGB(96, 230, 170), accent2 = Color3.fromRGB(112, 176, 255),
	gold = Color3.fromRGB(248, 198, 96), danger = Color3.fromRGB(238, 112, 126), violet = Color3.fromRGB(160, 138, 255),
}

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do if k ~= "Parent" then o[k] = v end end
	if parent then o.Parent = parent end
	return o
end
local function corner(o, r) new("UICorner", { CornerRadius = UDim.new(0, r or 9) }, o) end
local function stroke(o, col, tr)
	return new("UIStroke", { Color = col or T.stroke, Thickness = 1, Transparency = tr or 0.35 }, o)
end
local function pad(o, n)
	new("UIPadding", { PaddingLeft = UDim.new(0, n), PaddingRight = UDim.new(0, n),
		PaddingTop = UDim.new(0, n), PaddingBottom = UDim.new(0, n) }, o)
end
local function tw(o, t, props)
	TweenService:Create(o, TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end
local function conn(sig, fn)
	if not sig then return nil end
	local ok, c = pcall(function() return sig:Connect(fn) end)
	if ok and c then table.insert(P.Conns, c) return c end
	return nil
end
local function hit(txt, words)
	if not txt then return false end
	txt = txt:lower()
	for _, w in ipairs(words or {}) do if txt:find(w, 1, true) then return true end end
	return false
end
local function char() return LP.Character end
local function hum() local c = char() return c and c:FindFirstChildOfClass("Humanoid") or nil end
local function hrp() local c = char() return c and c:FindFirstChild("HumanoidRootPart") or nil end
local function alive() local h = hum() return (h and h.Health > 0) or false end
local function dist(a, b) return (a - b).Magnitude end
local function pause(base) return math.max(0, base * (1 + (math.random() * 2 - 1) * (Cfg.Humanize and Cfg.Jitter or 0))) end

local function log(msg, kind)
	if not P.Console then return end
	local col = (kind == "warn" and T.gold) or (kind == "ok" and T.accent) or (kind == "err" and T.danger) or T.sub
	local l = new("TextLabel", { Size = UDim2.new(1, -18, 0, 14), BackgroundTransparency = 1, Font = Enum.Font.Code,
		TextSize = 11, TextColor3 = col, TextXAlignment = Enum.TextXAlignment.Left,
		Text = "› " .. tostring(msg) }, P.Console)
	task.delay(35, function() if l and l.Parent then l:Destroy() end end)
	local kids = P.Console:GetChildren()
	if #kids > 26 then for i = 1, #kids - 26 do if kids[i] then kids[i]:Destroy() end end end
end
local function warnOnce(key, msg)
	if P.LastWarn[key] and os.clock() - P.LastWarn[key] < 25 then return end
	P.LastWarn[key] = os.clock()
	log(msg, "warn")
end
local function toast(text, color)
	if not P.Toasts then return end
	local col = color or T.accent
	local b = new("Frame", { Size = UDim2.fromOffset(260, 32), BackgroundColor3 = T.card, BackgroundTransparency = 1,
		BorderSizePixel = 0 }, P.Toasts)
	corner(b, 9)
	local s = stroke(b, col, 0.7)
	new("Frame", { Size = UDim2.new(0, 3, 1, -12), Position = UDim2.fromOffset(0, 6),
		BackgroundColor3 = col, BorderSizePixel = 0 }, b)
	local lbl = new("TextLabel", { Size = UDim2.new(1, -18, 1, 0), Position = UDim2.fromOffset(11, 0),
		BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = T.text,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = text }, b)
	tw(b, 0.16, { BackgroundTransparency = 0.05 })
	tw(lbl, 0.16, { TextTransparency = 0 })
	task.delay(2.6, function()
		if not b.Parent then return end
		tw(b, 0.25, { BackgroundTransparency = 1 })
		tw(lbl, 0.25, { TextTransparency = 1 })
		tw(s, 0.25, { Transparency = 1 })
		task.delay(0.3, function() if b then b:Destroy() end end)
	end)
end

--------------------------------------------------------------------------------
-- Tracker : วัตถุ/ปุ่ม ที่關心 ไมสแกนทั้งโลกทุกเฟรม
--------------------------------------------------------------------------------
local tracked = setmetatable({}, { __mode = "k" })
local function track(inst)
	if inst:IsA("BasePart") or inst:IsA("ProximityPrompt") or inst:IsA("ClickDetector") then
		tracked[inst] = true
	end
end

local function promptText(prompt)
	local holder = prompt.Parent
	local t = {}
	if prompt:IsA("ProximityPrompt") then
		t[#t + 1] = tostring(prompt.ActionText or "")
		t[#t + 1] = tostring(prompt.ObjectText or "")
	end
	t[#t + 1] = prompt.Name
	if holder then
		t[#t + 1] = holder.Name
		if holder.Parent then t[#t + 1] = holder.Parent.Name end
	end
	return table.concat(t, " "):lower()
end

local function catOfPrompt(prompt)
	local txt = promptText(prompt)
	for _, cat in ipairs(CAT_ORDER) do
		if hit(txt, CAT[cat].words) then return cat end
	end
	return nil
end

local function refresh()
	local parts, prompts = {}, {}
	local my, ch = hrp(), char()
	local origin = my and my.Position or Vector3.zero
	for inst in pairs(tracked) do
		if inst.Parent then
			if inst:IsA("BasePart") then
				if inst.Transparency < 1 and not (ch and inst:IsDescendantOf(ch)) then
					if (inst.Position - origin).Magnitude <= Cfg.Range then parts[#parts + 1] = inst end
				end
			elseif inst:IsA("ProximityPrompt") then
				if inst.Enabled and inst.Parent and inst.Parent:IsA("BasePart") then
					local d = (inst.Parent.Position - origin).Magnitude
					if d <= Cfg.Range then
						prompts[#prompts + 1] = { prompt = inst, part = inst.Parent, text = promptText(inst), cat = catOfPrompt(inst), d = d }
					end
				end
			elseif inst:IsA("ClickDetector") then
				if inst.Parent and inst.Parent:IsA("BasePart") then
					local d = (inst.Parent.Position - origin).Magnitude
					if d <= Cfg.Range then
						prompts[#prompts + 1] = { click = inst, part = inst.Parent, text = promptText(inst), cat = catOfPrompt(inst), d = d }
					end
				end
			end
		else
			tracked[inst] = nil
		end
	end
	table.sort(prompts, function(a, b) return a.d < b.d end)
	P.W.parts, P.W.prompts = parts, prompts
	P.W.t = os.clock()
end
local function world()
	if os.clock() - P.W.t > 1.5 then refresh() end
	return P.W.parts, P.W.prompts
end

local function nearestPrompt(cat, maxD)
	local _, prompts = world()
	local my = hrp(); if not my then return nil end
	for _, e in ipairs(prompts) do
		if e.cat == cat then
			local d = dist(e.part.Position, my.Position)
			if d <= (maxD or Cfg.Range) then return e, d end
		end
	end
	return nil
end

local function countCat(cat)
	local n = 0
	local _, prompts = world()
	for _, e in ipairs(prompts) do if e.cat == cat then n += 1 end end
	return n
end

local wordCache = setmetatable({}, { __mode = "k" })
local function matchWords(part, words)
	local c = wordCache[part]
	if not c then c = {}; wordCache[part] = c end
	if c.words ~= words then
		c.words, c.res = words, hit(part.Name, words)
	end
	return c.res
end

local function nearestPart(words, maxD)
	local parts = world()
	local my = hrp(); if not my then return nil end
	local best, bd = nil, maxD or Cfg.Range
	for _, p in ipairs(parts) do
		if matchWords(p, words) then
			local d = dist(p.Position, my.Position)
			if d < bd then best, bd = p, d end
		end
	end
	return best, bd
end

--------------------------------------------------------------------------------
-- check "ผ่าน" ของเรา (ไม่ใช้ HubServer)
--------------------------------------------------------------------------------
local function promptAlive(e) return e and e.part and e.part.Parent ~= nil end

--------------------------------------------------------------------------------
-- movement / interaction
--------------------------------------------------------------------------------
local lastPos, stuck = nil, 0
local function walkTo(pos, reach)
	local my, h = hrp(), hum()
	if not my or not h then return false end
	if dist(my.Position, pos) <= (reach or Cfg.Reach) then return true end
	if lastPos and dist(my.Position, lastPos) < 0.9 then stuck += 1 else stuck = 0 end
	lastPos = my.Position
	if stuck >= 4 then
		h.Jump = true
		stuck = 0
		h:MoveTo(pos + Vector3.new(math.random(-6, 6), 0, math.random(-6, 6)))
	else
		h:MoveTo(pos)
	end
	return false
end

local function aim(pos)
	local cam = Workspace.CurrentCamera
	if cam then pcall(function() cam.CFrame = CFrame.lookAt(cam.CFrame.Position, pos) end) end
end

local function clickScreen(pos)
	local cam = Workspace.CurrentCamera
	if not cam then return end
	local point = cam.ViewportSize / 2
	if pos then
		local vp, onScreen = cam:WorldToViewportPoint(pos)
		if onScreen then point = Vector2.new(vp.X, vp.Y) end
	end
	if mouse1move then pcall(mouse1move, point.X, point.Y) end
	if mouse1click then if pcall(mouse1click) then return end end
	pcall(function()
		VirtualUser:CaptureController()
		VirtualUser:Button1Down(point, cam.CFrame)
		task.wait(0.04)
		VirtualUser:Button1Up(point, cam.CFrame)
	end)
end

local function touchPart(part)
	if not firetouchinterest then return end
	local my = hrp(); if not my or not part then return end
	pcall(function()
		firetouchinterest(my, part, 0)
		task.wait(0.02)
		firetouchinterest(my, part, 1)
	end)
end

local function firePrompt(entry)
	if not promptAlive(entry) then return false end
	if entry.prompt then
		if fireproximityprompt then
			local ok = pcall(fireproximityprompt, entry.prompt)
			if ok then return true end
		end
		pcall(function()
			entry.prompt:InputHoldBegin()
			task.wait(math.max(tonumber(entry.prompt.HoldDuration) or 0, 0) + 0.05)
			entry.prompt:InputHoldEnd()
		end)
		return true
	end
	if entry.click then
		if fireclickdetector then
			local ok = pcall(fireclickdetector, entry.click)
			if ok then return true end
		end
		clickScreen(entry.part.Position)
		return true
	end
	return false
end

local function toolBy(words)
	local c = char(); if not c then return nil end
	for _, box in ipairs({ c, LP:FindFirstChild("Backpack") }) do
		if box then
			for _, t in ipairs(box:GetChildren()) do
				if t:IsA("Tool") and hit(t.Name, words) then return t end
			end
		end
	end
	return nil
end
local function equip(words)
	local h, t = hum(), toolBy(words)
	if not h or not t then return nil end
	if t.Parent ~= char() then pcall(function() h:EquipTool(t) end) end
	return t
end
local function useTool(times, gap)
	local t = char() and char():FindFirstChildOfClass("Tool")
	if not t then return false end
	for _ = 1, times or 1 do
		pcall(function() t:Activate() end)
		task.wait(pause(gap or 0.12))
	end
	return true
end

--------------------------------------------------------------------------------
-- Engine
--------------------------------------------------------------------------------
local function register(flag, prio, step, name)
	P.Actions[flag] = { prio = prio, step = step, name = name or flag }
end

local function engineLoop()
	while not P.Destroyed do
		local best, prio = nil, -1
		for flag, a in pairs(P.Actions) do
			if P.State[flag] and a.prio > prio then best, prio = a, a.prio end
		end
		if best then
			local ok, err = pcall(best.step)
			if not ok then warnOnce("a" .. best.name, ("%s ผิดพลาด: %s"):format(best.name, tostring(err):sub(1, 70))) end
		else
			task.wait(0.12)
		end
		if Cfg.Turbo then task.wait() else task.wait(pause(Cfg.Delay)) end
	end
end

-- ขั้นตอนกลาง: หมวดไหนมี prompt ก็กด prompt, ไม่มีก็ใช้ไอเทม/แตะ
local function catStep(cat, prio, fallbackTool)
	register("Auto_" .. cat, prio, function()
		local e = nearestPrompt(cat)
		if e then
			local reach = math.min(tonumber(e.prompt and e.prompt.MaxActivationDistance) or 10, 20) - 1
			if walkTo(e.part.Position, math.max(reach, 3)) then
				local last = P.Cool[e.prompt or e.click] or 0
				if os.clock() - last < Cfg.PromptCd then return end
				P.Cool[e.prompt or e.click] = os.clock()
				aim(e.part.Position)
				firePrompt(e)
				P.Stats.actions += 1
				if cat == "sell" then P.Stats.sells += 1 end
			else
				aim(e.part.Position)
			end
			return
		end
		-- ไม่มี prompt → ใช้ไอเทมกับวัตถุ (ถ้ามีคำค้น)
		local words = PART_WORDS[cat]
		if not words then warnOnce("np" .. cat, "ไม่พบปุ่ม '" .. CAT[cat].label .. "' ในระยะ " .. Cfg.Range) return end
		local target = nearestPart(words)
		if not target then warnOnce("npart" .. cat, "ไม่พบวัตถุหมวด " .. CAT[cat].label) return end
		if walkTo(target.Position, Cfg.Reach) then
			if fallbackTool then
				equip(TOOL_WORDS[cat] or {})
				aim(target.Position)
				useTool(2, 0.14)
			end
			touchPart(target)
			clickScreen(target.Position)
			P.Stats.actions += 1
		else
			aim(target.Position)
		end
	end, CAT[cat].label)
end

local prioList = {
	harvest = 96, water = 94, plant = 92, egg = 88, pet = 86,
	mine = 80, chop = 76, fish = 72,
	claim = 50, sell = 46, craft = 44, buy = 40, talk = 30,
}
for _, cat in ipairs(CAT_ORDER) do
	catStep(cat, prioList[cat] or 60, TOOL_WORDS[cat] ~= nil)
end

-- เก็บของตก (เดินผ่าน/แตะ)
local function lootStep()
	local target, d = nearestPart(LOOT_WORDS, 120)
	if not target then return end
	if walkTo(target.Position, 3) then
		touchPart(target)
		P.Stats.items += 1
	else
		aim(target.Position)
	end
end
register("Auto_loot", 60, lootStep, "เก็บของตก")

--------------------------------------------------------------------------------
-- ESP + Radar
--------------------------------------------------------------------------------
local espMap = {}
local function espLoop()
	while not P.Destroyed do
		local my = hrp()
		if Cfg.ESP and my then
			for _, e in ipairs(P.W.prompts) do
				local key = e.prompt or e.click
				if key and not espMap[key] and e.cat then
					local hl = new("Highlight", { FillColor = CAT[e.cat].col, OutlineColor = CAT[e.cat].col,
						FillTransparency = 0.72, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Adornee = e.part }, e.part)
					espMap[key] = hl
				end
			end
			for key, hl in pairs(espMap) do
				if not key.Parent or not hl.Adornee or not hl.Adornee.Parent then
					hl:Destroy(); espMap[key] = nil
				end
			end
		end
		task.wait(Cfg.LowPower and 2.4 or 1.6)
	end
end

local radarRows = {}
local function radarLoop()
	while not P.Destroyed do
		if Cfg.Radar and P.RadarBox then
			local my = hrp()
			local list = {}
			if my then
				for _, e in ipairs(P.W.prompts) do
					if e.cat and P.State["Auto_" .. e.cat] then
						list[#list + 1] = e
					end
				end
			end
			table.sort(list, function(a, b) return a.d < b.d end)
			local n = #radarRows
			for i = 1, n do
				local row = radarRows[i]
				local e = list[i]
				if e then
					row.Visible = true
					row.Text = ("%s • %s • %dm"):format(CAT[e.cat].label, (e.part.Name):sub(1, 14), math.floor(e.d))
					row.TextColor3 = CAT[e.cat].col
				else
					row.Visible = false
				end
			end
		end
		task.wait(Cfg.LowPower and 1.8 or 1.1)
	end
end

--------------------------------------------------------------------------------
-- สถิติ
--------------------------------------------------------------------------------
local fps, frames, acc = 60, 0, 0
conn(RunService.Heartbeat, function(dt)
	frames += 1; acc += dt
	if acc >= 1 then fps = math.floor(frames / acc + 0.5); frames, acc = 0, 0 end
end)

--------------------------------------------------------------------------------
-- Movement
--------------------------------------------------------------------------------
local flyBody
local function stopFly()
	P.State.Fly = false
	if flyBody and flyBody.Parent then flyBody:Destroy() end
	flyBody = nil
	local h = hum(); if h then h.PlatformStand = false end
end
local function startFly()
	local my, h = hrp(), hum(); if not my or not h then return end
	h.PlatformStand = true
	flyBody = new("BodyVelocity", { MaxForce = Vector3.new(1e5, 1e5, 1e5), Velocity = Vector3.zero }, my)
	task.spawn(function()
		while P.State.Fly and my.Parent do
			local cam = Workspace.CurrentCamera
			local dir = Vector3.zero
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += cam.CFrame.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= cam.CFrame.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += cam.CFrame.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= cam.CFrame.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.yAxis end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.yAxis end
			local hh = hum()
			local mv = hh and hh.MoveDirection or Vector3.zero
			if mv.Magnitude > 0.05 then dir += mv.Unit end
			flyBody.Velocity = dir * Cfg.FlySpeed
			task.wait()
		end
	end)
end

local noclipTick = 0
conn(RunService.Stepped, function()
	noclipTick += 1
	local h = hum(); if not h then return end
	if P.State.Speed and h.WalkSpeed ~= Cfg.Speed then h.WalkSpeed = Cfg.Speed end
	if P.State.Jump and h.JumpPower ~= Cfg.Jump then h.UseJumpPower = true; h.JumpPower = Cfg.Jump end
	if P.State.Noclip and noclipTick % 4 == 0 then
		local c = char()
		if c then for _, p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end end
	end
end)
conn(UserInputService.JumpRequest, function()
	if P.State.InfJump and alive() then local h = hum(); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end end
end)
conn(LP.Idled, function()
	if not Cfg.AntiAfk then return end
	pcall(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.zero)
	end)
end)

--------------------------------------------------------------------------------
-- GUI toolkit
--------------------------------------------------------------------------------
local function guiParent() return LP:WaitForChild("PlayerGui") end

local gui = new("ScreenGui", { Name = "GardenProX", ResetOnSpawn = false, IgnoreGuiInset = false,
	DisplayOrder = 9999, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, guiParent())
P.Toasts = new("Frame", { Size = UDim2.fromOffset(270, 300), Position = UDim2.new(1, -286, 0, 92),
	BackgroundTransparency = 1, Active = false, ZIndex = 200 }, gui)
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, P.Toasts)

local root, pill
local shown = true
local function uiSafe() end
local function setShown(v)
	shown = v
	if root then root.Visible = v end
	if pill then pill.Visible = not v end
	if v then pcall(uiSafe) end
end

pill = new("TextButton", { Size = UDim2.fromOffset(52, 52), Position = UDim2.fromOffset(14, 92), Visible = false,
	BackgroundColor3 = T.card, AutoButtonColor = false, Font = Enum.Font.GothamBlack, TextSize = 14,
	TextColor3 = T.accent, Text = "GP", ZIndex = 210, Active = true }, gui)
corner(pill, 26)
stroke(pill, T.stroke, 0.25)

root = new("Frame", { Size = UDim2.fromOffset(600, 440), AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.46), BackgroundColor3 = T.bg, BorderSizePixel = 0,
	ClipsDescendants = true, Active = true, ZIndex = 10 }, gui)
corner(root, 15)
stroke(root, T.stroke, 0.2)
new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(18, 21, 28), Color3.fromRGB(12, 14, 19)) }, root)
local uiscale = new("UIScale", { Scale = 1 }, root)

local function fit()
	local cam = Workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local s = math.clamp(math.min(vp.X / 700, vp.Y / 520), 0.5, 1.15)
	uiscale.Scale = s
	root.Position = UDim2.fromScale(0.5, isMobile and 0.45 or 0.46)
end
uiSafe = function() pcall(fit) root.Visible = true; pill.Visible = false; shown = true end

local header = new("Frame", { Size = UDim2.new(1, 0, 0, 54), BackgroundColor3 = T.card, BorderSizePixel = 0 }, root)
corner(header, 15)
new("Frame", { Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 1, -22), BackgroundColor3 = T.card, BorderSizePixel = 0 }, header)
new("Frame", { Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 1, -2) }, header)
local glow = new("Frame", { Size = UDim2.new(1, -30, 0, 1), Position = UDim2.new(0, 15, 1, -1), BorderSizePixel = 0 }, header)
new("UIGradient", { Color = ColorSequence.new(T.accent, T.accent2), Rotation = 15 }, glow)

local logo = new("Frame", { Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(14, 13),
	BackgroundColor3 = T.accent, BorderSizePixel = 0, ZIndex = 2 }, header)
corner(logo, 9)
new("UIGradient", { Color = ColorSequence.new(T.accent, T.accent2), Rotation = 35 }, logo)
new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack,
	TextSize = 14, TextColor3 = T.bg, Text = "G" }, logo)

new("TextLabel", { Size = UDim2.fromOffset(260, 16), Position = UDim2.fromOffset(50, 12), BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = T.text, TextXAlignment = Enum.TextXAlignment.Left,
	Text = "GARDENPRO X" }, header)
new("TextLabel", { Size = UDim2.fromOffset(300, 14), Position = UDim2.fromOffset(50, 29), BackgroundTransparency = 1,
	Font = Enum.Font.Gotham, TextSize = 9, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Left,
	Text = "UNIVERSAL HELP  •  ใช้ได้ทุกแมพ  •  v" .. VERSION }, header)

local function hbtn(x, text, col)
	local b = new("TextButton", { Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, x, 0, 14),
		BackgroundColor3 = T.well, AutoButtonColor = false, Font = Enum.Font.GothamBold, TextSize = 12,
		TextColor3 = col or T.sub, Text = text }, header)
	corner(b, 8)
	stroke(b, T.stroke, 0.4)
	return b
end
local minBtn = hbtn(-62, "—")
local closeBtn = hbtn(-32, "✕", T.danger)

-- แถบแท็บ
local tabRail = new("Frame", { Size = UDim2.new(1, -20, 0, 32), Position = UDim2.fromOffset(10, 60),
	BackgroundColor3 = T.well, BackgroundTransparency = 0.3, BorderSizePixel = 0 }, root)
corner(tabRail, 10)
stroke(tabRail, T.stroke, 0.5)

local content = new("Frame", { Size = UDim2.new(1, -20, 1, -128), Position = UDim2.fromOffset(10, 98),
	BackgroundTransparency = 1 }, root)
local footer = new("Frame", { Size = UDim2.new(1, -20, 0, 22), Position = UDim2.new(0, 10, 1, -26),
	BackgroundTransparency = 1 }, root)
new("TextLabel", { Size = UDim2.new(1, -60, 1, 0), BackgroundTransparency = 1, Font = Enum.Font.Gotham,
	TextSize = 9, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Left,
	Text = "RightShift ซ่อน • ปุ่ม GP เปิดคืน • ทุกอย่างทำงานฝั่งเครื่องคุณเท่านั้น" }, footer)
local verLbl = new("TextLabel", { Size = UDim2.fromOffset(52, 1), Position = UDim2.new(1, -52, 0, 4),
	BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 9, TextColor3 = T.stroke,
	TextXAlignment = Enum.TextXAlignment.Right, Text = "v" .. VERSION }, footer)

local TAB_NAMES = { "หลัก", "ปุ่มโต้ตอบ", "เก็บของ", "เครื่องมือ", "ตั้งค่า" }
local tabBtns, tabs = {}, {}
local indicator = new("Frame", { Size = UDim2.new(1 / #TAB_NAMES, -8, 0, 24), Position = UDim2.new(0, 4, 0, 4),
	BackgroundColor3 = T.accent, BorderSizePixel = 0, ZIndex = 2 }, tabRail)
corner(indicator, 8)
new("UIGradient", { Color = ColorSequence.new(T.accent, T.accent2), Rotation = 20 }, indicator)

local function makePage()
	local s = new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 3, ScrollBarImageColor3 = T.stroke, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false }, content)
	new("UIPadding", { PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 2),
		PaddingBottom = UDim.new(0, 8) }, s)
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, s)
	return s
end

local function selectTab(i)
	for idx, p in ipairs(tabs) do p.Visible = (idx == i) end
	for idx, b in ipairs(tabBtns) do
		b.TextColor3 = (idx == i) and T.bg or T.sub
		b.Font = (idx == i) and Enum.Font.GothamBold or Enum.Font.Gotham
	end
	tw(indicator, 0.2, { Position = UDim2.new((i - 1) / #TAB_NAMES, 4, 0, 4) })
end

for i, name in ipairs(TAB_NAMES) do
	local b = new("TextButton", { Size = UDim2.new(1 / #TAB_NAMES, 0, 1, 0),
		Position = UDim2.new((i - 1) / #TAB_NAMES, 0, 0, 0), BackgroundTransparency = 1,
		Font = Enum.Font.Gotham, TextSize = 10.5, TextColor3 = T.sub, Text = name, ZIndex = 3 }, tabRail)
	tabBtns[i] = b
	tabs[i] = makePage()
	b.MouseButton1Click:Connect(function() selectTab(i) end)
end

-- widgets
local function section(parent, text, col)
	local w = new("Frame", { Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1 }, parent)
	new("Frame", { Size = UDim2.fromOffset(3, 11), Position = UDim2.fromOffset(2, 3), BackgroundColor3 = col or T.accent }, w)
	new("TextLabel", { Size = UDim2.new(1, -14, 1, 0), Position = UDim2.fromOffset(12, 0), BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold, TextSize = 9.5, TextColor3 = T.sub, TextXAlignment = Enum.TextXAlignment.Left,
		Text = string.upper(text) }, w)
	return w
end
local function card(parent, h)
	local f = new("Frame", { Size = UDim2.new(1, 0, 0, h or 34), BackgroundColor3 = T.card,
		BackgroundTransparency = 0.1, BorderSizePixel = 0 }, parent)
	corner(f, 9)
	stroke(f, T.stroke, 0.45)
	return f
end
local function toggle(parent, label, flag, onOn, onOff, desc)
	local f = card(parent, desc and 48 or 34)
	new("TextLabel", { Size = UDim2.new(1, -80, 0, 15), Position = UDim2.fromOffset(11, desc and 7 or 9),
		BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = T.text,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = label }, f)
	if desc then
		new("TextLabel", { Size = UDim2.new(1, -80, 0, 13), Position = UDim2.fromOffset(11, 24),
			BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 9, TextColor3 = T.muted,
			TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = desc }, f)
	end
	local sw = new("Frame", { Size = UDim2.fromOffset(40, 20), Position = UDim2.new(1, -50, 0.5, -10),
		BackgroundColor3 = T.well, BorderSizePixel = 0 }, f)
	corner(sw, 10)
	local sws = stroke(sw, T.accent, 0.9)
	local knob = new("Frame", { Size = UDim2.fromOffset(14, 14), Position = UDim2.new(0, 3, 0.5, -7),
		BackgroundColor3 = T.text, BorderSizePixel = 0 }, sw)
	corner(knob, 7)
	local hitBtn = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "" }, f)
	local function render(v)
		tw(sw, 0.15, { BackgroundColor3 = v and T.accent or T.well })
		tw(sws, 0.15, { Transparency = v and 0.9 or 1 })
		tw(knob, 0.16, { Position = UDim2.new(0, v and 23 or 3, 0.5, -7), BackgroundColor3 = v and T.bg or T.text })
	end
	local function set(v)
		P.State[flag] = v
		render(v)
		if v then if onOn then pcall(onOn) end else if onOff then pcall(onOff) end end
	end
	P.Set = P.Set or {}
	P.Set[flag] = set
	hitBtn.MouseButton1Click:Connect(function() set(not P.State[flag]) end)
	render(false)
	P.Rows = P.Rows or {}
	P.Rows[flag] = f
	return set
end
local function slider(parent, label, minV, maxV, cur, fmt, onChange)
	local f = card(parent, 42)
	local l = new("TextLabel", { Size = UDim2.new(1, -20, 0, 14), Position = UDim2.fromOffset(11, 5),
		BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 10.5, TextColor3 = T.text,
		TextXAlignment = Enum.TextXAlignment.Left, Text = label }, f)
	local track = new("Frame", { Size = UDim2.new(1, -24, 0, 4), Position = UDim2.new(0, 12, 0, 30),
		BackgroundColor3 = T.well, BorderSizePixel = 0 }, f)
	corner(track, 2)
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.accent, BorderSizePixel = 0 }, track)
	corner(fill, 2)
	local knob = new("Frame", { Size = UDim2.fromOffset(10, 10), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0), BackgroundColor3 = T.text, BorderSizePixel = 0 }, track)
	corner(knob, 5)
	local hitBox = new("TextButton", { Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 16),
		BackgroundTransparency = 1, Text = "" }, f)
	local value = cur
	local function render()
		local a = math.clamp((value - minV) / math.max(maxV - minV, 1), 0, 1)
		fill.Size = UDim2.fromScale(a, 1)
		knob.Position = UDim2.new(a, 0, 0.5, 0)
		l.Text = ("%s • %s"):format(label, fmt:format(value))
	end
	local function apply(v)
		value = math.floor(v + 0.5); render()
		if onChange then pcall(onChange, value) end
	end
	local dragging = false
	local function calc(px)
		apply(minV + math.clamp((px - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1) * (maxV - minV))
	end
	hitBox.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true; calc(i.Position.X)
		end
	end)
	conn(UserInputService.InputChanged, function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			calc(i.Position.X)
		end
	end)
	conn(UserInputService.InputEnded, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end)
	render()
	return apply
end
local function button(parent, label, col, cb, h)
	local filled = col ~= nil and col ~= T.card
	local row = new("Frame", { Size = UDim2.new(1, 0, 0, h or 32), BackgroundColor3 = col or T.card,
		BackgroundTransparency = filled and 0 or 0.1, BorderSizePixel = 0 }, parent)
	corner(row, 9)
	stroke(row, col or T.stroke, filled and 0.5 or 0.45)
	new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
		TextSize = 11, TextColor3 = filled and T.bg or T.text, Text = label }, row)
	local b = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "" }, row)
	b.MouseButton1Click:Connect(function() if cb then pcall(cb) end end)
	return row
end
local function statusCard(parent, rows)
	local h = 14 * (rows or 2) + 12
	local f = card(parent, h)
	new("Frame", { Size = UDim2.fromOffset(2, h - 12), Position = UDim2.fromOffset(0, 6),
		BackgroundColor3 = T.accent, BackgroundTransparency = 0.25 }, f)
	local l = new("TextLabel", { Size = UDim2.new(1, -20, 1, -8), Position = UDim2.fromOffset(10, 4),
		BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 10, TextColor3 = T.sub,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true, Text = "—" }, f)
	return l
end
local function setLbl(l, text) if l and l.Text ~= text then l.Text = text end end

--------------------------------------------------------------------------------
-- TAB 1 : หลัก
--------------------------------------------------------------------------------
local pMain = tabs[1]
section(pMain, "เริ่มใช้งานเร็ว", T.accent)
button(pMain, "▶ เปิดทุกหมวดที่เจอในแมพนี้", T.accent, function()
	local n = 0
	for _, cat in ipairs(CAT_ORDER) do
		if countCat(cat) > 0 and P.Set["Auto_" .. cat] then
			P.Set["Auto_" .. cat](true); n += 1
		end
	end
	if n == 0 then toast("ไม่พบปุ่มโต้ตอบในระยะ — ลองเพิ่มระยะค้นหา", T.gold)
	else toast(("เปิด %d หมวด • กำลังเดินไปกดให้"):format(n), T.accent) end
end, 34)
button(pMain, "■ หยุดทั้งหมด", Color3.fromRGB(150, 60, 70), function()
	for _, setter in pairs(P.Set or {}) do pcall(setter, false) end
	pcall(stopFly)
	toast("หยุดทั้งหมดแล้ว", T.sub)
end, 30)

section(pMain, "สถานะ")
local dash = statusCard(pMain, 6)
local catList = new("Frame", { Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1 }, pMain)
new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, catList)

section(pMain, "เครื่องมือด่วน", T.accent2)
button(pMain, "🔍 ตรวจแมพ (คัดลอกรายงาน)", T.violet, function() P.Diagnose() end)
button(pMain, "🎯 วาร์ปไปปุ่มที่ใกล้สุด", T.accent2, function()
	local my = hrp()
	local nearest, nd = nil, math.huge
	for _, e in ipairs(P.W.prompts) do
		if e.cat and e.d < nd then nearest, nd = e, e.d end
	end
	if nearest and my then my.CFrame = CFrame.new(nearest.part.Position + Vector3.new(0, 6, 0))
		toast(("วาร์ปไป %s (%.0fm)"):format(CAT[nearest.cat].label, nd), T.accent)
	else toast("ยังไม่พบปุ่มในระยะ", T.gold) end
end)

--------------------------------------------------------------------------------
-- TAB 2 : ปุ่มโต้ตอบ (auto prompt)
--------------------------------------------------------------------------------
local pPrompt = tabs[2]
section(pPrompt, "กดปุ่มให้อัตโนมัติ (เดินไปเอง)", T.accent)
local promptToggles = {}
for _, cat in ipairs(CAT_ORDER) do
	local row = toggle(pPrompt, ("%s  (%s)"):format(CAT[cat].label, cat), "Auto_" .. cat, nil, nil,
		"เดินไปหาแล้วกด ProximityPrompt / คลิกให้")
	promptToggles[cat] = row
end
slider(pPrompt, "ระยะค้นหา", 300, 8000, Cfg.Range, "%d", function(v) Cfg.Range = v end)
slider(pPrompt, "ดีเลย์ระหว่างกด (x0.1 วิ)", 0, 30, math.floor(Cfg.PromptCd * 10), "%d",
	function(v) Cfg.PromptCd = v / 10 end)

section(pPrompt, "เรดาร์ (ใกล้สุด)", T.gold)
local radarBox = new("Frame", { Size = UDim2.new(1, 0, 0, 96), BackgroundColor3 = T.well,
		BackgroundTransparency = 0.25, BorderSizePixel = 0 }, pPrompt)
corner(radarBox, 9)
stroke(radarBox, T.stroke, 0.5)
pad(radarBox, 7)
for i = 1, 6 do
	local r = new("TextLabel", { Size = UDim2.new(1, 0, 0, 13), BackgroundTransparency = 1, Font = Enum.Font.Code,
		TextSize = 10, TextColor3 = T.sub, TextXAlignment = Enum.TextXAlignment.Left, Visible = false }, radarBox)
	radarRows[i] = r
end
radarRows[1].Visible = true
radarRows[1].Text = "เปิดสวิตช์ด้านบนเพื่อดูรายการ"
P.RadarBox = radarBox

--------------------------------------------------------------------------------
-- TAB 3 : เก็บของ
--------------------------------------------------------------------------------
local pGather = tabs[3]
section(pGather, "เหมือง / ป่า / ทะเล / ฟาร์ม", T.accent)
toggle(pGather, "เก็บของตก / เหรียญที่ร่วง", "Auto_loot", nil, nil, "เดินไปแตะวัตถุที่ชื่อมี coin/drop/loot")
slider(pGather, "ระยะเข้าถึง", 3, 20, Cfg.Reach, "%d", function(v) Cfg.Reach = v end)

section(pGather, "แสดงผล (ESP)", T.violet)
toggle(pGather, "ไฮไลต์ปุ่มโต้ตอบ", "ESP", function() Cfg.ESP = true end, function() Cfg.ESP = false end)
toggle(pGather, "แสดงเรดาร์บนสุด", "RadarOn", function() Cfg.Radar = true end, function() Cfg.Radar = false end)

section(pGather, "ไทม์เมอร์", T.gold)
local timerRow = new("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1 }, pGather)
local chipRow = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, timerRow)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5),
	SortOrder = Enum.SortOrder.LayoutOrder }, chipRow)
local timerLbl = statusCard(pGather, 2)
local timers = {}
local function fmtTime(s)
	s = math.max(0, math.floor(s + 0.5))
	return ("%02d:%02d"):format(math.floor(s / 60), s % 60)
end
local function addTimer(mins)
	local t = { label = mins .. " นาที", endAt = os.clock() + mins * 60 }
	timers[#timers + 1] = t
	toast(("เริ่มไทม์เมอร์ %d นาที"):format(mins), T.gold)
	return t
end
local function sound()
	local s = new("Sound", { SoundId = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.35 }, gui)
	s:Play()
	task.delay(2, function() if s.Parent then s:Destroy() end end)
end
for i, mins in ipairs({ 1, 5, 10, 30 }) do
	local b = new("TextButton", { Size = UDim2.fromOffset(52, 28), BackgroundColor3 = T.card, AutoButtonColor = false,
		Font = Enum.Font.GothamBold, TextSize = 10.5, TextColor3 = T.gold, Text = mins .. "น." }, chipRow)
	corner(b, 8); stroke(b, T.stroke, 0.5)
	b.MouseButton1Click:Connect(function() addTimer(mins) end)
end

--------------------------------------------------------------------------------
-- TAB 4 : เครื่องมือ (movement)
--------------------------------------------------------------------------------
local pTools = tabs[4]
section(pTools, "การเคลื่อนที่", T.accent)
slider(pTools, "ความเร็วเดิน", 16, 300, Cfg.Speed, "%d", function(v) Cfg.Speed = v end)
slider(pTools, "พลังกระโดด", 50, 400, Cfg.Jump, "%d", function(v) Cfg.Jump = v end)
slider(pTools, "ความเร็วบิน", 10, 400, Cfg.FlySpeed, "%d", function(v) Cfg.FlySpeed = v end)
toggle(pTools, "เพิ่มความเร็ว", "Speed")
toggle(pTools, "กระโดดสูง", "Jump")
toggle(pTools, "กระโดดไม่จำกัด", "InfJump")
toggle(pTools, "เดินทะลุของ", "Noclip", nil, function()
	local c = char(); if c then for _, p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = true end end end
end)
toggle(pTools, "บิน (จอยลอย/คีย์บอร์ด)", "Fly", startFly, stopFly)
button(pTools, "กลับจุดเกิด", T.card, function()
	local s = Workspace:FindFirstChildOfClass("SpawnLocation")
	if s then hrp().CFrame = s.CFrame + Vector3.new(0, 5, 0) else local h = hum(); if h then h.Health = 0 end end
end)

section(pTools, "โหมดเครื่อง", T.gold)
toggle(pTools, "โหมดโหด (ไม่มีดีเลย์)", "Turbo", function()
	Cfg.Turbo = true; Cfg.Humanize = false; Cfg.Delay = 0.01
end, function()
	Cfg.Turbo = false; Cfg.Humanize = true; Cfg.Delay = 0.06
end, "เร็วสุด ไม่หน่วงสุ่ม (อาจดูไม่เป็นธรรมชาติ)")
toggle(pTools, "โหมดประหยัด", "LowPower", function() Cfg.LowPower = true end, function() Cfg.LowPower = false end,
	"ลดความถี่การอัปเดตเรดาร์/ESP ลงครึ่ง")
toggle(pTools, "กันเตะ AFK", "AntiAfk", function() Cfg.AntiAfk = true end, function() Cfg.AntiAfk = false end)

--------------------------------------------------------------------------------
-- TAB 5 : ตั้งค่า
--------------------------------------------------------------------------------
local pSet = tabs[5]
section(pSet, "ระบบ", T.accent2)
button(pSet, "🔄 สแกนใหม่ทันที", T.accent2, function() refresh(); toast(("พบวัตถุ %d • ปุ่ม %d"):format(#P.W.parts, #P.W.prompts), T.accent) end)
button(pSet, "🔍 ตรวจแมพ + คัดลอกรายงาน", T.violet, function() P.Diagnose() end)
button(pSet, "🛠 ซ่อม UI (คืนตำแหน่ง/ขนาด)", T.card, function() uiSafe(); toast("ซ่อม UI แล้ว", T.accent) end)

section(pSet, "คอนโซล")
P.Console = new("Frame", { Size = UDim2.new(1, 0, 0, 150), BackgroundColor3 = T.well,
	BackgroundTransparency = 0.15, BorderSizePixel = 0 }, pSet)
corner(P.Console, 9)
stroke(P.Console, T.stroke, 0.5)
pad(P.Console, 6)
new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, P.Console)

section(pSet, "เกี่ยวกับ")
button(pSet, "ปิดสคริปต์ทั้งหมด", Color3.fromRGB(150, 60, 70), function() P.Destroy() end)
local about = new("TextLabel", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = T.card, BackgroundTransparency = 0.1, Font = Enum.Font.Gotham, TextSize = 9.5,
	TextColor3 = T.sub, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
	Text = "  วิธีใช้: แท็บ 'ปุ่มโต้ตอบ' เปิดหมวดที่อยากให้กด (เช่น เก็บเกี่ยว / ขุด / ขาย) แล้วตัวละครจะเดินไปกดเอง\n  ถ้าหมวดไหนขึ้น 0 = ไม่มีปุ่มชนิดนั้นในระยะ → เพิ่ม 'ระยะค้นหา' หรือใช้ปุ่มตรวจแมพดูของจริงในเกม" }, pSet)
corner(about, 9); pad(about, 8)

--------------------------------------------------------------------------------
-- Diagnose
--------------------------------------------------------------------------------
function P.Diagnose()
	pcall(refresh)
	local lines = {}
	local function add(fmt, ...)
		local ok, s = pcall(string.format, fmt, ...)
		lines[#lines + 1] = ok and s or tostring(fmt)
	end
	add("=== GardenProX v%s diagnose ===", VERSION)
	add("place=%s player=%s mobile=%s", game.PlaceId, LP.Name, tostring(isMobile))
	add("parts=%d prompts=%d range=%d", #P.W.parts, #P.W.prompts, Cfg.Range)
	local byCat = {}
	for _, e in ipairs(P.W.prompts) do
		local k = e.cat or "ไม่ระบุ"
		byCat[k] = (byCat[k] or 0) + 1
	end
	for _, cat in ipairs(CAT_ORDER) do
		if byCat[cat] then add("  %s = %d", CAT[cat].label, byCat[cat]) end
	end
	if byCat["ไม่ระบุ"] then add("  ไม่ระบุหมวด = %d", byCat["ไม่ระบุ"]) end
	add("รายการปุ่ม (ใกล้สุด 12)")
	for i = 1, math.min(#P.W.prompts, 12) do
		local e = P.W.prompts[i]
		add("  [%s] %s → %s (%dm)", tostring(e.cat), (e.prompt and e.prompt.ActionText or "คลิก"):sub(1, 12),
			e.part.Name:sub(1, 18), math.floor(e.d))
	end
	local bp = LP:FindFirstChild("Backpack")
	local tools = {}
	if bp then for _, t in ipairs(bp:GetChildren()) do if t:IsA("Tool") then tools[#tools + 1] = t.Name end end end
	add("ไอเท็มในกระเป๋า = %d", #tools)
	for i = 1, math.min(#tools, 10) do add("  %s", tools[i]) end
	local txt = table.concat(lines, "\n")
	print(txt)
	if setclipboard then pcall(setclipboard, txt) end
	for _, l in ipairs(lines) do log(l) end
	toast("คัดลอกรายงานแล้ว — ส่งมาให้ดูได้", T.accent)
end

--------------------------------------------------------------------------------
-- ลูป UI
--------------------------------------------------------------------------------
task.spawn(function()
	local acc2 = 0
	while not P.Destroyed do
		task.wait(0.5)
		acc2 += 0.5
		if pMain.Visible then
			local active = {}
			for flag in pairs(P.Actions) do if P.State[flag] then active[#active + 1] = flag:gsub("Auto_", "") end end
			table.sort(active)
			local ping = 0
			pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
			setLbl(dash, ("ทำงาน: %s\nปุ่มในระยะ: %d • วัตถุ: %d\nFPS %d • PING %d • กดไปแล้ว %d ครั้ง\nเวลาเล่น %s"):format(
				#active > 0 and table.concat(active, ", ") or "หยุดอยู่",
				#P.W.prompts, #P.W.parts, fps, ping, P.Stats.actions, fmtTime(os.clock() - P.Stats.start)))
		end
		if acc2 >= 1.5 then
			acc2 = 0
			for _, c in ipairs(catList:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() end end
			for _, cat in ipairs(CAT_ORDER) do
				local n = countCat(cat)
				if n > 0 then
					local l = new("TextLabel", { Size = UDim2.new(1, 0, 0, 13), BackgroundTransparency = 1,
						Font = Enum.Font.Code, TextSize = 10, TextColor3 = P.State["Auto_" .. cat] and CAT[cat].col or T.muted,
						TextXAlignment = Enum.TextXAlignment.Left,
						Text = ("%s %-12s %d ปุ่ม%s"):format(P.State["Auto_" .. cat] and "●" or "○", CAT[cat].label, n,
							P.State["Auto_" .. cat] and "  (กำลังทำ)" or "") }, catList)
					l.Text = ("%s  %s — %d ปุ่ม%s"):format(P.State["Auto_" .. cat] and "●" or "○", CAT[cat].label, n,
						P.State["Auto_" .. cat] and "  กำลังทำ" or "")
				end
			end
			if #catList:GetChildren() <= 1 then
				new("TextLabel", { Size = UDim2.new(1, 0, 0, 13), BackgroundTransparency = 1, Font = Enum.Font.Code,
					TextSize = 10, TextColor3 = T.gold, TextXAlignment = Enum.TextXAlignment.Left,
					Text = "ไม่พบปุ่มโต้ตอบในระยะ — เพิ่มระยะค้นหา หรือกดตรวจแมพ" }, catList)
			end
			if P.Rows then
				for _, cat in ipairs(CAT_ORDER) do
					local row = P.Rows["Auto_" .. cat]
					if row then
						local lbl = row:FindFirstChildOfClass("TextLabel")
						if lbl then lbl.Text = ("%s  (%d ปุ่ม)"):format(CAT[cat].label, countCat(cat)) end
					end
				end
			end
		end
		if timerLbl then
			if #timers > 0 then
				local now = os.clock()
				local out = {}
				for i = #timers, 1, -1 do
					local t = timers[i]
					if now >= t.endAt then
						table.remove(timers, i)
						toast(t.label .. " ครบเวลา!", T.gold)
						sound()
					else
						table.insert(out, 1, ("%s → %s"):format(t.label, fmtTime(t.endAt - now)))
					end
				end
				setLbl(timerLbl, #out > 0 and table.concat(out, "\n") or "ไม่มีไทม์เมอร์ทำงาน")
			else
				setLbl(timerLbl, "ไม่มีไทม์เมอร์ทำงาน")
			end
		end
	end
end)

--------------------------------------------------------------------------------
-- input / drag / boot
--------------------------------------------------------------------------------
conn(UserInputService.InputBegan, function(i, busy)
	if busy then return end
	if i.KeyCode == Enum.KeyCode.RightShift then setShown(not shown) end
	if i.KeyCode == Enum.KeyCode.RightControl then P.Destroy() end
end)
minBtn.MouseButton1Click:Connect(function() setShown(false) end)
closeBtn.MouseButton1Click:Connect(function() P.Destroy() end)
pill.MouseButton1Click:Connect(function() setShown(true) end)

local dragging, from, startPos
header.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
		dragging, from, startPos = true, i.Position, root.Position
	end
end)
conn(UserInputService.InputChanged, function(i)
	if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
		local d = i.Position - from
		root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
	end
end)
conn(UserInputService.InputEnded, function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
end)

function P.Destroy()
	if P.Destroyed then return end
	P.Destroyed = true
	for k in pairs(P.State) do P.State[k] = false end
	pcall(stopFly)
	for _, c in ipairs(P.Conns) do pcall(function() c:Disconnect() end) end
	for _, h in pairs(espMap) do if h then h:Destroy() end end
	if gui then gui:Destroy() end
	if _G.GardenProX == P then _G.GardenProX = nil end
end

selectTab(1)
pcall(fit)

task.spawn(engineLoop)
task.spawn(espLoop)
task.spawn(radarLoop)

task.spawn(function()
	task.wait(isMobile and 2.5 or 1.2)
	for _, d in ipairs(Workspace:GetDescendants()) do track(d) end
	conn(Workspace.DescendantAdded, track)
	conn(Workspace.DescendantRemoving, function(d) if tracked[d] then tracked[d] = nil end end)
	refresh()
	pcall(fit)
	local n = #P.W.prompts
	toast(("GardenPro X v%s พร้อม • พบปุ่ม %d"):format(VERSION, n), T.accent)
	log(("พบปุ่มโต้ตอบ %d • วัตถุ %d ในระยะ %d"):format(n, #P.W.parts, Cfg.Range), n > 0 and "ok" or "warn")
	if n == 0 then log("ไม่พบปุ่ม — เพิ่มระยะค้นหา หรือไปยืนใกล้จุดที่มีปุ่มก่อน", "warn") end
end)

print(("[GardenProX] v%s พร้อม • universal client helper"):format(VERSION))
