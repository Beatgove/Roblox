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

-- A decoration part at a world CFrame, welded to `attach` (a wing root, a ring...).
local function decoAt(model: Model, attach: BasePart, props, cf: CFrame): Part
	return deco(model, attach, props, attach.CFrame:ToObjectSpace(cf))
end

-- An invisible hinge welded to the body with a Weld, so the client can swing it by changing C0
-- (wings flapping, rings orbiting). Parts welded to the hinge move with it.
local function hinge(model: Model, body: BasePart, name: string, offset: CFrame, tag: string): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = Vector3.one * 0.2
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CFrame = body.CFrame * offset
	p.Parent = model
	local w = Instance.new("Weld")
	w.Name = "Hinge"
	w.Part0 = body
	w.Part1 = p
	w.C0 = offset
	w.Parent = p
	CollectionService:AddTag(p, tag)
	return p
end

-- Feathered wings: long primaries fanning out from a shoulder, a row of soft coverts on top.
-- `tip` colours the feather ends; fire wings get flames on top.
local function featherWings(model: Model, body: BasePart, r: number, base: Color3, tip: Color3, fire: boolean)
	for _, s in { -1, 1 } do
		local root = hinge(model, body, "WingRoot", CFrame.new(s * r * 0.62, r * 0.3, r * 0.35) * CFrame.Angles(0, s * math.rad(-25), 0), "Flap")
		root:SetAttribute("Side", s)
		local rc = root.CFrame
		for i = 0, 5 do
			local fan = math.rad(48 - i * 19)
			local len = r * (1.9 - i * 0.15)
			local cf = rc * CFrame.Angles(0, 0, s * fan) * CFrame.new(s * len * 0.5, 0, i * r * 0.015)
			decoAt(model, root, { Name = "Feather", Shape = Enum.PartType.Ball, Size = Vector3.new(len, r * 0.3, r * 0.07), Color = base:Lerp(tip, 0.25 + i * 0.08), Material = if fire then Enum.Material.Neon else Enum.Material.SmoothPlastic }, cf)
			decoAt(model, root, { Name = "FeatherTip", Shape = Enum.PartType.Ball, Size = Vector3.new(len * 0.35, r * 0.22, r * 0.08), Color = tip, Material = Enum.Material.Neon, Transparency = 0.1 },
				cf * CFrame.new(s * len * 0.36, 0, 0.01))
		end
		for i = 0, 3 do
			local fan = math.rad(40 - i * 22)
			local len = r * 0.85
			decoAt(model, root, { Name = "Covert", Shape = Enum.PartType.Ball, Size = Vector3.new(len, r * 0.34, r * 0.1), Color = base:Lerp(Color3.new(1, 1, 1), 0.4), Material = Enum.Material.Neon, Transparency = 0.15 },
				rc * CFrame.Angles(0, 0, s * fan) * CFrame.new(s * len * 0.45, 0, -r * 0.05))
		end
		if fire then
			local f = Instance.new("ParticleEmitter")
			f.Name = "WingFire"
			f.Texture = FIRE
			f.Color = ColorSequence.new(Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 60, 20))
			f.LightEmission = 0.9
			f.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, r * 0.7), NumberSequenceKeypoint.new(1, 0) })
			f.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
			f.Lifetime = NumberRange.new(0.4, 0.7)
			f.Rate = 25
			f.Speed = NumberRange.new(1, 3)
			f.EmissionDirection = Enum.NormalId.Top
			f.Parent = root:FindFirstChild("Feather") or root
		end
	end
end

-- Leathery wings: an arm bone along the top edge, three scalloped membrane lobes hanging from it
-- with a glowing rim behind each, and a claw at the tip. Demons, dragons and bats share it.
local function membraneWings(model: Model, body: BasePart, r: number, scale: number, bone: Color3, skin: Color3, rim: Color3)
	local arm = r * 1.9 * scale
	local up = math.rad(34)
	for _, s in { -1, 1 } do
		local root = hinge(model, body, "WingRoot", CFrame.new(s * r * 0.6, r * 0.45, r * 0.4) * CFrame.Angles(0, s * math.rad(-25), 0), "Flap")
		root:SetAttribute("Side", s)
		local rc = root.CFrame
		-- x runs out from the body (mirrored per side), y up, z back.
		local function at(x: number, y: number, z: number, rot: number): CFrame
			return rc * CFrame.new(s * x, y, z) * CFrame.Angles(0, 0, s * rot)
		end
		local cu, su = math.cos(up), math.sin(up)
		decoAt(model, root, { Name = "WingBone", Size = Vector3.new(arm, r * 0.13, r * 0.13), Color = bone, Material = Enum.Material.SmoothPlastic },
			at(cu * arm * 0.5, su * arm * 0.5, 0, up))
		decoAt(model, root, { Name = "Claw", Size = Vector3.new(r * 0.1, r * 0.34, r * 0.1), Color = rim, Material = Enum.Material.Neon },
			at(cu * arm + r * 0.04, su * arm + r * 0.14, 0, math.rad(-20)))
		for k = 0, 2 do
			local t = 0.32 + k * 0.3
			local w = arm * (0.5 - k * 0.06)
			local h = arm * (0.85 - k * 0.15)
			local x, y = cu * arm * t, su * arm * t - h * 0.42
			local tilt = math.rad(8 + k * 10)
			decoAt(model, root, { Name = "Membrane", Shape = Enum.PartType.Ball, Size = Vector3.new(w, h, r * 0.05), Color = skin, Material = Enum.Material.SmoothPlastic },
				at(x, y, k * r * 0.03, tilt))
			decoAt(model, root, { Name = "WingRim", Shape = Enum.PartType.Ball, Size = Vector3.new(w * 1.1, h * 1.06, r * 0.04), Color = rim, Material = Enum.Material.Neon, Transparency = 0.15 },
				at(x, y - h * 0.02, k * r * 0.03 + r * 0.05, tilt))
			-- A finger bone down the middle of each lobe.
			decoAt(model, root, { Name = "WingFinger", Size = Vector3.new(r * 0.06, h * 0.9, r * 0.06), Color = bone, Material = Enum.Material.SmoothPlastic },
				at(x, y + h * 0.02, k * r * 0.03 - r * 0.03, tilt))
		end
	end
end

local function makeLabel(parent: BasePart, height: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(200, 66)
	gui.StudsOffset = Vector3.new(0, height, 0)
	gui.MaxDistance = 45
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

local function addExtras(model: Model, body: BasePart, size: number, extras: { string }, color: Color3, auraColor: Color3?)
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
		elseif e == "wings" or e == "angelwings" then
			featherWings(model, body, r, Color3.fromRGB(255, 255, 255), auraColor or Color3.fromRGB(255, 225, 120), false)
		elseif e == "firewings" then
			featherWings(model, body, r, Color3.fromRGB(255, 200, 70), Color3.fromRGB(255, 70, 20), true)
		elseif e == "demonwings" then
			membraneWings(model, body, r, 1.15, Color3.fromRGB(25, 10, 25), Color3.fromRGB(70, 10, 30), auraColor or Color3.fromRGB(255, 30, 60))
		elseif e == "dragonwings" then
			membraneWings(model, body, r, 1.1, Color3.new(0, 0, 0):Lerp(color, 0.45), color:Lerp(Color3.new(1, 1, 0.6), 0.15), auraColor or Color3.fromRGB(180, 255, 80))
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
		elseif e == "witchhat" then
			-- A floppy pointed hat: a wide brim, a cone of shrinking rings bent to one side, a band.
			local black = Color3.fromRGB(35, 25, 45)
			deco(model, body, { Name = "HatBrim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(r * 0.08, r * 1.9, r * 1.9), Color = black, Material = Enum.Material.Fabric },
				CFrame.new(0, r * 0.88, 0) * CFrame.Angles(0, 0, math.pi / 2))
			for k = 0, 5 do
				local t = k / 6
				local w = r * (1.05 - t * 0.85)
				deco(model, body, { Name = "Hat", Shape = Enum.PartType.Cylinder, Size = Vector3.new(r * 0.24, w, w), Color = black, Material = Enum.Material.Fabric },
					CFrame.new(t * t * r * 0.45, r * (1.0 + t * 1.15), 0) * CFrame.Angles(0, 0, math.pi / 2 - t * 0.5))
			end
			deco(model, body, { Name = "HatBand", Shape = Enum.PartType.Cylinder, Size = Vector3.new(r * 0.12, r * 1.08, r * 1.08), Color = Color3.fromRGB(150, 60, 220), Material = Enum.Material.Neon },
				CFrame.new(0, r * 1.02, 0) * CFrame.Angles(0, 0, math.pi / 2))
			deco(model, body, { Name = "HatBuckle", Size = Vector3.new(r * 0.22, r * 0.18, r * 0.05), Color = Color3.fromRGB(255, 210, 60), Material = Enum.Material.Metal },
				CFrame.new(0, r * 1.02, -r * 0.55))
		elseif e == "batwings" then
			membraneWings(model, body, r, 0.9, Color3.fromRGB(35, 20, 45), Color3.fromRGB(60, 40, 75), auraColor or Color3.fromRGB(170, 90, 255))
		elseif e == "fangs" then
			for _, s in { -1, 1 } do
				deco(model, body, { Name = "Fang", Size = Vector3.new(r * 0.08, r * 0.16, r * 0.06), Color = Color3.new(1, 1, 1), Material = Enum.Material.SmoothPlastic },
					CFrame.new(s * r * 0.08, -r * 0.25, -r * 0.99))
			end
		elseif e == "jackface" then
			-- Pumpkin ribs and a glowing grin.
			local rib = Color3.new(0, 0, 0):Lerp(color, 0.75)
			for _, s in { -0.55, 0, 0.55 } do
				deco(model, body, { Name = "Rib", Shape = Enum.PartType.Ball, Size = Vector3.new(r * 0.12, r * 1.9, r * 1.2), Color = rib, Material = Enum.Material.SmoothPlastic, Transparency = 0.2 },
					CFrame.new(s * r * 0.95, 0, 0) * CFrame.Angles(0, s * 1.1, 0))
			end
			for k = -2, 2 do
				local grin = deco(model, body, { Name = "Grin", Size = Vector3.new(r * 0.13, r * (if k % 2 == 0 then 0.14 else 0.22), r * 0.05), Color = Color3.fromRGB(255, 220, 80), Material = Enum.Material.Neon },
					CFrame.new(k * r * 0.12, -r * 0.3 + math.abs(k) * r * 0.05, -r * 0.93))
				if k == 0 then
					local glow = Instance.new("PointLight")
					glow.Color = Color3.fromRGB(255, 170, 60)
					glow.Range = r * 4
					glow.Brightness = 1.2
					glow.Parent = grin
				end
			end
		end
	end
end

local function addAura(model: Model, body: BasePart, rarity, mut, auraColor: Color3?)
	local order = rarity.order
	-- Codes-only slimes look like Legendaries; everything else climbs a tier at a time.
	local tier = if rarity.name == "Exclusive" then 5 else order
	local col = auraColor or rarity.color
	local r = body.Size.X / 2
	if rarity.name == "Secret" and not auraColor then
		col = Color3.fromRGB(255, 60, 200)
	end
	-- Epic and up: a glowing ring on the ground that breathes in and out.
	if tier >= 4 then
		local ring = deco(model, body, { Name = "AuraRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.05, r * 3, r * 3), Color = col, Material = Enum.Material.Neon, Transparency = 0.55 },
			CFrame.new(0, -r * 0.92, 0) * CFrame.Angles(0, 0, math.pi / 2))
		CollectionService:AddTag(ring, "AuraFade")
	end
	-- Legendary and up: a shimmering force-field shell around the whole slime.
	if tier >= 5 then
		local shell = deco(model, body, { Name = "AuraShell", Shape = Enum.PartType.Ball, Size = Vector3.one * r * 2.5, Color = col, Material = Enum.Material.ForceField, Transparency = 0 },
			CFrame.new(0, r * 0.1, 0))
		CollectionService:AddTag(shell, "AuraPulse")
		if rarity.name == "Secret" then
			CollectionService:AddTag(shell, "Rainbow")
		end
	end
	-- Mythic and up: glowing orbs circling the slime; Divine and Secret get a second, tilted ring.
	if tier >= 6 then
		for k = 1, if tier >= 7 then 2 else 1 do
			local tilt = if k == 1 then CFrame.Angles(math.rad(12), 0, 0) else CFrame.Angles(math.rad(-25), 0, math.rad(20))
			local orbit = hinge(model, body, "Orbit", CFrame.new(0, r * 0.1, 0) * tilt, "Orbit")
			orbit:SetAttribute("Speed", if k == 1 then 1.2 else -0.9)
			local n = if k == 1 then 3 else 4
			for i = 1, n do
				local a = i / n * math.pi * 2
				decoAt(model, orbit, { Name = "Orb", Shape = Enum.PartType.Ball, Size = Vector3.one * r * 0.22, Color = col:Lerp(Color3.new(1, 1, 1), 0.35), Material = Enum.Material.Neon },
					orbit.CFrame * CFrame.new(math.cos(a) * r * 1.55, 0, math.sin(a) * r * 1.55))
			end
		end
	end
	-- Divine and up: light rising from the ground ring.
	if tier >= 7 then
		local rise = Instance.new("ParticleEmitter")
		rise.Name = "AuraRise"
		rise.Texture = SPARKLE
		rise.Color = ColorSequence.new(col)
		rise.LightEmission = 1
		rise.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
		rise.Lifetime = NumberRange.new(1, 1.6)
		rise.Rate = 20
		rise.Speed = NumberRange.new(3, 6)
		rise.EmissionDirection = Enum.NormalId.Top
		rise.SpreadAngle = Vector2.new(15, 15)
		rise.Parent = body
	end
	if order >= 3 then
		local p = Instance.new("ParticleEmitter")
		p.Name = "Aura"
		p.Texture = SPARKLE
		p.Color = ColorSequence.new(col)
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
		light.Color = col
		light.Range = 8 + order * 2
		light.Brightness = 2
		light.Parent = body
		local h = Instance.new("Highlight")
		h.FillTransparency = 1
		h.OutlineColor = col
		h.OutlineTransparency = 0.1
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Parent = body.Parent
	end
	if order >= 6 then
		local f = Instance.new("ParticleEmitter")
		f.Name = "Flames"
		f.Texture = FIRE
		f.Color = ColorSequence.new(col)
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
		s.Color = ColorSequence.new(col)
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
function SlimeModel.Create(slimeId: string, stage: number, mut: string?, stars: number?, traits: { string }?, diet: string?): Model
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
	-- An open happy mouth: a dark oval with a tongue, its top half hidden under a body-coloured
	-- lip so it reads as a "D" smile. Pumpkins have their own carved grin instead.
	if not table.find(def.extra or {}, "jackface") then
		local function onSurface(x: number, y: number, out: number): CFrame
			local n = Vector3.new(x, y, -math.sqrt(math.max(0, 1 - x * x - y * y))).Unit
			local p = n * r * (1 + out)
			return CFrame.lookAt(p, p + n)
		end
		deco(model, body, { Name = "Mouth", Shape = Enum.PartType.Ball, Size = Vector3.new(r * 0.38, r * 0.28, r * 0.06), Color = Color3.fromRGB(70, 15, 35), Material = Enum.Material.SmoothPlastic },
			onSurface(0, -0.24, -0.005))
		deco(model, body, { Name = "Tongue", Shape = Enum.PartType.Ball, Size = Vector3.new(r * 0.2, r * 0.1, r * 0.05), Color = Color3.fromRGB(255, 110, 140), Material = Enum.Material.SmoothPlastic },
			onSurface(0, -0.31, 0.005))
		deco(model, body, { Name = "Lip", Shape = Enum.PartType.Ball, Size = Vector3.new(r * 0.46, r * 0.18, r * 0.05), Color = color, Material = material, Reflectance = reflect },
			onSurface(0, -0.15, 0.012))
	end
	deco(model, body, { Name = "Shine", Shape = Enum.PartType.Ball, Size = Vector3.new(r * 0.45, r * 0.3, r * 0.2), Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, Transparency = 0.35 },
		CFrame.new(-r * 0.4, r * 0.6, -r * 0.55))

	addExtras(model, body, size, def.extra or {}, def.color, def.aura)
	addAura(model, body, rarity, mut, def.aura)

	local gui = makeLabel(body, r + 2.2)
	gui.Rarity.Text = if mut then (mut .. " " .. def.rarity):upper() else def.rarity:upper()
	gui.Rarity.TextColor3 = if mutation then mutation.color else rarity.color
	if rarity.name == "Secret" then
		gui.Rarity.TextColor3 = Color3.new(1, 1, 1)
		gui.Rarity.TextStrokeColor3 = Color3.fromRGB(255, 0, 80)
	end
	local icons = Config.TraitIcons(traits)
	gui.Title.Text = (if icons ~= "" then icons .. " " else "") .. Config.SlimeName(slimeId) .. Config.Stars(starCount)
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
	local lip = model:FindFirstChild("Lip")
	if lip and CollectionService:HasTag(body, "Rainbow") then
		CollectionService:AddTag(lip, "Rainbow")
	end
	local snack = diet and Config.Snacks[diet]
	if snack then
		SlimeModel.ApplyDiet(model, body, diet :: string, size)
		gui.Title.Text = (if icons ~= "" then icons .. " " else "") .. snack.diet .. " " .. Config.SlimeName(slimeId) .. Config.Stars(starCount)
		gui.Info.Text = Util.Money(def.income * Config.MutationMult(mut) * Config.StarMult(starCount) * Config.TraitMult(traits) * snack.mult) .. "/s"
	end
	return model
end

-- Diet forms: each snack gives the slime a new look on top of its mutation.
function SlimeModel.ApplyDiet(model: Model, body: BasePart, diet: string, size: number)
	local snack = Config.Snacks[diet]
	local r = size / 2
	model:SetAttribute("Diet", diet)
	if not model:GetAttribute("Mutation") then
		body.Color = body.Color:Lerp(snack.color, 0.5)
		local lip = model:FindFirstChild("Lip") :: BasePart?
		if lip then
			lip.Color = body.Color
		end
	end
	local function emitter(props)
		local p = Instance.new("ParticleEmitter")
		p.Texture = SPARKLE
		p.LightEmission = 1
		p.SpreadAngle = Vector2.new(180, 180)
		for k, v in props do
			(p :: any)[k] = v
		end
		p.Parent = body
		return p
	end
	if diet == "Pepper" then
		local fire = Instance.new("Fire")
		fire.Heat = 4
		fire.Size = math.max(2, r * 1.4)
		fire.Color = Color3.fromRGB(255, 120, 30)
		fire.SecondaryColor = Color3.fromRGB(255, 40, 20)
		fire.Parent = body
	elseif diet == "Berry" then
		-- Little berry bubbles drifting up.
		emitter({ Name = "DietBubbles", Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(snack.color), LightEmission = 0.4,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0.1) }), Lifetime = NumberRange.new(1, 1.6),
			Rate = 6, Speed = NumberRange.new(2, 3), Acceleration = Vector3.new(0, 3, 0), SpreadAngle = Vector2.new(30, 30) })
		deco(model, body, { Name = "BerryLeaf", Size = Vector3.new(r * 0.5, r * 0.08, r * 0.3), Color = Color3.fromRGB(80, 200, 90), Material = Enum.Material.SmoothPlastic },
			CFrame.new(0, r * 0.98, 0) * CFrame.Angles(0, 0, math.rad(20)))
	elseif diet == "Honey" then
		body.Material = Enum.Material.Glass
		body.Transparency = math.max(body.Transparency, 0.15)
		for i = 1, 3 do
			local a = (i / 3) * math.pi * 2
			deco(model, body, { Name = "HoneyDrip", Shape = Enum.PartType.Ball, Size = Vector3.new(r * 0.22, r * 0.4, r * 0.22), Color = snack.color, Material = Enum.Material.Glass, Transparency = 0.2 },
				CFrame.new(math.cos(a) * r * 0.75, -r * 0.45, math.sin(a) * r * 0.75))
		end
	elseif diet == "Crystal" then
		body.Reflectance = 0.4
		for i = 1, 4 do
			local a = (i / 4) * math.pi * 2 + 0.4
			deco(model, body, { Name = "Crystal", Size = Vector3.new(r * 0.25, r * 0.6, r * 0.25), Color = snack.color, Material = Enum.Material.Glass, Transparency = 0.15, Reflectance = 0.3 },
				CFrame.new(math.cos(a) * r * 0.55, r * 0.75, math.sin(a) * r * 0.55) * CFrame.Angles(math.sin(a) * 0.5, 0, -math.cos(a) * 0.5))
		end
		emitter({ Name = "DietGlint", Color = ColorSequence.new(snack.color), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) }),
			Lifetime = NumberRange.new(0.5, 0.8), Rate = 8, Speed = NumberRange.new(0.5, 1.5) })
	elseif diet == "Glowcap" then
		local light = Instance.new("PointLight")
		light.Color = snack.color
		light.Range = math.max(10, size * 2)
		light.Brightness = 1.6
		light.Parent = body
		for i = 1, 5 do
			local a = (i / 5) * math.pi * 2
			deco(model, body, { Name = "GlowSpot", Shape = Enum.PartType.Ball, Size = Vector3.one * r * 0.2, Color = snack.color, Material = Enum.Material.Neon },
				CFrame.new(math.cos(a) * r * 0.8, r * 0.35, math.sin(a) * r * 0.8))
		end
		deco(model, body, { Name = "Cap", Shape = Enum.PartType.Ball, Size = Vector3.new(r * 0.9, r * 0.35, r * 0.9), Color = Color3.fromRGB(230, 60, 80), Material = Enum.Material.SmoothPlastic },
			CFrame.new(0, r * 0.95, 0))
	end
end

return SlimeModel
