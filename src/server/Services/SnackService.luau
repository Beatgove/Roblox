-- Slime Snacks: feed SnackEvolve of one kind to a slime and it evolves into a diet form
-- (Spicy Goop, Glowing Blobby...). Snacks drop from rolls, belt buys, quests, bounties and
-- the King Slime, and the Snack Bar sells them for cash.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Util = require(game.ReplicatedStorage.Shared.Util)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local Net = require(script.Parent.Net)
local Signals = require(script.Parent.Signals)

local SnackService = {}

local totalWeight = 0
for _, key in Config.SnackOrder do
	totalWeight += Config.Snacks[key].weight
end

local function randomSnack(): string
	local r = math.random() * totalWeight
	for _, key in Config.SnackOrder do
		r -= Config.Snacks[key].weight
		if r <= 0 then
			return key
		end
	end
	return Config.SnackOrder[1]
end

function SnackService.Price(player: Player, key: string): number
	local snack = Config.Snacks[key]
	return math.floor(math.max(Config.SnackMinPrice, PlotService.IncomePerSecond(player) * Config.SnackPriceSeconds) * snack.priceMult)
end

function SnackService.Sync(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local prices = {}
	for _, key in Config.SnackOrder do
		prices[key] = SnackService.Price(player, key)
	end
	player:SetAttribute("Snacks", HttpService:JSONEncode(data.snacks))
	player:SetAttribute("SnackPrices", HttpService:JSONEncode(prices))
	local n = 0
	for _ in data.diets do
		n += 1
	end
	player:SetAttribute("DietCount", n)
	local pick = player:GetAttribute("SnackPick")
	if not pick or (data.snacks[pick] or 0) <= 0 then
		-- Default to the first snack you own.
		for _, key in Config.SnackOrder do
			if (data.snacks[key] or 0) > 0 then
				player:SetAttribute("SnackPick", key)
				break
			end
		end
	end
end

-- Gives `count` snacks (random kind if `key` is nil). Returns the kind given.
function SnackService.Give(player: Player, key: string?, count: number?, quiet: boolean?): string?
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local k = key or randomSnack()
	local n = count or 1
	data.snacks[k] = (data.snacks[k] or 0) + n
	SnackService.Sync(player)
	local snack = Config.Snacks[k]
	if not quiet then
		Net.Fx(player, "snack", { key = k, icon = snack.icon, count = n })
		Net.Notify(player, snack.icon .. " +" .. n .. " " .. k .. " snack" .. (if n > 1 then "s" else "") .. "! Feed " .. Config.SnackEvolve .. " to a slime to evolve it.", "good")
	end
	return k
end

function SnackService.Feed(player: Player, slot: number)
	local data = DataService.Get(player)
	local slime = data and data.slimes[slot]
	if not data or not slime then
		return
	end
	if slime.diet then
		Net.Notify(player, "This slime has already evolved!", "info")
		return
	end
	local key = player:GetAttribute("SnackPick")
	if type(key) ~= "string" or not Config.Snacks[key] or (data.snacks[key] or 0) <= 0 then
		Net.Notify(player, "You don't have any snacks! Get them from rolls, quests and the 🍽️ Snack Bar.", "bad")
		Net.Fx(player, "deny", {})
		return
	end
	local snack = Config.Snacks[key]
	data.snacks[key] -= 1
	if data.snacks[key] <= 0 then
		data.snacks[key] = nil
	end
	slime.food = slime.food or {}
	-- Diet decides the form: switching snacks resets the other progress.
	for k in slime.food do
		if k ~= key then
			slime.food[k] = nil
		end
	end
	slime.food[key] = (slime.food[key] or 0) + 1
	local plot = PlotService.GetPlot(player)
	local pad = plot and plot.model.Pens:FindFirstChild("Pen" .. slot)
	local pos = if pad then pad.Position else nil
	if slime.food[key] >= Config.SnackEvolve then
		slime.food = nil
		slime.diet = key
		local name = Config.DisplayName(slime.id, slime.mut, slime.stars, slime.traits, slime.diet)
		local dietKey = slime.id .. ":" .. key
		local isNew = not data.diets[dietKey]
		data.diets[dietKey] = true
		PlotService.Render(player)
		Signals.Progress(player, "evolve")
		Net.FxAll("evolve", { pos = pos, color = snack.color })
		Net.Fx(player, "evolved", { name = name, icon = snack.icon, desc = snack.desc, new = isNew })
		Net.Notify(player, snack.icon .. " EVOLVED! " .. name .. " now earns x" .. snack.mult .. " cash!" .. (if isNew then " (NEW in your Diet Book)" else ""), "epic")
		local rarity = Config.RarityByName[Config.SlimeById[slime.id].rarity]
		if rarity.order >= 5 then
			Net.NotifyAll(snack.icon .. " " .. player.DisplayName .. " evolved a " .. name .. "!", "epic")
		end
	else
		PlotService.Render(player)
		Net.Fx(player, "fed", { pos = pos, icon = snack.icon, color = snack.color, n = slime.food[key], of = Config.SnackEvolve })
	end
	SnackService.Sync(player)
end

local function buy(player: Player, key: any)
	local data = DataService.Get(player)
	if not data or type(key) ~= "string" or not Config.Snacks[key] then
		return
	end
	local price = SnackService.Price(player, key)
	if data.cash < price then
		Net.Notify(player, "You need " .. Util.Money(price) .. " for that snack.", "bad")
		Net.Fx(player, "deny", {})
		return
	end
	data.cash -= price
	PlotService.Sync(player)
	SnackService.Give(player, key, 1, true)
	player:SetAttribute("SnackPick", key)
	Net.Fx(player, "snack", { key = key, icon = Config.Snacks[key].icon, count = 1 })
end

function SnackService.Start()
	Net.BuySnackEvent.OnServerEvent:Connect(buy)
	Net.PickSnackEvent.OnServerEvent:Connect(function(player, key)
		if type(key) == "string" and Config.Snacks[key] then
			player:SetAttribute("SnackPick", key)
		end
	end)
	PlotService.FeedRequested.Event:Connect(SnackService.Feed)

	-- Drops: a chance on every roll and belt buy, and a sure thing for bigger wins.
	Signals.Quest.Event:Connect(function(player: Player, kind: string)
		if kind == "roll" or kind == "buy" then
			if math.random() < Config.SnackDropChance * (if Config.HasRelic(DataService.Get(player), "SnackPouch") then 2 else 1) then
				task.delay(1.8, function()
					if player.Parent then
						SnackService.Give(player)
					end
				end)
			end
		elseif kind == "quest" or kind == "bounty" then
			SnackService.Give(player)
		elseif kind == "boss" then
			SnackService.Give(player, nil, 2)
		end
	end)

	local function onJoin(player: Player)
		task.spawn(function()
			for _ = 1, 40 do
				if DataService.Get(player) then
					SnackService.Sync(player)
					return
				end
				task.wait(0.25)
			end
		end)
	end
	Players.PlayerAdded:Connect(onJoin)
	for _, p in Players:GetPlayers() do
		onJoin(p)
	end
	-- Prices follow income, so refresh them now and then.
	task.spawn(function()
		while true do
			task.wait(10)
			for _, p in Players:GetPlayers() do
				SnackService.Sync(p)
			end
		end
	end)
end

return SnackService
