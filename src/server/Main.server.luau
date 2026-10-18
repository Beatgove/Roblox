-- Entry point: builds the map, starts every service and handles players joining/leaving.

local Players = game:GetService("Players")

local Services = script.Parent.Services
local Config = require(game.ReplicatedStorage.Shared.Config)
local Util = require(game.ReplicatedStorage.Shared.Util)
local Net = require(Services.Net)
local MapBuilder = require(Services.MapBuilder)
local DataService = require(Services.DataService)
local Rewards = require(Services.Rewards)
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
local NemesisService = require(Services.NemesisService)
local SnackService = require(Services.SnackService)
local BlackoutService = require(Services.BlackoutService)
local RelicService = require(Services.RelicService)
local FishingService = require(Services.FishingService)
local ArcadeService = require(Services.ArcadeService)
local TowerService = require(Services.TowerService)
local EventDropService = require(Services.EventDropService)
local TutorialService = require(Services.TutorialService)
local StormService = require(Services.StormService)
local SeasonService = require(Services.SeasonService)
local Analytics = require(Services.Analytics)
local BossService = require(Services.BossService)
local SlimeVoices = require(Services.SlimeVoices)
local HolidayService = require(Services.HolidayService)
local SettingsService = require(Services.SettingsService)

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
NemesisService.Start()
SnackService.Start()
BlackoutService.Start()
RelicService.Start()
FishingService.Start()
ArcadeService.Start()
TowerService.Start()
EventDropService.Start()
TutorialService.Start()
StormService.Start()
SeasonService.Start()
Analytics.Start()
BossService.Start()
SlimeVoices.Start()
HolidayService.Start()
SettingsService.Start()
require(Services.AdminService).Start({
	EventService = EventService,
	BossService = BossService,
	BlackoutService = BlackoutService,
	EventDropService = EventDropService,
	StormService = StormService,
})
require(Services.DebugService).Start({
	DataService = DataService,
	Net = Net,
	PlotService = PlotService,
	BossService = BossService,
	BaseDecor = require(Services.BaseDecor),
	LevelService = LevelService,
	EventService = EventService,
	BountyService = BountyService,
	SnackService = SnackService,
	BlackoutService = BlackoutService,
	RelicService = RelicService,
	ArcadeService = ArcadeService,
	EventDropService = EventDropService,
	TutorialService = TutorialService,
	StormService = StormService,
	SeasonService = SeasonService,
	HolidayService = HolidayService,
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
			PlotService.AddCash(player, earned, "Offline")
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
	SettingsService.OnPlayer(player)
	TutorialService.OnPlayer(player)
	SeasonService.OnPlayer(player)
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

Net.On(Net.RebirthEvent, function(player)
	local t = os.clock()
	if rebirthDebounce[player] and t - rebirthDebounce[player] < 2 then
		return
	end
	rebirthDebounce[player] = t
	local data = DataService.Get(player)
	local before = if data then data.rebirths else 0
	PlotService.Rebirth(player)
	-- A prize for every rebirth (Config.RebirthRewards), after the base resets.
	if data and data.rebirths > before then
		local reward = Config.RebirthRewards[data.rebirths] or Config.RebirthRewardDefault
		task.delay(1.5, function()
			if player.Parent then
				local got = Rewards.Grant(player, reward)
				Net.Notify(player, "🎁 REBIRTH " .. data.rebirths .. " PRIZE: " .. got, "epic")
			end
		end)
	end
end)
