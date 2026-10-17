-- Spawns slimes on the central belt (they hop along it), sells them, and runs Slime Rain events.

local RunService = game:GetService("RunService")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Util = require(game.ReplicatedStorage.Shared.Util)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local SlimeModel = require(script.Parent.SlimeModel)
local MapBuilder = require(script.Parent.MapBuilder)
local Roller = require(script.Parent.Roller)
local Net = require(script.Parent.Net)
local Signals = require(script.Parent.Signals)

local ConveyorService = {}

local rainUntil = 0
local beltFolder: Folder
local moving: { { model: Model, start: CFrame, finish: CFrame, born: number, phase: number } } = {}

function ConveyorService.IsRaining(): boolean
	return os.clock() < rainUntil
end

local function announceIfRare(rarity, text: string)
	if rarity.order >= 5 then
		Net.NotifyAll(text, "epic")
	end
end

local function spawnSlime()
	local luck = (if ConveyorService.IsRaining() then Config.RainLuck else 1) * Roller.EventLuck()
	local def = Roller.Slime(luck)
	local mut = Roller.Mutation(luck)
	local traits = Roller.Traits()
	local rarity = Config.RarityByName[def.rarity]
	local price = math.floor(def.price * Config.MutationMult(mut) * Config.TraitMult(traits))
	local name = Config.DisplayName(def.id, mut, nil, traits)

	local model = SlimeModel.Create(def.id, 1, mut, nil, traits)
	local height = model.PrimaryPart.Size.Y / 2
	local y = MapBuilder.BeltTopY + height
	local facing = CFrame.Angles(0, -math.pi / 2, 0)
	local startCF = CFrame.new(MapBuilder.BeltStart + Vector3.new(0, y, 0)) * facing
	local endCF = CFrame.new(MapBuilder.BeltEnd + Vector3.new(0, y, 0)) * facing
	model:PivotTo(startCF)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyPrompt"
	prompt.ActionText = "Buy " .. Util.Money(price)
	prompt.ObjectText = name .. " (" .. def.rarity .. ")"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart

	local claimed = false
	prompt.Triggered:Connect(function(player)
		if claimed then
			return
		end
		local data = DataService.Get(player)
		if not data then
			return
		end
		local price = if Config.HasRelic(data, "BargainBelt") then math.floor(price * 0.85) else price
		if data.cash < price then
			Net.Notify(player, "Not enough cash for " .. name .. " (" .. Util.Money(price) .. ")", "bad")
			Net.Fx(player, "deny", {})
			return
		end
		if not PlotService.HasFreeSlot(player) then
			Net.Notify(player, "Your pens are full! Sell a slime or rebirth for more space.", "bad")
			Net.Fx(player, "deny", {})
			return
		end
		claimed = true
		data.cash -= price
		Net.FxAll("buy", { pos = model.PrimaryPart.Position, color = rarity.color, order = rarity.order })
		Net.Fx(player, "reveal", { name = name, rarity = def.rarity, mut = mut, quiet = rarity.order < 4 and mut == nil })
		model:Destroy()
		PlotService.AddSlime(player, { id = def.id, born = os.time(), mut = mut, traits = traits })
		Net.Notify(player, "Bought " .. name .. "! It's in your base.", "good")
		Signals.Progress(player, "buy")
		announceIfRare(rarity, player.DisplayName .. " bought a " .. def.rarity .. " " .. name .. "!")
	end)

	model.Parent = beltFolder
	table.insert(moving, { model = model, start = startCF, finish = endCF, born = os.clock(), phase = math.random() * 6 })

	if rarity.order >= 5 or mut or traits then
		Net.FxAll("rareSpawn", { pos = startCF.Position, color = rarity.color, order = rarity.order })
	end
	announceIfRare(rarity, "A " .. def.rarity .. " " .. name .. " is on the belt! RUN!")
end

-- One loop moves every belt slime: forward along the belt with little hops.
local lastStep = 0
local function stepBelt()
	local t = os.clock()
	-- 30 Hz is smooth enough and halves the replication traffic.
	if t - lastStep < 1 / 30 then
		return
	end
	lastStep = t
	for i = #moving, 1, -1 do
		local m = moving[i]
		if not m.model.Parent then
			table.remove(moving, i)
			continue
		end
		local alpha = (t - m.born) / Config.BeltTravelSeconds
		if alpha >= 1 then
			m.model:Destroy()
			table.remove(moving, i)
			continue
		end
		local hop = math.abs(math.sin((t + m.phase) * 4)) * 1.4
		m.model:PivotTo(m.start:Lerp(m.finish, alpha) + Vector3.new(0, hop, 0))
	end
end

function ConveyorService.StartRain(seconds: number, byName: string?)
	local t = os.clock()
	rainUntil = math.max(rainUntil, t) + seconds
	workspace:SetAttribute("RainUntil", workspace:GetServerTimeNow() + (rainUntil - t))
	local who = if byName then byName .. " started a " else "A "
	Net.Banner(who .. "SLIME RAIN! 5x LUCK everywhere for " .. seconds .. "s", seconds, "rain")
end

function ConveyorService.Start()
	beltFolder = Instance.new("Folder")
	beltFolder.Name = "BeltSlimes"
	beltFolder.Parent = workspace

	RunService.Heartbeat:Connect(stepBelt)

	task.spawn(function()
		while true do
			spawnSlime()
			task.wait(if ConveyorService.IsRaining() then Config.RainSpawnInterval else Config.SpawnInterval)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(Config.RainEverySeconds)
			ConveyorService.StartRain(Config.RainDurationSeconds)
		end
	end)
end

return ConveyorService
