-- Thin wrapper around Roblox AnalyticsService so a failing call never breaks gameplay.
-- Shows up in Creator Hub > Analytics: the onboarding funnel (where new players quit)
-- and custom events (rebirths, steals, minigames...).

local AnalyticsService = game:GetService("AnalyticsService")

local DataService = require(script.Parent.DataService)
local Signals = require(script.Parent.Signals)

local Analytics = {}

function Analytics.Onboarding(player: Player, step: number, name: string)
	pcall(AnalyticsService.LogOnboardingFunnelStepEvent, AnalyticsService, player, step, name)
end

function Analytics.Custom(player: Player, name: string, value: number?)
	pcall(AnalyticsService.LogCustomEvent, AnalyticsService, player, name, value or 1)
end

-- Economy events (Creator Hub > Analytics > Economy): where cash comes from and where it goes,
-- so you can see which shops people use and whether prices feel right. Spending is logged
-- straight away; earnings come in many small amounts, so they are added up per player and
-- per source and sent once a minute.
local function balance(player: Player): number
	local data = DataService.Get(player)
	return if data then data.cash else 0
end

local function economy(player: Player, flow: Enum.AnalyticsEconomyFlowType, amount: number, tx: string, sku: string)
	if amount <= 0 or amount ~= amount or amount == math.huge then
		return
	end
	pcall(AnalyticsService.LogEconomyEvent, AnalyticsService, player, flow, "Cash", math.floor(amount), math.floor(balance(player)), tx, sku)
end

-- tx is an Enum.AnalyticsEconomyTransactionType name: "Shop", "Gameplay", "ContextualPurchase"...
function Analytics.Spend(player: Player, amount: number, sku: string, tx: string?)
	economy(player, Enum.AnalyticsEconomyFlowType.Sink, amount, tx or Enum.AnalyticsEconomyTransactionType.Shop.Name, sku)
end

local pending: { [Player]: { [string]: number } } = {}

function Analytics.Earn(player: Player, amount: number, sku: string)
	if amount <= 0 then
		return
	end
	local mine = pending[player]
	if not mine then
		mine = {}
		pending[player] = mine
	end
	mine[sku] = (mine[sku] or 0) + amount
end

local function flush(player: Player)
	local mine = pending[player]
	pending[player] = nil
	for sku, amount in (mine or {}) do
		economy(player, Enum.AnalyticsEconomyFlowType.Source, amount, Enum.AnalyticsEconomyTransactionType.Gameplay.Name, sku)
	end
end

-- Progression (Creator Hub > Analytics > Progression): how far people get.
function Analytics.Progress(player: Player, path: string, level: number)
	pcall(AnalyticsService.LogProgressionCompleteEvent, AnalyticsService, player, path, level)
end

-- Gameplay moments worth counting (keep this list short: Roblox caps custom event names).
local TRACKED = { steal = "Steal", rebirth = "Rebirth", minigame = "Minigame", boss = "KingSlime", fuse = "Fuse", evolve = "Evolve", avenge = "Avenge" }

function Analytics.Start()
	task.spawn(function()
		while true do
			task.wait(60)
			for player in pending do
				flush(player)
			end
		end
	end)
	game:GetService("Players").PlayerRemoving:Connect(flush)
	Signals.Quest.Event:Connect(function(player: Player, kind: string)
		local name = TRACKED[kind]
		if name then
			Analytics.Custom(player, name)
		end
	end)
end

return Analytics
