-- Loads, caches and saves player data. Data is only saved if it loaded cleanly,
-- so a DataStore outage never overwrites someone's progress with a blank save.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(game.ReplicatedStorage.Shared.Config)

local DataService = {}

local store = nil
local ok, err = pcall(function()
	store = DataStoreService:GetDataStore("StealASlime_v1")
end)
if not ok then
	warn("[DataService] DataStore unavailable (enable Studio API access to save in Studio):", err)
end

local profiles: { [Player]: any } = {}
local canSave: { [Player]: boolean } = {}

local function defaultData()
	return {
		version = 1,
		cash = Config.StartingCash,
		bank = 0,
		rebirths = 0,
		slimes = {}, -- array of { id = string, born = os.time(), mut = mutation name or nil }
		lastOnline = 0,
		lastDaily = 0,
		dailyStreak = 0,
		totalEarned = 0,
		rookieOff = false, -- true once a new player steals (ends their Rookie Shield)
		steals = 0,
		index = {}, -- slime id -> true once ever owned (Slime Index)
		codes = {}, -- redeemed code -> true
		luckUntil = 0, -- os.time() until which 5x dispenser luck is active
		rolls = 0,
		gear = { Slap = true }, -- gear key -> true once bought
		upgrades = {}, -- upgrade key -> level
		xp = 0,
		level = 1,
		fuse = { active = false }, -- Fuse Machine job: { active, endsAt, result = slime table }
		indexRewards = {},
		snacks = {}, -- snack key -> count owned
		towerAt = 0, -- os.time() of the last Sky Tower prize
		relics = {}, -- equipped relic keys (up to Config.RelicSlots), reset on rebirth
		relicBag = {}, -- relic key -> true, owned this run
		diets = {}, -- "SlimeId:SnackKey" -> true once evolved (Diet Book) -- milestone count (as string) -> true
		quests = { day = -1, list = {}, bonus = false }, -- today's daily quests
		receipts = {}, -- PurchaseId -> true (recent, for idempotent ProcessReceipt)
		receiptOrder = {},
	}
end

local function reconcile(data)
	local def = defaultData()
	for k, v in def do
		if data[k] == nil then
			data[k] = v
		end
	end
	-- Drop slimes whose id no longer exists in Config.
	local clean = {}
	for _, s in data.slimes do
		if Config.SlimeById[s.id] then
			table.insert(clean, s)
		end
	end
	data.slimes = clean
	if data.fuse.active and not (data.fuse.result and Config.SlimeById[data.fuse.result.id]) then
		data.fuse = { active = false }
	end
	-- Older saves: everything currently owned counts as discovered.
	for _, s in data.slimes do
		data.index[s.id] = true
	end
	return data
end

local function withRetry(fn)
	for attempt = 1, 4 do
		local success, result = pcall(fn)
		if success then
			return true, result
		end
		warn("[DataService] attempt", attempt, "failed:", result)
		task.wait(attempt * 1.5)
	end
	return false, nil
end

function DataService.Load(player: Player)
	local key = "u_" .. player.UserId
	local data
	if store then
		local success, result = withRetry(function()
			return store:GetAsync(key)
		end)
		if success then
			data = result and reconcile(result) or defaultData()
			canSave[player] = true
		else
			data = defaultData()
			canSave[player] = false
			warn("[DataService] could not load data for", player.Name, "- progress this session will not save")
		end
	else
		data = defaultData()
		canSave[player] = false
	end
	profiles[player] = data
	return data
end

function DataService.Get(player: Player)
	return profiles[player]
end

function DataService.Save(player: Player)
	local data = profiles[player]
	if not data or not store or not canSave[player] then
		return
	end
	data.lastOnline = os.time()
	local key = "u_" .. player.UserId
	withRetry(function()
		store:UpdateAsync(key, function()
			return data
		end)
	end)
end

function DataService.Release(player: Player)
	DataService.Save(player)
	profiles[player] = nil
	canSave[player] = nil
end

-- Remember a receipt so a repeated ProcessReceipt call never grants twice.
function DataService.MarkReceipt(player: Player, purchaseId: string): boolean
	local data = profiles[player]
	if not data then
		return false
	end
	if data.receipts[purchaseId] then
		return false
	end
	data.receipts[purchaseId] = true
	table.insert(data.receiptOrder, purchaseId)
	while #data.receiptOrder > 50 do
		local old = table.remove(data.receiptOrder, 1)
		data.receipts[old] = nil
	end
	return true
end

function DataService.HasReceipt(player: Player, purchaseId: string): boolean
	local data = profiles[player]
	return data ~= nil and data.receipts[purchaseId] == true
end

function DataService.Start()
	task.spawn(function()
		while true do
			task.wait(Config.SaveIntervalSeconds)
			for _, player in Players:GetPlayers() do
				task.spawn(DataService.Save, player)
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() and not store then
			return
		end
		local threads = 0
		for _, player in Players:GetPlayers() do
			threads += 1
			task.spawn(function()
				DataService.Save(player)
				threads -= 1
			end)
		end
		local t = os.clock()
		while threads > 0 and os.clock() - t < 25 do
			task.wait(0.1)
		end
	end)
end

return DataService
