-- Bases get prettier with every rebirth: new materials, flower boxes, lanterns, a gate,
-- crystals, gold, banners, sparkles and finally a floating crown. Each tier adds to the last,
-- so you can tell how far someone has come just by looking at their base.

local CollectionService = game:GetService("CollectionService")

local BaseDecor = {}

local HALF = 34 -- MapBuilder.PlotSize / 2
local H = 18 -- MapBuilder.WallHeight
local DOOR = 10 -- half of MapBuilder.DoorWidth

local Config = require(game.ReplicatedStorage.Shared.Config)

BaseDecor.Tiers = Config.BaseTiers

local function part(parent: Instance, props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

-- Remember each base's original look so a released base can be reset.
local function remember(model: Model)
	for _, d in model:GetChildren() do
		if d:IsA("BasePart") and (d.Name == "Floor" or d.Name == "Wall" or d.Name == "Trim") and d:GetAttribute("OrigColor") == nil then
			d:SetAttribute("OrigColor", d.Color)
			d:SetAttribute("OrigMaterial", d.Material.Name)
		end
	end
end

local function restyle(model: Model, name: string, color: Color3?, material: Enum.Material?)
	for _, d in model:GetChildren() do
		if d:IsA("BasePart") and d.Name == name then
			d.Color = color or d:GetAttribute("OrigColor") or d.Color
			d.Material = material or (Enum.Material :: any)[d:GetAttribute("OrigMaterial") or "SmoothPlastic"]
			CollectionService:RemoveTag(d, "Rainbow")
		end
	end
end

-- Restyles parts in the starting look (towers, roofs...), remembering their original style.
local function restyleStart(model: Model, name: string, color: Color3?, material: Enum.Material?)
	local start = model:FindFirstChild("StartDecor")
	if not start then
		return
	end
	for _, d in start:GetChildren() do
		if d:IsA("BasePart") and d.Name == name then
			if d:GetAttribute("OrigColor") == nil then
				d:SetAttribute("OrigColor", d.Color)
				d:SetAttribute("OrigMaterial", d.Material.Name)
			end
			d.Color = color or d:GetAttribute("OrigColor")
			d.Material = material or (Enum.Material :: any)[d:GetAttribute("OrigMaterial")]
		end
	end
end

-- Base skin (Config.BaseSkins): recolours the castle walls, posts, battlements and towers.
local function applySkin(model: Model, key: string?)
	local skin
	for _, s in Config.BaseSkins do
		if s.key == key then
			skin = s
		end
	end
	if not skin or not skin.wall then
		return
	end
	local wallMat = (Enum.Material :: any)[skin.wallMat]
	local trimMat = (Enum.Material :: any)[skin.trimMat]
	restyle(model, "Wall", skin.wall, wallMat)
	for _, name in { "WallPost", "Parapet", "Skirting" } do
		restyleStart(model, name, skin.trim, trimMat)
	end
end

local function applyTiers(model: Model, cf: CFrame, rebirths: number)
	remember(model)
	local old = model:FindFirstChild("Decor")
	if old then
		old:Destroy()
	end
	for _, name in { "WallPost", "Parapet", "Skirting" } do
		restyleStart(model, name)
	end
	restyle(model, "Floor")
	restyle(model, "Wall")
	-- 20: golden pen pedestals (reset to marble below that, so a lower rebirth looks right)
	local pens = model:FindFirstChild("Pens")
	for _, pad in (if pens then pens:GetChildren() else {}) do
		local pedestal = pad:FindFirstChild("Pedestal") :: BasePart?
		if pedestal then
			pedestal.Color = if rebirths >= 20 then Color3.fromRGB(240, 195, 70) else Color3.fromRGB(245, 240, 250)
			pedestal.Material = if rebirths >= 20 then Enum.Material.Metal else Enum.Material.Marble
		end
	end

	restyle(model, "Trim")
	if rebirths <= 0 then
		return
	end
	local themeAttr = model:GetAttribute("Theme")
	local theme: Color3 = if typeof(themeAttr) == "Color3" then themeAttr else Color3.fromRGB(255, 120, 200)
	local light = theme:Lerp(Color3.new(1, 1, 1), 0.55)
	local folder = Instance.new("Folder")
	folder.Name = "Decor"
	folder.Parent = model
	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end
	local walls = {
		{ from = Vector3.new(-HALF, 0, -HALF), to = Vector3.new(-HALF, 0, HALF) },
		{ from = Vector3.new(HALF, 0, -HALF), to = Vector3.new(HALF, 0, HALF) },
		{ from = Vector3.new(-HALF, 0, HALF), to = Vector3.new(HALF, 0, HALF) },
	}
	local capWalls = table.clone(walls)
	table.insert(capWalls, { from = Vector3.new(-HALF, 0, -HALF), to = Vector3.new(-DOOR, 0, -HALF) })
	table.insert(capWalls, { from = Vector3.new(DOOR, 0, -HALF), to = Vector3.new(HALF, 0, -HALF) })

	-- 1: stone floor and white caps on the walls
	restyle(model, "Floor", Color3.fromRGB(200, 195, 205), Enum.Material.Slate)
	for _, w in capWalls do
		local mid = (w.from + w.to) / 2
		local len = (w.to - w.from).Magnitude + 1.4
		local alongX = math.abs(w.to.X - w.from.X) > 0.1
		part(folder, { Name = "Cap", Size = if alongX then Vector3.new(len, 0.4, 1.4) else Vector3.new(1.4, 0.4, len), CFrame = at(mid.X, H + 0.2, mid.Z), Color = Color3.fromRGB(245, 240, 250), Material = Enum.Material.SmoothPlastic })
	end

	-- 2: flower boxes along the inside of the walls
	if rebirths >= 2 then
		local flowerColors = { Color3.fromRGB(255, 90, 140), Color3.fromRGB(255, 220, 80), Color3.fromRGB(180, 120, 255), light }
		local n = 0
		for _, w in walls do
			local len = (w.to - w.from).Magnitude
			for d = 6, len - 6, 10 do
				n += 1
				local p = w.from + (w.to - w.from).Unit * d
				-- Nudge inward, off the wall face.
				p -= Vector3.new(math.sign(p.X) * (if math.abs(p.X) >= HALF - 0.1 then 1.6 else 0), 0, math.sign(p.Z) * (if math.abs(p.Z) >= HALF - 0.1 then 1.6 else 0))
				part(folder, { Name = "FlowerBox", Size = Vector3.new(2.6, 0.8, 2.6), CFrame = at(p.X, 0.9, p.Z), Color = Color3.fromRGB(120, 80, 50), Material = Enum.Material.WoodPlanks })
				for k = 1, 3 do
					local off = Vector3.new(math.cos(k * 2.1) * 0.7, 0, math.sin(k * 2.1) * 0.7)
					part(folder, { Name = "Flower", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, CFrame = at(p.X + off.X, 1.7, p.Z + off.Z), Color = flowerColors[(n + k) % #flowerColors + 1], Material = Enum.Material.SmoothPlastic })
				end
				part(folder, { Name = "Leaves", Size = Vector3.new(2.2, 0.3, 2.2), CFrame = at(p.X, 1.35, p.Z), Color = Color3.fromRGB(70, 170, 70), Material = Enum.Material.Grass })
			end
		end
	end

	-- 3: lanterns on the front corners and halfway down the sides (the back corners have towers)
	if rebirths >= 3 then
		for _, c in { Vector3.new(-HALF, 0, -HALF), Vector3.new(HALF, 0, -HALF), Vector3.new(-HALF, 0, 0), Vector3.new(HALF, 0, 0) } do
			local lamp = part(folder, { Name = "Lantern", Size = Vector3.new(1.8, 2, 1.8), CFrame = at(c.X, H + 3.4, c.Z), Color = Color3.fromRGB(255, 220, 140), Material = Enum.Material.Neon })
			CollectionService:AddTag(lamp, "Pulse")
			local pl = Instance.new("PointLight")
			pl.Color = Color3.fromRGB(255, 210, 140)
			pl.Range = 18
			pl.Brightness = 1.5
			pl.Parent = lamp
			part(folder, { Name = "LanternRoof", Size = Vector3.new(2.4, 0.4, 2.4), CFrame = at(c.X, H + 4.6, c.Z), Color = Color3.fromRGB(60, 45, 70), Material = Enum.Material.Metal })
		end
	end

	-- 4: a grand entrance gate on the open side, with your rebirth count
	if rebirths >= 4 then
		for _, x in { -DOOR - 1.1, DOOR + 1.1 } do
			part(folder, { Name = "GatePillar", Size = Vector3.new(2.6, 13.2, 2.8), CFrame = at(x, 6.6, -HALF), Color = Color3.fromRGB(240, 235, 245), Material = Enum.Material.Marble })
			part(folder, { Name = "GateOrb", Shape = Enum.PartType.Ball, Size = Vector3.one * 2.4, CFrame = at(x, 14.2, -HALF), Color = theme, Material = Enum.Material.Neon })
		end
		local beam = part(folder, { Name = "GateBeam", Size = Vector3.new(DOOR * 2 + 5, 2, 1.2), CFrame = at(0, 13, -HALF - 1.2), Color = theme, Material = Enum.Material.SmoothPlastic })
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Back -- faces outward, toward the belt
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.Parent = beam
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0
		label.Text = "★ REBIRTH " .. rebirths .. " ★"
		label.Parent = gui
	end

	-- 5: crystal clusters in the back corners
	if rebirths >= 5 then
		for _, c in { Vector3.new(-HALF + 3, 0, HALF - 3), Vector3.new(HALF - 3, 0, HALF - 3) } do
			for k = 1, 4 do
				local h = 3 + k * 1.3
				local off = Vector3.new(math.cos(k * 1.7) * 1.2, 0, math.sin(k * 1.7) * 1.2)
				local crystal = part(folder, { Name = "Crystal", Size = Vector3.new(1.2, h, 1.2), CFrame = at(c.X + off.X, 0.5 + h / 2, c.Z + off.Z) * CFrame.Angles(math.rad(k * 7 - 14), k, math.rad(10 - k * 5)), Color = light, Material = Enum.Material.Glass, Transparency = 0.2 })
				if k == 4 then
					local pl = Instance.new("PointLight")
					pl.Color = theme
					pl.Range = 14
					pl.Brightness = 0.6
					pl.Shadows = true
					pl.Parent = crystal
				end
			end
		end
	end

	-- 6: marble walls and floor with gold trim
	if rebirths >= 6 then
		restyle(model, "Floor", Color3.fromRGB(198, 192, 202), Enum.Material.Marble)
		restyle(model, "Wall", Color3.fromRGB(226, 222, 230), Enum.Material.Marble)
		restyle(model, "Trim", Color3.fromRGB(255, 205, 60), Enum.Material.Metal)
		for _, cap in folder:GetChildren() do
			if cap.Name == "Cap" then
				(cap :: BasePart).Color = Color3.fromRGB(255, 205, 60);
				(cap :: BasePart).Material = Enum.Material.Metal
			end
		end
	end

	-- 7: fireflies drifting over the pens
	if rebirths >= 7 then
		local zone = part(folder, { Name = "Fireflies", Size = Vector3.new(56, 1, 56), CFrame = at(0, 8, 0), Transparency = 1 })
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(Color3.fromRGB(255, 240, 140), Color3.fromRGB(200, 255, 140))
		e.LightEmission = 1
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.45), NumberSequenceKeypoint.new(1, 0) })
		e.Lifetime = NumberRange.new(3, 5)
		e.Rate = 5
		e.Speed = NumberRange.new(0.5, 1.5)
		e.SpreadAngle = Vector2.new(180, 180)
		e.RotSpeed = NumberRange.new(-30, 30)
		e.Parent = zone
	end

	-- 8: royal banners on the back wall
	if rebirths >= 8 then
		for _, x in { -20, -10, 10, 20 } do
			part(folder, { Name = "BannerPole", Size = Vector3.new(0.5, 14, 0.5), CFrame = at(x, 7, HALF + 0.6), Color = Color3.fromRGB(255, 205, 60), Material = Enum.Material.Metal })
			local banner = part(folder, { Name = "Banner", Size = Vector3.new(4, 6, 0.2), CFrame = at(x + 2.2, 10, HALF + 0.6), Color = theme, Material = Enum.Material.Fabric })
			part(folder, { Name = "BannerStripe", Size = Vector3.new(4.02, 0.6, 0.22), CFrame = banner.CFrame * CFrame.new(0, -2.2, 0), Color = Color3.fromRGB(255, 205, 60), Material = Enum.Material.Neon })
		end
	end

	-- 9: a string of party lights across the entrance
	if rebirths >= 9 then
		local colors = { Color3.fromRGB(255, 90, 120), Color3.fromRGB(255, 220, 80), Color3.fromRGB(100, 220, 255), Color3.fromRGB(150, 255, 120), light }
		for k = 0, 12 do
			local x = -HALF + k * (HALF * 2 / 12)
			local sag = -2.2 * (1 - ((x / HALF) ^ 2))
			local bulb = part(folder, { Name = "PartyBulb", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, CFrame = at(x, H + 2 + sag, -HALF - 2), Color = colors[k % #colors + 1], Material = Enum.Material.Neon })
			if k % 3 == 0 then
				CollectionService:AddTag(bulb, "Pulse")
			end
		end
		part(folder, { Name = "PartyWire", Size = Vector3.new(HALF * 2, 0.1, 0.1), CFrame = at(0, H + 2.4, -HALF - 2), Color = Color3.fromRGB(40, 40, 50), Material = Enum.Material.SmoothPlastic })
	end

	-- 10: sparkles drifting up from the floor edges
	if rebirths >= 10 then
		for _, w in walls do
			local mid = (w.from + w.to) / 2
			local alongX = math.abs(w.to.X - w.from.X) > 0.1
			local emitterPart = part(folder, { Name = "Aura", Size = if alongX then Vector3.new(HALF * 2, 0.2, 1) else Vector3.new(1, 0.2, HALF * 2), CFrame = at(mid.X, 0.6, mid.Z), Transparency = 1 })
			local e = Instance.new("ParticleEmitter")
			e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			e.Color = ColorSequence.new(light, Color3.fromRGB(255, 230, 120))
			e.LightEmission = 1
			e.Size = NumberSequence.new(0.6, 0)
			e.Lifetime = NumberRange.new(2, 3)
			e.Rate = 6
			e.Speed = NumberRange.new(2, 4)
			e.EmissionDirection = Enum.NormalId.Top
			e.Parent = emitterPart
		end
	end

	-- 12: a golden slime statue at the end of the red carpet
	if rebirths >= 12 then
		part(folder, { Name = "Plinth", Size = Vector3.new(6, 1.2, 4), CFrame = at(0, 1.1, HALF - 3), Color = Color3.fromRGB(245, 240, 250), Material = Enum.Material.Marble })
		local s = part(folder, { Name = "StatueSlime", Shape = Enum.PartType.Ball, Size = Vector3.one * 5, CFrame = at(0, 4.2, HALF - 3), Color = Color3.fromRGB(255, 205, 60), Material = Enum.Material.Metal, Reflectance = 0.35 })
		for _, side in { -1, 1 } do
			part(folder, { Name = "StatueEye", Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 1.1, 0.4), CFrame = s.CFrame * CFrame.new(side * 0.9, 0.4, -2.3), Color = Color3.fromRGB(30, 25, 20), Material = Enum.Material.SmoothPlastic })
		end
	end

	-- 15: a giant floating crown above the base
	if rebirths >= 15 then
		local crownFolder = Instance.new("Model")
		crownFolder.Name = "Crown"
		crownFolder.Parent = folder
		part(crownFolder, { Name = "CrownBand", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 9, 9), CFrame = at(0, H + 36, 6) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(255, 205, 60), Material = Enum.Material.Neon })
		for k = 0, 5 do
			local a = k / 6 * math.pi * 2
			part(crownFolder, { Name = "Spike", Size = Vector3.new(1, 3.4, 1), CFrame = at(math.cos(a) * 3.8, H + 38.6, 6 + math.sin(a) * 3.8), Color = Color3.fromRGB(255, 205, 60), Material = Enum.Material.Neon })
			part(crownFolder, { Name = "Gem", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.1, CFrame = at(math.cos(a) * 3.8, H + 40.6, 6 + math.sin(a) * 3.8), Color = theme, Material = Enum.Material.Neon })
		end
		-- Spin around the crown's own upright axis.
		crownFolder.WorldPivot = at(0, H + 38, 6)
		CollectionService:AddTag(crownFolder, "Spin")
	end

	-- ===== The big building upgrades =====
	local RY = H + 1.2 -- top of the roof
	local muted = theme:Lerp(Color3.fromRGB(200, 200, 205), 0.45)
	local function tree(x: number, z: number, y: number, s: number)
		part(folder, { Name = "RoofTrunk", Size = Vector3.new(0.9, 4 * s, 0.9) , CFrame = at(x, y + 2 * s, z), Color = Color3.fromRGB(110, 75, 55), Material = Enum.Material.Wood })
		part(folder, { Name = "RoofLeaves", Shape = Enum.PartType.Ball, Size = Vector3.one * 5 * s, CFrame = at(x, y + 4.6 * s, z), Color = Color3.fromRGB(90, 175, 90), Material = Enum.Material.Grass })
	end

	-- 2: a rooftop garden: lawns, planters, little trees and benches
	if rebirths >= 2 then
		for _, sx in { -1, 1 } do
			part(folder, { Name = "RoofLawn", Size = Vector3.new(12, 0.3, 40), CFrame = at(sx * 25, RY + 0.15, 4), Color = Color3.fromRGB(100, 180, 90), Material = Enum.Material.Grass })
			for _, z in { -10, 4, 18 } do
				tree(sx * 28, z, RY + 0.3, 0.8)
				part(folder, { Name = "RoofBench", Size = Vector3.new(1.4, 0.6, 4), CFrame = at(sx * 22, RY + 0.9, z + 6), Color = Color3.fromRGB(150, 100, 65), Material = Enum.Material.WoodPlanks })
			end
			part(folder, { Name = "Planter", Size = Vector3.new(2, 1.2, 40), CFrame = at(sx * 18.6, RY + 0.6, 4), Color = Color3.fromRGB(235, 232, 228), Material = Enum.Material.SmoothPlastic })
			for z = -14, 22, 4 do
				part(folder, { Name = "PlanterFlower", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.3, CFrame = at(sx * 18.6, RY + 1.5, z), Color = ({ Color3.fromRGB(255, 120, 160), Color3.fromRGB(255, 220, 90), Color3.fromRGB(180, 130, 255) })[(z // 4) % 3 + 1], Material = Enum.Material.SmoothPlastic })
			end
		end
	end

	-- 3: searchlights on the back corners of the roof, sweeping the sky
	if rebirths >= 3 then
		for _, sx in { -1, 1 } do
			local rig = Instance.new("Model")
			rig.Name = "Searchlight"
			rig.Parent = folder
			part(rig, { Name = "LightBase", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4, 4, 4), CFrame = at(sx * 29, RY + 0.7, 29) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(60, 60, 70), Material = Enum.Material.Metal })
			local head = part(rig, { Name = "LightHead", Size = Vector3.new(2.6, 2.6, 3.4), CFrame = at(sx * 29, RY + 3, 29) * CFrame.Angles(math.rad(55), 0, 0), Color = Color3.fromRGB(70, 70, 80), Material = Enum.Material.Metal })
			local lens = part(rig, { Name = "Lens", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 2.3, 2.3), CFrame = head.CFrame * CFrame.new(0, 0, -1.75) * CFrame.Angles(0, math.pi / 2, 0), Color = Color3.fromRGB(255, 250, 220), Material = Enum.Material.Neon })
			local beam = part(rig, { Name = "LightBeam", Size = Vector3.new(2, 2, 70), CFrame = head.CFrame * CFrame.new(0, 0, -37), Color = Color3.fromRGB(255, 250, 220), Material = Enum.Material.Neon, Transparency = 0.85 })
			beam.CanQuery = false
			local sl = Instance.new("SpotLight")
			sl.Range = 60
			sl.Brightness = 3
			sl.Angle = 25
			sl.Face = Enum.NormalId.Left
			sl.Parent = lens
			rig.WorldPivot = at(sx * 29, RY, 29)
			CollectionService:AddTag(rig, "Spin")
		end
	end

	-- 5: an indoor fountain at the end of the red carpet
	if rebirths >= 5 then
		part(folder, { Name = "IndoorFountain", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4, 11, 11), CFrame = at(0, 0.7, HALF - 13) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(235, 232, 240), Material = Enum.Material.Marble })
		part(folder, { Name = "IndoorWater", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 9.6, 9.6), CFrame = at(0, 1.35, HALF - 13) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(110, 190, 235), Material = Enum.Material.Glass, Transparency = 0.3 })
		local spout = part(folder, { Name = "Spout", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 1.4, 1.4), CFrame = at(0, 2.6, HALF - 13) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(255, 205, 60), Material = Enum.Material.Metal })
		local e = Instance.new("ParticleEmitter")
		e.Color = ColorSequence.new(Color3.fromRGB(190, 230, 255))
		e.Size = NumberSequence.new(0.4, 0.1)
		e.Transparency = NumberSequence.new(0.2, 1)
		e.Lifetime = NumberRange.new(0.9, 1.2)
		e.Rate = 30
		e.Speed = NumberRange.new(8, 10)
		e.SpreadAngle = Vector2.new(15, 15)
		e.Acceleration = Vector3.new(0, -25, 0)
		e.EmissionDirection = Enum.NormalId.Right -- the cylinder's axis points up
		e.Parent = spout
	end

	-- 4: a second floor with stairs up the middle; it holds pens 9 to 16
	if rebirths >= Config.SecondFloorRebirth then
		local FY = 9.5 -- MapBuilder.UpperFloorY, the top of the upper floor
		local inner = HALF - 0.6
		local front = -8 -- the upper floor runs from here to the back wall
		local wood = Color3.fromRGB(196, 150, 108)
		local function solid(props)
			local p = part(folder, props)
			p.CanCollide = true
			p.CanQuery = true
			return p
		end
		solid({ Name = "UpperFloor", Size = Vector3.new(inner * 2, 0.8, inner - front), CFrame = at(0, FY - 0.4, (inner + front) / 2), Color = wood, Material = Enum.Material.WoodPlanks })
		part(folder, { Name = "UpperRug", Size = Vector3.new(11, 0.08, inner - front - 2), CFrame = at(0, FY + 0.04, (inner + front) / 2 + 1), Color = Color3.fromRGB(200, 40, 60), Material = Enum.Material.Fabric })
		-- Stairs from the entrance hall up to the front edge of the upper floor.
		local steps, bottom = 15, -20
		local run = (front - bottom) / steps
		for k = 1, steps do
			local z0 = bottom + (k - 1) * run
			solid({ Name = "Stair", Size = Vector3.new(8, k * 0.6, front - z0), CFrame = at(0, 0.5 + k * 0.3, (z0 + front) / 2), Color = Color3.fromRGB(235, 230, 240), Material = Enum.Material.Marble })
			part(folder, { Name = "StairCarpet", Size = Vector3.new(5, 0.06, run), CFrame = at(0, 0.53 + k * 0.6, z0 + run / 2), Color = Color3.fromRGB(200, 40, 60), Material = Enum.Material.Fabric })
		end
		for _, sx in { -1, 1 } do
			-- Handrails up the stairs.
			local a, b = Vector3.new(sx * 4.2, 3.6, bottom), Vector3.new(sx * 4.2, FY + 3, front)
			part(folder, { Name = "StairRail", Size = Vector3.new(0.4, 0.4, (b - a).Magnitude), CFrame = CFrame.lookAt((cf * CFrame.new(a)).Position, (cf * CFrame.new(b)).Position) * CFrame.new(0, 0, -(b - a).Magnitude / 2), Color = Color3.fromRGB(255, 205, 60), Material = Enum.Material.Metal })
			-- Railing along the front edge of the upper floor, open where the stairs arrive.
			local len = inner - 4
			local x = sx * (4 + len / 2)
			solid({ Name = "Railing", Size = Vector3.new(len, 0.4, 0.4), CFrame = at(x, FY + 3, front + 0.2), Color = Color3.fromRGB(255, 205, 60), Material = Enum.Material.Metal })
			part(folder, { Name = "RailingGlass", Size = Vector3.new(len, 2.8, 0.15), CFrame = at(x, FY + 1.5, front + 0.2), Color = Color3.fromRGB(190, 225, 245), Material = Enum.Material.Glass, Transparency = 0.6 }).CanCollide = true
			for px = 4, inner, 4 do
				part(folder, { Name = "RailPost", Size = Vector3.new(0.4, 3, 0.4), CFrame = at(sx * px, FY + 1.5, front + 0.2), Color = Color3.fromRGB(255, 205, 60), Material = Enum.Material.Metal })
			end
			-- Soft lights under the upper floor so the downstairs pens aren't in the dark.
			for _, z in { 2, 16, 28 } do
				local lamp = part(folder, { Name = "UnderLight", Size = Vector3.new(3, 0.2, 3), CFrame = at(sx * 16, FY - 0.9, z), Color = Color3.fromRGB(255, 250, 240), Material = Enum.Material.SmoothPlastic })
				local pl = Instance.new("PointLight")
				pl.Range = 16
				pl.Brightness = 0.3
				pl.Shadows = true
				pl.Color = Color3.fromRGB(255, 245, 225)
				pl.Parent = lamp
			end
		end
	end

	-- 7: a penthouse on the roof, so your base stands taller than everyone else's
	if rebirths >= 7 then
		local ph, pw, pd = 9, 26, 18
		local base = RY
		for _, w in {
			{ Vector3.new(pw, ph, 1), Vector3.new(0, base + ph / 2, 14 + pd / 2) },
			{ Vector3.new(1, ph, pd), Vector3.new(-pw / 2, base + ph / 2, 14) },
			{ Vector3.new(1, ph, pd), Vector3.new(pw / 2, base + ph / 2, 14) },
		} do
			part(folder, { Name = "PenthouseWall", Size = w[1], CFrame = at(w[2].X, w[2].Y, w[2].Z), Color = muted, Material = Enum.Material.SmoothPlastic, CanCollide = true })
		end
		-- A glass front facing the street.
		part(folder, { Name = "PenthouseGlass", Size = Vector3.new(pw, ph - 1, 0.4), CFrame = at(0, base + (ph - 1) / 2, 14 - pd / 2), Color = Color3.fromRGB(170, 225, 255), Material = Enum.Material.Glass, Transparency = 0.45, CanCollide = true })
		part(folder, { Name = "PenthouseRoof", Size = Vector3.new(pw + 3, 1, pd + 3), CFrame = at(0, base + ph + 0.5, 14), Color = theme:Lerp(Color3.fromRGB(60, 60, 70), 0.6), Material = Enum.Material.SmoothPlastic, CanCollide = true })
		part(folder, { Name = "PenthouseTrim", Size = Vector3.new(pw + 3.2, 0.4, pd + 3.2), CFrame = at(0, base + ph + 1.1, 14), Color = Color3.fromRGB(255, 205, 60), Material = Enum.Material.Metal })
		local lamp = part(folder, { Name = "PenthouseLight", Size = Vector3.new(6, 0.3, 6), CFrame = at(0, base + ph - 0.2, 14), Color = Color3.fromRGB(255, 240, 210), Material = Enum.Material.Neon })
		local pl = Instance.new("PointLight")
		pl.Range = 18
		pl.Brightness = 1
		pl.Parent = lamp
		part(folder, { Name = "PenthouseSofa", Size = Vector3.new(10, 1.6, 3), CFrame = at(0, base + 0.8, 20), Color = theme, Material = Enum.Material.Fabric })
	end

	-- 8: a VIP rope line down the red carpet
	if rebirths >= 8 then
		for _, x in { -7.6, 7.6 } do
			for z = -HALF + 6, HALF - 20, 8 do
				part(folder, { Name = "Stanchion", Size = Vector3.new(0.5, 3, 0.5), CFrame = at(x, 2, z), Color = Color3.fromRGB(255, 205, 60), Material = Enum.Material.Metal })
				part(folder, { Name = "StanchionTop", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, CFrame = at(x, 3.6, z), Color = Color3.fromRGB(255, 205, 60), Material = Enum.Material.Metal })
				if z + 8 <= HALF - 20 then
					part(folder, { Name = "Rope", Size = Vector3.new(0.3, 0.3, 8), CFrame = at(x, 2.8, z + 4), Color = Color3.fromRGB(170, 20, 40), Material = Enum.Material.Fabric })
				end
			end
		end
	end

	-- 10: a helipad on the roof with a little slime copter
	if rebirths >= 10 then
		part(folder, { Name = "Helipad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 14, 14), CFrame = at(0, RY + 0.15, -18) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(70, 70, 80), Material = Enum.Material.Concrete })
		part(folder, { Name = "HeliRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.32, 12.5, 12.5), CFrame = at(0, RY + 0.17, -18) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(255, 205, 60), Material = Enum.Material.SmoothPlastic })
		part(folder, { Name = "HeliInner", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.34, 11, 11), CFrame = at(0, RY + 0.19, -18) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(70, 70, 80), Material = Enum.Material.Concrete })
		for _, h in { { Vector3.new(1, 0.1, 5), Vector3.new(-1.6, 0, 0) }, { Vector3.new(1, 0.1, 5), Vector3.new(1.6, 0, 0) }, { Vector3.new(2.4, 0.1, 1), Vector3.new(0, 0, 0) } } do
			part(folder, { Name = "HeliH", Size = h[1], CFrame = at(h[2].X, RY + 0.4, -18 + h[2].Z), Color = Color3.new(1, 1, 1), Material = Enum.Material.SmoothPlastic })
		end
		local body = part(folder, { Name = "CopterBody", Shape = Enum.PartType.Ball, Size = Vector3.new(4.4, 3.6, 5), CFrame = at(0, RY + 3, -18), Color = theme, Material = Enum.Material.SmoothPlastic })
		part(folder, { Name = "CopterTail", Size = Vector3.new(0.8, 0.8, 5), CFrame = body.CFrame * CFrame.new(0, 0.4, 4.4), Color = theme, Material = Enum.Material.SmoothPlastic })
		for _, sx in { -1, 1 } do
			part(folder, { Name = "CopterEye", Shape = Enum.PartType.Ball, Size = Vector3.new(0.7, 1, 0.4), CFrame = body.CFrame * CFrame.new(sx * 0.9, 0.3, -2.4), Color = Color3.fromRGB(30, 25, 30), Material = Enum.Material.SmoothPlastic })
			part(folder, { Name = "CopterSkid", Size = Vector3.new(0.4, 0.4, 5), CFrame = body.CFrame * CFrame.new(sx * 1.6, -2, 0), Color = Color3.fromRGB(60, 60, 70), Material = Enum.Material.Metal })
		end
		local rotor = Instance.new("Model")
		rotor.Name = "Rotor"
		rotor.Parent = folder
		part(rotor, { Name = "Blade", Size = Vector3.new(12, 0.2, 0.8), CFrame = body.CFrame * CFrame.new(0, 2.2, 0), Color = Color3.fromRGB(50, 50, 60), Material = Enum.Material.Metal })
		part(rotor, { Name = "Blade", Size = Vector3.new(0.8, 0.2, 12), CFrame = body.CFrame * CFrame.new(0, 2.2, 0), Color = Color3.fromRGB(50, 50, 60), Material = Enum.Material.Metal })
		rotor.WorldPivot = body.CFrame * CFrame.new(0, 2.2, 0)
		CollectionService:AddTag(rotor, "Spin")
	end

	-- 25: the trim cycles through the rainbow
	if rebirths >= 25 then
		for _, d in model:GetChildren() do
			if d:IsA("BasePart") and d.Name == "Trim" then
				CollectionService:AddTag(d, "Rainbow")
			end
		end
	end
end

function BaseDecor.Apply(model: Model, cf: CFrame, rebirths: number, skin: string?)
	applyTiers(model, cf, rebirths)
	applySkin(model, skin)
end

-- The next tier this player will unlock, for the Rebirth menu.
function BaseDecor.NextTier(rebirths: number)
	for _, t in BaseDecor.Tiers do
		if t.rebirth > rebirths then
			return t
		end
	end
	return nil
end

return BaseDecor
