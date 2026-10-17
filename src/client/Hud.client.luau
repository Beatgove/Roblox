-- All player-facing UI, built in code: cash HUD, luck timer, rebirth bar, shop, rebirth,
-- codes, Slime Index, toasts and the event banner.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
for _, name in { "Notify", "Rebirth", "Banner", "RedeemCode", "ClaimDaily", "BuyGear", "ClaimGift", "ClaimQuest", "BuyUpgrade", "FuseStart", "FuseClaim", "HoldTight", "BuySnack", "PickSnack", "EquipRelic", "UnequipRelic", "Reel", "Fx" } do
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
-- Kept small so the screen doesn't feel crowded (the bar and chips scale down together).
local TOP_SCALE = 0.55
local topScale = new("UIScale", { Scale = TOP_SCALE, Parent = top })
local cashLabel = text({ Size = UDim2.new(1, -20, 0, 44), Position = UDim2.fromOffset(10, 4), TextColor3 = COLORS.accent, Text = "$0", Parent = top })
local incomeLabel = text({ Size = UDim2.new(1, -20, 0, 20), Position = UDim2.fromOffset(10, 48), TextColor3 = COLORS.muted, Text = "+$0/s", Parent = top })
-- Rebirth progress bar along the bottom of the cash bar.
local barBack = new("Frame", { Position = UDim2.new(0, 14, 1, -14), Size = UDim2.new(1, -28, 0, 8), BackgroundColor3 = Color3.fromRGB(20, 12, 35), Parent = top }, { corner(4) })
local barFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = barBack }, { corner(4), gradient(COLORS.purple, COLORS.pink) })
-- Level badge on the left of the cash bar, with an XP bar under the number.
local levelBox = new("Frame", { Position = UDim2.new(0, -80, 0, 0), Size = UDim2.fromOffset(72, 84), BackgroundColor3 = Color3.new(1, 1, 1), Parent = top }, { corner(18), stroke(COLORS.outline, 4), gradient(COLORS.gold, Color3.fromRGB(200, 120, 30)) })
text({ Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 0, 18), Text = "LEVEL", Parent = levelBox })
local levelLabel = text({ Position = UDim2.fromOffset(4, 20), Size = UDim2.new(1, -8, 0, 38), Text = "1", Parent = levelBox })
local xpBack = new("Frame", { Position = UDim2.new(0, 8, 1, -20), Size = UDim2.new(1, -16, 0, 12), BackgroundColor3 = Color3.fromRGB(20, 12, 35), Parent = levelBox }, { corner(6) })
local xpFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = xpBack }, { corner(6), gradient(COLORS.accent, Color3.fromRGB(40, 170, 90)) })
local function refreshLevel()
	local xp = player:GetAttribute("XP") or 0
	local need = math.max(player:GetAttribute("XPNeeded") or 1, 1)
	levelLabel.Text = tostring(player:GetAttribute("Level") or 1)
	xpFill.Size = UDim2.fromScale(math.clamp(xp / need, 0, 1), 1)
end
for _, attr in { "Level", "XP", "XPNeeded" } do
	player:GetAttributeChangedSignal(attr):Connect(refreshLevel)
end
refreshLevel()

local chips = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 56),
	Size = UDim2.fromOffset(600, 68),
	BackgroundTransparency = 1,
	Parent = gui,
}, { new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6), Wraps = true }), new("UIScale", { Scale = 0.6 }) })
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
local kingChip, kingLabel = chip(Color3.fromRGB(110, 210, 80))
local revengeChip, revengeLabel = chip(Color3.fromRGB(220, 50, 50))
local bountyChip, bountyLabel = chip(Color3.fromRGB(230, 170, 30))
local rookieChip, rookieLabel = chip(Color3.fromRGB(255, 200, 90))
local nemesisChip, nemesisLabel = chip(Color3.fromRGB(140, 50, 200))
local blackoutChip, blackoutLabel = chip(Color3.fromRGB(50, 40, 110))
local arcadeChip, arcadeLabel = chip(Color3.fromRGB(255, 120, 200))
local towerChip, towerLabel = chip(Color3.fromRGB(150, 120, 255))
local stormChip, stormLabel = chip(Color3.fromRGB(110, 90, 220))

-- ===== Banner (Slime Rain) =====
local banner = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 100),
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
	TextSize = 17,
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
	local nextText = "  ·  All rewards claimed!"
	for _, m in Config.IndexMilestones do
		if n < m.count then
			nextText = "  ·  At " .. m.count .. ": " .. m.label
			break
		end
	end
	indexHeader.Text = string.format("Found %d/%d (+%d%% income)", n, #Config.Slimes, math.floor(n * Config.IndexBonusPerSlime * 100)) .. nextText
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

-- Base upgrades (permanent, kept on rebirth)
local upgrades, upgradesScale = panel("⬆️ Upgrades", Color3.fromRGB(120, 255, 160))
local upList = scroller(upgrades, new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }))
upList.Size = UDim2.new(1, -24, 1, -110) -- leave room for the footer line
local upRows = {}
for i, key in Config.UpgradeOrder do
	local def = Config.Upgrades[key]
	local row = new("Frame", { Size = UDim2.new(1, -8, 0, 80), BackgroundColor3 = COLORS.panel, LayoutOrder = i, Parent = upList }, { corner(12), new("UIStroke", { Color = COLORS.accent, Thickness = 2, Transparency = 0.4 }) })
	local title = text({ Size = UDim2.new(0.66, -10, 0, 30), Position = UDim2.fromOffset(12, 6), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = COLORS.accent, Text = def.name, Parent = row })
	text({ Size = UDim2.new(0.66, -10, 0, 22), Position = UDim2.fromOffset(12, 38), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = COLORS.muted, Font = Enum.Font.GothamMedium, TextStrokeTransparency = 1, Text = def.desc, Parent = row })
	local pips = new("Frame", { Position = UDim2.fromOffset(12, 62), Size = UDim2.new(0.66, -10, 0, 10), BackgroundTransparency = 1, Parent = row }, { new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 3) }) })
	local pipList = {}
	for l = 1, def.max do
		pipList[l] = new("Frame", { Size = UDim2.new(1 / def.max, -3, 1, 0), BackgroundColor3 = Color3.fromRGB(20, 12, 35), Parent = pips }, { corner(4) })
	end
	local b = button({ Size = UDim2.new(0.3, -8, 0, 56), Position = UDim2.new(0.7, 0, 0, 12), BackgroundColor3 = COLORS.accent, Text = "", Parent = row }, function()
		Remotes.BuyUpgrade:FireServer(key)
	end)
	upRows[key] = { title = title, button = b, pips = pipList }
end
text({ Position = UDim2.new(0, 16, 1, -36), Size = UDim2.new(1, -32, 0, 24), Font = Enum.Font.GothamBold, TextStrokeTransparency = 1, TextColor3 = COLORS.gold, Text = "Upgrades are permanent. You keep them when you rebirth!", Parent = upgrades })
local function refreshUpgrades()
	local levels = {}
	for k, v in string.gmatch(player:GetAttribute("Upgrades") or "", "(%w+)=(%d+)") do
		levels[k] = tonumber(v) or 0
	end
	for key, r in upRows do
		local def = Config.Upgrades[key]
		local lv = levels[key] or 0
		r.title.Text = def.name .. "  Lv " .. lv .. "/" .. def.max
		r.button.Text = if lv >= def.max then "MAXED" else Util.Money(Config.UpgradeCost(key, lv))
		for l, pip in r.pips do
			pip.BackgroundColor3 = if l <= lv then COLORS.accent else Color3.fromRGB(20, 12, 35)
		end
	end
end
player:GetAttributeChangedSignal("Upgrades"):Connect(refreshUpgrades)
refreshUpgrades()

-- Snack Bar: your snacks, which one "Feed" uses, and buying more.
local SNACK_COLOR = Color3.fromRGB(255, 150, 80)
local snacksPanel, snacksScale = panel("🍽️ Snack Bar", SNACK_COLOR)
local snackList = scroller(snacksPanel, new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }))
snackList.Size = UDim2.new(1, -24, 1, -110) -- leave room for the footer line
local snackRows = {}
for i, key in Config.SnackOrder do
	local def = Config.Snacks[key]
	local row = new("Frame", { Size = UDim2.new(1, -8, 0, 72), BackgroundColor3 = COLORS.panel, LayoutOrder = i, Parent = snackList }, { corner(12) })
	local rowStroke = new("UIStroke", { Color = def.color, Thickness = 2, Transparency = 0.5, Parent = row })
	text({ Size = UDim2.fromOffset(56, 56), Position = UDim2.fromOffset(8, 8), Text = def.icon, Parent = row })
	local title = text({ Size = UDim2.new(0.5, -70, 0, 28), Position = UDim2.fromOffset(70, 6), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = def.color, Text = key, Parent = row })
	text({ Size = UDim2.new(0.5, -70, 0, 32), Position = UDim2.fromOffset(70, 34), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = COLORS.muted, Font = Enum.Font.GothamMedium, TextStrokeTransparency = 1, TextWrapped = true,
		Text = "→ " .. def.diet .. ": x" .. def.mult .. " cash. " .. def.desc, Parent = row })
	local use = button({ Size = UDim2.new(0.22, -6, 0, 52), Position = UDim2.new(0.5, 0, 0, 10), BackgroundColor3 = def.color, Text = "USE", Parent = row }, function()
		Remotes.PickSnack:FireServer(key)
	end)
	local buy = button({ Size = UDim2.new(0.28, -12, 0, 52), Position = UDim2.new(0.72, 0, 0, 10), BackgroundColor3 = COLORS.gold, Text = "", Parent = row }, function()
		Remotes.BuySnack:FireServer(key)
	end)
	snackRows[key] = { title = title, use = use, buy = buy, stroke = rowStroke }
end
local snackInfo = text({ Position = UDim2.new(0, 16, 1, -36), Size = UDim2.new(1, -32, 0, 24), Font = Enum.Font.GothamBold, TextStrokeTransparency = 1, TextColor3 = COLORS.gold, Text = "", Parent = snacksPanel })
local function refreshSnacks()
	local ok, owned = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("Snacks") or "{}")
	local ok2, prices = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("SnackPrices") or "{}")
	owned = if ok and type(owned) == "table" then owned else {}
	prices = if ok2 and type(prices) == "table" then prices else {}
	local pick = player:GetAttribute("SnackPick")
	for key, r in snackRows do
		local n = owned[key] or 0
		r.title.Text = key .. "  x" .. n
		r.use.Text = if pick == key then "✅ USING" else "USE"
		r.use.AutoButtonColor = n > 0
		r.use.BackgroundTransparency = if n > 0 then 0 else 0.5
		r.buy.Text = "BUY " .. Util.Money(prices[key] or 0)
		r.stroke.Transparency = if pick == key then 0 else 0.5
	end
	snackInfo.Text = "Hold G on your slime to feed. " .. Config.SnackEvolve .. " of one kind = EVOLVE! 📕 Diet Book " .. (player:GetAttribute("DietCount") or 0) .. "/" .. (#Config.Slimes * #Config.SnackOrder)
end
for _, attr in { "Snacks", "SnackPrices", "SnackPick", "DietCount" } do
	player:GetAttributeChangedSignal(attr):Connect(refreshSnacks)
end
refreshSnacks()

-- Relics: 3 slots for rule-changing charms, plus the ones you've found this run.
local RELIC_COLOR = Color3.fromRGB(200, 120, 255)
local relicsPanel, relicsScale = panel("🔮 Relics", RELIC_COLOR)
text({ Position = UDim2.fromOffset(16, 58), Size = UDim2.new(1, -32, 0, 22), Font = Enum.Font.GothamBold, TextStrokeTransparency = 1, TextColor3 = COLORS.muted,
	Text = "Equip up to " .. Config.RelicSlots .. ". Find more from the King, bounties, quests and the Index. They reset on rebirth!", Parent = relicsPanel })
local relicList = new("ScrollingFrame", { Position = UDim2.fromOffset(12, 86), Size = UDim2.new(1, -24, 1, -98), BackgroundTransparency = 1, ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = relicsPanel },
	{ new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
local relicRows = {}
for i, key in Config.RelicOrder do
	local def = Config.Relics[key]
	local color = Config.RelicRarities[def.rarity].color
	local row = new("Frame", { Size = UDim2.new(1, -8, 0, 66), BackgroundColor3 = COLORS.panel, LayoutOrder = i, Visible = false, Parent = relicList }, { corner(12) })
	local rowStroke = new("UIStroke", { Color = color, Thickness = 2, Transparency = 0.5, Parent = row })
	text({ Size = UDim2.fromOffset(50, 50), Position = UDim2.fromOffset(8, 8), Text = def.icon, Parent = row })
	text({ Size = UDim2.new(0.72, -66, 0, 26), Position = UDim2.fromOffset(64, 4), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = color, Text = def.name .. "  · " .. def.rarity, Parent = row })
	text({ Size = UDim2.new(0.72, -66, 0, 32), Position = UDim2.fromOffset(64, 30), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = COLORS.muted, Font = Enum.Font.GothamMedium, TextStrokeTransparency = 1, TextWrapped = true, Text = def.desc, Parent = row })
	local b
	b = button({ Size = UDim2.new(0.28, -12, 0, 48), Position = UDim2.new(0.72, 0, 0, 9), BackgroundColor3 = color, Text = "EQUIP", Parent = row }, function()
		if b:GetAttribute("On") then
			Remotes.UnequipRelic:FireServer(key)
		else
			Remotes.EquipRelic:FireServer(key)
		end
	end)
	relicRows[key] = { row = row, button = b, stroke = rowStroke }
end
local relicEmpty = text({ Position = UDim2.new(0, 16, 0.5, -20), Size = UDim2.new(1, -32, 0, 40), TextColor3 = COLORS.muted, Text = "No relics yet. Beat the King Slime or claim a bounty!", Parent = relicsPanel })
local function refreshRelics()
	local ok, info = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("Relics") or "{}")
	info = if ok and type(info) == "table" then info else {}
	local equipped = {}
	for _, k in info.equipped or {} do
		equipped[k] = true
	end
	local owned = 0
	for _, k in info.bag or {} do
		owned += 1
	end
	local bag = {}
	for _, k in info.bag or {} do
		bag[k] = true
	end
	for key, r in relicRows do
		r.row.Visible = bag[key] == true
		r.button:SetAttribute("On", equipped[key] == true)
		r.button.Text = if equipped[key] then "✅ ON" else "EQUIP"
		r.stroke.Transparency = if equipped[key] then 0 else 0.5
	end
	relicEmpty.Visible = owned == 0
end
player:GetAttributeChangedSignal("Relics"):Connect(refreshRelics)
refreshRelics()

-- Thief tracker: while someone runs off with your slime, they glow red through walls,
-- a red trail points at them, and a chip shows how far away they are.
do
	local chipFrame, chipLabel = chip(Color3.fromRGB(220, 30, 50))
	local highlight = new("Highlight", { FillColor = Color3.fromRGB(255, 30, 40), FillTransparency = 0.6, OutlineColor = Color3.fromRGB(255, 255, 255), DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Enabled = false, Parent = gui })
	local trail = new("Beam", { Color = ColorSequence.new(Color3.fromRGB(255, 40, 50)), LightEmission = 1, Width0 = 0.5, Width1 = 0.2, FaceCamera = true, Transparency = NumberSequence.new(0.25), Enabled = false, Parent = workspace.Terrain })
	RunService.Heartbeat:Connect(function()
		local thief: Player? = nil
		for _, other in Players:GetPlayers() do
			if other:GetAttribute("StealingFrom") == player.UserId then
				thief = other
			end
		end
		local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local theirRoot = thief and thief.Character and thief.Character:FindFirstChild("HumanoidRootPart")
		chipFrame.Visible = theirRoot ~= nil
		highlight.Enabled = theirRoot ~= nil
		trail.Enabled = theirRoot ~= nil and myRoot ~= nil
		if not (thief and theirRoot) then
			return
		end
		local t = thief :: Player
		highlight.Adornee = t.Character
		local dist = if myRoot then math.floor(((myRoot :: BasePart).Position - (theirRoot :: BasePart).Position).Magnitude) else 0
		chipLabel.Text = "🚨 " .. t.DisplayName .. " · " .. dist .. "m"
		if myRoot then
			local a0 = myRoot:FindFirstChild("ThiefTrail0") or new("Attachment", { Name = "ThiefTrail0", Parent = myRoot })
			local a1 = theirRoot:FindFirstChild("ThiefTrail1") or new("Attachment", { Name = "ThiefTrail1", Parent = theirRoot })
			trail.Attachment0 = a0 :: Attachment
			trail.Attachment1 = a1 :: Attachment
		end
	end)
end

-- Slime Season lives in its own block (this script is near Luau's 200-local limit).
local seasonUI: { [string]: any } = {}
do
	-- Slime Season: free monthly reward track.
	local SEASON_COLOR = Color3.fromRGB(255, 200, 70)
	local seasonPanel, seasonScale = panel("🌟 Slime Season", SEASON_COLOR)
	local seasonInfo = text({ Position = UDim2.fromOffset(16, 58), Size = UDim2.new(1, -32, 0, 22), Font = Enum.Font.GothamBold, TextStrokeTransparency = 1, TextColor3 = COLORS.muted, Text = "", Parent = seasonPanel })
	local seasonBarBack = new("Frame", { Position = UDim2.fromOffset(16, 84), Size = UDim2.new(1, -32, 0, 14), BackgroundColor3 = Color3.fromRGB(20, 12, 35), Parent = seasonPanel }, { corner(7) })
	local seasonBarFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = seasonBarBack }, { corner(7), gradient(SEASON_COLOR, Color3.fromRGB(255, 130, 40)) })
	local seasonList = new("ScrollingFrame", { Position = UDim2.fromOffset(12, 106), Size = UDim2.new(1, -24, 1, -118), BackgroundTransparency = 1, ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = seasonPanel },
		{ new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local seasonRows = {}
	for i, t in Config.Season.tiers do
		local final = i == #Config.Season.tiers
		local row = new("Frame", { Size = UDim2.new(1, -8, 0, 48), BackgroundColor3 = COLORS.panel, LayoutOrder = i, Parent = seasonList }, { corner(10) })
		local rowStroke = new("UIStroke", { Color = if final then SEASON_COLOR else COLORS.muted, Thickness = 2, Transparency = 0.5, Parent = row })
		text({ Size = UDim2.fromOffset(70, 36), Position = UDim2.fromOffset(8, 6), TextColor3 = SEASON_COLOR, Text = "TIER " .. i, Parent = row })
		text({ Size = UDim2.new(0.72, -86, 0, 32), Position = UDim2.fromOffset(84, 8), TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBold, TextStrokeTransparency = 1, Text = t.label, Parent = row })
		local b = button({ Size = UDim2.new(0.28, -12, 0, 36), Position = UDim2.new(0.72, 0, 0, 6), BackgroundColor3 = SEASON_COLOR, Text = "🔒", Parent = row }, function()
			Remotes.ClaimSeason:FireServer(i)
		end)
		seasonRows[i] = { button = b, stroke = rowStroke }
	end
	local function refreshSeason()
		local ok, info = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("Season") or "{}")
		info = if ok and type(info) == "table" then info else {}
		local xp = info.xp or 0
		local per = Config.Season.tierXP
		local unlocked = math.min(xp // per, #Config.Season.tiers)
		local claimed = {}
		for _, k in info.claimed or {} do
			claimed[k] = true
		end
		local left = (info.endsAt or 0) - os.time()
		local ends = if left >= 86400 then (left // 86400) .. " days" else Util.Duration(math.max(left, 0))
		seasonInfo.Text = "Tier " .. unlocked .. " of " .. #Config.Season.tiers .. " · " .. (xp % per) .. "/" .. per .. " XP to next · ends in " .. ends
		seasonBarFill.Size = UDim2.fromScale(if unlocked >= #Config.Season.tiers then 1 else (xp % per) / per, 1)
		local ready = 0
		for i, r in seasonRows do
			if claimed[i] then
				r.button.Text = "✅"
				r.stroke.Transparency = 0.7
			elseif i <= unlocked then
				r.button.Text = "CLAIM"
				r.stroke.Transparency = 0
				ready += 1
			else
				r.button.Text = "🔒"
				r.stroke.Transparency = 0.5
			end
		end
		if seasonUI.badge then
			seasonUI.badge.Visible = ready > 0
		end
	end
	player:GetAttributeChangedSignal("Season"):Connect(refreshSeason)
	seasonUI.panel, seasonUI.scale, seasonUI.color, seasonUI.refresh = seasonPanel, seasonScale, SEASON_COLOR, refreshSeason
end

-- Fuse Machine: pick 3 slimes, see the fee and odds, fuse, come back later.
local FUSE_COLOR = Color3.fromRGB(150, 255, 120)
local fuse, fuseScale = panel("🧪 Fuse Machine", FUSE_COLOR)
text({ Position = UDim2.fromOffset(16, 58), Size = UDim2.new(1, -32, 0, 24), Font = Enum.Font.GothamBold, TextStrokeTransparency = 1, TextColor3 = COLORS.muted, Text = "Pick " .. Config.FuseCount .. " slimes. You get 1 new slime based on their rarity.", Parent = fuse })
local fuseGrid = new("ScrollingFrame", {
	Position = UDim2.fromOffset(12, 86),
	Size = UDim2.new(1, -24, 1, -200),
	BackgroundTransparency = 1,
	ScrollBarThickness = 6,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	Parent = fuse,
}, { new("UIGridLayout", { CellSize = UDim2.fromOffset(104, 70), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
local fuseEmpty = text({ Position = UDim2.fromOffset(16, 96), Size = UDim2.new(1, -32, 0, 30), Font = Enum.Font.GothamBold, TextStrokeTransparency = 1, TextColor3 = COLORS.muted, Text = "You need slimes in your pens to fuse.", Visible = false, Parent = fuse })
local fuseFee = text({ Position = UDim2.new(0, 16, 1, -112), Size = UDim2.new(1, -32, 0, 22), TextColor3 = COLORS.gold, Text = "", Parent = fuse })
local fuseOdds = text({ Position = UDim2.new(0, 16, 1, -88), Size = UDim2.new(1, -32, 0, 26), Font = Enum.Font.GothamBold, TextStrokeTransparency = 1, TextColor3 = COLORS.text, RichText = true, Text = "", Parent = fuse })
local fuseSelected: { number } = {}
local fuseSlimes = {}
local fuseState = { active = false, endsAt = 0 }
local fuseBtn
local function fuseOrder(id: string): number
	local def = Config.SlimeById[id]
	return math.min(Config.RarityByName[def.rarity].order, 8)
end
local function refreshFuseInfo()
	if fuseState.active then
		fuseFee.Text = "🧪 Your slimes are fusing..."
		fuseOdds.Text = "Come back when the timer ends to claim your new slime."
		return
	end
	local fee, sum = 0, 0
	for _, i in fuseSelected do
		local s = fuseSlimes[i]
		fee += Config.SlimeById[s.id].price * Config.FuseFeeShare
		sum += fuseOrder(s.id)
	end
	fuseFee.Text = string.format("Selected %d/%d  ·  Fee %s", #fuseSelected, Config.FuseCount, Util.Money(math.floor(fee)))
	if #fuseSelected == 0 then
		fuseOdds.Text = "Rarer slimes in = rarer slime out. Best mutation kept " .. math.floor(Config.FuseKeepMutationChance * 100) .. "% of the time."
		return
	end
	local avg = math.floor(sum / #fuseSelected + 0.5)
	local chances: { [number]: number } = {}
	local total = 0
	for _, o in Config.FuseOdds do
		total += o.chance
	end
	for _, o in Config.FuseOdds do
		local order = math.clamp(avg + o.shift, 1, 8)
		chances[order] = (chances[order] or 0) + o.chance / total
	end
	local parts = {}
	for order = 1, 8 do
		if chances[order] then
			local r = Config.Rarities[order]
			table.insert(parts, string.format('<font color="#%s">%s %d%%</font>', r.color:ToHex(), r.name, math.floor(chances[order] * 100 + 0.5)))
		end
	end
	fuseOdds.Text = "Odds: " .. table.concat(parts, "  ")
end
local function refreshFuseButton()
	local left = fuseState.endsAt - workspace:GetServerTimeNow()
	if fuseState.active then
		fuseBtn.Text = if left > 0 then "⏳ " .. Util.Duration(left) else "CLAIM YOUR SLIME!"
	else
		fuseBtn.Text = if #fuseSelected == Config.FuseCount then "🧪 FUSE!" else "PICK " .. (Config.FuseCount - #fuseSelected) .. " MORE"
	end
end
local function rebuildFuseGrid()
	for _, c in fuseGrid:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local ok, list = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute("SlimeList") or "[]")
	end)
	fuseSlimes = if ok and typeof(list) == "table" then list else {}
	fuseSelected = {}
	fuseEmpty.Visible = #fuseSlimes == 0
	for i, s in fuseSlimes do
		local def = Config.SlimeById[s.id]
		if not def then
			continue
		end
		local r = Config.RarityByName[def.rarity]
		local card = new("TextButton", { BackgroundColor3 = COLORS.panel, Text = "", AutoButtonColor = false, LayoutOrder = i, Parent = fuseGrid }, { corner(12) })
		local st = new("UIStroke", { Color = r.color, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = card })
		text({ Position = UDim2.fromOffset(4, 6), Size = UDim2.new(1, -8, 0, 30), Text = Config.DisplayName(s.id, s.mut, s.stars, s.traits, s.diet), Parent = card })
		text({ Position = UDim2.fromOffset(4, 40), Size = UDim2.new(1, -8, 0, 20), Font = Enum.Font.GothamBold, TextStrokeTransparency = 1, TextColor3 = r.color, Text = def.rarity, Parent = card })
		local exclusive = def.rarity == "Exclusive"
		if exclusive then
			card.BackgroundTransparency = 0.6
		end
		card.Activated:Connect(function()
			if fuseState.active then
				return
			end
			if exclusive then
				toast("Exclusive slimes are too special to fuse!", "bad")
				return
			end
			click()
			local at = table.find(fuseSelected, i)
			if at then
				table.remove(fuseSelected, at)
			elseif #fuseSelected < Config.FuseCount then
				table.insert(fuseSelected, i)
			end
			local picked = table.find(fuseSelected, i) ~= nil
			st.Color = if picked then FUSE_COLOR else r.color
			st.Thickness = if picked then 5 else 2
			card.BackgroundColor3 = if picked then Color3.fromRGB(50, 90, 60) else COLORS.panel
			refreshFuseInfo()
			refreshFuseButton()
		end)
	end
	refreshFuseInfo()
end
fuseBtn = button({ Size = UDim2.new(1, -40, 0, 50), Position = UDim2.new(0, 20, 1, -58), BackgroundColor3 = FUSE_COLOR, Text = "", Parent = fuse }, function()
	if fuseState.active then
		Remotes.FuseClaim:FireServer()
	elseif #fuseSelected == Config.FuseCount then
		Remotes.FuseStart:FireServer(fuseSelected)
	end
end)
local function refreshFuseState()
	local ok, st = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute("Fuse") or "{}")
	end)
	if ok and typeof(st) == "table" then
		fuseState = { active = st.active == true, endsAt = tonumber(st.endsAt) or 0 }
	end
	refreshFuseInfo()
	refreshFuseButton()
end
player:GetAttributeChangedSignal("SlimeList"):Connect(rebuildFuseGrid)
player:GetAttributeChangedSignal("Fuse"):Connect(refreshFuseState)
rebuildFuseGrid()
refreshFuseState()
Remotes.Fx.OnClientEvent:Connect(function(kind)
	if kind == "openFuse" and not fuse.Visible then
		openPanel(fuse, fuseScale)
	end
end)

-- ===== Side buttons =====
local side = new("Frame", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 10, 0.5, 0),
	Size = UDim2.fromOffset(208, 494),
	BackgroundTransparency = 1,
	Parent = gui,
}, { new("UIGridLayout", { CellSize = UDim2.fromOffset(100, 56), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
-- Shrink the side buttons on short screens so they never hit Roblox's top-left menu.
local sideScale = new("UIScale", { Parent = side })
local function fitSide()
	local h = workspace.CurrentCamera.ViewportSize.Y
	sideScale.Scale = math.clamp((h - 150) / 494, 0.5, 0.75)
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
sideButton(9, Color3.fromRGB(120, 255, 160), "⬆️ UPGRADE", upgrades, upgradesScale)
local fuseSideBtn = sideButton(10, FUSE_COLOR, "🧪 FUSE", fuse, fuseScale)
sideButton(11, SNACK_COLOR, "🍽️ SNACKS", snacksPanel, snacksScale)
sideButton(12, RELIC_COLOR, "🔮 RELICS", relicsPanel, relicsScale)
seasonUI.badge = makeBadge(sideButton(13, seasonUI.color, "🌟 SEASON", seasonUI.panel, seasonUI.scale))
seasonUI.refresh()
-- Invite friends: everyone earns +10% cash per friend in the server.
button({ BackgroundColor3 = Color3.fromRGB(80, 200, 255), Text = "💌 INVITE", LayoutOrder = 14, Parent = side }, function()
	local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
	if ok and can then
		pcall(SocialService.PromptGameInvite, SocialService, player)
	else
		toast("Invites aren't available on this account right now.", "bad")
	end
end)
local fuseBadge = makeBadge(fuseSideBtn)
local badge = makeBadge(dailyBtn)
local questBadge = makeBadge(questsBtn)
local giftBadge = makeBadge(giftsBtn)
do
	-- Only the main buttons show by default; ➕ MORE opens the rest, so the screen stays clear.
	-- The MORE button gets a badge whenever a hidden button has one.
	local moreOpen = false
	local moreBtn
	moreBtn = button({ BackgroundColor3 = Color3.fromRGB(110, 100, 140), Text = "➕ MORE", LayoutOrder = 99, Parent = side }, function()
		moreOpen = not moreOpen
		moreBtn.Text = if moreOpen then "✖ LESS" else "➕ MORE"
		for _, b in side:GetChildren() do
			local order = if b:IsA("GuiObject") then b.LayoutOrder else 0
			if b:IsA("GuiButton") and b ~= moreBtn and not table.find({ 1, 3, 5, 7, 8 }, order) then
				b.Visible = moreOpen
			end
		end
	end)
	for _, b in side:GetChildren() do
		if b:IsA("GuiButton") and b ~= moreBtn and not table.find({ 1, 3, 5, 7, 8 }, b.LayoutOrder) then
			b.Visible = false
		end
	end
	local moreBadge = makeBadge(moreBtn)
	task.spawn(function()
		while true do
			task.wait(1)
			local any = false
			for _, b in side:GetChildren() do
				local bd = b:IsA("GuiButton") and not b.Visible and b:FindFirstChildWhichIsA("Frame")
				if bd and bd.Visible and bd.ZIndex == 3 then
					any = true
				end
			end
			moreBadge.Visible = any and not moreOpen
		end
	end)
end
task.spawn(function()
	while true do
		refreshGifts()
		giftBadge.Visible = giftsReady > 0
		questBadge.Visible = questsReady > 0
		refreshFuseButton()
		fuseBadge.Visible = fuseState.active and fuseState.endsAt <= workspace:GetServerTimeNow()
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
		"Rebirth %d → %d\n\nCost: %s\nYou have: %s\n\n🎁 Prize: %s\n✅ Keep: +%d%% income forever, +%d pen slots, +%ds lock time, your Slime Index\n❌ Lose: cash and slimes",
		rebirths,
		rebirths + 1,
		Util.Money(cost),
		Util.Money(cash),
		(Config.RebirthRewards[rebirths + 1] or Config.RebirthRewardDefault).label,
		math.floor(Config.RebirthIncomeBonus * 100 * (rebirths + 1)),
		Config.SlotsPerRebirth,
		Config.RebirthLockBonus
	)
	for _, t in Config.BaseTiers do
		if t.rebirth > rebirths then
			rebirthInfo.Text ..= "\n🏰 Rebirth " .. t.rebirth .. " base upgrade: " .. t.name
			break
		end
	end
	-- Punch the cash bar on big gains.
	if cash > lastCash and cash - lastCash > math.max(income * 2, 10) then
		topScale.Scale = TOP_SCALE * 1.12
		TweenService:Create(topScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = TOP_SCALE }):Play()
	end
	lastCash = cash
end
for _, attr in { "Cash", "Income", "Rebirths", "RebirthCost", "Slots", "SlimeCount", "Bank" } do
	player:GetAttributeChangedSignal(attr):Connect(refresh)
end
refresh()

-- Revenge: the thief who robbed you glows red (only on your screen).
local revengeGlow: Highlight? = nil
local function updateRevengeGlow(active: boolean)
	local target = active and Players:GetPlayerByUserId(player:GetAttribute("RevengeUserId") or 0)
	local char = target and target.Character
	if char then
		if not revengeGlow or revengeGlow.Parent ~= char then
			if revengeGlow then
				revengeGlow:Destroy()
			end
			revengeGlow = new("Highlight", { Name = "RevengeGlow", FillColor = Color3.fromRGB(255, 40, 40), FillTransparency = 0.5, OutlineColor = Color3.fromRGB(255, 220, 60), DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Parent = char })
			local head = char:FindFirstChild("Head")
			if head then
				local tag = new("BillboardGui", { Name = "RevengeTag", Size = UDim2.fromOffset(180, 34), StudsOffset = Vector3.new(0, 8.5, 0), AlwaysOnTop = true, Parent = revengeGlow })
				tag.Adornee = head
				text({ Size = UDim2.fromScale(1, 1), Text = "😤 REVENGE TARGET", TextColor3 = Color3.fromRGB(255, 90, 90), Parent = tag })
			end
		end
	elseif revengeGlow then
		revengeGlow:Destroy()
		revengeGlow = nil
	end
end

-- Nemesis: a purple skull over the player who keeps robbing you (only on your screen).
local nemesisMark: BillboardGui? = nil
local function updateNemesisMark()
	local target = Players:GetPlayerByUserId(player:GetAttribute("NemesisUserId") or 0)
	local head = target and target.Character and target.Character:FindFirstChild("Head")
	if head then
		if not nemesisMark or nemesisMark.Adornee ~= head then
			if nemesisMark then
				nemesisMark:Destroy()
			end
			local mark = new("BillboardGui", { Name = "NemesisMark", Size = UDim2.fromOffset(150, 64), StudsOffset = Vector3.new(0, 11, 0), AlwaysOnTop = true, Parent = gui })
			mark.Adornee = head
			text({ Size = UDim2.fromScale(1, 0.62), Text = "☠️", Parent = mark })
			text({ Position = UDim2.fromScale(0, 0.6), Size = UDim2.fromScale(1, 0.4), Text = "NEMESIS", TextColor3 = Color3.fromRGB(210, 120, 255), Parent = mark })
			nemesisMark = mark
		end
	elseif nemesisMark then
		nemesisMark:Destroy()
		nemesisMark = nil
	end
end

-- Squirm: when a stolen slime wriggles, tap HOLD ON in time or it slips away.
local squirmBtn
local squirmToken = 0
squirmBtn = button({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.62), Size = UDim2.fromOffset(260, 90), BackgroundColor3 = Color3.fromRGB(255, 80, 120), Text = "🫳 HOLD ON! (F)", Visible = false, ZIndex = 5, Parent = gui }, function()
	if squirmBtn.Visible then
		squirmBtn.Visible = false
		Remotes.HoldTight:FireServer(squirmToken)
	end
end)
game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
	if not processed and squirmBtn.Visible and (input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonX) then
		squirmBtn.Visible = false
		Remotes.HoldTight:FireServer(squirmToken)
	end
end)
local squirmBar = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(0.8, 0, 0, 8), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 6, Parent = squirmBtn }, { corner(4) })
Remotes.Fx.OnClientEvent:Connect(function(kind, d)
	if kind == "squirm" then
		squirmBar.Size = UDim2.new(0.8, 0, 0, 8)
		TweenService:Create(squirmBar, TweenInfo.new(d.window, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 8) }):Play()
		squirmToken = d.token
		squirmBtn.Position = UDim2.fromScale(0.35 + math.random() * 0.3, 0.55 + math.random() * 0.15)
		squirmBtn.Visible = true
		local s = squirmBtn:FindFirstChildOfClass("UIScale")
		if s then
			s.Scale = 0.5
			TweenService:Create(s, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
		local token = d.token
		task.delay(d.window, function()
			if squirmToken == token then
				squirmBtn.Visible = false
			end
		end)
	end
end)

-- Fishing: REEL! when the bobber dips.
local reelBtn
local reelToken = 0
local function doReel()
	if reelBtn.Visible then
		reelBtn.Visible = false
		Remotes.Reel:FireServer(reelToken)
	end
end
reelBtn = button({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.62), Size = UDim2.fromOffset(260, 90), BackgroundColor3 = Color3.fromRGB(90, 220, 140), Text = "🎣 REEL! (F)", Visible = false, ZIndex = 5, Parent = gui }, doReel)
local reelBar = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(0.8, 0, 0, 8), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 6, Parent = reelBtn }, { corner(4) })
game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
	if not processed and (input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonX) then
		doReel()
	end
end)
Remotes.Fx.OnClientEvent:Connect(function(kind, d)
	if kind == "fishBite" then
		reelToken = d.token
		reelBar.Size = UDim2.new(0.8, 0, 0, 8)
		TweenService:Create(reelBar, TweenInfo.new(d.window, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 8) }):Play()
		reelBtn.Position = UDim2.fromScale(0.4 + math.random() * 0.2, 0.58 + math.random() * 0.1)
		reelBtn.Visible = true
		local token = d.token
		task.delay(d.window, function()
			if reelToken == token then
				reelBtn.Visible = false
			end
		end)
	elseif kind == "fishMiss" or kind == "fishCatch" then
		reelBtn.Visible = false
	end
end)

local rainEndsAt = 0
local rainMsg = ""
local rainKind = "rain"
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
		local event = workspace:GetAttribute("Event")
		rainChip.Visible = rainLeft > 0 and rainKind == "rain"
		local stormIn = (workspace:GetAttribute("NextStorm") or 0) - nowT
		stormChip.Visible = stormIn > 0 and event ~= "SlimeStorm"
		if stormIn > 0 then
			stormLabel.Text = "⛈️ STORM in " .. (if stormIn >= 86400 then string.format("%dd %dh", stormIn // 86400, (stormIn % 86400) // 3600) else Util.Duration(stormIn))
		end
		rainLabel.Text = "🌧️ RAIN " .. math.ceil(math.max(rainLeft, 0)) .. "s"
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
		local kingLeft = (workspace:GetAttribute("KingUntil") or 0) - nowT
		kingChip.Visible = kingLeft > 0
		kingLabel.Text = string.format("👑 KING %d/%d · %s", workspace:GetAttribute("KingHp") or 0, workspace:GetAttribute("KingMaxHp") or 0, Util.Duration(math.max(kingLeft, 0)))
		local revengeLeft = (player:GetAttribute("RevengeUntil") or 0) - nowT
		revengeChip.Visible = revengeLeft > 0
		revengeLabel.Text = "😤 " .. (player:GetAttribute("RevengeName") or "REVENGE") .. " " .. Util.Duration(math.max(revengeLeft, 0))
		local bounty = player:GetAttribute("Bounty") or 0
		bountyChip.Visible = bounty > 0
		bountyLabel.Text = "💰 WANTED " .. Util.Money(bounty)
		rookieChip.Visible = player:GetAttribute("Rookie") == true
		rookieLabel.Text = "🐣 ROOKIE SHIELD"
		updateRevengeGlow(revengeLeft > 0)
		local blackoutLeft = (workspace:GetAttribute("BlackoutUntil") or 0) - nowT
		blackoutChip.Visible = blackoutLeft > 0
		blackoutLabel.Text = "🌑 BLACKOUT " .. Util.Duration(math.max(blackoutLeft, 0))
		local arcadeLeft = (player:GetAttribute("ArcadeUntil") or 0) - nowT
		arcadeChip.Visible = arcadeLeft > 0
		arcadeLabel.Text = "🔨 SCORE " .. (player:GetAttribute("ArcadeScore") or 0) .. " · " .. math.ceil(math.max(arcadeLeft, 0)) .. "s"
		local towerStart = player:GetAttribute("TowerStart")
		towerChip.Visible = towerStart ~= nil
		towerLabel.Text = string.format("🗼 CLIMB %.1fs", if towerStart then nowT - towerStart else 0)
		local nemesisName = player:GetAttribute("NemesisName")
		nemesisChip.Visible = nemesisName ~= nil
		nemesisLabel.Text = "☠️ " .. (nemesisName or "") .. (if player:GetAttribute("NemesisNear") then " · ⚡ CHASE" else "")
		updateNemesisMark()
		if rainLeft > 0 then
			banner.Visible = true
			bannerText.Text = rainMsg
		elseif eventDef and eventLeft > 0 and nowT - (workspace:GetAttribute("EventStart") or 0) < 12 then
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
		rainKind = kind
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
	elseif prompt.Name == "SellPrompt" or prompt.Name == "MergePrompt" or prompt.Name == "FeedPrompt" then
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
	"Tap 💌 INVITE: you get +10% cash for every friend in your server!",
	"🌟 Play to earn Season XP and claim free rewards in 🌟 SEASON. Tier 30 is the exclusive Starling slime!",
	"⛈️ The SLIME STORM hits every Wednesday and Saturday. Storm-only slimes, 3x luck and 2x cash!",
	"Watch for events: Golden Hour, Lava Storm, Candy Party, Cash Frenzy, Lucky Hour!",
	"During events, meteors can hit your slimes and give them TRAITS like ☄️ Meteor (x4 cash)!",
	"Got spare slimes? Put 3 in the 🧪 FUSE Machine to make a rarer one.",
	"During events, boxes fall into the street. Run and grab them first! 🎁 Lucky Boxes hold free rolls and relics.",
	"Waiting for a rare slime? Go fishing at the 🎣 Goo Pond, play 🔨 Whack-a-Slime or climb the 🗼 Sky Tower!",
	"Equip 🔮 RELICS for combos: lots of Commons + Common Crowd = big income!",
	"During a 🌑 BLACKOUT base locks stop working. Raid in the dark, but avoid the Gloom!",
	"Feed 5 of the same 🍽️ SNACK to a slime and it evolves into a new form that earns way more!",
	"Buy ⬆️ UPGRADES for more income, longer shields and extra pens. They survive rebirth!",
	"Level up by playing. Every level pays cash, and new titles show over your head.",
	"Find more slimes for the 📖 INDEX to unlock big milestone rewards.",
	"Stolen slimes SQUIRM! Tap HOLD ON fast or they slip away and bounce home.",
	"Got robbed? You get REVENGE: the thief's shield can't stop you for 90 seconds.",
	"Thieves get a 💰 bounty. Slap a WANTED player to claim it!",
	"👑 The King Slime shows up every 12 minutes. Slap it with everyone for big cash!",
}
if os.date("!*t").month == 10 then
	table.insert(tips, 1, "🎃 HALLOWEEN UPDATE: Pumpkin, Ghosty and Vampire slimes until Oct 31! Code: SPOOKY")
end
-- Tips trickle in one at a time (after the first-time guide), instead of a wall of toasts.
task.spawn(function()
	task.wait(3)
	for _, tip in tips do
		while player:GetAttribute("TutorialStep") do
			task.wait(1)
		end
		toast("💡 " .. tip, "info")
		task.wait(40)
	end
end)

do
	-- ===== First-time guide: pinned goal + an arrow to the spot =====
	local goal = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -84), -- low on the screen, above the hotbar, so the view stays clear
		Size = UDim2.new(0.9, 0, 0, 58),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
		Parent = gui,
	}, { corner(14), stroke(COLORS.outline, 4), gradient(Color3.fromRGB(255, 210, 80), Color3.fromRGB(255, 140, 40)), new("UISizeConstraint", { MaxSize = Vector2.new(480, 58) }) })
	local goalStep = text({ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 16), Text = "", Parent = goal })
	local goalText = text({ Position = UDim2.fromOffset(10, 20), Size = UDim2.new(1, -20, 0, 34), Text = "", Parent = goal })
	local goalScale = new("UIScale", { Parent = goal })

	local marker = new("Part", { Name = "GuideMarker", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.one })
	local markerAtt = new("Attachment", { Parent = marker })
	local markerGui = new("BillboardGui", { Size = UDim2.fromOffset(90, 90), StudsOffset = Vector3.new(0, 7, 0), AlwaysOnTop = true, Parent = marker })
	text({ Size = UDim2.fromScale(1, 1), Text = "⬇️", TextStrokeTransparency = 1, Parent = markerGui })
	local beam = new("Beam", {
		Attachment1 = markerAtt,
		Color = ColorSequence.new(Color3.fromRGB(255, 220, 80)),
		LightEmission = 1,
		Width0 = 0.6,
		Width1 = 0.6,
		FaceCamera = true,
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		TextureMode = Enum.TextureMode.Static,
		TextureLength = 3,
		TextureSpeed = 2,
		Transparency = NumberSequence.new(0.2),
		Parent = marker,
	})

	local function refreshGoal()
		local step = player:GetAttribute("TutorialStep")
		local target = player:GetAttribute("TutorialTarget")
		goal.Visible = step ~= nil
		if not step then
			marker.Parent = nil
			return
		end
		goalStep.Text = "🧭 GOAL " .. step .. " OF " .. #Config.Tutorial
		goalText.Text = player:GetAttribute("TutorialText") or ""
		goalScale.Scale = 0.45
		TweenService:Create(goalScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 0.6 }):Play()
		if typeof(target) == "Vector3" then
			marker.Position = target
			marker.Parent = workspace
		else
			marker.Parent = nil
		end
	end
	for _, attr in { "TutorialStep", "TutorialTarget" } do
		player:GetAttributeChangedSignal(attr):Connect(refreshGoal)
	end
	refreshGoal()
	RunService.RenderStepped:Connect(function()
		-- Panels sit in the middle of the screen: tuck the goal card away while one is open.
		local panelOpen = false
		for _, pnl in panels do
			panelOpen = panelOpen or pnl.Visible
		end
		goal.Visible = player:GetAttribute("TutorialStep") ~= nil and not panelOpen
		if not marker.Parent then
			return
		end
		markerGui.StudsOffset = Vector3.new(0, 7 + math.sin(os.clock() * 5) * 1, 0)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local att = root and root:FindFirstChild("GuideAttachment")
		if root and not att then
			att = new("Attachment", { Name = "GuideAttachment", Position = Vector3.new(0, -2.5, 0), Parent = root })
		end
		beam.Attachment0 = att :: Attachment?
		-- Hide the trail once you're standing on the spot.
		beam.Enabled = root ~= nil and ((root :: BasePart).Position - marker.Position).Magnitude > 8
	end)
end

