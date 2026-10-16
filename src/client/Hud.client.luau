-- All player-facing UI, built in code: cash HUD, shop, rebirth, toasts and event banner.

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
for _, name in { "Notify", "Rebirth", "Banner" } do
	Remotes:WaitForChild(name)
end

local player = Players.LocalPlayer

local COLORS = {
	bg = Color3.fromRGB(25, 22, 40),
	panel = Color3.fromRGB(40, 35, 65),
	accent = Color3.fromRGB(120, 255, 160),
	gold = Color3.fromRGB(255, 205, 60),
	bad = Color3.fromRGB(255, 90, 100),
	text = Color3.new(1, 1, 1),
	muted = Color3.fromRGB(190, 185, 215),
}
local KIND_COLOR = {
	info = COLORS.text,
	good = COLORS.accent,
	bad = COLORS.bad,
	epic = COLORS.gold,
}

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
	return new("UIStroke", { Color = color or Color3.new(0, 0, 0), Thickness = th or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function text(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextColor3 = props.TextColor3 or COLORS.text
	props.TextScaled = if props.TextScaled == nil then true else props.TextScaled
	return new("TextLabel", props)
end

local function button(props, onClick)
	props.Font = props.Font or Enum.Font.GothamBlack
	props.TextColor3 = props.TextColor3 or Color3.new(0.1, 0.1, 0.1)
	props.TextScaled = true
	props.AutoButtonColor = true
	local b = new("TextButton", props, { corner(10), stroke(Color3.new(0, 0, 0), 2) })
	b.Activated:Connect(onClick)
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
	Size = UDim2.fromOffset(300, 70),
	BackgroundColor3 = COLORS.bg,
	BackgroundTransparency = 0.15,
	Parent = gui,
}, { corner(14), stroke(COLORS.accent, 2) })
local cashLabel = text({ Size = UDim2.new(1, -16, 0.6, 0), Position = UDim2.fromOffset(8, 4), Font = Enum.Font.GothamBlack, TextColor3 = COLORS.accent, Text = "$0", Parent = top })
local incomeLabel = text({ Size = UDim2.new(1, -16, 0.32, 0), Position = UDim2.new(0, 8, 0.62, 0), TextColor3 = COLORS.muted, Text = "+$0/s", Parent = top })

local statusLabel = text({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 84),
	Size = UDim2.fromOffset(420, 26),
	TextColor3 = COLORS.gold,
	TextStrokeTransparency = 0.3,
	Text = "",
	Parent = gui,
})

-- ===== Banner (Slime Rain) =====
local banner = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 116),
	Size = UDim2.new(0.9, 0, 0, 44),
	BackgroundColor3 = Color3.fromRGB(60, 200, 120),
	Visible = false,
	Parent = gui,
}, { corner(12), stroke(Color3.new(0, 0, 0), 2), new("UISizeConstraint", { MaxSize = Vector2.new(520, 44) }) })
local bannerText = text({ Size = UDim2.new(1, -16, 1, -8), Position = UDim2.fromOffset(8, 4), Font = Enum.Font.GothamBlack, Text = "", Parent = banner })

-- ===== Toasts =====
local toastHolder = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -110),
	Size = UDim2.new(0.9, 0, 0, 200),
	BackgroundTransparency = 1,
	Parent = gui,
}, {
	new("UISizeConstraint", { MaxSize = Vector2.new(460, 200) }),
	new("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local toastCount = 0
local function toast(msg: string, kind: string?)
	toastCount += 1
	local f = new("Frame", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = COLORS.bg,
		BackgroundTransparency = 0.1,
		LayoutOrder = toastCount,
		Parent = toastHolder,
	}, { corner(10) })
	text({ Size = UDim2.new(1, -16, 1, -8), Position = UDim2.fromOffset(8, 4), TextColor3 = KIND_COLOR[kind or "info"] or COLORS.text, Text = msg, Parent = f })
	if #toastHolder:GetChildren() > 8 then
		for _, c in toastHolder:GetChildren() do
			if c:IsA("Frame") then
				c:Destroy()
				break
			end
		end
	end
	task.delay(4, function()
		if f.Parent then
			TweenService:Create(f, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
			task.wait(0.3)
			f:Destroy()
		end
	end)
end

-- ===== Panels =====
local function panel(title: string)
	local p = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.92, 0.8),
		BackgroundColor3 = COLORS.bg,
		Visible = false,
		Parent = gui,
	}, { corner(16), stroke(COLORS.accent, 3), new("UISizeConstraint", { MaxSize = Vector2.new(460, 420) }) })
	text({ Size = UDim2.new(1, -60, 0, 36), Position = UDim2.fromOffset(16, 10), Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, Text = title, Parent = p })
	button({ Size = UDim2.fromOffset(36, 36), Position = UDim2.new(1, -46, 0, 10), BackgroundColor3 = COLORS.bad, Text = "X", Parent = p }, function()
		p.Visible = false
	end)
	return p
end

local shop = panel("Shop")
local list = new("ScrollingFrame", {
	Position = UDim2.fromOffset(12, 56),
	Size = UDim2.new(1, -24, 1, -68),
	BackgroundTransparency = 1,
	ScrollBarThickness = 6,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	Parent = shop,
}, { new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })

local function shopRow(order: number, item, isPass: boolean)
	local row = new("Frame", { Size = UDim2.new(1, -8, 0, 64), BackgroundColor3 = COLORS.panel, LayoutOrder = order, Parent = list }, { corner(10) })
	text({ Size = UDim2.new(0.68, -10, 0, 24), Position = UDim2.fromOffset(10, 6), TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBlack, TextColor3 = if isPass then COLORS.gold else COLORS.text, Text = item.name, Parent = row })
	text({ Size = UDim2.new(0.68, -10, 0, 26), Position = UDim2.fromOffset(10, 32), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = COLORS.muted, Font = Enum.Font.Gotham, Text = item.desc, Parent = row })
	local label = if item.id == 0 then "Soon" else ("R$ " .. item.price)
	button({ Size = UDim2.new(0.3, -8, 0, 44), Position = UDim2.new(0.7, 0, 0, 10), BackgroundColor3 = if item.id == 0 then COLORS.muted else COLORS.accent, Text = label, Parent = row }, function()
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
local passKeys = { "DoubleCash", "VIP", "ExtraPens", "AutoCollect" }
local productKeys = { "SmallCash", "BigCash", "HugeCash", "InstantLock", "GrowBoost", "SlimeRain" }
for _, k in passKeys do
	order += 1
	shopRow(order, Config.GamePasses[k], true)
end
for _, k in productKeys do
	order += 1
	shopRow(order, Config.Products[k], false)
end

local rebirth = panel("Rebirth")
local rebirthInfo = text({
	Position = UDim2.fromOffset(20, 64),
	Size = UDim2.new(1, -40, 0, 200),
	TextScaled = false,
	TextSize = 20,
	TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top,
	Font = Enum.Font.GothamMedium,
	Text = "",
	Parent = rebirth,
})
button({ Size = UDim2.new(1, -40, 0, 60), Position = UDim2.new(0, 20, 1, -84), BackgroundColor3 = COLORS.gold, Text = "REBIRTH", Parent = rebirth }, function()
	Remotes.Rebirth:FireServer()
	rebirth.Visible = false
end)

-- ===== Side buttons =====
local side = new("Frame", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 10, 0.5, 0),
	Size = UDim2.fromOffset(110, 140),
	BackgroundTransparency = 1,
	Parent = gui,
}, { new("UIListLayout", { Padding = UDim.new(0, 10) }) })
button({ Size = UDim2.fromOffset(110, 60), BackgroundColor3 = COLORS.gold, Text = "SHOP", Parent = side }, function()
	rebirth.Visible = false
	shop.Visible = not shop.Visible
end)
button({ Size = UDim2.fromOffset(110, 60), BackgroundColor3 = Color3.fromRGB(190, 120, 255), Text = "REBIRTH", Parent = side }, function()
	shop.Visible = false
	rebirth.Visible = not rebirth.Visible
end)

-- ===== Live values =====
local function refresh()
	local cash = player:GetAttribute("Cash") or 0
	local income = player:GetAttribute("Income") or 0
	local rebirths = player:GetAttribute("Rebirths") or 0
	local cost = player:GetAttribute("RebirthCost") or 0
	local slots = player:GetAttribute("Slots") or 0
	local count = player:GetAttribute("SlimeCount") or 0
	local auto = ""
	local bank = player:GetAttribute("Bank") or 0
	if bank >= 1 then
		auto = "  ·  " .. Util.Money(bank) .. " waiting at your green pad"
	end
	cashLabel.Text = Util.Money(cash)
	incomeLabel.Text = "+" .. Util.Money(income) .. "/s  ·  Pens " .. count .. "/" .. slots .. auto
	rebirthInfo.Text = string.format(
		"Rebirth %d → %d\n\nCost: %s (you have %s)\n\nYou keep: +%d%% income forever and +%d pen slots.\nYou lose: your cash and all slimes.",
		rebirths,
		rebirths + 1,
		Util.Money(cost),
		Util.Money(cash),
		math.floor(Config.RebirthIncomeBonus * 100 * (rebirths + 1)),
		Config.SlotsPerRebirth
	)
end
for _, attr in { "Cash", "Income", "Rebirths", "RebirthCost", "Slots", "SlimeCount", "Bank" } do
	player:GetAttributeChangedSignal(attr):Connect(refresh)
end
refresh()

local rainEndsAt = 0
task.spawn(function()
	while true do
		task.wait(0.25)
		local parts = {}
		local carrying = player:GetAttribute("Carrying")
		if carrying then
			table.insert(parts, "Carrying " .. carrying .. "! Run to your base!")
		end
		local lockedUntil = player:GetAttribute("LockedUntil") or 0
		local left = lockedUntil - workspace:GetServerTimeNow()
		if left > 0 then
			table.insert(parts, "Shield up: " .. Util.Duration(left))
		end
		statusLabel.Text = table.concat(parts, "   ·   ")
		local rainLeft = rainEndsAt - os.clock()
		if rainLeft > 0 then
			banner.Visible = true
			bannerText.Text = bannerText:GetAttribute("Msg") .. "  (" .. math.ceil(rainLeft) .. "s)"
		else
			banner.Visible = false
		end
	end
end)

Remotes.Notify.OnClientEvent:Connect(toast)
Remotes.Banner.OnClientEvent:Connect(function(msg, seconds)
	bannerText:SetAttribute("Msg", msg)
	rainEndsAt = os.clock() + seconds
	toast(msg, "epic")
end)

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
	end
end)
for _, d in workspace:GetDescendants() do
	if d:IsA("ProximityPrompt") then
		filterPrompt(d)
	end
end

-- ===== First-time tips =====
local tips = {
	"Buy slimes on the conveyor belt in the middle.",
	"They earn cash every second. Step on your green pad to collect it.",
	"Slimes grow over time, even while you're offline.",
	"Hold E on someone's slime to steal it, then run home!",
	"Press the red button in your base to shield it from thieves.",
}
task.spawn(function()
	task.wait(3)
	for _, tip in tips do
		toast(tip, "info")
		task.wait(4.5)
	end
end)
