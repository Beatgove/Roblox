-- All player-facing UI, built in code: cash HUD, luck timer, rebirth bar, shop, rebirth,
-- codes, Slime Index, toasts and the event banner.

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
for _, name in { "Notify", "Rebirth", "Banner", "RedeemCode" } do
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
	Size = UDim2.fromOffset(600, 30),
	BackgroundTransparency = 1,
	Parent = gui,
}, { new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8) }) })
local function chip(color: Color3)
	local f = new("Frame", { Size = UDim2.fromOffset(190, 30), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false, Parent = chips }, { corner(15), stroke(COLORS.outline, 3), gradient(color, color:Lerp(Color3.new(0, 0, 0), 0.3)) })
	local l = text({ Size = UDim2.new(1, -12, 1, -6), Position = UDim2.fromOffset(6, 3), Text = "", Parent = f })
	return f, l
end
local luckChip, luckLabel = chip(Color3.fromRGB(60, 200, 90))
local shieldChip, shieldLabel = chip(Color3.fromRGB(230, 60, 80))
local carryChip, carryLabel = chip(Color3.fromRGB(255, 170, 30))
local rainChip, rainLabel = chip(Color3.fromRGB(70, 150, 255))

-- ===== Banner (Slime Rain) =====
local banner = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 134),
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

-- ===== Side buttons =====
local side = new("Frame", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 10, 0.5, 0),
	Size = UDim2.fromOffset(120, 300),
	BackgroundTransparency = 1,
	Parent = gui,
}, { new("UIListLayout", { Padding = UDim.new(0, 10) }) })
local shopBtn = button({ Size = UDim2.fromOffset(120, 62), BackgroundColor3 = COLORS.gold, Text = "🛒 SHOP", Parent = side }, function()
	openPanel(shop, shopScale)
end)
button({ Size = UDim2.fromOffset(120, 62), BackgroundColor3 = COLORS.purple, Text = "🔄 REBIRTH", Parent = side }, function()
	openPanel(rebirth, rebirthScale)
end)
button({ Size = UDim2.fromOffset(120, 62), BackgroundColor3 = COLORS.blue, Text = "🎟️ CODES", Parent = side }, function()
	openPanel(codes, codesScale)
end)
button({ Size = UDim2.fromOffset(120, 62), BackgroundColor3 = COLORS.pink, Text = "📖 INDEX", Parent = side }, function()
	openPanel(index, indexScale)
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
		if rainLeft > 0 then
			banner.Visible = true
			bannerText.Text = rainMsg
		else
			banner.Visible = false
		end
	end
end)

Remotes.Notify.OnClientEvent:Connect(toast)
Remotes.Banner.OnClientEvent:Connect(function(msg, seconds)
	rainMsg = msg
	rainEndsAt = os.clock() + seconds
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
	elseif prompt.Name == "SellPrompt" then
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
	"Press the red button in your base to shield it from thieves.",
	"Try the code RELEASE in 🎟️ CODES for free cash and 5x luck!",
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
