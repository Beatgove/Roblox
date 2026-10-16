-- Spawns slimes on the central belt, sells them, and runs Slime Rain events.

local TweenService = game:GetService("TweenService")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Util = require(game.ReplicatedStorage.Shared.Util)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local SlimeModel = require(script.Parent.SlimeModel)
local MapBuilder = require(script.Parent.MapBuilder)
local Net = require(script.Parent.Net)

local ConveyorService = {}

local rainUntil = 0
local beltFolder: Folder

local byRarity: { [string]: { any } } = {}
for _, s in Config.Slimes do
	byRarity[s.rarity] = byRarity[s.rarity] or {}
	table.insert(byRarity[s.rarity], s)
end

function ConveyorService.IsRaining(): boolean
	return os.clock() < rainUntil
end

local function rollRarity(luck: number)
	local total = 0
	local weights = {}
	for i, r in Config.Rarities do
		local w = r.weight * (if r.order >= 3 then luck else 1)
		weights[i] = w
		total += w
	end
	local roll = math.random() * total
	for i, r in Config.Rarities do
		roll -= weights[i]
		if roll <= 0 then
			return r
		end
	end
	return Config.Rarities[1]
end

local function rollSlime(luck: number)
	local rarity = rollRarity(luck)
	local list = byRarity[rarity.name]
	return list[math.random(1, #list)]
end

local function spawnSlime()
	local def = rollSlime(if ConveyorService.IsRaining() then Config.RainLuck else 1)
	local model = SlimeModel.Create(def.id, 1)
	local height = model.PrimaryPart.Size.Y / 2
	local y = MapBuilder.BeltTopY + height
	local startCF = CFrame.new(MapBuilder.BeltStart + Vector3.new(0, y, 0)) * CFrame.Angles(0, -math.pi / 2, 0)
	local endCF = CFrame.new(MapBuilder.BeltEnd + Vector3.new(0, y, 0)) * CFrame.Angles(0, -math.pi / 2, 0)
	model:PivotTo(startCF)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyPrompt"
	prompt.ActionText = "Buy " .. Util.Money(def.price)
	prompt.ObjectText = def.id .. " (" .. def.rarity .. ")"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 12
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
		if data.cash < def.price then
			Net.Notify(player, "Not enough cash for " .. def.id .. " (" .. Util.Money(def.price) .. ")", "bad")
			return
		end
		if not PlotService.HasFreeSlot(player) then
			Net.Notify(player, "Your pens are full! Sell a slime or rebirth for more space.", "bad")
			return
		end
		claimed = true
		data.cash -= def.price
		PlotService.AddSlime(player, { id = def.id, born = os.time() })
		model:Destroy()
		local rarity = Config.RarityByName[def.rarity]
		Net.Notify(player, "Bought " .. def.id .. "! It's in your base.", "good")
		if rarity.order >= 5 then
			Net.NotifyAll(player.DisplayName .. " bought a " .. def.rarity .. " " .. def.id .. "!", "epic")
		end
	end)

	model.Parent = beltFolder

	if Config.RarityByName[def.rarity].order >= 5 then
		Net.NotifyAll("A " .. def.rarity .. " " .. def.id .. " is on the belt!", "epic")
	end

	local tween = TweenService:Create(
		model.PrimaryPart,
		TweenInfo.new(Config.BeltTravelSeconds, Enum.EasingStyle.Linear),
		{ CFrame = endCF }
	)
	tween.Completed:Connect(function()
		if model.Parent then
			model:Destroy()
		end
	end)
	tween:Play()
end

function ConveyorService.StartRain(seconds: number, byName: string?)
	local t = os.clock()
	rainUntil = math.max(rainUntil, t) + seconds
	local who = if byName then byName .. " started a " else "A "
	Net.Banner(who .. "SLIME RAIN! Rare slimes x" .. Config.RainLuck .. " for " .. seconds .. "s", seconds)
end

function ConveyorService.Start()
	beltFolder = Instance.new("Folder")
	beltFolder.Name = "BeltSlimes"
	beltFolder.Parent = workspace

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
