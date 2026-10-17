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
local DispenserService = require(Services.DispenserService)
local CodeService = require(Services.CodeService)
local DailyService = require(Services.DailyService)
local EventService = require(Services.EventService)
local GearService = require(Services.GearService)
local GiftService = require(Services.GiftService)
local QuestService = require(Services.QuestService)
local BoostService = require(Services.BoostService)
local LeaderboardService = require(Services.LeaderboardService)
local TraitService = require(Services.TraitService)
local UpgradeService = require(Services.UpgradeService)
local IndexService = require(Services.IndexService)
local LevelService = require(Services.LevelService)
local FuseService = require(Services.FuseService)
local BountyService = require(Services.BountyService)
local BossService = require(Services.BossService)

local plots = MapBuilder.Build()
DataService.Start()
PlotService.Start(plots)
ConveyorService.Start()
StealService.Start()
MonetizationService.Start()
DispenserService.Start()
CodeService.Start()
DailyService.Start()
EventService.Start()
GearService.Start()
GiftService.Start()
QuestService.Start()
BoostService.Start()
LeaderboardService.Start()
TraitService.Start()
UpgradeService.Start()
IndexService.Start()
LevelService.Start()
FuseService.Start()
BountyService.Start()
BossService.Start()
require(Services.DebugService).Start({
	DataService = DataService,
	PlotService = PlotService,
	BossService = BossService,
	BaseDecor = require(Services.BaseDecor),
	LevelService = LevelService,
	EventService = EventService,
	BountyService = BountyService,
})

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
	if data.lastOnline == 0 then
		DispenserService.GiveLuck(player, Config.NewPlayerLuckMinutes * 60)
		Net.Notify(player, "🍀 NEW PLAYER BONUS: 5x LUCK for " .. Config.NewPlayerLuckMinutes .. " minutes! Try the Slime Dispenser!", "epic")
	end
	if data.lastOnline > 0 then
		local away = math.min(t - data.lastOnline, Config.OfflineCapSeconds)
		local earned = math.floor(PlotService.IncomePerSecond(player) * away * Config.OfflineRate)
		if away > 60 and earned > 0 then
			PlotService.AddCash(player, earned)
			Net.Notify(player, "Welcome back! Your slimes made " .. Util.Money(earned) .. " and grew while you were away.", "epic")
		end
	end

	DailyService.Sync(player)
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
	GearService.OnPlayer(player)
	GiftService.OnPlayer(player)
	LevelService.OnPlayer(player)
	FuseService.OnPlayer(player)
	IndexService.Check(player)
	welcomeBack(player, data)
	QuestService.Sync(player)
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
