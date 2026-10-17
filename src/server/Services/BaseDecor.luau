-- Bases get prettier with every rebirth: new materials, flower boxes, lanterns, a gate,
-- crystals, gold, banners, sparkles and finally a floating crown. Each tier adds to the last,
-- so you can tell how far someone has come just by looking at their base.

local CollectionService = game:GetService("CollectionService")

local BaseDecor = {}

local HALF = 26 -- MapBuilder.PlotSize / 2

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

function BaseDecor.Apply(model: Model, cf: CFrame, rebirths: number)
	remember(model)
	local old = model:FindFirstChild("Decor")
	if old then
		old:Destroy()
	end
	restyle(model, "Floor")
	restyle(model, "Wall")
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

	-- 1: stone floor and white caps on the walls
	restyle(model, "Floor", Color3.fromRGB(200, 195, 205), Enum.Material.Slate)
	for _, w in walls do
		local mid = (w.from + w.to) / 2
		local len = (w.to - w.from).Magnitude + 1.4
		local alongX = math.abs(w.to.X - w.from.X) > 0.1
		part(folder, { Name = "Cap", Size = if alongX then Vector3.new(len, 0.4, 1.4) else Vector3.new(1.4, 0.4, len), CFrame = at(mid.X, 3.2, mid.Z), Color = Color3.fromRGB(245, 240, 250), Material = Enum.Material.SmoothPlastic })
	end

	-- 2: flower boxes along the wall tops
	if rebirths >= 2 then
		local flowerColors = { Color3.fromRGB(255, 90, 140), Color3.fromRGB(255, 220, 80), Color3.fromRGB(180, 120, 255), light }
		local n = 0
		for _, w in walls do
			local len = (w.to - w.from).Magnitude
			for d = 6, len - 6, 10 do
				n += 1
				local p = w.from + (w.to - w.from).Unit * d
				part(folder, { Name = "FlowerBox", Size = Vector3.new(2.6, 0.8, 2.6), CFrame = at(p.X, 3.8, p.Z), Color = Color3.fromRGB(120, 80, 50), Material = Enum.Material.WoodPlanks })
				for k = 1, 3 do
					local off = Vector3.new(math.cos(k * 2.1) * 0.7, 0, math.sin(k * 2.1) * 0.7)
					part(folder, { Name = "Flower", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, CFrame = at(p.X + off.X, 4.6, p.Z + off.Z), Color = flowerColors[(n + k) % #flowerColors + 1], Material = Enum.Material.SmoothPlastic })
				end
				part(folder, { Name = "Leaves", Size = Vector3.new(2.2, 0.3, 2.2), CFrame = at(p.X, 4.25, p.Z), Color = Color3.fromRGB(70, 170, 70), Material = Enum.Material.Grass })
			end
		end
	end

	-- 3: lanterns on the four corners
	if rebirths >= 3 then
		for _, c in { Vector3.new(-HALF, 0, -HALF), Vector3.new(HALF, 0, -HALF), Vector3.new(-HALF, 0, HALF), Vector3.new(HALF, 0, HALF) } do
			part(folder, { Name = "Post", Size = Vector3.new(1, 8, 1), CFrame = at(c.X, 4, c.Z), Color = Color3.fromRGB(60, 45, 70), Material = Enum.Material.Metal })
			local lamp = part(folder, { Name = "Lantern", Size = Vector3.new(1.8, 2, 1.8), CFrame = at(c.X, 9, c.Z), Color = Color3.fromRGB(255, 220, 140), Material = Enum.Material.Neon })
			CollectionService:AddTag(lamp, "Pulse")
			local pl = Instance.new("PointLight")
			pl.Color = Color3.fromRGB(255, 210, 140)
			pl.Range = 18
			pl.Brightness = 1.5
			pl.Parent = lamp
			part(folder, { Name = "LanternRoof", Size = Vector3.new(2.4, 0.4, 2.4), CFrame = at(c.X, 10.2, c.Z), Color = Color3.fromRGB(60, 45, 70), Material = Enum.Material.Metal })
		end
	end

	-- 4: a grand entrance gate on the open side, with your rebirth count
	if rebirths >= 4 then
		for _, x in { -9, 9 } do
			part(folder, { Name = "GatePillar", Size = Vector3.new(2.4, 13, 2.4), CFrame = at(x, 6.5, -HALF), Color = Color3.fromRGB(240, 235, 245), Material = Enum.Material.Marble })
			part(folder, { Name = "GateOrb", Shape = Enum.PartType.Ball, Size = Vector3.one * 2.4, CFrame = at(x, 14.2, -HALF), Color = theme, Material = Enum.Material.Neon })
		end
		local beam = part(folder, { Name = "GateBeam", Size = Vector3.new(21, 2, 2), CFrame = at(0, 12, -HALF), Color = theme, Material = Enum.Material.Neon })
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
				local crystal = part(folder, { Name = "Crystal", Size = Vector3.new(1.2, h, 1.2), CFrame = at(c.X + off.X, 3 + h / 2, c.Z + off.Z) * CFrame.Angles(math.rad(k * 7 - 14), k, math.rad(10 - k * 5)), Color = light, Material = Enum.Material.Glass, Transparency = 0.2 })
				if k == 4 then
					local pl = Instance.new("PointLight")
					pl.Color = theme
					pl.Range = 14
					pl.Parent = crystal
				end
			end
		end
	end

	-- 6: marble walls and floor with gold trim
	if rebirths >= 6 then
		restyle(model, "Floor", Color3.fromRGB(235, 230, 240), Enum.Material.Marble)
		restyle(model, "Wall", Color3.fromRGB(245, 242, 250), Enum.Material.Marble)
		restyle(model, "Trim", Color3.fromRGB(255, 205, 60), Enum.Material.Neon)
		for _, cap in folder:GetChildren() do
			if cap.Name == "Cap" then
				(cap :: BasePart).Color = Color3.fromRGB(255, 205, 60);
				(cap :: BasePart).Material = Enum.Material.Metal
			end
		end
	end

	-- 7: fireflies drifting over the pens
	if rebirths >= 7 then
		local zone = part(folder, { Name = "Fireflies", Size = Vector3.new(44, 1, 34), CFrame = at(0, 6, 8), Transparency = 1 })
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
			local bulb = part(folder, { Name = "PartyBulb", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, CFrame = at(x, 8 + sag, -HALF), Color = colors[k % #colors + 1], Material = Enum.Material.Neon })
			if k % 3 == 0 then
				CollectionService:AddTag(bulb, "Pulse")
			end
		end
		part(folder, { Name = "PartyWire", Size = Vector3.new(HALF * 2, 0.1, 0.1), CFrame = at(0, 8.4, -HALF), Color = Color3.fromRGB(40, 40, 50), Material = Enum.Material.SmoothPlastic })
	end

	-- 10: sparkles drifting up from the floor edges
	if rebirths >= 10 then
		for _, w in walls do
			local mid = (w.from + w.to) / 2
			local alongX = math.abs(w.to.X - w.from.X) > 0.1
			local emitterPart = part(folder, { Name = "Aura", Size = if alongX then Vector3.new(52, 0.2, 1) else Vector3.new(1, 0.2, 52), CFrame = at(mid.X, 0.6, mid.Z), Transparency = 1 })
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

	-- 12: a golden slime statue on top of the back wall sign
	if rebirths >= 12 then
		part(folder, { Name = "Plinth", Size = Vector3.new(6, 1.2, 4), CFrame = at(0, 10.6, HALF - 1), Color = Color3.fromRGB(245, 240, 250), Material = Enum.Material.Marble })
		local s = part(folder, { Name = "StatueSlime", Shape = Enum.PartType.Ball, Size = Vector3.one * 5, CFrame = at(0, 13.4, HALF - 1), Color = Color3.fromRGB(255, 205, 60), Material = Enum.Material.Metal, Reflectance = 0.35 })
		for _, side in { -1, 1 } do
			part(folder, { Name = "StatueEye", Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 1.1, 0.4), CFrame = s.CFrame * CFrame.new(side * 0.9, 0.4, -2.3), Color = Color3.fromRGB(30, 25, 20), Material = Enum.Material.SmoothPlastic })
		end
	end

	-- 15: a giant floating crown above the base
	if rebirths >= 15 then
		local crownFolder = Instance.new("Model")
		crownFolder.Name = "Crown"
		crownFolder.Parent = folder
		part(crownFolder, { Name = "CrownBand", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 9, 9), CFrame = at(0, 30, 6) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(255, 205, 60), Material = Enum.Material.Neon })
		for k = 0, 5 do
			local a = k / 6 * math.pi * 2
			part(crownFolder, { Name = "Spike", Size = Vector3.new(1, 3.4, 1), CFrame = at(math.cos(a) * 3.8, 32.6, 6 + math.sin(a) * 3.8), Color = Color3.fromRGB(255, 205, 60), Material = Enum.Material.Neon })
			part(crownFolder, { Name = "Gem", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.1, CFrame = at(math.cos(a) * 3.8, 34.6, 6 + math.sin(a) * 3.8), Color = theme, Material = Enum.Material.Neon })
		end
		-- Spin around the crown's own upright axis.
		crownFolder.WorldPivot = at(0, 32, 6)
		CollectionService:AddTag(crownFolder, "Spin")
	end

	-- 20: the floor border glows in your colour
	if rebirths >= 20 then
		local start = model:FindFirstChild("StartDecor")
		for _, d in (if start then start:GetChildren() else {}) do
			if d:IsA("BasePart") and d.Name == "FloorBorder" then
				local glow = d:Clone()
				glow.Name = "GlowBorder"
				glow.Color = theme
				glow.Material = Enum.Material.Neon
				glow.Size += Vector3.new(0, 0.02, 0)
				glow.Parent = folder
			end
		end
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
