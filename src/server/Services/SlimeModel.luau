-- Builds slime visuals from primitives: a glossy blob, two eyes, a shine, and a label.

local Config = require(game.ReplicatedStorage.Shared.Config)
local Util = require(game.ReplicatedStorage.Shared.Util)

local SlimeModel = {}

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

local function makeLabel(parent: BasePart, height: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(180, 60)
	gui.StudsOffset = Vector3.new(0, height, 0)
	gui.MaxDistance = 60
	gui.AlwaysOnTop = false
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
		t.TextStrokeTransparency = 0.3
		t.Parent = gui
		return t
	end
	line("Rarity", 0, 0.3, Enum.Font.GothamBold)
	line("Title", 0.3, 0.4, Enum.Font.GothamBlack)
	line("Info", 0.7, 0.3, Enum.Font.GothamMedium)
	return gui
end

-- Creates a slime model. `stage` is the growth stage (1 for belt slimes).
function SlimeModel.Create(slimeId: string, stage: number): Model
	local def = Config.SlimeById[slimeId]
	local rarity = Config.RarityByName[def.rarity]
	local size = def.size * Config.GrowthSizeMult[stage]

	local model = Instance.new("Model")
	model.Name = slimeId

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.one * size
	body.Color = def.color
	body.Material = if def.rarity == "Secret" or def.rarity == "Mythic" then Enum.Material.Neon else Enum.Material.SmoothPlastic
	body.Transparency = 0.1
	body.Reflectance = 0.15
	body.Anchored = true
	body.CanCollide = false
	body.Parent = model
	model.PrimaryPart = body

	for _, side in { -1, 1 } do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.one * size * 0.18
		eye.Color = Color3.new(0.05, 0.05, 0.05)
		eye.Material = Enum.Material.SmoothPlastic
		eye.CanCollide = false
		eye.Anchored = false
		eye.Massless = true
		eye.CFrame = body.CFrame * CFrame.new(side * size * 0.18, size * 0.1, -size * 0.42)
		eye.Parent = model
		weld(body, eye)
	end

	local shine = Instance.new("Part")
	shine.Name = "Shine"
	shine.Shape = Enum.PartType.Ball
	shine.Size = Vector3.one * size * 0.2
	shine.Color = Color3.new(1, 1, 1)
	shine.Material = Enum.Material.Neon
	shine.Transparency = 0.3
	shine.CanCollide = false
	shine.Anchored = false
	shine.Massless = true
	shine.CFrame = body.CFrame * CFrame.new(size * 0.22, size * 0.28, -size * 0.2)
	shine.Parent = model
	weld(body, shine)

	if rarity.order >= 5 then
		local light = Instance.new("PointLight")
		light.Color = rarity.color
		light.Range = 10
		light.Brightness = 2
		light.Parent = body
		local sparkle = Instance.new("Sparkles")
		sparkle.SparkleColor = rarity.color
		sparkle.Parent = body
	end

	local gui = makeLabel(body, size * 0.6 + 1.5)
	gui.Rarity.Text = def.rarity
	gui.Rarity.TextColor3 = rarity.color
	gui.Title.Text = slimeId
	gui.Info.Text = Util.Money(def.income) .. "/s"

	model:SetAttribute("SlimeId", slimeId)
	return model
end

-- Sets every part's Anchored flag (body anchored in pens/belt, unanchored when carried).
function SlimeModel.SetAnchored(model: Model, anchored: boolean)
	model.PrimaryPart.Anchored = anchored
end

return SlimeModel
