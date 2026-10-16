-- 7-day login reward calendar. Players claim once per UTC day; missing a day resets the streak.

local Players = game:GetService("Players")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Util = require(game.ReplicatedStorage.Shared.Util)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local DispenserService = require(script.Parent.DispenserService)
local Net = require(script.Parent.Net)

local DailyService = {}

local function today(): number
	return os.time() // 86400
end

-- Which calendar day the player would claim now, and whether they can.
function DailyService.State(data): (number, boolean)
	local d = today()
	if data.lastDaily == d then
		return data.dailyStreak, false
	end
	if data.lastDaily == d - 1 then
		return (data.dailyStreak % #Config.DailyRewards) + 1, true
	end
	return 1, true
end

function DailyService.Sync(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local day, claimable = DailyService.State(data)
	player:SetAttribute("DailyDay", day)
	player:SetAttribute("DailyClaimable", claimable)
	player:SetAttribute("DailyResetAt", (today() + 1) * 86400)
end

local function claim(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local day, claimable = DailyService.State(data)
	if not claimable then
		Net.Notify(player, "Already claimed today! Come back tomorrow.", "bad")
		return
	end
	local reward = Config.DailyRewards[day]
	data.lastDaily = today()
	data.dailyStreak = day

	local parts = {}
	if reward.cashSeconds then
		local amount = math.max(reward.cashMin or 0, math.floor(PlotService.IncomePerSecond(player) * reward.cashSeconds))
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
	DailyService.Sync(player)
	DataService.Save(player)
	Net.Fx(player, "daily", { day = day })
	Net.Notify(player, "🎁 Day " .. day .. " reward: " .. table.concat(parts, " + ") .. "!", "epic")
end

function DailyService.Start()
	Net.ClaimDailyEvent.OnServerEvent:Connect(claim)
	-- Keep the calendar fresh for players online across midnight.
	task.spawn(function()
		while true do
			task.wait(60)
			for _, p in Players:GetPlayers() do
				DailyService.Sync(p)
			end
		end
	end)
end

return DailyService
