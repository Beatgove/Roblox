-- The Slime Dispenser: pay cash, get a random slime. Personal 5x luck and Slime Rain boost it.
-- Odds are shown on the board next to the machine (Roblox requires visible odds for random rewards).

local Config = require(game.ReplicatedStorage.Shared.Config)
local Util = require(game.ReplicatedStorage.Shared.Util)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local ConveyorService = require(script.Parent.ConveyorService)
local MapBuilder = require(script.Parent.MapBuilder)
local Roller = require(script.Parent.Roller)
local Net = require(script.Parent.Net)
local Signals = require(script.Parent.Signals)

local DispenserService = {}

local lastRoll: { [Player]: number } = {}

function DispenserService.Luck(player: Player): number
	local luck = 1
	if PlotService.LuckUntil(player) > os.time() then
		luck *= Config.LuckMult
	end
	if ConveyorService.IsRaining() then
		luck *= Config.RainLuck
	end
	luck *= Roller.EventLuck()
	if Config.HasRelic(DataService.Get(player), "LuckyCharm") then
		luck *= 1.3
	end
	return math.min(luck, Config.MaxLuck)
end

function DispenserService.GiveLuck(player: Player, seconds: number)
	local data = DataService.Get(player)
	if not data then
		return
	end
	data.luckUntil = math.max(data.luckUntil, os.time()) + seconds
	PlotService.Sync(player)
	Net.Fx(player, "luck", {})
end

-- free: a gift roll (no cost, no cooldown). minLuck: luck floor for that roll.
local function roll(player: Player, free: boolean?, minLuck: number?): boolean
	local t = os.clock()
	if not free and lastRoll[player] and t - lastRoll[player] < Config.DispenserCooldown then
		return false
	end
	local data = DataService.Get(player)
	if not data then
		return false
	end
	local cost = if free then 0 else PlotService.RollCost(player)
	if data.cash < cost then
		Net.Notify(player, "A roll costs " .. Util.Money(cost) .. ". Collect more cash!", "bad")
		Net.Fx(player, "deny", {})
		return false
	end
	if not PlotService.HasFreeSlot(player) then
		Net.Notify(player, "Your pens are full! Sell a slime or rebirth for more space.", "bad")
		Net.Fx(player, "deny", {})
		return false
	end
	if not free then
		lastRoll[player] = t
	end
	data.cash -= cost
	data.rolls += 1
	PlotService.Sync(player)
	Signals.Progress(player, "roll")

	local luck = math.max(DispenserService.Luck(player), minLuck or 1)
	local def = Roller.Slime(luck)
	local mut = Roller.Mutation(luck)
	local traits = Roller.Traits()
	local rarity = Config.RarityByName[def.rarity]
	local name = Config.DisplayName(def.id, mut, nil, traits)

	-- The client plays a spin animation, then reveals; the slime lands when the reveal ends.
	Net.Fx(player, "roll", { name = name, rarity = def.rarity, mut = mut, luck = luck })
	Net.FxAll("dispense", { pos = MapBuilder.DispenserPosition, color = rarity.color, order = rarity.order })
	task.delay(1.6, function()
		if not player.Parent then
			return
		end
		if not PlotService.AddSlime(player, { id = def.id, born = os.time(), mut = mut, traits = traits }) then
			-- Pens filled up during the animation: refund (a free roll pays the slime's value).
			PlotService.AddCash(player, if free then PlotService.SellValue({ id = def.id, mut = mut, traits = traits }) else cost)
			Net.Notify(player, "Pens full, roll refunded.", "bad")
			return
		end
		if rarity.order >= 5 or mut or traits then
			Net.NotifyAll("🎰 " .. player.DisplayName .. " rolled a " .. def.rarity .. " " .. name .. " from the Dispenser!", "epic")
		end
	end)
	return true
end

-- A free roll from a gift. Returns false if it couldn't happen (pens full).
function DispenserService.FreeRoll(player: Player, minLuck: number?): boolean
	return roll(player, true, minLuck)
end

local function oddsText(): string
	local lines = { "ODDS PER ROLL" }
	for _, o in Roller.Odds(1) do
		local pct = if o.pct >= 1 then string.format("%.1f%%", o.pct) else string.format("%.3f%%", o.pct)
		table.insert(lines, o.name .. ": " .. pct)
	end
	table.insert(lines, "")
	table.insert(lines, "5x LUCK = 5x chance of")
	table.insert(lines, "Rare and better")
	table.insert(lines, "Mutations: Golden 5%, Diamond 1%,")
	table.insert(lines, "Rainbow 0.2% (x2 with luck)")
	table.insert(lines, "Events: Golden x10 in Golden Hour,")
	table.insert(lines, "Lava 15% in Lava Storm,")
	table.insert(lines, "Candy 8% in Candy Party")
	table.insert(lines, "Traits: Sparkly 3%, event traits 6-10%")
	return table.concat(lines, "\n")
end

function DispenserService.Start()
	local machine = MapBuilder.Dispenser
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RollPrompt"
	prompt.ActionText = "Roll a Slime!"
	prompt.ObjectText = "Slime Dispenser"
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt.Parent = machine
	prompt.Triggered:Connect(function(player)
		roll(player)
	end)

	local board = MapBuilder.OddsBoard
	if board then
		board.Text = oddsText()
	end

	game:GetService("Players").PlayerRemoving:Connect(function(p)
		lastRoll[p] = nil
	end)
end

return DispenserService
