-- The ⚙️ settings menu: music and sound volume, Low Graphics and screen shake, saved with
-- the player's data. Also routes every sound into a Music or SFX SoundGroup so the volume
-- sliders reach all of them, and shows the one-time "favourite the game" prompt.

local AvatarEditorService = game:GetService("AvatarEditorService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SaveSettings = Remotes:WaitForChild("SaveSettings") :: RemoteEvent
local FavoriteAsked = Remotes:WaitForChild("FavoriteAsked") :: RemoteEvent

local player = Players.LocalPlayer
local FONT = Enum.Font.FredokaOne
local BG = Color3.fromRGB(28, 20, 48)
local PANEL = Color3.fromRGB(48, 36, 80)
local OUTLINE = Color3.fromRGB(20, 10, 35)
local ON = Color3.fromRGB(120, 255, 160)
local OFF = Color3.fromRGB(110, 100, 140)

local settings = table.clone(Config.DefaultSettings)

-- ===== Sound groups =====
local function group(name: string): SoundGroup
	local g = SoundService:FindFirstChild(name) :: SoundGroup?
	if not g then
		local made = Instance.new("SoundGroup")
		made.Name = name
		made.Parent = SoundService
		g = made
	end
	return g :: SoundGroup
end
local musicGroup, sfxGroup = group("Music"), group("SFX")

local function route(inst: Instance)
	if inst:IsA("Sound") and not inst.SoundGroup then
		inst.SoundGroup = if inst.Name == "BackgroundMusic" then musicGroup else sfxGroup
	end
end
for _, root in { SoundService, workspace } do
	for _, d in root:GetDescendants() do
		route(d)
	end
	root.DescendantAdded:Connect(route)
end

-- ===== Low Graphics =====
-- Shadows and post effects off, ambient particles cut to a third. Effects/Weather read OptLowFx.
local postFx = { "BloomEffect", "SunRaysEffect", "DepthOfFieldEffect" }
local function scaleEmitter(inst: Instance)
	if not inst:IsA("ParticleEmitter") then
		return
	end
	local e = inst :: ParticleEmitter
	if e.Rate <= 0 and e:GetAttribute("BaseRate") == nil then
		return -- one-shot bursts (Rate 0) are thinned where they Emit
	end
	local base = e:GetAttribute("BaseRate")
	if base == nil then
		base = e.Rate
		e:SetAttribute("BaseRate", base)
	end
	e.Rate = if settings.lowFx then base / 3 else base
end
local function applyLowFx()
	player:SetAttribute("OptLowFx", settings.lowFx)
	Lighting.GlobalShadows = not settings.lowFx
	for _, fx in Lighting:GetChildren() do
		if table.find(postFx, fx.ClassName) then
			(fx :: any).Enabled = not settings.lowFx
		end
	end
	for _, d in workspace:GetDescendants() do
		scaleEmitter(d)
	end
end
workspace.DescendantAdded:Connect(function(d)
	if settings.lowFx and d:IsA("ParticleEmitter") then
		task.defer(scaleEmitter, d) -- after the creating script has set its Rate
	end
end)

local function apply()
	musicGroup.Volume = settings.music
	sfxGroup.Volume = settings.sfx
	player:SetAttribute("OptShake", settings.shake)
	if player:GetAttribute("OptLowFx") ~= settings.lowFx then
		applyLowFx()
	end
end

local function load()
	local raw = player:GetAttribute("Settings")
	if type(raw) == "string" then
		local ok, saved = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok and type(saved) == "table" then
			for k, v in saved do
				if Config.DefaultSettings[k] ~= nil and type(v) == type(Config.DefaultSettings[k]) then
					settings[k] = v
				end
			end
		end
	end
end
load()
player:SetAttribute("OptLowFx", false)
apply()
-- The saved copy usually arrives a moment after this script starts.
local loadedOnce = player:GetAttribute("Settings") ~= nil
player:GetAttributeChangedSignal("Settings"):Connect(function()
	if not loadedOnce then
		loadedOnce = true
		load()
		apply()
	end
end)

local saveToken = 0
local function save()
	saveToken += 1
	local token = saveToken
	task.delay(1, function()
		if token == saveToken then
			SaveSettings:FireServer(settings)
		end
	end)
end

-- ===== UI =====
local gui = Instance.new("ScreenGui")
gui.Name = "SettingsGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 20
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(parent: Instance, r: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 12)
	c.Parent = parent
end
local function stroke(parent: Instance, th: number?)
	local s = Instance.new("UIStroke")
	s.Color = OUTLINE
	s.Thickness = th or 3
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end
local function label(parent: Instance, text: string, size: UDim2, pos: UDim2, align: Enum.TextXAlignment?)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextXAlignment = align or Enum.TextXAlignment.Center
	l.Text = text
	l.Size = size
	l.Position = pos
	l.Parent = parent
	local s = Instance.new("UIStroke")
	s.Color = OUTLINE
	s.Thickness = 2
	s.Parent = l
	return l
end
local function chunky(parent: Instance, text: string, color: Color3, size: UDim2, pos: UDim2, onClick: () -> ())
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BackgroundColor3 = color
	b.Text = ""
	b.Size = size
	b.Position = pos
	b.Parent = parent
	corner(b, 10)
	stroke(b, 3)
	local l = label(b, text, UDim2.fromScale(0.86, 0.78), UDim2.fromScale(0.07, 0.11))
	local scale = Instance.new("UIScale")
	scale.Parent = b
	b.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1.06 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1 }):Play()
	end)
	b.Activated:Connect(function()
		scale.Scale = 0.9
		TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		onClick()
	end)
	return b, l
end

-- The ⚙️ button sits just left of the 🎵 music button in the bottom-right corner.
local gear = Instance.new("TextButton")
gear.AnchorPoint = Vector2.new(1, 1)
gear.Position = UDim2.new(1, -60, 1, -12)
gear.Size = UDim2.fromOffset(40, 40)
gear.BackgroundColor3 = Color3.fromRGB(40, 34, 60)
gear.BackgroundTransparency = 0.25
gear.Font = Enum.Font.GothamBold
gear.TextSize = 20
gear.TextColor3 = Color3.new(1, 1, 1)
gear.Text = "⚙️"
gear.Parent = gui
Instance.new("UICorner", gear).CornerRadius = UDim.new(1, 0)

local shade = Instance.new("TextButton") -- tap outside the panel to close
shade.AutoButtonColor = false
shade.Text = ""
shade.Size = UDim2.fromScale(1, 1)
shade.BackgroundColor3 = Color3.new(0, 0, 0)
shade.BackgroundTransparency = 0.45
shade.Visible = false
shade.Parent = gui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(380, 330)
panel.BackgroundColor3 = BG
panel.Visible = false
panel.Parent = gui
corner(panel, 18)
stroke(panel, 4)
local panelScale = Instance.new("UIScale")
panelScale.Parent = panel
local function fit()
	local vp = workspace.CurrentCamera.ViewportSize
	panelScale.Scale = math.clamp(math.min(vp.X / 420, vp.Y / 380), 0.6, 1.4)
end
fit()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)

label(panel, "⚙️ SETTINGS", UDim2.new(1, -80, 0, 40), UDim2.fromOffset(20, 12), Enum.TextXAlignment.Left)

local function close()
	panel.Visible = false
	shade.Visible = false
end
chunky(panel, "✖", Color3.fromRGB(255, 90, 100), UDim2.fromOffset(40, 40), UDim2.new(1, -54, 0, 12), close)
shade.Activated:Connect(close)

local rows = {}
local function row(i: number, title: string)
	local r = Instance.new("Frame")
	r.BackgroundColor3 = PANEL
	r.Size = UDim2.new(1, -32, 0, 52)
	r.Position = UDim2.fromOffset(16, 64 + (i - 1) * 62)
	r.Parent = panel
	corner(r, 12)
	label(r, title, UDim2.new(0.5, 0, 0, 30), UDim2.fromOffset(14, 11), Enum.TextXAlignment.Left)
	return r
end

-- Volume rows: − 60% + in steps of 10%.
local function volumeRow(i: number, title: string, key: string)
	local r = row(i, title)
	local value = label(r, "", UDim2.fromOffset(64, 30), UDim2.new(1, -112, 0, 11))
	local function show()
		value.Text = math.round(settings[key] * 100) .. "%"
	end
	local function step(d: number)
		settings[key] = math.clamp(math.round((settings[key] + d) * 10) / 10, 0, 1)
		show()
		apply()
		save()
	end
	chunky(r, "−", OFF, UDim2.fromOffset(40, 40), UDim2.new(1, -162, 0, 6), function()
		step(-0.1)
	end)
	chunky(r, "+", ON, UDim2.fromOffset(40, 40), UDim2.new(1, -46, 0, 6), function()
		step(0.1)
	end)
	rows[key] = show
	show()
end

local function toggleRow(i: number, title: string, key: string)
	local r = row(i, title)
	local b, l
	local function show()
		b.BackgroundColor3 = if settings[key] then ON else OFF
		l.Text = if settings[key] then "ON" else "OFF"
	end
	b, l = chunky(r, "", OFF, UDim2.fromOffset(90, 40), UDim2.new(1, -100, 0, 6), function()
		settings[key] = not settings[key]
		show()
		apply()
		save()
	end)
	rows[key] = show
	show()
end

volumeRow(1, "🎵 Music", "music")
volumeRow(2, "🔊 Sounds", "sfx")
toggleRow(3, "✨ Low Graphics", "lowFx")
toggleRow(4, "📳 Screen Shake", "shake")

gear.Activated:Connect(function()
	local open = not panel.Visible
	for _, show in rows do
		show()
	end
	panel.Visible = open
	shade.Visible = open
	if open then
		panelScale.Scale *= 0.85
		TweenService:Create(panelScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = panelScale.Scale / 0.85 }):Play()
	end
end)

-- ===== Favourite prompt =====
-- Once per account, after a few minutes of real play and never mid-steal.
task.spawn(function()
	task.wait(Config.FavoritePromptMinutes * 60)
	if game.PlaceId == 0 or player:GetAttribute("AskedFavorite") ~= false then
		return
	end
	while player:GetAttribute("Carrying") or player:GetAttribute("StealingFrom") do
		task.wait(5)
	end
	local ok = pcall(AvatarEditorService.PromptSetFavorite, AvatarEditorService, game.PlaceId, Enum.AvatarItemType.Asset, true)
	if ok then
		FavoriteAsked:FireServer()
	end
end)
