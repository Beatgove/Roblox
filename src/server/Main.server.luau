-- Entry point: builds the map, starts every service and handles players joining/leaving.

local Players = game:GetService("Players")

local Services = script.Parent.Services
local Config = require(game.ReplicatedStorage.Shared.Config)
local Util = require(game.ReplicatedStorage.Shared.Util)
local Net = require(Services.Net)
local MapBuilder = require(Services.MapBuilder)
local DataService = require(Services.DataService)
local Passes = require(Services.Passes)
local PlotService = require(Services.PlotService)
local ConveyorService = require(Services.ConveyorService)
local StealService = require(Services.StealService)
local MonetizationService = require(Services.MonetizationService)

local plots = MapBuilder.Build()
DataService.Start()
PlotService.Start(plots)
ConveyorService.Start()
StealService.Start()
MonetizationService.Start()

local function makeLeaderstats(player: Player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local cash = Instance.new("StringValue")
	cash.Name = "Cash"
	cash.Value = "$0"
	cash.Parent = ls
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = ls
	ls.Parent = player
end

-- Offline earnings and the daily streak gift: the reasons to come back tomorrow.
local function welcomeBack(player: Player, data)
	local t = os.time()
	if data.lastOnline > 0 then
		local away = math.min(t - data.lastOnline, Config.OfflineCapSeconds)
		local earned = math.floor(PlotService.IncomePerSecond(player) * away * Config.OfflineRate)
		if away > 60 and earned > 0 then
			PlotService.AddCash(player, earned)
			Net.Notify(player, "Welcome back! Your slimes made " .. Util.Money(earned) .. " and grew while you were away.", "epic")
		end
	end

	local today = t // 86400
	if data.lastDaily ~= today then
		data.dailyStreak = if data.lastDaily == today - 1 then math.min(data.dailyStreak + 1, 7) else 1
		data.lastDaily = today
		local gift = math.max(100, math.floor(PlotService.IncomePerSecond(player) * 60 * data.dailyStreak))
		PlotService.AddCash(player, gift)
		Net.Notify(player, "Day " .. data.dailyStreak .. " streak gift: " .. Util.Money(gift) .. "! Come back tomorrow for more.", "good")
	end
	data.lastOnline = t
end

local function onPlayerAdded(player: Player)
	makeLeaderstats(player)
	local data = DataService.Load(player)
	Passes.Load(player)
	if not player.Parent then
		DataService.Release(player)
		return
	end
	PlotService.Assign(player)
	MonetizationService.OnPlayer(player)
	welcomeBack(player, data)
	PlotService.Sync(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in Players:GetPlayers() do
	task.spawn(onPlayerAdded, p)
end

local rebirthDebounce: { [Player]: number } = {}

Players.PlayerRemoving:Connect(function(player)
	PlotService.Release(player)
	DataService.Release(player)
	Passes.Release(player)
	rebirthDebounce[player] = nil
end)

Net.RebirthEvent.OnServerEvent:Connect(function(player)
	local t = os.clock()
	if rebirthDebounce[player] and t - rebirthDebounce[player] < 2 then
		return
	end
	rebirthDebounce[player] = t
	PlotService.Rebirth(player)
end)
