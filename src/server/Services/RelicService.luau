-- Base Relics: rule-changing charms (like Balatro jokers). You find them from the King Slime,
-- bounties, quests and Index milestones, equip up to 3, and they float above your base for
-- everyone to see. They reset on rebirth, so each run you build a new combo.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Util = require(game.ReplicatedStorage.Shared.Util)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local Net = require(script.Parent.Net)
local Signals = require(script.Parent.Signals)

local RelicService = {}

local function randomRelic(): string
	local total = 0
	for _, key in Config.RelicOrder do
		total += Config.RelicRarities[Config.Relics[key].rarity].weight
	end
	local r = math.random() * total
	for _, key in Config.RelicOrder do
		r -= Config.RelicRarities[Config.Relics[key].rarity].weight
		if r <= 0 then
			return key
		end
	end
	return Config.RelicOrder[1]
end

-- Floating gems above the back of the base, one per equipped relic.
local function render(player: Player)
	local plot = PlotService.GetPlot(player)
	local data = DataService.Get(player)
	if not plot then
		return
	end
	local old = plot.model:FindFirstChild("Relics")
	if old then
		old:Destroy()
	end
	if not data or #data.relics == 0 then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Relics"
	folder.Parent = plot.model
	local n = #data.relics
	for i, key in data.relics do
		local def = Config.Relics[key]
		local color = Config.RelicRarities[def.rarity].color
		local x = (i - (n + 1) / 2) * 7
		local gem = Instance.new("Part")
		gem.Name = key
		gem.Anchored = true
		gem.CanCollide = false
		gem.CanQuery = false
		gem.CastShadow = false
		gem.Size = Vector3.new(2.2, 2.2, 2.2)
		gem.CFrame = plot.cframe * CFrame.new(x, 24, 34 - 3) * CFrame.Angles(math.rad(45), 0, math.rad(45))
		gem.Color = color
		gem.Material = Enum.Material.Neon
		gem.Parent = folder
		CollectionService:AddTag(gem, "Float")
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 12
		light.Parent = gem
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromScale(6, 1.6)
		gui.StudsOffset = Vector3.new(0, 2.4, 0)
		gui.MaxDistance = 80
		gui.Parent = gem
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = color
		label.TextStrokeTransparency = 0
		label.Text = def.icon .. " " .. def.name
		label.Parent = gui
	end
end

function RelicService.Sync(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local bag = {}
	for _, key in Config.RelicOrder do
		if data.relicBag[key] then
			table.insert(bag, key)
		end
	end
	player:SetAttribute("Relics", HttpService:JSONEncode({ equipped = data.relics, bag = bag }))
	PlotService.Sync(player) -- income changes with relics
end

-- Gives a relic (random if `key` is nil). Duplicates turn into cash.
function RelicService.Give(player: Player, key: string?, source: string?)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local k = key or randomRelic()
	local def = Config.Relics[k]
	local rarity = Config.RelicRarities[def.rarity]
	if data.relicBag[k] then
		local cash = math.max(500, math.floor(PlotService.IncomePerSecond(player) * Config.RelicDupCashSeconds))
		PlotService.AddCash(player, cash, "Relic")
		Net.Notify(player, def.icon .. " Duplicate " .. def.name .. " relic turned into " .. Util.Money(cash) .. "!", "good")
		return
	end
	data.relicBag[k] = true
	-- Auto-equip into a free slot so new players feel it right away.
	local equipped = false
	if #data.relics < Config.RelicSlots then
		table.insert(data.relics, k)
		equipped = true
		render(player)
	end
	RelicService.Sync(player)
	Net.Fx(player, "relic", { name = def.name, icon = def.icon, desc = def.desc, rarity = def.rarity, color = rarity.color, equipped = equipped })
	Net.Notify(player, def.icon .. " NEW RELIC" .. (if source then " from " .. source else "") .. ": " .. def.name .. "! " .. def.desc, "epic")
	if def.rarity == "Epic" then
		Net.NotifyAll("🔮 " .. player.DisplayName .. " found the EPIC relic " .. def.name .. "!", "epic")
	end
end

local function equip(player: Player, key: any)
	local data = DataService.Get(player)
	if not data or type(key) ~= "string" or not data.relicBag[key] or Config.HasRelic(data, key) then
		return
	end
	if #data.relics >= Config.RelicSlots then
		Net.Notify(player, "All " .. Config.RelicSlots .. " relic slots are full. Take one off first.", "bad")
		Net.Fx(player, "deny", {})
		return
	end
	table.insert(data.relics, key)
	render(player)
	RelicService.Sync(player)
end

local function unequip(player: Player, key: any)
	local data = DataService.Get(player)
	local i = data and type(key) == "string" and table.find(data.relics, key)
	if not data or not i then
		return
	end
	table.remove(data.relics, i)
	render(player)
	RelicService.Sync(player)
end

function RelicService.Start()
	Net.On(Net.EquipRelicEvent, equip)
	Net.On(Net.UnequipRelicEvent, unequip)

	Signals.Quest.Event:Connect(function(player: Player, kind: string, amount: number)
		local chance = Config.RelicDropChance[kind]
		if chance and math.random() < chance then
			task.delay(2.5, function()
				if player.Parent then
					RelicService.Give(player, nil, if kind == "boss" then "the King Slime" elseif kind == "bounty" then "a bounty" else "a quest")
				end
			end)
		elseif kind == "index" and amount > 0 and amount % Config.RelicIndexEvery == 0 then
			task.delay(2.5, function()
				if player.Parent then
					RelicService.Give(player, nil, "your Slime Index")
				end
			end)
		elseif kind == "rebirth" then
			render(player)
			RelicService.Sync(player)
		end
	end)

	local function onJoin(player: Player)
		task.spawn(function()
			for _ = 1, 240 do -- up to a minute: a load can wait ~20 s on another server's lock
				local data = DataService.Get(player)
				if data and PlotService.GetPlot(player) then
					-- Drop any relic keys that no longer exist.
					for i = #data.relics, 1, -1 do
						if not Config.Relics[data.relics[i]] then
							table.remove(data.relics, i)
						end
					end
					for k in data.relicBag do
						if not Config.Relics[k] then
							data.relicBag[k] = nil
						end
					end
					render(player)
					RelicService.Sync(player)
					return
				end
				task.wait(0.25)
			end
		end)
	end
	Players.PlayerAdded:Connect(onJoin)
	for _, p in Players:GetPlayers() do
		onJoin(p)
	end
end

return RelicService
