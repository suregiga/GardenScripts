--!nocheck
--[[ ============================================================
     GardenPro X  (v2.4)  •  สคริปต์ฟาร์มครบวงจรสำหรับ Garden Game
     v2.4: เพิ่มโหมดตรวจแมพ / แก้ crash VirtualUser.Idled + HUD พอดีทุกจอ (auto-fit + สไลเดอร์ขนาด UI)
     place 6348373477  •  ปรับแต่งสำหรับ Delta / มือถือ
     ------------------------------------------------------------
     โครงสร้าง:
       World   : สแกนโลกแบบแคช (เร็ว/ไม่กระตุก) + แปลงชื่อเป็นหมวด
       Engine  : คิวงานเดี่ยว จัดลำดับความสำคัญ (ไม่แย่งกันเดิน)
       Utility : งานเบื้องหลัง (ขาย/เควส/คราฟ/รับรางวัล) ทำงานทุก ~2 วิ
       Stats   : อ่านเงิน/นับของที่เก็บได้/เวลาเล่น
       Profile : เซฟค่า+จุดวาร์ป ตาม PlaceId
     ปุ่ม: RightShift ซ่อน HUD • RightCtrl ปิดสคริปต์ • ปุ่ม GP ลากได้
     เริ่มใช้: แท็บ หลัก → กด "ตรวจแมพ" → ส่งรายงานมาเพื่อจูนคำค้นหาให้ตรงเกม
     ============================================================ ]]

if _G.GardenProX and _G.GardenProX.Destroy then pcall(_G.GardenProX.Destroy) end

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local VirtualUser       = game:GetService("VirtualUser")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService       = game:GetService("HttpService")
local Workspace         = game:GetService("Workspace")
local Lighting          = game:GetService("Lighting")

local LP = Players.LocalPlayer
local P = {
	State = {}, Conns = {}, Actions = {}, Utility = {}, Pages = {}, Nav = {}, Waypoints = {},
	Route = { list = {}, play = false }, Stats = { items = 0, sells = 0, quests = 0, coins = 0, kills = 0, start = tick() },
	Cfg = {}, LastWarn = {},
}
_G.GardenProX = P

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

--------------------------------------------------------------------------------
-- ค่าตั้งต้น
--------------------------------------------------------------------------------
local Cfg = {
	Speed = 55, Jump = 120, FlySpeed = 90, Reach = 8,
	ScanRange = 2600, Delay = 0.05, Jitter = 0.25,
	SellAt = 40, SkipRare = true, Humanize = true, Turbo = false, UIScale = 1,
	RadarOn = true, RadarCount = 6, FpsGuard = true,
	ESP = { ore = true, tree = true, egg = true, animal = false, monster = true, crop = true, loot = true },
	UseTouch = true,       -- ใช้การแตะ (firetouchinterest) ช่วยตอนปลูก/เก็บ
	Filter = {
		enabled = false, strict = false,
		tiers = { common = true, uncommon = true, rare = true, epic = true, legendary = true, mythic = true, divine = true },
		minLevel = 0, maxLevel = 999,
		use = { crop = true, ore = true, tree = true, monster = true, loot = true, egg = true, animal = false },
		seedHighFirst = true, seedMin = 1, keepSelected = false,
	},
}
P.Cfg = Cfg

--------------------------------------------------------------------------------
-- หมวดคำค้นหา
--------------------------------------------------------------------------------
local KIND = {
	plant   = { "plot", "dirt", "soil", "farm", "garden", "planter", "patch" },
	seed    = { "seed" },
	crop    = { "crop", "fruit", "ready", "grown", "harvest", "ripe", "veg", "berry", "produce" },
	ore     = { "ore", "rock", "stone", "crystal", "deepslate", "node", "vein", "gem", "mineral", "coal" },
	tree    = { "tree", "log", "wood", "trunk", "stump", "bark", "oak", "pine" },
	fish    = { "fish", "fishspot", "sea", "lake", "pond", "water", "school" },
	egg     = { "egg", "nest" },
	animal  = { "animal", "pet", "chicken", "cow", "sheep", "pig", "breed", "cage", "coop", "pen" },
	monster = { "monster", "slime", "enemy", "zombie", "goblin", "boss", "bat", "wolf", "cave" },
	sell    = { "sell", "market", "steven", "trader", "vendor" },
	shop    = { "seedshop", "shop", "store", "buy", "merchant", "sam" },
	quest   = { "quest", "daily", "mission", "task", "objective" },
	loot    = { "drop", "loot", "coin", "cash", "orb", "chest", "bag", "reward", "token" },
	food    = { "food", "apple", "bread", "eat", "heal", "potion", "berry" },
	toolPick= { "pickaxe", "pick" },
	toolAxe = { "axe", "hatchet" },
	toolRod = { "rod" },
	toolCan = { "can", "watering" },
	toolWep = { "sword", "blade", "spear", "bow", "club", "dagger", "staff" },
	claim   = { "claim", "collect", "reward", "gift", "spin", "daily", "รับ", "เก็บ", "รางวัล" },
	craft   = { "craft", "upgrade", "enchant", "forge", "combine" },
}
local OBJECT_KINDS = { "plant", "crop", "ore", "tree", "fish", "egg", "animal", "monster", "sell", "shop", "loot", "quest" }

-- ระดับ (tier) ที่เกมแนวนี้ใช้
local TIERS = { "common", "uncommon", "rare", "epic", "legendary", "mythic", "divine" }
local TIER_TH = { common = "ธรรมดา", uncommon = "ไม่ธรรมดา", rare = "หายาก", epic = "มหากาพย์",
	legendary = "ตำนาน", mythic = "เทพนิยาย", divine = "สวรรค์" }
local TIER_COL = { common = Color3.fromRGB(150, 158, 150), uncommon = Color3.fromRGB(96, 200, 116),
	rare = Color3.fromRGB(96, 156, 226), epic = Color3.fromRGB(168, 116, 226),
	legendary = Color3.fromRGB(240, 176, 74), mythic = Color3.fromRGB(226, 96, 96),
	divine = Color3.fromRGB(96, 220, 220) }
local TIER_SCORE = { common = 1, uncommon = 2, rare = 3, epic = 4, legendary = 5, mythic = 6, divine = 7 }
local TIER_ALIAS = { { "legend", "legendary" }, { "myth", "mythic" }, { "divin", "divine" }, { "unco", "uncommon" } }
local ATTR_NAMES = { "Rarity", "Tier", "RarityName", "TierName", "Quality", "Grade", "Level", "Lvl" }

--------------------------------------------------------------------------------
-- helper
--------------------------------------------------------------------------------
local function cd(class, props, kids)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do if k ~= "Parent" then o[k] = v end end
	for _, k in ipairs(kids or {}) do k.Parent = o end
	if props and props.Parent then o.Parent = props.Parent end
	return o
end
local function corner(o, r) cd("UICorner", { CornerRadius = UDim.new(0, r or 8), Parent = o }) end
local function pad(o, n) cd("UIPadding", { PaddingLeft = UDim.new(0, n), PaddingRight = UDim.new(0, n),
	PaddingTop = UDim.new(0, n), PaddingBottom = UDim.new(0, n), Parent = o }) end
local function tween(o, t, props)
	TweenService:Create(o, TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end
local function conn(sig, fn)
	if not sig then return nil end
	local ok, c = pcall(function() return sig:Connect(fn) end)
	if ok and c then table.insert(P.Conns, c); return c end
	if not ok then print("[GardenProX] เชื่อม event ไม่ได้: " .. tostring(c)) end
	return nil
end
local function hit(txt, words)
	if not txt then return false end
	txt = txt:lower()
	for _, w in ipairs(words or {}) do if txt:find(w, 1, true) then return true end end
	return false
end

local C = {
	bg = Color3.fromRGB(15, 18, 16), card = Color3.fromRGB(27, 32, 28), card2 = Color3.fromRGB(36, 43, 38),
	stroke = Color3.fromRGB(54, 65, 57), text = Color3.fromRGB(236, 243, 237), dim = Color3.fromRGB(146, 160, 148),
	accent = Color3.fromRGB(96, 200, 116), ok = Color3.fromRGB(50, 205, 120), off = Color3.fromRGB(52, 60, 54),
	warn = Color3.fromRGB(240, 186, 74), bad = Color3.fromRGB(226, 96, 96), blue = Color3.fromRGB(96, 156, 226),
}

local function char() return LP.Character end
local function hum() local c = char() return c and c:FindFirstChildOfClass("Humanoid") or nil end
local function hrp() local c = char() return c and c:FindFirstChild("HumanoidRootPart") or nil end
local function alive() local h = hum() return (h and h.Health > 0) or false end
local function dist(a, b) return (a - b).Magnitude end
local function pause(base) return math.max(0, base * (1 + (math.random() * 2 - 1) * (Cfg.Humanize and Cfg.Jitter or 0))) end

local function log(msg, kind)
	if not P.Console then return end
	local col = (kind == "warn" and C.warn) or (kind == "ok" and C.ok) or (kind == "err" and C.bad) or C.dim
	local l = cd("TextLabel", { Size = UDim2.new(1, -20, 0, 15), BackgroundTransparency = 1,
		Font = Enum.Font.Code, TextSize = 11, TextColor3 = col,
		TextXAlignment = Enum.TextXAlignment.Left, Text = ("› %s"):format(msg), Parent = P.Console })
	task.delay(40, function() if l and l.Parent then l:Destroy() end end)
	local kids = P.Console:GetChildren()
	if #kids > 30 then for i = 1, #kids - 30 do if kids[i] then kids[i]:Destroy() end end end
end
local function warnOnce(key, msg)
	if P.LastWarn[key] and tick() - P.LastWarn[key] < 25 then return end
	P.LastWarn[key] = tick()
	log(msg, "warn")
end
local function toast(text, kind)
	if not P.Toasts then return end
	local col = (kind == "ok" and C.ok) or (kind == "err" and C.bad) or C.accent
	local b = cd("Frame", { Size = UDim2.fromOffset(300, 36), BackgroundColor3 = C.card2,
		BackgroundTransparency = 1, BorderSizePixel = 0, Parent = P.Toasts }, {
		cd("Frame", { Size = UDim2.fromOffset(4, 18), Position = UDim2.fromOffset(0, 9),
			BackgroundColor3 = col, BorderSizePixel = 0 }),
		cd("TextLabel", { Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(10, 0),
			BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12,
			TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left, Text = text }),
	})
	corner(b, 8)
	tween(b, 0.16, { BackgroundTransparency = 0 })
	task.delay(2.6, function()
		tween(b, 0.2, { BackgroundTransparency = 1 })
		task.delay(0.25, function() if b then b:Destroy() end end)
	end)
end

--------------------------------------------------------------------------------
-- World : แคชโลก + แปลงชื่อเป็นหมวด (คำนวณครั้งเดียวต่อชิ้น)
--------------------------------------------------------------------------------
local W = { list = {}, idx = {}, t = 0, prompts = {}, pt = 0 }
local kindCache = setmetatable({}, { __mode = "k" })
local function bucket(kind)
	local b = W.idx[kind]
	if not b then b = {}; W.idx[kind] = b end
	return b
end

local function pathOf(part)
	local t, node = {}, part
	for _ = 1, 4 do
		node = node and node.Parent
		if not node or node == Workspace then break end
		table.insert(t, node.Name:lower())
	end
	return table.concat(t, "/")
end

local function attrText(inst)
	for _, n in ipairs(ATTR_NAMES) do
		local v = inst:GetAttribute(n)
		if type(v) == "string" and #v > 1 then return v:lower() end
	end
	return nil
end

local function kindsOf(part)
	local c = kindCache[part]
	if c then return c end
	local name = part.Name:lower()
	local path = pathOf(part)
	c = { own = path:find(LP.Name:lower(), 1, true) ~= nil }
	for _, kind in ipairs(OBJECT_KINDS) do
		if hit(name, KIND[kind]) or (kind ~= "plant" and hit(path, KIND[kind])) then c[kind] = true end
	end
	-- ตัวกรองระดับ: หา tier/level จากชื่อ / ชื่อโฟลเดอร์ / attribute ที่เกมตั้งไว้
	local txt = name .. " " .. path
	local at = attrText(part)
	if not at and part.Parent then at = attrText(part.Parent) end
	if at then txt = txt .. " " .. at end
	local tier
	for _, t in ipairs(TIERS) do
		if txt:find(t, 1, true) then tier = t end
	end
	if not tier then
		for _, m in ipairs(TIER_ALIAS) do
			if txt:find(m[1], 1, true) then tier = m[2] break end
		end
	end
	c.tier = tier
	c.score = tier and TIER_SCORE[tier] or 0
	local lv = tonumber(part:GetAttribute("Level")) or tonumber(part:GetAttribute("Lvl"))
	if not lv and part.Parent then
		lv = tonumber(part.Parent:GetAttribute("Level")) or tonumber(part.Parent:GetAttribute("Lvl"))
	end
	if not lv then
		lv = tonumber(name:match("lv%.?%s*(%d+)")) or tonumber(name:match("lvl%s*(%d+)"))
			or tonumber(name:match("level%s*(%d+)"))
	end
	c.lvl = lv
	kindCache[part] = c
	return c
end

local function tierOf(part) return kindsOf(part).tier end
local function levelOf(part) return kindsOf(part).lvl end
local function scoreOf(part) return kindsOf(part).score or 0 end

-- ตัวกรอง: ผ่านหรือไม่ (ใช้กับ nearest/collect ทุกที่)
local function passesFilter(kind, part)
	local F = Cfg.Filter
	if not F.enabled then return true end
	if not F.use[kind] then return true end
	local info = kindsOf(part)
	if info.tier then
		if not F.tiers[info.tier] then return false end
	elseif F.strict then
		return false
	end
	local lv = info.lvl
	if lv then
		if lv < F.minLevel or lv > F.maxLevel then return false end
	elseif F.strict then
		return false
	end
	return true
end

-- เก็บเฉพาะ BasePart ที่ถูกเพิ่มเข้ามา (ไม่ต้อง GetDescendants ทั้งเกมทุกครั้ง)
local tracked = setmetatable({}, { __mode = "k" })
local function track(d)
	if d:IsA("BasePart") then tracked[d] = true end
end
local function untrack(d)
	if tracked[d] then tracked[d] = nil end
end

local function refreshWorld()
	local list, idx = {}, {}
	local my, ch = hrp(), char()
	local origin = my and my.Position or Vector3.zero
	local range = Cfg.ScanRange
	for part in pairs(tracked) do
		if part.Parent then
			if part.Transparency >= 1 or (ch and part:IsDescendantOf(ch)) then
				-- ข้ามของล่องหน/ของที่ตัวเราใส่อยู่
			else
				local dd = (part.Position - origin).Magnitude
				if dd <= range then
					local e = { p = part, d = dd }
					list[#list + 1] = e
					local info = kindsOf(part)
					for _, kind in ipairs(OBJECT_KINDS) do
						if info[kind] then
							local b = idx[kind]
							if not b then b = {}; idx[kind] = b end
							b[#b + 1] = e
						end
					end
				end
			end
		else
			tracked[part] = nil
		end
	end
	for _, b in pairs(idx) do table.sort(b, function(x, y) return x.d < y.d end) end
	W.list, W.idx = list, idx
	W.t = os.clock()
end

local function world()
	if os.clock() - W.t > 1.6 then refreshWorld() end
	return W.list
end

local function nearest(kind, ownOnly, maxD)
	local my = hrp(); if not my then return nil end
	if os.clock() - W.t > 1.6 then refreshWorld() end
	local b = W.idx[kind]
	if not b then return nil end
	local limit = maxD or Cfg.ScanRange
	for _, e in ipairs(b) do
		local p = e.p
		if p.Parent then
			local k = kindsOf(p)
			if (not ownOnly or k.own) and passesFilter(kind, p) then
				local dd = dist(p.Position, my.Position)
				if dd < limit then return p, dd end
			end
		end
	end
	return nil
end

local function collect(kind, ownOnly, maxD, limit)
	local my = hrp(); if not my then return {} end
	if os.clock() - W.t > 1.6 then refreshWorld() end
	local b = W.idx[kind]
	if not b then return {} end
	local out, max = {}, maxD or Cfg.ScanRange
	for _, e in ipairs(b) do
		local p = e.p
		if p.Parent then
			local k = kindsOf(p)
			if (not ownOnly or k.own) and passesFilter(kind, p) then
				local dd = dist(p.Position, my.Position)
				if dd < max then
					out[#out + 1] = { p = p, d = dd }
					if limit and #out >= limit then break end
				end
			end
		end
	end
	return out
end

local function promptsRefresh()
	local list = {}
	for part in pairs(tracked) do
		if part.Parent then
			local pr = part:FindFirstChildOfClass("ProximityPrompt")
			if pr and pr.Enabled then
				local nm = (part.Name .. " " .. (part.Parent and part.Parent.Name or "")):lower()
				list[#list + 1] = { prompt = pr, part = part, name = nm }
			end
		end
	end
	W.prompts = list
	W.pt = os.clock()
end
local function prompts()
	if os.clock() - W.pt > 2.5 then promptsRefresh() end
	return W.prompts
end
local function promptBy(kind, maxD)
	local my = hrp(); if not my then return nil, nil end
	local best, bd = nil, maxD or 300
	for _, e in ipairs(prompts()) do
		if hit(e.name, KIND[kind]) then
			local dd = dist(e.part.Position, my.Position)
			if dd < bd then best, bd = e, dd end
		end
	end
	return best, bd
end
local function firePrompt(e)
	if not e then return false end
	if fireproximityprompt then pcall(fireproximityprompt, e.prompt)
	else
		pcall(function()
			e.prompt:InputHoldBegin()
			task.wait(math.max(e.prompt.HoldDuration, 0) + 0.05)
			e.prompt:InputHoldEnd()
		end)
	end
	return true
end

--------------------------------------------------------------------------------
-- Remotes
--------------------------------------------------------------------------------
local remotes = {}
local function classifyRemote(name)
	local out, n = {}, name:lower()
	for kind, words in pairs(KIND) do
		for _, w in ipairs(words) do
			if n:find(w, 1, true) then out[kind] = (out[kind] or 0) + 1 break end
		end
	end
	return out
end
local function scanRemotes()
	remotes = {}
	local roots = { ReplicatedStorage, Workspace }
	local ps = LP:FindFirstChild("PlayerScripts"); if ps then table.insert(roots, ps) end
	for _, root in ipairs(roots) do
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("UnreliableRemoteEvent") then
				table.insert(remotes, { obj = d, name = d.Name, path = d:GetFullName(), score = classifyRemote(d.Name) })
			end
		end
	end
	if P.refreshRemoteList then pcall(P.refreshRemoteList) end
	log(("สแกนรีโมท: %d"):format(#remotes), "ok")
	return #remotes
end
local function bestRemote(kind)
	local best, score = nil, 0
	for _, r in ipairs(remotes) do
		local s = r.score[kind] or 0
		if s > score then best, score = r, s end
	end
	return best, score
end
local function fire(kind, ...)
	local r = bestRemote(kind)
	if not r or not r.obj.Parent then return false end
	local a = table.pack(...)
	pcall(function() r.obj:FireServer(table.unpack(a, 1, a.n)) end)
	return true
end

--------------------------------------------------------------------------------
-- การเคลื่อนที่ / ไอเทม / การคลิก
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
		-- เบี่ยงเล็กน้อยกันติดมุม
		local off = Vector3.new(math.random(-6, 6), 0, math.random(-6, 6))
		h:MoveTo(pos + off)
	else
		h:MoveTo(pos)
	end
	return false
end

local function toolBy(kind)
	local c = char(); if not c then return nil end
	for _, box in ipairs({ c, LP:FindFirstChild("Backpack") }) do
		if box then
			for _, t in ipairs(box:GetChildren()) do
				if t:IsA("Tool") and hit(t.Name, KIND[kind]) then return t end
			end
		end
	end
	return nil
end
local function equip(kind)
	local h = hum(); if not h then return nil end
	local t = toolBy(kind)
	if not t then warnOnce("tool" .. kind, "ไม่พบไอเทมกลุ่ม " .. kind .. " ในกระเป๋า") return nil end
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
local function clickCenter()
	local cam = Workspace.CurrentCamera
	local v = cam and cam.ViewportSize / 2 or Vector2.new(0, 0)
	if mouse1click then if pcall(mouse1click) then return end end
	pcall(function()
		VirtualUser:CaptureController()
		VirtualUser:Button1Down(v, cam and cam.CFrame or CFrame.new())
		task.wait(0.05)
		VirtualUser:Button1Up(v, cam and cam.CFrame or CFrame.new())
	end)
end
local function aim(pos)
	local cam = Workspace.CurrentCamera
	if cam then pcall(function() cam.CFrame = CFrame.lookAt(cam.CFrame.Position, pos) end) end
end

-- กดคลิกที่ "ตำแหน่งของวัตถุบนจอ" (แม่นกว่ากดกลางจอ)
local function clickWorld(pos)
	local cam = Workspace.CurrentCamera
	if not cam then return end
	local sp, onScreen = cam:WorldToViewportPoint(pos)
	if onScreen and sp.Z > 0 then
		if mouse1move then pcall(mouse1move, sp.X, sp.Y) end
		if mouse1click then
			if pcall(mouse1click) then return end
		end
		pcall(function()
			VirtualUser:CaptureController()
			VirtualUser:Button1Down(Vector2.new(sp.X, sp.Y), cam.CFrame)
			task.wait(0.04)
			VirtualUser:Button1Up(Vector2.new(sp.X, sp.Y), cam.CFrame)
		end)
	else
		clickCenter()
	end
end

-- จำลองการแตะวัตถุ (เกมที่ใช้ Touched จะรับรู้)
local function touchPart(part)
	if not Cfg.UseTouch or not part then return end
	if not firetouchinterest then return end
	local my = hrp()
	if not my then return end
	pcall(function()
		firetouchinterest(my, part, 0)
		task.wait(0.03)
		firetouchinterest(my, part, 1)
	end)
end

-- ใช้ไอเทม + คลิกที่วัตถุ + แตะ
local function useOn(part, times)
	aim(part.Position)
	useTool(times or 1, 0.08)
	clickWorld(part.Position)
	touchPart(part)
end

--------------------------------------------------------------------------------
-- GUI helper (สร้าง UI)
--------------------------------------------------------------------------------
local function guiParent()
	-- ใช้ PlayerGui เป็นหลัก (กดได้แน่) • gethui เป็นตัวเลือก
	if _G.GPX_USE_GETHUI then
		local ok, h = pcall(function() return gethui() end)
		if ok and h then return h end
	end
	return LP:WaitForChild("PlayerGui")
end

local gui = cd("ScreenGui", { Name = "GardenProX", ResetOnSpawn = false, IgnoreGuiInset = false,
	Enabled = true, DisplayOrder = 9999, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = guiParent() })
P.Toasts = cd("Frame", { Size = UDim2.fromOffset(320, 300), Position = UDim2.fromOffset(0, 100),
	BackgroundTransparency = 1, Active = false, ZIndex = 100, Parent = gui }, { cd("UIListLayout", { Padding = UDim.new(0, 6) }) })

local root, reopen
local shown = true
local function setShown(v)
	shown = v
	root.Visible = v
	reopen.Visible = not v
	if v then pcall(function() if P.Fit then P.Fit() end end) end
end

reopen = cd("TextButton", { Size = UDim2.fromOffset(58, 58), Position = UDim2.fromOffset(14, 96),
	Visible = false, BackgroundColor3 = C.accent, BorderSizePixel = 0, Font = Enum.Font.GothamBlack,
	TextSize = 17, TextColor3 = Color3.fromRGB(15, 22, 16), Text = "GP", ZIndex = 120, Parent = gui })
corner(reopen, 29)
local rdrag, rfrom, rstart
reopen.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
		rdrag, rfrom, rstart = true, i.Position, reopen.Position
	end
end)
reopen.InputEnded:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
		rdrag = false
		if rfrom and (i.Position - rfrom).Magnitude < 8 then setShown(true) end
	end
end)
conn(UserInputService.InputChanged, function(i)
	if rdrag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
		local d = i.Position - rfrom
		reopen.Position = UDim2.new(rstart.X.Scale, rstart.X.Offset + d.X, rstart.Y.Scale, rstart.Y.Offset + d.Y)
	end
end)

root = cd("Frame", { Size = UDim2.fromOffset(620, 486), AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.42), BackgroundColor3 = C.bg, Active = true, ZIndex = 50,
	BorderSizePixel = 0, ClipsDescendants = true, Parent = gui })
corner(root, 14)
cd("UIStroke", { Color = C.stroke, Thickness = 1, Parent = root })

--------------------------------------------------------------------------------
-- ปรับขนาด HUD ให้พอดีทุกจอ (auto-fit ตาม viewport จริง)
--------------------------------------------------------------------------------
local DESIGN = Vector2.new(620, 486)
local scale = cd("UIScale", { Name = "HudScale", Parent = root })

local function viewportSize()
	local ok, s = pcall(function() return gui.AbsoluteSize end)
	if ok and s and s.X and s.X > 0 and s.Y and s.Y > 0 then return s end
	local cv = Workspace.CurrentCamera
	if cv and cv.ViewportSize.X > 0 and cv.ViewportSize.Y > 0 then return cv.ViewportSize end
	return Vector2.new(1280, 720)
end

local function fit()
	local vp = viewportSize()
	-- เว้นขอบ 20px กันชนขอบจอ/ติ่งมือถือ แล้วคูณขนาดที่ผู้ใช้ตั้งไว้
	local base = math.min((vp.X - 20) / DESIGN.X, (vp.Y - 20) / DESIGN.Y)
	local mul = tonumber(Cfg.UIScale) or 1
	if mul <= 0 then mul = 1 end
	scale.Scale = math.clamp(math.clamp(base, 0.30, 1.25) * mul, 0.24, 1.6)
	root.Size = UDim2.fromOffset(DESIGN.X, DESIGN.Y)
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
end
P.Fit = fit
pcall(fit)
conn(gui:GetPropertyChangedSignal("AbsoluteSize"), function() task.wait(0.15); pcall(fit) end)
local camFit = Workspace.CurrentCamera
if camFit then conn(camFit:GetPropertyChangedSignal("ViewportSize"), function() task.wait(0.15); pcall(fit) end) end

local bar = cd("Frame", { Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = C.card,
	BorderSizePixel = 0, Parent = root })
cd("Frame", { Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 1, -2),
	BackgroundColor3 = C.accent, BorderSizePixel = 0, Parent = bar })
cd("TextLabel", { Size = UDim2.fromOffset(232, 20), Position = UDim2.fromOffset(16, 8),
	BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 15, TextColor3 = C.text,
	TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
	Text = "GARDEN PRO X • v2.4", Parent = bar })
local subBar = cd("TextLabel", { Size = UDim2.fromOffset(232, 14), Position = UDim2.fromOffset(16, 30),
	BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 10.5, TextColor3 = C.dim,
	TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = bar,
	Text = isMobile and "แตะ GP ซ่อน/เปิด • ลากแถบนี้เพื่อย้าย" or "RightShift ซ่อน HUD" })

-- สถิติบนหัว
local function chip(x, w, label)
	local f = cd("Frame", { Size = UDim2.fromOffset(w, 34), Position = UDim2.new(0, x, 0, 11),
		BackgroundColor3 = C.card2, BorderSizePixel = 0, Parent = bar })
	corner(f, 8)
	local l = cd("TextLabel", { Size = UDim2.new(1, -10, 0, 14), Position = UDim2.fromOffset(8, 3),
		BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 9, TextColor3 = C.dim,
		TextXAlignment = Enum.TextXAlignment.Left, Text = label:upper() })
	local v = cd("TextLabel", { Size = UDim2.new(1, -10, 0, 16), Position = UDim2.fromOffset(8, 15),
		BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = C.accent,
		TextXAlignment = Enum.TextXAlignment.Left, Text = "--" })
	return l, v
end
local moneyLbl = select(2, chip(256, 84, "เงิน"))
local itemLbl = select(2, chip(344, 78, "เก็บได้"))
local fpsLbl = select(2, chip(426, 92, "FPS/PING"))

local function barBtn(txt, x, col)
	local b = cd("TextButton", { Size = UDim2.fromOffset(26, 26), Position = UDim2.new(0, x, 0, 15),
		BackgroundColor3 = col, BorderSizePixel = 0, Font = Enum.Font.GothamBold, TextSize = 13,
		TextColor3 = C.text, Text = txt, ZIndex = 5, Parent = bar })
	corner(b, 7)
	return b
end
local minBtn = barBtn("—", 440, C.card2)
local closeBtn = barBtn("✕", 470, C.bad)
minBtn.Position = UDim2.new(1, -92, 0, 15)
closeBtn.Position = UDim2.new(1, -30, 0, 15)
local fixBtn = barBtn("⟳", 0, C.blue)
fixBtn.Position = UDim2.new(1, -61, 0, 15)

local rail = cd("Frame", { Size = UDim2.fromOffset(160, 400), Position = UDim2.fromOffset(0, 56),
	BackgroundColor3 = C.card, BorderSizePixel = 0, Parent = root }, { cd("UIListLayout", { Padding = UDim.new(0, 4) }) })
pad(rail, 7)

local body = cd("Frame", { Size = UDim2.new(1, -160, 1, -92), Position = UDim2.fromOffset(160, 56),
	BackgroundTransparency = 1, Parent = root })

local console = cd("Frame", { Size = UDim2.new(1, -160, 0, 34), Position = UDim2.new(0, 160, 1, -36),
	BackgroundColor3 = C.card, BorderSizePixel = 0, Parent = root })
P.Console = console

local function page(name)
	local f = cd("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
		BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3, ScrollBarImageColor3 = C.stroke, Visible = false, Parent = body },
		{ cd("UIListLayout", { Padding = UDim.new(0, 6) }) })
	pad(f, 10)
	P.Pages[name] = f
	return f
end
local function switchTab(name, btn)
	for n, f in pairs(P.Pages) do f.Visible = (n == name) end
	for n, b in pairs(P.Nav) do b.BackgroundColor3 = (n == name) and C.accent or C.card2 end
	if btn then btn.BackgroundColor3 = C.accent end
end

-- ซ่อม HUD: คืนขนาด/ตำแหน่งให้พอดีจอ แล้วเปิดแท็บหลัก (เรียกได้ทุกเมื่อ)
function P.RepairUI()
	pcall(fit)
	if root then
		root.Visible = true
		root.AnchorPoint = Vector2.new(0.5, 0.5)
		root.Position = UDim2.fromScale(0.5, 0.5)
	end
	pcall(function() setShown(true) end)
	pcall(function() switchTab("หลัก", P.Nav["หลัก"]) end)
end
function uiScaleSafe() P.RepairUI() end
local function navBtn(name, icon)
	local b = cd("TextButton", { Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = C.card2,
		BorderSizePixel = 0, Font = Enum.Font.GothamBold, TextSize = 12.5, TextColor3 = C.text,
		TextXAlignment = Enum.TextXAlignment.Left, Text = "  " .. icon .. "  " .. name, Parent = rail })
	corner(b, 8)
	P.Nav[name] = b
	b.MouseButton1Click:Connect(function() switchTab(name, b) end)
	return b
end

local function head(parent, txt)
	cd("TextLabel", { Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold, TextSize = 10.5, TextColor3 = C.dim,
		TextXAlignment = Enum.TextXAlignment.Left, Text = txt:upper(), Parent = parent })
end
local function note(parent, txt)
	local f = cd("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.card, BorderSizePixel = 0, Parent = parent })
	corner(f, 8)
	pad(f, 9)
	cd("TextLabel", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 10.5, TextColor3 = C.dim,
		TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Text = txt, Parent = f })
	return f
end
local function row(parent, label, h)
	local r = cd("Frame", { Size = UDim2.new(1, 0, 0, h or 34), BackgroundColor3 = C.card2,
		BorderSizePixel = 0, Parent = parent })
	corner(r, 8)
	cd("TextLabel", { Size = UDim2.new(1, -70, 1, 0), Position = UDim2.fromOffset(11, 0),
		BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12.5, TextColor3 = C.text,
		TextXAlignment = Enum.TextXAlignment.Left, Text = label, Parent = r })
	return r
end
local function toggle(parent, label, flag, onOn, onOff)
	local r = row(parent, label)
	local track = cd("Frame", { Size = UDim2.fromOffset(40, 22), Position = UDim2.new(1, -51, 0.5, -11),
		BackgroundColor3 = C.off, BorderSizePixel = 0, Parent = r })
	corner(track, 11)
	local knob = cd("Frame", { Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(3, 3),
		BackgroundColor3 = C.text, BorderSizePixel = 0, Parent = track })
	corner(knob, 8)
	local click = cd("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Parent = r })
	local function render(on)
		tween(track, 0.14, { BackgroundColor3 = on and C.ok or C.off })
		tween(knob, 0.14, { Position = on and UDim2.fromOffset(21, 3) or UDim2.fromOffset(3, 3) })
	end
	local function set(v)
		P.State[flag] = v
		render(v)
		if v then if onOn then pcall(onOn) end else if onOff then pcall(onOff) end end
		if onOn or onOff then pcall(saveProfileSoon) end
	end
	click.MouseButton1Click:Connect(function() set(not P.State[flag]) end)
	P.Setters = P.Setters or {}
	P.Setters[flag] = set
	return set
end
local function slider(parent, label, minV, maxV, cur, fmt, onChange)
	local wrap = cd("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = C.card2,
		BorderSizePixel = 0, Parent = parent })
	corner(wrap, 8)
	local l = cd("TextLabel", { Size = UDim2.new(1, -20, 0, 15), Position = UDim2.fromOffset(11, 5),
		BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 11.5, TextColor3 = C.text,
		TextXAlignment = Enum.TextXAlignment.Left, Text = label, Parent = wrap })
	local track = cd("Frame", { Size = UDim2.new(1, -24, 0, 5), Position = UDim2.new(0, 12, 0, 32),
		BackgroundColor3 = C.off, BorderSizePixel = 0, Parent = wrap })
	corner(track, 3)
	local fill = cd("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.accent,
		BorderSizePixel = 0, Parent = track })
	corner(fill, 3)
	local knob = cd("Frame", { Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0), BackgroundColor3 = C.text, BorderSizePixel = 0, Parent = track })
	corner(knob, 6)
	local hitBox = cd("TextButton", { Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 18),
		BackgroundTransparency = 1, Text = "", Parent = wrap })
	local value = cur
	local function render()
		local a = math.clamp((value - minV) / (maxV - minV), 0, 1)
		fill.Size = UDim2.fromScale(a, 1)
		knob.Position = UDim2.new(a, 0, 0.5, 0)
		l.Text = ("%s • %s"):format(label, fmt:format(value))
	end
	local function apply(v)
		value = math.floor(v + 0.5); render()
		if onChange then pcall(onChange, value) end
		pcall(saveProfileSoon)
	end
	local function calc(px)
		apply(minV + math.clamp((px - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1) * (maxV - minV))
	end
	local dragging = false
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
local function button(parent, label, cb, col, h)
	local b = cd("TextButton", { Size = UDim2.new(1, 0, 0, h or 32), BackgroundColor3 = col or C.card2,
		BorderSizePixel = 0, AutoButtonColor = false, Font = Enum.Font.GothamBold, TextSize = 12.5,
		TextColor3 = C.text, Text = label, Parent = parent })
	corner(b, 8)
	b.MouseButton1Click:Connect(function() pcall(cb) end)
	return b
end

--------------------------------------------------------------------------------
-- Engine : คิวงานเดี่ยว (ไม่แย่งกันเดิน)
--------------------------------------------------------------------------------
local function registerAction(flag, prio, step, name)
	P.Actions[flag] = { prio = prio, step = step, name = name or flag }
end
local function registerUtil(flag, every, step, name)
	P.Utility[flag] = { every = every, step = step, next = 0, name = name or flag }
end

local function engineLoop()
	while true do
		if P.Destroyed then break end
		local best, bestPrio = nil, -1
		for flag, a in pairs(P.Actions) do
			if P.State[flag] and a.prio > bestPrio then best, bestPrio = a, a.prio end
		end
		if best then
			local ok, err = pcall(best.step)
			if not ok and err then
				warnOnce("act" .. best.name, ("งาน %s ผิดพลาด: %s"):format(best.name, tostring(err):sub(1, 60)))
			end
		elseif P.Route.play then
			pcall(function()
				local pts = P.Route.list
				if #pts == 0 then return end
				P.Route.i = (P.Route.i or 1)
				local target = pts[P.Route.i]
				if not target then P.Route.i = 1; return end
				if walkTo(target, 4) then P.Route.i = P.Route.i % #pts + 1 end
			end)
		else
			task.wait(0.15)
		end
		if Cfg.Turbo then task.wait() else task.wait(pause(Cfg.Delay)) end
	end
end

local function utilLoop()
	while true do
		if P.Destroyed then break end
		for flag, u in pairs(P.Utility) do
			if P.State[flag] and os.clock() >= u.next then
				u.next = os.clock() + u.every
				local ok, err = pcall(u.step)
				if not ok and err then
					warnOnce("util" .. flag, ("งาน %s ผิดพลาด: %s"):format(flag, tostring(err):sub(1, 60)))
				end
			end
		end
		task.wait(0.5)
	end
end

--------------------------------------------------------------------------------
-- งาน: ฟาร์ม
--------------------------------------------------------------------------------
local function nameOwned(name)
	local n = name:lower()
	return n:find(LP.Name:lower(), 1, true) ~= nil or n:find(tostring(LP.UserId), 1, true) ~= nil
end
local function attrOwner(inst)
	for _, key in ipairs({ "Owner", "Player", "PlayerName", "UserId", "OwnerId" }) do
		local v = inst:GetAttribute(key)
		if v ~= nil then
			local t = tostring(v):lower()
			if t == LP.Name:lower() or t == tostring(LP.UserId) then return true end
		end
	end
	return false
end
local function ownPlotOf(part)
	local node = part
	for _ = 1, 5 do
		if not node then break end
		if nameOwned(node.Name) or attrOwner(node) then return true end
		node = node.Parent
	end
	return false
end

-- หาแปลง: 1) ชื่อ/attribute บอกว่าเป็นของเรา  2) ถ้าไม่เจอ ใช้แปลงที่ใกล้ตัวสุด
local function plotsOf()
	local mine, any = {}, {}
	local my = hrp()
	for _, e in ipairs(world()) do
		local k = kindsOf(e.p)
		if k.plant then
			if k.own or ownPlotOf(e.p) then mine[#mine + 1] = e.p else any[#any + 1] = e.p end
		end
	end
	if #mine > 0 then return mine end
	if #any > 0 and my then
		table.sort(any, function(a, b)
			return (a.Position - my.Position).Magnitude < (b.Position - my.Position).Magnitude
		end)
		P.PlotFallback = true
		local out = {}
		for i = 1, math.min(#any, 8) do out[i] = any[i] end
		return out
	end
	return mine
end

-- หาพืชที่ใกล้แปลงของเราที่สุด (ไม่ต้องพึ่งชื่อโฟลเดอร์ผู้เล่น)
local function cropNearPlots()
	local my = hrp()
	if not my then return nil end
	local crops = W.idx.crop or {}
	local plots = plotsOf()
	local best, bd
	if #plots == 0 then
		for i = 1, math.min(#crops, 60) do
			local cp = crops[i].p
			local d = (cp.Position - my.Position).Magnitude
			if d < 40 and (not bd or d < bd) then best, bd = cp, d end
		end
		return best
	end
	for i = 1, math.min(#crops, 60) do
		local cp = crops[i].p
		for _, plot in ipairs(plots) do
			local d = (cp.Position - plot.Position).Magnitude
			if d < 30 and (not bd or d < bd) then best, bd = cp, d end
		end
	end
	return best
end
local function plotHasCrop(plot)
	for _, e in ipairs(world()) do
		local k = kindsOf(e.p)
		if k.crop and dist(e.p.Position, plot.Position) < 9 then return true end
	end
	return false
end

registerAction("Harvest", 92, function()
	local t = cropNearPlots() or nearest("crop", true)
	if not t then warnOnce("crop", "ไม่พบพืชให้เก็บ — กดปุ่ม 'ตรวจแมพ' ในแท็บหลัก") return end
	if walkTo(t.Position, Cfg.Reach) then
		useOn(t, 2)
		fire("crop", t)
		P.Stats.items += 1
	else
		aim(t.Position)
	end
end, "เก็บเกี่ยว")

local function seedTools()
	local out = {}
	local bp = LP:FindFirstChild("Backpack")
	if bp then
		for _, t in ipairs(bp:GetChildren()) do
			if t:IsA("Tool") and hit(t.Name, KIND.seed) then table.insert(out, t) end
		end
	end
	return out
end
local function bestSeed()
	local list, F = seedTools(), Cfg.Filter
	if #list == 0 then return nil end
	if not F.seedHighFirst then
		for _, t in ipairs(list) do if scoreOf(t) >= F.seedMin then return t end end
		return list[1]
	end
	local best, bscore = nil, -1
	for _, t in ipairs(list) do
		local s = scoreOf(t) * 1000 + (levelOf(t) or 0)
		if scoreOf(t) >= F.seedMin and s > bscore then best, bscore = t, s end
	end
	return best or list[1]
end

registerAction("Plant", 88, function()
	local seed = bestSeed()
	if not seed then warnOnce("seed", "ไม่พบเมล็ด — เปิด 'ซื้อเมล็ดอัตโนมัติ' ในแท็บเศรษฐกิจ หรือลด 'ระดับเมล็ดขั้นต่ำ'") return end
	local h = hum()
	for _, plot in ipairs(plotsOf()) do
		if not plotHasCrop(plot) then
			if walkTo(plot.Position, Cfg.Reach) then
				if seed.Parent ~= char() and h then pcall(function() h:EquipTool(seed) end) end
				useOn(plot, 1)
				fire("plant", plot, seed.Name)
			else
				aim(plot.Position)
			end
			return
		end
	end
end, "ปลูก")

registerAction("Water", 84, function()
	if not toolBy("toolCan") then warnOnce("can", "ไม่พบบัวรดน้ำ") return end
	local plot = plotsOf()[1]
	if not plot then return end
	if walkTo(plot.Position, Cfg.Reach) then
		equip("toolCan")
		useOn(plot, 1)
		fire("water", plot)
	end
end, "รดน้ำ")

--------------------------------------------------------------------------------
-- ตรวจแมพ (Diagnose) — บอกว่าเกมมีอะไร ชื่ออะไร เพื่อปรับให้ตรง
--------------------------------------------------------------------------------
function P.Diagnose()
	local lines = {}
	local function add(fmt, ...)
		local ok, txt = pcall(string.format, fmt, ...)
		lines[#lines + 1] = ok and txt or tostring(fmt)
	end
	add("=== GardenProX diagnose ===")
	add("place=%s player=%s", game.PlaceId, LP.Name)

	local nTracked, nWorld = 0, #W.list
	for _ in pairs(tracked) do nTracked += 1 end
	add("parts tracked=%d inRange=%d scanRange=%d", nTracked, nWorld, Cfg.ScanRange)

	-- แปลง
	local plots = plotsOf()
	add("plots=%d fallback=%s", #plots, tostring(P.PlotFallback or false))
	for i = 1, math.min(#plots, 6) do
		local pl = plots[i]
		add("  plot[%d] %s | %s", i, pl.Name, pl:GetFullName():sub(1, 70))
	end

	-- พืช
	local crops = W.idx.crop or {}
	add("crops=%d", #crops)
	for i = 1, math.min(#crops, 6) do
		local info = kindsOf(crops[i].p)
		add("  crop[%d] %s (tier=%s lv=%s d=%d)", i, crops[i].p.Name,
			tostring(info.tier), tostring(info.lvl), math.floor(crops[i].d))
	end

	-- ไอเท็มในกระเป๋า
	local bp = LP:FindFirstChild("Backpack")
	local tools = {}
	if bp then
		for _, t in ipairs(bp:GetChildren()) do
			if t:IsA("Tool") then tools[#tools + 1] = t.Name end
		end
	end
	add("tools=%d", #tools)
	for i = 1, math.min(#tools, 12) do add("  tool %s", tools[i]) end

	-- ProximityPrompt
	local prs = prompts()
	add("prompts=%d", #prs)
	for i = 1, math.min(#prs, 8) do
		local e = prs[i]
		add("  prompt %s | %s | action=%s obj=%s", e.part.Name,
			e.part:GetFullName():sub(1, 50), e.prompt.ActionText, e.prompt.ObjectText)
	end

	-- Remote ที่เข้าข่าย
	local hits = 0
	add("remotes")
	for _, r in ipairs(remotes) do
		if next(r.score) ~= nil and hits < 14 then
			hits += 1
			local kinds = {}
			for k in pairs(r.score) do kinds[#kinds + 1] = k end
			add("  %s -> %s (%s)", r.name, table.concat(kinds, ","), r.path:sub(1, 45))
		end
	end
	if hits == 0 then add("  (ไม่มีรีโมทที่เข้าข่าย — กด 'สแกนรีโมทใหม่')") end

	local text = table.concat(lines, "\n")
	print(text)
	if setclipboard then pcall(setclipboard, text) end
	for _, l in ipairs(lines) do log(l) end
	toast("คัดลอกรายงานตรวจแมพแล้ว — ส่งมาให้ดูได้", "ok")
	return text
end

--------------------------------------------------------------------------------
-- งาน: เก็บของ
--------------------------------------------------------------------------------
local function gatherAction(flag, targetKind, toolKind, prio, keepDist, label)
	registerAction(flag, prio, function()
		local t, d = nearest(targetKind)
		if not t then warnOnce("no" .. targetKind, "ไม่พบเป้าหมายกลุ่ม " .. targetKind) return end
		local reach = keepDist and math.max(Cfg.Reach, keepDist) or Cfg.Reach
		if walkTo(t.Position, reach) then
			if toolKind then equip(toolKind) end
			aim(t.Position)
			useTool(3, 0.16)
			fire(targetKind, t)
			P.Stats.items += 1
			if targetKind == "monster" then P.Stats.kills += 1 end
		else
			aim(t.Position)
		end
	end, label)
end
gatherAction("Mine", "ore", "toolPick", 70, nil, "ขุดแร่")
gatherAction("Chop", "tree", "toolAxe", 66, nil, "ตัดไม้")
gatherAction("Fight", "monster", "toolWep", 74, nil, "สู้มอน")
gatherAction("Loot", "loot", "toolPick", 60, nil, "เก็บของตก")

registerAction("Fish", 62, function()
	local spot = nearest("fish")
	if spot and not walkTo(spot.Position, Cfg.Reach + 6) then aim(spot.Position) return end
	equip("toolRod")
	if not char() or not char():FindFirstChildOfClass("Tool") then return end
	aim((hrp() and hrp().Position or Vector3.zero) + Vector3.new(0, -25, 0))
	useTool(1, 0.3)
	fire("fish")
	P.FishPhase = (P.FishPhase or 0) + 1
	-- เกมส่วนใหญ่: โยนเบ็ด → รอ → งัด
	for _ = 1, 10 do
		if not P.State.Fish then break end
		task.wait(0.25)
	end
	useTool(1, 0.2)
	P.Stats.items += 1
end, "ตกปลา")

--------------------------------------------------------------------------------
-- งาน: ไข่ / สัตว์ / ฮีล
--------------------------------------------------------------------------------
registerAction("Egg", 50, function()
	local e, d = promptBy("egg", 200)
	if not e then warnOnce("egg", "ไม่พบจุดฟักไข่") return end
	if walkTo(e.part.Position, Cfg.Reach + 2) then
		firePrompt(e)
		fire("egg", e.part)
		P.Stats.items += 1
	else
		aim(e.part.Position)
	end
end, "ฟักไข่")

registerAction("Pet", 48, function()
	local e = promptBy("animal", 200)
	if not e then warnOnce("animal", "ไม่พบจุดดูแลสัตว์") return end
	if walkTo(e.part.Position, Cfg.Reach + 3) then
		firePrompt(e)
		if P.State.Breed then fire("animal", e.part) end
	else
		aim(e.part.Position)
	end
end, "ดูแลสัตว์")

registerAction("Heal", 98, function()
	local h = hum()
	if not h or h.Health / h.MaxHealth > 0.45 then return end
	local food = toolBy("food")
	if food then equip("food"); useTool(1, 0.2); fire("food", food.Name) end
end, "ฮีลตัวเอง")

--------------------------------------------------------------------------------
-- Utility : งานเบื้องหลัง
--------------------------------------------------------------------------------
local GUIWORDS = {}
local guiHarvest, guiHarvestT = {}, 0
local function harvestGui()
	local list = {}
	local pg = LP:FindFirstChild("PlayerGui")
	if pg then
		for _, d in ipairs(pg:GetDescendants()) do
			if (d:IsA("TextButton") or d:IsA("ImageButton")) and d.Visible then
				if not (gui and d:IsDescendantOf(gui)) then
					list[#list + 1] = {
						txt = (d.Name .. " " .. (d:IsA("TextButton") and d.Text or "")):lower(),
						obj = d,
					}
				end
			end
		end
	end
	guiHarvest, guiHarvestT = list, os.clock()
	return list
end
local function guiButtons(words)
	local src = (os.clock() - guiHarvestT < 0.8) and guiHarvest or harvestGui()
	local out = {}
	for _, e in ipairs(src) do
		if e.obj.Parent and hit(e.txt, words) then out[#out + 1] = e.obj end
	end
	return out
end
local function press(btn)
	if not btn then return end
	pcall(function() btn.MouseButton1Click:Fire() end)
	local cam = Workspace.CurrentCamera
	local v = btn.AbsolutePosition + btn.AbsoluteSize / 2
	if mouse1click then if pcall(mouse1click) then return end end
	pcall(function()
		VirtualUser:CaptureController()
		VirtualUser:Button1Down(v, cam and cam.CFrame or CFrame.new())
		task.wait(0.04)
		VirtualUser:Button1Up(v, cam and cam.CFrame or CFrame.new())
	end)
end

local RARE = { "mutat", "shiny", "gold", "rainbow", "glow", "giant", "star", "golden", "crystal" }
local function invCount()
	local bp = LP:FindFirstChild("Backpack"); if not bp then return 0 end
	local n = 0
	for _, d in ipairs(bp:GetChildren()) do
		if d:IsA("Tool") then
			local isTool = false
			for _, k in ipairs({ "toolPick", "toolAxe", "toolRod", "toolCan", "toolWep", "seed", "food" }) do
				if hit(d.Name, KIND[k]) then isTool = true break end
			end
			if not isTool then
				local tier = tierOf(d)
				local keep = false
				if Cfg.SkipRare and hit(d.Name, RARE) then keep = true end
				if Cfg.Filter.keepSelected and tier and Cfg.Filter.tiers[tier] then keep = true end
				if not keep then n += 1 end
			end
		end
	end
	return n
end
local function sellOnce()
	local e = promptBy("sell", 400)
	local done = false
	if e then
		if walkTo(e.part.Position, Cfg.Reach + 3) then
			firePrompt(e); done = true
		else
			aim(e.part.Position)
			return false
		end
	end
	if not done then fire("sell", LP) end
	for _, b in ipairs(guiButtons({ "sell all", "ขายทั้งหมด", "sell" })) do press(b) end
	P.Stats.sells += 1
	return true
end
registerUtil("Sell", 3, function()
	if not alive() then return end
	if invCount() >= Cfg.SellAt then
		if sellOnce() then log(("ขายของแล้ว (สะสม %d)"):format(invCount()), "ok") end
	end
end, "ขายอัตโนมัติ")

registerUtil("Quest", 2.2, function()
	local n = 0
	for _, b in ipairs(guiButtons(KIND.claim)) do press(b); n += 1 end
	if n > 0 then P.Stats.quests += n; log(("กดรับรางวัล %d ปุ่ม"):format(n), "ok") end
	if P.State.QuestFollow then
		local m = detectQuestMode()
		if m and not P.State[m] and P.Setters[m] then
			log("เควสต้องการ: " .. m .. " → เปิดโหมดให้แล้ว")
			P.Setters[m](true)
		end
	end
	local r = bestRemote("quest")
	if r then pcall(function() r.obj:FireServer() end) end
end, "เควส")

local function textOfGui()
	local pg = LP:FindFirstChild("PlayerGui"); if not pg then return "" end
	local buf = {}
	for _, d in ipairs(pg:GetDescendants()) do
		if d:IsA("TextLabel") and d.Text and #d.Text > 2 then table.insert(buf, d.Text) end
	end
	return table.concat(buf, " "):lower()
end
function detectQuestMode()
	local t = textOfGui()
	if t == "" then return nil end
	if hit(t, KIND.tree) or hit(t, { "chop", "wood" }) then return "Chop" end
	if hit(t, KIND.ore) or hit(t, { "mining", "mine" }) then return "Mine" end
	if hit(t, KIND.fish) then return "Fish" end
	if hit(t, KIND.monster) then return "Fight" end
	if hit(t, KIND.egg) then return "Egg" end
	if hit(t, KIND.crop) or hit(t, { "plant", "harvest", "grow", "water" }) then return "Harvest" end
	return nil
end

registerUtil("Craft", 4, function()
	for _, b in ipairs(guiButtons(KIND.craft)) do press(b) end
end, "คราฟ/อัปเกรด")

registerUtil("BuySeed", 5, function()
	if toolBy("seed") then return end
	local e = promptBy("shop", 500)
	if not e then return end
	if not walkTo(e.part.Position, Cfg.Reach + 3) then aim(e.part.Position) return end
	firePrompt(e)
	task.wait(0.4)
	local bought = 0
	for _, b in ipairs(guiButtons({ "buy", "ซื้อ", "¢", "$" })) do
		if bought >= 3 then break end
		press(b); bought += 1; task.wait(0.1)
	end
	if bought > 0 then log(("ซื้อเมล็ด %d ครั้ง"):format(bought), "ok") end
	local r = bestRemote("seed") or bestRemote("shop")
	if r then pcall(function() r.obj:FireServer() end) end
end, "ซื้อเมล็ด")

registerUtil("Reward", 6, function()
	for _, b in ipairs(guiButtons({ "reward", "daily", "gift", "spin", "รางวัล", "รับ" })) do press(b) end
end, "รับรางวัล/กิจกรรม")

--------------------------------------------------------------------------------
-- ESP + Radar
--------------------------------------------------------------------------------
local espObj = {}
local ESPCOL = {
	ore = Color3.fromRGB(120, 200, 255), tree = Color3.fromRGB(150, 220, 120),
	egg = Color3.fromRGB(255, 220, 120), animal = Color3.fromRGB(255, 160, 210),
	monster = Color3.fromRGB(255, 100, 100), crop = Color3.fromRGB(120, 255, 170),
	loot = Color3.fromRGB(255, 200, 90),
}
local function espLoop()
	while not P.Destroyed do
		local my = hrp()
		if Cfg.FpsGuard and P.Fps and P.Fps < 28 and P.State.ESP then
			if P.Setters and P.Setters.ESP then P.Setters.ESP(false) end
			log("FPS ต่ำ → ปิดเรดาร์ภาพชั่วคราว", "warn")
		end
		if P.State.ESP and my then
			for kind, on in pairs(Cfg.ESP) do
				if on then
					for _, e in ipairs(collect(kind, kind == "crop", 420, 14)) do
						local p = e.p
						if not espObj[p] then
							espObj[p] = cd("Highlight", { FillColor = ESPCOL[kind] or C.accent, OutlineColor = ESPCOL[kind] or C.accent,
								FillTransparency = 0.72, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Adornee = p, Parent = p })
						end
					end
				end
			end
			for p, h in pairs(espObj) do
				if not p.Parent then h:Destroy(); espObj[p] = nil end
			end
		end
		task.wait(2.2)
	end
end

local radarRows = {}
P.SetESPOff = function()
	if P.Setters and P.Setters.ESP then pcall(P.Setters.ESP, false) end
end
local function radarLoop()
	while not P.Destroyed do
		if P.State.Radar and P.RadarBox then
			local kinds = { { "crop", true }, { "ore" }, { "tree" }, { "monster" }, { "egg" }, { "loot" } }
			local rows = {}
			for _, k in ipairs(kinds) do
				local list = collect(k[1], k[2], Cfg.ScanRange, Cfg.RadarCount)
				for i = 1, math.min(#list, 3) do
					table.insert(rows, { kind = k[1], d = list[i].d, p = list[i].p })
				end
			end
			table.sort(rows, function(a, b) return a.d < b.d end)
			for i, r in ipairs(radarRows) do
				if i <= Cfg.RadarCount and rows[i] then
					local info = kindsOf(rows[i].p)
					local tag = (info.tier and TIER_TH[info.tier]) or tostring(rows[i].kind):upper()
					if info.lvl then tag = tag .. " Lv" .. info.lvl end
					r.Text = ("%s • %s • %dm"):format(tag, rows[i].p.Name:sub(1, 12), math.floor(rows[i].d))
					r.TextColor3 = (info.tier and TIER_COL[info.tier]) or ESPCOL[rows[i].kind] or C.dim
					r.Visible = true
				else
					r.Visible = false
				end
			end
		end
		task.wait(1.7)
	end
end

--------------------------------------------------------------------------------
-- สถิติ / เงิน / FPS
--------------------------------------------------------------------------------
local function parseMoney()
	local pg = LP:FindFirstChild("PlayerGui"); if not pg then return 0 end
	local best, scanned = 0, 0
	for _, d in ipairs(pg:GetDescendants()) do
		if d:IsA("TextLabel") then
			scanned += 1
			if d.Text and #d.Text > 0 then
				for num in d.Text:gmatch("([%d][%d,]*)%s*$") do
					local n = tonumber((num:gsub(",", "")))
					if n and n > best then best = n end
				end
			end
			if scanned > 200 then break end
		end
	end
	return best
end
local statTick = 0
local function statsLoop()
	local frames, acc = 0, 0
	while not P.Destroyed do
		local dt = RunService.Heartbeat:Wait()
		frames += 1; acc += dt
		if acc >= 1 then
			P.Fps = math.floor(frames / acc)
			frames, acc = 0, 0
			if P.Fps < 28 and Cfg.FpsGuard and P.SetESPOff then pcall(P.SetESPOff) end
		end
		statTick += dt
		if statTick >= 3 then
			statTick = 0
			local m = parseMoney()
			if m > 0 then Cfg.lastMoney = m end
			if moneyLbl then moneyLbl.Text = (Cfg.lastMoney and ("%d"):format(Cfg.lastMoney)) or "--" end
			if itemLbl then itemLbl.Text = ("%d"):format(P.Stats.items) end
			if fpsLbl then
				local okPing, ping = pcall(function()
					return math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())
				end)
				fpsLbl.Text = ("%d/%s"):format(P.Fps or 0, okPing and ping or "?")
			end
		end
	end
end

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
	flyBody = cd("BodyVelocity", { MaxForce = Vector3.new(1e5, 1e5, 1e5), Velocity = Vector3.zero, Parent = my })
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
		if c then
			for _, p in ipairs(c:GetDescendants()) do
				if p:IsA("BasePart") then p.CanCollide = false end
			end
		end
	end
end)
conn(UserInputService.JumpRequest, function()
	if P.State.InfJump and alive() then local h = hum(); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end end
end)
-- VirtualUser ไม่มี event Idled (ของเดิมทำให้สคริปต์พังตั้งแต่บรรทัดนี้) -> ใช้ LP.Idled
conn(LP.Idled, function()
	if not P.State.AntiAfk then return end
	pcall(function() VirtualUser:CaptureController() end)
	pcall(function() VirtualUser:ClickButton2(Vector2.zero) end)
end)

--------------------------------------------------------------------------------
-- Profile (เซฟ/โหลดตาม PlaceId)
--------------------------------------------------------------------------------
local FILE = ("GardenProX_%d.json"):format(game.PlaceId)
local saveQueued = false
function saveProfileSoon()
	if saveQueued then return end
	saveQueued = true
	task.delay(3, function()
		saveQueued = false
		pcall(function()
			if not writefile then return end
			local data = { cfg = Cfg, state = {}, waypoints = P.Waypoints }
			for k, v in pairs(P.State) do if type(v) == "boolean" then data.state[k] = v end end
			writefile(FILE, HttpService:JSONEncode(data))
		end)
	end)
end
local function loadProfile()
	local ok = pcall(function()
		if not (readfile and isfile and isfile(FILE)) then return end
		local d = HttpService:JSONDecode(readfile(FILE))
		if type(d.cfg) == "table" then
			for k, v in pairs(d.cfg) do if type(v) ~= "table" and Cfg[k] ~= nil then Cfg[k] = v end end
			if type(d.cfg.ESP) == "table" then for k, v in pairs(d.cfg.ESP) do Cfg.ESP[k] = v end end
			if type(d.cfg.Filter) == "table" then
				for k, v in pairs(d.cfg.Filter) do
					if type(v) ~= "table" then
						Cfg.Filter[k] = v
					elseif type(Cfg.Filter[k]) == "table" then
						for kk, vv in pairs(v) do Cfg.Filter[k][kk] = vv end
					end
				end
			end
		end
		if type(d.waypoints) == "table" then P.Waypoints = d.waypoints end
		if type(d.state) == "table" then
			P.PendingState = d.state
		end
	end)
	return ok
end

--------------------------------------------------------------------------------
-- แท็บ: หน้าหลัก
--------------------------------------------------------------------------------
local pMain  = page("หลัก")
local pFarm  = page("ฟาร์ม")
local pGath  = page("เก็บของ")
local pPet   = page("ไข่/สัตว์")
local pQuest = page("เควส")
local pEcon  = page("เศรษฐกิจ")
local pFilter= page("กรอง")
local pMove  = page("ย้าย")
local pSet   = page("ตั้งค่า")

local nMain = navBtn("หลัก", "★")
navBtn("ฟาร์ม", "❦")
navBtn("เก็บของ", "⛏")
navBtn("ไข่/สัตว์", "✦")
navBtn("เควส", "☰")
navBtn("เศรษฐกิจ", "◈")
navBtn("กรอง", "⊙")
navBtn("ย้าย", "➤")
navBtn("ตั้งค่า", "⚙")

head(pMain, "สถานะรวม")
local dash = cd("Frame", { Size = UDim2.new(1, 0, 0, 62), BackgroundColor3 = C.card,
	BorderSizePixel = 0, Parent = pMain })
corner(dash, 8); pad(dash, 8)
local dashLbl = cd("TextLabel", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 11, TextColor3 = C.dim,
	TextXAlignment = Enum.TextXAlignment.Left, Text = "กำลังอ่านข้อมูล...", Parent = dash })

head(pMain, "เปิด/หยุดทั้งระบบ")
button(pMain, "▶ เปิดทุกอย่าง (ยกเว้นโหดเกินไป)", function()
	local on = { "Harvest", "Plant", "Water", "Mine", "Chop", "Fish", "Fight", "Loot",
		"Egg", "Pet", "Quest", "QuestFollow", "Sell", "Craft", "Reward", "Heal", "AntiAfk", "Radar" }
	for _, f in ipairs(on) do if P.Setters[f] then P.Setters[f](true) end end
	toast("เปิดทุกอย่างแล้ว • ปรับละเอียดได้ในแต่ละแท็บ", "ok")
end, Color3.fromRGB(36, 92, 56), 36)
button(pMain, "■ หยุดทุกอย่างทันที", function()
	for flag, s in pairs(P.Setters) do pcall(s, false) end
	pcall(stopFly)
	toast("หยุดทั้งหมด", "ok")
end, Color3.fromRGB(96, 48, 48), 32)
button(pMain, "⚡ โหมดโหด (ไม่หน่วง ไม่มีดีเลย์สุ่ม)", function()
	Cfg.Turbo = true; Cfg.Humanize = false; Cfg.Delay = 0.01
	toast("เปิดโหมดโหด — เร็วกว่าแต่ดูไม่เป็นธรรมชาติ", "warn")
end, Color3.fromRGB(76, 60, 24), 32)
button(pMain, "🐢 โหมดปลอดภัย (หน่วงสุ่ม ลดความเสี่ยง)", function()
	Cfg.Turbo = false; Cfg.Humanize = true; Cfg.Delay = 0.08; Cfg.Jitter = 0.3
	toast("เปิดโหมดปลอดภัย", "ok")
end, Color3.fromRGB(38, 60, 92), 32)

head(pMain, "เป้าหมายด่วน")
button(pMain, "วาร์ปไปของที่ใกล้สุด", function()
	local best, bd, bk
	for _, k in ipairs({ "crop", "ore", "tree", "monster", "loot", "egg" }) do
		local t, d = nearest(k, k == "crop")
		if t and (not bd or d < bd) then best, bd, bk = t, d, k end
	end
	if best then hrp().CFrame = CFrame.new(best.Position + Vector3.new(0, 7, 0)); toast(("วาร์ป %s (%.0fm)"):format(bk, bd), "ok") end
end)
button(pMain, "สแกนโลกใหม่ทันที", function() refreshWorld(); promptsRefresh(); toast(("พบวัตถุ %d ชิ้น"):format(#W.list), "ok") end)
button(pMain, "🔍 ตรวจแมพ (คัดลอกรายงานส่งให้ดู)", function()
	scanRemotes(); refreshWorld(); promptsRefresh(); P.Diagnose()
end, C.blue, 34)

--------------------------------------------------------------------------------
-- แท็บ: ฟาร์ม
--------------------------------------------------------------------------------
head(pFarm, "พืชผล")
toggle(pFarm, "เก็บเกี่ยวอัตโนมัติ", "Harvest")
toggle(pFarm, "ปลูกอัตโนมัติ (เมล็ดในกระเป๋า)", "Plant")
toggle(pFarm, "รดน้ำอัตโนมัติ", "Water")
toggle(pFarm, "เก็บของตก/เหรียญที่ร่วง", "Loot")
toggle(pFarm, "กินอาหารฮีลตัวเองเมื่อเลือดน้อย", "Heal")
slider(pFarm, "ระยะเข้าถึง", 4, 20, Cfg.Reach, "%d", function(v) Cfg.Reach = v end)
head(pFarm, "เครื่องมือ")
button(pFarm, "วาร์ปไปแปลงของฉัน", function()
	local p = plotsOf()[1]
	if p then hrp().CFrame = p.CFrame + Vector3.new(0, 6, 0); toast("วาร์ปไปแปลงแล้ว", "ok")
	else toast("ไม่พบแปลง (ชื่อแปลงต้องมีชื่อผู้เล่น)", "err") end
end)
button(pFarm, "นับแปลง / เช็คสถานะ", function()
	local pl = plotsOf()
	local empty = 0
	for _, p in ipairs(pl) do if not plotHasCrop(p) then empty += 1 end end
	toast(("แปลง %d จุด • ว่าง %d"):format(#pl, empty), "ok")
end)
note(pFarm, "ถ้าไม่ยอมปลูก: ตรวจว่ามี 'เมล็ด' ในกระเป๋า และชื่อแปลงมีชื่อผู้เล่นอยู่ (ระบบใช้ชื่อนี้หาแปลงของเรา)")

--------------------------------------------------------------------------------
-- แท็บ: เก็บของ
--------------------------------------------------------------------------------
head(pGath, "งานเก็บของ")
toggle(pGath, "ขุดหินและแร่", "Mine")
toggle(pGath, "ตัดไม้", "Chop")
toggle(pGath, "ตกปลา", "Fish")
toggle(pGath, "สู้มอน (ใกล้ตัวเท่านั้น)", "Fight")
slider(pGath, "ระยะค้นหาเป้าหมาย", 200, 8000, Cfg.ScanRange, "%d", function(v) Cfg.ScanRange = v end)
head(pGath, "เรดาร์ (รายการเป้าหมายใกล้)")
toggle(pGath, "เปิดรายการเรดาร์", "Radar", function() P.State.Radar = true end)
local radarBox = cd("Frame", { Size = UDim2.new(1, 0, 0, 104), BackgroundColor3 = C.card,
	BorderSizePixel = 0, Parent = pGath })
corner(radarBox, 8); pad(radarBox, 6)
for i = 1, Cfg.RadarCount do
	local r = cd("TextLabel", { Size = UDim2.new(1, 0, 0, 15), BackgroundTransparency = 1,
		Font = Enum.Font.Code, TextSize = 10.5, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left,
		Text = "", Visible = false, Parent = radarBox })
	radarRows[i] = r
	r.Name = "r" .. i
end
radarRows[1].Text = "เปิดสวิตช์ด้านบนเพื่อดูรายการ"
radarRows[1].Visible = true
P.RadarBox = radarBox
head(pGath, "แสดงผล (ESP)")
toggle(pGath, "เรดาร์ภาพ (Highlight)", "ESP")
for _, k in ipairs({ { "ore", "แร่" }, { "tree", "ไม้" }, { "crop", "พืช" }, { "monster", "มอน" }, { "egg", "ไข่" }, { "loot", "ของตก" } }) do
	local f = row(pGath, " · แสดง " .. k[2], 28)
	local cb = cd("TextButton", { Size = UDim2.fromOffset(24, 24), Position = UDim2.new(1, -32, 0.5, -12),
		BackgroundColor3 = C.off, BorderSizePixel = 0, Font = Enum.Font.GothamBold, TextSize = 12,
		TextColor3 = C.text, Text = "", Parent = f })
	corner(cb, 6)
	local function render()
		local on = Cfg.ESP[k[1]]
		cb.BackgroundColor3 = on and C.ok or C.off
		cb.Text = on and "✓" or ""
	end
	cb.MouseButton1Click:Connect(function()
		Cfg.ESP[k[1]] = not Cfg.ESP[k[1]]
		render(); saveProfileSoon()
	end)
	render()
end

--------------------------------------------------------------------------------
-- แท็บ: ไข่/สัตว์
--------------------------------------------------------------------------------
head(pPet, "ฟักไข่และสัตว์")
toggle(pPet, "ฟักไข่อัตโนมัติ", "Egg")
toggle(pPet, "ดูแล/ให้อาหารสัตว์", "Pet")
toggle(pPet, "เพาะพันธุ์อัตโนมัติ (ถ้าเกมมี)", "Breed")
button(pPet, "วาร์ปไปจุดฟักไข่", function()
	local e = promptBy("egg", 8000)
	if e then hrp().CFrame = CFrame.new(e.part.Position + Vector3.new(0, 6, 0)); toast("วาร์ปแล้ว", "ok")
	else toast("ไม่พบจุดฟักไข่", "err") end
end)
button(pPet, "วาร์ปไปคอกสัตว์", function()
	local e = promptBy("animal", 8000)
	if e then hrp().CFrame = CFrame.new(e.part.Position + Vector3.new(0, 6, 0)); toast("วาร์ปแล้ว", "ok")
	else toast("ไม่พบคอกสัตว์", "err") end
end)
note(pPet, "ระบบนี้ใช้ ProximityPrompt เป็นหลัก ถ้าเกมไม่มี prompt จะใช้ Remote ที่ชื่อมีคำว่า egg/animal แทน")

--------------------------------------------------------------------------------
-- แท็บ: เควส
--------------------------------------------------------------------------------
head(pQuest, "เควส")
toggle(pQuest, "เก็บรางวัลเควสอัตโนมัติ", "Quest")
toggle(pQuest, "เลือกงานให้ตรงเควสเอง", "QuestFollow")
button(pQuest, "อ่านเควสตอนนี้", function()
	local t = textOfGui()
	if t == "" then return toast("อ่านไม่เจอ — ลองเปิดหน้าต่างเควสค้างไว้", "err") end
	local m = detectQuestMode()
	toast("โหมดที่ควรทำ: " .. tostring(m), "ok")
	log("ข้อความที่อ่านได้: " .. t:sub(1, 120))
end)
button(pQuest, "กดรับ/ยืนยันทั้งหมด", function()
	local n = 0
	for _, b in ipairs(guiButtons(KIND.claim)) do press(b); n += 1; task.wait(0.12) end
	if n > 0 then P.Stats.quests += n end
	toast(("กด %d ปุ่ม"):format(n), n > 0 and "ok" or "err")
end)
note(pQuest, "เปิดหน้าต่างเควสค้างไว้ ระหว่างใช้โหมดนี้ ระบบจะอ่านข้อความแล้วเปิดงานที่ตรงให้เอง")

--------------------------------------------------------------------------------
-- แท็บ: เศรษฐกิจ
--------------------------------------------------------------------------------
head(pEcon, "การขาย")
toggle(pEcon, "ขายอัตโนมัติเมื่อของเยอะ", "Sell")
toggle(pEcon, "ไม่ขายของหายาก (mutated/shiny/gold)", "SkipRare", function() Cfg.SkipRare = true end,
	function() Cfg.SkipRare = false end)
slider(pEcon, "จำนวนขั้นต่ำก่อนขาย", 5, 200, Cfg.SellAt, "%d", function(v) Cfg.SellAt = v end)
toggle(pEcon, "คราฟ/อัปเกรดอัตโนมัติ", "Craft")
toggle(pEcon, "ซื้อเมล็ดอัตโนมัติเมื่อของหมด", "BuySeed")
toggle(pEcon, "รับรางวัล/กิจกรรม/รายวัน", "Reward")
button(pEcon, "ขายเดี๋ยวนี้", function() sellOnce(); toast("ขายแล้ว", "ok") end)
button(pEcon, "วาร์ปไปร้านขาย", function()
	local e = promptBy("sell", 8000)
	if e then hrp().CFrame = CFrame.new(e.part.Position + Vector3.new(0, 6, 0)); toast("วาร์ปแล้ว", "ok")
	else toast("ไม่พบร้านขาย", "err") end
end)
head(pEcon, "สรุปการเงินเซสชัน")
local econLbl = cd("TextLabel", { Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = C.card,
	Font = Enum.Font.Code, TextSize = 11, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left,
	TextWrapped = true, Text = "  --", Parent = pEcon })
corner(econLbl, 8); pad(econLbl, 8)

--------------------------------------------------------------------------------
-- แท็บ: ตัวกรองระดับ
--------------------------------------------------------------------------------
head(pFilter, "เปิดใช้ตัวกรอง")
toggle(pFilter, "ใช้ตัวกรองระดับ / เลเวล", "FilterOn", function() Cfg.Filter.enabled = true end,
	function() Cfg.Filter.enabled = false end)
toggle(pFilter, "เข้มงวด: ไม่รู้ระดับ = ไม่เอา", "FilterStrict", function() Cfg.Filter.strict = true end,
	function() Cfg.Filter.strict = false end)

head(pFilter, "ระดับ (Tier) ที่ต้องการเก็บ")
local tierCbs = {}
for _, t in ipairs(TIERS) do
	local f = row(pFilter, "", 30)
	cd("Frame", { Size = UDim2.fromOffset(10, 10), Position = UDim2.fromOffset(11, 10),
		BackgroundColor3 = TIER_COL[t], BorderSizePixel = 0, Parent = f })
	cd("TextLabel", { Size = UDim2.new(1, -90, 1, 0), Position = UDim2.fromOffset(26, 0),
		BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = C.text,
		TextXAlignment = Enum.TextXAlignment.Left, Text = ("%s (%s)"):format(TIER_TH[t], t), Parent = f })
	local cb = cd("TextButton", { Size = UDim2.fromOffset(24, 24), Position = UDim2.new(1, -32, 0.5, -12),
		BackgroundColor3 = C.off, BorderSizePixel = 0, Font = Enum.Font.GothamBold, TextSize = 12,
		TextColor3 = C.text, Parent = f })
	corner(cb, 6)
	local function render()
		local on = Cfg.Filter.tiers[t]
		cb.BackgroundColor3 = on and TIER_COL[t] or C.off
		cb.Text = on and "✓" or ""
	end
	cb.MouseButton1Click:Connect(function()
		Cfg.Filter.tiers[t] = not Cfg.Filter.tiers[t]
		render(); saveProfileSoon()
	end)
	render()
	tierCbs[t] = render
end

head(pFilter, "ช่วงระดับเลเวล")
slider(pFilter, "เลเวลต่ำสุด", 0, 200, Cfg.Filter.minLevel, "%d", function(v) Cfg.Filter.minLevel = v end)
slider(pFilter, "เลเวลสูงสุด", 0, 999, Cfg.Filter.maxLevel, "%d", function(v) Cfg.Filter.maxLevel = v end)

head(pFilter, "นำไปใช้กับ")
for _, u in ipairs({ { "crop", "พืช/ผลผลิต" }, { "ore", "แร่" }, { "tree", "ไม้" }, { "monster", "มอน" },
	{ "loot", "ของตก" }, { "egg", "ไข่" }, { "animal", "สัตว์" } }) do
	toggle(pFilter, "กรอง " .. u[2], "FilterUse_" .. u[1],
		function() Cfg.Filter.use[u[1]] = true end, function() Cfg.Filter.use[u[1]] = false end)
end

head(pFilter, "เมล็ดพันธุ์")
toggle(pFilter, "เลือกเมล็ดระดับสูงสุดก่อน", "SeedHigh", function() Cfg.Filter.seedHighFirst = true end,
	function() Cfg.Filter.seedHighFirst = false end)
slider(pFilter, "ระดับเมล็ดขั้นต่ำ (1=ธรรมดา 7=สวรรค์)", 1, 7, Cfg.Filter.seedMin, "%d",
	function(v) Cfg.Filter.seedMin = v end)

head(pFilter, "การขาย")
toggle(pFilter, "ไม่ขายของที่อยู่ในระดับที่เลือกไว้", "KeepSel",
	function() Cfg.Filter.keepSelected = true end, function() Cfg.Filter.keepSelected = false end)

head(pFilter, "สถานะตัวกรอง")
local filterLbl = cd("TextLabel", { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = C.card,
	Font = Enum.Font.Code, TextSize = 11, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left,
	TextWrapped = true, Text = "  --", Parent = pFilter })
corner(filterLbl, 8); pad(filterLbl, 8)
button(pFilter, "ล้างตัวกรอง (เลือกทุกระดับ)", function()
	for _, t in ipairs(TIERS) do Cfg.Filter.tiers[t] = true end
	Cfg.Filter.minLevel, Cfg.Filter.maxLevel = 0, 999
	for _, t in ipairs(TIERS) do if tierCbs[t] then tierCbs[t]() end end
	toast("ล้างตัวกรองแล้ว", "ok")
end)
note(pFilter, "วิธีใช้: เปิดสวิตช์บนสุด แล้วเลือกเฉพาะระดับที่อยากเก็บ • ระบบอ่านระดับจากชื่อวัตถุ / ชื่อโฟลเดอร์ / attribute Rarity-Tier-Level ของเกม • ถ้าเกมไม่บอกระดับ จะถูกนับเป็น 'ไม่รู้ระดับ' (โหมดเข้มงวดจะข้ามไป)")

task.spawn(function()
	while not P.Destroyed do
		if filterLbl then
			if not Cfg.Filter.enabled then
				filterLbl.Text = "  ตัวกรองปิดอยู่ — เก็บทุกอย่าง\n  เปิดสวิตช์ด้านบนเพื่อเริ่มกรอง"
			else
				local pass, total = 0, 0
				for _, kind in ipairs({ "crop", "ore", "tree", "monster", "loot", "egg", "animal" }) do
					local b = W.idx[kind]
					if b then
						for _, e in ipairs(b) do
							if e.p.Parent and e.d <= 900 then
								total += 1
								if passesFilter(kind, e.p) then pass += 1 end
							end
						end
					end
				end
				filterLbl.Text = ("  ผ่านตัวกรอง %d / %d ชิ้นในระยะ 900 (%.0f%%)\n  เลเวล %d-%d • เข้มงวด: %s"):format(
					pass, total, total > 0 and (pass / total * 100) or 0,
					Cfg.Filter.minLevel, Cfg.Filter.maxLevel, Cfg.Filter.strict and "ใช่" or "ไม่")
			end
		end
		task.wait(3.5)
	end
end)

--------------------------------------------------------------------------------
-- แท็บ: ย้าย
--------------------------------------------------------------------------------
head(pMove, "การเคลื่อนที่")
slider(pMove, "ความเร็วเดิน", 16, 300, Cfg.Speed, "%d", function(v) Cfg.Speed = v end)
slider(pMove, "ความเร็วบิน", 10, 400, Cfg.FlySpeed, "%d", function(v) Cfg.FlySpeed = v end)
toggle(pMove, "เพิ่มความเร็ว", "Speed")
toggle(pMove, "กระโดดสูง", "Jump")
toggle(pMove, "กระโดดไม่จำกัด", "InfJump")
toggle(pMove, "เดินทะลุของ", "Noclip", nil, function()
	local c = char(); if c then for _, p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = true end end end
end)
toggle(pMove, "บิน (จอยลอย/คีย์บอร์ด)", "Fly", startFly, stopFly)
head(pMove, "วาร์ปสถานี")
button(pMove, "ร้านเมล็ด", function()
	local e = promptBy("shop", 9000)
	if e then hrp().CFrame = CFrame.new(e.part.Position + Vector3.new(0, 6, 0)) else toast("ไม่พบร้านเมล็ด", "err") end
end)
button(pMove, "เหมือง", function()
	local t = nearest("ore", 9000)
	if t then hrp().CFrame = CFrame.new(t.Position + Vector3.new(0, 8, 0)) else toast("ไม่พบเหมือง", "err") end
end)
button(pMove, "ทะเล/จุดตกปลา", function()
	local t = nearest("fish", 9000)
	if t then hrp().CFrame = CFrame.new(t.Position + Vector3.new(0, 12, 0)) else toast("ไม่พบทะเล", "err") end
end)
button(pMove, "ป่า/ต้นไม้", function()
	local t = nearest("tree", 9000)
	if t then hrp().CFrame = CFrame.new(t.Position + Vector3.new(0, 8, 0)) else toast("ไม่พบป่า", "err") end
end)
head(pMove, "จุดวาร์ปของฉัน")
local wpBox = cd("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1, Parent = pMove }, { cd("UIListLayout", { Padding = UDim.new(0, 4) }) })
local function renderWaypoints()
	for _, c in ipairs(wpBox:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
	if #P.Waypoints == 0 then
		cd("TextLabel", { Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Font = Enum.Font.Gotham,
			TextSize = 11, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left,
			Text = "ยังไม่มีจุด — กด 'บันทึกจุดนี้'", Parent = wpBox })
	end
	for i, wp in ipairs(P.Waypoints) do
		local r = cd("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = C.card2,
			BorderSizePixel = 0, Parent = wpBox })
		corner(r, 7)
		cd("TextLabel", { Size = UDim2.new(1, -80, 1, 0), Position = UDim2.fromOffset(10, 0),
			BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 11.5, TextColor3 = C.text,
			TextXAlignment = Enum.TextXAlignment.Left, Text = ("%d. %s"):format(i, wp.name or "จุด"), Parent = r })
		local go = cd("TextButton", { Size = UDim2.fromOffset(44, 22), Position = UDim2.new(1, -70, 0.5, -11),
			BackgroundColor3 = C.accent, BorderSizePixel = 0, Font = Enum.Font.GothamBold, TextSize = 11,
			TextColor3 = Color3.fromRGB(15, 22, 16), Text = "ไป", Parent = r })
		corner(go, 6)
		go.MouseButton1Click:Connect(function()
			local my = hrp()
			if my and wp.p then my.CFrame = CFrame.new(wp.p) end
		end)
		local del = cd("TextButton", { Size = UDim2.fromOffset(22, 22), Position = UDim2.new(1, -22, 0.5, -11),
			BackgroundColor3 = C.bad, BorderSizePixel = 0, Font = Enum.Font.GothamBold, TextSize = 11,
			TextColor3 = C.text, Text = "✕", Parent = r })
		corner(del, 6)
		del.MouseButton1Click:Connect(function()
			table.remove(P.Waypoints, i)
			renderWaypoints(); saveProfileSoon()
		end)
	end
end
button(pMove, "＋ บันทึกจุดนี้", function()
	local my = hrp(); if not my then return end
	table.insert(P.Waypoints, { name = ("จุด %d"):format(#P.Waypoints + 1), p = my.Position })
	renderWaypoints(); saveProfileSoon(); toast("บันทึกจุดแล้ว", "ok")
end)
button(pMove, "ล้างจุดทั้งหมด", function() P.Waypoints = {}; renderWaypoints(); saveProfileSoon() end)
head(pMove, "เส้นทางอัตโนมัติ (Route)")
toggle(pMove, "เล่นเส้นทางวนซ้ำ", "RoutePlay", function()
	P.Route.play = true
	if #P.Route.list == 0 then
		for _, wp in ipairs(P.Waypoints) do table.insert(P.Route.list, wp.p) end
	end
	if #P.Route.list == 0 then toast("ยังไม่มีจุด — บันทึกจุดก่อน", "err"); P.Route.play = false end
end, function() P.Route.play = false end)
toggle(pMove, "บันทึกเส้นทางจากการเดิน", "RouteRec", function()
	P.RouteRec = true
	task.spawn(function()
		local last
		while P.State.RouteRec and not P.Destroyed do
			local my = hrp()
			if my and (not last or dist(my.Position, last) > 6) then
				last = my.Position
				table.insert(P.Route.list, my.Position)
				log(("บันทึกจุดเส้นทาง %d"):format(#P.Route.list))
			end
			task.wait(0.35)
		end
	end)
end, function() P.RouteRec = false end)
button(pMove, "ล้างเส้นทาง", function() P.Route.list = {}; P.Route.i = 1; toast("ล้างเส้นทางแล้ว", "ok") end)
renderWaypoints()

--------------------------------------------------------------------------------
-- แท็บ: ตั้งค่า
--------------------------------------------------------------------------------
head(pSet, "การทำงานในเกม")
toggle(pSet, "ใช้การแตะวัตถุ (Touched) ช่วยปลูก/เก็บ", "UseTouch", function()
	Cfg.UseTouch = true
end, function()
	Cfg.UseTouch = false
end)
head(pSet, "ซ่อม HUD")
button(pSet, "⟳ ซ่อม UI ทันที (คืนตำแหน่ง/ขนาด)", function() P.RepairUI(); toast("ซ่อม UI แล้ว", "ok") end, C.blue)
slider(pSet, "ขนาด UI", 60, 130, math.floor((Cfg.UIScale or 1) * 100), "%d%%", function(v)
	Cfg.UIScale = v / 100
	pcall(fit)
	pcall(saveProfileSoon)
end)
note(pSet, "ขนาด UI 100% = พอดีจออัตโนมัติ • ถ้าตัวหนังสือเล็กไปเลื่อนเป็น 110-120% (อาจล้นจอเล็กน้อย) • หมุนจอ/เปลี่ยนความละเอียด ระบบปรับให้เอง")
toggle(pSet, "ย้าย GUI ไป gethui (ถ้าโดน UI เกมทับ)", "UseGethui", function()
	_G.GPX_USE_GETHUI = true
	local ok, h = pcall(function() return gethui() end)
	if ok and h then gui.Parent = h; P.RepairUI(); toast("ย้ายไป gethui แล้ว", "ok")
	else toast("executor นี้ไม่มี gethui", "err") end
end, function()
	_G.GPX_USE_GETHUI = false
	gui.Parent = LP:WaitForChild("PlayerGui")
	P.RepairUI()
end)

head(pSet, "ประสิทธิภาพ / ความปลอดภัย")
toggle(pSet, "โหมดโหด (ไม่มีดีเลย์)", "Turbo", function()
	Cfg.Turbo = true; Cfg.Humanize = false; Cfg.Delay = 0.01
end, function() Cfg.Turbo = false; Cfg.Humanize = true; Cfg.Delay = 0.06 end)
toggle(pSet, "หน่วงแบบมนุษย์ (สุ่มเวลา)", "Humanize", function() Cfg.Humanize = true end,
	function() Cfg.Humanize = false end)
slider(pSet, "ระดับความสุ่ม", 0, 80, math.floor(Cfg.Jitter * 100), "%d%%", function(v) Cfg.Jitter = v / 100 end)
toggle(pSet, "ลด ESP อัตโนมัติเมื่อ FPS ต่ำ", "FpsGuard", function() Cfg.FpsGuard = true end,
	function() Cfg.FpsGuard = false end)
toggle(pSet, "กันเตะ AFK", "AntiAfk")

head(pSet, "รีโมท (ดีบัก)")
local remoteBox = cd("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1, Parent = pSet }, { cd("UIListLayout", { Padding = UDim.new(0, 2) }) })
function P.refreshRemoteList()
	for _, c in ipairs(remoteBox:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() end end
	local n = 0
	for _, r in ipairs(remotes) do
		if next(r.score) ~= nil and n < 25 then
			n += 1
			local kinds = {}
			for k in pairs(r.score) do table.insert(kinds, k) end
			cd("TextLabel", { Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Font = Enum.Font.Code,
				TextSize = 10, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left,
				Text = ("%s → %s"):format(r.name:sub(1, 26), table.concat(kinds, ","):sub(1, 28)), Parent = remoteBox })
		end
	end
end
button(pSet, "สแกนรีโมทใหม่", function()
	local n = scanRemotes()
	toast(("พบรีโมท %d"):format(n), "ok")
end)
button(pSet, "คัดลอกรายชื่อรีโมททั้งหมด", function()
	local t = {}
	for _, r in ipairs(remotes) do table.insert(t, r.path) end
	if setclipboard then pcall(setclipboard, table.concat(t, "\n")) end
	toast("คัดลอกแล้ว — เอามาวางในแชทได้เลย", "ok")
end)
button(pSet, "🔍 ตรวจแมพ + คัดลอกรายงาน", function()
	scanRemotes(); refreshWorld(); promptsRefresh(); P.Diagnose()
end, C.blue)
button(pSet, "ยิงรีโมททดสอบตามหมวด", function()
	for _, k in ipairs({ "plant", "crop", "sell", "quest", "egg", "loot" }) do
		local r, s = bestRemote(k)
		log(("%s: %s (%d)"):format(k, r and r.name or "-", s or 0))
	end
end)

head(pSet, "โปรไฟล์")
button(pSet, "บันทึกโปรไฟล์", function() saveProfileSoon(); toast("บันทึกแล้ว", "ok") end)
button(pSet, "โหลดโปรไฟล์", function() loadProfile(); toast("โหลดแล้ว (รีสตาร์ทสคริปต์เพื่อใช้ค่าใหม่)", "ok") end)
button(pSet, "รีเซ็ตค่าโรงงาน", function()
	Cfg.Speed, Cfg.Jump, Cfg.FlySpeed, Cfg.Reach = 55, 120, 90, 8
	Cfg.Delay, Cfg.Jitter, Cfg.SellAt = 0.05, 0.25, 40
	toast("รีเซ็ตแล้ว", "ok")
end)
button(pSet, "ปิดสคริปต์ทั้งหมด", function() P.Destroy() end, Color3.fromRGB(150, 52, 52))
note(pSet, "ทริค: ถ้าอยากให้ฟาร์มเร็วสุด ให้เปิด 'โหมดโหด' + เพิ่มความเร็วเดิน 90-120 + ระยะเข้าถึง 10 • ถ้าเนียน ให้ 'โหมดปลอดภัย'")

--------------------------------------------------------------------------------
-- ลูปแสดงผลหลักของ UI
--------------------------------------------------------------------------------
local uiLoop = task.spawn(function()
	while not P.Destroyed do
		if dashLbl then
			local active = {}
			for flag in pairs(P.Actions) do if P.State[flag] then table.insert(active, flag) end end
			table.sort(active)
			local uptime = math.floor(tick() - P.Stats.start)
			dashLbl.Text = ("สถานะ: %s\nเงิน: %s • เก็บได้: %d • สู้: %d • ขาย: %d • เควส: %d\nตัวกรอง: %s • ต่ำสุด %d-%d • เมล็ดขั้นต่ำ %d\nเวลา: %d นาที %d วิ • FPS %d"):format(
				#active > 0 and table.concat(active, ", ") or "หยุดอยู่",
				Cfg.lastMoney and tostring(Cfg.lastMoney) or "--",
				P.Stats.items, P.Stats.kills, P.Stats.sells, P.Stats.quests,
				Cfg.Filter.enabled and "เปิด" or "ปิด", Cfg.Filter.minLevel, Cfg.Filter.maxLevel, Cfg.Filter.seedMin,
				math.floor(uptime / 60), uptime % 60, P.Fps or 0)
			if econLbl then
				econLbl.Text = ("เงินล่าสุด: %s\nเก็บของ: %d ชิ้น • ขายไป: %d ครั้ง\nของหายาก: %s"):format(
					Cfg.lastMoney and tostring(Cfg.lastMoney) or "--", P.Stats.items, P.Stats.sells,
					Cfg.SkipRare and "ไม่ขาย" or "ขายด้วย")
			end
		end
		task.wait(1)
	end
end)

--------------------------------------------------------------------------------
-- toggle / ควบคุมหน้าต่าง
--------------------------------------------------------------------------------
conn(UserInputService.InputBegan, function(i, busy)
	if busy then return end
	if i.KeyCode == Enum.KeyCode.RightShift then setShown(not shown) end
	if i.KeyCode == Enum.KeyCode.RightControl then P.Destroy() end
end)
minBtn.MouseButton1Click:Connect(function() setShown(false) end)
fixBtn.MouseButton1Click:Connect(function() pcall(P.RepairUI) end)
closeBtn.MouseButton1Click:Connect(function() P.Destroy() end)

local dragging, from, startPos
bar.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
		dragging, from, startPos = true, i.Position, root.Position
	end
end)
conn(UserInputService.InputChanged, function(i)
	if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
		local d = i.Position - from
		local vp = viewportSize()
		local half = Vector2.new(root.AbsoluteSize.X * 0.5, root.AbsoluteSize.Y * 0.5)
		local function lim(v, h, total)
			local lo, hi = h - total * 0.5, total * 0.5 - h
			if hi < lo then lo, hi = hi, lo end
			return math.clamp(v, lo, hi)
		end
		root.Position = UDim2.new(0.5, lim(startPos.X.Offset + d.X, half.X, vp.X), 0.5, lim(startPos.Y.Offset + d.Y, half.Y, vp.Y))
	end
end)
conn(UserInputService.InputEnded, function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
end)

-- fit/ซ่อม UI ถูกย้ายไปสร้างไว้ตั้งแต่ต้นไฟล์ (ทำงานได้แม้เนื้อหาแท็บสร้างไม่ครบ)
pcall(fit)

switchTab("หลัก", nMain)

local tabCount = 0
for _ in pairs(P.Pages) do tabCount += 1 end
log(("HUD พร้อม • %d แท็บ • สเกล %.2f"):format(tabCount, scale.Scale))

--------------------------------------------------------------------------------
-- เก็บกวาด
--------------------------------------------------------------------------------
function P.Destroy()
	if P.Destroyed then return end
	P.Destroyed = true
	pcall(saveProfileSoon)
	for k in pairs(P.State) do P.State[k] = false end
	pcall(stopFly)
	for _, c in ipairs(P.Conns) do pcall(function() c:Disconnect() end) end
	for o, h in pairs(espObj) do if h then h:Destroy() end end
	if gui then gui:Destroy() end
	if _G.GardenProX == P then _G.GardenProX = nil end
end

--------------------------------------------------------------------------------
-- บูต
--------------------------------------------------------------------------------
task.spawn(statsLoop)
task.spawn(espLoop)
task.spawn(radarLoop)
task.spawn(engineLoop)
task.spawn(utilLoop)

task.spawn(function()
	task.wait(isMobile and 2.5 or 1.5)
	ensureProfile = pcall(loadProfile)
	-- เติมรายการวัตถุครั้งเดียว แล้วค่อยติดตามของใหม่แบบ incremental
	task.spawn(function()
		for _, d in ipairs(Workspace:GetDescendants()) do track(d) end
		log(("ติดตามวัตถุ %d ชิ้น"):format((function()
			local n = 0
			for _ in pairs(tracked) do n += 1 end
			return n
		end)()))
	end)
	scanRemotes()
	refreshWorld()
	promptsRefresh()
	if P.PendingState then
		for flag, v in pairs(P.PendingState) do
			if v and P.Setters[flag] then pcall(P.Setters[flag], true) end
		end
	end
	local n = 0
	for _, r in ipairs(remotes) do if next(r.score) ~= nil then n += 1 end end
	toast(("GardenPro X พร้อม • รีโมท %d • วัตถุ %d"):format(n, #W.list), "ok")
	pcall(P.RepairUI)
	-- เช็คความพร้อมแบบเร็ว ๆ บอกในคอนโซล
	task.delay(2, function()
		local plots = plotsOf()
		local seed = bestSeed()
		local prs = prompts()
		log(("พร้อม: แปลง %d • เมล็ด %s • prompt %d • วัตถุในระยะ %d"):format(
			#plots, seed and seed.Name or "ไม่มี", #prs, #W.list), #plots > 0 and "ok" or "warn")
		if #plots == 0 then
			log("ไม่พบแปลง → กด 'ตรวจแมพ' เพื่อดูชื่อจริงในเกม", "warn")
		end
	end)
	log("เริ่มระบบ • v2.4 • ตรวจแมพได้ที่แท็บ 'หลัก'")
end)

conn(Workspace.DescendantAdded, track)
conn(Workspace.DescendantRemoving, untrack)

conn(Players.LocalPlayer.CharacterAdded, function()
	task.wait(1)
	if P.State.Speed then local h = hum(); if h then h.WalkSpeed = Cfg.Speed end end
end)
pcall(function()
	if queue_on_teleport and getsynsource then
		local src = getsynsource()
		if src and #src > 100 then queue_on_teleport(src) end
	end
end)
