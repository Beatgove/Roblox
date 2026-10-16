-- Builds slime visuals from primitives: a glossy blob with a face, rarity decorations
-- (crowns, wings, halos...), mutation looks, aura particles and a label.

local CollectionService = game:GetService("CollectionService")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Util = require(game.ReplicatedStorage.Shared.Util)

local SlimeModel = {}

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

-- Adds a decoration part welded to the body. `offset` is relative to the body centre.
local function deco(model: Model, body: BasePart, props, offset: CFrame): Part
	local p = Instance.new("Part")
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Anchored = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	-- Ball parts are always perfect spheres, so ellipsoids use a sphere mesh on a block instead.
	local sphere = props.Shape == Enum.PartType.Ball
	for k, v in props do
		if k ~= "Shape" then
			(p :: any)[k] = v
		end
	end
	if sphere then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	elseif props.Shape then
		p.Shape = props.Shape
	end
	p.CFrame = body.CFrame * offset
	p.Parent = model
	weld(body, p)
	return p
end

local function makeLabel(parent: BasePart, height: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(200, 66)
	gui.StudsOffset = Vector3.new(0, height, 0)
	gui.MaxDistance = 70
	gui.LightInfluence = 0
	gui.Parent = parent

	local function line(name, y, h, font)
		local t = Instance.new("TextLabel")
		t.Name = name
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, 0, h, 0)
		t.Position = UDim2.new(0, 0, y, 0)
		t.Font = font
		t.TextScaled = true
		t.TextColor3 = Color3.new(1, 1, 1)
		t.TextStrokeTransparency = 0.2
		t.Parent = gui
		return t
	end
	line("Rarity", 0, 0.28, Enum.Font.FredokaOne)
	line("Title", 0.28, 0.42, Enum.Font.FredokaOne)
	line("Info", 0.7, 0.3, Enum.Font.GothamBold)
	return gui
end

local function addExtras(model: Model, body: BasePart, size: number, extras: { string }, color: Color3)
	local r = size / 2
	local gold = Color3.fromRGB(255, 210, 50)
	for _, e in extras do
		if e == "crown" then
			deco(model, body, { Name = "Crown", Shape = Enum.PartType.Cylinder, Size = Vector3.new(r * 0.35, r * 0.9, r * 0.9), Color = gold, Material = Enum.Material.Metal, Reflectance = 0.3 },
				CFrame.new(0, r * 0.95, 0) * CFrame.Angles(0, 0, math.pi / 2))
			for i = 0, 4 do
				local a = i / 5 * math.pi * 2
				deco(model, body, { Name = "Spike", Size = Vector3.new(r * 0.14, r * 0.35, r * 0.14), Color = gold, Material = Enum.Material.Metal },
					CFrame.new(math.cos(a) * r * 0.38, r * 1.25, math.sin(a) * r * 0.38))
			end
			deco(model, body, { Name = "Gem", Shape = Enum.PartType.Ball, Size = Vector3.one * r * 0.18, Color = Color3.fromRGB(255, 40, 80), Material = Enum.Material.Neon },
				CFrame.new(0, r * 0.98, -r * 0.45))
		elseif e == "halo" then
			deco(model, body, { Name = "Halo", Shape = Enum.PartType.Cylinder, Size = Vector3.new(r * 0.08, r * 1.2, r * 1.2), Color = Color3.fromRGB(255, 250, 190), Material = Enum.Material.Neon, Transparency = 0.15 },
				CFrame.new(0, r * 1.45, 0) * CFrame.Angles(0, 0, math.pi / 2))
		elseif e == "horns" then
			for _, s in { -1, 1 } do
				deco(model, body, { Name = "Horn", Size = Vector3.new(r * 0.16, r * 0.6, r * 0.16), Color = Color3.fromRGB(250, 240, 220), Material = Enum.Material.SmoothPlastic },
					CFrame.new(s * r * 0.45, r * 0.95, -r * 0.1) * CFrame.Angles(0, 0, -s * math.rad(25)))
			end
		elseif e == "wings" then
			for _, s in { -1, 1 } do
				deco(model, body, { Name = "Wing", Shape = Enum.PartType.Ball, Size = Vector3.new(r * 1.1, r * 0.7, r * 0.12), Color = Color3.fromRGB(255, 255, 255), Material = Enum.Material.Neon, Transparency = 0.35 },
					CFrame.new(s * r * 1.05, r * 0.35, r * 0.25) * CFrame.Angles(0, s * math.rad(25), s * math.rad(20)))
			end
		elseif e == "antenna" then
			for _, s in { -1, 1 } do
				deco(model, body, { Name = "Stalk", Size = Vector3.new(r * 0.07, r * 0.6, r * 0.07), Color = color, Material = Enum.Material.SmoothPlastic },
					CFrame.new(s * r * 0.25, r * 1.1, 0) * CFrame.Angles(0, 0, -s * math.rad(15)))
				deco(model, body, { Name = "Bulb", Shape = Enum.PartType.Ball, Size = Vector3.one * r * 0.22, Color = Color3.fromRGB(255, 255, 120), Material = Enum.Material.Neon },
					CFrame.new(s * r * 0.33, r * 1.42, 0))
			end
		elseif e == "leaf" then
			deco(model, body, { Name = "Stem", Size = Vector3.new(r * 0.08, r * 0.35, r * 0.08), Color = Color3.fromRGB(90, 60, 30), Material = Enum.Material.Wood },
				CFrame.new(0, r * 1.05, 0))
			deco(model, body, { Name = "Leaf", Shape = Enum.PartType.Ball, Size = Vector3.new(r * 0.55, r * 0.08, r * 0.3), Color = Color3.fromRGB(60, 200, 70), Material = Enum.Material.SmoothPlastic },
				CFrame.new(r * 0.22, r * 1.15, 0) * CFrame.Angles(0, 0, math.rad(20)))
		elseif e == "ears" then
			for _, s in { -1, 1 } do
				deco(model, body, { Name = "Ear", Shape = Enum.PartType.Ball, Size = Vector3.new(r * 0.3, r * 0.55, r * 0.2), Color = color, Material = Enum.Material.SmoothPlastic },
					CFrame.new(s * r * 0.45, r * 0.85, 0) * CFrame.Angles(0, 0, -s * math.rad(20)))
			end
		elseif e == "spikes" then
			for i = 0, 5 do
				local a = (i / 6) * math.pi - math.pi / 2
				deco(model, body, { Name = "Spike", Size = Vector3.new(r * 0.18, r * 0.45, r * 0.18), Color = Color3.new(1, 1, 1):Lerp(color, 0.5), Material = Enum.Material.Glass, Transparency = 0.1 },
					CFrame.new(0, math.cos(a) * r * 0.85, math.sin(a) * r * 0.85 + r * 0.1) * CFrame.Angles(a, 0, 0))
			end
		elseif e == "band" then
			deco(model, body, { Name = "Band", Shape = Enum.PartType.Cylinder, Size = Vector3.new(r * 0.25, r * 2.02, r * 2.02), Color = Color3.fromRGB(220, 30, 40), Material = Enum.Material.Fabric },
				CFrame.new(0, r * 0.35, 0) * CFrame.Angles(0, 0, math.pi / 2))
		elseif e == "bow" then
			for _, s in { -1, 1 } do
				deco(model, body, { Name = "Bow", Shape = Enum.PartType.Ball, Size = Vector3.new(r * 0.4, r * 0.3, r * 0.15), Color = Color3.fromRGB(255, 70, 150), Material = Enum.Material.SmoothPlastic },
					CFrame.new(r * 0.35 + s * r * 0.18, r * 0.85, -r * 0.2))
			end
		end
	end
end

local function addAura(body: BasePart, rarity, mut)
	local order = rarity.order
	if order >= 3 then
		local p = Instance.new("ParticleEmitter")
		p.Name = "Aura"
		p.Texture = SPARKLE
		p.Color = ColorSequence.new(rarity.color)
		p.LightEmission = 1
		p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
		p.Lifetime = NumberRange.new(0.8, 1.4)
		p.Rate = 4 + order * 3
		p.Speed = NumberRange.new(1, 3)
		p.SpreadAngle = Vector2.new(180, 180)
		p.Parent = body
	end
	if order >= 5 then
		local light = Instance.new("PointLight")
		light.Color = rarity.color
		light.Range = 8 + order * 2
		light.Brightness = 2
		light.Parent = body
		local h = Instance.new("Highlight")
		h.FillTransparency = 1
		h.OutlineColor = rarity.color
		h.OutlineTransparency = 0.1
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Parent = body.Parent
	end
	if order >= 6 then
		local f = Instance.new("ParticleEmitter")
		f.Name = "Flames"
		f.Texture = FIRE
		f.Color = ColorSequence.new(rarity.color)
		f.LightEmission = 0.8
		f.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, body.Size.X * 0.4), NumberSequenceKeypoint.new(1, 0) })
		f.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
		f.Lifetime = NumberRange.new(0.5, 0.9)
		f.Rate = 18
		f.Speed = NumberRange.new(2, 4)
		f.EmissionDirection = Enum.NormalId.Top
		f.Parent = body
	end
	if rarity.name == "Secret" or rarity.name == "Divine" then
		local s = Instance.new("ParticleEmitter")
		s.Name = "Smoke"
		s.Texture = SMOKE
		s.Color = ColorSequence.new(rarity.color)
		s.Size = NumberSequence.new(body.Size.X * 0.6)
		s.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1) })
		s.Lifetime = NumberRange.new(1, 2)
		s.Rate = 6
		s.Speed = NumberRange.new(0.5, 1)
		s.Parent = body
	end
	if mut then
		local m = Config.MutationByName[mut]
		local p = Instance.new("ParticleEmitter")
		p.Name = "MutationGlitter"
		p.Texture = SPARKLE
		p.Color = ColorSequence.new(m.color)
		p.LightEmission = 1
		p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
		p.Lifetime = NumberRange.new(0.6, 1)
		p.Rate = 20
		p.Speed = NumberRange.new(2, 5)
		p.SpreadAngle = Vector2.new(180, 180)
		p.Parent = body
	end
end

-- Creates a slime model. `stage` is the growth stage (1 for belt slimes), `mut` an optional mutation.
function SlimeModel.Create(slimeId: string, stage: number, mut: string?, stars: number?, traits: { string }?): Model
	local def = Config.SlimeById[slimeId]
	local rarity = Config.RarityByName[def.rarity]
	local starCount: number = stars or 0
	local size = def.size * Config.GrowthSizeMult[stage] * (1 + 0.15 * starCount)
	local mutation = mut and Config.MutationByName[mut]

	local model = Instance.new("Model")
	model.Name = slimeId

	local color = def.color
	local material = if rarity.order >= 6 then Enum.Material.Neon else Enum.Material.SmoothPlastic
	local reflect = 0.15
	if mutation then
		if mut == "Golden" then
			color = color:Lerp(mutation.color, 0.75)
			material = Enum.Material.Metal
			reflect = 0.45
		elseif mut == "Diamond" then
			color = mutation.color
			material = Enum.Material.Glass
			reflect = 0.5
		elseif mut == "Rainbow" then
			material = Enum.Material.Neon
		elseif mut == "Lava" then
			color = color:Lerp(mutation.color, 0.7)
			material = Enum.Material.CrackedLava
		elseif mut == "Candy" then
			color = color:Lerp(mutation.color, 0.6)
			material = Enum.Material.Pebble
			reflect = 0.3
		end
	end

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.one * size
	body.Color = color
	body.Material = material
	body.Transparency = if slimeId == "Ghosty" then 0.45 elseif mut == "Diamond" then 0.25 else 0.05
	body.Reflectance = reflect
	body.Anchored = true
	body.CanCollide = false
	body.Parent = model
	model.PrimaryPart = body

	local r = size / 2
	-- Big cute eyes with shine, and a smile.
	for _, side in { -1, 1 } do
		local eye = deco(model, body, { Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.new(r * 0.32, r * 0.42, r * 0.2), Color = Color3.new(0.05, 0.05, 0.08), Material = Enum.Material.SmoothPlastic },
			CFrame.new(side * r * 0.36, r * 0.15, -r * 0.88))
		deco(model, body, { Name = "EyeShine", Shape = Enum.PartType.Ball, Size = Vector3.one * r * 0.12, Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon },
			CFrame.new(side * r * 0.36 - r * 0.06, r * 0.28, -r * 0.97))
		eye:SetAttribute("Blink", true)
		deco(model, body, { Name = "Blush", Shape = Enum.PartType.Ball, Size = Vector3.new(r * 0.25, r * 0.12, r * 0.08), Color = Color3.fromRGB(255, 120, 150), Material = Enum.Material.SmoothPlastic, Transparency = 0.3 },
			CFrame.new(side * r * 0.62, -r * 0.08, -r * 0.76))
	end
	deco(model, body, { Name = "Mouth", Size = Vector3.new(r * 0.3, r * 0.07, r * 0.06), Color = Color3.new(0.05, 0.05, 0.08), Material = Enum.Material.SmoothPlastic },
		CFrame.new(0, -r * 0.18, -r * 0.97))
	deco(model, body, { Name = "Shine", Shape = Enum.PartType.Ball, Size = Vector3.new(r * 0.45, r * 0.3, r * 0.2), Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, Transparency = 0.35 },
		CFrame.new(-r * 0.4, r * 0.6, -r * 0.55))

	addExtras(model, body, size, def.extra or {}, def.color)
	addAura(body, rarity, mut)

	local gui = makeLabel(body, r + 2.2)
	gui.Rarity.Text = if mut then (mut .. " " .. def.rarity):upper() else def.rarity:upper()
	gui.Rarity.TextColor3 = if mutation then mutation.color else rarity.color
	if rarity.name == "Secret" then
		gui.Rarity.TextColor3 = Color3.new(1, 1, 1)
		gui.Rarity.TextStrokeColor3 = Color3.fromRGB(255, 0, 80)
	end
	local icons = Config.TraitIcons(traits)
	gui.Title.Text = (if icons ~= "" then icons .. " " else "") .. slimeId .. Config.Stars(starCount)
	local traitList: { string } = traits or {}
	for _, t in traitList do
		local tdef = Config.Traits[t]
		if tdef then
			local p = Instance.new("ParticleEmitter")
			p.Name = "Trait" .. t
			p.Texture = SPARKLE
			p.Color = ColorSequence.new(tdef.color)
			p.LightEmission = 1
			p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
			p.Lifetime = NumberRange.new(0.7, 1.1)
			p.Rate = 10
			p.Speed = NumberRange.new(1.5, 3.5)
			p.SpreadAngle = Vector2.new(180, 180)
			p.Parent = body
		end
	end
	if starCount > 0 then
		gui.Title.TextColor3 = Color3.fromRGB(255, 225, 90)
		-- Orbiting star sparkles for merged slimes.
		local p = Instance.new("ParticleEmitter")
		p.Name = "StarSparkle"
		p.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		p.Color = ColorSequence.new(Color3.fromRGB(255, 225, 90))
		p.LightEmission = 1
		p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5 + starCount * 0.3), NumberSequenceKeypoint.new(1, 0) })
		p.Lifetime = NumberRange.new(0.8, 1.2)
		p.Rate = 6 * starCount
		p.Speed = NumberRange.new(2, 4)
		p.SpreadAngle = Vector2.new(180, 180)
		p.Parent = body
		model:SetAttribute("Stars", starCount)
	end
	gui.Info.Text = Util.Money(def.income * Config.MutationMult(mut) * Config.StarMult(starCount) * Config.TraitMult(traits)) .. "/s"

	model:SetAttribute("SlimeId", slimeId)
	model:SetAttribute("Rarity", def.rarity)
	model:SetAttribute("Size", size)
	if mut then
		model:SetAttribute("Mutation", mut)
		if mut == "Rainbow" then
			CollectionService:AddTag(body, "Rainbow")
		end
	end
	if def.rarity == "Secret" or slimeId == "Glitch" then
		CollectionService:AddTag(body, "Rainbow")
	end
	return model
end

return SlimeModel
