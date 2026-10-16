-- Builds the whole map from code: ground, the slime conveyor and 8 player bases.
-- Doing it in code means the Rojo project alone is a complete, playable place.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local MapBuilder = {}

MapBuilder.BeltStart = Vector3.new(-135, 0, 0)
MapBuilder.BeltEnd = Vector3.new(135, 0, 0)
MapBuilder.BeltTopY = 1.5
MapBuilder.PlotSize = 52

local PEN_X = { -18, -9, 0, 9, 18 }
local PEN_Z = { -4, 5, 14, 23 }
local THEMES = {
	Color3.fromRGB(255, 90, 140),
	Color3.fromRGB(90, 170, 255),
	Color3.fromRGB(255, 190, 50),
	Color3.fromRGB(150, 100, 255),
	Color3.fromRGB(60, 220, 160),
	Color3.fromRGB(255, 120, 60),
	Color3.fromRGB(240, 90, 255),
	Color3.fromRGB(100, 230, 255),
}

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

local function signGui(parent: BasePart, face: Enum.NormalId, text: string, name: string)
	local gui = Instance.new("SurfaceGui")
	gui.Name = name
	gui.Face = face
	gui.PixelsPerStud = 40
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = gui
	return label
end

-- studs: size the label in world studs so it shrinks with distance (base
-- labels), instead of a fixed pixel size that crowds the screen from afar.
local function billboard(parent: BasePart, offset: number, text: string, studs: Vector2?): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Size = if studs then UDim2.fromScale(studs.X, studs.Y) else UDim2.fromOffset(200, 50)
	gui.StudsOffset = Vector3.new(0, offset, 0)
	gui.MaxDistance = if studs then 70 else 80
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = gui
	return label
end

local function buildLighting()
	Lighting.ClockTime = 15.2
	Lighting.Brightness = 3
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 140, 180)
	Lighting.Ambient = Color3.fromRGB(70, 60, 90)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GlobalShadows = true
	pcall(function()
		Lighting.Technology = Enum.Technology.Future
	end)

	local atm = Instance.new("Atmosphere")
	atm.Density = 0.32
	atm.Offset = 0.15
	atm.Color = Color3.fromRGB(255, 200, 230)
	atm.Decay = Color3.fromRGB(120, 90, 200)
	atm.Glare = 0.4
	atm.Haze = 1.6
	atm.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 1
	bloom.Size = 28
	bloom.Threshold = 0.9
	bloom.Parent = Lighting

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "ColorCorrection" -- the client tints this during server events
	cc.Saturation = 0.28
	cc.Contrast = 0.08
	cc.Brightness = 0.02
	cc.TintColor = Color3.fromRGB(255, 248, 255)
	cc.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.08
	rays.Spread = 0.8
	rays.Parent = Lighting

	local clouds = Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.6
	clouds.Color = Color3.fromRGB(255, 230, 250)
	clouds.Parent = workspace.Terrain
end

local function buildBelt(map: Folder)
	local length = (MapBuilder.BeltEnd - MapBuilder.BeltStart).Magnitude
	local belt = part({
		Name = "Belt",
		Size = Vector3.new(length, 1, 10),
		Position = Vector3.new(0, 1, 0),
		Color = Color3.fromRGB(40, 40, 48),
		Material = Enum.Material.DiamondPlate,
	})
	belt.Parent = map
	for _, side in { -1, 1 } do
		part({
			Name = "Rail",
			Size = Vector3.new(length, 1.6, 0.8),
			Position = Vector3.new(0, 1.8, side * 5.4),
			Color = Color3.fromRGB(255, 200, 40),
			Material = Enum.Material.SmoothPlastic,
		}).Parent = map
	end
	-- Moving chevrons sell the conveyor motion.
	local beam = Instance.new("Beam")
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(-length / 2, 0.55, 0)
	a0.Parent = belt
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(length / 2, 0.55, 0)
	a1.Parent = belt
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Width0 = 8
	beam.Width1 = 8
	beam.FaceCamera = false
	beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	beam.TextureMode = Enum.TextureMode.Static
	beam.TextureLength = 6
	beam.TextureSpeed = length / 32 / 6
	beam.Transparency = NumberSequence.new(0.6)
	beam.Color = ColorSequence.new(Color3.fromRGB(120, 255, 160))
	beam.Parent = belt

	-- Glowing portals at both ends of the belt. Client code spins/pulses anything tagged "Pulse".
	local function portal(pos: Vector3, color: Color3, label: string)
		local ring = Instance.new("Model")
		ring.Name = "Portal"
		for _, z in { -7.5, 7.5 } do
			local pillar = part({
				Name = "Pillar",
				Size = Vector3.new(3, 16, 3),
				Position = pos + Vector3.new(0, 8, z),
				Color = Color3.fromRGB(40, 30, 70),
				Material = Enum.Material.Slate,
			})
			pillar.Parent = ring
			part({
				Name = "Trim",
				Size = Vector3.new(3.3, 16, 0.6),
				Position = pos + Vector3.new(0, 8, z - math.sign(z) * 1.5),
				Color = color,
				Material = Enum.Material.Neon,
				CanCollide = false,
			}).Parent = ring
		end
		local top = part({
			Name = "Top",
			Size = Vector3.new(3.5, 3, 19),
			Position = pos + Vector3.new(0, 17.5, 0),
			Color = color,
			Material = Enum.Material.Neon,
		})
		top.Parent = ring
		billboard(top, 4, label).TextColor3 = color
		local film = part({
			Name = "Film",
			Size = Vector3.new(0.3, 15, 12),
			Position = pos + Vector3.new(0, 8.5, 0),
			Color = color,
			Material = Enum.Material.ForceField,
			Transparency = 0.2,
			CanCollide = false,
			CanQuery = false,
		})
		film.Parent = ring
		film:SetAttribute("PulseColor", color)
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 30
		light.Brightness = 3
		light.Parent = film
		local p = Instance.new("ParticleEmitter")
		p.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		p.Color = ColorSequence.new(color)
		p.LightEmission = 1
		p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
		p.Lifetime = NumberRange.new(1, 2)
		p.Rate = 25
		p.Speed = NumberRange.new(2, 6)
		p.SpreadAngle = Vector2.new(180, 180)
		p.Parent = film
		ring.Parent = map
		CollectionService:AddTag(top, "Pulse")
	end
	portal(MapBuilder.BeltStart, Color3.fromRGB(120, 255, 160), "SLIME DROP")
	portal(MapBuilder.BeltEnd, Color3.fromRGB(255, 80, 160), "LAST CHANCE!")
end

MapBuilder.DispenserPosition = Vector3.new(0, 0, 25) -- far enough from the belt that their prompts never overlap

-- The Slime Dispenser: a giant gumball machine full of slimes, with an odds board.
local function buildDispenser(map: Folder)
	local pos = MapBuilder.DispenserPosition
	local model = Instance.new("Model")
	model.Name = "SlimeDispenser"
	local base = part({
		Name = "Base",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(7, 9, 9),
		CFrame = CFrame.new(pos + Vector3.new(0, 3.5, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(255, 70, 120),
		Material = Enum.Material.SmoothPlastic,
	})
	base.Parent = model
	part({
		Name = "Chute",
		Size = Vector3.new(3, 2.5, 1),
		Position = pos + Vector3.new(0, 2.5, -4.6),
		Color = Color3.fromRGB(255, 220, 60),
		Material = Enum.Material.Neon,
	}).Parent = model
	part({
		Name = "Rim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.8, 10, 10),
		CFrame = CFrame.new(pos + Vector3.new(0, 7.2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(255, 220, 60),
		Material = Enum.Material.Neon,
	}).Parent = model
	local globe = part({
		Name = "Globe",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 12,
		Position = pos + Vector3.new(0, 13, 0),
		Color = Color3.fromRGB(200, 240, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.6,
		Reflectance = 0.2,
		CanCollide = false,
	})
	globe.Parent = model
	local rng = Random.new(7)
	local ballColors = { Color3.fromRGB(120, 230, 120), Color3.fromRGB(255, 140, 200), Color3.fromRGB(90, 160, 255), Color3.fromRGB(255, 200, 40), Color3.fromRGB(180, 90, 255), Color3.fromRGB(255, 90, 40) }
	local balls = Instance.new("Model")
	balls.Name = "Balls"
	for _ = 1, 22 do
		local dir = rng:NextUnitVector() * rng:NextNumber(0, 3.8)
		local b = part({
			Name = "Ball",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * rng:NextNumber(1.6, 2.4),
			Position = globe.Position + Vector3.new(dir.X, -math.abs(dir.Y) + 0.5, dir.Z),
			Color = ballColors[rng:NextInteger(1, #ballColors)],
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		b.Parent = balls
	end
	balls.Parent = model
	CollectionService:AddTag(balls, "Spin")
	local cap = part({
		Name = "Cap",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 3,
		Position = pos + Vector3.new(0, 19.3, 0),
		Color = Color3.fromRGB(255, 70, 120),
		Material = Enum.Material.SmoothPlastic,
	})
	cap.Parent = model
	billboard(cap, 4, "🎰 SLIME DISPENSER").TextColor3 = Color3.fromRGB(255, 220, 60)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 160, 220)
	light.Range = 26
	light.Brightness = 3
	light.Parent = globe
	CollectionService:AddTag(cap, "Pulse")
	model.Parent = map
	MapBuilder.Dispenser = base

	local board = part({
		Name = "OddsBoard",
		Size = Vector3.new(11, 13, 0.6),
		Position = pos + Vector3.new(13, 6.5, 0),
		Color = Color3.fromRGB(30, 20, 50),
		Material = Enum.Material.SmoothPlastic,
	})
	board.Parent = map
	local label = signGui(board, Enum.NormalId.Front, "ODDS", "OddsGui")
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 240, 200)
	MapBuilder.OddsBoard = label
end

MapBuilder.FusePosition = Vector3.new(-30, 0, 18)

-- The Fuse Machine: a bubbling cauldron with two glowing tubes.
local function buildFuseMachine(map: Folder)
	local pos = MapBuilder.FusePosition
	local model = Instance.new("Model")
	model.Name = "FuseMachine"
	local base = part({
		Name = "Base",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(5, 10, 10),
		CFrame = CFrame.new(pos + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(60, 40, 90),
		Material = Enum.Material.Metal,
	})
	base.Parent = model
	local goo = part({
		Name = "Goo",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 9, 9),
		CFrame = CFrame.new(pos + Vector3.new(0, 5.1, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(150, 255, 120),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	goo.Parent = model
	CollectionService:AddTag(goo, "Pulse")
	for _, side in { -1, 1 } do
		local tube = part({
			Name = "Tube",
			Size = Vector3.new(1.4, 9, 1.4),
			Position = pos + Vector3.new(side * 5.5, 7, 0),
			Color = Color3.fromRGB(190, 120, 255),
			Material = Enum.Material.Neon,
			Transparency = 0.2,
			CanCollide = false,
		})
		tube.Parent = model
		CollectionService:AddTag(tube, "Pulse")
	end
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	bubbles.Color = ColorSequence.new(Color3.fromRGB(150, 255, 120), Color3.fromRGB(190, 120, 255))
	bubbles.LightEmission = 1
	bubbles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
	bubbles.Lifetime = NumberRange.new(1, 2)
	bubbles.Rate = 18
	bubbles.Speed = NumberRange.new(3, 6)
	bubbles.EmissionDirection = Enum.NormalId.Right
	bubbles.Parent = goo
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(150, 255, 120)
	light.Range = 22
	light.Brightness = 3
	light.Parent = goo
	billboard(goo, 6, "🧪 FUSE MACHINE").TextColor3 = Color3.fromRGB(150, 255, 120)
	model.Parent = map
	MapBuilder.FuseMachine = base
end

-- Trees, lamps, crystals and flowers so the world feels alive.
local function decorate(map: Folder)
	local deco = Instance.new("Folder")
	deco.Name = "Decor"
	deco.Parent = map
	local rng = Random.new(42)
	local leafColors = {
		Color3.fromRGB(255, 150, 200),
		Color3.fromRGB(150, 230, 120),
		Color3.fromRGB(180, 140, 255),
		Color3.fromRGB(255, 200, 90),
	}

	local function tree(pos: Vector3)
		local h = rng:NextNumber(10, 16)
		part({
			Name = "Trunk",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(h, 2.2, 2.2),
			CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			Color = Color3.fromRGB(120, 80, 60),
			Material = Enum.Material.Wood,
		}).Parent = deco
		local leaf = leafColors[rng:NextInteger(1, #leafColors)]
		for i = 1, 3 do
			local r = rng:NextNumber(6, 9)
			part({
				Name = "Leaves",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * r,
				Position = pos + Vector3.new(rng:NextNumber(-2.5, 2.5), h + rng:NextNumber(-1, 2.5), rng:NextNumber(-2.5, 2.5)),
				Color = leaf,
				Material = Enum.Material.SmoothPlastic,
			}).Parent = deco
		end
	end

	local function lamp(pos: Vector3, color: Color3)
		part({
			Name = "Post",
			Size = Vector3.new(0.8, 9, 0.8),
			Position = pos + Vector3.new(0, 4.5, 0),
			Color = Color3.fromRGB(40, 30, 60),
			Material = Enum.Material.Metal,
		}).Parent = deco
		local bulb = part({
			Name = "Bulb",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 2.2,
			Position = pos + Vector3.new(0, 9.6, 0),
			Color = color,
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		bulb.Parent = deco
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 22
		light.Brightness = 2
		light.Shadows = false
		light.Parent = bulb
	end

	local function crystal(pos: Vector3, color: Color3)
		local c = part({
			Name = "Crystal",
			Size = Vector3.new(3, 7, 3),
			CFrame = CFrame.new(pos) * CFrame.Angles(math.rad(45), math.rad(45), 0),
			Color = color,
			Material = Enum.Material.Glass,
			Transparency = 0.25,
			Reflectance = 0.3,
			CanCollide = false,
		})
		c.Parent = deco
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 18
		light.Brightness = 2
		light.Parent = c
		CollectionService:AddTag(c, "Float")
	end

	-- Walkway lamps along both sides of the belt.
	for x = -120, 120, 30 do
		lamp(Vector3.new(x, 0, 12), Color3.fromRGB(255, 220, 140))
		lamp(Vector3.new(x, 0, -12), Color3.fromRGB(255, 220, 140))
	end
	-- Floating crystals above the belt.
	local crystalColors = { Color3.fromRGB(120, 255, 200), Color3.fromRGB(255, 120, 220), Color3.fromRGB(140, 160, 255) }
	for i, x in { -100, -50, 0, 50, 100 } do
		crystal(Vector3.new(x, 26, 0), crystalColors[(i - 1) % #crystalColors + 1])
	end
	-- Trees around the outside of the map.
	for _ = 1, 40 do
		local side = rng:NextInteger(1, 4)
		local pos
		if side == 1 then
			pos = Vector3.new(rng:NextNumber(-200, 200), 0, rng:NextNumber(92, 150))
		elseif side == 2 then
			pos = Vector3.new(rng:NextNumber(-200, 200), 0, rng:NextNumber(-150, -92))
		elseif side == 3 then
			pos = Vector3.new(rng:NextNumber(-200, -138), 0, rng:NextNumber(-85, 85))
		else
			pos = Vector3.new(rng:NextNumber(138, 200), 0, rng:NextNumber(-85, 85))
		end
		tree(pos)
	end
	-- Colourful flowers scattered on the grass.
	for _ = 1, 120 do
		local pos = Vector3.new(rng:NextNumber(-200, 200), 0.3, rng:NextNumber(-150, 150))
		if math.abs(pos.Z) > 88 or math.abs(pos.X) > 132 then
			part({
				Name = "Flower",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * rng:NextNumber(0.8, 1.6),
				Position = pos,
				Color = leafColors[rng:NextInteger(1, #leafColors)],
				Material = Enum.Material.Neon,
				CanCollide = false,
			}).Parent = deco
		end
	end
end

local function buildPlot(map: Folder, index: number, center: Vector3, facing: number)
	local half = MapBuilder.PlotSize / 2
	local cf = CFrame.new(center) * CFrame.Angles(0, facing, 0)
	local plot = Instance.new("Model")
	plot.Name = "Plot" .. index
	plot:SetAttribute("Index", index)

	local floor = part({
		Name = "Floor",
		Size = Vector3.new(MapBuilder.PlotSize, 0.5, MapBuilder.PlotSize),
		CFrame = cf * CFrame.new(0, 0.25, 0),
		Color = Color3.fromRGB(235, 225, 210),
		Material = Enum.Material.WoodPlanks,
	})
	floor.Parent = plot
	plot.PrimaryPart = floor

	-- Low walls on three sides; the front (toward the belt) is open.
	local theme = THEMES[(index - 1) % #THEMES + 1]
	local wallColor = theme
	plot:SetAttribute("Theme", theme)
	-- Neon trim around the floor edge in the base colour.
	for _, t in {
		{ Vector3.new(MapBuilder.PlotSize, 0.3, 0.6), Vector3.new(0, 0.6, -half) },
		{ Vector3.new(0.6, 0.3, MapBuilder.PlotSize), Vector3.new(-half, 0.6, 0) },
		{ Vector3.new(0.6, 0.3, MapBuilder.PlotSize), Vector3.new(half, 0.6, 0) },
	} do
		part({ Name = "Trim", Size = t[1], CFrame = cf * CFrame.new(t[2]), Color = theme, Material = Enum.Material.Neon, CanCollide = false }).Parent = plot
	end
	for _, w in {
		{ Vector3.new(MapBuilder.PlotSize, 3, 1), Vector3.new(0, 1.5, half) },
		{ Vector3.new(1, 3, MapBuilder.PlotSize), Vector3.new(-half, 1.5, 0) },
		{ Vector3.new(1, 3, MapBuilder.PlotSize), Vector3.new(half, 1.5, 0) },
	} do
		part({ Name = "Wall", Size = w[1], CFrame = cf * CFrame.new(w[2]), Color = wallColor }).Parent = plot
	end

	-- Shield walls, only visible while the base is locked.
	local shield = Instance.new("Folder")
	shield.Name = "Shield"
	shield.Parent = plot
	for _, w in {
		{ Vector3.new(MapBuilder.PlotSize, 14, 0.4), Vector3.new(0, 7, -half) },
		{ Vector3.new(MapBuilder.PlotSize, 14, 0.4), Vector3.new(0, 7, half) },
		{ Vector3.new(0.4, 14, MapBuilder.PlotSize), Vector3.new(-half, 7, 0) },
		{ Vector3.new(0.4, 14, MapBuilder.PlotSize), Vector3.new(half, 7, 0) },
	} do
		part({
			Name = "ShieldWall",
			Size = w[1],
			CFrame = cf * CFrame.new(w[2]),
			Color = Color3.fromRGB(255, 60, 80),
			Material = Enum.Material.ForceField,
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
		}).Parent = shield
	end

	local pens = Instance.new("Folder")
	pens.Name = "Pens"
	pens.Parent = plot
	local n = 0
	for zi = 1, #PEN_Z do
		for xi = 1, #PEN_X do
			n += 1
			local pad = part({
				Name = "Pen" .. n,
				Size = Vector3.new(7, 0.4, 7),
				CFrame = cf * CFrame.new(PEN_X[xi], 0.7, PEN_Z[zi]),
				Color = Color3.fromRGB(180, 170, 160),
				Material = Enum.Material.SmoothPlastic,
				Transparency = 1,
				CanCollide = false,
			})
			pad:SetAttribute("Slot", n)
			pad.Parent = pens
		end
	end

	local collector = part({
		Name = "Collector",
		Size = Vector3.new(8, 0.6, 8),
		CFrame = cf * CFrame.new(-16, 0.8, -18),
		Color = Color3.fromRGB(60, 220, 100),
		Material = Enum.Material.Neon,
	})
	collector.Parent = plot
	billboard(collector, 4, "$0", Vector2.new(9, 2.4)).Name = "Bank"

	local lock = part({
		Name = "LockButton",
		Size = Vector3.new(6, 1, 6),
		CFrame = cf * CFrame.new(16, 0.9, -18),
		Color = Color3.fromRGB(255, 60, 80),
		Material = Enum.Material.Neon,
	})
	lock.Parent = plot
	billboard(lock, 4, "LOCK BASE", Vector2.new(9, 2.2)).Name = "Status"

	local sign = part({
		Name = "Sign",
		Size = Vector3.new(30, 6, 1),
		CFrame = cf * CFrame.new(0, 7, half - 1),
		Color = wallColor,
	})
	sign.Parent = plot
	-- Front (-Z in plot space) faces into the base, toward the entrance.
	signGui(sign, Enum.NormalId.Front, "Empty Base", "OwnerGui")

	local spawnPoint = Instance.new("Part")
	spawnPoint.Name = "SpawnPoint"
	spawnPoint.Anchored = true
	spawnPoint.CanCollide = false
	spawnPoint.Transparency = 1
	spawnPoint.Size = Vector3.one
	spawnPoint.CFrame = cf * CFrame.new(0, 4, -14) * CFrame.Angles(0, math.pi, 0)
	spawnPoint.Parent = plot

	plot.Parent = map
	return plot, cf
end

-- Returns a list of { model, cframe } for each plot.
function MapBuilder.Build()
	buildLighting()

	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = workspace

	part({
		Name = "Ground",
		Size = Vector3.new(420, 2, 320),
		Position = Vector3.new(0, -1, 0),
		Color = Color3.fromRGB(110, 190, 90),
		Material = Enum.Material.Grass,
	}).Parent = map

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = Vector3.new(0, 0.5, -20)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = Color3.fromRGB(120, 255, 160)
	spawn.Material = Enum.Material.Neon
	spawn.Parent = map

	buildBelt(map)
	decorate(map)
	buildDispenser(map)
	buildFuseMachine(map)

	local plots = {}
	local xs = { -96, -32, 32, 96 }
	local i = 0
	for _, side in { 1, -1 } do
		for _, x in xs do
			i += 1
			-- Plot local -Z must point at the belt (world z = 0).
			local facing = if side == 1 then 0 else math.pi
			local model, cf = buildPlot(map, i, Vector3.new(x, 0, side * 58), facing)
			table.insert(plots, { model = model, cframe = cf })
		end
	end
	return plots
end

return MapBuilder
