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
	-- Holiday items only show in the shop while their holiday is on (Config.Holidays).
	CandyBucket = { id = 0, name = "🍬 Candy Bucket", price = 99, desc = "Trick-or-treat: double treats and knock again twice as fast, every Halloween.", holiday = "Halloween" },
}

Config.Products = {
	SmallCash = { id = 0, name = "Small Cash", price = 25, desc = "5 minutes of your income (min $500).", kind = "Cash", seconds = 300, min = 500 },
	BigCash = { id = 0, name = "Big Cash", price = 99, desc = "30 minutes of your income (min $5K).", kind = "Cash", seconds = 1800, min = 5000 },
	HugeCash = { id = 0, name = "Huge Cash", price = 399, desc = "3 hours of your income (min $50K).", kind = "Cash", seconds = 10800, min = 50000 },
	Luck = { id = 0, name = "5x Luck (15 min)", price = 79, desc = "5x Rare+ odds on the Slime Dispenser. Odds are shown on the machine.", kind = "Luck", seconds = 900 },
	InstantLock = { id = 0, name = "Shield (5 min)", price = 39, desc = "Nobody can raid your base for 5 minutes.", kind = "Lock", seconds = 300 },
	GrowBoost = { id = 0, name = "Grow Boost", price = 49, desc = "Every slime you own grows one stage now.", kind = "Grow" },
	SlimeRain = { id = 0, name = "Server Slime Rain", price = 199, desc = "Start a Slime Rain for everyone. Rare slimes x5!", kind = "Rain" },
	PumpkinNight = { id = 0, name = "🎃 Start Pumpkin Night", price = 149, desc = "Start Pumpkin Night for the whole server: Halloween slimes, 2x luck, candy drops!", kind = "Event", event = "PumpkinNight", holiday = "Halloween" },
	HalloweenPack = { id = 0, name = "🦇 Halloween Pack", price = 199, desc = "The Batty slime + 30 minutes of 5x LUCK. Always the same, no random.", kind = "Pack", reward = { slime = "Batty", luckMinutes = 30 }, holiday = "Halloween" },
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
	-- Weekly, on a fixed schedule on every server at once (see Config.Storm). Never rolled randomly.
	SlimeStorm = { title = "⛈️ SLIME STORM", desc = "Storm-only slimes, 3x luck, 2x cash and ⚡ Charged strikes!", luck = 3, incomeMult = 2, tint = Color3.fromRGB(190, 170, 255), scheduled = true },
	-- Holiday events only roll while their holiday is on (see Config.Holidays).
	PumpkinNight = { title = "🎃 PUMPKIN NIGHT", desc = "Halloween slimes everywhere, 2x luck and 🎃 Haunted slimes (x4 cash)!", luck = 2, tint = Color3.fromRGB(255, 175, 120), holiday = "Halloween" },
}

-- Holidays: special events on the calendar (UTC dates; `to` is the first day after it ends).
-- While one is on, its slimes (Config.Slimes `holiday`) show up on the belt and Dispenser,
-- the map gets dressed up, the music changes, and every `eventEvery`th server event is the
-- holiday's own event. Add the next holiday here (Christmas, Easter...) the same way.
Config.Holidays = {
	Halloween = {
		title = "🎃 HALLOWEEN",
		desc = "Spooky slimes on the belt, 🎃 Pumpkin Night events and trick-or-treat at every base!",
		from = { month = 10, day = 17 },
		to = { month = 11, day = 2 },
		event = "PumpkinNight",
		eventEvery = 2,
		pick = 0.3, -- chance a roll picks a holiday slime when its rarity has one
		eventPick = 0.6, -- the same chance during the holiday's own event
		-- Knock on any other player's base door once every `cooldown` seconds per base.
		-- The odds are shown on the door prompt.
		trickOrTreat = {
			cooldown = 300,
			outcomes = {
				{ label = "🍬 Treat", weight = 70, reward = { cashSeconds = 20, cashMin = 150 } },
				{ label = "🍭 Big Treat", weight = 20, reward = { cashSeconds = 40, cashMin = 300, snacks = 1 } },
				{ label = "👻 Trick", weight = 10, trick = true },
			},
		},
	},
}

-- The weekly Slime Storm: a big live event at fixed UTC times, so every server gets it at
-- once and players learn to show up (like Steal a Brainrot's Admin Abuse). wday: 1 = Sunday.
Config.Storm = {
	times = { { wday = 4, hour = 23 }, { wday = 7, hour = 17 } }, -- Wed 7 PM and Sat 1 PM US Eastern
	minutes = 20,
	warnMinutes = { 10, 5, 1 },
	stormPick = 0.5, -- during the Storm, chance a roll picks a storm slime when its rarity has one
}

-- Event drops: while an event (or a Blackout) runs, themed boxes fall into the street.
-- First player to touch one gets it. A themed box can also infuse a random pen slime
-- with the event's trait. Any event can drop a rare Lucky Box instead.
Config.EventDrops = {
	every = 5, perWave = 2, lifeSeconds = 25, maxPerPlayer = 8,
	traitChance = 0.2, luckyChance = 0.08,
	area = { x = 165, zMin = 8, zMax = 42 }, -- street between the bases, off the belt
	themes = {
		GoldenHour = { name = "Golden Crate", icon = "✨", color = Color3.fromRGB(255, 205, 60), material = "Metal", reward = { cashSeconds = 25, cashMin = 150 } },
		LavaStorm = { name = "Lava Rock", icon = "🌋", color = Color3.fromRGB(255, 90, 20), material = "CrackedLava", reward = { cashSeconds = 20, cashMin = 120 } },
		CandyParty = { name = "Candy Box", icon = "🍬", color = Color3.fromRGB(255, 130, 200), material = "SmoothPlastic", reward = { snacks = 2 } },
		CashFrenzy = { name = "Money Bag", icon = "💸", color = Color3.fromRGB(110, 230, 110), material = "Fabric", reward = { cashSeconds = 35, cashMin = 200 } },
		LuckyHour = { name = "Clover Box", icon = "🍀", color = Color3.fromRGB(90, 230, 110), material = "Grass", reward = { luckMinutes = 3 } },
		SlimeStorm = { name = "Storm Crate", icon = "⛈️", color = Color3.fromRGB(150, 140, 255), material = "Neon", reward = { cashSeconds = 45, cashMin = 300, luckMinutes = 2 } },
		Blackout = { name = "Glow Orb", icon = "🍄", color = Color3.fromRGB(110, 255, 150), material = "Neon", reward = { snackKey = "Glowcap" } },
		PumpkinNight = { name = "Candy Pumpkin", icon = "🎃", color = Color3.fromRGB(255, 130, 20), material = "SmoothPlastic", reward = { cashSeconds = 30, cashMin = 200, snacks = 1 } },
	},
	-- Odds inside a Lucky Box (shown on pickup in the notification).
	lucky = {
		{ label = "Free Slime Roll", weight = 50, reward = { freeRoll = true } },
		{ label = "Big Cash", weight = 30, reward = { cashSeconds = 120, cashMin = 800 } },
		{ label = "Lucky Roll (3x luck)", weight = 15, reward = { freeRoll = true, rollLuck = 3 } },
		{ label = "Relic", weight = 5, reward = { relic = true, source = "a Lucky Box" } },
	},
}

-- ===== Traits (like Steal a Brainrot) =====
-- Extra tags on a slime that stack with each other (their multipliers add up) and
-- multiply with mutations. Some roll on new slimes; event ones also strike slimes
-- already in your pens while that event runs (a meteor hits it, candy rains on it...).
-- chance = when rolling a new slime. event = only during that event. month = only that month.
-- holiday = only while that holiday is on (Config.Holidays).
Config.MaxTraits = 3
Config.Traits = {
	Sparkly = { icon = "✨", mult = 1.5, chance = 0.03, color = Color3.fromRGB(255, 255, 200) },
	Spooky = { icon = "👻", mult = 2.5, chance = 0.05, holiday = "Halloween", color = Color3.fromRGB(200, 120, 255) },
	Haunted = { icon = "🎃", mult = 4, chance = 0.08, event = "PumpkinNight", color = Color3.fromRGB(255, 140, 30) },
	Midas = { icon = "👑", mult = 3, chance = 0.08, event = "GoldenHour", color = Color3.fromRGB(255, 210, 60) },
	Meteor = { icon = "☄️", mult = 4, chance = 0.06, event = "LavaStorm", color = Color3.fromRGB(255, 110, 40) },
	Sugar = { icon = "🍬", mult = 3, chance = 0.08, event = "CandyParty", color = Color3.fromRGB(255, 150, 210) },
	Rich = { icon = "💵", mult = 2, chance = 0.1, event = "CashFrenzy", color = Color3.fromRGB(120, 255, 140) },
	Clover = { icon = "🍀", mult = 2.5, chance = 0.08, event = "LuckyHour", color = Color3.fromRGB(90, 230, 110) },
	Charged = { icon = "⚡", mult = 5, chance = 0.1, event = "SlimeStorm", color = Color3.fromRGB(150, 200, 255) },
}
-- While an event runs, every StrikeEverySeconds each pen slime has StrikeChance to get that event's trait.
Config.TraitStrikeEverySeconds = 30
Config.TraitStrikeChance = 0.04

function Config.TraitMult(traits: { string }?): number
	if not traits or #traits == 0 then
		return 1
	end
	local sum = 0
	local list = traits :: { string }
	for _, t in list do
		local def = Config.Traits[t]
		sum += if def then def.mult else 1
	end
	return sum
end

function Config.TraitIcons(traits: { string }?): string
	local out = ""
	local list: { string } = traits or {}
	for _, t in list do
		local def = Config.Traits[t]
		if def then
			out ..= def.icon
		end
	end
	return out
end

-- ===== Slime Snacks (diet decides evolution, like Pokémon evolution items) =====
-- Snacks drop from rolls, belt buys, quests, bounties and the King Slime, or you can buy
-- them at the Snack Bar. Feed SnackEvolve of ONE kind to a slime and it evolves into that
-- diet form for good: new look, new name, and an income boost that stacks with everything.
-- weight = drop chance share. priceMult = Snack Bar price x (base price).
Config.SnackEvolve = 5
Config.SnackDropChance = 0.2 -- per roll or belt buy
Config.SnackPriceSeconds = 25 -- Snack Bar price = income per second x this x priceMult
Config.SnackMinPrice = 150
Config.SnackOrder = { "Berry", "Pepper", "Honey", "Crystal", "Glowcap" }
Config.Snacks = {
	Berry = { icon = "🍇", diet = "Juicy", mult = 1.4, weight = 34, priceMult = 1, color = Color3.fromRGB(120, 90, 255), desc = "Bouncy and bubbly" },
	Pepper = { icon = "🌶️", diet = "Spicy", mult = 1.5, weight = 26, priceMult = 1.2, color = Color3.fromRGB(255, 70, 30), desc = "Literally on fire" },
	Honey = { icon = "🍯", diet = "Sweet", mult = 1.5, weight = 24, priceMult = 1.2, color = Color3.fromRGB(255, 185, 50), desc = "Sticky golden drips" },
	Crystal = { icon = "💎", diet = "Gem", mult = 1.8, weight = 11, priceMult = 2.5, color = Color3.fromRGB(150, 235, 255), desc = "Shiny crystal skin" },
	Glowcap = { icon = "🍄", diet = "Glowing", mult = 2.2, weight = 5, priceMult = 4, color = Color3.fromRGB(110, 255, 150), desc = "Glows in the dark" },
}
function Config.DietMult(diet: string?): number
	local s = diet and Config.Snacks[diet]
	return if s then s.mult else 1
end

-- ===== Mini games (things to do while you wait for that one slime) =====
-- Rewards scale with your income so they stay worth it, but pay about what your base
-- earns in the same time (on top of it), so they're a bonus, not a replacement.
Config.Fishing = {
	pos = Vector3.new(272, 0, -42), radius = 17,
	biteMin = 2, biteMax = 6, reelWindow = 1.1,
	-- weight = chance share. Shown on the board by the pond.
	loot = {
		{ label = "Cash", weight = 55, reward = { cashSeconds = 6, cashMin = 40 } },
		{ label = "Snack", weight = 24, reward = { snacks = 1 } },
		{ label = "Big Cash", weight = 9, reward = { cashSeconds = 30, cashMin = 200 } },
		{ label = "5 min 5x Luck", weight = 8, reward = { luckMinutes = 5 } },
		{ label = "Free Slime Roll", weight = 3, reward = { freeRoll = true } },
		{ label = "Relic", weight = 1, reward = { relic = true, source = "the Goo Pond" } },
	},
}
Config.Arcade = {
	pos = Vector3.new(272, 0, 44), seconds = 30, holes = 9,
	upStart = 1.1, upEnd = 0.55, -- how long a slime stays up, start -> end of round
	goldenChance = 0.1, bombChance = 0.12,
	cashPerPoint = 0.8, minPerPoint = 25, -- reward = max(score x min, income x score x cashPerPoint)
	snackAt = 20, luckAt = 30,
}
Config.Tower = {
	pos = Vector3.new(-276, 0, 0), steps = 38, radius = 17, rise = 3.1, turn = math.rad(24),
	cooldownSeconds = 15 * 60,
	reward = { cashSeconds = 180, cashMin = 1000, snacks = 2 },
	relicChance = 0.1,
}

-- ===== Base Relics (Balatro jokers / Hades boons) =====
-- Rule-changing charms. Equip up to RelicSlots. They drop from the King Slime, bounties,
-- quests and Index milestones, and they reset when you rebirth, so every run plays a bit
-- differently. Income relics ADD to each other (never multiply), so combos stay fair.
Config.RelicSlots = 3
Config.RelicDupCashSeconds = 180 -- a duplicate relic turns into this many seconds of income
Config.RelicDropChance = { boss = 0.5, bounty = 0.25, quest = 0.15 }
Config.RelicIndexEvery = 5 -- a relic every 5 new Index entries
Config.RelicRarities = {
	Common = { color = Color3.fromRGB(170, 230, 170), weight = 60 },
	Rare = { color = Color3.fromRGB(90, 170, 255), weight = 30 },
	Epic = { color = Color3.fromRGB(200, 110, 255), weight = 10 },
}
Config.RelicOrder = { "CommonCrowd", "StarPolish", "MutantMagnet", "DietFan", "Insurance", "StickyFloor", "SlipperySlimes", "LuckyCharm", "BargainBelt", "SnackPouch", "BountyHunter", "QuickFuse" }
Config.Relics = {
	CommonCrowd = { name = "Common Crowd", icon = "👥", rarity = "Common", desc = "+4% income for every Common slime you own (max +40%)" },
	StarPolish = { name = "Star Polish", icon = "⭐", rarity = "Rare", desc = "+6% income for every merged slime you own (max +60%)" },
	MutantMagnet = { name = "Mutant Magnet", icon = "🧲", rarity = "Rare", desc = "+5% income for every mutated slime you own (max +50%)" },
	DietFan = { name = "Diet Fan", icon = "🍽️", rarity = "Rare", desc = "+6% income for every evolved slime you own (max +60%)" },
	Insurance = { name = "Insurance", icon = "📄", rarity = "Common", desc = "When a slime is stolen from you, get 25% of its value back" },
	StickyFloor = { name = "Sticky Floor", icon = "🍯", rarity = "Common", desc = "Thieves carrying your slimes move 20% slower" },
	SlipperySlimes = { name = "Slippery Slimes", icon = "🫧", rarity = "Rare", desc = "Your stolen slimes squirm twice as often" },
	LuckyCharm = { name = "Lucky Charm", icon = "🍀", rarity = "Epic", desc = "+30% luck on the Dispenser" },
	BargainBelt = { name = "Bargain Belt", icon = "🏷️", rarity = "Common", desc = "Belt slimes cost you 15% less" },
	SnackPouch = { name = "Snack Pouch", icon = "🎒", rarity = "Common", desc = "Snacks drop twice as often" },
	BountyHunter = { name = "Bounty Hunter", icon = "🤠", rarity = "Rare", desc = "Bounties you claim pay +50% (still from the thief's pocket)" },
	QuickFuse = { name = "Quick Fuse", icon = "⚗️", rarity = "Epic", desc = "The Fuse Machine finishes twice as fast" },
}

function Config.HasRelic(data, key: string): boolean
	if not data or not data.relics then
		return false
	end
	return table.find(data.relics, key) ~= nil
end

-- Income bonus from equipped relics, added on top of 1 (0.25 = +25%).
function Config.RelicIncomeBonus(data): number
	if not data or not data.relics or #data.relics == 0 then
		return 0
	end
	local commons, stars, muts, diets = 0, 0, 0, 0
	for _, s in data.slimes do
		local def = Config.SlimeById[s.id]
		if def and def.rarity == "Common" then
			commons += 1
		end
		if (s.stars or 0) > 0 then
			stars += 1
		end
		if s.mut then
			muts += 1
		end
		if s.diet then
			diets += 1
		end
	end
	local bonus = 0
	if Config.HasRelic(data, "CommonCrowd") then
		bonus += math.min(0.4, commons * 0.04)
	end
	if Config.HasRelic(data, "StarPolish") then
		bonus += math.min(0.6, stars * 0.06)
	end
	if Config.HasRelic(data, "MutantMagnet") then
		bonus += math.min(0.5, muts * 0.05)
	end
	if Config.HasRelic(data, "DietFan") then
		bonus += math.min(0.6, diets * 0.06)
	end
	return bonus
end

-- ===== Fuse Machine (like Steal a Brainrot's) =====
-- Put in 3 slimes of any kind, pay a fee, wait, get one slime whose rarity is based on
-- the average rarity you put in. Odds are shown before you fuse.
Config.FuseCount = 3
Config.FuseSeconds = 10 * 60
Config.FuseFeeShare = 0.25 -- fee = 25% of the input slimes' prices
Config.FuseOdds = { { shift = -1, chance = 15 }, { shift = 0, chance = 50 }, { shift = 1, chance = 30 }, { shift = 2, chance = 5 } }
Config.FuseKeepMutationChance = 0.5

-- ===== Base upgrades (permanent, bought with cash, kept on rebirth) =====
Config.UpgradeOrder = { "Income", "Shield", "Pens" }
Config.Upgrades = {
	Income = { name = "Slime Food", desc = "+15% income per level", max = 10, base = 2000, growth = 5, per = 0.15 },
	Shield = { name = "Stronger Shield", desc = "+15s base lock per level", max = 5, base = 10000, growth = 6, per = 15 },
	Pens = { name = "Bigger Base", desc = "+1 pen slot per level", max = 4, base = 50000, growth = 8, per = 1 },
}

function Config.UpgradeCost(key: string, level: number): number
	local u = Config.Upgrades[key]
	return math.floor(u.base * u.growth ^ level)
end

-- ===== Player level =====
-- XP for doing things. Levels give cash, every 5 levels gives luck, and titles show over your head.
Config.XP = { buy = 5, roll = 6, collect = 0, merge = 25, steal = 40, slap = 2, gift = 10, quest = 60, fuse = 30, boss = 40, bounty = 30, avenge = 80, evolve = 50, minigame = 8 }
Config.XPPerCollect = 1 / 500 -- plus 1 XP per $500 collected (capped per collect)
function Config.XPForLevel(level: number): number
	return math.floor(80 * level ^ 1.45)
end
Config.Titles = {
	{ level = 1, name = "Slime Rookie", color = Color3.fromRGB(200, 200, 200) },
	{ level = 5, name = "Goo Collector", color = Color3.fromRGB(120, 230, 120) },
	{ level = 10, name = "Slime Wrangler", color = Color3.fromRGB(90, 170, 255) },
	{ level = 20, name = "Slime Baron", color = Color3.fromRGB(190, 110, 255) },
	{ level = 35, name = "Slime Tycoon", color = Color3.fromRGB(255, 200, 50) },
	{ level = 50, name = "Slime Legend", color = Color3.fromRGB(255, 80, 120) },
}

-- ===== Base looks: what each rebirth adds to your base (cumulative, see BaseDecor) =====
Config.BaseTiers = {
	{ rebirth = 1, name = "Stone floor and wall caps" },
	{ rebirth = 2, name = "Rooftop garden and flower boxes" },
	{ rebirth = 3, name = "Sweeping searchlights and lanterns" },
	{ rebirth = 4, name = "A whole second storey, the Goo Spiral and a grand gate" },
	{ rebirth = 5, name = "Indoor fountain and crystals" },
	{ rebirth = 6, name = "Marble and gold" },
	{ rebirth = 7, name = "A penthouse on your roof" },
	{ rebirth = 8, name = "VIP rope line and royal banners" },
	{ rebirth = 9, name = "Party lights over the entrance" },
	{ rebirth = 10, name = "Helipad with a slime copter" },
	{ rebirth = 12, name = "Golden slime statue" },
	{ rebirth = 15, name = "Floating crown" },
	{ rebirth = 20, name = "Golden pen pedestals" },
	{ rebirth = 25, name = "Rainbow trim" },
}

-- ===== Rebirth rewards: a prize the moment you rebirth, on top of the base upgrade =====
-- Uses the Rewards.Grant fields. Every rebirth also adds Config.RebirthLockBonus seconds of lock time.
Config.RebirthLockBonus = 10
Config.RebirthRewards = {
	[1] = { label = "Lucky roll + 15 min 5x Luck", freeRoll = true, rollLuck = 5, luckMinutes = 15 },
	[2] = { label = "Frosty (Rare) + 3 snacks", slime = "Frosty", snacks = 3 },
	[3] = { label = "Galaxy (Epic) + a relic", slime = "Galaxy", relic = true },
	[4] = { label = "Ninja (Epic) + 30 min 5x Luck", slime = "Ninja", luckMinutes = 30 },
	[5] = { label = "Golden (Legendary)", slime = "Golden" },
	[6] = { label = "Rainbow (Legendary) + a relic", slime = "Rainbow", relic = true },
	[7] = { label = "Dragon (Legendary) + 5 snacks", slime = "Dragon", snacks = 5 },
	[8] = { label = "Void (Mythic)", slime = "Void" },
	[9] = { label = "Angel (Mythic) + a relic", slime = "Angel", relic = true },
	[10] = { label = "Phoenix (Mythic) + 60 min 5x Luck", slime = "Phoenix", luckMinutes = 60 },
	[12] = { label = "Cosmic (Divine)", slime = "Cosmic" },
	[15] = { label = "Titan (Divine) + a relic", slime = "Titan", relic = true },
	[20] = { label = "Celestial (Divine)", slime = "Celestial" },
}
-- Rebirths without their own prize get a super-lucky roll.
Config.RebirthRewardDefault = { label = "Super lucky roll + 30 min 5x Luck", freeRoll = true, rollLuck = 15, luckMinutes = 30 }

-- ===== Standout systems (from player feedback on steal games) =====
-- Squirm: stolen slimes are slippery. While carried, they try to wriggle free and the thief
-- has to tap HOLD ON in time or the slime bounces home. Rarer slimes squirm more.
Config.SquirmEverySeconds = 2.5
Config.SquirmWindow = 1.4
function Config.SquirmChance(rarityOrder: number): number
	return 0.03 + 0.015 * rarityOrder
end
-- Revenge: after you're robbed, the thief's shield can't stop you for a while, you carry at
-- full speed when stealing from them, and they glow for you.
Config.RevengeSeconds = 90
-- Blackout (Doors / 99 Nights style): the power goes out, free locks stop working and the
-- Gloom roams the street between bases. Bought shields and the Rookie Shield still hold.
Config.Blackout = {
	firstDelay = 9 * 60, everySeconds = 25 * 60, seconds = 90, warnSeconds = 5,
	size = 8, height = 5, roamX = 175, roamZ = 40,
	roamSpeed = 7, chaseSpeed = 11, chaseRange = 40, catchRange = 5, graceSeconds = 4,
}
-- Nemesis: steals from the same thief before they become your Nemesis.
Config.Nemesis = { steals = 2, chaseRange = 70, chaseSpeed = 1.2, bountyMult = 1.5 }
-- Bounty: every steal puts a bounty on the thief. Slap, zap or trap them to cash it in.
Config.BountyShare = 0.25 -- of the stolen slime's sell value
Config.BountyMaxIncomeSeconds = 600 -- a claim pays at most this many seconds of the claimer's income
Config.BountyMinPayout = 250
-- Rookie Shield: brand new players can't be robbed until they've earned this much
-- (or rebirth, or steal from someone themselves).
Config.RookieEarnedLimit = 3000
-- King Slime: a co-op boss that crashes into the middle of the map. Slap it together.
Config.King = {
	firstDelay = 240,
	everySeconds = 720,
	lifeSeconds = 150,
	baseHp = 30,
	hpPerPlayer = 20,
	slapDamage = 1,
	taserDamage = 5,
	hopEvery = 2.2,
	stompEvery = 3, -- every Nth hop is a stomp
	stompRange = 18,
	stompForce = 65,
	-- Hops around a strip between the belt and the south bases (spawn side), clear of plots.
	pos = Vector3.new(60, 0, -21),
	roamX = 24,
	roamZ = 3,
	enrageAt = 0.3, -- below 30% HP it hops faster and stomps every hop
	warnSeconds = 4,
	size = 12,
	rewardSeconds = 240, -- cash = income x this x (0.5 + your share of the hits)
	rewardMin = 1500,
	topRollLuck = 5,
}

-- ===== Slime Index milestones (granted automatically) =====
Config.IndexMilestones = {
	{ count = 5, label = "$2K + 10 min Luck", cash = 2000, luckMinutes = 10 },
	{ count = 10, label = "$25K + Grow Boost", cash = 25000, grow = true },
	{ count = 15, label = "Lucky free roll", freeRoll = true, rollLuck = 5 },
	{ count = 20, label = "$1M + 30 min Luck", cash = 1000000, luckMinutes = 30 },
	{ count = 25, label = "$50M", cash = 50000000 },
	{ count = 30, label = "$1B + Lucky roll", cash = 1000000000, freeRoll = true, rollLuck = 10 },
}

-- ===== Base skins (unlocked by discovering slimes, like Steal a Brainrot's index skins) =====
-- need = different slimes in your Slime Index. Change skin at the 🎨 stand in your base.
-- wall/trim recolour the castle walls, posts, battlements and towers.
Config.BaseSkins = {
	{ key = "Classic", name = "Classic", need = 0 },
	{ key = "Stone", name = "Stone Keep", need = 6, wall = Color3.fromRGB(150, 148, 158), wallMat = "Cobblestone", trim = Color3.fromRGB(105, 100, 115), trimMat = "Slate" },
	{ key = "Candy", name = "Candy Castle", need = 12, wall = Color3.fromRGB(255, 170, 215), wallMat = "SmoothPlastic", trim = Color3.fromRGB(255, 250, 255), trimMat = "SmoothPlastic" },
	{ key = "Frost", name = "Frost Fort", need = 18, wall = Color3.fromRGB(190, 235, 255), wallMat = "Ice", trim = Color3.fromRGB(240, 250, 255), trimMat = "Glacier" },
	{ key = "Gold", name = "Golden Fort", need = 24, wall = Color3.fromRGB(255, 205, 70), wallMat = "Metal", trim = Color3.fromRGB(255, 240, 170), trimMat = "Metal" },
	{ key = "Galaxy", name = "Galaxy Citadel", need = 30, wall = Color3.fromRGB(60, 30, 120), wallMat = "Foil", trim = Color3.fromRGB(170, 120, 255), trimMat = "Neon" },
}

-- ===== Gear (bought with cash in the GEAR menu, kept forever) =====
-- rebirth = rebirths needed to buy it. Slap is free for everyone.
-- Slap weapons (slap = true) form a ladder: you hold only the best one you own. Better slaps
-- hit harder and further and add effects: slow (speed x for slowFor s), freeze (s), chain
-- (also zaps the nearest other player within chain studs), aoe (knocks everyone within aoe
-- studs of the target), up (how high the knock throws). They're sold at the 🥊 Slap Shop.
Config.SlapOrder = { "Slap", "JellyGlove", "StickySlapper", "BubbleBat", "ThunderPaddle", "FrostMitten", "MeteorMallet", "GalaxyGauntlet", "KingScepter" }
Config.GearOrder = { "Slap", "JellyGlove", "StickySlapper", "BubbleBat", "ThunderPaddle", "FrostMitten", "MeteorMallet", "GalaxyGauntlet", "KingScepter", "SpeedCoil", "GravityCoil", "Trap", "Taser" }
Config.Gear = {
	Slap = { name = "Slap Hand", slap = true, price = 0, rebirth = 0, desc = "Knock players away. Slap a thief and they drop your slime!", color = Color3.fromRGB(255, 200, 150), cooldown = 1.2, range = 9, force = 70 },
	JellyGlove = { name = "Jelly Glove", slap = true, price = 15000, rebirth = 0, desc = "A wobbly glove that hits harder and further.", color = Color3.fromRGB(120, 230, 160), cooldown = 1.05, range = 10, force = 95, look = "glove" },
	StickySlapper = { name = "Sticky Slapper", slap = true, price = 60000, rebirth = 1, desc = "Covers them in goo: 50% slower for 3s.", color = Color3.fromRGB(170, 255, 90), cooldown = 1, range = 11, force = 105, slow = 0.5, slowFor = 3, look = "paddle" },
	BubbleBat = { name = "Bubble Bat", slap = true, price = 300000, rebirth = 2, desc = "Pops a bubble round them: stuck for 1.5s.", color = Color3.fromRGB(120, 200, 255), cooldown = 1, range = 12, force = 120, freeze = 1.5, look = "bat" },
	ThunderPaddle = { name = "Thunder Paddle", slap = true, price = 1500000, rebirth = 3, desc = "Lightning jumps to a second player nearby.", color = Color3.fromRGB(255, 235, 80), cooldown = 0.95, range = 13, force = 135, chain = 16, look = "paddle" },
	FrostMitten = { name = "Frost Mitten", slap = true, price = 8000000, rebirth = 4, desc = "Freezes them solid for 2.5s.", color = Color3.fromRGB(190, 240, 255), cooldown = 0.95, range = 13, force = 140, freeze = 2.5, look = "glove" },
	MeteorMallet = { name = "Meteor Mallet", slap = true, price = 200000000, rebirth = 6, desc = "Sends them flying sky-high and knocks back everyone close.", color = Color3.fromRGB(255, 120, 50), cooldown = 0.9, range = 14, force = 170, up = 1.4, aoe = 10, look = "mallet" },
	GalaxyGauntlet = { name = "Galaxy Gauntlet", slap = true, price = 5000000000, rebirth = 8, desc = "Huge reach, big shockwave, stuck for 1.5s.", color = Color3.fromRGB(170, 110, 255), cooldown = 0.8, range = 17, force = 200, aoe = 14, freeze = 1.5, look = "glove" },
	KingScepter = { name = "King's Scepter", slap = true, price = 3000000000000, rebirth = 12, desc = "The ultimate slap: chain lightning, shockwave and a 2s freeze.", color = Color3.fromRGB(255, 205, 60), cooldown = 0.7, range = 19, force = 230, up = 1.1, aoe = 14, chain = 20, freeze = 2, look = "scepter" },
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
	{ kind = "bounty", goal = 1, text = "Claim %d bounty on a thief" },
	{ kind = "boss", goal = 1, text = "Help beat the King Slime %d time" },
	{ kind = "evolve", goal = 1, text = "Evolve %d slime with snacks" },
	{ kind = "minigame", goal = 3, text = "Play %d mini games (fishing, arcade, tower)" },
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
Config.BaseSlots = 6
Config.SlotsPerRebirth = 1
Config.MaxSlots = 16 -- 8 pens downstairs + 8 on the second floor
Config.GroundSlots = 8 -- the cap until the second floor is built
Config.SecondFloorRebirth = 4
Config.ExtraPensSlots = 4
Config.RebirthIncomeBonus = 1 -- +100% income per rebirth (x2, x3, x4...)
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
-- Background music. Every track is from Roblox's own licensed music library (uploaded by
-- APMOfficial), so it is cleared for use in any Roblox game. The main list plays shuffled;
-- while an event runs, its own track takes over and loops until the event ends.
Config.MusicVolume = 0.3
Config.Music = {
	{ id = "rbxassetid://1842203247", name = "Happy Funk" },
	{ id = "rbxassetid://1842801496", name = "Right Here" },
	{ id = "rbxassetid://1842285773", name = "The Cactus Kid" },
	{ id = "rbxassetid://1846818766", name = "Happy Whistling" },
	{ id = "rbxassetid://1847543886", name = "Cross Country" },
	{ id = "rbxassetid://1845736900", name = "Happy End" },
	{ id = "rbxassetid://1845756489", name = "Town Talk" },
}
-- Keys match Config.Events, plus Blackout, SlimeRain and King (the Slime King boss).
Config.EventMusic = {
	GoldenHour = { id = "rbxassetid://9045322527", name = "Hollywood Romance" },
	LavaStorm = { id = "rbxassetid://1838757391", name = "Evolution's Drawbacks" },
	CandyParty = { id = "rbxassetid://9043853947", name = "Cherry Juice" },
	CashFrenzy = { id = "rbxassetid://1836755212", name = "Get Crazy" },
	LuckyHour = { id = "rbxassetid://1838577804", name = "Irish Dance" },
	SlimeStorm = { id = "rbxassetid://1847041997", name = "Drowning 3" },
	Blackout = { id = "rbxassetid://1847313950", name = "Spooky Kooky" },
	SlimeRain = { id = "rbxassetid://1836420164", name = "Celebration Time" },
	King = { id = "rbxassetid://9045156325", name = "Fire In The Sky" },
	PumpkinNight = { id = "rbxassetid://1836009678", name = "Fast Paced Halloween" },
}

-- Holiday playlists: replace Config.Music while the holiday is on (no event running).
Config.HolidayMusic = {
	Halloween = {
		{ id = "rbxassetid://1836009626", name = "Halloween Horrors Waltz" },
		{ id = "rbxassetid://139190190976686", name = "Halloween Music Box" },
		{ id = "rbxassetid://1837467198", name = "Night of the Ghouls" },
		{ id = "rbxassetid://1838592691", name = "Halloween Night" },
	},
}

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

-- extra: decorations built on the slime (crown, halo, horns, angelwings, firewings, demonwings, dragonwings,
-- batwings, antenna, leaf, ears, spikes, band, bow, witchhat, fangs, jackface). Wings flap.
-- aura: colour of the slime's aura (ring, shell, orbs) instead of its rarity colour, e.g. red for evil ones.
-- Auras grow with rarity: sparkles (Rare), ground ring (Epic), force-field shell (Legendary),
-- orbiting orbs and flames (Mythic), a second ring and rising light (Divine and Secret).
-- season: month number it can spawn in (others keep it once owned).
-- holiday: only spawns while that holiday is on (Config.Holidays); owners keep it forever.
-- storm: only spawns during the weekly Slime Storm.
Config.Slimes = {
	{ id = "Goop", name = "Goopini Goopala", rarity = "Common", price = 25, income = 1, color = Color3.fromRGB(120, 230, 120), size = 2.6 },
	{ id = "Dewdrop", name = "Dewdropo Splashini", rarity = "Common", price = 60, income = 2, color = Color3.fromRGB(120, 200, 255), size = 2.7, extra = { "antenna" } },
	{ id = "Pebble", name = "Pebblino Rockarino", rarity = "Common", price = 120, income = 4, color = Color3.fromRGB(150, 140, 130), size = 2.8 },
	{ id = "Leafy", name = "Leafuccio Verdolino", rarity = "Common", price = 200, income = 6, color = Color3.fromRGB(170, 230, 90), size = 2.8, extra = { "leaf" } },

	{ id = "Minty", name = "Mintolini Freschino", rarity = "Uncommon", price = 400, income = 10, color = Color3.fromRGB(150, 255, 210), size = 3, extra = { "ears" } },
	{ id = "Bubblegum", name = "Bubbaloo Gommarella", rarity = "Uncommon", price = 900, income = 20, color = Color3.fromRGB(255, 140, 200), size = 3.1, extra = { "bow" } },
	{ id = "Pumpkin", name = "Zucchino Pumpkinello", rarity = "Uncommon", price = 1500, income = 32, color = Color3.fromRGB(255, 130, 20), size = 3.2, extra = { "leaf", "jackface" }, holiday = "Halloween" },

	{ id = "Lava", name = "Lavarino Bollentino", rarity = "Rare", price = 3000, income = 55, color = Color3.fromRGB(255, 90, 20), size = 3.3, extra = { "horns" } },
	{ id = "Frosty", name = "Frostolo Brrrrino", rarity = "Rare", price = 7500, income = 120, color = Color3.fromRGB(190, 240, 255), size = 3.4, extra = { "spikes" } },
	{ id = "Stormy", name = "Nuvolone Tempestino", rarity = "Rare", price = 12000, income = 260, color = Color3.fromRGB(120, 130, 200), size = 3.4, extra = { "antenna", "ears" }, storm = true },
	{ id = "Batty", name = "Pipistrellino Svolazzone", rarity = "Rare", price = 10000, income = 200, color = Color3.fromRGB(95, 70, 120), size = 3.4, extra = { "ears", "batwings", "fangs" }, holiday = "Halloween" },
	{ id = "Zappy", name = "Zappadoodle Zappazap", rarity = "Rare", price = 15000, income = 220, color = Color3.fromRGB(255, 240, 60), size = 3.4, extra = { "antenna" } },

	{ id = "Toxic", name = "Toxicolli Bleghissimo", rarity = "Epic", price = 25000, income = 350, color = Color3.fromRGB(170, 255, 0), size = 3.6, extra = { "spikes" } },
	{ id = "Galaxy", name = "Galassio Stellarino", rarity = "Epic", price = 60000, income = 750, color = Color3.fromRGB(90, 40, 200), size = 3.7, extra = { "halo" } },
	{ id = "Ghosty", name = "Boo Boo Fantasmino", rarity = "Epic", price = 90000, income = 1100, color = Color3.fromRGB(235, 235, 255), size = 3.8, holiday = "Halloween" },
	{ id = "Thunderbolt", name = "Tuono Tuono Boltaccio", rarity = "Epic", price = 120000, income = 2000, color = Color3.fromRGB(255, 255, 120), size = 3.8, extra = { "spikes", "antenna" }, storm = true },
	{ id = "Ninja", name = "Ninjarino Shhhhini", rarity = "Epic", price = 150000, income = 1600, color = Color3.fromRGB(50, 50, 60), size = 3.7, extra = { "band" } },

	{ id = "Golden", name = "Goldoni Ricchissimo", rarity = "Legendary", price = 250000, income = 2500, color = Color3.fromRGB(255, 200, 40), size = 4, extra = { "crown" } },
	{ id = "Rainbow", name = "Arcobalenino Sparkalala", rarity = "Legendary", price = 600000, income = 5500, color = Color3.fromRGB(255, 100, 255), size = 4.1, extra = { "halo" } },
	{ id = "Vampire", name = "Vampirelli Bitebite", rarity = "Legendary", price = 1200000, income = 10000, color = Color3.fromRGB(140, 0, 30), size = 4.3, aura = Color3.fromRGB(220, 0, 40), extra = { "fangs", "batwings" }, holiday = "Halloween" },
	{ id = "Tempest", name = "Uraganino Tempestoso", rarity = "Legendary", price = 1500000, income = 18000, color = Color3.fromRGB(80, 60, 200), size = 4.4, aura = Color3.fromRGB(120, 190, 255), extra = { "angelwings", "halo" }, storm = true },
	{ id = "Dragon", name = "Draghettino Fiammifero", rarity = "Legendary", price = 2000000, income = 15000, color = Color3.fromRGB(40, 180, 90), size = 4.4, extra = { "horns", "dragonwings" } },

	{ id = "Void", name = "Vuotolino Nullissimo", rarity = "Mythic", price = 4000000, income = 28000, color = Color3.fromRGB(30, 0, 60), size = 4.5, aura = Color3.fromRGB(170, 0, 255), extra = { "horns", "demonwings" } },
	{ id = "Angel", name = "Angelino Halollo", rarity = "Mythic", price = 9000000, income = 60000, color = Color3.fromRGB(255, 255, 230), size = 4.6, aura = Color3.fromRGB(255, 225, 120), extra = { "angelwings", "halo" } },
	{ id = "Witchy", name = "Streghina Pozionella", rarity = "Mythic", price = 12000000, income = 85000, color = Color3.fromRGB(130, 220, 90), size = 4.6, aura = Color3.fromRGB(170, 70, 255), extra = { "witchhat" }, holiday = "Halloween" },
	{ id = "Phoenix", name = "Fenicino Fuocobello", rarity = "Mythic", price = 20000000, income = 120000, color = Color3.fromRGB(255, 110, 30), size = 4.8, aura = Color3.fromRGB(255, 120, 30), extra = { "firewings", "crown" } },

	{ id = "Cosmic", name = "Cosmolino Universone", rarity = "Divine", price = 60000000, income = 320000, color = Color3.fromRGB(60, 90, 255), size = 5, extra = { "halo", "antenna" } },
	{ id = "Titan", name = "Titanone Gigantesco", rarity = "Divine", price = 150000000, income = 750000, color = Color3.fromRGB(160, 160, 180), size = 5.4, extra = { "crown", "spikes" } },
	{ id = "Celestial", name = "Celestino Divinissimo", rarity = "Divine", price = 400000000, income = 1800000, color = Color3.fromRGB(255, 240, 160), size = 5.4, aura = Color3.fromRGB(255, 215, 90), extra = { "angelwings", "halo" } },

	{ id = "KingSlime", name = "Re Slimone Supremo", rarity = "Secret", price = 1000000000, income = 4000000, color = Color3.fromRGB(255, 215, 0), size = 5.8, aura = Color3.fromRGB(255, 200, 40), extra = { "crown", "angelwings" } },
	{ id = "Glitch", name = "Glitchini Errorrino", rarity = "Secret", price = 3000000000, income = 11000000, color = Color3.fromRGB(0, 255, 120), size = 5.8, aura = Color3.fromRGB(0, 255, 120), extra = { "antenna", "spikes" } },

	{ id = "Codey", name = "Codeyno Bippity", rarity = "Exclusive", price = 1500, income = 40, color = Color3.fromRGB(0, 230, 230), size = 3.2, extra = { "antenna", "bow" } },
	{ id = "Sunny", name = "Solino Sunnissimo", rarity = "Exclusive", price = 20000, income = 400, color = Color3.fromRGB(255, 230, 80), size = 3.5, extra = { "halo", "ears" } },
	{ id = "Starling", name = "Stellina Twinkolina", rarity = "Exclusive", price = 40000, income = 800, color = Color3.fromRGB(120, 170, 255), size = 3.7, extra = { "halo", "angelwings" } },
	{ id = "PumpkinKing", name = "Re Zuccone Pumpkinissimo", rarity = "Exclusive", price = 50000, income = 900, color = Color3.fromRGB(255, 120, 0), size = 3.8, extra = { "crown", "leaf" } },
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
for k, e in Config.Events do
	if not e.scheduled and not e.holiday then
		table.insert(Config.EventKeys, k)
	end
end
table.sort(Config.EventKeys)

function Config.MutationMult(mut: string?): number
	local m = mut and Config.MutationByName[mut]
	return if m then m.mult else 1
end

-- The silly name players see (and hear) for a slime id. Ids stay short for saves and code.
function Config.SlimeName(id: string): string
	local def = Config.SlimeById[id]
	return if def and def.name then def.name else id
end

function Config.DisplayName(id: string, mut: string?, stars: number?, traits: { string }?, diet: string?): string
	local icons = Config.TraitIcons(traits)
	local snack = diet and Config.Snacks[diet]
	local name = if snack then snack.diet .. " " .. Config.SlimeName(id) else Config.SlimeName(id)
	return (if icons ~= "" then icons .. " " else "") .. (if mut then mut .. " " .. name else name) .. Config.Stars(stars)
end

-- First-time guide: a short pinned objective with an arrow. Each step ends on a Signals kind.
Config.Tutorial = {
	{ kind = "buy", text = "Buy a slime! Walk to the conveyor belt and hold E on one.", alt = "roll" },
	{ kind = "collect", text = "Your slime makes cash. Step on your green pad to collect it." },
	{ kind = "lock", text = "Press the red button in your base to lock it from thieves." },
}
Config.TutorialReward = { cashMin = 400, freeRoll = true }

-- Slime Season: a free monthly reward track (UTC calendar month). Season XP comes from
-- playing; every Config.Season.tierXP unlocks the next tier. Tier 30 is the season slime.
Config.Season = {
	tierXP = 100,
	points = { quest = 40, bounty = 30, boss = 50, minigame = 15, steal = 20, avenge = 30, rebirth = 120, evolve = 40, fuse = 25, merge = 15, gift = 10, buy = 3, roll = 3 },
	slime = "Starling",
	tiers = {},
}
for i = 1, 30 do
	local t
	if i == 30 then
		t = { label = "🌟 Starling slime (season exclusive)", reward = { slime = "Starling" } }
	elseif i % 10 == 0 then
		t = { label = "🔮 Relic", reward = { relic = true, source = "the Slime Season" } }
	elseif i % 5 == 0 then
		t = { label = "🎰 Lucky roll (3x luck)", reward = { freeRoll = true, rollLuck = 3 } }
	elseif i % 3 == 0 then
		t = { label = "🍽️ 2 snacks", reward = { snacks = 2 } }
	elseif i % 2 == 0 then
		t = { label = "🍀 5 min 5x luck", reward = { luckMinutes = 5 } }
	else
		t = { label = "💰 Cash (" .. (i + 1) .. " min of income)", reward = { cashSeconds = (i + 1) * 60, cashMin = 200 * i } }
	end
	Config.Season.tiers[i] = t
end

-- Phone alerts (Roblox experience notifications) when someone steals from you.
-- Roblox allows 1 per player per day per game, only to players 13+ who opted in, and
-- only once the game has 100+ visits. Setup after publishing (see README):
--   1. Creator Hub > your game > Engagement > Notifications > create a string such as
--      "{thief} stole your {slime}! Get it back in {experienceName}" and copy its Asset ID here.
--   2. Create an Open Cloud API key with the notification permission and save it as a
--      game secret named below (Creator Hub > your game > Secrets).
--   3. Game Settings > Security > Allow HTTP Requests.
Config.PhoneAlerts = {
	stolenMessageId = "", -- paste the notification string's Asset ID
	secretName = "notifications_key",
	everyHours = 20, -- don't try more often than this per player (Roblox caps it at 1/day anyway)
}

return Config
