-- Sky Tower: a spiral jumping course (obby) around a glowing pillar. Step on the start pad,
-- climb to the chest at the top and get a prize (once every 15 minutes). Falling just drops
-- you back to the grass. Bounce pads launch you over the big gaps.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Util = require(game.ReplicatedStorage.Shared.Util)
local DataService = require(script.Parent.DataService)
local Net = require(script.Parent.Net)
local Rewards = require(script.Parent.Rewards)
local Signals = require(script.Parent.Signals)

local TowerService = {}

local T = Config.Tower
local bestTime = { name = "nobody yet", seconds = math.huge }

local function part(parent: Instance, props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

local function playerFrom(hit: BasePart): Player?
	local model = hit:FindFirstAncestorOfClass("Model")
	return model and Players:GetPlayerFromCharacter(model)
end

local function cooldownLeft(player: Player): number
	local data = DataService.Get(player)
	return if data then math.max(0, (data.towerAt or 0) + T.cooldownSeconds - os.time()) else 0
end

local function build()
	local folder = Instance.new("Folder")
	folder.Name = "SkyTower"
	folder.Parent = workspace
	local base = T.pos
	local height = T.steps * T.rise + 14
	local pillar = part(folder, { Name = "Pillar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, 8, 8), CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(150, 120, 255), Material = Enum.Material.Glass, Transparency = 0.3 })
	local core = Instance.new("PointLight")
	core.Color = Color3.fromRGB(170, 140, 255)
	core.Range = 30
	core.Parent = pillar
	part(folder, { Name = "TowerBase", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 30, 30), CFrame = CFrame.new(base + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(80, 60, 140), Material = Enum.Material.SmoothPlastic })

	-- The start pad faces the street (+X from here).
	local start = part(folder, { Name = "StartPad", Size = Vector3.new(6, 0.6, 6), CFrame = CFrame.new(base + Vector3.new(T.radius, 1.3, 0)), Color = Color3.fromRGB(90, 255, 140), Material = Enum.Material.Neon })
	local startGui = Instance.new("BillboardGui")
	startGui.Size = UDim2.fromScale(12, 3)
	startGui.StudsOffset = Vector3.new(0, 6, 0)
	startGui.MaxDistance = 120
	startGui.Parent = start
	local startLabel = Instance.new("TextLabel")
	startLabel.Size = UDim2.fromScale(1, 1)
	startLabel.BackgroundTransparency = 1
	startLabel.Font = Enum.Font.FredokaOne
	startLabel.TextScaled = true
	startLabel.TextColor3 = Color3.new(1, 1, 1)
	startLabel.TextStrokeTransparency = 0
	startLabel.Text = "🗼 SKY TOWER\nStep here to start the clock!"
	startLabel.Parent = startGui

	-- Spiral steps. Every 7th is a small one, two are bounce pads for the big gaps.
	local angle = 0
	local y = 1
	for i = 1, T.steps do
		angle += T.turn
		y += T.rise
		local radius = if i % 5 == 0 then T.radius + 4 else T.radius
		local small = i % 7 == 0
		local bounce = i == 13 or i == 27
		local hue = (i / T.steps) * 0.8
		local p = base + Vector3.new(math.cos(angle) * radius, y, math.sin(angle) * radius)
		local step = part(folder, { Name = if bounce then "BouncePad" else "Step" .. i, Size = if small then Vector3.new(3.6, 1, 3.6) else Vector3.new(6, 1, 6),
			CFrame = CFrame.lookAt(p, base + Vector3.new(0, y, 0)), Color = if bounce then Color3.fromRGB(255, 80, 200) else Color3.fromHSV(hue, 0.55, 1),
			Material = if bounce then Enum.Material.Neon else Enum.Material.SmoothPlastic })
		if bounce then
			CollectionService:AddTag(step, "BouncePad") -- the client launches you when you land on it
			y += 9 -- leaves a gap only a bounce clears
		end
	end

	-- Prize platform and chest at the top.
	y += T.rise
	local topPos = base + Vector3.new(0, y, 0)
	part(folder, { Name = "Summit", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 16, 16), CFrame = CFrame.new(topPos) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(255, 215, 80), Material = Enum.Material.Neon })
	local chest = part(folder, { Name = "Chest", Size = Vector3.new(4, 3, 3), CFrame = CFrame.new(topPos + Vector3.new(0, 2, 0)), Color = Color3.fromRGB(150, 90, 40), Material = Enum.Material.WoodPlanks })
	part(folder, { Name = "ChestLid", Size = Vector3.new(4.2, 0.8, 3.2), CFrame = chest.CFrame * CFrame.new(0, 1.8, 0), Color = Color3.fromRGB(255, 205, 60), Material = Enum.Material.Metal })
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 230, 120))
	sparkle.LightEmission = 1
	sparkle.Rate = 12
	sparkle.Size = NumberSequence.new(0.7, 0)
	sparkle.Speed = NumberRange.new(2, 4)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Parent = chest
	local beacon = Instance.new("PointLight")
	beacon.Color = Color3.fromRGB(255, 220, 120)
	beacon.Range = 30
	beacon.Brightness = 2
	beacon.Parent = chest
	local topGui = Instance.new("BillboardGui")
	topGui.Size = UDim2.fromScale(14, 3)
	topGui.StudsOffset = Vector3.new(0, 6, 0)
	topGui.MaxDistance = 400
	topGui.AlwaysOnTop = true
	topGui.Parent = chest
	local topLabel = Instance.new("TextLabel")
	topLabel.Size = UDim2.fromScale(1, 1)
	topLabel.BackgroundTransparency = 1
	topLabel.Font = Enum.Font.FredokaOne
	topLabel.TextScaled = true
	topLabel.TextColor3 = Color3.fromRGB(255, 230, 120)
	topLabel.TextStrokeTransparency = 0
	topLabel.Text = "🎁 PRIZE"
	topLabel.Parent = topGui

	local function refreshBoard()
		startLabel.Text = "🗼 SKY TOWER\nBest: " .. bestTime.name .. (if bestTime.seconds < math.huge then string.format(" %.1fs", bestTime.seconds) else "")
	end
	refreshBoard()

	start.Touched:Connect(function(hit)
		local player = playerFrom(hit)
		if not player then
			return
		end
		local left = cooldownLeft(player)
		if left > 0 then
			if (player:GetAttribute("TowerNotified") or 0) < os.clock() - 5 then
				player:SetAttribute("TowerNotified", os.clock())
				Net.Notify(player, "🗼 You can climb for fun, but the prize is back in " .. Util.Duration(left) .. ".", "info")
			end
			return
		end
		if not player:GetAttribute("TowerStart") then
			player:SetAttribute("TowerStart", workspace:GetServerTimeNow())
			Net.Fx(player, "towerStart", {})
		end
	end)

	chest.Touched:Connect(function(hit)
		local player = playerFrom(hit)
		local started = player and player:GetAttribute("TowerStart")
		if not player or not started then
			return
		end
		local data = DataService.Get(player)
		if not data or cooldownLeft(player) > 0 then
			return
		end
		player:SetAttribute("TowerStart", nil)
		local seconds = workspace:GetServerTimeNow() - started
		-- A climb faster than this is not humanly possible: ignore it.
		if seconds < 12 then
			return
		end
		data.towerAt = os.time()
		local reward = table.clone(T.reward)
		if math.random() < T.relicChance then
			reward.relic = true
			reward.source = "the Sky Tower"
		end
		local text = Rewards.Grant(player, reward)
		Signals.Progress(player, "minigame")
		local record = seconds < bestTime.seconds
		if record then
			bestTime = { name = player.DisplayName, seconds = seconds }
			refreshBoard()
			Net.NotifyAll(string.format("🗼 %s climbed the Sky Tower in a record %.1fs!", player.DisplayName, seconds), "epic")
		end
		Net.Fx(player, "towerWin", { seconds = seconds, text = text, record = record, pos = chest.Position })
	end)
end

function TowerService.Start()
	build()
	Players.PlayerRemoving:Connect(function(p)
		p:SetAttribute("TowerStart", nil)
	end)
end

return TowerService
