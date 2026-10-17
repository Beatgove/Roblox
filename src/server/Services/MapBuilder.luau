-- Builds the whole map from code: ground, the slime conveyor and 8 player bases.
-- Doing it in code means the Rojo project alone is a complete, playable place.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local MapBuilder = {}

MapBuilder.BeltStart = Vector3.new(-205, 0, 0)
MapBuilder.BeltEnd = Vector3.new(205, 0, 0)
MapBuilder.BeltTopY = 1.5
MapBuilder.PlotSize = 68
MapBuilder.WallHeight = 18
local KNEE, HEADER = 4, 3 -- the low wall under a base's glass and the solid band above it
MapBuilder.DoorWidth = 20
MapBuilder.DoorHeight = 12
-- Base layout: 4 bases on each side of the belt, with room to breathe between them.
MapBuilder.PlotXs = { -165, -55, 55, 165 }
MapBuilder.PlotZ = 84

-- Two rows of pens down each side of the aisle, front row first.
local PEN_X = { -25, -15, 15, 25 }
local PEN_Z = { -8, 12 }
-- The second storey (built by BaseDecor at Config.SecondFloorRebirth) holds pens 9 to 16 in the
-- same layout as downstairs, on a floor whose top is at UPPER_Y.
local UPPER_Y = 18.7 -- BaseDecor.UpperFloorY
local UPPER_Z = PEN_Z
MapBuilder.UpperFloorY = UPPER_Y
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

-- Lights for one storey of a base, from floor height y0 to ceiling height y1: warm glowing
-- ceiling panels, each ringed by a thin strip in the base colour, and an LED strip running
-- round the top of the walls. The colours are softened so they glow without glaring.
-- Tagged "BaseLight" so a Blackout can switch them off.
function MapBuilder.AddRoomLights(parent: Instance, cf: CFrame, y0: number, y1: number, theme: Color3)
	local half = MapBuilder.PlotSize / 2
	local led = theme:Lerp(Color3.fromRGB(255, 255, 255), 0.3)
	local function lit(props, range: number, brightness: number, color: Color3, shadows: boolean?)
		props.Anchored = true
		props.CanCollide = false
		props.CanQuery = false
		props.CastShadow = false
		local p = part(props)
		p.Parent = parent
		local pl = Instance.new("PointLight")
		pl.Range = range
		pl.Brightness = brightness
		pl.Shadows = shadows == true
		pl.Color = color
		pl.Parent = p
		CollectionService:AddTag(p, "BaseLight")
		return p
	end
	local function strip(props)
		props.Anchored = true
		props.CanCollide = false
		props.CanQuery = false
		props.CastShadow = false
		local p = part(props)
		p.Parent = parent
		CollectionService:AddTag(p, "BaseLight")
		return p
	end
	for _, x in { -16, 16 } do
		for _, z in { -20, 0, 20 } do
			lit({ Name = "CeilingLight", Size = Vector3.new(4, 0.3, 4), CFrame = cf * CFrame.new(x, y1 - 0.3, z), Color = Color3.fromRGB(255, 236, 200), Material = Enum.Material.Neon }, 24, 0.7, Color3.fromRGB(255, 232, 200), true)
			for _, e in {
				{ Vector3.new(5, 0.12, 0.3), Vector3.new(0, 0, 2.35) },
				{ Vector3.new(5, 0.12, 0.3), Vector3.new(0, 0, -2.35) },
				{ Vector3.new(0.3, 0.12, 4.4), Vector3.new(2.35, 0, 0) },
				{ Vector3.new(0.3, 0.12, 4.4), Vector3.new(-2.35, 0, 0) },
			} do
				strip({ Name = "LightRing", Size = e[1], CFrame = cf * CFrame.new(x + e[2].X, y1 - 0.3, z + e[2].Z), Color = led, Material = Enum.Material.Neon })
			end
		end
	end
	-- The wall-top LED strip, just in front of the inner walls, with a few soft coloured lights
	-- along it so the walls pick up the glow.
	local y, w = y1 - 1, half - 0.9
	for _, s in {
		{ Vector3.new(w * 2, 0.25, 0.25), Vector3.new(0, y, w) },
		{ Vector3.new(w * 2, 0.25, 0.25), Vector3.new(0, y, -w) },
		{ Vector3.new(0.25, 0.25, w * 2), Vector3.new(w, y, 0) },
		{ Vector3.new(0.25, 0.25, w * 2), Vector3.new(-w, y, 0) },
	} do
		strip({ Name = "LEDStrip", Size = s[1], CFrame = cf * CFrame.new(s[2]), Color = led, Material = Enum.Material.Neon })
	end
	for _, p in {
		Vector3.new(-w + 1, y, -16), Vector3.new(-w + 1, y, 16), Vector3.new(w - 1, y, -16), Vector3.new(w - 1, y, 16),
		Vector3.new(-16, y, w - 1), Vector3.new(16, y, w - 1),
	} do
		lit({ Name = "LEDGlow", Size = Vector3.one * 0.2, CFrame = cf * CFrame.new(p), Transparency = 1 }, 18, 0.5, led)
	end
end

local function buildLighting()
	Lighting.ClockTime = 15.2
	Lighting.Brightness = 2.2
	Lighting.OutdoorAmbient = Color3.fromRGB(135, 135, 150)
	Lighting.Ambient = Color3.fromRGB(96, 88, 112) -- indoors: soft, not gloomy
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.ExposureCompensation = -0.25 -- a touch darker overall so nothing looks washed out
	Lighting.GlobalShadows = true
	pcall(function()
		Lighting.Technology = Enum.Technology.Future
	end)

	local atm = Instance.new("Atmosphere")
	atm.Density = 0.26
	atm.Offset = 0.15
	atm.Color = Color3.fromRGB(215, 225, 240)
	atm.Decay = Color3.fromRGB(120, 130, 170)
	atm.Glare = 0.05
	atm.Haze = 0.4
	atm.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.15
	bloom.Size = 16
	bloom.Threshold = 2.2
	bloom.Parent = Lighting

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "ColorCorrection" -- the client tints this during server events
	cc.Saturation = 0
	cc.Contrast = 0.08
	cc.Brightness = 0
	cc.TintColor = Color3.fromRGB(255, 255, 255)
	cc.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.08
	rays.Spread = 0.8
	rays.Parent = Lighting

	local clouds = Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.6
	clouds.Color = Color3.fromRGB(245, 245, 250)
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
-- The 🥊 Slap Shop: a little market stall with a striped awning, a giant glove on the roof,
-- a slime shopkeeper behind the counter and every slap weapon on display (locked ones say
-- which rebirth they need). The counter's prompt opens the Gear menu (GearService).
MapBuilder.SlapShopPosition = Vector3.new(120, 0, -34)
local function buildSlapShop(map: Folder)
	local Config = require(game.ReplicatedStorage.Shared.Config)
	local model = Instance.new("Model")
	model.Name = "SlapShop"
	-- Local -Z faces the belt.
	local cf = CFrame.new(MapBuilder.SlapShopPosition) * CFrame.Angles(0, math.pi, 0)
	local W, D, H = 30, 18, 12
	local wood = Color3.fromRGB(150, 100, 65)
	local cream = Color3.fromRGB(250, 244, 232)
	local red = Color3.fromRGB(215, 60, 70)
	local function add(props): Part
		props.CastShadow = props.CastShadow or false
		local p = part(props)
		p.Parent = model
		return p
	end
	add({ Name = "ShopFloor", Size = Vector3.new(W, 0.4, D), CFrame = cf * CFrame.new(0, 0.2, 0), Color = Color3.fromRGB(196, 150, 108), Material = Enum.Material.WoodPlanks })
	for _, w in {
		{ Vector3.new(W, H, 1), Vector3.new(0, H / 2, D / 2) },
		{ Vector3.new(1, H, D), Vector3.new(-W / 2, H / 2, 0) },
		{ Vector3.new(1, H, D), Vector3.new(W / 2, H / 2, 0) },
	} do
		add({ Name = "ShopWall", Size = w[1], CFrame = cf * CFrame.new(w[2]), Color = cream, Material = Enum.Material.SmoothPlastic })
	end
	add({ Name = "ShopRoof", Size = Vector3.new(W + 2, 1, D + 2), CFrame = cf * CFrame.new(0, H + 0.5, 0), Color = red, Material = Enum.Material.SmoothPlastic })
	for _, x in { -W / 2, W / 2 } do
		add({ Name = "ShopPost", Size = Vector3.new(1.4, H, 1.4), CFrame = cf * CFrame.new(x, H / 2, -D / 2), Color = wood, Material = Enum.Material.Wood })
	end
	-- Striped awning over the open front.
	local stripes = 10
	for i = 0, stripes - 1 do
		local x = -W / 2 + (i + 0.5) * W / stripes
		add({ Name = "Awning", Size = Vector3.new(W / stripes, 0.3, 6), CFrame = cf * CFrame.new(x, H - 1.2, -D / 2 - 2.4) * CFrame.Angles(math.rad(-22), 0, 0), Color = if i % 2 == 0 then red else Color3.new(1, 1, 1), Material = Enum.Material.Fabric })
	end
	-- Big sign above the awning.
	local sign = add({ Name = "ShopSign", Size = Vector3.new(20, 4, 0.6), CFrame = cf * CFrame.new(0, H + 3, -D / 2 + 0.4), Color = Color3.fromRGB(40, 30, 60), Material = Enum.Material.SmoothPlastic })
	signGui(sign, Enum.NormalId.Front, "🥊 SLAP SHOP", "ShopGui")
	-- A giant boxing glove bobbing on the roof.
	local glove = add({ Name = "GiantGlove", Shape = Enum.PartType.Ball, Size = Vector3.new(8, 7, 9), CFrame = cf * CFrame.new(0, H + 9, 3), Color = red, Material = Enum.Material.SmoothPlastic })
	CollectionService:AddTag(glove, "Float")
	add({ Name = "GloveCuff", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 5, 5), CFrame = cf * CFrame.new(0, H + 2.5, 3) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.new(1, 1, 1), Material = Enum.Material.SmoothPlastic })

	-- Counter and shopkeeper.
	local counter = add({ Name = "Counter", Size = Vector3.new(14, 3.4, 2.4), CFrame = cf * CFrame.new(0, 1.9, 1), Color = wood, Material = Enum.Material.WoodPlanks, CanCollide = true })
	add({ Name = "CounterTop", Size = Vector3.new(14.6, 0.3, 3), CFrame = cf * CFrame.new(0, 3.75, 1), Color = cream, Material = Enum.Material.Marble })
	local keeper = add({ Name = "Shopkeeper", Shape = Enum.PartType.Ball, Size = Vector3.new(4.4, 3.8, 4.4), CFrame = cf * CFrame.new(0, 5.4, 4.2), Color = Color3.fromRGB(255, 150, 90), Material = Enum.Material.SmoothPlastic })
	for _, sx in { -1, 1 } do
		add({ Name = "KeeperEye", Shape = Enum.PartType.Ball, Size = Vector3.new(0.7, 1, 0.4), CFrame = keeper.CFrame * CFrame.new(sx * 0.9, 0.3, -2.05), Color = Color3.fromRGB(30, 25, 30), Material = Enum.Material.SmoothPlastic })
	end
	add({ Name = "KeeperBand", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 4.2, 4.2), CFrame = keeper.CFrame * CFrame.new(0, 1.3, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = red, Material = Enum.Material.Fabric })
	billboard(keeper, 4, "Slapsmith Sam", Vector2.new(8, 1.6))

	-- Every slap on display along the walls, cheapest by the door.
	local spots = {}
	for i = 0, 3 do
		table.insert(spots, CFrame.new(-W / 2 + 1.6, 0, -6 + i * 4) * CFrame.Angles(0, -math.pi / 2, 0))
	end
	for i = 0, 3 do
		table.insert(spots, CFrame.new(W / 2 - 1.6, 0, 6 - i * 4) * CFrame.Angles(0, math.pi / 2, 0))
	end
	table.insert(spots, CFrame.new(-10, 0, D / 2 - 1.8))
	for i, key in Config.SlapOrder do
		local def = Config.Gear[key]
		local spot = spots[i]
		if not spot then
			break
		end
		local at = cf * spot
		add({ Name = "DisplayStand", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 2, 2), CFrame = at * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(60, 50, 80), Material = Enum.Material.SmoothPlastic })
		local shape = if def.look == "bat" or def.look == "mallet" then Enum.PartType.Block elseif def.look == "paddle" then Enum.PartType.Block else Enum.PartType.Ball
		local size = if def.look == "bat" then Vector3.new(0.9, 3, 0.9) elseif def.look == "mallet" then Vector3.new(2.2, 1.4, 1.4) elseif def.look == "paddle" then Vector3.new(2, 2.2, 0.4) else Vector3.new(1.8, 1.6, 1.8)
		local item = add({ Name = "Display_" .. key, Shape = shape, Size = size, CFrame = at * CFrame.new(0, 4.2, 0), Color = def.color, Material = if def.look == "scepter" then Enum.Material.Neon else Enum.Material.SmoothPlastic, CanCollide = false })
		CollectionService:AddTag(item, "Float")
		local label = billboard(item, 1.8, def.name .. (if def.rebirth > 0 then "\n🔒 Rebirth " .. def.rebirth else ""), Vector2.new(3.6, 1.3))
		label.TextColor3 = def.color
		label.Parent.MaxDistance = 24
	end
	-- Crates and barrels outside.
	for _, c in { { -W / 2 - 2.5, -D / 2 + 3 }, { W / 2 + 2.5, -D / 2 + 1 }, { W / 2 + 2.6, -D / 2 + 4.2 } } do
		add({ Name = "Crate", Size = Vector3.new(3, 3, 3), CFrame = cf * CFrame.new(c[1], 1.5, c[2]) * CFrame.Angles(0, math.rad(15), 0), Color = wood, Material = Enum.Material.WoodPlanks, CanCollide = true })
	end
	add({ Name = "Barrel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3.4, 2.6, 2.6), CFrame = cf * CFrame.new(-W / 2 - 2.4, 1.7, -D / 2 - 0.6) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(120, 80, 50), Material = Enum.Material.Wood, CanCollide = true })

	model.Parent = map
	MapBuilder.SlapShop = counter
end

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
	for lampX = -195, 195, 30 do
		-- Keep the base paths clear: bought slimes hop up them to their pens.
		local x = lampX
		for _, px in MapBuilder.PlotXs do
			if math.abs(x - px) < 8 then
				x = px + 9
			end
		end
		lamp(Vector3.new(x, 0, 12), Color3.fromRGB(255, 220, 140))
		lamp(Vector3.new(x, 0, -12), Color3.fromRGB(255, 220, 140))
	end
	-- Signposts at both ends of the street pointing to the mini games.
	for _, s in { { x = 215, text = "THIS WAY: 🎣 GOO POND · 🔨 ARCADE", face = Enum.NormalId.Left }, { x = -215, text = "THIS WAY: 🗼 SKY TOWER", face = Enum.NormalId.Right } } do
		local board = part({ Name = "FunSign", Size = Vector3.new(0.6, 5, 16), Position = Vector3.new(s.x, 9, -18), Color = Color3.fromRGB(60, 40, 100), Material = Enum.Material.WoodPlanks })
		board.Parent = deco
		part({ Name = "FunSignPost", Size = Vector3.new(0.8, 7, 0.8), Position = Vector3.new(s.x, 3.5, -18), Color = Color3.fromRGB(110, 75, 50), Material = Enum.Material.Wood }).Parent = deco
		signGui(board, s.face, s.text, "FunText")
	end
	-- Gardens in the gaps between neighbouring bases: a tree, bushes and a lamp.
	local bushColors = { Color3.fromRGB(80, 180, 80), Color3.fromRGB(100, 200, 90), Color3.fromRGB(70, 160, 100) }
	for _, side in { 1, -1 } do
		for i = 1, #MapBuilder.PlotXs - 1 do
			local x = (MapBuilder.PlotXs[i] + MapBuilder.PlotXs[i + 1]) / 2
			local z = side * (MapBuilder.PlotZ + 8)
			tree(Vector3.new(x, 0, z))
			for k = -2, 2 do
				if k ~= 0 then
					part({ Name = "Bush", Shape = Enum.PartType.Ball, Size = Vector3.one * rng:NextNumber(4, 5.5), Position = Vector3.new(x + rng:NextNumber(-3, 3), 1.4, side * (MapBuilder.PlotZ + k * 9)),
						Color = bushColors[rng:NextInteger(1, #bushColors)], Material = Enum.Material.Grass }).Parent = deco
				end
			end
			lamp(Vector3.new(x, 0, side * (MapBuilder.PlotZ - 24)), Color3.fromRGB(255, 200, 150))
		end
	end
	-- Floating crystals above the belt.
	local crystalColors = { Color3.fromRGB(120, 255, 200), Color3.fromRGB(255, 120, 220), Color3.fromRGB(140, 160, 255) }
	for i, x in { -180, -120, -60, 0, 60, 120, 180 } do
		crystal(Vector3.new(x, 26, 0), crystalColors[(i - 1) % #crystalColors + 1])
	end
	-- Trees around the outside of the map.
	for _ = 1, 56 do
		-- Ends of the map (|x| > 182) hold the mini games, so trees go above and below them.
		local side = rng:NextInteger(1, 2)
		local pos
		if side == 1 then
			pos = Vector3.new(rng:NextNumber(-330, 330), 0, rng:NextNumber(140, 250))
		elseif side == 2 then
			pos = Vector3.new(rng:NextNumber(-330, 330), 0, rng:NextNumber(-250, -140))
		elseif side == 3 then
			pos = Vector3.new(rng:NextNumber(-345, -305), 0, rng:NextNumber(-120, 120))
		else
			pos = Vector3.new(rng:NextNumber(305, 345), 0, rng:NextNumber(-120, 120))
		end
		tree(pos)
	end
	-- Colourful flowers scattered on the grass.
	for _ = 1, 180 do
		local pos = Vector3.new(rng:NextNumber(-350, 350), 0.3, rng:NextNumber(-270, 270))
		if math.abs(pos.Z) > 104 or math.abs(pos.X) > 172 then
			part({
				Name = "Flower",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * rng:NextNumber(0.8, 1.6),
				Position = pos,
				Color = leafColors[rng:NextInteger(1, #leafColors)],
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
			}).Parent = deco
		end
	end

	-- ===== Scenery so the map doesn't feel empty =====
	local stone = Color3.fromRGB(170, 165, 160)
	local function flat(name: string, size: Vector3, pos: Vector3, color: Color3, material: Enum.Material)
		part({ Name = name, Size = size, Position = pos, Color = color, Material = material, CanCollide = false, CastShadow = false }).Parent = deco
	end
	-- Sidewalks along both sides of the belt, and a stone path from the belt to every base door.
	local beltLen = (MapBuilder.BeltEnd - MapBuilder.BeltStart).Magnitude
	for _, side in { 1, -1 } do
		flat("Sidewalk", Vector3.new(beltLen + 10, 0.12, 5), Vector3.new(0, 0.06, side * 15.5), stone, Enum.Material.Cobblestone)
		flat("Curb", Vector3.new(beltLen + 10, 0.3, 0.6), Vector3.new(0, 0.15, side * 18.3), Color3.fromRGB(235, 232, 228), Enum.Material.SmoothPlastic)
		for _, x in MapBuilder.PlotXs do
			local from, to = 18, MapBuilder.PlotZ - MapBuilder.PlotSize / 2 - 0.5
			flat("Path", Vector3.new(12, 0.1, to - from), Vector3.new(x, 0.05, side * (from + to) / 2), stone, Enum.Material.Cobblestone)
			for _, dx in { -6.6, 6.6 } do
				flat("PathEdge", Vector3.new(1.2, 0.2, to - from), Vector3.new(x + dx, 0.1, side * (from + to) / 2), Color3.fromRGB(235, 232, 228), Enum.Material.SmoothPlastic)
				-- Flower beds lining the path.
				for z = from + 4, to - 4, 6 do
					part({ Name = "Shrub", Shape = Enum.PartType.Ball, Size = Vector3.one * rng:NextNumber(2.2, 3), Position = Vector3.new(x + dx * 1.35, 0.9, side * z),
						Color = Color3.fromRGB(80, 170, 80), Material = Enum.Material.Grass }).Parent = deco
					part({ Name = "Bloom", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, Position = Vector3.new(x + dx * 1.35, 2.1, side * z),
						Color = leafColors[rng:NextInteger(1, #leafColors)], Material = Enum.Material.SmoothPlastic, CanCollide = false }).Parent = deco
				end
			end
		end
	end

	-- Two slime fountains in the open squares between the bases.
	local function fountain(pos: Vector3, color: Color3)
		part({ Name = "FountainBase", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.6, 16, 16), CFrame = CFrame.new(pos + Vector3.new(0, 0.8, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(225, 222, 218), Material = Enum.Material.Slate }).Parent = deco
		part({ Name = "FountainWater", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 14, 14), CFrame = CFrame.new(pos + Vector3.new(0, 1.55, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(110, 190, 230), Material = Enum.Material.Glass, Transparency = 0.3, CanCollide = false }).Parent = deco
		part({ Name = "FountainColumn", Shape = Enum.PartType.Cylinder, Size = Vector3.new(5, 2, 2), CFrame = CFrame.new(pos + Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(225, 222, 218), Material = Enum.Material.Slate }).Parent = deco
		local slime = part({ Name = "FountainSlime", Shape = Enum.PartType.Ball, Size = Vector3.new(4, 3.4, 4), Position = pos + Vector3.new(0, 6.6, 0), Color = color, Material = Enum.Material.SmoothPlastic })
		slime.Parent = deco
		for _, sx in { -1, 1 } do
			part({ Name = "FountainEye", Shape = Enum.PartType.Ball, Size = Vector3.new(0.6, 0.9, 0.4), Position = pos + Vector3.new(sx * 0.8, 7, -1.85), Color = Color3.fromRGB(30, 25, 30), Material = Enum.Material.SmoothPlastic, CanCollide = false }).Parent = deco
		end
		local splash = Instance.new("ParticleEmitter")
		splash.Color = ColorSequence.new(Color3.fromRGB(190, 230, 255))
		splash.Size = NumberSequence.new(0.5, 0.1)
		splash.Transparency = NumberSequence.new(0.2, 1)
		splash.Lifetime = NumberRange.new(1, 1.4)
		splash.Rate = 30
		splash.Speed = NumberRange.new(9, 12)
		splash.SpreadAngle = Vector2.new(18, 18)
		splash.Acceleration = Vector3.new(0, -25, 0)
		splash.EmissionDirection = Enum.NormalId.Top
		splash.Parent = slime
		for k = 0, 7 do
			local a = k / 8 * math.pi * 2
			part({ Name = "Bench", Size = Vector3.new(4, 0.5, 1.4), CFrame = CFrame.new(pos + Vector3.new(math.cos(a) * 12, 1.4, math.sin(a) * 12)) * CFrame.Angles(0, -a + math.pi / 2, 0), Color = Color3.fromRGB(150, 100, 65), Material = Enum.Material.WoodPlanks }).Parent = deco
		end
	end
	fountain(Vector3.new(110, 0, 32), Color3.fromRGB(120, 220, 140))
	fountain(Vector3.new(-110, 0, -32), Color3.fromRGB(255, 150, 200))

	-- Giant slime mushrooms, rocks and pine trees behind the bases and round the edges.
	local function mushroom(pos: Vector3, scale: number)
		local h = 6 * scale
		part({ Name = "Stem", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 2 * scale, 2 * scale), CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(245, 235, 215), Material = Enum.Material.SmoothPlastic }).Parent = deco
		local capColor = ({ Color3.fromRGB(230, 80, 90), Color3.fromRGB(160, 110, 230), Color3.fromRGB(90, 180, 230) })[rng:NextInteger(1, 3)]
		part({ Name = "Cap", Shape = Enum.PartType.Ball, Size = Vector3.new(7, 3.4, 7) * scale, Position = pos + Vector3.new(0, h + 0.4 * scale, 0), Color = capColor, Material = Enum.Material.SmoothPlastic }).Parent = deco
		for k = 1, 4 do
			local a = k * 1.7
			part({ Name = "Spot", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9 * scale, Position = pos + Vector3.new(math.cos(a) * 2 * scale, h + 1.6 * scale, math.sin(a) * 2 * scale), Color = Color3.new(1, 1, 1), Material = Enum.Material.SmoothPlastic, CanCollide = false }).Parent = deco
		end
	end
	local function rock(pos: Vector3)
		local size = Vector3.new(rng:NextNumber(4, 9), rng:NextNumber(3, 6), rng:NextNumber(4, 8))
		part({ Name = "Rock", Size = size, CFrame = CFrame.new(pos + Vector3.new(0, size.Y / 2 - 0.6, 0)) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, 6.28), rng:NextNumber(-0.2, 0.2)), Color = Color3.fromRGB(130, 128, 135), Material = Enum.Material.Slate }).Parent = deco
	end
	local function pine(pos: Vector3)
		local h = rng:NextNumber(14, 22)
		part({ Name = "Trunk", Size = Vector3.new(1.6, h * 0.4, 1.6), Position = pos + Vector3.new(0, h * 0.2, 0), Color = Color3.fromRGB(110, 75, 55), Material = Enum.Material.Wood }).Parent = deco
		for k = 0, 2 do
			local w = (3 - k) * 3.4
			part({ Name = "PineLeaves", Shape = Enum.PartType.Ball, Size = Vector3.new(w, h * 0.32, w), Position = pos + Vector3.new(0, h * (0.38 + k * 0.2), 0), Color = Color3.fromRGB(50, 130, 80), Material = Enum.Material.Grass }).Parent = deco
		end
	end
	local backZ = MapBuilder.PlotZ + MapBuilder.PlotSize / 2 + 12
	for _, side in { 1, -1 } do
		for x = -330, 330, 14 do
			local z = side * (backZ + rng:NextNumber(0, 40))
			local roll = rng:NextNumber()
			if roll < 0.45 then
				pine(Vector3.new(x + rng:NextNumber(-4, 4), 0, z))
			elseif roll < 0.65 then
				mushroom(Vector3.new(x, 0, z), rng:NextNumber(0.8, 1.6))
			elseif roll < 0.85 then
				rock(Vector3.new(x, 0, z))
			end
		end
	end
	-- Rolling hills around the edge of the map.
	for k = 0, 47 do
		local a = k / 48 * math.pi * 2
		local pos = Vector3.new(math.cos(a) * 370, -6, math.sin(a) * 290)
		local r = rng:NextNumber(50, 80)
		part({ Name = "Hill", Shape = Enum.PartType.Ball, Size = Vector3.new(r, r * 0.6, r), Position = pos, Color = Color3.fromRGB(100, 175, 85):Lerp(Color3.fromRGB(80, 150, 90), rng:NextNumber()), Material = Enum.Material.Grass }).Parent = deco
	end
	-- A few mushrooms and rocks dotted round the squares near the belt.
	for _, p in { Vector3.new(-110, 0, 30), Vector3.new(85, 0, -44), Vector3.new(-200, 0, 34), Vector3.new(200, 0, -34), Vector3.new(0, 0, -40) } do
		mushroom(p, 0.9)
		rock(p + Vector3.new(7, 0, 3))
	end

	-- Bunting flags strung across the street between the lamp posts.
	local flagColors = { Color3.fromRGB(255, 110, 140), Color3.fromRGB(255, 215, 90), Color3.fromRGB(110, 200, 255), Color3.fromRGB(140, 230, 130) }
	for _, x in { -150, -90, -30, 30, 90, 150 } do
		part({ Name = "BuntingRope", Size = Vector3.new(0.12, 0.12, 24), Position = Vector3.new(x, 9.4, 0), Color = Color3.fromRGB(240, 240, 240), Material = Enum.Material.SmoothPlastic, CanCollide = false }).Parent = deco
		for k = 0, 10 do
			local z = -11 + k * 2.2
			local sag = -1.6 * (1 - (z / 12) ^ 2)
			part({ Name = "BuntingFlag", Size = Vector3.new(0.1, 1.2, 1.2), CFrame = CFrame.new(x, 8.6 + sag, z) * CFrame.Angles(math.rad(45), 0, 0), Color = flagColors[k % #flagColors + 1], Material = Enum.Material.Fabric, CanCollide = false, CastShadow = false }).Parent = deco
		end
	end

	-- A rainbow arch over the middle of the belt, above the spawn.
	local rainbow = { Color3.fromRGB(240, 90, 90), Color3.fromRGB(250, 160, 70), Color3.fromRGB(250, 220, 90), Color3.fromRGB(120, 210, 110), Color3.fromRGB(90, 160, 240), Color3.fromRGB(160, 110, 230) }
	for band, color in rainbow do
		local r = 34 - band * 1.6
		for k = 0, 23 do
			local a = k / 24 * math.pi
			local a2 = (k + 1) / 24 * math.pi
			local p1 = Vector3.new(0, math.sin(a) * r, math.cos(a) * r)
			local p2 = Vector3.new(0, math.sin(a2) * r, math.cos(a2) * r)
			part({ Name = "Rainbow", Size = Vector3.new(1.6, 1.6, (p2 - p1).Magnitude + 0.2), CFrame = CFrame.lookAt((p1 + p2) / 2, p2), Color = color, Material = Enum.Material.SmoothPlastic, CanCollide = false, CastShadow = false }).Parent = deco
		end
	end
	for _, z in { -34, 34 } do
		for k = 1, 5 do
			part({ Name = "RainbowCloud", Shape = Enum.PartType.Ball, Size = Vector3.one * (7 - k * 0.6), Position = Vector3.new((k - 3) * 3, 1.6 + (k % 2), z), Color = Color3.new(1, 1, 1), Material = Enum.Material.SmoothPlastic, CanCollide = false }).Parent = deco
		end
	end

	-- White picket fences along the sidewalks, with gaps for the paths.
	for _, side in { 1, -1 } do
		for x = -200, 200, 4 do
			local nearPath = false
			for _, px in MapBuilder.PlotXs do
				nearPath = nearPath or math.abs(x - px) < 9
			end
			if not nearPath and math.abs(x) > 8 then
				part({ Name = "Picket", Size = Vector3.new(0.5, 2.6, 0.3), Position = Vector3.new(x, 1.3, side * 19.4), Color = Color3.new(1, 1, 1), Material = Enum.Material.SmoothPlastic }).Parent = deco
				part({ Name = "FenceRail", Size = Vector3.new(4, 0.3, 0.2), Position = Vector3.new(x + 2, 1.7, side * 19.4), Color = Color3.new(1, 1, 1), Material = Enum.Material.SmoothPlastic, CanCollide = false }).Parent = deco
			end
		end
	end

	-- Flower meadows and darker grass patches in the open fields.
	local meadowCenters = {}
	for _, side in { 1, -1 } do
		for _, x in { -225, -110, 0, 110, 225 } do
			table.insert(meadowCenters, Vector3.new(x, 0, side * 36))
		end
		table.insert(meadowCenters, Vector3.new(-280, 0, side * 90))
		table.insert(meadowCenters, Vector3.new(280, 0, side * 110))
	end
	for _, c in meadowCenters do
		if (c - Vector3.new(110, 0, 32)).Magnitude < 20 or (c - Vector3.new(-110, 0, -32)).Magnitude < 20 or (c - MapBuilder.SlapShopPosition).Magnitude < 30 or (c - MapBuilder.DispenserPosition).Magnitude < 20 then
			continue
		end
		part({ Name = "GrassPatch", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 20, 16), CFrame = CFrame.new(c + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(90, 165, 75), Material = Enum.Material.Grass, CanCollide = false, CastShadow = false }).Parent = deco
		for _ = 1, 14 do
			local p = c + Vector3.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(-6, 6))
			part({ Name = "Stalk", Size = Vector3.new(0.2, 1.4, 0.2), Position = p + Vector3.new(0, 0.7, 0), Color = Color3.fromRGB(70, 150, 60), Material = Enum.Material.Grass, CanCollide = false, CastShadow = false }).Parent = deco
			part({ Name = "MeadowFlower", Shape = Enum.PartType.Ball, Size = Vector3.one * rng:NextNumber(0.8, 1.2), Position = p + Vector3.new(0, 1.5, 0), Color = leafColors[rng:NextInteger(1, #leafColors)], Material = Enum.Material.SmoothPlastic, CanCollide = false, CastShadow = false }).Parent = deco
		end
	end

	-- Floating islands with trees and waterfalls high above the hills.
	for i, c in { Vector3.new(-250, 95, 170), Vector3.new(240, 110, -180), Vector3.new(300, 85, 150), Vector3.new(-310, 105, -140) } do
		local r = 16 + i * 2
		part({ Name = "IslandTop", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, r * 2, r * 2), CFrame = CFrame.new(c) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(105, 185, 90), Material = Enum.Material.Grass }).Parent = deco
		for k = 1, 3 do
			part({ Name = "IslandRock", Shape = Enum.PartType.Ball, Size = Vector3.new(r * 2 - k * r * 0.5, r * 0.7, r * 2 - k * r * 0.5), Position = c - Vector3.new(0, k * r * 0.35, 0), Color = Color3.fromRGB(140, 115, 95):Lerp(Color3.fromRGB(110, 100, 105), k / 3), Material = Enum.Material.Slate }).Parent = deco
		end
		tree(c + Vector3.new(r * 0.3, 1.5, r * 0.2))
		tree(c + Vector3.new(-r * 0.4, 1.5, -r * 0.1))
		part({ Name = "Waterfall", Size = Vector3.new(5, c.Y, 0.6), Position = Vector3.new(c.X + r - 1, c.Y / 2, c.Z), Color = Color3.fromRGB(150, 210, 245), Material = Enum.Material.Glass, Transparency = 0.35, CanCollide = false, CastShadow = false }).Parent = deco
	end

	-- Hot air balloons drifting over the map.
	for i, c in { Vector3.new(-180, 70, 120), Vector3.new(60, 85, 150), Vector3.new(200, 75, 100), Vector3.new(-60, 90, -150), Vector3.new(170, 80, -130) } do
		local color = flagColors[(i - 1) % #flagColors + 1]
		local balloon = part({ Name = "Balloon", Shape = Enum.PartType.Ball, Size = Vector3.new(16, 19, 16), Position = c, Color = color, Material = Enum.Material.SmoothPlastic, CanCollide = false })
		balloon.Parent = deco
		part({ Name = "BalloonStripe", Shape = Enum.PartType.Ball, Size = Vector3.new(16.3, 5, 16.3), Position = c, Color = Color3.new(1, 1, 1), Material = Enum.Material.SmoothPlastic, CanCollide = false }).Parent = deco
		part({ Name = "Basket", Size = Vector3.new(4, 3, 4), Position = c - Vector3.new(0, 14, 0), Color = Color3.fromRGB(150, 100, 60), Material = Enum.Material.WoodPlanks, CanCollide = false }).Parent = deco
		for _, o in { Vector3.new(1.8, 0, 1.8), Vector3.new(-1.8, 0, 1.8), Vector3.new(1.8, 0, -1.8), Vector3.new(-1.8, 0, -1.8) } do
			part({ Name = "BalloonRope", Size = Vector3.new(0.15, 6, 0.15), Position = c - Vector3.new(0, 10, 0) + o, Color = Color3.fromRGB(90, 70, 50), Material = Enum.Material.SmoothPlastic, CanCollide = false }).Parent = deco
		end
	end

	-- Benches and planters along the sidewalks.
	for _, side in { 1, -1 } do
		for x = -180, 180, 30 do
			local clear = true
			for _, px in MapBuilder.PlotXs do
				clear = clear and math.abs(x + 15 - px) > 10
			end
			if clear then
				part({ Name = "StreetBench", Size = Vector3.new(5, 0.5, 1.6), Position = Vector3.new(x + 15, 1.5, side * 17), Color = Color3.fromRGB(150, 100, 65), Material = Enum.Material.WoodPlanks }).Parent = deco
				part({ Name = "BenchBack", Size = Vector3.new(5, 1.4, 0.3), Position = Vector3.new(x + 15, 2.4, side * 17.8), Color = Color3.fromRGB(150, 100, 65), Material = Enum.Material.WoodPlanks }).Parent = deco
			end
		end
	end
end

local function buildPlot(map: Folder, index: number, center: Vector3, facing: number)
	-- A big roofed base like Steal a Brainrot's: a coloured building with a wide front door
	-- (laser door when locked), pens in two rows either side of a red-carpet aisle, lights in
	-- the ceiling and the owner's name floating high above the roof.
	local S = MapBuilder.PlotSize
	local half = S / 2
	local H = MapBuilder.WallHeight
	local DH = MapBuilder.DoorHeight
	local door = MapBuilder.DoorWidth / 2
	local cf = CFrame.new(center) * CFrame.Angles(0, facing, 0)
	local plot = Instance.new("Model")
	plot.Name = "Plot" .. index
	plot:SetAttribute("Index", index)
	local theme = THEMES[(index - 1) % #THEMES + 1]
	plot:SetAttribute("Theme", theme)
	-- Muted tones of the base colour: easy on the eyes, still easy to tell bases apart.
	local muted = theme:Lerp(Color3.fromRGB(200, 200, 205), 0.45)
	local soft = Color3.fromRGB(214, 211, 206)
	local dark = theme:Lerp(Color3.fromRGB(60, 60, 70), 0.6)

	local floor = part({
		Name = "Floor",
		Size = Vector3.new(S, 0.5, S),
		CFrame = cf * CFrame.new(0, 0.25, 0),
		Color = Color3.fromRGB(196, 150, 108),
		Material = Enum.Material.WoodPlanks,
	})
	floor.Parent = plot
	plot.PrimaryPart = floor

	-- Neon trim around the floor edge in the base colour.
	for _, t in {
		{ Vector3.new(S, 0.3, 0.6), Vector3.new(0, 0.6, half - 0.8) },
		{ Vector3.new(0.6, 0.3, S), Vector3.new(-half + 0.8, 0.6, 0) },
		{ Vector3.new(0.6, 0.3, S), Vector3.new(half - 0.8, 0.6, 0) },
		{ Vector3.new(half - door, 0.3, 0.6), Vector3.new(-(door + half) / 2, 0.6, -half + 0.8) },
		{ Vector3.new(half - door, 0.3, 0.6), Vector3.new((door + half) / 2, 0.6, -half + 0.8) },
	} do
		part({ Name = "Trim", Size = t[1], CFrame = cf * CFrame.new(t[2]), Color = muted, Material = Enum.Material.SmoothPlastic, CanCollide = false }).Parent = plot
	end

	-- Outer walls: big glass panes over a low wall all round, like Steal a Brainrot's bases, so
	-- you can see the slimes inside and daylight gets in. The front has a wide doorway with a
	-- solid header above it for the name board.
	local side = half - door
	for _, w in {
		{ Vector3.new(S, KNEE, 1), Vector3.new(0, KNEE / 2, half) },
		{ Vector3.new(1, KNEE, S), Vector3.new(-half, KNEE / 2, 0) },
		{ Vector3.new(1, KNEE, S), Vector3.new(half, KNEE / 2, 0) },
		{ Vector3.new(S, HEADER, 1), Vector3.new(0, H - HEADER / 2, half) },
		{ Vector3.new(1, HEADER, S), Vector3.new(-half, H - HEADER / 2, 0) },
		{ Vector3.new(1, HEADER, S), Vector3.new(half, H - HEADER / 2, 0) },
		{ Vector3.new(side, KNEE, 1), Vector3.new(-(door + side / 2), KNEE / 2, -half) },
		{ Vector3.new(side, KNEE, 1), Vector3.new(door + side / 2, KNEE / 2, -half) },
		{ Vector3.new(side, HEADER, 1), Vector3.new(-(door + side / 2), H - HEADER / 2, -half) },
		{ Vector3.new(side, HEADER, 1), Vector3.new(door + side / 2, H - HEADER / 2, -half) },
		{ Vector3.new(door * 2, H - DH, 1), Vector3.new(0, DH + (H - DH) / 2, -half) },
	} do
		part({ Name = "Wall", Size = w[1], CFrame = cf * CFrame.new(w[2]), Color = muted, Material = Enum.Material.SmoothPlastic }).Parent = plot
	end
	local glassH = H - KNEE - HEADER
	for _, g in {
		{ Vector3.new(S, glassH, 0.4), Vector3.new(0, KNEE + glassH / 2, half) },
		{ Vector3.new(0.4, glassH, S), Vector3.new(-half, KNEE + glassH / 2, 0) },
		{ Vector3.new(0.4, glassH, S), Vector3.new(half, KNEE + glassH / 2, 0) },
		{ Vector3.new(side, glassH, 0.4), Vector3.new(-(door + side / 2), KNEE + glassH / 2, -half) },
		{ Vector3.new(side, glassH, 0.4), Vector3.new(door + side / 2, KNEE + glassH / 2, -half) },
	} do
		part({ Name = "GlassWall", Size = g[1], CFrame = cf * CFrame.new(g[2]), Color = Color3.fromRGB(200, 235, 255), Material = Enum.Material.Glass, Transparency = 0.6, CastShadow = false }).Parent = plot
	end

	local start = Instance.new("Folder")
	start.Name = "StartDecor"
	start.Parent = plot
	local function add(props): Part
		props.CanCollide = props.CanCollide or false
		props.CastShadow = props.CastShadow or false
		local p = part(props)
		p.Parent = start
		return p
	end

	-- The roof, with an overhang, a white parapet and a glowing rim.
	add({ Name = "RoofSlab", Size = Vector3.new(S + 3, 1.2, S + 3), CFrame = cf * CFrame.new(0, H + 0.6, 0), Color = dark, Material = Enum.Material.SmoothPlastic, CanCollide = true, CastShadow = true })
	for _, r in {
		{ Vector3.new(S + 3, 1.4, 1), Vector3.new(0, H + 1.9, half + 1) },
		{ Vector3.new(S + 3, 1.4, 1), Vector3.new(0, H + 1.9, -half - 1) },
		{ Vector3.new(1, 1.4, S + 3), Vector3.new(-half - 1, H + 1.9, 0) },
		{ Vector3.new(1, 1.4, S + 3), Vector3.new(half + 1, H + 1.9, 0) },
	} do
		add({ Name = "Parapet", Size = r[1], CFrame = cf * CFrame.new(r[2]), Color = soft, Material = Enum.Material.SmoothPlastic, CanCollide = true })
	end
	-- Two-tone walls: a dark skirting at the bottom and a light band under the roof.
	for _, b in {
		{ Vector3.new(S + 0.4, 1.6, 1.4), Vector3.new(0, 0.8, half) },
		{ Vector3.new(1.4, 1.6, S + 0.4), Vector3.new(-half, 0.8, 0) },
		{ Vector3.new(1.4, 1.6, S + 0.4), Vector3.new(half, 0.8, 0) },
		{ Vector3.new(side, 1.6, 1.4), Vector3.new(-(door + side / 2), 0.8, -half) },
		{ Vector3.new(side, 1.6, 1.4), Vector3.new(door + side / 2, 0.8, -half) },
	} do
		add({ Name = "Skirting", Size = b[1], CFrame = cf * CFrame.new(b[2]), Color = dark, Material = Enum.Material.SmoothPlastic })
	end
	for _, b in {
		{ Vector3.new(S + 0.4, 1.2, 1.4), Vector3.new(0, H - 0.6, half) },
		{ Vector3.new(1.4, 1.2, S + 0.4), Vector3.new(-half, H - 0.6, 0) },
		{ Vector3.new(1.4, 1.2, S + 0.4), Vector3.new(half, H - 0.6, 0) },
		{ Vector3.new(S + 0.4, 1.2, 1.4), Vector3.new(0, H - 0.6, -half) },
	} do
		add({ Name = "Band", Size = b[1], CFrame = cf * CFrame.new(b[2]), Color = soft, Material = Enum.Material.SmoothPlastic })
	end
	-- Corner pillars.
	for _, c in { Vector3.new(-half, 0, -half), Vector3.new(half, 0, -half), Vector3.new(-half, 0, half), Vector3.new(half, 0, half) } do
		add({ Name = "WallPost", Size = Vector3.new(2.6, H + 1, 2.6), CFrame = cf * CFrame.new(c.X, (H + 1) / 2, c.Z), Color = dark, Material = Enum.Material.SmoothPlastic, CanCollide = true })
	end
	-- Cream walls and a light ceiling inside, so the slimes stand out.
	local cream = Color3.fromRGB(194, 182, 168) -- inside walls: a soft warm beige, not white
	local ceilingColor = Color3.fromRGB(150, 140, 130)
	local kneeIn, headIn = KNEE - 0.8, HEADER - 0.2
	for _, l in {
		{ Vector3.new(S - 2, kneeIn, 0.2), Vector3.new(0, 0.8 + kneeIn / 2, half - 0.6) },
		{ Vector3.new(0.2, kneeIn, S - 2), Vector3.new(-half + 0.6, 0.8 + kneeIn / 2, 0) },
		{ Vector3.new(0.2, kneeIn, S - 2), Vector3.new(half - 0.6, 0.8 + kneeIn / 2, 0) },
		{ Vector3.new(S - 2, headIn, 0.2), Vector3.new(0, H - 0.2 - headIn / 2, half - 0.6) },
		{ Vector3.new(0.2, headIn, S - 2), Vector3.new(-half + 0.6, H - 0.2 - headIn / 2, 0) },
		{ Vector3.new(0.2, headIn, S - 2), Vector3.new(half - 0.6, H - 0.2 - headIn / 2, 0) },
		{ Vector3.new(side - 1, kneeIn, 0.2), Vector3.new(-(door + side / 2) - 0.5, 0.8 + kneeIn / 2, -half + 0.6) },
		{ Vector3.new(side - 1, kneeIn, 0.2), Vector3.new(door + side / 2 + 0.5, 0.8 + kneeIn / 2, -half + 0.6) },
		{ Vector3.new(side - 1, headIn, 0.2), Vector3.new(-(door + side / 2) - 0.5, H - 0.2 - headIn / 2, -half + 0.6) },
		{ Vector3.new(side - 1, headIn, 0.2), Vector3.new(door + side / 2 + 0.5, H - 0.2 - headIn / 2, -half + 0.6) },
	} do
		add({ Name = "InnerWall", Size = l[1], CFrame = cf * CFrame.new(l[2]), Color = cream, Material = Enum.Material.SmoothPlastic })
	end
	add({ Name = "Ceiling", Size = Vector3.new(S - 1, 0.2, S - 1), CFrame = cf * CFrame.new(0, H - 0.1, 0), Color = ceilingColor, Material = Enum.Material.SmoothPlastic })
	-- Pillars down the outside walls break up the big flat sides.
	for _, d in { -11.5, 11.5 } do
		add({ Name = "WallPost", Size = Vector3.new(2, H, 1.6), CFrame = cf * CFrame.new(d, H / 2, half + 0.5), Color = dark, Material = Enum.Material.SmoothPlastic })
	end
	for _, z in { -11, 3, 16.5 } do
		for _, sx in { -1, 1 } do
			add({ Name = "WallPost", Size = Vector3.new(1.6, H, 2), CFrame = cf * CFrame.new(sx * (half + 0.5), H / 2, z), Color = dark, Material = Enum.Material.SmoothPlastic })
		end
	end
	-- Window sills along the top of the low walls, under the glass.
	for _, b in {
		{ Vector3.new(S - 2, 0.3, 1.8), Vector3.new(0, KNEE + 0.15, half) },
		{ Vector3.new(1.8, 0.3, S - 2), Vector3.new(-half, KNEE + 0.15, 0) },
		{ Vector3.new(1.8, 0.3, S - 2), Vector3.new(half, KNEE + 0.15, 0) },
		{ Vector3.new(side - 2, 0.3, 1.8), Vector3.new(-(door + side / 2) - 1, KNEE + 0.15, -half) },
		{ Vector3.new(side - 2, 0.3, 1.8), Vector3.new(door + side / 2 + 1, KNEE + 0.15, -half) },
	} do
		add({ Name = "Sill", Size = b[1], CFrame = cf * CFrame.new(b[2]), Color = soft, Material = Enum.Material.SmoothPlastic })
	end

	-- Inside: a red carpet down the middle, borders, and lights in the ceiling.
	add({ Name = "WelcomeRug", Size = Vector3.new(13, 0.08, S - 4), CFrame = cf * CFrame.new(0, 0.55, 0), Color = Color3.fromRGB(200, 40, 60), Material = Enum.Material.Fabric })
	add({ Name = "RugStripe", Size = Vector3.new(11, 0.1, S - 6), CFrame = cf * CFrame.new(0, 0.56, 0), Color = Color3.fromRGB(230, 60, 80), Material = Enum.Material.Fabric })
	for _, x in { -6.8, 6.8 } do
		add({ Name = "FloorBorder", Size = Vector3.new(0.6, 0.1, S - 4), CFrame = cf * CFrame.new(x, 0.57, 0), Color = Color3.fromRGB(255, 205, 60), Material = Enum.Material.Metal })
	end
	MapBuilder.AddRoomLights(start, cf, 0, H, theme)
	-- A big stripe in the base colour along the back wall.
	add({ Name = "BackStripe", Size = Vector3.new(S - 4, 0.8, 0.3), CFrame = cf * CFrame.new(0, 2.6, half - 0.8), Color = muted, Material = Enum.Material.SmoothPlastic })

	-- The doorway: pillars either side, glowing orbs, laser emitters, and a name board over it.
	for _, x in { -door - 1.2, door + 1.2 } do
		add({ Name = "EntrancePillar", Size = Vector3.new(2.4, DH + 1, 2.8), CFrame = cf * CFrame.new(x, (DH + 1) / 2, -half - 0.4), Color = soft, Material = Enum.Material.SmoothPlastic, CanCollide = true })
		add({ Name = "LaserEmitter", Size = Vector3.new(0.5, DH - 1, 1), CFrame = cf * CFrame.new(x + (if x < 0 then 1.4 else -1.4), DH / 2, -half), Color = Color3.fromRGB(50, 50, 60), Material = Enum.Material.Metal })
		local orb = add({ Name = "EntranceOrb", Shape = Enum.PartType.Ball, Size = Vector3.one * 2.2, CFrame = cf * CFrame.new(x, DH + 2.2, -half - 0.6), Color = theme, Material = Enum.Material.Neon })
		CollectionService:AddTag(orb, "Pulse")
	end
	local facade = add({ Name = "FacadeSign", Size = Vector3.new(door * 2 + 4, 3.6, 0.6), CFrame = cf * CFrame.new(0, DH + (H - DH) / 2 + 0.6, -half - 0.8), Color = Color3.fromRGB(30, 25, 40), Material = Enum.Material.SmoothPlastic })
	signGui(facade, Enum.NormalId.Front, "Empty Base", "FacadeGui")

	-- Sirens on the front corners of the roof, hidden until an alarm (PlotService turns them on).
	for _, x in { -half, half } do
		local siren = part({ Name = "Siren", Shape = Enum.PartType.Ball, Size = Vector3.one * 2, CFrame = cf * CFrame.new(x, H + 3.4, -half), Color = Color3.fromRGB(255, 30, 40), Material = Enum.Material.Neon, CanCollide = false, CastShadow = false, Transparency = 1 })
		siren.Parent = start
		local beam = Instance.new("SpotLight")
		beam.Color = Color3.fromRGB(255, 40, 40)
		beam.Range = 40
		beam.Angle = 50
		beam.Brightness = 6
		beam.Face = Enum.NormalId.Front
		beam.Enabled = false
		beam.Parent = siren
		CollectionService:AddTag(siren, "Siren")
	end

	-- Hedges hugging the outside of the side and back walls.
	for _, h in {
		{ Vector3.new(3, 4, S - 8), Vector3.new(-half - 2.6, 2, 2) },
		{ Vector3.new(3, 4, S - 8), Vector3.new(half + 2.6, 2, 2) },
		{ Vector3.new(S - 8, 4, 3), Vector3.new(0, 2, half + 2.6) },
	} do
		add({ Name = "Hedge", Size = h[1], CFrame = cf * CFrame.new(h[2]), Color = Color3.fromRGB(80, 170, 80), Material = Enum.Material.Grass, CanCollide = true })
	end
	-- Rims so the cash pad and lock button read as buttons.
	add({ Name = "CollectorRim", Size = Vector3.new(9.6, 0.5, 9.6), CFrame = cf * CFrame.new(-22, 0.6, -26), Color = Color3.fromRGB(40, 90, 50), Material = Enum.Material.SmoothPlastic })
	add({ Name = "LockRim", Size = Vector3.new(7.6, 0.7, 7.6), CFrame = cf * CFrame.new(22, 0.7, -26), Color = Color3.fromRGB(90, 30, 40), Material = Enum.Material.SmoothPlastic })

	-- The doorway itself: open, until the base is locked. Then it's solid for everyone except
	-- the owner (and anyone with a revenge pass), using collision groups (PlotService).
	part({ Name = "Door", Size = Vector3.new(door * 2, DH, 1.2), CFrame = cf * CFrame.new(0, DH / 2, -half), Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false }).Parent = plot

	-- Red laser bars across the doorway, switched on while the base is locked.
	local lasers = Instance.new("Folder")
	lasers.Name = "Lasers"
	lasers.Parent = plot
	for y = 1.2, DH - 1.5, 1.4 do
		part({ Name = "Laser", Size = Vector3.new(door * 2, 0.22, 0.22), CFrame = cf * CFrame.new(0, y, -half - 0.2), Color = Color3.fromRGB(255, 30, 40), Material = Enum.Material.Neon,
			CanCollide = false, CanQuery = false, CastShadow = false, Transparency = 1 }).Parent = lasers
	end

	-- A forcefield shell around the building, only visible while the base is locked.
	local shield = Instance.new("Folder")
	shield.Name = "Shield"
	shield.Parent = plot
	for _, w in {
		{ Vector3.new(S + 4, H + 3, 0.4), Vector3.new(0, (H + 3) / 2, -half - 2) },
		{ Vector3.new(S + 4, H + 3, 0.4), Vector3.new(0, (H + 3) / 2, half + 2) },
		{ Vector3.new(0.4, H + 3, S + 4), Vector3.new(-half - 2, (H + 3) / 2, 0) },
		{ Vector3.new(0.4, H + 3, S + 4), Vector3.new(half + 2, (H + 3) / 2, 0) },
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
	local spots = {}
	for zi = 1, #PEN_Z do
		for xi = 1, #PEN_X do
			table.insert(spots, Vector3.new(PEN_X[xi], 0.7, PEN_Z[zi]))
		end
	end
	for zi = 1, #UPPER_Z do
		for xi = 1, #PEN_X do
			table.insert(spots, Vector3.new(PEN_X[xi], UPPER_Y + 0.2, UPPER_Z[zi]))
		end
	end
	for _, spot in spots do
			n += 1
			local pad = part({
				Name = "Pen" .. n,
				Size = Vector3.new(7, 0.4, 7),
				CFrame = cf * CFrame.new(spot),
				Color = theme:Lerp(Color3.new(1, 1, 1), 0.5),
				Material = Enum.Material.SmoothPlastic,
				Transparency = 1,
				CanCollide = false,
			})
			pad:SetAttribute("Slot", n)
			-- A round display pedestal with a coloured rim; PlotService shows it for unlocked
			-- pens and tints the rim with the rarity of the slime on it.
			local pedestal = part({ Name = "Pedestal", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 7.2, 7.2), CFrame = pad.CFrame * CFrame.new(0, -0.05, 0) * CFrame.Angles(0, 0, math.pi / 2),
				Color = Color3.fromRGB(210, 205, 215), Material = Enum.Material.Marble, Transparency = 1, CanCollide = false, CastShadow = false })
			pedestal.Parent = pad
			local ring = part({ Name = "Ring", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 8.4, 8.4), CFrame = pad.CFrame * CFrame.new(0, -0.15, 0) * CFrame.Angles(0, 0, math.pi / 2),
				Color = theme, Material = Enum.Material.SmoothPlastic, Transparency = 1, CanCollide = false, CastShadow = false })
			ring.Parent = pad
			pad.Parent = pens
	end

	local collector = part({
		Name = "Collector",
		Size = Vector3.new(8, 0.6, 8),
		CFrame = cf * CFrame.new(-22, 0.8, -26),
		Color = Color3.fromRGB(60, 220, 100),
		Material = Enum.Material.Neon,
	})
	collector.Parent = plot
	billboard(collector, 4, "$0", Vector2.new(9, 2.4)).Name = "Bank"

	local lock = part({
		Name = "LockButton",
		Size = Vector3.new(6, 1, 6),
		CFrame = cf * CFrame.new(22, 0.9, -26),
		Color = Color3.fromRGB(255, 60, 80),
		Material = Enum.Material.Neon,
	})
	lock.Parent = plot
	billboard(lock, 4, "LOCK BASE", Vector2.new(9, 2.2)).Name = "Status"

	-- The owner's name and avatar floating high above the roof, readable from across the map
	-- (like Steal a Brainrot). "Sign" is an invisible anchor; PlotService fills in OwnerGui.
	local sign = part({ Name = "Sign", Size = Vector3.one, CFrame = cf * CFrame.new(0, H + 24, 0), Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false })
	sign.Parent = plot
	local board = Instance.new("BillboardGui")
	board.Name = "OwnerGui"
	board.Size = UDim2.fromScale(44, 9) -- studs, so it reads like a giant sign in the world
	board.LightInfluence = 0
	board.MaxDistance = 2000
	board.Enabled = false -- PlotService turns it on once someone owns the base
	board.Parent = sign
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = Color3.fromRGB(25, 20, 35)
	panel.BackgroundTransparency = 0.25
	panel.Parent = board
	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0.25, 0)
	panelCorner.Parent = panel
	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = theme
	panelStroke.Thickness = 6
	panelStroke.Parent = panel
	local ownerText = Instance.new("TextLabel")
	ownerText.Name = "Text"
	ownerText.Size = UDim2.fromScale(0.76, 0.9)
	ownerText.Position = UDim2.fromScale(0.22, 0.05)
	ownerText.BackgroundTransparency = 1
	ownerText.Font = Enum.Font.FredokaOne
	ownerText.TextScaled = true
	ownerText.TextColor3 = Color3.new(1, 1, 1)
	ownerText.TextStrokeTransparency = 0
	ownerText.Text = "Empty Base"
	ownerText.Parent = board
	local avatar = Instance.new("ImageLabel")
	avatar.Name = "Avatar"
	avatar.Size = UDim2.fromScale(0.17, 0.84)
	avatar.Position = UDim2.fromScale(0.025, 0.08)
	avatar.BackgroundColor3 = Color3.new(1, 1, 1)
	avatar.BackgroundTransparency = 0.1
	avatar.Image = ""
	avatar.Parent = board
	local avatarCorner = Instance.new("UICorner")
	avatarCorner.CornerRadius = UDim.new(0.5, 0)
	avatarCorner.Parent = avatar
	local frame = Instance.new("UIStroke")
	frame.Color = Color3.new(1, 1, 1)
	frame.Thickness = 4
	frame.Parent = avatar

	-- 🎨 Skin stand: the owner picks a base skin here (PlotService, Config.BaseSkins).
	add({ Name = "SkinPost", Size = Vector3.new(0.6, 3.2, 0.6), CFrame = cf * CFrame.new(-13.5, 1.6, -31), Color = Color3.fromRGB(110, 75, 50), Material = Enum.Material.Wood })
	local stand = part({ Name = "SkinStand", Size = Vector3.new(3.4, 2.6, 0.3), CFrame = cf * CFrame.new(-13.5, 3.6, -31) * CFrame.Angles(math.rad(-20), math.pi, 0), Color = Color3.fromRGB(250, 245, 235), Material = Enum.Material.SmoothPlastic, CanCollide = false })
	stand.Parent = plot
	billboard(stand, 2.6, "🎨 BASE SKIN", Vector2.new(7, 1.6)).Name = "SkinLabel"

	local spawnPoint = Instance.new("Part")
	spawnPoint.Name = "SpawnPoint"
	spawnPoint.Anchored = true
	spawnPoint.CanCollide = false
	spawnPoint.Transparency = 1
	spawnPoint.Size = Vector3.one
	spawnPoint.CFrame = cf * CFrame.new(0, 4, -22) * CFrame.Angles(0, math.pi, 0)
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
		Size = Vector3.new(720, 2, 560),
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
	buildSlapShop(map)

	local plots = {}
	local xs = MapBuilder.PlotXs
	local i = 0
	for _, side in { 1, -1 } do
		for _, x in xs do
			i += 1
			-- Plot local -Z must point at the belt (world z = 0).
			local facing = if side == 1 then 0 else math.pi
			local model, cf = buildPlot(map, i, Vector3.new(x, 0, side * MapBuilder.PlotZ), facing)
			table.insert(plots, { model = model, cframe = cf })
		end
	end
	return plots
end

return MapBuilder
