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

local function roll(player: Player)
	local t = os.clock()
	if lastRoll[player] and t - lastRoll[player] < Config.DispenserCooldown then
		return
	end
	local data = DataService.Get(player)
	if not data then
		return
	end
	local cost = PlotService.RollCost(player)
	if data.cash < cost then
		Net.Notify(player, "A roll costs " .. Util.Money(cost) .. ". Collect more cash!", "bad")
		Net.Fx(player, "deny", {})
		return
	end
	if not PlotService.HasFreeSlot(player) then
		Net.Notify(player, "Your pens are full! Sell a slime or rebirth for more space.", "bad")
		Net.Fx(player, "deny", {})
		return
	end
	lastRoll[player] = t
	data.cash -= cost
	data.rolls += 1
	PlotService.Sync(player)

	local luck = DispenserService.Luck(player)
	local def = Roller.Slime(luck)
	local mut = Roller.Mutation(luck)
	local rarity = Config.RarityByName[def.rarity]
	local name = Config.DisplayName(def.id, mut)

	-- The client plays a spin animation, then reveals; the slime lands when the reveal ends.
	Net.Fx(player, "roll", { name = name, rarity = def.rarity, mut = mut, luck = luck })
	Net.FxAll("dispense", { pos = MapBuilder.DispenserPosition, color = rarity.color, order = rarity.order })
	task.delay(1.6, function()
		if not player.Parent then
			return
		end
		if not PlotService.AddSlime(player, { id = def.id, born = os.time(), mut = mut }) then
			-- Pens filled up during the animation: refund.
			PlotService.AddCash(player, cost)
			Net.Notify(player, "Pens full, roll refunded.", "bad")
			return
		end
		if rarity.order >= 5 or mut then
			Net.NotifyAll("🎰 " .. player.DisplayName .. " rolled a " .. def.rarity .. " " .. name .. " from the Dispenser!", "epic")
		end
	end)
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
	prompt.Triggered:Connect(roll)

	local board = MapBuilder.OddsBoard
	if board then
		board.Text = oddsText()
	end

	game:GetService("Players").PlayerRemoving:Connect(function(p)
		lastRoll[p] = nil
	end)
end

return DispenserService
