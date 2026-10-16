-- Daily quests: 3 random goals a day (buy, roll, collect, merge, steal, slap, gifts).
-- Each pays cash + luck; finishing all three pays a bonus.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Util = require(game.ReplicatedStorage.Shared.Util)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local Rewards = require(script.Parent.Rewards)
local Signals = require(script.Parent.Signals)
local Net = require(script.Parent.Net)

local QuestService = {}

local function today(): number
	return os.time() // 86400
end

local function describe(q): string
	local def = Config.QuestPool[q.i]
	local goal = if def.money then Util.Money(q.goal) else tostring(q.goal)
	return (string.gsub(def.text, "%%[ds]", goal))
end

local function ensure(player: Player)
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local quests = data.quests
	if quests.day ~= today() then
		local pool = {}
		for i in Config.QuestPool do
			table.insert(pool, i)
		end
		local list = {}
		for _ = 1, Config.QuestsPerDay do
			local i = table.remove(pool, math.random(1, #pool))
			local def = Config.QuestPool[i]
			local goal = def.goal
			if def.kind == "collect" then
				-- About 10 minutes of current income, so it scales with progress.
				goal = math.max(def.goal, math.floor(PlotService.IncomePerSecond(player) * 600 / 1000) * 1000)
			end
			table.insert(list, { i = i, goal = goal, progress = 0, claimed = false })
		end
		data.quests = { day = today(), list = list, bonus = false }
	end
	return data.quests
end

function QuestService.Sync(player: Player)
	local quests = ensure(player)
	if not quests then
		return
	end
	local out = {}
	for _, q in quests.list do
		table.insert(out, { text = describe(q), progress = math.min(q.progress, q.goal), goal = q.goal, claimed = q.claimed, money = Config.QuestPool[q.i].money == true })
	end
	player:SetAttribute("Quests", HttpService:JSONEncode(out))
	player:SetAttribute("QuestReset", (today() + 1) * 86400)
end

local function progress(player: Player, kind: string, amount: number)
	local quests = ensure(player)
	if not quests then
		return
	end
	local changed = false
	for _, q in quests.list do
		if Config.QuestPool[q.i].kind == kind and q.progress < q.goal then
			q.progress = math.min(q.goal, q.progress + amount)
			changed = true
			if q.progress >= q.goal then
				Net.Notify(player, "✅ Quest done: " .. describe(q) .. "! Claim it in QUESTS.", "epic")
				Net.Fx(player, "questDone", {})
			end
		end
	end
	if changed then
		QuestService.Sync(player)
	end
end

local function claim(player: Player, i: number)
	local quests = ensure(player)
	local q = quests and typeof(i) == "number" and quests.list[i]
	if not q or q.claimed or q.progress < q.goal then
		return
	end
	q.claimed = true
	local text = Rewards.Grant(player, Config.QuestReward)
	Net.Notify(player, "Quest reward: " .. text .. "!", "epic")
	Net.Fx(player, "gift", {})
	local all = true
	for _, other in quests.list do
		all = all and other.claimed
	end
	if all and not quests.bonus then
		quests.bonus = true
		local bonus = Rewards.Grant(player, Config.AllQuestsBonus)
		Net.Notify(player, "🏆 ALL QUESTS DONE! Bonus: " .. bonus .. "!", "epic")
		Net.Fx(player, "daily", { day = 7 })
	end
	QuestService.Sync(player)
end

function QuestService.Start()
	Signals.Quest.Event:Connect(progress)
	Net.ClaimQuestEvent.OnServerEvent:Connect(claim)
	-- New quests at midnight UTC for players who stay online.
	task.spawn(function()
		while true do
			task.wait(60)
			for _, p in Players:GetPlayers() do
				QuestService.Sync(p)
			end
		end
	end)
end

return QuestService
