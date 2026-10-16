-- All player-facing UI, built in code: cash HUD, luck timer, rebirth bar, shop, rebirth,
-- codes, Slime Index, toasts and the event banner.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
for _, name in { "Notify", "Rebirth", "Banner", "RedeemCode", "ClaimDaily", "BuyGear", "ClaimGift", "ClaimQuest" } do
	Remotes:WaitForChild(name)
end

local player = Players.LocalPlayer

local COLORS = {
	bg = Color3.fromRGB(28, 20, 48),
	bg2 = Color3.fromRGB(55, 35, 95),
	panel = Color3.fromRGB(48, 36, 80),
	accent = Color3.fromRGB(120, 255, 160),
	gold = Color3.fromRGB(255, 205, 60),
	pink = Color3.fromRGB(255, 100, 170),
	purple = Color3.fromRGB(190, 120, 255),
	blue = Color3.fromRGB(90, 180, 255),
	bad = Color3.fromRGB(255, 90, 100),
	text = Color3.new(1, 1, 1),
	muted = Color3.fromRGB(200, 190, 230),
	outline = Color3.fromRGB(20, 10, 35),
}
local KIND_COLOR = {
	info = COLORS.text,
	good = COLORS.accent,
	bad = COLORS.bad,
	epic = COLORS.gold,
}
local FONT = Enum.Font.FredokaOne

local function new(className: string, props, children)
	local inst = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	for _, c in children or {} do
		c.Parent = inst
	end
	inst.Parent = props.Parent
	return inst
end

local function corner(r)
	return new("UICorner", { CornerRadius = UDim.new(0, r or 12) })
end

local function stroke(color, th)
	return new("UIStroke", { Color = color or COLORS.outline, Thickness = th or 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function gradient(top: Color3, bottom: Color3)
	return new("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = 90 })
end

local function text(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or FONT
	props.TextColor3 = props.TextColor3 or COLORS.text
	props.TextScaled = if props.TextScaled == nil then true else props.TextScaled
	local label = new("TextLabel", props)
	if props.TextStrokeTransparency == nil then
		new("UIStroke", { Color = COLORS.outline, Thickness = 2, Parent = label })
	end
	return label
end

local function click()
	local s = Instance.new("Sound")
	s.SoundId = Config.Sounds.Click
	s.Volume = 0.5
	s.Parent = SoundService
	s:Play()
	task.delay(1, s.Destroy, s)
end

-- Chunky gradient button that grows on hover and squishes on click.
local function button(props, onClick)
	local color = props.BackgroundColor3 or COLORS.accent
	props.BackgroundColor3 = Color3.new(1, 1, 1)
	props.Font = props.Font or FONT
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	props.TextScaled = true
	props.AutoButtonColor = false
	local b = new("TextButton", props, {
		corner(12),
		stroke(COLORS.outline, 3),
		gradient(color:Lerp(Color3.new(1, 1, 1), 0.25), color:Lerp(Color3.new(0, 0, 0), 0.2)),
		new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }),
	})
	-- UIGradient tints a button's own text too (white text on a gradient
	-- vanishes), so the label lives in a child TextLabel that mirrors b.Text.
	local label = text({ Size = UDim2.fromScale(1, 1), Text = b.Text, TextColor3 = props.TextColor3, Font = props.Font, ZIndex = b.ZIndex, Parent = b })
	b.TextTransparency = 1
	b:GetPropertyChangedSignal("Text"):Connect(function()
		label.Text = b.Text
	end)
	local scale = new("UIScale", { Parent = b })
	b.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.07 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	b.Activated:Connect(function()
		click()
		scale.Scale = 0.88
		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		onClick()
	end)
	return b
end

local gui = new("ScreenGui", {
	Name = "Hud",
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

-- ===== Cash bar =====
local top = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 8),
	Size = UDim2.fromOffset(320, 84),
	BackgroundColor3 = Color3.new(1, 1, 1),
	Parent = gui,
}, { corner(18), stroke(COLORS.outline, 4), gradient(COLORS.bg2, COLORS.bg) })
local topScale = new("UIScale", { Parent = top })
local cashLabel = text({ Size = UDim2.new(1, -20, 0, 44), Position = UDim2.fromOffset(10, 4), TextColor3 = COLORS.accent, Text = "$0", Parent = top })
local incomeLabel = text({ Size = UDim2.new(1, -20, 0, 20), Position = UDim2.fromOffset(10, 48), TextColor3 = COLORS.muted, Text = "+$0/s", Parent = top })
-- Rebirth progress bar along the bottom of the cash bar.
local barBack = new("Frame", { Position = UDim2.new(0, 14, 1, -14), Size = UDim2.new(1, -28, 0, 8), BackgroundColor3 = Color3.fromRGB(20, 12, 35), Parent = top }, { corner(4) })
local barFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = barBack }, { corner(4), gradient(COLORS.purple, COLORS.pink) })

local chips = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 98),
	Size = UDim2.fromOffset(600, 68),
	BackgroundTransparency = 1,
	Parent = gui,
}, { new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8), Wraps = true }) })
local function chip(color: Color3)
	local f = new("Frame", { Size = UDim2.fromOffset(190, 30), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false, Parent = chips }, { corner(15), stroke(COLORS.outline, 3), gradient(color, color:Lerp(Color3.new(0, 0, 0), 0.3)) })
	local l = text({ Size = UDim2.new(1, -12, 1, -6), Position = UDim2.fromOffset(6, 3), Text = "", Parent = f })
	return f, l
end
local luckChip, luckLabel = chip(Color3.fromRGB(60, 200, 90))
local shieldChip, shieldLabel = chip(Color3.fromRGB(230, 60, 80))
local carryChip, carryLabel = chip(Color3.fromRGB(255, 170, 30))
local rainChip, rainLabel = chip(Color3.fromRGB(70, 150, 255))
local eventChip, eventLabel = chip(Color3.fromRGB(255, 150, 40))
local boostChip, boostLabel = chip(Color3.fromRGB(255, 120, 200))

-- ===== Banner (Slime Rain) =====
local banner = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 172),
	Size = UDim2.new(0.9, 0, 0, 48),
	BackgroundColor3 = Color3.new(1, 1, 1),
	Visible = false,
	Parent = gui,
}, { corner(14), stroke(COLORS.outline, 4), gradient(Color3.fromRGB(90, 230, 150), Color3.fromRGB(40, 150, 220)), new("UISizeConstraint", { MaxSize = Vector2.new(560, 48) }) })
local bannerText = text({ Size = UDim2.new(1, -16, 1, -8), Position = UDim2.fromOffset(8, 4), Text = "", Parent = banner })

-- ===== Toasts =====
local toastHolder = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -110),
	Size = UDim2.new(0.9, 0, 0, 220),
	BackgroundTransparency = 1,
	Parent = gui,
}, {
	new("UISizeConstraint", { MaxSize = Vector2.new(480, 220) }),
	new("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local toastCount = 0
local function toast(msg: string, kind: string?)
	toastCount += 1
	local f = new("Frame", {
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = COLORS.bg,
		BackgroundTransparency = 0.1,
		LayoutOrder = toastCount,
		Parent = toastHolder,
	}, { corner(12), new("UIStroke", { Color = KIND_COLOR[kind or "info"] or COLORS.text, Thickness = 2, Transparency = 0.3 }) })
	local scale = new("UIScale", { Scale = 0.6, Parent = f })
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	text({ Size = UDim2.new(1, -16, 1, -8), Position = UDim2.fromOffset(8, 4), TextColor3 = KIND_COLOR[kind or "info"] or COLORS.text, Text = msg, Parent = f })
	local frames = {}
	for _, c in toastHolder:GetChildren() do
		if c:IsA("Frame") then
			table.insert(frames, c)
		end
	end
	if #frames > 5 then
		frames[1]:Destroy()
	end
	task.delay(4.5, function()
		if f.Parent then
			TweenService:Create(scale, TweenInfo.new(0.2), { Scale = 0 }):Play()
			task.wait(0.2)
			f:Destroy()
		end
	end)
end

-- ===== Panels =====
local panels = {}
local function panel(title: string, color: Color3)
	local p = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.92, 0.8),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
		Parent = gui,
	}, { corner(20), stroke(COLORS.outline, 5), gradient(COLORS.bg2, COLORS.bg), new("UISizeConstraint", { MaxSize = Vector2.new(500, 460) }) })
	local header = new("Frame", { Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = Color3.new(1, 1, 1), Parent = p }, { corner(20), gradient(color, color:Lerp(Color3.new(0, 0, 0), 0.3)) })
	text({ Size = UDim2.new(1, -70, 0, 38), Position = UDim2.fromOffset(16, 7), TextXAlignment = Enum.TextXAlignment.Left, Text = title, Parent = header })
	button({ Size = UDim2.fromOffset(40, 40), Position = UDim2.new(1, -48, 0, 6), BackgroundColor3 = COLORS.bad, Text = "X", Parent = p }, function()
		p.Visible = false
	end)
	local scale = new("UIScale", { Parent = p })
	table.insert(panels, p)
	return p, scale
end

local function openPanel(p: Frame, scale: UIScale)
	local wasOpen = p.Visible
	for _, other in panels do
		other.Visible = false
	end
	if wasOpen then
		return
	end
	p.Visible = true
	scale.Scale = 0.7
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

local function scroller(parent: Frame, layout: Instance)
	return new("ScrollingFrame", {
		Position = UDim2.fromOffset(12, 62),
		Size = UDim2.new(1, -24, 1, -74),
		BackgroundTransparency = 1,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = parent,
	}, { layout })
end

-- Shop
local shop, shopScale = panel("🛒 Shop", COLORS.gold)
local list = scroller(shop, new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }))

local function shopRow(order: number, item, isPass: boolean)
	local row = new("Frame", { Size = UDim2.new(1, -8, 0, 70), BackgroundColor3 = COLORS.panel, LayoutOrder = order, Parent = list }, { corner(12), new("UIStroke", { Color = if isPass then COLORS.gold else COLORS.blue, Thickness = 2, Transparency = 0.4 }) })
	text({ Size = UDim2.new(0.66, -10, 0, 28), Position = UDim2.fromOffset(12, 6), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = if isPass then COLORS.gold else COLORS.text, Text = (if isPass then "⭐ " else "") .. item.name, Parent = row })
	text({ Size = UDim2.new(0.66, -10, 0, 28), Position = UDim2.fromOffset(12, 36), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = COLORS.muted, Font = Enum.Font.GothamMedium, TextStrokeTransparency = 1, Text = item.desc, Parent = row })
	local label = if item.id == 0 then "Soon" else ("R$ " .. item.price)
	button({ Size = UDim2.new(0.3, -8, 0, 48), Position = UDim2.new(0.7, 0, 0, 11), BackgroundColor3 = if item.id == 0 then Color3.fromRGB(120, 110, 140) else COLORS.accent, Text = label, Parent = row }, function()
		if item.id == 0 then
			toast("This item isn't set up yet (add its ID in Config).", "bad")
		elseif isPass then
			MarketplaceService:PromptGamePassPurchase(player, item.id)
		else
			MarketplaceService:PromptProductPurchase(player, item.id)
		end
	end)
end

local order = 0
for _, k in { "DoubleCash", "VIP", "ExtraPens", "AutoCollect" } do
	order += 1
	shopRow(order, Config.GamePasses[k], true)
end
for _, k in { "Luck", "SmallCash", "BigCash", "HugeCash", "InstantLock", "GrowBoost", "SlimeRain" } do
	order += 1
	shopRow(order, Config.Products[k], false)
end

-- Rebirth
local rebirth, rebirthScale = panel("🔄 Rebirth", COLORS.purple)
local rebirthInfo = text({
	Position = UDim2.fromOffset(20, 70),
	Size = UDim2.new(1, -40, 1, -170),
	TextScaled = false,
	TextSize = 22,
	TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top,
	Font = Enum.Font.GothamBold,
	TextStrokeTransparency = 1,
	Text = "",
	Parent = rebirth,
})
button({ Size = UDim2.new(1, -40, 0, 64), Position = UDim2.new(0, 20, 1, -84), BackgroundColor3 = COLORS.purple, Text = "REBIRTH!", Parent = rebirth }, function()
	Remotes.Rebirth:FireServer()
	rebirth.Visible = false
end)

-- Codes
local codes, codesScale = panel("🎟️ Codes", COLORS.blue)
text({ Position = UDim2.fromOffset(20, 72), Size = UDim2.new(1, -40, 0, 28), Font = Enum.Font.GothamBold, TextStrokeTransparency = 1, TextColor3 = COLORS.muted, Text = "Got a code? Type it here for free rewards!", Parent = codes })
local codeBox = new("TextBox", {
	Position = UDim2.fromOffset(20, 112),
	Size = UDim2.new(1, -40, 0, 56),
	BackgroundColor3 = Color3.fromRGB(20, 12, 35),
	Font = FONT,
	PlaceholderText = "Enter code...",
	PlaceholderColor3 = Color3.fromRGB(130, 120, 160),
	Text = "",
	TextColor3 = COLORS.text,
	TextScaled = true,
	ClearTextOnFocus = false,
	Parent = codes,
}, { corner(12), stroke(COLORS.blue, 3), new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }) })
local codeResult = text({ Position = UDim2.fromOffset(20, 252), Size = UDim2.new(1, -40, 0, 30), Text = "", Parent = codes })
local redeeming = false
button({ Size = UDim2.new(1, -40, 0, 58), Position = UDim2.fromOffset(20, 182), BackgroundColor3 = COLORS.accent, Text = "REDEEM", Parent = codes }, function()
	if redeeming or codeBox.Text == "" then
		return
	end
	redeeming = true
	local ok, okResult, msg = pcall(function()
		return Remotes.RedeemCode:InvokeServer(codeBox.Text)
	end)
	redeeming = false
	if not ok then
		codeResult.Text = "Couldn't reach the server, try again."
		codeResult.TextColor3 = COLORS.bad
		return
	end
	codeResult.Text = msg or ""
	codeResult.TextColor3 = if okResult then COLORS.accent else COLORS.bad
	if okResult then
		codeBox.Text = ""
	end
end)
text({ Position = UDim2.new(0, 20, 1, -44), Size = UDim2.new(1, -40, 0, 24), Font = Enum.Font.GothamBold, TextStrokeTransparency = 1, TextColor3 = COLORS.muted, Text = "New codes drop with every update. Like the game to get more!", Parent = codes })

-- Slime Index
local index, indexScale = panel("📖 Slime Index", COLORS.pink)
local indexHeader = text({ Position = UDim2.fromOffset(16, 60), Size = UDim2.new(1, -32, 0, 26), Font = Enum.Font.GothamBold, TextStrokeTransparency = 1, TextColor3 = COLORS.muted, Text = "", Parent = index })
local grid = new("ScrollingFrame", {
	Position = UDim2.fromOffset(12, 92),
	Size = UDim2.new(1, -24, 1, -104),
	BackgroundTransparency = 1,
	ScrollBarThickness = 6,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	Parent = index,
}, { new("UIGridLayout", { CellSize = UDim2.fromOffset(104, 92), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
local cards = {}
for _, s in Config.Slimes do
	local r = Config.RarityByName[s.rarity]
	local card = new("Frame", { BackgroundColor3 = COLORS.panel, LayoutOrder = s.order, Parent = grid }, { corner(12), new("UIStroke", { Color = r.color, Thickness = 2 }) })
	local blob = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(42, 36), BackgroundColor3 = s.color, Parent = card }, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }), stroke(COLORS.outline, 2) })
	local nameL = text({ Position = UDim2.fromOffset(4, 48), Size = UDim2.new(1, -8, 0, 20), Text = s.id, Parent = card })
	local rarL = text({ Position = UDim2.fromOffset(4, 68), Size = UDim2.new(1, -8, 0, 16), Font = Enum.Font.GothamBold, TextColor3 = r.color, TextStrokeTransparency = 1, Text = s.rarity, Parent = card })
	cards[s.id] = { blob = blob, name = nameL, rarity = rarL, def = s }
end

local function refreshIndex()
	local found = {}
	for id in string.gmatch(player:GetAttribute("IndexList") or "", "[^,]+") do
		found[id] = true
	end
	local n = 0
	for id, c in cards do
		local got = found[id] == true
		if got then
			n += 1
		end
		c.blob.BackgroundColor3 = if got then c.def.color else Color3.fromRGB(30, 25, 45)
		c.name.Text = if got then id else "???"
	end
	indexHeader.Text = string.format("Discovered %d / %d  ·  +%d%% income bonus", n, #Config.Slimes, math.floor(n * Config.IndexBonusPerSlime * 100))
end
player:GetAttributeChangedSignal("IndexList"):Connect(refreshIndex)
refreshIndex()

-- Daily rewards
local daily, dailyScale = panel("📅 Daily Rewards", Color3.fromRGB(255, 140, 60))
local dailyInfo = text({ Position = UDim2.fromOffset(16, 60), Size = UDim2.new(1, -32, 0, 26), Font = Enum.Font.GothamBold, TextStrokeTransparency = 1, TextColor3 = COLORS.muted, Text = "", Parent = daily })
local dayGrid = new("Frame", { Position = UDim2.fromOffset(12, 94), Size = UDim2.new(1, -24, 1, -186), BackgroundTransparency = 1, Parent = daily }, {
	new("UIGridLayout", { CellSize = UDim2.new(0.25, -8, 0.5, -8), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }),
})
local dayCards = {}
for i, r in Config.DailyRewards do
	local card = new("Frame", { BackgroundColor3 = COLORS.panel, LayoutOrder = i, Parent = dayGrid }, { corner(12) })
	local st = new("UIStroke", { Color = COLORS.muted, Thickness = 2, Parent = card })
	text({ Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 0.3, 0), Text = "DAY " .. i, TextColor3 = if i == 7 then COLORS.gold else COLORS.text, Parent = card })
	text({ Position = UDim2.new(0, 4, 0.32, 0), Size = UDim2.new(1, -8, 0.32, 0), Text = if r.slime then "🌟" elseif r.luckMinutes then "🍀" elseif r.grow then "🌱" else "💰", Parent = card })
	text({ Position = UDim2.new(0, 4, 0.66, 0), Size = UDim2.new(1, -8, 0.3, 0), Font = Enum.Font.GothamBold, TextStrokeTransparency = 1, TextColor3 = COLORS.muted, Text = r.label, Parent = card })
	dayCards[i] = { card = card, stroke = st }
end
local claimBtn = button({ Size = UDim2.new(1, -40, 0, 64), Position = UDim2.new(0, 20, 1, -84), BackgroundColor3 = Color3.fromRGB(255, 140, 60), Text = "CLAIM!", Parent = daily }, function()
	if player:GetAttribute("DailyClaimable") then
		Remotes.ClaimDaily:FireServer()
	end
end)

-- Gear shop (cash)
local gear, gearScale = panel("⚔️ Gear", Color3.fromRGB(90, 200, 255))
local gearList = scroller(gear, new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }))
local gearButtons = {}
for i, key in Config.GearOrder do
	local def = Config.Gear[key]
	local row = new("Frame", { Size = UDim2.new(1, -8, 0, 70), BackgroundColor3 = COLORS.panel, LayoutOrder = i, Parent = gearList }, { corner(12), new("UIStroke", { Color = def.color, Thickness = 2, Transparency = 0.3 }) })
	text({ Size = UDim2.new(0.66, -10, 0, 28), Position = UDim2.fromOffset(12, 6), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = def.color, Text = def.name, Parent = row })
	text({ Size = UDim2.new(0.66, -10, 0, 28), Position = UDim2.fromOffset(12, 36), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = COLORS.muted, Font = Enum.Font.GothamMedium, TextStrokeTransparency = 1, Text = def.desc, Parent = row })
	gearButtons[key] = button({ Size = UDim2.new(0.3, -8, 0, 48), Position = UDim2.new(0.7, 0, 0, 11), BackgroundColor3 = COLORS.accent, Text = Util.Money(def.price), Parent = row }, function()
		Remotes.BuyGear:FireServer(key)
	end)
end
local function refreshGear()
	local owned = {}
	for k in string.gmatch(player:GetAttribute("GearOwned") or "", "[^,]+") do
		owned[k] = true
	end
	local rebirths = player:GetAttribute("Rebirths") or 0
	for key, b in gearButtons do
		local def = Config.Gear[key]
		b.Text = if owned[key] then "OWNED" elseif rebirths < def.rebirth then "🔒 Rebirth " .. def.rebirth else Util.Money(def.price)
	end
end
player:GetAttributeChangedSignal("GearOwned"):Connect(refreshGear)
player:GetAttributeChangedSignal("Rebirths"):Connect(refreshGear)
refreshGear()

-- Daily quests
local quests, questsScale = panel("📜 Daily Quests", Color3.fromRGB(120, 230, 120))
local questInfo = text({ Position = UDim2.fromOffset(16, 60), Size = UDim2.new(1, -32, 0, 26), Font = Enum.Font.GothamBold, TextStrokeTransparency = 1, TextColor3 = COLORS.muted, Text = "", Parent = quests })
local questRows = {}
for i = 1, Config.QuestsPerDay do
	local row = new("Frame", { Position = UDim2.fromOffset(12, 94 + (i - 1) * 96), Size = UDim2.new(1, -24, 0, 86), BackgroundColor3 = COLORS.panel, Parent = quests }, { corner(12) })
	local title = text({ Position = UDim2.fromOffset(12, 6), Size = UDim2.new(0.66, -12, 0, 30), TextXAlignment = Enum.TextXAlignment.Left, Text = "", Parent = row })
	local barBg = new("Frame", { Position = UDim2.fromOffset(12, 46), Size = UDim2.new(0.66, -12, 0, 22), BackgroundColor3 = Color3.fromRGB(20, 12, 35), Parent = row }, { corner(8) })
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = barBg }, { corner(8), gradient(COLORS.accent, Color3.fromRGB(40, 170, 90)) })
	local count = text({ Size = UDim2.fromScale(1, 1), Text = "", Parent = barBg })
	local b = button({ Size = UDim2.new(0.3, -8, 0, 56), Position = UDim2.new(0.7, 0, 0, 15), BackgroundColor3 = COLORS.accent, Text = "CLAIM", Parent = row }, function()
		Remotes.ClaimQuest:FireServer(i)
	end)
	questRows[i] = { title = title, fill = fill, count = count, button = b }
end
text({ Position = UDim2.new(0, 16, 1, -44), Size = UDim2.new(1, -32, 0, 26), Font = Enum.Font.GothamBold, TextStrokeTransparency = 1, TextColor3 = COLORS.gold, Text = "Finish all 3 for a BONUS: big cash + 15 min 5x Luck!", Parent = quests })
local questsReady = 0
local function refreshQuests()
	local ok, list = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute("Quests") or "[]")
	end)
	if not ok then
		return
	end
	questsReady = 0
	for i, r in questRows do
		local q = list[i]
		r.title.Parent.Visible = q ~= nil
		if q then
			r.title.Text = q.text
			r.fill.Size = UDim2.fromScale(math.clamp(q.progress / q.goal, 0, 1), 1)
			r.count.Text = if q.money then Util.Money(q.progress) .. " / " .. Util.Money(q.goal) else q.progress .. " / " .. q.goal
			local done = q.progress >= q.goal
			r.button.Text = if q.claimed then "✅ DONE" elseif done then "CLAIM!" else "..."
			if done and not q.claimed then
				questsReady += 1
			end
		end
	end
end
player:GetAttributeChangedSignal("Quests"):Connect(refreshQuests)
refreshQuests()

-- Playtime gifts
local gifts, giftsScale = panel("🎁 Playtime Gifts", COLORS.pink)
text({ Position = UDim2.fromOffset(16, 60), Size = UDim2.new(1, -32, 0, 26), Font = Enum.Font.GothamBold, TextStrokeTransparency = 1, TextColor3 = COLORS.muted, Text = "Keep playing to unlock gifts! Tap one when it's ready.", Parent = gifts })
local giftGrid = new("Frame", { Position = UDim2.fromOffset(12, 94), Size = UDim2.new(1, -24, 1, -106), BackgroundTransparency = 1, Parent = gifts }, {
	new("UIGridLayout", { CellSize = UDim2.new(0.25, -8, 0.5, -8), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }),
})
local giftCards = {}
for i, g in Config.PlaytimeGifts do
	local b = button({ BackgroundColor3 = COLORS.pink, Text = "", LayoutOrder = i, Parent = giftGrid }, function()
		Remotes.ClaimGift:FireServer(i)
	end)
	local icon = text({ Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, 0.45), Text = "🎁", Parent = b })
	local label = text({ Position = UDim2.fromScale(0, 0.45), Size = UDim2.fromScale(1, 0.25), Text = g.label, Parent = b })
	local timer = text({ Position = UDim2.fromScale(0, 0.72), Size = UDim2.fromScale(1, 0.26), Text = "", TextColor3 = COLORS.gold, Parent = b })
	giftCards[i] = { button = b, icon = icon, label = label, timer = timer }
end
local giftsReady = 0
local function refreshGifts()
	local done = {}
	for k in string.gmatch(player:GetAttribute("GiftsClaimed") or "", "[^,]+") do
		done[tonumber(k) or 0] = true
	end
	local elapsed = workspace:GetServerTimeNow() - (player:GetAttribute("GiftStart") or workspace:GetServerTimeNow())
	giftsReady = 0
	for i, g in Config.PlaytimeGifts do
		local c = giftCards[i]
		local left = g.minutes * 60 - elapsed
		if done[i] then
			c.icon.Text = "✅"
			c.timer.Text = "Opened"
		elseif left <= 0 then
			c.icon.Text = "🎁"
			c.timer.Text = "OPEN!"
			giftsReady += 1
		else
			c.icon.Text = "🔒"
			c.timer.Text = Util.Duration(left)
		end
	end
end

-- ===== Side buttons =====
local side = new("Frame", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 10, 0.5, 0),
	Size = UDim2.fromOffset(208, 284),
	BackgroundTransparency = 1,
	Parent = gui,
}, { new("UIGridLayout", { CellSize = UDim2.fromOffset(100, 62), CellPadding = UDim2.fromOffset(8, 10), SortOrder = Enum.SortOrder.LayoutOrder }) })
-- Shrink the side buttons on short screens so they never hit Roblox's top-left menu.
local sideScale = new("UIScale", { Parent = side })
local function fitSide()
	local h = workspace.CurrentCamera.ViewportSize.Y
	sideScale.Scale = math.clamp((h - 150) / 284, 0.5, 1)
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitSide)
fitSide()
local function sideButton(order: number, color: Color3, label: string, p: Frame, scale: UIScale)
	return button({ BackgroundColor3 = color, Text = label, LayoutOrder = order, Parent = side }, function()
		openPanel(p, scale)
	end)
end
local function makeBadge(parent: GuiObject)
	local b = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(26, 26), BackgroundColor3 = COLORS.bad, Visible = false, ZIndex = 3, Parent = parent }, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }), stroke(COLORS.outline, 2) })
	text({ Size = UDim2.fromScale(1, 1), Text = "!", ZIndex = 3, Parent = b })
	return b
end
local shopBtn = sideButton(1, COLORS.gold, "🛒 SHOP", shop, shopScale)
sideButton(2, Color3.fromRGB(90, 200, 255), "⚔️ GEAR", gear, gearScale)
local questsBtn = sideButton(3, Color3.fromRGB(120, 230, 120), "📜 QUESTS", quests, questsScale)
local giftsBtn = sideButton(4, COLORS.pink, "🎁 GIFTS", gifts, giftsScale)
sideButton(5, COLORS.purple, "🔄 REBIRTH", rebirth, rebirthScale)
sideButton(6, COLORS.blue, "🎟️ CODES", codes, codesScale)
sideButton(7, Color3.fromRGB(255, 120, 200), "📖 INDEX", index, indexScale)
local dailyBtn = sideButton(8, Color3.fromRGB(255, 140, 60), "📅 DAILY", daily, dailyScale)
local badge = makeBadge(dailyBtn)
local questBadge = makeBadge(questsBtn)
local giftBadge = makeBadge(giftsBtn)
task.spawn(function()
	while true do
		refreshGifts()
		giftBadge.Visible = giftsReady > 0
		questBadge.Visible = questsReady > 0
		local reset = (player:GetAttribute("QuestReset") or 0) - workspace:GetServerTimeNow()
		questInfo.Text = "New quests in " .. Util.Duration(math.max(reset, 0))
		task.wait(1)
	end
end)

local function refreshDaily()
	local day = player:GetAttribute("DailyDay") or 1
	local claimable = player:GetAttribute("DailyClaimable") == true
	badge.Visible = claimable
	for i, c in dayCards do
		local done = i < day or (i == day and not claimable)
		local isToday = i == day and claimable
		c.stroke.Color = if isToday then COLORS.gold elseif done then COLORS.accent else COLORS.muted
		c.stroke.Thickness = if isToday then 4 else 2
		c.card.BackgroundColor3 = if done then Color3.fromRGB(40, 90, 70) else COLORS.panel
	end
	claimBtn.Text = if claimable then "CLAIM DAY " .. day .. "!" else "COME BACK TOMORROW"
end
player:GetAttributeChangedSignal("DailyDay"):Connect(refreshDaily)
player:GetAttributeChangedSignal("DailyClaimable"):Connect(refreshDaily)
refreshDaily()
task.spawn(function()
	while true do
		local left = (player:GetAttribute("DailyResetAt") or 0) - workspace:GetServerTimeNow()
		dailyInfo.Text = if player:GetAttribute("DailyClaimable") then "Log in every day! Missing a day restarts the streak." else "Next reward in " .. Util.Duration(left)
		task.wait(1)
	end
end)
-- Pop the calendar open when there's a reward waiting.
task.delay(2.5, function()
	if player:GetAttribute("DailyClaimable") then
		openPanel(daily, dailyScale)
	end
end)
-- The shop button gently pulses to draw the eye.
task.spawn(function()
	local s = shopBtn:FindFirstChildOfClass("UIScale")
	while true do
		task.wait(4)
		if s and not shop.Visible then
			TweenService:Create(s, TweenInfo.new(0.18), { Scale = 1.12 }):Play()
			task.wait(0.18)
			TweenService:Create(s, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
	end
end)

-- ===== Live values =====
local lastCash = player:GetAttribute("Cash") or 0
local function refresh()
	local cash = player:GetAttribute("Cash") or 0
	local income = player:GetAttribute("Income") or 0
	local rebirths = player:GetAttribute("Rebirths") or 0
	local cost = player:GetAttribute("RebirthCost") or 1
	local slots = player:GetAttribute("Slots") or 0
	local count = player:GetAttribute("SlimeCount") or 0
	local bank = player:GetAttribute("Bank") or 0
	cashLabel.Text = Util.Money(cash)
	local extra = if bank >= 1 then "  ·  " .. Util.Money(bank) .. " at your pad" else ""
	incomeLabel.Text = "+" .. Util.Money(income) .. "/s  ·  Pens " .. count .. "/" .. slots .. extra
	barFill.Size = UDim2.fromScale(math.clamp(cash / cost, 0, 1), 1)
	rebirthInfo.Text = string.format(
		"Rebirth %d → %d\n\nCost: %s\nYou have: %s\n\n✅ Keep: +%d%% income forever, +%d pen slots, your Slime Index\n❌ Lose: cash and slimes",
		rebirths,
		rebirths + 1,
		Util.Money(cost),
		Util.Money(cash),
		math.floor(Config.RebirthIncomeBonus * 100 * (rebirths + 1)),
		Config.SlotsPerRebirth
	)
	-- Punch the cash bar on big gains.
	if cash > lastCash and cash - lastCash > math.max(income * 2, 10) then
		topScale.Scale = 1.12
		TweenService:Create(topScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	lastCash = cash
end
for _, attr in { "Cash", "Income", "Rebirths", "RebirthCost", "Slots", "SlimeCount", "Bank" } do
	player:GetAttributeChangedSignal(attr):Connect(refresh)
end
refresh()

local rainEndsAt = 0
local rainMsg = ""
task.spawn(function()
	while true do
		task.wait(0.25)
		local nowT = workspace:GetServerTimeNow()
		local luckLeft = (player:GetAttribute("LuckUntil") or 0) - nowT
		luckChip.Visible = luckLeft > 0
		luckLabel.Text = "🍀 5x LUCK " .. Util.Duration(luckLeft)
		local shieldLeft = (player:GetAttribute("LockedUntil") or 0) - nowT
		shieldChip.Visible = shieldLeft > 0
		shieldLabel.Text = "🛡️ SHIELD " .. Util.Duration(shieldLeft)
		local carrying = player:GetAttribute("Carrying")
		carryChip.Visible = carrying ~= nil
		carryLabel.Text = "🏃 RUN HOME!"
		local rainLeft = rainEndsAt - os.clock()
		rainChip.Visible = rainLeft > 0
		rainLabel.Text = "🌧️ RAIN " .. math.ceil(math.max(rainLeft, 0)) .. "s"
		local event = workspace:GetAttribute("Event")
		local eventLeft = (workspace:GetAttribute("EventUntil") or 0) - nowT
		local eventDef = event and Config.Events[event]
		eventChip.Visible = eventDef ~= nil and eventLeft > 0
		if eventDef then
			eventLabel.Text = eventDef.title .. " " .. Util.Duration(math.max(eventLeft, 0))
		end
		local boost = player:GetAttribute("Boost") or 1
		boostChip.Visible = boost > 1.001
		local friends = player:GetAttribute("Friends") or 0
		boostLabel.Text = string.format("🚀 x%.2g CASH", boost) .. (if friends > 0 then " (" .. friends .. " friends)" else "")
		if rainLeft > 0 then
			banner.Visible = true
			bannerText.Text = rainMsg
		elseif eventDef and eventLeft > 0 and eventLeft > Config.EventSeconds - 12 then
			-- Show the event banner for its first few seconds; the chip stays up after.
			banner.Visible = true
			bannerText.Text = eventDef.title .. "! " .. eventDef.desc
		else
			banner.Visible = false
		end
	end
end)

Remotes.Notify.OnClientEvent:Connect(toast)
Remotes.Banner.OnClientEvent:Connect(function(msg, seconds, kind)
	if kind ~= "event" then
		rainMsg = msg
		rainEndsAt = os.clock() + seconds
	end
	toast(msg, "epic")
end)

-- Show each player the price of their next Dispenser roll on the machine's prompt.
local function updateRollPrompt()
	local machine = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("SlimeDispenser")
	local prompt = machine and machine:FindFirstChild("RollPrompt", true)
	if prompt then
		prompt.ObjectText = "Cost " .. Util.Money(player:GetAttribute("RollCost") or 0)
	end
end
player:GetAttributeChangedSignal("RollCost"):Connect(updateRollPrompt)
task.delay(2, updateRollPrompt)

-- ===== Prompt filtering =====
-- Owners see "Sell" on their own slimes; everyone else sees "Steal".
local function filterPrompt(prompt: ProximityPrompt)
	local ownerId = prompt:GetAttribute("OwnerId")
	if not ownerId then
		return
	end
	local mine = ownerId == player.UserId
	if prompt.Name == "StealPrompt" then
		prompt.Enabled = not mine
	elseif prompt.Name == "SellPrompt" or prompt.Name == "MergePrompt" then
		prompt.Enabled = mine
	end
end
workspace.DescendantAdded:Connect(function(d)
	if d:IsA("ProximityPrompt") then
		task.defer(filterPrompt, d)
		if d.Name == "RollPrompt" then
			task.defer(updateRollPrompt)
		end
	end
end)
for _, d in workspace:GetDescendants() do
	if d:IsA("ProximityPrompt") then
		filterPrompt(d)
	end
end

-- ===== First-time tips =====
local tips = {
	"Buy slimes on the conveyor belt, or roll the 🎰 Slime Dispenser!",
	"They earn cash every second. Step on your green pad to collect it.",
	"Slimes grow over time, even while you're offline.",
	"Hold E on someone's slime to steal it, then run home!",
	"Got 3 of the same slime? Hold R on one to MERGE them into a ★ slime!",
	"Claim your 🎁 DAILY reward every day. Day 7 gives the exclusive Sunny slime!",
	"Press the red button in your base to shield it from thieves.",
	"Try the code RELEASE in 🎟️ CODES for free cash and 5x luck!",
	"Use your Slap Hand (hotbar) on thieves to knock your slime loose!",
	"Open ⚔️ GEAR for Speed Coils, Traps and Tasers.",
	"Finish 📜 QUESTS and open 🎁 GIFTS for free rewards.",
	"Play with friends: +10% cash for every friend in your server!",
	"Watch for events: Golden Hour, Lava Storm, Candy Party, Cash Frenzy, Lucky Hour!",
}
if os.date("!*t").month == 10 then
	table.insert(tips, 1, "🎃 HALLOWEEN UPDATE: Pumpkin, Ghosty and Vampire slimes until Oct 31! Code: SPOOKY")
end
task.spawn(function()
	task.wait(3)
	for _, tip in tips do
		toast(tip, "info")
		task.wait(4.5)
	end
end)
