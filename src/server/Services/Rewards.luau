-- Grants a reward table shared by gifts, quests and daily rewards:
-- { cashSeconds, cashMin, luckMinutes, grow, slime, freeRoll, rollLuck }.
-- Returns a short text describing what was given.

local Config = require(game.ReplicatedStorage.Shared.Config)
local Util = require(game.ReplicatedStorage.Shared.Util)
local PlotService = require(script.Parent.PlotService)
local DispenserService = require(script.Parent.DispenserService)
local Net = require(script.Parent.Net)

local Rewards = {}

function Rewards.Grant(player: Player, reward): string
	local parts = {}
	if reward.cashSeconds or reward.cash then
		local amount = math.max(reward.cashMin or reward.cash or 0, math.floor(PlotService.IncomePerSecond(player) * (reward.cashSeconds or 0)))
		PlotService.AddCash(player, amount)
		table.insert(parts, "+" .. Util.Money(amount))
	end
	if reward.luckMinutes then
		DispenserService.GiveLuck(player, reward.luckMinutes * 60)
		table.insert(parts, reward.luckMinutes .. " min 5x LUCK")
	end
	if reward.grow then
		PlotService.GrowAll(player)
		table.insert(parts, "all slimes grew")
	end
	if reward.slime then
		if PlotService.AddSlime(player, { id = reward.slime, born = os.time() }) then
			Net.Fx(player, "reveal", { name = reward.slime, rarity = Config.SlimeById[reward.slime].rarity })
			table.insert(parts, reward.slime .. " slime")
		else
			local value = Config.SlimeById[reward.slime].price
			PlotService.AddCash(player, value)
			table.insert(parts, "+" .. Util.Money(value) .. " (pens full)")
		end
	end
	if reward.freeRoll then
		if DispenserService.FreeRoll(player, reward.rollLuck) then
			table.insert(parts, if reward.rollLuck then "a LUCKY free roll" else "a free roll")
		else
			local amount = math.max(500, PlotService.RollCost(player))
			PlotService.AddCash(player, amount)
			table.insert(parts, "+" .. Util.Money(amount) .. " (pens full)")
		end
	end
	return table.concat(parts, " + ")
end

return Rewards
