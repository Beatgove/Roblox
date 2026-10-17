-- Player bases: plot assignment, slimes in pens, growth, income, collecting and locking.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

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
	model: Model,
	cframe: CFrame,
	owner: Player?,
	slimeFolder: Folder?,
	stages: { number },
	lockedUntil: number,
	lockReadyAt: number,
}

local plots: { Plot } = {}
local plotOf: { [Player]: Plot } = {}

-- Fired when a non-owner triggers a steal prompt: (thief, victim, slotIndex)
PlotService.StealRequested = Instance.new("BindableEvent")

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
	return def.income * Config.GrowthIncomeMult[stage] * Config.MutationMult(slime.mut) * Config.StarMult(slime.stars) * Config.TraitMult(slime.traits)
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

function PlotService.IsLocked(plot: Plot): boolean
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
		owned[i] = { id = sl.id, mut = sl.mut, stars = sl.stars, traits = sl.traits }
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
	for _, pad in plot.model.Pens:GetChildren() do
		local slot = pad:GetAttribute("Slot")
		pad.Transparency = if slot <= slots then 0 else 1
	end

	for i, slime in data.slimes do
		local pad = plot.model.Pens:FindFirstChild("Pen" .. i)
		if not pad then
			continue
		end
		local stage = Util.Stage(now() - slime.born)
		plot.stages[i] = stage
		local model = SlimeModel.Create(slime.id, stage, slime.mut, slime.stars, slime.traits)
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
		steal.ObjectText = Config.DisplayName(slime.id, slime.mut, slime.stars, slime.traits)
		steal.HoldDuration = Config.StealHoldSeconds
		steal.MaxActivationDistance = 8
		steal.RequiresLineOfSight = false
		steal.KeyboardKeyCode = Enum.KeyCode.E
		steal:SetAttribute("OwnerId", player.UserId)
		steal.Parent = model.PrimaryPart

		local sell = Instance.new("ProximityPrompt")
		sell.Name = "SellPrompt"
		sell.ActionText = "Sell " .. Util.Money(PlotService.SellValue(slime))
		sell.ObjectText = Config.DisplayName(slime.id, slime.mut, slime.stars, slime.traits)
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
	return math.floor(Config.SlimeById[slime.id].price * Config.MutationMult(slime.mut) * Config.TraitMult(slime.traits) * (Config.MergeCount ^ (slime.stars or 0)) / 2)
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
		if i ~= slot and s.id == base.id and (s.stars or 0) == (base.stars or 0) then
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
	local merged = { id = base.id, born = born, mut = bestMut, stars = (base.stars or 0) + 1, traits = if #traits > 0 then traits else nil }
	table.sort(group, function(a, b)
		return a > b
	end)
	for _, i in group do
		table.remove(data.slimes, i)
	end
	table.insert(data.slimes, merged)
	PlotService.Render(player)
	local pad = plot.model.Pens:FindFirstChild("Pen" .. #data.slimes)
	local name = Config.DisplayName(merged.id, merged.mut, merged.stars, merged.traits)
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
	plot.lockedUntil = math.max(plot.lockedUntil, t) + seconds
	plot.lockReadyAt = plot.lockedUntil + Config.LockCooldownSeconds
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
	PlotService.Render(player)
	local plot = plotOf[player]
	if plot then
		BaseDecor.Apply(plot.model, plot.cframe, data.rebirths)
		Net.FxAll("baseUpgrade", { pos = plot.cframe.Position })
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
	local half = 26
	return math.abs(localPos.X) <= half and math.abs(localPos.Z) <= half and localPos.Y < 20
end
PlotService.InPlot = inPlot

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
		local seconds = (Config.LockSeconds + PlotService.UpgradeLevel(who, "Shield") * Config.Upgrades.Shield.per) * (if Passes.Owns(who, "VIP") then 2 else 1)
		if PlotService.Lock(who, seconds) then
			Net.Notify(who, "Base locked for " .. seconds .. "s", "good")
		else
			local wait = math.max(plot.lockedUntil, plot.lockReadyAt) - now()
			Net.Notify(who, "Lock ready in " .. Util.Duration(wait), "bad")
		end
	end)
end

function PlotService.Assign(player: Player)
	for _, plot in plots do
		if not plot.owner then
			plot.owner = player
			plot.lockedUntil = 0
			plot.lockReadyAt = 0
			plotOf[player] = plot
			setOwnerSign(plot)
			local data = DataService.Get(player)
			BaseDecor.Apply(plot.model, plot.cframe, if data then data.rebirths else 0)
			player:SetAttribute("PlotIndex", plot.model:GetAttribute("Index"))
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
		pad.Transparency = 1
	end
	plot.owner = nil
	plot.lockedUntil = 0
	plotOf[player] = nil
	BaseDecor.Apply(plot.model, plot.cframe, 0)
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
		}
		table.insert(plots, plot)
		setupPlotInteractions(plot)
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

	-- Lock visuals and pushing intruders out of locked bases.
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, plot in plots do
				local locked = plot.owner ~= nil and PlotService.IsLocked(plot)
				for _, wall in plot.model.Shield:GetChildren() do
					wall.Transparency = if locked then 0.4 else 1
				end
				local status = plot.model.LockButton:FindFirstChild("Status", true)
				if status then
					status.Text = if locked
						then "LOCKED " .. Util.Duration(plot.lockedUntil - now())
						elseif plot.owner and PlotService.IsRookie(plot.owner) then "🐣 ROOKIE SHIELD"
						elseif plot.owner and now() < plot.lockReadyAt then "Ready in " .. Util.Duration(plot.lockReadyAt - now())
						else "LOCK BASE"
				end
				if locked then
					for _, other in Players:GetPlayers() do
						local avenging = plot.owner ~= nil and other:GetAttribute("RevengeUserId") == plot.owner.UserId and (other:GetAttribute("RevengeUntil") or 0) > workspace:GetServerTimeNow()
						local root = other ~= plot.owner and not avenging and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
						if root and inPlot(plot, root.Position) then
							other.Character:PivotTo(plot.cframe * CFrame.new(0, 4, -34))
							Net.Notify(other, "That base is shielded!", "bad")
						end
					end
				end
			end
		end
	end)
end

return PlotService
