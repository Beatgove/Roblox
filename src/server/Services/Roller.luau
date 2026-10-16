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

-- Slimes of a rarity that can spawn right now (seasonal ones only in their month).
function Roller.Spawnable(rarityName: string)
	local month = os.date("!*t").month
	local list = {}
	for _, s in Config.Slimes do
		if s.rarity == rarityName and (s.season == nil or s.season == month) then
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
