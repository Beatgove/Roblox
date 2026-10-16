-- The Fuse Machine: put in 3 slimes of any kind + a fee, wait 10 minutes, get one slime
-- whose rarity depends on the average rarity you put in (odds shown before fusing).
-- A reason to come back later and a use for slimes you'd otherwise sell.

local HttpService = game:GetService("HttpService")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Util = require(game.ReplicatedStorage.Shared.Util)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local MapBuilder = require(script.Parent.MapBuilder)
local Roller = require(script.Parent.Roller)
local Signals = require(script.Parent.Signals)
local Net = require(script.Parent.Net)

local FuseService = {}

local MAX_ORDER = 8 -- Secret; fusing never makes Exclusive slimes

local function sync(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local f = data.fuse
	player:SetAttribute("Fuse", HttpService:JSONEncode({ active = f.active == true, endsAt = f.endsAt or 0 }))
end

local function pickSlime(order: number)
	local rarity = Config.Rarities[order]
	local list = Roller.Spawnable(rarity.name)
	if #list == 0 then
		for _, s in Config.Slimes do
			if s.rarity == rarity.name then
				table.insert(list, s)
			end
		end
	end
	return list[math.random(1, #list)]
end

local function rollShift(): number
	local total = 0
	for _, o in Config.FuseOdds do
		total += o.chance
	end
	local r = math.random() * total
	for _, o in Config.FuseOdds do
		r -= o.chance
		if r <= 0 then
			return o.shift
		end
	end
	return 0
end

local function start(player: Player, slots)
	local data = DataService.Get(player)
	if not data or typeof(slots) ~= "table" then
		return
	end
	if data.fuse.active then
		Net.Notify(player, "The Fuse Machine is already working on your slimes!", "bad")
		return
	end
	-- Validate: exactly FuseCount distinct, existing slots.
	local seen, list = {}, {}
	for _, v in slots do
		local i = tonumber(v)
		if i and data.slimes[i] and not seen[i] then
			seen[i] = true
			table.insert(list, i)
		end
	end
	if #list ~= Config.FuseCount then
		Net.Notify(player, "Pick " .. Config.FuseCount .. " slimes to fuse.", "bad")
		return
	end
	local fee, orderSum, bestMut, bestMult = 0, 0, nil, 1
	for _, i in list do
		local s = data.slimes[i]
		local def = Config.SlimeById[s.id]
		fee += def.price * Config.FuseFeeShare
		orderSum += math.min(Config.RarityByName[def.rarity].order, MAX_ORDER)
		if Config.MutationMult(s.mut) > bestMult then
			bestMut, bestMult = s.mut, Config.MutationMult(s.mut)
		end
	end
	fee = math.floor(fee)
	if data.cash < fee then
		Net.Notify(player, "Fusing these costs " .. Util.Money(fee), "bad")
		Net.Fx(player, "deny", {})
		return
	end
	local avg = math.floor(orderSum / #list + 0.5)
	local order = math.clamp(avg + rollShift(), 1, MAX_ORDER)
	local def = pickSlime(order)
	local mut = if bestMut and math.random() < Config.FuseKeepMutationChance then bestMut else nil

	data.cash -= fee
	table.sort(list, function(a, b)
		return a > b
	end)
	for _, i in list do
		table.remove(data.slimes, i)
	end
	data.fuse = { active = true, endsAt = os.time() + Config.FuseSeconds, result = { id = def.id, mut = mut } }
	PlotService.Render(player)
	sync(player)
	Net.FxAll("fuseStart", { pos = MapBuilder.FusePosition })
	Net.Notify(player, "🧪 Fusing! Come back in " .. Util.Duration(Config.FuseSeconds) .. " to see what you get.", "epic")
	Signals.Progress(player, "fuse")
end

local function claim(player: Player)
	local data = DataService.Get(player)
	if not data or not data.fuse.active then
		return
	end
	local left = (data.fuse.endsAt or 0) - os.time()
	if left > 0 then
		Net.Notify(player, "Still fusing... " .. Util.Duration(left) .. " left.", "info")
		return
	end
	local r = data.fuse.result
	if not PlotService.AddSlime(player, { id = r.id, born = os.time(), mut = r.mut }) then
		Net.Notify(player, "Your pens are full! Make room, then claim your fused slime.", "bad")
		return
	end
	data.fuse = { active = false }
	sync(player)
	local def = Config.SlimeById[r.id]
	Net.Fx(player, "reveal", { name = Config.DisplayName(r.id, r.mut), rarity = def.rarity, mut = r.mut })
	Net.Notify(player, "🧪 The Fuse Machine made a " .. def.rarity .. " " .. Config.DisplayName(r.id, r.mut) .. "!", "epic")
	if Config.RarityByName[def.rarity].order >= 5 then
		Net.NotifyAll("🧪 " .. player.DisplayName .. " fused a " .. def.rarity .. " " .. r.id .. "!", "epic")
	end
end

function FuseService.OnPlayer(player: Player)
	sync(player)
end

function FuseService.Start()
	Net.FuseStartEvent.OnServerEvent:Connect(start)
	Net.FuseClaimEvent.OnServerEvent:Connect(claim)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "FusePrompt"
	prompt.ActionText = "Open Fuse Machine"
	prompt.ObjectText = "Fuse 3 slimes into 1"
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = MapBuilder.FuseMachine
	prompt.Triggered:Connect(function(player)
		Net.Fx(player, "openFuse", {})
	end)
end

return FuseService
