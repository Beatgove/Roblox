-- Random rolls shared by the belt and the dispenser: rarity, slime and mutation.

local Config = require(game.ReplicatedStorage.Shared.Config)

local Roller = {}

local rng = Random.new()

function Roller.Rarity(luck: number)
	local total = 0
	local weights = {}
	for i, r in Config.Rarities do
		local w = r.weight * (if r.order >= 3 then luck else 1)
		weights[i] = w
		total += w
	end
	local roll = rng:NextNumber() * total
	for i, r in Config.Rarities do
		roll -= weights[i]
		if roll <= 0 and weights[i] > 0 then
			return r
		end
	end
	return Config.Rarities[1]
end

local function stormOn(): boolean
	return workspace:GetAttribute("Event") == "SlimeStorm" and (workspace:GetAttribute("EventUntil") or 0) > workspace:GetServerTimeNow()
end

-- The holiday on right now (Config.Holidays key), if any. HolidayService sets it.
function Roller.Holiday(): string?
	return workspace:GetAttribute("Holiday")
end

-- Slimes of a rarity that can spawn right now (seasonal ones only in their month,
-- holiday ones only during their holiday, storm ones only during the Slime Storm).
function Roller.Spawnable(rarityName: string)
	local month = os.date("!*t").month
	local storm = stormOn()
	local holiday = Roller.Holiday()
	local list = {}
	for _, s in Config.Slimes do
		if s.rarity == rarityName and (s.season == nil or s.season == month) and (s.holiday == nil or s.holiday == holiday) and (not s.storm or storm) then
			table.insert(list, s)
		end
	end
	return list
end

function Roller.Slime(luck: number)
	local list
	repeat
		list = Roller.Spawnable(Roller.Rarity(luck).name)
	until #list > 0
	-- During the Storm, storm slimes show up often so everyone has a real shot at one.
	if stormOn() and rng:NextNumber() < Config.Storm.stormPick then
		local storm = {}
		for _, s in list do
			if s.storm then
				table.insert(storm, s)
			end
		end
		if #storm > 0 then
			return storm[rng:NextInteger(1, #storm)]
		end
	end
	-- During a holiday its slimes turn up often, and even more during its own event.
	local holiday = Roller.Holiday()
	local h = holiday and Config.Holidays[holiday]
	if h then
		local pick = if Roller.ActiveEvent() == h.event then h.eventPick else h.pick
		if rng:NextNumber() < pick then
			local special = {}
			for _, s in list do
				if s.holiday == holiday then
					table.insert(special, s)
				end
			end
			if #special > 0 then
				return special[rng:NextInteger(1, #special)]
			end
		end
	end
	return list[rng:NextInteger(1, #list)]
end

-- The server event running right now (Config.Events key), if any.
function Roller.ActiveEvent(): string?
	local e = workspace:GetAttribute("Event")
	if e and (workspace:GetAttribute("EventUntil") or 0) > workspace:GetServerTimeNow() then
		return e
	end
	return nil
end

-- Extra luck from the current event (Lucky Hour).
function Roller.EventLuck(): number
	local e = Roller.ActiveEvent()
	return if e and Config.Events[e].luck then Config.Events[e].luck else 1
end

function Roller.Mutation(luck: number): string?
	local boost = if luck > 1 then 2 else 1
	local event = Roller.ActiveEvent()
	local golden = if event and Config.Events[event].goldenMult then Config.Events[event].goldenMult else 1
	-- Rarest first so a lucky roll lands on the best mutation.
	for i = #Config.Mutations, 1, -1 do
		local m = Config.Mutations[i]
		if m.event and m.event ~= event then
			continue
		end
		local chance = m.chance * boost * (if m.name == "Golden" then golden else 1)
		if rng:NextNumber() < chance then
			return m.name
		end
	end
	return nil
end

-- Traits a brand-new slime is born with (Sparkly any time, event/month traits when active).
function Roller.Traits(): { string }?
	local event = Roller.ActiveEvent()
	local month = os.date("!*t").month
	local holiday = Roller.Holiday()
	local out = {}
	for name, t in Config.Traits do
		if (t.event == nil or t.event == event) and (t.month == nil or t.month == month) and (t.holiday == nil or t.holiday == holiday) and rng:NextNumber() < t.chance then
			table.insert(out, name)
		end
	end
	table.sort(out)
	return if #out > 0 then out else nil
end

-- Percent chance of each rarity at a given luck, for the odds display.
function Roller.Odds(luck: number)
	local total = 0
	for _, r in Config.Rarities do
		total += r.weight * (if r.order >= 3 then luck else 1)
	end
	local out = {}
	for _, r in Config.Rarities do
		if r.weight > 0 then
			table.insert(out, { name = r.name, pct = 100 * r.weight * (if r.order >= 3 then luck else 1) / total })
		end
	end
	return out
end

return Roller
