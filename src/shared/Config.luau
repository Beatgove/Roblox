-- Central tuning for Steal a Slime. Change numbers here, not in the services.

local Config = {}

-- ===== Monetization IDs =====
-- Create these in Creator Hub (your experience > Monetization) and paste the IDs.
-- An ID of 0 means "not set up yet"; the shop shows it as unavailable.
Config.GamePasses = {
	DoubleCash = { id = 0, name = "2x Cash", price = 199, desc = "Double all slime income forever." },
	VIP = { id = 0, name = "VIP", price = 299, desc = "+25% income, gold name tag, base lock lasts twice as long." },
	ExtraPens = { id = 0, name = "Extra Pens", price = 149, desc = "+4 pen slots for more slimes." },
	AutoCollect = { id = 0, name = "Auto Collect", price = 99, desc = "Cash goes straight to you, no collector needed." },
}

Config.Products = {
	SmallCash = { id = 0, name = "Small Cash", price = 25, desc = "5 minutes of your income (min $500).", kind = "Cash", seconds = 300, min = 500 },
	BigCash = { id = 0, name = "Big Cash", price = 99, desc = "30 minutes of your income (min $5K).", kind = "Cash", seconds = 1800, min = 5000 },
	HugeCash = { id = 0, name = "Huge Cash", price = 399, desc = "3 hours of your income (min $50K).", kind = "Cash", seconds = 10800, min = 50000 },
	Luck = { id = 0, name = "5x Luck (15 min)", price = 79, desc = "5x Rare+ odds on the Slime Dispenser. Odds are shown on the machine.", kind = "Luck", seconds = 900 },
	InstantLock = { id = 0, name = "Shield (5 min)", price = 39, desc = "Nobody can raid your base for 5 minutes.", kind = "Lock", seconds = 300 },
	GrowBoost = { id = 0, name = "Grow Boost", price = 49, desc = "Every slime you own grows one stage now.", kind = "Grow" },
	SlimeRain = { id = 0, name = "Server Slime Rain", price = 199, desc = "Start a Slime Rain for everyone. Rare slimes x5!", kind = "Rain" },
}

-- Set true to pretend you own every game pass while testing in Studio.
Config.StudioOwnsAllPasses = false

-- ===== Codes =====
-- Players type these in the CODES menu. Each works once per player.
-- cash: flat cash. incomeSeconds: or that many seconds of income if bigger.
-- luckMinutes: minutes of 5x dispenser luck. slime: a slime id to give.
-- expires: os.time() after which the code stops working (nil = never).
Config.Codes = {
	RELEASE = { cash = 1000, luckMinutes = 15, msg = "Welcome! $1K and 15 minutes of 5x LUCK!" },
	SLIMETIME = { cash = 2500, incomeSeconds = 300, msg = "Cash boost!" },
	LUCKY = { luckMinutes = 30, msg = "30 minutes of 5x LUCK!" },
	FREESLIME = { slime = "Codey", msg = "You got the exclusive Codey slime!" },
	SPOOKY = { slime = "PumpkinKing", expires = os.time({ year = 2026, month = 11, day = 1, hour = 0 }), msg = "Exclusive Pumpkin King slime!" },
}

-- ===== Daily login rewards =====
-- A 7-day streak. Missing a day restarts at day 1. Day 7 repeats every week.
-- cashSeconds = that many seconds of income (at least cashMin).
Config.DailyRewards = {
	{ label = "Cash", cashSeconds = 60, cashMin = 200 },
	{ label = "15 min 5x Luck", luckMinutes = 15 },
	{ label = "Big Cash", cashSeconds = 300, cashMin = 1000 },
	{ label = "Grow Boost", grow = true },
	{ label = "Huge Cash", cashSeconds = 900, cashMin = 5000 },
	{ label = "30 min 5x Luck", luckMinutes = 30 },
	{ label = "Sunny Slime + Mega Cash", slime = "Sunny", cashSeconds = 1800, cashMin = 20000 },
}

-- ===== Luck =====
Config.LuckMult = 5
Config.NewPlayerLuckMinutes = 10 -- first-time players get free 5x luck
Config.MaxLuck = 25 -- personal luck x Slime Rain luck can stack up to this

-- ===== Slime Dispenser =====
Config.DispenserMinCost = 150
Config.DispenserIncomeSeconds = 40 -- cost = max(min, income per second x this)
Config.DispenserCooldown = 1.8

-- ===== Mutations =====
-- Rolled for every slime from the belt or dispenser. Luck doubles the chances.
-- event = only rolls while that server event is running (see Config.Events).
Config.Mutations = {
	{ name = "Golden", chance = 0.05, mult = 2, color = Color3.fromRGB(255, 205, 40) },
	{ name = "Lava", chance = 0.15, mult = 3, color = Color3.fromRGB(255, 90, 20), event = "LavaStorm" },
	{ name = "Diamond", chance = 0.01, mult = 4, color = Color3.fromRGB(140, 240, 255) },
	{ name = "Candy", chance = 0.08, mult = 5, color = Color3.fromRGB(255, 130, 200), event = "CandyParty" },
	{ name = "Rainbow", chance = 0.002, mult = 8, color = Color3.fromRGB(255, 120, 255) },
}

-- ===== Server events (like weather in Grow a Garden / admin events in Steal a Brainrot) =====
-- One random event runs every EventEverySeconds for EventSeconds. Slime Rain is separate.
Config.EventEverySeconds = 8 * 60
Config.EventSeconds = 3 * 60
Config.Events = {
	GoldenHour = { title = "✨ GOLDEN HOUR", desc = "Golden mutations x10!", goldenMult = 10, tint = Color3.fromRGB(255, 225, 150) },
	LavaStorm = { title = "🌋 LAVA STORM", desc = "Lava slimes (x3 cash) are falling!", tint = Color3.fromRGB(255, 170, 140) },
	CandyParty = { title = "🍬 CANDY PARTY", desc = "Candy slimes (x5 cash) are here!", tint = Color3.fromRGB(255, 200, 235) },
	CashFrenzy = { title = "💸 CASH FRENZY", desc = "Every slime earns 2x cash!", incomeMult = 2, tint = Color3.fromRGB(190, 255, 190) },
	LuckyHour = { title = "🍀 LUCKY HOUR", desc = "3x luck on the belt and Dispenser!", luck = 3, tint = Color3.fromRGB(200, 255, 210) },
}

-- ===== Gear (bought with cash in the GEAR menu, kept forever) =====
-- rebirth = rebirths needed to buy it. Slap is free for everyone.
Config.GearOrder = { "Slap", "SpeedCoil", "GravityCoil", "Trap", "Taser" }
Config.Gear = {
	Slap = { name = "Slap Hand", price = 0, rebirth = 0, desc = "Knock players away. Slap a thief and they drop your slime!", color = Color3.fromRGB(255, 200, 150), cooldown = 1.2, range = 9, force = 70 },
	SpeedCoil = { name = "Speed Coil", price = 2500, rebirth = 0, desc = "Run much faster while you hold it.", color = Color3.fromRGB(90, 200, 255), walkSpeed = 28 },
	GravityCoil = { name = "Gravity Coil", price = 8000, rebirth = 0, desc = "Jump super high while you hold it.", color = Color3.fromRGB(190, 120, 255), jumpHeight = 22 },
	Trap = { name = "Slime Trap", price = 40000, rebirth = 1, desc = "Drop a sticky trap. Thieves who step in freeze for 4s.", color = Color3.fromRGB(120, 255, 120), cooldown = 25, freeze = 4, life = 60 },
	Taser = { name = "Slime Taser", price = 500000, rebirth = 2, desc = "Zap a player from far away and stun them for 3s.", color = Color3.fromRGB(255, 240, 80), cooldown = 12, range = 40, stun = 3 },
}

-- ===== Playtime gifts (claim while you play; reset every visit) =====
Config.PlaytimeGifts = {
	{ minutes = 2, label = "Cash", cashSeconds = 60, cashMin = 150 },
	{ minutes = 5, label = "5 min Luck", luckMinutes = 5 },
	{ minutes = 10, label = "Big Cash", cashSeconds = 240, cashMin = 600 },
	{ minutes = 15, label = "Free Roll", freeRoll = true },
	{ minutes = 25, label = "Grow Boost", grow = true },
	{ minutes = 40, label = "Huge Cash", cashSeconds = 900, cashMin = 4000 },
	{ minutes = 60, label = "Lucky Roll", freeRoll = true, rollLuck = 5 },
}

-- ===== Daily quests (3 new ones every day) =====
-- kind is what counts: buy (belt), roll (dispenser), collect (cash from your pad),
-- merge, steal, slap, gift. goal scales with rebirths for "collect".
Config.QuestsPerDay = 3
Config.QuestPool = {
	{ kind = "buy", goal = 8, text = "Buy %d slimes from the belt" },
	{ kind = "roll", goal = 5, text = "Roll the Dispenser %d times" },
	{ kind = "collect", goal = 5000, text = "Collect %s from your pad", money = true },
	{ kind = "merge", goal = 1, text = "Merge slimes %d time" },
	{ kind = "steal", goal = 1, text = "Steal %d slime" },
	{ kind = "slap", goal = 5, text = "Slap players %d times" },
	{ kind = "gift", goal = 3, text = "Open %d playtime gifts" },
}
Config.QuestReward = { cashSeconds = 300, cashMin = 1500, luckMinutes = 5 }
Config.AllQuestsBonus = { cashSeconds = 900, cashMin = 5000, luckMinutes = 15 }

-- ===== Boosts =====
Config.FriendBoost = 0.1 -- +10% income per friend in the server
Config.MaxFriendBoost = 0.5
Config.PremiumBoost = 0.1 -- Roblox Premium members earn +10%

-- ===== Merging =====
-- Merge 3 identical slimes (same name and same stars) into one with an extra star.
Config.MergeCount = 3
Config.MaxStars = 3
Config.StarIncomeMult = 3.5 -- each star multiplies income by this (3 slimes in, 3.5x out, 2 pens freed)

function Config.StarMult(stars: number?): number
	return Config.StarIncomeMult ^ (stars or 0)
end

function Config.Stars(stars: number?): string
	return if stars and stars > 0 then " " .. string.rep("★", stars) else ""
end

-- ===== Economy =====
Config.StartingCash = 50
Config.BaseSlots = 8
Config.SlotsPerRebirth = 2
Config.MaxSlots = 20
Config.ExtraPensSlots = 4
Config.RebirthIncomeBonus = 0.5 -- +50% income per rebirth
Config.IndexBonusPerSlime = 0.01 -- +1% income for every slime discovered in the Index
Config.OfflineCapSeconds = 8 * 3600
Config.OfflineRate = 0.5 -- offline earnings are half speed
Config.SaveIntervalSeconds = 60

function Config.RebirthCost(rebirths: number): number
	return 100000 * (5 ^ rebirths)
end

-- ===== Growth (real time, keeps going while offline) =====
-- Stage n is reached after GrowthStages[n] seconds of age.
Config.GrowthStages = { 0, 10 * 60, 45 * 60, 3 * 3600, 12 * 3600 }
Config.GrowthIncomeMult = { 1, 1.5, 2.25, 3.5, 5 }
Config.GrowthSizeMult = { 1, 1.15, 1.3, 1.5, 1.75 }
Config.GrowthNames = { "Baby", "Small", "Big", "Huge", "Colossal" }

-- ===== Raiding =====
Config.LockSeconds = 60
Config.LockCooldownSeconds = 30
Config.StealHoldSeconds = 1.5
Config.CarryTimeoutSeconds = 60
Config.CarryWalkSpeed = 12
Config.OwnerTagDistance = 7

-- ===== Conveyor =====
Config.SpawnInterval = 2.5
Config.BeltTravelSeconds = 32
Config.RainSpawnInterval = 0.8
Config.RainLuck = 5
Config.RainEverySeconds = 15 * 60
Config.RainDurationSeconds = 60

-- ===== Sounds =====
-- Built-in Roblox sounds so the game works out of the box. Swap for Creator Store
-- sound IDs ("rbxassetid://123") any time for better audio.
Config.Sounds = {
	Ping = "rbxasset://sounds/electronicpingshort.wav",
	Click = "rbxasset://sounds/button.wav",
	Whoosh = "rbxasset://sounds/action_falling.mp3",
	Snap = "rbxasset://sounds/snap.mp3",
	Jump = "rbxasset://sounds/action_jump.mp3",
	Oof = "rbxasset://sounds/uuhhh.mp3",
}

-- ===== Rarities and slimes =====
-- weight = relative spawn chance. Luck multiplies the weight of Rare and above.
Config.Rarities = {
	{ name = "Common", weight = 60, color = Color3.fromRGB(200, 200, 200) },
	{ name = "Uncommon", weight = 25, color = Color3.fromRGB(90, 220, 110) },
	{ name = "Rare", weight = 10, color = Color3.fromRGB(70, 150, 255) },
	{ name = "Epic", weight = 4, color = Color3.fromRGB(180, 90, 255) },
	{ name = "Legendary", weight = 0.9, color = Color3.fromRGB(255, 190, 40) },
	{ name = "Mythic", weight = 0.09, color = Color3.fromRGB(255, 60, 90) },
	{ name = "Divine", weight = 0.03, color = Color3.fromRGB(255, 250, 200) },
	{ name = "Secret", weight = 0.01, color = Color3.fromRGB(30, 30, 30) },
	{ name = "Exclusive", weight = 0, color = Color3.fromRGB(0, 255, 230) }, -- codes only
}

-- extra: decorations built on the slime (crown, halo, horns, wings, antenna, leaf, ears, spikes, band, bow).
-- season: month number it can spawn in (others keep it once owned).
Config.Slimes = {
	{ id = "Goop", rarity = "Common", price = 25, income = 1, color = Color3.fromRGB(120, 230, 120), size = 2.6 },
	{ id = "Dewdrop", rarity = "Common", price = 60, income = 2, color = Color3.fromRGB(120, 200, 255), size = 2.7, extra = { "antenna" } },
	{ id = "Pebble", rarity = "Common", price = 120, income = 4, color = Color3.fromRGB(150, 140, 130), size = 2.8 },
	{ id = "Leafy", rarity = "Common", price = 200, income = 6, color = Color3.fromRGB(170, 230, 90), size = 2.8, extra = { "leaf" } },

	{ id = "Minty", rarity = "Uncommon", price = 400, income = 10, color = Color3.fromRGB(150, 255, 210), size = 3, extra = { "ears" } },
	{ id = "Bubblegum", rarity = "Uncommon", price = 900, income = 20, color = Color3.fromRGB(255, 140, 200), size = 3.1, extra = { "bow" } },
	{ id = "Pumpkin", rarity = "Uncommon", price = 1500, income = 32, color = Color3.fromRGB(255, 130, 20), size = 3.2, extra = { "leaf" }, season = 10 },

	{ id = "Lava", rarity = "Rare", price = 3000, income = 55, color = Color3.fromRGB(255, 90, 20), size = 3.3, extra = { "horns" } },
	{ id = "Frosty", rarity = "Rare", price = 7500, income = 120, color = Color3.fromRGB(190, 240, 255), size = 3.4, extra = { "spikes" } },
	{ id = "Zappy", rarity = "Rare", price = 15000, income = 220, color = Color3.fromRGB(255, 240, 60), size = 3.4, extra = { "antenna" } },

	{ id = "Toxic", rarity = "Epic", price = 25000, income = 350, color = Color3.fromRGB(170, 255, 0), size = 3.6, extra = { "spikes" } },
	{ id = "Galaxy", rarity = "Epic", price = 60000, income = 750, color = Color3.fromRGB(90, 40, 200), size = 3.7, extra = { "halo" } },
	{ id = "Ghosty", rarity = "Epic", price = 90000, income = 1100, color = Color3.fromRGB(235, 235, 255), size = 3.8, season = 10 },
	{ id = "Ninja", rarity = "Epic", price = 150000, income = 1600, color = Color3.fromRGB(50, 50, 60), size = 3.7, extra = { "band" } },

	{ id = "Golden", rarity = "Legendary", price = 250000, income = 2500, color = Color3.fromRGB(255, 200, 40), size = 4, extra = { "crown" } },
	{ id = "Rainbow", rarity = "Legendary", price = 600000, income = 5500, color = Color3.fromRGB(255, 100, 255), size = 4.1, extra = { "halo" } },
	{ id = "Vampire", rarity = "Legendary", price = 1200000, income = 10000, color = Color3.fromRGB(140, 0, 30), size = 4.3, extra = { "horns", "wings" }, season = 10 },
	{ id = "Dragon", rarity = "Legendary", price = 2000000, income = 15000, color = Color3.fromRGB(40, 180, 90), size = 4.4, extra = { "horns", "wings" } },

	{ id = "Void", rarity = "Mythic", price = 4000000, income = 28000, color = Color3.fromRGB(30, 0, 60), size = 4.5, extra = { "horns" } },
	{ id = "Angel", rarity = "Mythic", price = 9000000, income = 60000, color = Color3.fromRGB(255, 255, 230), size = 4.6, extra = { "wings", "halo" } },
	{ id = "Phoenix", rarity = "Mythic", price = 20000000, income = 120000, color = Color3.fromRGB(255, 110, 30), size = 4.8, extra = { "wings", "crown" } },

	{ id = "Cosmic", rarity = "Divine", price = 60000000, income = 320000, color = Color3.fromRGB(60, 90, 255), size = 5, extra = { "halo", "antenna" } },
	{ id = "Titan", rarity = "Divine", price = 150000000, income = 750000, color = Color3.fromRGB(160, 160, 180), size = 5.4, extra = { "crown", "spikes" } },
	{ id = "Celestial", rarity = "Divine", price = 400000000, income = 1800000, color = Color3.fromRGB(255, 240, 160), size = 5.4, extra = { "wings", "halo" } },

	{ id = "KingSlime", rarity = "Secret", price = 1000000000, income = 4000000, color = Color3.fromRGB(255, 215, 0), size = 5.8, extra = { "crown", "wings" } },
	{ id = "Glitch", rarity = "Secret", price = 3000000000, income = 11000000, color = Color3.fromRGB(0, 255, 120), size = 5.8, extra = { "antenna", "spikes" } },

	{ id = "Codey", rarity = "Exclusive", price = 1500, income = 40, color = Color3.fromRGB(0, 230, 230), size = 3.2, extra = { "antenna", "bow" } },
	{ id = "Sunny", rarity = "Exclusive", price = 20000, income = 400, color = Color3.fromRGB(255, 230, 80), size = 3.5, extra = { "halo", "ears" } },
	{ id = "PumpkinKing", rarity = "Exclusive", price = 50000, income = 900, color = Color3.fromRGB(255, 120, 0), size = 3.8, extra = { "crown", "leaf" } },
}

Config.SlimeById = {}
Config.RarityByName = {}
Config.MutationByName = {}
for i, s in Config.Slimes do
	s.order = i
	Config.SlimeById[s.id] = s
end
for i, r in Config.Rarities do
	r.order = i
	Config.RarityByName[r.name] = r
end
for _, m in Config.Mutations do
	Config.MutationByName[m.name] = m
end

Config.EventKeys = {}
for k in Config.Events do
	table.insert(Config.EventKeys, k)
end
table.sort(Config.EventKeys)

function Config.MutationMult(mut: string?): number
	local m = mut and Config.MutationByName[mut]
	return if m then m.mult else 1
end

function Config.DisplayName(id: string, mut: string?, stars: number?): string
	return (if mut then mut .. " " .. id else id) .. Config.Stars(stars)
end

return Config
