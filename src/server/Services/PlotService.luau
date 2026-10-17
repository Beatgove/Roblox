-- Player bases: plot assignment, slimes in pens, growth, income, collecting and locking.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Util = require(game.ReplicatedStorage.Shared.Util)
local DataService = require(script.Parent.DataService)
local Passes = require(script.Parent.Passes)
local SlimeModel = require(script.Parent.SlimeModel)
local Net = require(script.Parent.Net)
local BaseDecor = require(script.Parent.BaseDecor)
local Roller = require(script.Parent.Roller)
local Signals = require(script.Parent.Signals)

local PlotService = {}

type Plot = {
	intruders: { [Player]: number }?,
	model: Model,
	cframe: CFrame,
	owner: Player?,
	slimeFolder: Folder?,
	stages: { number },
	lockedUntil: number,
	lockReadyAt: number,
	paidLockUntil: number,
}

local plots: { Plot } = {}
local plotOf: { [Player]: Plot } = {}

-- Fired when a non-owner triggers a steal prompt: (thief, victim, slotIndex)
PlotService.StealRequested = Instance.new("BindableEvent")
PlotService.FeedRequested = Instance.new("BindableEvent") -- (player, slot) owner fed a snack

-- Pens are round pedestals with a glowing rim (built by MapBuilder under each pad).
local function setPen(pad: Instance, visible: boolean, ringColor: Color3?)
	local pedestal = pad:FindFirstChild("Pedestal") :: BasePart?
	local ring = pad:FindFirstChild("Ring") :: BasePart?
	if pedestal then
		pedestal.Transparency = if visible then 0 else 1
	end
	if ring then
		ring.Transparency = if visible then 0.1 else 1
		if ringColor then
			ring.Color = ringColor
		end
	end
end

local function now()
	return os.time()
end

function PlotService.GetPlot(player: Player): Plot?
	return plotOf[player]
end

function PlotService.AllPlots()
	return plots
end

function PlotService.Slots(player: Player): number
	local data = DataService.Get(player)
	if not data then
		return 0
	end
	local slots = Config.BaseSlots + data.rebirths * Config.SlotsPerRebirth
	if Passes.Owns(player, "ExtraPens") then
		slots += Config.ExtraPensSlots
	end
	slots += PlotService.UpgradeLevel(player, "Pens") * Config.Upgrades.Pens.per
	return math.min(slots, Config.MaxSlots)
end

function PlotService.UpgradeLevel(player: Player, key: string): number
	local data = DataService.Get(player)
	return data and data.upgrades[key] or 0
end

function PlotService.IncomeMultiplier(player: Player): number
	local data = DataService.Get(player)
	local mult = (1 + (data and data.rebirths or 0) * Config.RebirthIncomeBonus) * (1 + PlotService.UpgradeLevel(player, "Income") * Config.Upgrades.Income.per)
	if Passes.Owns(player, "DoubleCash") then
		mult *= 2
	end
	if Passes.Owns(player, "VIP") then
		mult *= 1.25
	end
	if data then
		mult *= 1 + PlotService.IndexCount(player) * Config.IndexBonusPerSlime
		mult *= 1 + Config.RelicIncomeBonus(data)
	end
	return mult * PlotService.BoostMultiplier(player)
end

-- Temporary/social boosts on top of permanent ones: friends in the server, Premium, Cash Frenzy.
function PlotService.BoostMultiplier(player: Player): number
	local friend = player:GetAttribute("FriendBoost")
	local mult = 1 + (if typeof(friend) == "number" then friend else 0)
	if player.MembershipType == Enum.MembershipType.Premium then
		mult += Config.PremiumBoost
	end
	local event = Roller.ActiveEvent()
	if event and Config.Events[event].incomeMult then
		mult *= Config.Events[event].incomeMult
	end
	return mult
end

function PlotService.SlimeIncome(slime, at: number?): number
	local def = Config.SlimeById[slime.id]
	local stage = Util.Stage((at or now()) - slime.born)
	return def.income * Config.GrowthIncomeMult[stage] * Config.MutationMult(slime.mut) * Config.StarMult(slime.stars) * Config.TraitMult(slime.traits) * Config.DietMult(slime.diet)
end

function PlotService.IndexCount(player: Player): number
	local data = DataService.Get(player)
	local n = 0
	if data then
		for _ in data.index do
			n += 1
		end
	end
	return n
end

function PlotService.LuckUntil(player: Player): number
	local data = DataService.Get(player)
	return data and data.luckUntil or 0
end

function PlotService.RollCost(player: Player): number
	return math.max(Config.DispenserMinCost, math.floor(PlotService.IncomePerSecond(player) * Config.DispenserIncomeSeconds))
end

function PlotService.IncomePerSecond(player: Player): number
	local data = DataService.Get(player)
	if not data then
		return 0
	end
	local total = 0
	local t = now()
	for _, s in data.slimes do
		total += PlotService.SlimeIncome(s, t)
	end
	return total * PlotService.IncomeMultiplier(player)
end

-- Slimes taken from a player that haven't landed anywhere yet (carried or bouncing home).
-- Rebirth waits for these so nothing can be smuggled into a fresh base.
local inTransit: { [Player]: number } = {}
function PlotService.Transit(player: Player, delta: number)
	inTransit[player] = math.max((inTransit[player] or 0) + delta, 0)
end

-- Adds a slime, or pays its sell value if the pens are full, so a slime is never lost.
function PlotService.AddOrPay(player: Player, slime): boolean
	if PlotService.AddSlime(player, slime) then
		return true
	end
	local value = PlotService.SellValue(slime)
	PlotService.AddCash(player, value)
	Net.Notify(player, "Your pens were full, so your " .. slime.id .. " was sold for " .. Util.Money(value) .. ".", "info")
	return false
end

-- New players can't be robbed until they've found their feet (see Config.RookieEarnedLimit).
function PlotService.IsRookie(player: Player): boolean
	local data = DataService.Get(player)
	return data ~= nil and not data.rookieOff and data.rebirths == 0 and data.totalEarned < Config.RookieEarnedLimit
end

-- Blackout: the power is out and free base locks stop working (bought shields still hold).
function PlotService.IsBlackout(): boolean
	return (workspace:GetAttribute("BlackoutUntil") or 0) > workspace:GetServerTimeNow()
end

function PlotService.IsLocked(plot: Plot): boolean
	if PlotService.IsBlackout() then
		return plot.paidLockUntil > now()
	end
	return plot.lockedUntil > now()
end

-- Pushes attribute values the client HUD reads.
function PlotService.Sync(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	player:SetAttribute("Cash", data.cash)
	player:SetAttribute("Bank", data.bank)
	player:SetAttribute("Income", PlotService.IncomePerSecond(player))
	player:SetAttribute("Rebirths", data.rebirths)
	player:SetAttribute("RebirthCost", Config.RebirthCost(data.rebirths))
	player:SetAttribute("Slots", PlotService.Slots(player))
	player:SetAttribute("SlimeCount", #data.slimes)
	player:SetAttribute("LuckUntil", data.luckUntil)
	player:SetAttribute("RollCost", PlotService.RollCost(player))
	player:SetAttribute("Boost", PlotService.BoostMultiplier(player))
	local rookie = PlotService.IsRookie(player)
	if player:GetAttribute("Rookie") == true and not rookie and not data.rookieOff then
		Net.Notify(player, "🐣 Your Rookie Shield wore off. Guard your slimes, thieves can raid you now!", "bad")
		Net.Fx(player, "rookieEnd", {})
	end
	player:SetAttribute("Rookie", rookie)
	local ups = {}
	for _, key in Config.UpgradeOrder do
		table.insert(ups, key .. "=" .. (data.upgrades[key] or 0))
	end
	player:SetAttribute("Upgrades", table.concat(ups, ","))
	-- Compact list of owned slimes for menus (Fuse Machine picker).
	local owned = {}
	for i, sl in data.slimes do
		owned[i] = { id = sl.id, mut = sl.mut, stars = sl.stars, traits = sl.traits, diet = sl.diet }
	end
	player:SetAttribute("SlimeList", HttpService:JSONEncode(owned))
	local ids = {}
	for id in data.index do
		table.insert(ids, id)
	end
	player:SetAttribute("IndexList", table.concat(ids, ","))
	local plot = plotOf[player]
	if plot then
		player:SetAttribute("LockedUntil", plot.lockedUntil)
		local bank = plot.model.Collector:FindFirstChild("Bank", true)
		if bank then
			bank.Text = Util.Money(data.bank)
		end
	end
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		ls.Cash.Value = Util.Money(data.cash)
		ls.Rebirths.Value = data.rebirths
	end
end

function PlotService.AddCash(player: Player, amount: number)
	local data = DataService.Get(player)
	if not data then
		return
	end
	data.cash += amount
	data.totalEarned += math.max(0, amount)
	PlotService.Sync(player)
end

local function slimeLabelInfo(slime, player: Player): string
	local age = now() - slime.born
	local stage = Util.Stage(age)
	local income = PlotService.SlimeIncome(slime) * PlotService.IncomeMultiplier(player)
	local nextIn = Util.TimeToNextStage(age)
	local text = Util.Money(income) .. "/s · " .. Config.GrowthNames[stage]
	if nextIn then
		text ..= " · grows in " .. Util.Duration(nextIn)
	end
	-- Snack progress toward a diet form.
	if not slime.diet and slime.food then
		for _, key in Config.SnackOrder do
			local n = slime.food[key]
			if n and n > 0 then
				text ..= " · " .. Config.Snacks[key].icon .. " " .. n .. "/" .. Config.SnackEvolve
			end
		end
	end
	return text
end

-- Rebuilds every slime model in a player's pens.
function PlotService.Render(player: Player)
	local plot = plotOf[player]
	local data = DataService.Get(player)
	if not plot or not data then
		return
	end
	if plot.slimeFolder then
		plot.slimeFolder:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Slimes"
	folder.Parent = plot.model
	plot.slimeFolder = folder
	plot.stages = {}

	local slots = PlotService.Slots(player)
	local theme = plot.model:GetAttribute("Theme")
	local emptyRing = if typeof(theme) == "Color3" then theme:Lerp(Color3.new(1, 1, 1), 0.35) else Color3.new(1, 1, 1)
	for _, pad in plot.model.Pens:GetChildren() do
		local slot = pad:GetAttribute("Slot")
		local slime = data.slimes[slot]
		setPen(pad, slot <= slots, if slime then Config.RarityByName[Config.SlimeById[slime.id].rarity].color else emptyRing)
	end

	for i, slime in data.slimes do
		local pad = plot.model.Pens:FindFirstChild("Pen" .. i)
		if not pad then
			continue
		end
		local stage = Util.Stage(now() - slime.born)
		plot.stages[i] = stage
		local model = SlimeModel.Create(slime.id, stage, slime.mut, slime.stars, slime.traits, slime.diet)
		local height = model.PrimaryPart.Size.Y / 2
		-- Face the entrance (plot -Z) so slimes look at visitors.
		model:PivotTo(pad.CFrame * CFrame.new(0, 0.2 + height, 0))
		model:SetAttribute("Slot", i)
		model:SetAttribute("OwnerId", player.UserId)
		model.PrimaryPart.Label.Info.Text = slimeLabelInfo(slime, player)
		CollectionService:AddTag(model, "PenSlime")

		local steal = Instance.new("ProximityPrompt")
		steal.Name = "StealPrompt"
		steal.ActionText = "Steal"
		steal.ObjectText = Config.DisplayName(slime.id, slime.mut, slime.stars, slime.traits, slime.diet)
		steal.HoldDuration = Config.StealHoldSeconds
		steal.MaxActivationDistance = 8
		steal.RequiresLineOfSight = false
		steal.KeyboardKeyCode = Enum.KeyCode.E
		steal:SetAttribute("OwnerId", player.UserId)
		steal.Parent = model.PrimaryPart

		local sell = Instance.new("ProximityPrompt")
		sell.Name = "SellPrompt"
		sell.ActionText = "Sell " .. Util.Money(PlotService.SellValue(slime))
		sell.ObjectText = Config.DisplayName(slime.id, slime.mut, slime.stars, slime.traits, slime.diet)
		sell.HoldDuration = 1
		sell.MaxActivationDistance = 8
		sell.RequiresLineOfSight = false
		sell.KeyboardKeyCode = Enum.KeyCode.F
		sell:SetAttribute("OwnerId", player.UserId)
		sell.Parent = model.PrimaryPart

		steal.Triggered:Connect(function(who)
			if who ~= player then
				PlotService.StealRequested:Fire(who, player, model:GetAttribute("Slot"))
			end
		end)
		sell.Triggered:Connect(function(who)
			if who == player then
				PlotService.Sell(player, model:GetAttribute("Slot"))
			end
		end)

		-- Feed prompt until the slime has evolved into a diet form.
		if not slime.diet then
			local feed = Instance.new("ProximityPrompt")
			feed.Name = "FeedPrompt"
			feed.ActionText = "Feed Snack"
			feed.ObjectText = Config.DisplayName(slime.id, slime.mut, slime.stars, slime.traits)
			feed.HoldDuration = 0.25
			feed.MaxActivationDistance = 8
			feed.RequiresLineOfSight = false
			feed.KeyboardKeyCode = Enum.KeyCode.G
			feed.GamepadKeyCode = Enum.KeyCode.ButtonY
			feed.UIOffset = Vector2.new(0, -80)
			feed:SetAttribute("OwnerId", player.UserId)
			feed.Parent = model.PrimaryPart
			feed.Triggered:Connect(function(who)
				if who == player then
					PlotService.FeedRequested:Fire(player, model:GetAttribute("Slot"))
				end
			end)
		end

		-- Merge prompt only when this slime has enough identical partners.
		if #PlotService.MergeGroup(data, i) >= Config.MergeCount then
			local merge = Instance.new("ProximityPrompt")
			merge.Name = "MergePrompt"
			merge.ActionText = "MERGE 3 → " .. string.rep("★", (slime.stars or 0) + 1)
			merge.ObjectText = Config.DisplayName(slime.id, nil, slime.stars)
			merge.HoldDuration = 0.8
			merge.MaxActivationDistance = 8
			merge.RequiresLineOfSight = false
			merge.KeyboardKeyCode = Enum.KeyCode.R
			merge.UIOffset = Vector2.new(0, 80)
			merge:SetAttribute("OwnerId", player.UserId)
			merge.Parent = model.PrimaryPart
			merge.Triggered:Connect(function(who)
				if who == player then
					PlotService.Merge(player, model:GetAttribute("Slot"))
				end
			end)
		end

		model.Parent = folder
	end
	PlotService.Sync(player)
end

function PlotService.HasFreeSlot(player: Player): boolean
	local data = DataService.Get(player)
	return data ~= nil and #data.slimes < PlotService.Slots(player)
end

function PlotService.SellValue(slime): number
	return math.floor(Config.SlimeById[slime.id].price * Config.MutationMult(slime.mut) * Config.TraitMult(slime.traits) * Config.DietMult(slime.diet) * (Config.MergeCount ^ (slime.stars or 0)) / 2)
end

-- Slots of slimes that can merge with the one in `slot` (same name, same stars), including itself.
function PlotService.MergeGroup(data, slot: number): { number }
	local base = data.slimes[slot]
	if not base or (base.stars or 0) >= Config.MaxStars then
		return {}
	end
	local group = { slot }
	for i, s in data.slimes do
		if #group >= Config.MergeCount then
			break
		end
		if i ~= slot and s.id == base.id and (s.stars or 0) == (base.stars or 0) and s.diet == base.diet then
			table.insert(group, i)
		end
	end
	return group
end

-- Fuses 3 identical slimes into one with an extra star. Keeps the oldest age and the best mutation.
function PlotService.Merge(player: Player, slot: number)
	local data = DataService.Get(player)
	local plot = plotOf[player]
	if not data or not plot then
		return
	end
	local group = PlotService.MergeGroup(data, slot)
	if #group < Config.MergeCount then
		Net.Notify(player, "You need " .. Config.MergeCount .. " of the same slime to merge.", "bad")
		return
	end
	local positions = {}
	local born = math.huge
	local bestMut, bestMult = nil, 1
	local traitSet = {}
	for _, i in group do
		local s = data.slimes[i]
		born = math.min(born, s.born)
		for _, t in s.traits or {} do
			traitSet[t] = true
		end
		if Config.MutationMult(s.mut) > bestMult then
			bestMut, bestMult = s.mut, Config.MutationMult(s.mut)
		end
		local pad = plot.model.Pens:FindFirstChild("Pen" .. i)
		if pad then
			table.insert(positions, pad.Position)
		end
	end
	local base = data.slimes[slot]
	-- Traits from all three carry over (best ones first, up to the cap).
	local traits = {}
	for t in traitSet do
		table.insert(traits, t)
	end
	table.sort(traits, function(a, b)
		return Config.Traits[a].mult > Config.Traits[b].mult
	end)
	while #traits > Config.MaxTraits do
		table.remove(traits)
	end
	local merged = { id = base.id, born = born, mut = bestMut, stars = (base.stars or 0) + 1, traits = if #traits > 0 then traits else nil, diet = base.diet }
	table.sort(group, function(a, b)
		return a > b
	end)
	for _, i in group do
		table.remove(data.slimes, i)
	end
	table.insert(data.slimes, merged)
	PlotService.Render(player)
	local pad = plot.model.Pens:FindFirstChild("Pen" .. #data.slimes)
	local name = Config.DisplayName(merged.id, merged.mut, merged.stars, merged.traits, merged.diet)
	Net.FxAll("merge", { from = positions, to = pad and pad.Position or positions[1], color = Config.RarityByName[Config.SlimeById[merged.id].rarity].color })
	Net.Fx(player, "merged", { name = name, stars = merged.stars })
	Signals.Progress(player, "merge")
	Net.Notify(player, "MERGED! " .. name .. " earns " .. Util.Money(PlotService.SlimeIncome(merged) * PlotService.IncomeMultiplier(player)) .. "/s", "epic")
	if merged.stars >= 2 then
		Net.NotifyAll(player.DisplayName .. " merged a " .. name .. "!", "epic")
	end
end

-- World position of the pen a newly added slime would go in.
function PlotService.NextPenPosition(player: Player): Vector3?
	local plot = plotOf[player]
	local data = DataService.Get(player)
	if not plot or not data then
		return nil
	end
	local pad = plot.model.Pens:FindFirstChild("Pen" .. (#data.slimes + 1))
	return pad and pad.Position
end

function PlotService.AddSlime(player: Player, slime): boolean
	local data = DataService.Get(player)
	if not data or not PlotService.HasFreeSlot(player) then
		return false
	end
	table.insert(data.slimes, slime)
	PlotService.Render(player)
	local plot = plotOf[player]
	local pad = plot and plot.model.Pens:FindFirstChild("Pen" .. #data.slimes)
	local rarity = Config.RarityByName[Config.SlimeById[slime.id].rarity]
	if pad then
		Net.FxAll("land", { pos = pad.Position, color = rarity.color, big = rarity.order >= 5 })
	end
	if not data.index[slime.id] then
		data.index[slime.id] = true
		PlotService.Sync(player)
		Net.Notify(player, "📖 NEW! " .. slime.id .. " added to your Slime Index (+1% income)", "epic")
		Signals.Progress(player, "index", PlotService.IndexCount(player))
	end
	return true
end

function PlotService.RemoveSlime(player: Player, slot: number)
	local data = DataService.Get(player)
	if not data or not data.slimes[slot] then
		return nil
	end
	local slime = table.remove(data.slimes, slot)
	PlotService.Render(player)
	return slime
end

function PlotService.Sell(player: Player, slot: number)
	local data = DataService.Get(player)
	local slime = data and data.slimes[slot]
	if not slime then
		return
	end
	PlotService.RemoveSlime(player, slot)
	local value = PlotService.SellValue(slime)
	PlotService.AddCash(player, value)
	Net.Notify(player, "Sold " .. slime.id .. " for " .. Util.Money(value), "good")
end

function PlotService.Lock(player: Player, seconds: number, ignoreCooldown: boolean?)
	local plot = plotOf[player]
	if not plot then
		return false
	end
	local t = now()
	if not ignoreCooldown and (PlotService.IsLocked(plot) or t < plot.lockReadyAt) then
		return false
	end
	if not ignoreCooldown and PlotService.IsBlackout() then
		return false
	end
	plot.lockedUntil = math.max(plot.lockedUntil, t) + seconds
	plot.lockReadyAt = plot.lockedUntil + Config.LockCooldownSeconds
	if ignoreCooldown then
		plot.paidLockUntil = math.max(plot.paidLockUntil, t) + seconds
	end
	PlotService.Sync(player)
	return true
end

-- Grows every slime one stage by moving its birth time back.
function PlotService.GrowAll(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local t = now()
	for _, s in data.slimes do
		local toNext = Util.TimeToNextStage(t - s.born)
		if toNext then
			s.born -= toNext
		end
	end
	PlotService.Render(player)
end

function PlotService.Rebirth(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	if player:GetAttribute("Carrying") or (inTransit[player] or 0) > 0 then
		Net.Notify(player, "Finish the chase first! You can't rebirth while a slime is on the move.", "bad")
		return
	end
	if data.fuse.active then
		Net.Notify(player, "Claim your Fuse Machine slime before you rebirth!", "bad")
		return
	end
	local cost = Config.RebirthCost(data.rebirths)
	if data.cash < cost then
		Net.Notify(player, "You need " .. Util.Money(cost) .. " to rebirth", "bad")
		return
	end
	data.rebirths += 1
	data.cash = Config.StartingCash
	data.bank = 0
	data.slimes = {}
	-- Relics are per run: a fresh set every rebirth.
	data.relics = {}
	data.relicBag = {}
	PlotService.Render(player)
	local plot = plotOf[player]
	if plot then
		BaseDecor.Apply(plot.model, plot.cframe, data.rebirths, data.baseSkin)
		Net.FxAll("baseUpgrade", { pos = plot.cframe.Position })
		Signals.Progress(player, "rebirth")
	end
	local unlocked
	for _, t in BaseDecor.Tiers do
		if t.rebirth == data.rebirths then
			unlocked = t.name
		end
	end
	if unlocked then
		Net.Notify(player, "🏰 Your base got an upgrade: " .. unlocked .. "!", "epic")
	end
	Net.Fx(player, "rebirth", { n = data.rebirths })
	Net.Notify(player, "REBIRTH " .. data.rebirths .. "! Income is now x" .. PlotService.IncomeMultiplier(player), "epic")
	Net.NotifyAll(player.DisplayName .. " reached Rebirth " .. data.rebirths .. "!", "epic")
end

local function setOwnerSign(plot: Plot)
	local label = plot.model.Sign.OwnerGui.Text
	label.Text = if plot.owner then plot.owner.DisplayName .. "'s Base" else "Empty Base"
	local facade = plot.model:FindFirstChild("FacadeSign", true)
	local facadeText = facade and facade:FindFirstChild("Text", true) :: TextLabel?
	if facadeText then
		facadeText.Text = label.Text
	end
	local avatar = plot.model.Sign.OwnerGui:FindFirstChild("Avatar") :: ImageLabel?
	if avatar then
		avatar.Image = ""
		avatar.Visible = plot.owner ~= nil
		local owner = plot.owner
		if owner then
			task.spawn(function()
				local ok, image = pcall(Players.GetUserThumbnailAsync, Players, owner.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
				if ok and plot.owner == owner then
					avatar.Image = image
				end
			end)
		end
	end
end

local function teleportHome(player: Player)
	local plot = plotOf[player]
	local char = player.Character
	if plot and char then
		char:PivotTo(plot.model.SpawnPoint.CFrame)
	end
end

local function inPlot(plot: Plot, position: Vector3): boolean
	local localPos = plot.cframe:PointToObjectSpace(position)
	local half = 34 -- MapBuilder.PlotSize / 2
	return math.abs(localPos.X) <= half and math.abs(localPos.Z) <= half and localPos.Y < 22
end
PlotService.InPlot = inPlot

-- Base skins you've unlocked (by Slime Index count), in Config order.
function PlotService.UnlockedSkins(player: Player)
	local count = PlotService.IndexCount(player)
	local list = {}
	for _, skin in Config.BaseSkins do
		if count >= skin.need then
			table.insert(list, skin)
		end
	end
	return list
end

local function skinLabel(plot: Plot)
	local label = plot.model.SkinStand:FindFirstChild("SkinLabel", true) :: TextLabel?
	local data = if plot.owner then DataService.Get(plot.owner) else nil
	if label then
		local name = "Classic"
		for _, skin in Config.BaseSkins do
			if data and skin.key == data.baseSkin then
				name = skin.name
			end
		end
		label.Text = "🎨 " .. name
	end
end

local function setupPlotInteractions(plot: Plot)
	local collector = plot.model.Collector
	local debounce = false
	collector.Touched:Connect(function(hit)
		local owner = plot.owner
		if debounce or not owner or not owner.Character or not hit:IsDescendantOf(owner.Character) then
			return
		end
		local data = DataService.Get(owner)
		if not data or data.bank < 1 then
			return
		end
		debounce = true
		local amount = math.floor(data.bank)
		data.bank -= amount
		PlotService.AddCash(owner, amount)
		Signals.Progress(owner, "collect", amount)
		Net.Fx(owner, "collect", { pos = collector.Position, amount = amount })
		task.delay(0.5, function()
			debounce = false
		end)
	end)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LockPrompt"
	prompt.ActionText = "Lock Base"
	prompt.ObjectText = "Shield"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = plot.model.LockButton
	prompt.Triggered:Connect(function(who)
		if who ~= plot.owner then
			return
		end
		local data = DataService.Get(who)
		local rebirthBonus = (if data then data.rebirths else 0) * Config.RebirthLockBonus
		local seconds = (Config.LockSeconds + rebirthBonus + PlotService.UpgradeLevel(who, "Shield") * Config.Upgrades.Shield.per) * (if Passes.Owns(who, "VIP") then 2 else 1)
		if PlotService.IsBlackout() and not PlotService.IsLocked(plot) then
			Net.Notify(who, "⚡ The power is out! Locks don't work during the Blackout.", "bad")
			Net.Fx(who, "deny", {})
		elseif PlotService.Lock(who, seconds) then
			Signals.Progress(who, "lock")
			Net.Notify(who, "Base locked for " .. seconds .. "s", "good")
		else
			local wait = math.max(plot.lockedUntil, plot.lockReadyAt) - now()
			Net.Notify(who, "Lock ready in " .. Util.Duration(wait), "bad")
		end
	end)

	-- 🎨 Skin stand: cycles through the base skins you've unlocked.
	local skinPrompt = Instance.new("ProximityPrompt")
	skinPrompt.Name = "SkinPrompt"
	skinPrompt.ActionText = "Change Skin"
	skinPrompt.ObjectText = "Base Skin"
	skinPrompt.HoldDuration = 0
	skinPrompt.MaxActivationDistance = 8
	skinPrompt.RequiresLineOfSight = false
	skinPrompt.Parent = plot.model.SkinStand
	skinPrompt.Triggered:Connect(function(who)
		local data = DataService.Get(who)
		if who ~= plot.owner or not data then
			return
		end
		local list = PlotService.UnlockedSkins(who)
		local at = 1
		for i, skin in list do
			if skin.key == data.baseSkin then
				at = i
			end
		end
		local skin = list[at % #list + 1]
		data.baseSkin = skin.key
		BaseDecor.Apply(plot.model, plot.cframe, data.rebirths, skin.key)
		skinLabel(plot)
		Net.Fx(who, "baseUpgrade", { pos = plot.cframe.Position })
		local nextSkin
		for _, s in Config.BaseSkins do
			if not nextSkin and s.need > PlotService.IndexCount(who) then
				nextSkin = s
			end
		end
		Net.Notify(who, "🎨 Base skin: " .. skin.name .. (if nextSkin then " · Next: " .. nextSkin.name .. " at " .. nextSkin.need .. " slimes in your Index" else ""), "good")
	end)
end

function PlotService.Assign(player: Player)
	for _, plot in plots do
		if not plot.owner then
			plot.owner = player
			plot.lockedUntil = 0
			plot.lockReadyAt = 0
			plot.paidLockUntil = 0
			plotOf[player] = plot
			setOwnerSign(plot)
			local data = DataService.Get(player)
			BaseDecor.Apply(plot.model, plot.cframe, if data then data.rebirths else 0, if data then data.baseSkin else nil)
			player:SetAttribute("PlotIndex", plot.model:GetAttribute("Index"))
			if data then
				local ok = false
				for _, skin in PlotService.UnlockedSkins(player) do
					ok = ok or skin.key == data.baseSkin
				end
				if not ok then
					data.baseSkin = "Classic"
				end
			end
			skinLabel(plot)
			PlotService.Render(player)
			player.CharacterAdded:Connect(function(char)
				char:WaitForChild("HumanoidRootPart", 10)
				task.wait()
				teleportHome(player)
			end)
			if player.Character then
				teleportHome(player)
			end
			return plot
		end
	end
	warn("[PlotService] no free plot for", player.Name)
	return nil
end

function PlotService.Release(player: Player)
	inTransit[player] = nil
	local plot = plotOf[player]
	if not plot then
		return
	end
	if plot.slimeFolder then
		plot.slimeFolder:Destroy()
		plot.slimeFolder = nil
	end
	for _, pad in plot.model.Pens:GetChildren() do
		setPen(pad, false)
	end
	plot.owner = nil
	plot.intruders = nil
	plot.lockedUntil = 0
	plot.paidLockUntil = 0
	local relics = plot.model:FindFirstChild("Relics")
	if relics then
		relics:Destroy()
	end
	plotOf[player] = nil
	BaseDecor.Apply(plot.model, plot.cframe, 0)
	skinLabel(plot)
	setOwnerSign(plot)
end

function PlotService.Start(builtPlots)
	for _, p in builtPlots do
		local plot: Plot = {
			model = p.model,
			cframe = p.cframe,
			owner = nil,
			slimeFolder = nil,
			stages = {},
			lockedUntil = 0,
			lockReadyAt = 0,
			paidLockUntil = 0,
		}
		table.insert(plots, plot)
		setupPlotInteractions(plot)
		-- The doorway blocks everyone in the default group while locked; the owner's
		-- character is moved into this plot's Pass group so it walks straight through.
		local i = #plots
		PhysicsService:RegisterCollisionGroup("Door" .. i)
		PhysicsService:RegisterCollisionGroup("Pass" .. i)
		PhysicsService:CollisionGroupSetCollidable("Door" .. i, "Pass" .. i, false)
		local door = plot.model:FindFirstChild("Door") :: BasePart?
		if door then
			door.CollisionGroup = "Door" .. i
		end
	end

	-- Income tick.
	task.spawn(function()
		while true do
			task.wait(1)
			for player, _ in plotOf do
				local data = DataService.Get(player)
				if data then
					local income = PlotService.IncomePerSecond(player)
					if Passes.Owns(player, "AutoCollect") then
						data.cash += income
						data.totalEarned += income
						Signals.Progress(player, "collect", income)
					else
						data.bank += income
					end
					PlotService.Sync(player)
				end
			end
		end
	end)

	-- Growth, labels and lock visuals.
	task.spawn(function()
		while true do
			task.wait(5)
			for player, plot in plotOf do
				local data = DataService.Get(player)
				if not data then
					continue
				end
				local grew = false
				for i, s in data.slimes do
					if Util.Stage(now() - s.born) ~= plot.stages[i] then
						grew = true
						break
					end
				end
				if grew then
					PlotService.Render(player)
					Net.Fx(player, "grow", {})
					Net.Notify(player, "Your slimes grew! Income is up.", "good")
				elseif plot.slimeFolder then
					for _, m in plot.slimeFolder:GetChildren() do
						local s = data.slimes[m:GetAttribute("Slot")]
						if s then
							m.PrimaryPart.Label.Info.Text = slimeLabelInfo(s, player)
						end
					end
				end
			end
		end
	end)

	-- Which plot's door each character walks through: their own, or the base they're
	-- taking revenge on.
	local function passGroup(player: Player): string
		local target: Plot? = plotOf[player]
		local revengeId = player:GetAttribute("RevengeUserId")
		if revengeId and (player:GetAttribute("RevengeUntil") or 0) > workspace:GetServerTimeNow() then
			for _, p in plots do
				if p.owner and p.owner.UserId == revengeId then
					target = p
				end
			end
		end
		return if target then "Pass" .. (table.find(plots, target) or 0) else "Default"
	end
	local function setGroup(char: Model, group: string)
		if char:GetAttribute("PassGroup") == group then
			return
		end
		char:SetAttribute("PassGroup", group)
		for _, d in char:GetDescendants() do
			if d:IsA("BasePart") then
				d.CollisionGroup = group
			end
		end
	end
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(char)
			char.DescendantAdded:Connect(function(d)
				local group = char:GetAttribute("PassGroup")
				if d:IsA("BasePart") and type(group) == "string" then
					d.CollisionGroup = group
				end
			end)
		end)
	end)

	-- Lock visuals and pushing intruders out of locked bases.
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, player in Players:GetPlayers() do
				if player.Character then
					setGroup(player.Character, passGroup(player))
				end
			end
			for _, plot in plots do
				local locked = plot.owner ~= nil and PlotService.IsLocked(plot)
				local door = plot.model:FindFirstChild("Door") :: BasePart?
				if door then
					door.CanCollide = locked
				end
				for _, wall in plot.model.Shield:GetChildren() do
					wall.Transparency = if locked then 0.85 else 1
				end
				local lasers = plot.model:FindFirstChild("Lasers")
				if lasers then
					for _, d in lasers:GetDescendants() do
						if d:IsA("Beam") then
							d.Enabled = locked
						elseif d:IsA("BasePart") then
							d.Transparency = if locked then 0 else 1
						end
					end
				end
				-- Sirens on the towers spin while someone is running off with one of your slimes.
				local robbed = false
				if plot.owner then
					for _, other in Players:GetPlayers() do
						if other:GetAttribute("StealingFrom") == plot.owner.UserId then
							robbed = true
						end
					end
				end
				local start = plot.model:FindFirstChild("StartDecor")
				if start then
					for _, d in start:GetChildren() do
						if d.Name == "Siren" and d:IsA("BasePart") then
							d.Transparency = if robbed then 0 else 1
							local light = d:FindFirstChildOfClass("SpotLight")
							if light then
								light.Enabled = robbed
							end
						end
					end
				end
				-- Heads-up when another player walks into your base.
				if plot.owner and not locked then
					plot.intruders = plot.intruders or {}
					for _, other in Players:GetPlayers() do
						local char = if other ~= plot.owner then other.Character else nil
						local root = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
						local inside = root ~= nil and inPlot(plot, root.Position)
						local seen = plot.intruders[other]
						if inside and not seen then
							plot.intruders[other] = os.clock()
							if not PlotService.IsRookie(plot.owner) then
								Net.Notify(plot.owner, "👀 " .. other.DisplayName .. " just walked into your base!", "bad")
								Net.Fx(plot.owner, "intruder", { name = other.DisplayName })
							end
						elseif not inside and seen and os.clock() - seen > 20 then
							plot.intruders[other] = nil -- leave for 20 s and the next visit alerts again
						end
					end
				end
				local status = plot.model.LockButton:FindFirstChild("Status", true)
				if status then
					status.Text = if locked
						then "LOCKED " .. Util.Duration((if PlotService.IsBlackout() then plot.paidLockUntil else plot.lockedUntil) - now())
						elseif plot.owner and PlotService.IsBlackout() and not PlotService.IsRookie(plot.owner) then "⚡ POWER OUT"
						elseif plot.owner and PlotService.IsRookie(plot.owner) then "🐣 ROOKIE SHIELD"
						elseif plot.owner and now() < plot.lockReadyAt then "Ready in " .. Util.Duration(plot.lockReadyAt - now())
						else "LOCK BASE"
				end
				if locked then
					for _, other in Players:GetPlayers() do
						local avenging = plot.owner ~= nil and other:GetAttribute("RevengeUserId") == plot.owner.UserId and (other:GetAttribute("RevengeUntil") or 0) > workspace:GetServerTimeNow()
						local root = other ~= plot.owner and not avenging and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
						if root and inPlot(plot, root.Position) then
							other.Character:PivotTo(plot.cframe * CFrame.new(0, 4, -46))
							Net.Notify(other, "That base is shielded!", "bad")
						end
					end
				end
			end
		end
	end)
end

return PlotService
