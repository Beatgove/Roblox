-- Goo Pond fishing: walk up to a spot, cast, wait for a bite, tap REEL in time.
-- Catches are cash, snacks, luck, a free roll, or (rarely) a relic. Odds are on the board.

local Players = game:GetService("Players")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Net = require(script.Parent.Net)
local Rewards = require(script.Parent.Rewards)
local Signals = require(script.Parent.Signals)

local FishingService = {}

local F = Config.Fishing
local SPOTS = 8

type Cast = { token: number, spot: number, biteAt: number, deadline: number?, rod: Instance?, bobber: BasePart?, done: boolean }
local casts: { [Player]: Cast } = {}
local spotBusy: { [number]: Player } = {}
local token = 0

local function part(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local function spotDir(i: number): Vector3
	local a = (i / SPOTS) * math.pi * 2
	return Vector3.new(math.cos(a), 0, math.sin(a))
end

local function cleanup(player: Player)
	local c = casts[player]
	if not c then
		return
	end
	c.done = true
	casts[player] = nil
	if spotBusy[c.spot] == player then
		spotBusy[c.spot] = nil
	end
	if c.rod then
		c.rod:Destroy()
	end
	if c.bobber then
		c.bobber:Destroy()
	end
	if player.Parent then
		player:SetAttribute("Fishing", nil)
	end
end

local function totalWeight(): number
	local t = 0
	for _, l in F.loot do
		t += l.weight
	end
	return t
end

local function rollLoot()
	local r = math.random() * totalWeight()
	for _, l in F.loot do
		r -= l.weight
		if r <= 0 then
			return l
		end
	end
	return F.loot[1]
end

local function giveRod(player: Player): Instance?
	local char = player.Character
	local hand = char and (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")) :: BasePart?
	if not hand then
		return nil
	end
	local rod = Instance.new("Part")
	rod.Name = "FishingRod"
	rod.Size = Vector3.new(0.25, 0.25, 6)
	rod.Color = Color3.fromRGB(120, 80, 50)
	rod.Material = Enum.Material.Wood
	rod.CanCollide = false
	rod.Massless = true
	rod.CFrame = hand.CFrame * CFrame.new(0, -0.6, -3) * CFrame.Angles(math.rad(30), 0, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = rod
	weld.Parent = rod
	local tip = Instance.new("Attachment")
	tip.Name = "Tip"
	tip.Position = Vector3.new(0, 0, -3)
	tip.Parent = rod
	rod.Parent = char
	return rod
end

local function startCast(player: Player, spot: number)
	if casts[player] then
		return
	end
	if spotBusy[spot] and spotBusy[spot] ~= player then
		Net.Notify(player, "Someone is already fishing here. Try another spot!", "bad")
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	token += 1
	spotBusy[spot] = player
	local dir = spotDir(spot)
	local water = F.pos + dir * (F.radius - 7) + Vector3.new(0, 0.9, 0)
	local bobber = part({ Name = "Bobber", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, CFrame = CFrame.new(water), Color = Color3.fromRGB(255, 60, 70), Material = Enum.Material.SmoothPlastic, CanCollide = false })
	local top = part({ Name = "BobberTop", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.5, CFrame = CFrame.new(water + Vector3.new(0, 0.4, 0)), Color = Color3.new(1, 1, 1), Material = Enum.Material.SmoothPlastic, CanCollide = false })
	top.Parent = bobber
	bobber.Parent = workspace
	local rod = giveRod(player)
	if rod then
		local a1 = Instance.new("Attachment")
		a1.Parent = bobber
		local line = Instance.new("Beam")
		line.Attachment0 = rod:FindFirstChild("Tip") :: Attachment
		line.Attachment1 = a1
		line.Width0 = 0.06
		line.Width1 = 0.06
		line.Color = ColorSequence.new(Color3.new(1, 1, 1))
		line.CurveSize0 = 2
		line.FaceCamera = true
		line.Parent = bobber
	end
	local c: Cast = { token = token, spot = spot, biteAt = os.clock() + F.biteMin + math.random() * (F.biteMax - F.biteMin), rod = rod, bobber = bobber, done = false }
	casts[player] = c
	player:SetAttribute("Fishing", true)
	Net.FxAll("fishCast", { pos = water })
	task.spawn(function()
		while not c.done and os.clock() < c.biteAt do
			task.wait(0.2)
			local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not r or (r.Position - (F.pos + dir * F.radius)).Magnitude > 16 then
				cleanup(player)
				return
			end
		end
		if c.done then
			return
		end
		-- Bite! The bobber dips and the player has a moment to reel.
		c.deadline = os.clock() + F.reelWindow + 0.35
		bobber.CFrame = CFrame.new(water - Vector3.new(0, 0.5, 0))
		top.CFrame = CFrame.new(water - Vector3.new(0, 0.1, 0))
		Net.Fx(player, "fishBite", { token = c.token, window = F.reelWindow, pos = water })
		task.wait(F.reelWindow + 0.4)
		if not c.done then
			Net.Fx(player, "fishMiss", {})
			cleanup(player)
		end
	end)
end

local function reel(player: Player, t: any)
	local c = casts[player]
	if not c or c.token ~= t then
		return
	end
	if not c.deadline or os.clock() > c.deadline then
		return
	end
	local pos = c.bobber and c.bobber.Position
	cleanup(player)
	local loot = rollLoot()
	local text = Rewards.Grant(player, loot.reward)
	Signals.Progress(player, "minigame")
	Net.Fx(player, "fishCatch", { label = loot.label, text = text, pos = pos, rare = loot.weight <= 3 })
	if loot.weight <= 1 then
		Net.NotifyAll("🎣 " .. player.DisplayName .. " fished a RELIC out of the Goo Pond!", "epic")
	end
end

local function build()
	local folder = Instance.new("Folder")
	folder.Name = "GooPond"
	folder.Parent = workspace
	local goo = part({ Name = "Goo", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, F.radius * 2, F.radius * 2), CFrame = CFrame.new(F.pos + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(110, 255, 150), Material = Enum.Material.Glass, Transparency = 0.15, Reflectance = 0.2, CanCollide = false })
	goo.Parent = folder
	part({ Name = "PondBed", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, F.radius * 2, F.radius * 2), CFrame = CFrame.new(F.pos + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(30, 110, 70), Material = Enum.Material.SmoothPlastic }).Parent = folder
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(110, 255, 150)
	glow.Range = 30
	glow.Brightness = 1
	glow.Parent = goo
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	bubbles.Color = ColorSequence.new(Color3.fromRGB(180, 255, 200))
	bubbles.Size = NumberSequence.new(0.5, 0)
	bubbles.Rate = 6
	bubbles.Lifetime = NumberRange.new(1, 2)
	bubbles.Speed = NumberRange.new(1, 2)
	bubbles.EmissionDirection = Enum.NormalId.Right -- the cylinder's axis points up
	bubbles.Parent = goo
	-- Stone rim
	for i = 1, 28 do
		local a = (i / 28) * math.pi * 2
		local p = F.pos + Vector3.new(math.cos(a), 0, math.sin(a)) * (F.radius + 1)
		part({ Name = "Rim", Size = Vector3.new(4.2, 1.4, 2.2), CFrame = CFrame.lookAt(p + Vector3.new(0, 0.7, 0), F.pos + Vector3.new(0, 0.7, 0)),
			Color = Color3.fromRGB(150, 145, 160), Material = Enum.Material.Slate }).Parent = folder
	end
	-- Fishing spots: little wooden decks with a prompt.
	for i = 1, SPOTS do
		local dir = spotDir(i)
		local p = F.pos + dir * (F.radius + 2.5)
		local deck = part({ Name = "Deck" .. i, Size = Vector3.new(5, 0.6, 5), CFrame = CFrame.lookAt(p + Vector3.new(0, 1.4, 0), F.pos + Vector3.new(0, 1.4, 0)),
			Color = Color3.fromRGB(170, 120, 80), Material = Enum.Material.WoodPlanks })
		deck.Parent = folder
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "FishPrompt"
		prompt.ActionText = "Cast Line"
		prompt.ObjectText = "🎣 Goo Pond"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.Parent = deck
		prompt.Triggered:Connect(function(who)
			startCast(who, i)
		end)
	end
	-- Sign and odds board
	local sign = part({ Name = "PondSign", Size = Vector3.new(14, 9, 0.6), CFrame = CFrame.lookAt(F.pos + Vector3.new(-F.radius - 8, 6, -F.radius + 2), F.pos + Vector3.new(-200, 6, -F.radius + 2)),
		Color = Color3.fromRGB(40, 90, 60), Material = Enum.Material.WoodPlanks })
	sign.Parent = folder
	part({ Name = "SignPost", Size = Vector3.new(1, 6, 1), CFrame = sign.CFrame * CFrame.new(0, -6, 0.6), Color = Color3.fromRGB(110, 75, 50), Material = Enum.Material.Wood }).Parent = folder
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	local lines = { "🎣 GOO POND", "Cast, wait for the bite, then REEL!", "" }
	local total = totalWeight()
	for _, l in F.loot do
		table.insert(lines, string.format("%s  %g%%", l.label, math.floor(l.weight / total * 1000 + 0.5) / 10))
	end
	label.Text = table.concat(lines, "\n")
	label.Parent = gui
end

function FishingService.Start()
	build()
	Net.On(Net.ReelEvent, reel)
	Players.PlayerRemoving:Connect(cleanup)
end

return FishingService
