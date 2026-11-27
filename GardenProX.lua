--!nocheck
--[[ GardenProX v3.2 — single-file hub (client) • performance pass
     ปรับให้เบาเครื่อง:
       • ไม่บล็อกตอนเริ่ม (ไม่ WaitForChild นาน) + ปลดล็อกอัตโนมัติเมื่อเจอ HubRequest ทีหลัง
       • ไม่มี RenderStepped ในสายงานหลัก, ไม่มี pcall ในลูปความถี่สูง
       • อัปเดตข้อความเฉพาะเมื่อค่าเปลี่ยน (text diff) + จำกัดระยะด้วย BillboardGui.MaxDistance
       • แคชรายการ tag 3 วินาที, ลดความถี่ลงอัตโนมัติเมื่อ FPS ตก, มีโหมดประหยัด
       • ซ่อนหน้าต่าง = หยุดลูปทั้งหมด, สไลเดอร์ส่งค่าแบบ debounce (ไม่ยิง remote ทุกพิกเซล)
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")
local Stats             = game:GetService("Stats")
local Workspace         = game:GetService("Workspace")
local VirtualUser       = game:GetService("VirtualUser")

local LP = Players.LocalPlayer

local VERSION   = "4.0"
local BRIDGE_ID = "HubRequest"
local bridge    = ReplicatedStorage:FindFirstChild(BRIDGE_ID)
local HAS_SERVER = bridge ~= nil

local T = {
	bgTop    = Color3.fromRGB(15, 17, 23),
	bgBottom = Color3.fromRGB(24, 27, 36),
	card     = Color3.fromRGB(28, 32, 42),
	cardHi   = Color3.fromRGB(36, 41, 54),
	well     = Color3.fromRGB(20, 23, 30),
	stroke   = Color3.fromRGB(54, 61, 78),
	strokeHi = Color3.fromRGB(96, 108, 132),
	accent   = Color3.fromRGB(96, 230, 170),
	accent2  = Color3.fromRGB(112, 176, 255),
	violet   = Color3.fromRGB(150, 128, 255),
	gold     = Color3.fromRGB(248, 198, 96),
	text     = Color3.fromRGB(236, 242, 252),
	sub      = Color3.fromRGB(150, 162, 182),
	muted    = Color3.fromRGB(110, 120, 140),
	danger   = Color3.fromRGB(238, 112, 126),
	dark     = Color3.fromRGB(16, 18, 24),
	font     = Enum.Font.Gotham,
	bold     = Enum.Font.GothamBold,
	code     = Enum.Font.Code,
	W        = 600,
	H        = 430,
	headerH  = 58,
	tabsH    = 36,
	footerH  = 30,
}

local DEFAULT_HINT = "ลากแถบหัวเพื่อย้าย • RightShift หรือ ☰ ซ่อน/แสดง"

-- สถานะประสิทธิภาพ (อ่าน/เขียนจากหลายลูป)
local perf = {
	hidden = false,
	collapsed = false,
	lowPower = false,
	fxInterval = 0.2,
	uiInterval = 0.5,
	fps = 60,
}

local afkClicks, lastCritShown = 0, false
local startedAt = os.clock()

local function new(class, props, parent)
	local inst = Instance.new(class)
	for k, v in pairs(props) do
		if k ~= "Parent" then inst[k] = v end
	end
	if parent then inst.Parent = parent end
	return inst
end

local function corner(inst, r)
	new("UICorner", { CornerRadius = UDim.new(0, r or 10) }, inst)
end

local function stroke(inst, color, thick, trans)
	return new("UIStroke", {
		Color = color or T.stroke,
		Thickness = thick or 1,
		Transparency = trans or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, inst)
end

local function fire(action, value)
	if not bridge then bridge = ReplicatedStorage:FindFirstChild(BRIDGE_ID) end
	if bridge then bridge:FireServer(action, value) end
end

local function setLabel(label, text)
	if label.Text ~= text then label.Text = text end
end

-- ===== GUI =====
local gui = new("ScreenGui", {
	Name = "GardenProX",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 999,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, LP:WaitForChild("PlayerGui"))

local toastBox = new("Frame", {
	Size = UDim2.fromOffset(252, 10),
	Position = UDim2.new(1, -268, 0, 18),
	BackgroundTransparency = 1,
}, gui)
new("UIListLayout", { Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder }, toastBox)

local MAX_TOASTS = 4

local function notify(text, color)
	local accent = color or T.accent

	local frames = {}
	for _, c in ipairs(toastBox:GetChildren()) do
		if c:IsA("Frame") then frames[#frames + 1] = c end
	end
	if #frames >= MAX_TOASTS then frames[1]:Destroy() end

	local box = new("Frame", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = T.card,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, toastBox)
	corner(box, 9)
	local s = stroke(box, accent, 1, 0.65)
	local bar = new("Frame", {
		Size = UDim2.new(0, 3, 1, -14),
		Position = UDim2.fromOffset(0, 7),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, box)
	corner(bar, 2)
	local label = new("TextLabel", {
		Size = UDim2.new(1, -22, 1, 0),
		Position = UDim2.fromOffset(13, 0),
		BackgroundTransparency = 1,
		Font = T.bold,
		TextSize = 11,
		TextColor3 = T.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextTransparency = 1,
		Text = text,
	}, box)

	TweenService:Create(box, TweenInfo.new(0.18), { BackgroundTransparency = 0.04 }):Play()
	TweenService:Create(label, TweenInfo.new(0.18), { TextTransparency = 0 }):Play()
	TweenService:Create(s, TweenInfo.new(0.18), { Transparency = 0 }):Play()

	task.delay(2.8, function()
		if not box.Parent then return end
		TweenService:Create(box, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		TweenService:Create(s, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		task.wait(0.35)
		box:Destroy()
	end)
end

-- ===== ROOT =====
local shadow = new("Frame", {
	Size = UDim2.fromOffset(T.W + 14, T.H + 16),
	Position = UDim2.new(0.5, 0, 0.5, 8),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0.55,
	BorderSizePixel = 0,
	ZIndex = 1,
}, gui)
corner(shadow, 22)

local root = new("Frame", {
	Name = "Root",
	Size = UDim2.fromOffset(T.W, T.H),
	Position = UDim2.new(0.5, 0, 0.5, 0),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = T.bgTop,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	ZIndex = 2,
}, gui)
corner(root, 16)
new("UIGradient", { Rotation = 90, Color = ColorSequence.new(T.bgTop, T.bgBottom) }, root)
stroke(root, Color3.fromRGB(70, 80, 100), 1, 0.15)

local scale = new("UIScale", { Scale = 1 }, root)

-- ===== HEADER =====
local header = new("Frame", {
	Size = UDim2.new(1, 0, 0, T.headerH),
	BackgroundTransparency = 1,
	ZIndex = 3,
}, root)

local headerGlow = new("Frame", {
	Size = UDim2.new(1, 0, 0, 1),
	Position = UDim2.new(0, 0, 1, 0),
	BackgroundColor3 = Color3.fromRGB(255, 255, 255),
	BorderSizePixel = 0,
	ZIndex = 3,
}, header)
new("UIGradient", {
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	}),
	Color = ColorSequence.new(T.accent, T.accent2),
}, headerGlow)

local logo = new("Frame", {
	Size = UDim2.fromOffset(26, 26),
	Position = UDim2.fromOffset(14, 16),
	BackgroundColor3 = T.accent,
	BorderSizePixel = 0,
	ZIndex = 4,
}, header)
corner(logo, 9)
new("UIGradient", { Color = ColorSequence.new(T.accent, T.accent2), Rotation = 35 }, logo)
new("TextLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Font = T.bold,
	TextSize = 13,
	TextColor3 = T.dark,
	Text = "G",
	ZIndex = 5,
}, logo)

new("TextLabel", {
	Size = UDim2.new(0, 230, 0, 17),
	Position = UDim2.fromOffset(50, 15),
	BackgroundTransparency = 1,
	Font = T.bold,
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = T.text,
	Text = "GARDENPRO X",
	ZIndex = 4,
}, header)

new("TextLabel", {
	Size = UDim2.new(0, 230, 0, 13),
	Position = UDim2.fromOffset(50, 33),
	BackgroundTransparency = 1,
	Font = T.font,
	TextSize = 9,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = T.muted,
	Text = "LIGHTWEIGHT HUD  •  v" .. VERSION,
	ZIndex = 4,
}, header)

local chip = new("Frame", {
	Size = UDim2.fromOffset(86, 22),
	Position = UDim2.new(1, -228, 0, 18),
	BackgroundColor3 = T.well,
	BorderSizePixel = 0,
	ZIndex = 4,
}, header)
corner(chip, 11)
local chipStroke = stroke(chip, HAS_SERVER and T.accent or T.strokeHi, 1, 0.55)
local chipDot = new("Frame", {
	Size = UDim2.fromOffset(6, 6),
	Position = UDim2.fromOffset(10, 8),
	BackgroundColor3 = HAS_SERVER and T.accent or T.muted,
	BorderSizePixel = 0,
	ZIndex = 5,
}, chip)
corner(chipDot, 3)
local chipLabel = new("TextLabel", {
	Size = UDim2.new(1, -22, 1, 0),
	Position = UDim2.fromOffset(20, 0),
	BackgroundTransparency = 1,
	Font = T.bold,
	TextSize = 9,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = HAS_SERVER and T.accent or T.sub,
	Text = HAS_SERVER and "SERVER LINK" or "CLIENT ONLY",
	ZIndex = 5,
}, chip)

-- ปลดล็อกภายหลังได้ (ถ้าเซิร์ฟเวอร์โหลดช้ากว่า)
local unlockables = {}
local function registerUnlock(fn)
	if HAS_SERVER then fn() else table.insert(unlockables, fn) end
end

task.spawn(function()
	if HAS_SERVER then return end
	local found = ReplicatedStorage:WaitForChild(BRIDGE_ID, 20)
	if not found then return end
	bridge = found
	HAS_SERVER = true
	chipLabel.Text = "SERVER LINK"
	chipLabel.TextColor3 = T.accent
	chipDot.BackgroundColor3 = T.accent
	chipStroke.Color = T.accent
	chipStroke.Transparency = 0.55
	for _, fn in ipairs(unlockables) do
		local ok = pcall(fn)
		if not ok then warn("[GardenProX] ปลดล็อกไม่สำเร็จบางรายการ") end
	end
	if _G.GardenProX then _G.GardenProX.HasServer = true end
	notify("เชื่อมต่อเซิร์ฟเวอร์แล้ว — ใช้งานครบทุกฟีเจอร์", T.accent)
end)

local function headerButton(x, text)
	local b = new("TextButton", {
		Size = UDim2.fromOffset(26, 26),
		Position = UDim2.new(1, x, 0, 16),
		BackgroundColor3 = T.card,
		AutoButtonColor = false,
		Font = T.bold,
		TextSize = 12,
		TextColor3 = T.sub,
		Text = text,
		ZIndex = 4,
	}, header)
	corner(b, 8)
	local s = stroke(b, T.stroke, 1, 0.5)
	b.MouseEnter:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = T.cardHi, TextColor3 = T.text }):Play()
		TweenService:Create(s, TweenInfo.new(0.12), { Transparency = 0 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = T.card, TextColor3 = T.sub }):Play()
		TweenService:Create(s, TweenInfo.new(0.12), { Transparency = 0.5 }):Play()
	end)
	return b
end

local hideBtn     = headerButton(-36, "✕")
local collapseBtn = headerButton(-68, "–")

-- drag (ทำงานเฉพาะตอนกดค้างเมาส์ จึงไม่กิน CPU ตอนไม่ได้ใช้)
local dragging, dragInput, dragStart, startPos
header.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = root.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then dragging = false end
		end)
	end
end)
header.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		dragInput = input
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if dragging and input == dragInput then
		local d = input.Position - dragStart
		root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
	end
end)

-- ===== TABS =====
local tabsBar = new("Frame", {
	Size = UDim2.new(1, -24, 0, T.tabsH),
	Position = UDim2.fromOffset(12, T.headerH + 2),
	BackgroundColor3 = T.well,
	BackgroundTransparency = 0.35,
	BorderSizePixel = 0,
	ZIndex = 3,
}, root)
corner(tabsBar, 12)
stroke(tabsBar, T.stroke, 1, 0.6)

local indicator = new("Frame", {
	Size = UDim2.new(1 / 6, -12, 0, T.tabsH - 8),
	Position = UDim2.new(0, 6, 0, 4),
	BackgroundColor3 = T.accent,
	BorderSizePixel = 0,
	ZIndex = 4,
}, tabsBar)
corner(indicator, 9)
new("UIGradient", { Color = ColorSequence.new(T.accent, T.accent2), Rotation = 20 }, indicator)

local content = new("Frame", {
	Size = UDim2.new(1, -24, 1, -(T.headerH + T.tabsH + T.footerH + 14)),
	Position = UDim2.fromOffset(12, T.headerH + T.tabsH + 8),
	BackgroundTransparency = 1,
	ZIndex = 3,
}, root)

local TAB_NAMES = { "🌱  ฟาร์ม", "⚔  สู้", "💎  ถ้ำ", "🎣  ตกปลา", "🐾  สัตว์", "⚙  อื่น ๆ" }
local tabButtons, tabPanels = {}, {}

local function makePanel()
	local p = new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = T.strokeHi,
		ScrollBarImageTransparency = 0.45,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
		ClipsDescendants = true,
		ZIndex = 3,
	}, content)
	new("UIPadding", {
		PaddingTop = UDim.new(0, 2),
		PaddingLeft = UDim.new(0, 2),
		PaddingRight = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 10),
	}, p)
	return p
end

local function stacker(panel)
	local y = 0
	return function(h)
		local top = y
		y = y + h + 8
		panel.CanvasSize = UDim2.new(0, 0, 0, y)
		return top
	end
end

local function selectTab(i)
	for idx, panel in ipairs(tabPanels) do panel.Visible = (idx == i) end
	for idx, btn in ipairs(tabButtons) do
		btn.TextColor3 = (idx == i) and T.dark or T.sub
		btn.Font = (idx == i) and T.bold or T.font
	end
	TweenService:Create(indicator, TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Position = UDim2.new((i - 1) / #TAB_NAMES, 6, 0, 4),
	}):Play()
end

for i, name in ipairs(TAB_NAMES) do
	local btn = new("TextButton", {
		Size = UDim2.new(1 / #TAB_NAMES, 0, 1, 0),
		Position = UDim2.new((i - 1) / #TAB_NAMES, 0, 0, 0),
		BackgroundTransparency = 1,
		Font = T.font,
		TextSize = 11,
		TextColor3 = T.sub,
		Text = name,
		ZIndex = 5,
	}, tabsBar)
	tabButtons[i] = btn
	tabPanels[i] = makePanel()
	btn.MouseButton1Click:Connect(function() selectTab(i) end)
end

-- ===== FOOTER =====
local footer = new("Frame", {
	Size = UDim2.new(1, -24, 0, T.footerH - 8),
	Position = UDim2.new(0, 12, 1, -(T.footerH - 4)),
	BackgroundTransparency = 1,
	ZIndex = 3,
}, root)

local footerDot = new("Frame", {
	Size = UDim2.fromOffset(5, 5),
	Position = UDim2.fromOffset(2, 8),
	BackgroundColor3 = HAS_SERVER and T.accent or T.gold,
	BorderSizePixel = 0,
	ZIndex = 4,
}, footer)
corner(footerDot, 3)

local hintLabel = new("TextLabel", {
	Size = UDim2.new(1, -96, 1, 0),
	Position = UDim2.fromOffset(14, 0),
	BackgroundTransparency = 1,
	Font = T.font,
	TextSize = 9,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	TextColor3 = T.muted,
	Text = DEFAULT_HINT,
	ZIndex = 4,
}, footer)

new("TextLabel", {
	Size = UDim2.fromOffset(70, 1),
	Position = UDim2.new(1, -70, 0, 8),
	BackgroundTransparency = 1,
	Font = T.code,
	TextSize = 9,
	TextXAlignment = Enum.TextXAlignment.Right,
	TextColor3 = T.strokeHi,
	Text = "v" .. VERSION,
	ZIndex = 4,
}, footer)

local function setHint(text)
	if hintLabel.Text ~= text then hintLabel.Text = text end
end

-- ===== แคช/ตัวช่วย =====
local tagCache = { plots = {}, enemies = {}, ores = {}, at = -1e9 }

local function refreshTags(force)
	if not force and (os.clock() - tagCache.at) < 3 then return tagCache end
	tagCache.plots = CollectionService:GetTagged("FarmPlot")
	tagCache.enemies = CollectionService:GetTagged("TestEnemy")
	tagCache.ores = CollectionService:GetTagged("TestOre")
	tagCache.at = os.clock()
	return tagCache
end

refreshTags(true)

local function getPing()
	local ok, v = pcall(function()
		return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
	end)
	return ok and math.floor(v) or 0
end

local function statOf(name)
	local ls = LP:FindFirstChild("leaderstats")
	local v = ls and ls:FindFirstChild(name)
	return v and v.Value or 0
end

local function auditCollision()
	local char = LP.Character
	if not char then return "ไม่มีตัวละคร" end
	local bad = 0
	local first = nil
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") and part.CanCollide == false
			and not part:FindFirstAncestorOfClass("Accessory") then
			bad = bad + 1
			first = first or part.Name
		end
	end
	if bad == 0 then return "✅ ไม่พบร่องรอย noclip" end
	return ("⚠️ %d ชิ้นปิดการชน เช่น %s"):format(bad, first or "?")
end

-- ===== widgets =====
local function hoverable(row, s, desc)
	row.MouseEnter:Connect(function()
		TweenService:Create(s, TweenInfo.new(0.12), { Color = T.strokeHi, Transparency = 0 }):Play()
		if desc then setHint(desc) end
	end)
	row.MouseLeave:Connect(function()
		TweenService:Create(s, TweenInfo.new(0.12), { Color = T.stroke, Transparency = 0.45 }):Play()
		setHint(DEFAULT_HINT)
	end)
end

local function section(panel, top, text, color)
	new("Frame", {
		Size = UDim2.fromOffset(3, 12),
		Position = UDim2.fromOffset(2, top + 2),
		BackgroundColor3 = color or T.accent,
		BorderSizePixel = 0,
	}, panel)
	return new("TextLabel", {
		Size = UDim2.new(1, -14, 0, 16),
		Position = UDim2.fromOffset(12, top),
		BackgroundTransparency = 1,
		Font = T.bold,
		TextSize = 10,
		TextColor3 = T.sub,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = string.upper(text),
	}, panel)
end

local function card(panel, top, h)
	local row = new("Frame", {
		Size = UDim2.new(1, 0, 0, h),
		Position = UDim2.fromOffset(0, top),
		BackgroundColor3 = T.card,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
	}, panel)
	corner(row, 11)
	local s = stroke(row, T.stroke, 1, 0.45)
	return row, s
end

-- หมายเหตุ: ทุก widget คืน "ตัวปลดล็อก" ผ่าน registerUnlock เมื่อยังไม่พบเซิร์ฟเวอร์
local function toggle(panel, top, title, desc, default, needsServer, onChange)
	local locked = needsServer and not HAS_SERVER
	local row, s = card(panel, top, 52)

	local titleLabel = new("TextLabel", {
		Size = UDim2.new(1, -92, 0, 16),
		Position = UDim2.fromOffset(13, 8),
		BackgroundTransparency = 1,
		Font = T.bold,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextColor3 = locked and T.muted or T.text,
		Text = title,
	}, row)

	local descLabel = new("TextLabel", {
		Size = UDim2.new(1, -92, 0, 14),
		Position = UDim2.fromOffset(13, 27),
		BackgroundTransparency = 1,
		Font = T.font,
		TextSize = 9,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextColor3 = T.muted,
		Text = locked and "🔒 ต้องติดตั้ง HubServer ในแมพนี้" or desc,
	}, row)

	local sw = new("Frame", {
		Size = UDim2.fromOffset(42, 22),
		Position = UDim2.new(1, -56, 0.5, -11),
		BackgroundColor3 = default and T.accent or T.cardHi,
		BorderSizePixel = 0,
	}, row)
	corner(sw, 11)
	local swStroke = stroke(sw, T.accent, 1, default and 0 or 1)

	local knob = new("Frame", {
		Size = UDim2.fromOffset(16, 16),
		Position = UDim2.new(0, default and 23 or 3, 0.5, -8),
		BackgroundColor3 = locked and T.muted or (default and T.dark or T.text),
		BorderSizePixel = 0,
	}, sw)
	corner(knob, 8)

	local state = default and not locked
	local set
	set = function(v, silent)
		state = v
		TweenService:Create(sw, TweenInfo.new(0.16), { BackgroundColor3 = v and T.accent or T.cardHi }):Play()
		TweenService:Create(swStroke, TweenInfo.new(0.16), { Transparency = v and 0 or 1 }):Play()
		TweenService:Create(knob, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0, v and 23 or 3, 0.5, -8),
		}):Play()
		knob.BackgroundColor3 = v and T.dark or T.text
		if not silent and onChange then onChange(v) end
	end

	local hit = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "" }, sw)
	hit.MouseButton1Click:Connect(function()
		if locked then
			notify("ต้องติดตั้ง HubServer ในแมพก่อน (ดูแท็บ Misc)", T.danger)
			return
		end
		set(not state)
	end)

	if locked then
		registerUnlock(function()
			locked = false
			titleLabel.TextColor3 = T.text
			descLabel.Text = desc
			sw.BackgroundColor3 = T.cardHi
			knob.BackgroundColor3 = T.text
			state = false
		end)
	end

	hoverable(row, s, desc)
	return set
end

local function slider(panel, top, title, desc, min, max, default, step, needsServer, onChange)
	local locked = needsServer and not HAS_SERVER
	local row, s = card(panel, top, 66)

	local titleLabel = new("TextLabel", {
		Size = UDim2.new(1, -100, 0, 16),
		Position = UDim2.fromOffset(13, 8),
		BackgroundTransparency = 1,
		Font = T.bold,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = locked and T.muted or T.text,
		Text = title,
	}, row)

	local descLabel = new("TextLabel", {
		Size = UDim2.new(1, -100, 0, 14),
		Position = UDim2.fromOffset(13, 25),
		BackgroundTransparency = 1,
		Font = T.font,
		TextSize = 9,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextColor3 = T.muted,
		Text = locked and "🔒 ต้องติดตั้ง HubServer ในแมพนี้" or desc,
	}, row)

	local chip = new("Frame", {
		Size = UDim2.fromOffset(54, 20),
		Position = UDim2.new(1, -66, 0, 9),
		BackgroundColor3 = T.well,
		BorderSizePixel = 0,
	}, row)
	corner(chip, 8)
	local chipStroke = stroke(chip, locked and T.stroke or T.accent, 1, 0.55)

	local valueLabel = new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = T.bold,
		TextSize = 10,
		TextColor3 = locked and T.muted or T.accent,
		Text = locked and "—" or tostring(default),
	}, chip)

	local track = new("Frame", {
		Size = UDim2.new(1, -28, 0, 5),
		Position = UDim2.new(0, 14, 0, 50),
		BackgroundColor3 = T.well,
		BorderSizePixel = 0,
	}, row)
	corner(track, 3)
	stroke(track, T.stroke, 1, 0.7)

	local startRel = locked and 0 or (default - min) / (max - min)
	local fill = new("Frame", {
		Size = UDim2.fromScale(startRel, 1),
		BackgroundColor3 = locked and T.muted or T.accent,
		BorderSizePixel = 0,
	}, track)
	corner(fill, 3)
	if not locked then
		new("UIGradient", { Color = ColorSequence.new(T.accent, T.accent2), Rotation = 10 }, fill)
	end

	local knob = new("Frame", {
		Size = UDim2.fromOffset(12, 12),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(startRel, 0, 0.5, 0),
		BackgroundColor3 = T.text,
		BorderSizePixel = 0,
	}, track)
	corner(knob, 6)
	stroke(knob, T.dark, 2, 0)

	local value = default
	local draggingSlider = false
	local pending, lastSent = nil, 0

	-- debounce: ส่งค่าลงเซิร์ฟเวอร์ไม่เกิน 10 ครั้ง/วินาที
	local function send(v)
		local now = os.clock()
		if now - lastSent < 0.1 then
			pending = v
			return
		end
		lastSent = now
		pending = nil
		if onChange then onChange(v) end
	end

	local function setValueFromX(px)
		local rel = math.clamp((px - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
		local v = min + (max - min) * rel
		v = math.floor(v / step + 0.5) * step
		v = math.clamp(v, min, max)
		if v == value then return end
		value = v
		fill.Size = UDim2.fromScale((v - min) / (max - min), 1)
		knob.Position = UDim2.new((v - min) / (max - min), 0, 0.5, 0)
		valueLabel.Text = tostring(v)
		send(v)
	end

	local grab = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 34),
		Position = UDim2.new(0, 0, 0, 36),
		BackgroundTransparency = 1,
		Text = "",
	}, row)

	grab.InputBegan:Connect(function(input)
		if locked then
			notify("สไลเดอร์นี้ต้องติดตั้ง HubServer ก่อน", T.danger)
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			draggingSlider = true
			setValueFromX(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setValueFromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if draggingSlider and pending ~= nil then
				lastSent = os.clock()
				local p = pending
				pending = nil
				if onChange then onChange(p) end
			end
			draggingSlider = false
		end
	end)

	if locked then
		registerUnlock(function()
			locked = false
			titleLabel.TextColor3 = T.text
			descLabel.Text = desc
			valueLabel.Text = tostring(value)
			valueLabel.TextColor3 = T.accent
			chipStroke.Color = T.accent
			fill.BackgroundColor3 = T.accent
			new("UIGradient", { Color = ColorSequence.new(T.accent, T.accent2), Rotation = 10 }, fill)
		end)
	end

	hoverable(row, s, desc)
	return function() return value end
end

local function button(panel, top, text, variant, needsServer, onClick)
	local locked = needsServer and not HAS_SERVER
	local isPrimary = variant == "primary"
	local row = new("Frame", {
		Size = UDim2.new(1, 0, 0, 36),
		Position = UDim2.fromOffset(0, top),
		BackgroundColor3 = isPrimary and T.accent or T.card,
		BackgroundTransparency = (isPrimary and not locked) and 0 or 0.12,
		BorderSizePixel = 0,
	}, panel)
	corner(row, 11)
	local s = stroke(row, (isPrimary and not locked) and T.accent or T.stroke, 1, (isPrimary and not locked) and 0 or 0.45)
	if isPrimary and not locked then
		new("UIGradient", { Color = ColorSequence.new(T.accent, T.accent2), Rotation = 12 }, row)
	end

	local label = new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = T.bold,
		TextSize = 11,
		TextColor3 = locked and T.muted or (isPrimary and T.dark or (variant == "danger" and T.danger or T.text)),
		Text = locked and (text .. "   🔒") or text,
	}, row)

	local btn = new("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
	}, row)

	local baseColor = row.BackgroundColor3
	btn.MouseEnter:Connect(function()
		if locked then return end
		TweenService:Create(row, TweenInfo.new(0.12), { BackgroundColor3 = isPrimary and T.accent or T.cardHi }):Play()
		TweenService:Create(s, TweenInfo.new(0.12), { Color = T.strokeHi }):Play()
	end)
	btn.MouseLeave:Connect(function()
		if locked then return end
		TweenService:Create(row, TweenInfo.new(0.12), { BackgroundColor3 = baseColor }):Play()
		TweenService:Create(s, TweenInfo.new(0.12), { Color = T.stroke }):Play()
	end)

	btn.MouseButton1Click:Connect(function()
		if locked then
			notify("ปุ่มนี้ต้องติดตั้ง HubServer ก่อน", T.danger)
			return
		end
		local old = row.Size
		row.Size = UDim2.new(old.X.Scale, old.X.Offset - 6, old.Y.Scale, old.Y.Offset - 2)
		task.delay(0.1, function()
			if row.Parent then row.Size = old end
		end)
		if onClick then onClick() end
	end)

	if locked then
		registerUnlock(function()
			locked = false
			label.Text = text
			label.TextColor3 = isPrimary and T.dark or T.text
			row.BackgroundColor3 = isPrimary and T.accent or T.card
			if isPrimary then
				new("UIGradient", { Color = ColorSequence.new(T.accent, T.accent2), Rotation = 12 }, row)
				s.Color = T.accent
				s.Transparency = 0
				row.BackgroundTransparency = 0
			end
		end)
	end

	label.ZIndex = 3
	btn.ZIndex = 4
	return btn
end

local function statusCard(panel, top, rows)
	local h = 16 * rows + 14
	local row = card(panel, top, h)
	new("Frame", {
		Size = UDim2.fromOffset(2, h - 16),
		Position = UDim2.fromOffset(0, 8),
		BackgroundColor3 = T.accent,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
	}, row)
	corner(row:FindFirstChildOfClass("Frame"), 1)
	return new("TextLabel", {
		Size = UDim2.new(1, -22, 1, -8),
		Position = UDim2.fromOffset(12, 4),
		BackgroundTransparency = 1,
		Font = T.code,
		TextSize = 10,
		TextColor3 = T.sub,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Text = "—",
	}, row)
end

local function noteCard(panel, top, text, rows)
	local row = card(panel, top, 16 * rows + 16)
	row.BackgroundTransparency = 0.5
	new("TextLabel", {
		Size = UDim2.new(1, -24, 1, -12),
		Position = UDim2.fromOffset(12, 6),
		BackgroundTransparency = 1,
		Font = T.font,
		TextSize = 9,
		TextColor3 = T.muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Text = text,
	}, row)
	return row
end

local F = {
	plotHL = false,
	autoSell = false,
	enemyHP = false,
	critToast = false,
	reveal = false,
	audit = false,
	antiAFK = false,
	stats = false,
	radius = 40,
}

-- ===== TAB 1 : FARMING =====
local farmPanel = tabPanels[1]
local farmAt = stacker(farmPanel)

section(farmPanel, farmAt(16), "แปลงผัก", T.accent)
toggle(farmPanel, farmAt(52), "ไฮไลต์แปลงตามสถานะ", "สีเขียว = กำลังโต • เหลือง = พร้อมเก็บ", false, true, function(v)
	F.plotHL = v
	refreshTags(true)
end)
toggle(farmPanel, farmAt(52), "ขายอัตโนมัติทุก 5 วิ", "เซิร์ฟเวอร์คิดคูลดาวน์เอง ป้องกันการยิงรัว", false, true, function(v)
	F.autoSell = v
	if v then notify("เปิดขายอัตโนมัติ (คูลดาวน์ 5 วิ)", T.accent) end
end)
button(farmPanel, farmAt(36), "ขายของทั้งหมดตอนนี้", "primary", true, function()
	fire("sell")
	notify("ส่งคำขอขายไปเซิร์ฟเวอร์แล้ว", T.accent)
end)
local farmStatus = statusCard(farmPanel, farmAt(48), 2)

-- ===== TAB 2 : COMBAT =====
local combatPanel = tabPanels[2]
local combatAt = stacker(combatPanel)

section(combatPanel, combatAt(16), "ศัตรูฝึกซ้อม", T.danger)
toggle(combatPanel, combatAt(52), "แสดง HP / ระยะศัตรู", "ป้ายลอยเหนือหัว พร้อมระยะห่างเป็น studs", false, true, function(v)
	F.enemyHP = v
	refreshTags(true)
end)
toggle(combatPanel, combatAt(52), "แจ้งเตือนเมื่อตีติดคริ", "เด้ง toast มุมขวาบนเมื่อเซิร์ฟเวอร์ยืนยันคริ", false, true, function(v) F.critToast = v end)
local combatStatus = statusCard(combatPanel, combatAt(48), 2)

section(combatPanel, combatAt(16), "หมายเหตุ", T.muted)
noteCard(combatPanel, combatAt(50), "คริและดาเมจถูกตัดสินฝั่งเซิร์ฟเวอร์ (สูงสุด 1 คริ / 2 วิ) — client สั่งให้คริเองไม่ได้ จึงไม่มีช่องให้โกง", 3)

-- ===== TAB 3 : CAVE =====
local cavePanel = tabPanels[3]
local caveAt = stacker(cavePanel)

section(cavePanel, caveAt(16), "สแกนแร่", T.violet)
toggle(cavePanel, caveAt(52), "สแกนแร่หายาก", "เห็นเฉพาะแร่ที่เซิร์ฟเวอร์อนุญาต 5 วินาที", false, true, function(v)
	F.reveal = v
	refreshTags(true)
	if v then fire("scan", F.radius) end
end)
local getRadius = slider(cavePanel, caveAt(66), "รัศมีสแกน", "10–80 studs • เซิร์ฟเวอร์ clamp ให้อีกชั้น", 10, 80, 40, 5, true, function(v)
	F.radius = v
	if F.reveal then fire("scan", v) end
end)

section(cavePanel, caveAt(16), "ตรวจการชน", T.gold)
toggle(cavePanel, caveAt(52), "Collision Audit (anti-noclip)", "สแกนชิ้นส่วนในตัวละครที่ปิดการชน", false, false, function(v) F.audit = v end)
local caveStatus = statusCard(cavePanel, caveAt(48), 3)

-- ===== TAB 4 : FISHING =====
local fishPanel = tabPanels[4]
local fishAt = stacker(fishPanel)
local biteUntil, reelRow = 0, nil

section(fishPanel, fishAt(16), "ตกปลา", T.accent2)
button(fishPanel, fishAt(36), "เหวี่ยงเบ็ด (ยืนในวงเขียว)", "primary", true, function()
	biteUntil = 0
	if reelRow then reelRow.Visible = false end
	fire("cast")
end)

local reelBtn = button(fishPanel, fishAt(36), "REEL!  กด F", "primary", true, function()
	if os.clock() <= biteUntil then
		biteUntil = 0
		reelRow.Visible = false
		fire("reel")
	else
		notify("ยังไม่มีปลากัดเบ็ด", T.muted)
	end
end)
reelRow = reelBtn.Parent
reelRow.Visible = false

local fishStatus = statusCard(fishPanel, fishAt(48), 2)
noteCard(fishPanel, fishAt(54), "เหวี่ยงแล้วรอ 1.4–2.8 วิ • มีเวลา 2.2 วิให้กด REEL • คริ/Fortune ช่วยเพิ่มเหรียญ", 2)

-- ===== TAB 5 : PETS =====
local petPanel = tabPanels[5]
local petAt = stacker(petPanel)

section(petPanel, petAt(16), "สัตว์เลี้ยง", T.gold)
button(petPanel, petAt(36), "ฟักไข่ (50 เหรียญ)", "primary", true, function()
	fire("hatch")
end)
local petStatus = statusCard(petPanel, petAt(48), 2)
noteCard(petPanel, petAt(54), "สัตว์จะลอยตามหลัง • หมา 5 / แมว 8 / จิ้งจอก 14 / แพนด้า 22 / มังกร 45 พลัง", 2)

-- ===== TAB 6 : MISC =====
local miscPanel = tabPanels[6]
local miscAt = stacker(miscPanel)

section(miscPanel, miscAt(16), "การเคลื่อนที่", T.accent2)
slider(miscPanel, miscAt(66), "WalkSpeed", "ความเร็วเดิน • เซิร์ฟเวอร์จำกัดตามโหมด", 8, 60, 16, 1, true, function(v) fire("setWalk", v) end)
slider(miscPanel, miscAt(66), "JumpPower", "แรงกระโดด • ใช้กับ UseJumpPower", 30, 120, 50, 1, true, function(v) fire("setJump", v) end)
button(miscPanel, miscAt(36), "รีเซ็ตค่าเริ่มต้น (16 / 50)", "ghost", true, function()
	fire("reset")
	notify("รีเซ็ต WalkSpeed / JumpPower แล้ว", T.accent)
end)

section(miscPanel, miscAt(16), "เศรษฐกิจ / ต้มกล่อง", T.violet)
button(miscPanel, miscAt(36), "ต้มกล่อง enchant (50 เหรียญ)", "ghost", true, function()
	fire("enchant")
end)
button(miscPanel, miscAt(36), "ต้มอัตโนมัติ (สูงสุด 60 ครั้ง)", "ghost", true, function()
	fire("enchant", true)
end)
local econStatus = statusCard(miscPanel, miscAt(32), 1)

section(miscPanel, miscAt(16), "ประสิทธิภาพ", T.accent)
toggle(miscPanel, miscAt(52), "โหมดประหยัด (ลด FX ครึ่งหนึ่ง)", "ลดการอัปเดตป้ายลอย/สถานะ เหมาะกับเครื่องช้า", false, false, function(v)
	perf.lowPower = v
	notify(v and "เปิดโหมดประหยัด" or "ปิดโหมดประหยัด", v and T.gold or T.accent)
end)
toggle(miscPanel, miscAt(52), "แสดง FPS / ตำแหน่ง", "แสดงในแถบสถานะด้านล่าง", false, false, function(v) F.stats = v end)

section(miscPanel, miscAt(16), "อื่น ๆ", T.gold)
toggle(miscPanel, miscAt(52), "Anti-AFK", "กดปุ่มอัตโนมัติเมื่อเกมตรวจ Idled", false, false, function(v)
	F.antiAFK = v
	if v then notify("Anti-AFK เปิดใช้งานแล้ว", T.accent) end
end)
button(miscPanel, miscAt(36), "ตรวจระบบ (Diagnostics)", "ghost", false, function()
	for _, l in ipairs({
		"version   = " .. VERSION,
		"server    = " .. tostring(HAS_SERVER),
		"plots     = " .. #tagCache.plots,
		"enemies   = " .. #tagCache.enemies,
		"ores      = " .. #tagCache.ores,
		"fps       = " .. tostring(perf.fps),
		"fx rate   = " .. string.format("%.1f Hz", 1 / math.max(perf.fxInterval, 0.05)),
		"ping      = " .. tostring(getPing()) .. " ms",
	}) do
		print("[GardenProX] " .. l)
	end
	notify("Diagnostics → ดูที่ Output", T.accent2)
end)
local miscStatus = statusCard(miscPanel, miscAt(48), 2)

-- ===== COLLAPSE / HIDE =====
local pill

local function setVisible(v)
	root.Visible = v
	shadow.Visible = v
	toastBox.Visible = v
	perf.hidden = not v
	if pill then pill.Visible = not v end
end

collapseBtn.MouseButton1Click:Connect(function()
	perf.collapsed = not perf.collapsed
	local c = perf.collapsed
	TweenService:Create(root, TweenInfo.new(0.26, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Size = c and UDim2.fromOffset(T.W, T.headerH) or UDim2.fromOffset(T.W, T.H),
	}):Play()
	TweenService:Create(shadow, TweenInfo.new(0.26), {
		Size = c and UDim2.fromOffset(T.W + 14, T.headerH + 16) or UDim2.fromOffset(T.W + 14, T.H + 16),
	}):Play()
	tabsBar.Visible = not c
	content.Visible = not c
	footer.Visible = not c
	collapseBtn.Text = c and "+" or "–"
end)

hideBtn.MouseButton1Click:Connect(function() setVisible(false) end)

pill = new("TextButton", {
	Size = UDim2.fromOffset(38, 38),
	Position = UDim2.fromOffset(16, 16),
	BackgroundColor3 = T.card,
	AutoButtonColor = false,
	Font = T.bold,
	TextSize = 15,
	TextColor3 = T.accent,
	Text = "☰",
	Visible = false,
	ZIndex = 10,
}, gui)
corner(pill, 11)
stroke(pill, T.stroke, 1, 0.3)
new("UIGradient", { Color = ColorSequence.new(T.card, T.bgTop), Rotation = 90 }, pill)
pill.MouseButton1Click:Connect(function() setVisible(true) end)
pill.MouseEnter:Connect(function()
	TweenService:Create(pill, TweenInfo.new(0.12), { TextColor3 = T.text }):Play()
end)
pill.MouseLeave:Connect(function()
	TweenService:Create(pill, TweenInfo.new(0.12), { TextColor3 = T.accent }):Play()
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.RightShift then
		setVisible(not root.Visible)
	elseif input.KeyCode == Enum.KeyCode.F and biteUntil > os.clock() then
		biteUntil = 0
		reelRow.Visible = false
		fire("reel")
	end
end)

-- ===== รับข้อความจากเซิร์ฟเวอร์ =====
task.spawn(function()
	local hub = ReplicatedStorage:WaitForChild("HubNotify", 15)
	if not hub or not hub:IsA("RemoteEvent") then return end
	hub.OnClientEvent:Connect(function(data)
		if type(data) ~= "table" then return end
		local kind = data.kind
		if kind == "bite" then
			biteUntil = os.clock() + (tonumber(data.window) or 2.2)
			reelRow.Visible = true
			notify("ปลากัดเบ็ด! กด REEL / F", T.gold)
		elseif kind == "catch" or kind == "sold" or kind == "hatch" then
			biteUntil = 0
			reelRow.Visible = false
			notify(data.text or "สำเร็จ", T.accent)
		elseif kind == "miss" then
			biteUntil = 0
			reelRow.Visible = false
			notify(data.text or "พลาด", T.danger)
		elseif kind == "enchant" then
			local c = data.color
			local col = (type(c) == "table" and c[1] and c[2] and c[3])
				and Color3.fromRGB(c[1], c[2], c[3]) or T.violet
			notify(data.text or "", col)
		else
			notify(data.text or "", T.sub)
		end
	end)
end)

-- ===== FPS (ตัวนับเบา ๆ ตัวเดียว) =====
local frames, acc = 0, 0
RunService.Heartbeat:Connect(function(dt)
	frames = frames + 1
	acc = acc + dt
	if acc >= 1 then
		perf.fps = math.floor(frames / acc + 0.5)
		frames, acc = 0, 0
		perf.fxInterval = perf.fps < 30 and 0.6 or (perf.fps < 45 and 0.35 or 0.2)
	end
end)

-- ===== 3D FX (สร้างเมื่อเปิดใช้เท่านั้น + จำกัดระยะ) =====
local plotFX, enemyFX, oreFX = {}, {}, {}
local BILLBOARD_RANGE = 90

local function makeBillboard(adornee, width, offsetY)
	local bb = new("BillboardGui", {
		Size = UDim2.fromOffset(width, 28),
		StudsOffset = Vector3.new(0, offsetY, 0),
		AlwaysOnTop = true,
		MaxDistance = BILLBOARD_RANGE,
		Adornee = adornee,
		Enabled = true,
	}, gui)
	local holder = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = T.dark,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	}, bb)
	corner(holder, 8)
	local label = new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = T.bold,
		TextSize = 11,
		TextColor3 = T.text,
		Text = "",
	}, holder)
	return bb, holder, label
end

local function plotColor(state)
	if state == "ready" then return T.gold end
	if state == "growing" then return T.accent end
	return T.sub
end

local function ensurePlotFX(plot)
	local fx = plotFX[plot]
	if fx and fx.highlight.Parent then return fx end
	local d = plot:FindFirstChild("Dirt")
	if not d then return nil end
	local hl = new("Highlight", { Adornee = d, FillTransparency = 0.75, OutlineTransparency = 0.15 }, gui)
	local bb, holder, label = makeBillboard(d, 180, 3.5)
	stroke(holder, T.accent, 1, 0.45)
	fx = { highlight = hl, billboard = bb, holder = holder, label = label, state = nil, growth = -1, water = -1, enabled = true }
	plotFX[plot] = fx
	return fx
end

local function clearPlotFX(plot)
	local fx = plotFX[plot]
	if fx then
		fx.highlight:Destroy()
		fx.billboard:Destroy()
		plotFX[plot] = nil
	end
end

local function ensureEnemyFX(model)
	local fx = enemyFX[model]
	if fx and fx.billboard.Parent then return fx end
	local body = model:FindFirstChild("Body")
	if not body then return nil end
	local bb, holder, label = makeBillboard(body, 200, 3.6)
	label.TextColor3 = Color3.fromRGB(255, 186, 196)
	stroke(holder, T.danger, 1, 0.4)
	fx = { billboard = bb, holder = holder, label = label, hp = -1, max = -1, dist = -1 }
	enemyFX[model] = fx
	return fx
end

local function clearEnemyFX(model)
	local fx = enemyFX[model]
	if fx then
		fx.billboard:Destroy()
		enemyFX[model] = nil
	end
end

local function ensureOreFX(ore)
	local fx = oreFX[ore]
	if fx and fx.highlight.Parent then return fx end
	local hl = new("Highlight", {
		Adornee = ore,
		FillTransparency = 0.62,
		FillColor = ore.Color,
		OutlineColor = Color3.fromRGB(255, 255, 255),
	}, gui)
	local bb, holder, label = makeBillboard(ore, 190, 3)
	label.TextColor3 = Color3.fromRGB(255, 246, 214)
	stroke(holder, T.gold, 1, 0.35)
	fx = { highlight = hl, billboard = bb, holder = holder, label = label, sec = -1, dist = -1 }
	oreFX[ore] = fx
	return fx
end

local function clearOreFX(ore)
	local fx = oreFX[ore]
	if fx then
		fx.highlight:Destroy()
		fx.billboard:Destroy()
		oreFX[ore] = nil
	end
end

local function getOrigin()
	local char = LP.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	return hrp and hrp.Position or nil
end

task.spawn(function()
	while true do
		task.wait(perf.lowPower and 0.5 or perf.fxInterval)
		if root.Visible and not perf.collapsed and not perf.hidden then
			local wantFX = F.plotHL or F.enemyHP or F.reveal
			if wantFX then
				local origin = getOrigin()
				local now = Workspace:GetServerTimeNow()
				local cache = refreshTags(false)

				if F.plotHL then
					for _, plot in ipairs(cache.plots) do
						local fx = ensurePlotFX(plot)
						if fx then
							local state = tostring(plot:GetAttribute("State") or "empty")
							local growth = tonumber(plot:GetAttribute("Growth")) or 0
							local water = tonumber(plot:GetAttribute("Water")) or 0
							local pos = fx.billboard.Adornee and fx.billboard.Adornee.Position
							local d = (pos and origin) and (pos - origin).Magnitude or 0
							local visible = d <= BILLBOARD_RANGE
							if fx.enabled ~= visible then
								fx.enabled = visible
								fx.billboard.Enabled = visible
								fx.highlight.Enabled = visible
							end
							if fx.state ~= state then
								fx.state = state
								local c = plotColor(state)
								fx.highlight.FillColor = c
								fx.highlight.OutlineColor = c
								fx.holder.UIStroke.Color = c
							end
							if visible and (fx.growth ~= growth or fx.water ~= water) then
								fx.growth, fx.water = growth, water
								fx.label.Text = ("%s  •  โต %d%%  •  น้ำ %d%%"):format(string.upper(state), growth, water)
							end
						end
					end
				else
					for plot in pairs(plotFX) do clearPlotFX(plot) end
				end

				if F.enemyHP then
					for _, model in ipairs(cache.enemies) do
						local fx = ensureEnemyFX(model)
						local hum = model:FindFirstChildOfClass("Humanoid")
						if fx and hum then
							local body = model:FindFirstChild("Body")
							local d = (origin and body) and math.floor((body.Position - origin).Magnitude / 5 + 0.5) * 5 or 0
							local visible = d <= BILLBOARD_RANGE
							fx.billboard.Enabled = visible
							local hp, max = math.floor(hum.Health), math.floor(hum.MaxHealth)
							if visible and (fx.hp ~= hp or fx.max ~= max or fx.dist ~= d) then
								fx.hp, fx.max, fx.dist = hp, max, d
								fx.label.Text = ("%s  •  %d/%d HP  •  %d studs"):format(model.Name, hp, max, d)
							end
						end
					end
				else
					for model in pairs(enemyFX) do clearEnemyFX(model) end
				end

				if F.reveal then
					for _, ore in ipairs(cache.ores) do
						local untilAt = tonumber(ore:GetAttribute("RevealUntil")) or 0
						local rare = ore:GetAttribute("Rare") == true
						local remain = untilAt - now
						if rare and remain > 0 then
							local fx = ensureOreFX(ore)
							if fx then
								local d = origin and math.floor((ore.Position - origin).Magnitude) or 0
								local sec = math.ceil(remain)
								local visible = d <= BILLBOARD_RANGE
								fx.billboard.Enabled = visible
								if visible and (fx.sec ~= sec or fx.dist ~= d) then
									fx.sec, fx.dist = sec, d
									fx.label.Text = ("%s  •  %d studs  •  %ds"):format(ore.Name, d, sec)
								end
							end
						elseif oreFX[ore] then
							clearOreFX(ore)
						end
					end
				else
					for ore in pairs(oreFX) do clearOreFX(ore) end
				end
			end
		end
	end
end)

-- ===== UI refresh (ช้า ๆ พอ + เฉพาะแท็บที่เปิดอยู่) =====
local uiFrameCount = 0

task.spawn(function()
	while true do
		task.wait(perf.lowPower and 1 or 0.5)
		if root.Visible and not perf.hidden and not perf.collapsed then
			uiFrameCount = uiFrameCount + 1
			local cache = refreshTags(false)

			if farmPanel.Visible then
				local counts = { empty = 0, growing = 0, ready = 0 }
				for _, plot in ipairs(cache.plots) do
					local st = tostring(plot:GetAttribute("State") or "empty")
					if counts[st] ~= nil then counts[st] = counts[st] + 1 end
				end
				setLabel(farmStatus, ("แปลง  •  ว่าง %d    โต %d    พร้อม %d\nไม้ %d   หิน %d   เหรียญ %d"):format(
					counts.empty, counts.growing, counts.ready,
					statOf("Wood"), statOf("Stone"), statOf("Coins")))
			end

			if combatPanel.Visible then
				local crit = LP:GetAttribute("LastCrit") == true
				if F.critToast and crit and not lastCritShown then
					notify("คริ! ดาเมจ x2", T.accent)
				end
				lastCritShown = crit
				setLabel(combatStatus, ("คริทั้งหมด  %d ครั้ง   •   ล่าสุด %s\nดาเมจต่อตี 10   •   คริ 20"):format(
					LP:GetAttribute("CritCount") or 0, crit and "คริ ⚡" or "ปกติ"))
			end

			if cavePanel.Visible then
				setLabel(caveStatus, (F.audit and auditCollision() or "Collision Audit : ปิด")
					.. ("\nรัศมีสแกน %d studs   •   สถานะ %s"):format(getRadius(), F.reveal and "เปิด" or "ปิด"))
			end

			if reelRow and reelRow.Visible and os.clock() > biteUntil then
				reelRow.Visible = false
			end

			if fishPanel.Visible then
				setLabel(fishStatus, ("เหรียญ %d   •   ปลา %d ตัว\nสถานะ %s"):format(
					statOf("Coins"), statOf("Fish"),
					os.clock() <= biteUntil and "ปลากัดเบ็ด! กด REEL / F" or "พร้อมเหวี่ยงเบ็ด"))
			end

			if petPanel.Visible then
				setLabel(petStatus, ("สัตว์เลี้ยง  %s %s   •   พลัง %d\nเหรียญ %d   •   ฟักไข่ 50"):format(
					LP:GetAttribute("PetEmoji") or "—",
					LP:GetAttribute("PetName") or "ยังไม่มี",
					LP:GetAttribute("PetPower") or 0,
					statOf("Coins")))
			end

			if miscPanel.Visible and econStatus then
				setLabel(econStatus, ("Enchant  %s   •   เหรียญ %d"):format(
					LP:GetAttribute("Enchant") or "None", statOf("Coins")))
			end

			if miscPanel.Visible then
				local mins = math.floor((os.clock() - startedAt) / 60)
				local text
				if F.stats then
					local char = LP.Character
					local pos = char and char:GetPivot().Position or Vector3.zero
					text = ("FPS %d   •   ping %d ms   •   X %d  Z %d\nเปิดมา %d นาที   •   Anti-AFK %d ครั้ง"):format(
						perf.fps, getPing(), math.floor(pos.X), math.floor(pos.Z), mins, afkClicks)
				else
					text = ("โหมด %s   •   เปิดมา %d นาที   •   Anti-AFK %d ครั้ง"):format(
						HAS_SERVER and "SERVER" or "CLIENT", mins, afkClicks)
				end
				setLabel(miscStatus, text)
				setLabel(hintLabel, F.stats
					and ("FX %.0f Hz  •  UI 2 Hz  •  ธีม v%s"):format(1 / math.max(perf.fxInterval, 0.05), VERSION)
					or DEFAULT_HINT)
			end
		end
	end
end)

-- ===== auto sell (ตัวจับเวลาเบา ๆ) =====
task.spawn(function()
	while true do
		task.wait(5)
		if F.autoSell and not perf.hidden then fire("sell") end
	end
end)

-- ===== anti-afk =====
LP.Idled:Connect(function()
	if not F.antiAFK then return end
	afkClicks = afkClicks + 1
	pcall(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton1(Vector2.new(960, 540))
	end)
end)

-- ===== scale =====
local function fit()
	local cam = Workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local s = math.min(vp.X / (T.W + 40), vp.Y / (T.H + 40), 1)
	scale.Scale = math.clamp(s, 0.55, 1)
end
fit()
if Workspace.CurrentCamera then
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
end

-- ===== API / SELF-TEST =====
local function repairUI()
	if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
	root.Visible = true
	shadow.Visible = true
	perf.hidden = false
	pill.Visible = false
end

_G.GardenProX = {
	Version = VERSION,
	HasServer = HAS_SERVER,
	Toggle = function() setVisible(not root.Visible) end,
	RepairUI = repairUI,
	Destroy = function() gui:Destroy() end,
}

selectTab(1)

local checks = {
	{ "UI ครบ 6 แท็บ", #tabPanels == 6 },
	{ "แถบคำอธิบาย (hint bar)", hintLabel ~= nil },
	{ "แคช tag", type(refreshTags) == "function" },
	{ "บายพาสเฉพาะค่าเปลี่ยน (setLabel)", type(setLabel) == "function" },
	{ "โหมดเซิร์ฟเวอร์ตรวจแล้ว", HAS_SERVER == true or HAS_SERVER == false },
	{ "ฟังก์ชันซ่อม UI", type(repairUI) == "function" },
	{ "ตัวนับ FPS ตั้งต้น", perf.fps > 0 and perf.fxInterval > 0 },
}
local pass = 0
for _, c in ipairs(checks) do
	if c[2] then pass = pass + 1 end
	print(("[GardenProX] %s %s"):format(c[2] and "PASS" or "FAIL", c[1]))
end
print(("[GardenProX] self-test %d/%d ผ่าน"):format(pass, #checks))
print(("[GardenProX] v%s • %s • FX %.1f Hz"):format(
	VERSION, HAS_SERVER and "SERVER LINK" or "CLIENT ONLY", 1 / perf.fxInterval))
notify(HAS_SERVER and ("SERVER LINK • v" .. VERSION) or ("CLIENT ONLY • v" .. VERSION), HAS_SERVER and T.accent or T.gold)
