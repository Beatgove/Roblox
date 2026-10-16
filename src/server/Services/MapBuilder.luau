-- Builds the whole map from code: ground, the slime conveyor and 8 player bases.
-- Doing it in code means the Rojo project alone is a complete, playable place.

local Lighting = game:GetService("Lighting")

local MapBuilder = {}

MapBuilder.BeltStart = Vector3.new(-135, 0, 0)
MapBuilder.BeltEnd = Vector3.new(135, 0, 0)
MapBuilder.BeltTopY = 1.5
MapBuilder.PlotSize = 52

local PEN_X = { -18, -9, 0, 9, 18 }
local PEN_Z = { -4, 5, 14, 23 }

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

local function billboard(parent: BasePart, offset: number, text: string): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 50)
	gui.StudsOffset = Vector3.new(0, offset, 0)
	gui.MaxDistance = 80
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
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.5
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 160)
	Lighting.GlobalShadows = true
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atm = Instance.new("Atmosphere")
		atm.Density = 0.25
		atm.Color = Color3.fromRGB(200, 230, 255)
		atm.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("BloomEffect") then
		local bloom = Instance.new("BloomEffect")
		bloom.Intensity = 0.6
		bloom.Threshold = 1.2
		bloom.Parent = Lighting
	end
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

	local arch = part({
		Name = "SpawnArch",
		Size = Vector3.new(4, 14, 16),
		Position = MapBuilder.BeltStart + Vector3.new(0, 7, 0),
		Color = Color3.fromRGB(120, 255, 160),
		Material = Enum.Material.Neon,
		Transparency = 0.3,
		CanCollide = false,
	})
	arch.Parent = map
	billboard(arch, 10, "SLIME DROP").TextColor3 = Color3.fromRGB(120, 255, 160)
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
	local wallColor = Color3.fromRGB(110, 90, 200)
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
	billboard(collector, 4, "$0").Name = "Bank"

	local lock = part({
		Name = "LockButton",
		Size = Vector3.new(6, 1, 6),
		CFrame = cf * CFrame.new(16, 0.9, -18),
		Color = Color3.fromRGB(255, 60, 80),
		Material = Enum.Material.Neon,
	})
	lock.Parent = plot
	billboard(lock, 4, "LOCK BASE").Name = "Status"

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
	spawn.Position = Vector3.new(0, 0.5, 16)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = Color3.fromRGB(120, 255, 160)
	spawn.Material = Enum.Material.Neon
	spawn.Parent = map

	buildBelt(map)

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
