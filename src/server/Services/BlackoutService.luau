-- Blackout (like Doors / 99 Nights): every so often the power goes out for a minute and a half.
-- The world goes dark, free base locks stop working, and the Gloom drifts through the street
-- between the bases. Anyone it touches drops what they carry and wakes up back home.

local Players = game:GetService("Players")

local Config = require(game.ReplicatedStorage.Shared.Config)
local PlotService = require(script.Parent.PlotService)
local StealService = require(script.Parent.StealService)
local Net = require(script.Parent.Net)

local BlackoutService = {}

local B = Config.Blackout
local running = false
local caughtAt: { [Player]: number } = {}

local function part(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local function buildGloom(): Model
	local model = Instance.new("Model")
	model.Name = "Gloom"
	local body = part({ Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.one * B.size, Color = Color3.fromRGB(8, 4, 14), Material = Enum.Material.SmoothPlastic })
	body.Parent = model
	model.PrimaryPart = body
	local r = B.size / 2
	for _, side in { -1, 1 } do
		part({ Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.new(r * 0.28, r * 0.18, r * 0.1), Color = Color3.fromRGB(255, 40, 60), Material = Enum.Material.Neon,
			CFrame = body.CFrame * CFrame.new(side * r * 0.35, r * 0.2, -r * 0.96) }).Parent = model
	end
	part({ Name = "Grin", Size = Vector3.new(r * 0.8, r * 0.06, r * 0.06), Color = Color3.fromRGB(255, 40, 60), Material = Enum.Material.Neon,
		CFrame = body.CFrame * CFrame.new(0, -r * 0.25, -r * 0.99) }).Parent = model
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(10, 0, 20))
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, r), NumberSequenceKeypoint.new(1, r * 2) })
	smoke.Lifetime = NumberRange.new(1, 1.6)
	smoke.Rate = 18
	smoke.Speed = NumberRange.new(1, 2)
	smoke.SpreadAngle = Vector2.new(180, 180)
	smoke.Parent = body
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 30, 60)
	glow.Range = 14
	glow.Brightness = 1.2
	glow.Parent = body
	local hl = Instance.new("Highlight")
	hl.FillColor = Color3.fromRGB(0, 0, 0)
	hl.FillTransparency = 0.2
	hl.OutlineColor = Color3.fromRGB(255, 40, 60)
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Adornee = body -- only the body, so the red eyes stay bright
	hl.Parent = model
	-- Weld-free: everything moves together with PivotTo.
	return model
end

local function clampToStreet(p: Vector3): Vector3
	return Vector3.new(math.clamp(p.X, -B.roamX, B.roamX), B.height, math.clamp(p.Z, -B.roamZ, B.roamZ))
end

local function randomSpot(): Vector3
	return Vector3.new(math.random(-B.roamX, B.roamX), B.height, math.random(-B.roamZ, B.roamZ))
end

local function catch(player: Player, pos: Vector3)
	caughtAt[player] = os.clock()
	local carrying = StealService.IsCarrying(player)
	if carrying then
		StealService.Drop(player, "gloom")
	end
	Net.FxAll("gloomCatch", { pos = pos })
	Net.Fx(player, "gloomCaught", { dropped = carrying })
	task.delay(0.6, function()
		local plot = PlotService.GetPlot(player)
		local char = player.Character
		local spawnPoint = plot and plot.model:FindFirstChild("SpawnPoint") :: BasePart?
		if char and spawnPoint then
			char:PivotTo(spawnPoint.CFrame + Vector3.new(0, 3, 0))
		end
	end)
	Net.NotifyAll("👻 The Gloom got " .. player.DisplayName .. (if carrying then " and their stolen slime hopped home!" else "!"), "info")
end

local function run()
	if running then
		return
	end
	running = true
	Net.FxAll("blackoutWarn", { seconds = B.warnSeconds })
	Net.NotifyAll("⚡ The lights are flickering... a BLACKOUT is coming!", "epic")
	task.wait(B.warnSeconds)
	local untilT = workspace:GetServerTimeNow() + B.seconds
	workspace:SetAttribute("BlackoutUntil", untilT)
	Net.FxAll("blackout", { seconds = B.seconds })
	Net.NotifyAll("🌑 BLACKOUT! Base locks are down. Stay out of the Gloom's way!", "epic")

	local gloom = buildGloom()
	local pos = randomSpot()
	gloom:PivotTo(CFrame.new(pos))
	gloom.Parent = workspace
	local target = randomSpot()
	local dt = 1 / 20
	while workspace:GetServerTimeNow() < untilT do
		task.wait(dt)
		-- Chase the nearest player in reach, otherwise drift around the street.
		local chase: Player? = nil
		local best = B.chaseRange
		for _, p in Players:GetPlayers() do
			local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
			if root and hum and hum.Health > 0 and os.clock() - (caughtAt[p] or 0) > B.graceSeconds then
				local d = (Vector3.new(root.Position.X, B.height, root.Position.Z) - pos).Magnitude
				if d < best then
					best, chase = d, p
				end
				if d <= B.catchRange and math.abs(root.Position.Z) <= B.roamZ + B.catchRange then
					catch(p, pos)
				end
			end
		end
		local goal = target
		local speed = B.roamSpeed
		if chase then
			local root = (chase.Character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart
			goal = clampToStreet(root.Position)
			speed = B.chaseSpeed
		elseif (target - pos).Magnitude < 3 then
			target = randomSpot()
		end
		local step = goal - pos
		if step.Magnitude > 0.01 then
			pos = clampToStreet(pos + step.Unit * math.min(step.Magnitude, speed * dt))
			local bob = math.sin(os.clock() * 3) * 0.6
			gloom:PivotTo(CFrame.lookAt(pos + Vector3.new(0, bob, 0), Vector3.new(goal.X, pos.Y + bob, goal.Z)))
		end
	end

	gloom:Destroy()
	workspace:SetAttribute("BlackoutUntil", nil)
	Net.FxAll("blackoutEnd", {})
	Net.NotifyAll("💡 The power is back on. Lock your base!", "good")
	running = false
end

function BlackoutService.RunNow()
	task.spawn(run)
end

function BlackoutService.Start()
	task.spawn(function()
		task.wait(B.firstDelay)
		while true do
			-- Never at the same time as the King Slime.
			while (workspace:GetAttribute("KingUntil") or 0) > workspace:GetServerTimeNow() do
				task.wait(10)
			end
			run()
			task.wait(B.everySeconds)
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		caughtAt[p] = nil
	end)
end

return BlackoutService
