-- Client-side juice: particle bursts, reveals, flashes, camera shake, sounds,
-- bouncing pen slimes, spinning/pulsing decorations and Slime Rain drops.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local FxEvent = Remotes:WaitForChild("Fx")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local fxFolder = Instance.new("Folder")
fxFolder.Name = "LocalFx"
fxFolder.Parent = workspace

-- ===== Sound =====
local function sound(name: string, speed: number?, volume: number?, at: Vector3?)
	local id = Config.Sounds[name]
	if not id then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.PlaybackSpeed = speed or 1
	s.Volume = volume or 0.6
	if at then
		local holder = Instance.new("Part")
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.Transparency = 1
		holder.Size = Vector3.one
		holder.Position = at
		holder.Parent = fxFolder
		s.RollOffMaxDistance = 90
		s.Parent = holder
		s:Play()
		Debris:AddItem(holder, 3)
	else
		s.Parent = SoundService
		s:Play()
		Debris:AddItem(s, 3)
	end
end

-- ===== World particles =====
local function burst(pos: Vector3, color: Color3, count: number, opts)
	opts = opts or {}
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.Position = pos
	holder.Parent = fxFolder
	local p = Instance.new("ParticleEmitter")
	p.Texture = opts.texture or SPARKLE
	p.Color = ColorSequence.new(color)
	p.LightEmission = opts.light or 1
	p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, opts.size or 1.2), NumberSequenceKeypoint.new(1, 0) })
	p.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	p.Lifetime = NumberRange.new(opts.life or 0.6, (opts.life or 0.6) * 1.8)
	p.Speed = NumberRange.new(opts.speed or 12, (opts.speed or 12) * 2)
	p.SpreadAngle = Vector2.new(180, 180)
	p.Acceleration = Vector3.new(0, opts.gravity or -20, 0)
	p.Drag = 2
	p.Rate = 0
	p.Parent = holder
	p:Emit(count)
	Debris:AddItem(holder, 3)
end

local function ring(pos: Vector3, color: Color3, size: number)
	local r = Instance.new("Part")
	r.Shape = Enum.PartType.Cylinder
	r.Anchored = true
	r.CanCollide = false
	r.CanQuery = false
	r.Material = Enum.Material.Neon
	r.Color = color
	r.Transparency = 0.2
	r.Size = Vector3.new(0.2, 1, 1)
	r.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2)
	r.Parent = fxFolder
	TweenService:Create(r, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.2, size, size), Transparency = 1 }):Play()
	Debris:AddItem(r, 0.6)
end

local function pillar(pos: Vector3, color: Color3)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = 0.3
	p.Size = Vector3.new(4, 120, 4)
	p.Position = pos + Vector3.new(0, 60, 0)
	p.Parent = fxFolder
	TweenService:Create(p, TweenInfo.new(2.5), { Transparency = 1, Size = Vector3.new(10, 120, 10) }):Play()
	Debris:AddItem(p, 2.6)
end

local function popText(pos: Vector3, text: string, color: Color3)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.Position = pos + Vector3.new(0, 3, 0)
	holder.Parent = fxFolder
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 60)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = holder
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Parent = gui
	TweenService:Create(holder, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = holder.Position + Vector3.new(0, 7, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(holder, 1.3)
end

-- ===== Screen effects =====
local screen = Instance.new("ScreenGui")
screen.Name = "FxGui"
screen.IgnoreGuiInset = true
screen.ResetOnSpawn = false
screen.DisplayOrder = 5
screen.Parent = player:WaitForChild("PlayerGui")

local flashFrame = Instance.new("Frame")
flashFrame.Size = UDim2.fromScale(1, 1)
flashFrame.BackgroundTransparency = 1
flashFrame.BorderSizePixel = 0
flashFrame.Parent = screen

local function flash(color: Color3, strength: number?, duration: number?)
	flashFrame.BackgroundColor3 = color
	flashFrame.BackgroundTransparency = 1 - (strength or 0.5)
	TweenService:Create(flashFrame, TweenInfo.new(duration or 0.5), { BackgroundTransparency = 1 }):Play()
end

local shakeAmount = 0
local function shake(amount: number)
	shakeAmount = math.max(shakeAmount, amount)
end
RunService:BindToRenderStep("SlimeShake", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if shakeAmount > 0.01 then
		local a = shakeAmount
		camera.CFrame *= CFrame.new((math.random() - 0.5) * a, (math.random() - 0.5) * a, 0) * CFrame.Angles(0, 0, (math.random() - 0.5) * a * 0.02)
		shakeAmount = math.max(0, shakeAmount - dt * 3)
	end
end)

local bigText = Instance.new("TextLabel")
bigText.AnchorPoint = Vector2.new(0.5, 0.5)
bigText.Position = UDim2.fromScale(0.5, 0.38)
bigText.Size = UDim2.fromScale(0.8, 0.14)
bigText.BackgroundTransparency = 1
bigText.Font = Enum.Font.FredokaOne
bigText.TextScaled = true
bigText.TextStrokeTransparency = 0
bigText.TextTransparency = 1
bigText.TextStrokeColor3 = Color3.fromRGB(25, 15, 45)
bigText.Parent = screen
local bigScale = Instance.new("UIScale")
bigScale.Parent = bigText

local subText = bigText:Clone()
subText.Position = UDim2.fromScale(0.5, 0.49)
subText.Size = UDim2.fromScale(0.7, 0.07)
subText.Parent = screen
local subScale = subText:FindFirstChildOfClass("UIScale")

local textToken = 0
local function announce(main: string, color: Color3, sub: string?, subColor: Color3?, hold: number?)
	textToken += 1
	local token = textToken
	bigText.Text = main
	bigText.TextColor3 = color
	bigText.TextTransparency = 0
	bigText.TextStrokeTransparency = 0
	bigScale.Scale = 0.2
	TweenService:Create(bigScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	subText.Text = sub or ""
	subText.TextColor3 = subColor or Color3.new(1, 1, 1)
	subText.TextTransparency = if sub then 0 else 1
	subText.TextStrokeTransparency = if sub then 0 else 1
	if subScale then
		subScale.Scale = 0.2
		TweenService:Create(subScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	task.delay(hold or 1.8, function()
		if token ~= textToken then
			return
		end
		TweenService:Create(bigText, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		TweenService:Create(subText, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
end

local CONFETTI = { Color3.fromRGB(255, 90, 140), Color3.fromRGB(90, 200, 255), Color3.fromRGB(255, 220, 60), Color3.fromRGB(120, 255, 160), Color3.fromRGB(190, 120, 255) }
local function confetti(count: number)
	for _ = 1, count do
		local f = Instance.new("Frame")
		f.Size = UDim2.fromOffset(math.random(8, 14), math.random(12, 20))
		f.Position = UDim2.new(math.random(), 0, -0.05, 0)
		f.BackgroundColor3 = CONFETTI[math.random(1, #CONFETTI)]
		f.BorderSizePixel = 0
		f.Rotation = math.random(0, 360)
		f.Parent = screen
		local t = math.random(15, 30) / 10
		TweenService:Create(f, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(f.Position.X.Scale + (math.random() - 0.5) * 0.3, 0, 1.1, 0),
			Rotation = f.Rotation + math.random(-540, 540),
		}):Play()
		Debris:AddItem(f, t + 0.1)
	end
end

local function rarityColor(name: string): Color3
	local r = Config.RarityByName[name]
	return r and r.color or Color3.new(1, 1, 1)
end

local function revealSlime(d)
	local r = Config.RarityByName[d.rarity]
	local color = r.color
	if d.rarity == "Secret" then
		color = Color3.new(1, 1, 1)
	end
	local sub = d.name
	if d.mut then
		sub = "✨ " .. d.name .. " ✨  (x" .. Config.MutationMult(d.mut) .. " income)"
	end
	announce(d.rarity:upper() .. "!", color, sub, if d.mut then Config.MutationByName[d.mut].color else nil)
	if r.order >= 5 or d.mut then
		flash(color, 0.55, 0.8)
		shake(r.order * 0.25)
		confetti(40 + r.order * 10)
		sound("Whoosh", 0.8)
		task.delay(0.15, sound, "Ping", 0.6, 0.9)
		task.delay(0.35, sound, "Ping", 0.9, 0.9)
		task.delay(0.55, sound, "Ping", 1.2, 0.9)
	elseif r.order >= 3 then
		flash(color, 0.3, 0.4)
		sound("Ping", 1.1, 0.8)
	else
		sound("Ping", 1.3, 0.5)
	end
end

-- Slot-machine style spin before revealing a Dispenser roll.
local function rollSpin(d)
	local names = {}
	for _, s in Config.Slimes do
		if s.rarity ~= "Exclusive" then
			table.insert(names, s)
		end
	end
	if d.luck and d.luck > 1 then
		subText.Text = "🍀 " .. d.luck .. "x LUCK"
	end
	local t0 = os.clock()
	local delay = 0.05
	while os.clock() - t0 < 1.4 do
		local s = names[math.random(1, #names)]
		textToken += 1
		bigText.Text = s.id
		bigText.TextColor3 = rarityColor(s.rarity)
		bigText.TextTransparency = 0
		bigText.TextStrokeTransparency = 0
		bigScale.Scale = 0.85
		subText.TextTransparency = if d.luck and d.luck > 1 then 0 else 1
		subText.TextStrokeTransparency = subText.TextTransparency
		subText.TextColor3 = Color3.fromRGB(120, 255, 140)
		sound("Click", 1.5, 0.35)
		task.wait(delay)
		delay *= 1.12
	end
	revealSlime(d)
end

-- ===== Fx dispatcher =====
local handlers = {}

handlers.buy = function(d)
	burst(d.pos, d.color, 25 + d.order * 8)
	ring(d.pos, d.color, 10 + d.order * 2)
	sound("Ping", 1 + d.order * 0.05, 0.5, d.pos)
end
handlers.reveal = function(d)
	if not d.quiet then
		revealSlime(d)
	end
end
handlers.land = function(d)
	burst(d.pos + Vector3.new(0, 2, 0), d.color, if d.big then 60 else 25, { speed = 10 })
	ring(d.pos, d.color, if d.big then 16 else 9)
	burst(d.pos, Color3.fromRGB(230, 230, 230), 10, { texture = SMOKE, light = 0, size = 3, speed = 4, gravity = 2 })
	sound("Snap", 1.2, 0.5, d.pos)
end
handlers.collect = function(d)
	burst(d.pos + Vector3.new(0, 1, 0), Color3.fromRGB(255, 215, 50), math.clamp(10 + math.floor(math.log10(d.amount + 1) * 8), 10, 70), { speed = 18, gravity = -40 })
	popText(d.pos, "+" .. Util.Money(d.amount), Color3.fromRGB(255, 225, 60))
	sound("Ping", 1.6, 0.7)
	task.delay(0.08, sound, "Ping", 2, 0.5)
end
handlers.rebirth = function(d)
	flash(Color3.new(1, 1, 1), 0.95, 1.4)
	shake(2.5)
	confetti(150)
	announce("REBIRTH " .. d.n .. "!", Color3.fromRGB(200, 140, 255), "Income x" .. (1 + d.n * Config.RebirthIncomeBonus) .. " forever", Color3.fromRGB(255, 230, 120), 2.5)
	sound("Whoosh", 0.6, 1)
	for i = 0, 4 do
		task.delay(0.15 * i, sound, "Ping", 0.7 + i * 0.15, 0.8)
	end
end
handlers.grow = function()
	sound("Snap", 0.8, 0.6)
	announce("YOUR SLIMES GREW!", Color3.fromRGB(120, 255, 160), "Bigger slimes, more cash", nil, 1.5)
end
handlers.deny = function()
	sound("Click", 0.6, 0.6)
	flash(Color3.fromRGB(255, 60, 70), 0.15, 0.25)
end
handlers.rareSpawn = function(d)
	pillar(d.pos, d.color)
	burst(d.pos + Vector3.new(0, 8, 0), d.color, 80, { speed = 25, size = 1.6 })
	sound("Whoosh", 0.9, 0.8)
end
handlers.dispense = function(d)
	burst(d.pos + Vector3.new(0, 3, -5), d.color, 30 + d.order * 6, { speed = 15 })
	sound("Whoosh", 1.4, 0.5, d.pos)
end
handlers.roll = function(d)
	task.spawn(rollSpin, d)
end
handlers.luck = function()
	flash(Color3.fromRGB(80, 255, 120), 0.4, 0.6)
	announce("🍀 5x LUCK! 🍀", Color3.fromRGB(120, 255, 140), "Roll the Slime Dispenser now!", nil, 2)
	confetti(60)
	sound("Ping", 1.4, 0.8)
end
handlers.alarm = function(d)
	announce("🚨 THIEF! 🚨", Color3.fromRGB(255, 60, 70), d.thief .. " is stealing your " .. (d.slime or "slime") .. "! CATCH THEM!", Color3.new(1, 1, 1), 2.5)
	for i = 0, 5 do
		task.delay(i * 0.3, function()
			flash(Color3.fromRGB(255, 0, 30), 0.35, 0.25)
			sound("Ping", if i % 2 == 0 then 2 else 1.6, 0.9)
		end)
	end
	shake(1.2)
end
handlers.grab = function()
	sound("Whoosh", 1.1, 0.8)
	announce("RUN!", Color3.fromRGB(255, 220, 60), "Get back to your base before they catch you!", nil, 1.6)
end
handlers.stealWin = function()
	confetti(90)
	flash(Color3.fromRGB(255, 220, 60), 0.4, 0.6)
	announce("NICE!", Color3.fromRGB(255, 220, 60), nil, nil, 1.4)
	sound("Ping", 1, 0.8)
	task.delay(0.12, sound, "Ping", 1.3, 0.8)
end
local askedPhoneAlerts = false
handlers.stolen = function()
	flash(Color3.fromRGB(255, 0, 30), 0.5, 0.8)
	shake(1)
	sound("Oof", 1, 0.6)
	-- The first time you're robbed in a session, offer phone alerts for next time.
	-- (Roblox shows its own prompt, at most once a month, and only to players who can get them.)
	if not askedPhoneAlerts then
		askedPhoneAlerts = true
		task.delay(4, function()
			local ens = game:GetService("ExperienceNotificationService")
			local ok, can = pcall(ens.CanPromptOptInAsync, ens)
			if ok and can then
				announce("📱 GET STEAL ALERTS", Color3.fromRGB(120, 200, 255), "Turn on notifications and we'll tell you when someone robs you.", nil, 2.5)
				task.wait(1.5)
				pcall(ens.PromptOptIn, ens)
			end
		end)
	end
end
handlers.intruder = function(d)
	announce("👀 INTRUDER", Color3.fromRGB(255, 170, 60), d.name .. " is in your base!", nil, 1.4)
	sound("Ping", 2.2, 0.6)
	task.delay(0.15, sound, "Ping", 2.2, 0.6)
end
handlers.caught = function()
	flash(Color3.fromRGB(255, 0, 30), 0.5, 0.6)
	shake(1.6)
	announce("CAUGHT!", Color3.fromRGB(255, 60, 70), "The slime is bouncing home...", nil, 1.6)
	sound("Oof", 1, 0.7)
end
handlers.hop = function(d)
	burst(d.pos, Color3.fromRGB(240, 240, 240), 6, { texture = SMOKE, light = 0, size = 2, speed = 4, gravity = 2 })
	sound("Jump", 1.3, 0.4, d.pos)
end
handlers.merge = function(d)
	-- Three glowing orbs fly from their pens into the merged slime's pen.
	for _, from in d.from do
		local orb = Instance.new("Part")
		orb.Shape = Enum.PartType.Ball
		orb.Anchored = true
		orb.CanCollide = false
		orb.CanQuery = false
		orb.Material = Enum.Material.Neon
		orb.Color = d.color
		orb.Size = Vector3.one * 2.5
		orb.Position = from + Vector3.new(0, 3, 0)
		orb.Parent = fxFolder
		local mid = (from + d.to) / 2 + Vector3.new(0, 12, 0)
		TweenService:Create(orb, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = mid }):Play()
		task.delay(0.35, function()
			TweenService:Create(orb, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = d.to + Vector3.new(0, 3, 0), Size = Vector3.one }):Play()
		end)
		Debris:AddItem(orb, 0.7)
	end
	task.delay(0.65, function()
		burst(d.to + Vector3.new(0, 3, 0), d.color, 80, { speed = 22, size = 1.6 })
		burst(d.to + Vector3.new(0, 3, 0), Color3.fromRGB(255, 225, 90), 50, { speed = 15 })
		ring(d.to, Color3.fromRGB(255, 225, 90), 22)
		pillar(d.to, Color3.fromRGB(255, 225, 90))
		sound("Snap", 0.8, 0.8, d.to)
	end)
end
handlers.merged = function(d)
	task.delay(0.65, function()
		announce("MERGED! " .. string.rep("★", d.stars), Color3.fromRGB(255, 225, 90), d.name, nil, 2)
		flash(Color3.fromRGB(255, 225, 90), 0.5, 0.6)
		shake(1 + d.stars * 0.5)
		confetti(60 + d.stars * 30)
		sound("Whoosh", 0.7, 0.9)
		for i = 0, d.stars + 1 do
			task.delay(0.12 * i, sound, "Ping", 0.8 + i * 0.2, 0.8)
		end
	end)
end
handlers.daily = function(d)
	confetti(100)
	flash(Color3.fromRGB(255, 160, 60), 0.4, 0.6)
	announce("🎁 DAY " .. d.day .. " REWARD!", Color3.fromRGB(255, 180, 70), if d.day < 7 then "Come back tomorrow for Day " .. (d.day + 1) .. "!" else "You finished the week!", nil, 2)
	for i = 0, 3 do
		task.delay(0.1 * i, sound, "Ping", 1 + i * 0.2, 0.8)
	end
end
handlers.baseUpgrade = function(d)
	pillar(d.pos, Color3.fromRGB(255, 215, 90))
	burst(d.pos + Vector3.new(0, 4, 0), Color3.fromRGB(255, 215, 90), 70, { speed = 24, size = 1.4 })
	ring(d.pos, Color3.fromRGB(255, 255, 255), 40)
end
handlers.milestone = function(d)
	confetti(90)
	flash(Color3.fromRGB(255, 120, 200), 0.35, 0.5)
	announce(d.title, Color3.fromRGB(255, 180, 230), d.sub, nil, 2)
	for i = 0, 3 do
		task.delay(0.1 * i, sound, "Ping", 1 + i * 0.2, 0.8)
	end
end
handlers.code = function()
	confetti(80)
	sound("Ping", 1.2, 0.8)
end

handlers.swing = function(d)
	sound("Whoosh", 1.8, 0.3, d.pos)
end
handlers.slap = function(d)
	burst(d.pos, d.color or Color3.fromRGB(255, 230, 180), 25, { speed = 20 })
	ring(d.pos, d.color or Color3.fromRGB(255, 255, 255), 8)
	sound("Snap", 1.5, 1, d.pos)
end
handlers.knock = function(d)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if root and hum then
		hum:ChangeState(Enum.HumanoidStateType.Freefall)
		root.AssemblyLinearVelocity = d.dir * d.force + Vector3.new(0, d.force * 0.55 * (d.up or 1), 0)
	end
	shake(1.2)
	flash(Color3.fromRGB(255, 255, 255), 0.3, 0.3)
	announce(d.text or "SLAPPED!", Color3.fromRGB(255, 200, 150), nil, nil, 1)
end
handlers.shockwave = function(d)
	ring(d.pos, d.color or Color3.new(1, 1, 1), d.radius * 2)
	burst(d.pos, d.color or Color3.new(1, 1, 1), 30, { speed = 30 })
end
handlers.frozen = function(d)
	flash(Color3.fromRGB(120, 255, 140), 0.4, 0.5)
	announce("STUCK!", Color3.fromRGB(120, 255, 140), "Frozen for " .. d.seconds .. "s", nil, d.seconds)
	sound("Oof", 1.2, 0.6)
end
handlers.trapPlaced = function(d)
	ring(d.pos, Color3.fromRGB(120, 255, 120), 8)
	sound("Snap", 0.7, 0.6, d.pos)
end
handlers.trapped = function(d)
	burst(d.pos + Vector3.new(0, 2, 0), Color3.fromRGB(120, 255, 120), 60, { speed = 14 })
	ring(d.pos, Color3.fromRGB(120, 255, 120), 16)
	sound("Snap", 0.5, 1, d.pos)
end
handlers.zap = function(d)
	local dist = (d.to - d.from).Magnitude
	local bolt = Instance.new("Part")
	bolt.Anchored = true
	bolt.CanCollide = false
	bolt.CanQuery = false
	bolt.Material = Enum.Material.Neon
	bolt.Color = Color3.fromRGB(255, 240, 80)
	bolt.Size = Vector3.new(0.35, 0.35, dist)
	bolt.CFrame = CFrame.lookAt((d.from + d.to) / 2, d.to)
	bolt.Parent = fxFolder
	TweenService:Create(bolt, TweenInfo.new(0.35), { Transparency = 1, Size = Vector3.new(0.05, 0.05, dist) }):Play()
	Debris:AddItem(bolt, 0.4)
	burst(d.to, Color3.fromRGB(255, 240, 80), 30, { speed = 18 })
	sound("Ping", 2.4, 0.8, d.to)
end
handlers.gear = function(d)
	confetti(60)
	announce("NEW GEAR!", Color3.fromRGB(90, 200, 255), d.name, nil, 1.6)
	sound("Ping", 1.3, 0.8)
end
handlers.gift = function()
	confetti(70)
	flash(Color3.fromRGB(255, 120, 200), 0.3, 0.4)
	sound("Ping", 1.5, 0.8)
	task.delay(0.1, sound, "Ping", 1.9, 0.6)
end
handlers.questDone = function()
	sound("Ping", 1.2, 0.8)
	task.delay(0.12, sound, "Ping", 1.6, 0.8)
end
-- An event trait strikes a pen slime: a glowing orb falls from the sky onto it.
handlers.strike = function(d)
	local orb = Instance.new("Part")
	orb.Shape = Enum.PartType.Ball
	orb.Anchored = true
	orb.CanCollide = false
	orb.CanQuery = false
	orb.Material = Enum.Material.Neon
	orb.Color = d.color
	orb.Size = Vector3.one * 2.5
	orb.Position = d.pos + Vector3.new(6, 70, 4)
	orb.Parent = fxFolder
	local f = Instance.new("Fire")
	f.Color = d.color
	f.SecondaryColor = Color3.new(1, 1, 1)
	f.Size = 6
	f.Parent = orb
	TweenService:Create(orb, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = d.pos + Vector3.new(0, 2, 0) }):Play()
	task.delay(0.8, function()
		orb:Destroy()
		burst(d.pos + Vector3.new(0, 2, 0), d.color, 60, { speed = 22, size = 1.4 })
		ring(d.pos, d.color, 14)
		popText(d.pos + Vector3.new(0, 3, 0), d.icon .. " TRAIT!", d.color)
		sound("Snap", 0.6, 1, d.pos)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and (root.Position - d.pos).Magnitude < 60 then
			shake(0.6)
		end
	end)
end
handlers.upgrade = function(d)
	confetti(50)
	announce("UPGRADED!", Color3.fromRGB(120, 255, 160), d.name .. " Lv " .. d.level, nil, 1.6)
	sound("Ping", 1.1, 0.8)
	task.delay(0.12, sound, "Ping", 1.5, 0.8)
end
handlers.levelUp = function(d)
	confetti(90)
	flash(Color3.fromRGB(255, 220, 80), 0.35, 0.5)
	announce("LEVEL " .. d.level .. "!", Color3.fromRGB(255, 220, 80), if d.title then "New title: " .. d.title else nil, Color3.fromRGB(255, 255, 255), 2)
	for i = 0, 2 do
		task.delay(0.12 * i, sound, "Ping", 1 + i * 0.25, 0.8)
	end
end
-- Squirm: a carried slime wriggles (everyone sees it shake; the thief also gets the HOLD ON button).
handlers.squirm = function()
	shake(0.5)
	sound("Oof", 1.8, 0.6)
end
handlers.squirmAll = function(d)
	burst(d.pos, Color3.fromRGB(150, 255, 150), 12, { speed = 8, size = 0.8 })
	popText(d.pos, "SQUIRM!", Color3.fromRGB(150, 255, 150))
end
handlers.held = function()
	sound("Snap", 1.6, 0.5)
	announce("GOT A GRIP!", Color3.fromRGB(150, 255, 150), nil, nil, 0.8)
end
handlers.revenge = function(d)
	flash(Color3.fromRGB(255, 70, 70), 0.35, 0.5)
	announce("REVENGE!", Color3.fromRGB(255, 80, 80), "Go steal one back from " .. d.name .. ". Their shield can't stop you!", nil, 3)
end
handlers.relic = function(d)
	confetti(70)
	flash(d.color, 0.35, 0.6)
	announce(d.icon .. " NEW RELIC!", d.color, d.name .. ": " .. d.desc .. (if d.equipped then " (equipped)" else " · open 🔮 RELICS to equip"), nil, 3.5)
	sound("Ping", 0.8, 0.9)
	task.delay(0.2, sound, "Ping", 1.1, 0.9)
end

-- ===== Event drops =====
handlers.dropLand = function(d)
	ring(d.pos - Vector3.new(0, 1.4, 0), d.color, if d.lucky then 14 else 8)
	burst(d.pos, d.color, if d.lucky then 40 else 16, { speed = 14 })
	sound("Snap", if d.lucky then 0.6 else 0.9, 0.5, d.pos)
end
handlers.dropTaken = function(d)
	burst(d.pos, d.color, 24, { speed = 16 })
end
handlers.dropGrab = function(d)
	if d.lucky then
		confetti(90)
		flash(d.color, 0.35, 0.5)
	end
	announce(d.title, d.color, d.text, nil, if d.lucky then 2.5 else 1.4)
	popText(d.pos + Vector3.new(0, 3, 0), d.title, d.color)
	sound("Ping", if d.lucky then 0.9 else 1.4, 0.8)
end

-- ===== Mini games =====
handlers.fishCast = function(d)
	burst(d.pos, Color3.fromRGB(150, 255, 180), 10, { speed = 6 })
	sound("Snap", 1.6, 0.4, d.pos)
end
handlers.fishBite = function(d)
	burst(d.pos, Color3.fromRGB(150, 255, 180), 24, { speed = 12 })
	ring(d.pos, Color3.fromRGB(150, 255, 180), 6)
	sound("Ping", 1.5, 0.8)
end
handlers.fishCatch = function(d)
	if d.pos then
		burst(d.pos + Vector3.new(0, 2, 0), Color3.fromRGB(150, 255, 180), 40, { speed = 18 })
		popText(d.pos + Vector3.new(0, 5, 0), "🎣 " .. d.label .. "!", Color3.fromRGB(150, 255, 180))
	end
	if d.rare then
		confetti(80)
		announce("🎣 BIG CATCH!", Color3.fromRGB(150, 255, 180), d.text, nil, 2.5)
	else
		announce("🎣 CAUGHT!", Color3.fromRGB(150, 255, 180), d.text, nil, 1.4)
	end
	sound("Ping", 1.2, 0.8)
end
handlers.fishMiss = function()
	announce("It got away!", Color3.fromRGB(200, 200, 220), "Wait for the bite, then tap REEL fast.", nil, 1.4)
	sound("Oof", 1.1, 0.4)
end
handlers.arcadeStart = function()
	announce("🔨 WHACK!", Color3.fromRGB(255, 140, 210), "Click or tap the slimes. Golden = 3, bombs = -2!", nil, 2)
	sound("Ping", 1, 0.8)
end
handlers.whack = function(d)
	burst(d.pos, d.color, 14, { speed = 12 })
	popText(d.pos + Vector3.new(0, 2, 0), (if d.points > 0 then "+" else "") .. d.points, if d.points > 0 then Color3.fromRGB(255, 230, 120) else Color3.fromRGB(255, 80, 80))
	sound(if d.points > 0 then "Snap" else "Oof", if d.points > 1 then 1.8 else 1.3, 0.6)
end
handlers.arcadeEnd = function(d)
	if d.record then
		confetti(100)
	end
	announce("🔨 SCORE " .. d.score .. (if d.record then " · RECORD!" else ""), Color3.fromRGB(255, 140, 210), d.text, nil, 2.5)
	sound("Ping", 1.3, 0.8)
end
handlers.towerStart = function()
	announce("🗼 GO!", Color3.fromRGB(180, 150, 255), "Climb to the chest at the top!", nil, 1.5)
	sound("Ping", 1.4, 0.7)
end
handlers.towerWin = function(d)
	confetti(120)
	flash(Color3.fromRGB(255, 230, 140), 0.4, 0.6)
	announce(string.format("🗼 TOP! %.1fs", d.seconds) .. (if d.record then " · RECORD!" else ""), Color3.fromRGB(255, 220, 120), d.text, nil, 3)
	burst(d.pos, Color3.fromRGB(255, 220, 120), 80, { speed = 24 })
	sound("Ping", 0.9, 0.9)
	task.delay(0.15, sound, "Ping", 1.2, 0.9)
end
handlers.tutorialStep = function()
	sound("Ping", 1.5, 0.7)
end
handlers.tutorialDone = function(d)
	confetti(90)
	announce("🧭 YOU'RE READY!", Color3.fromRGB(255, 210, 80), d.text .. ". Now go grow, steal and rebirth!", nil, 3)
	sound("Ping", 1.1, 0.9)
end
handlers.seasonTier = function(d)
	announce("🌟 SEASON TIER " .. d.tier .. "!", Color3.fromRGB(255, 200, 70), "Open 🌟 SEASON to claim your reward.", nil, 2)
	sound("Ping", 1.6, 0.8)
end
handlers.seasonClaim = function()
	confetti(40)
	sound("Ping", 1.3, 0.7)
end
-- Bounce pads on the Sky Tower: launch upward when you land on one.
local lastBounce = 0
local function hookBounce(pad: Instance)
	if not pad:IsA("BasePart") then
		return
	end
	local bp = pad :: BasePart
	bp.Touched:Connect(function(hit)
		local char = Players.LocalPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and hit:IsDescendantOf(char) and os.clock() - lastBounce > 0.6 then
			lastBounce = os.clock()
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(v.X, 82, v.Z)
			sound("Jump", 1.3, 0.8)
			burst(bp.Position + Vector3.new(0, 1, 0), Color3.fromRGB(255, 80, 200), 20, { speed = 14 })
		end
	end)
end
for _, p in CollectionService:GetTagged("BouncePad") do
	hookBounce(p)
end
CollectionService:GetInstanceAddedSignal("BouncePad"):Connect(hookBounce)

-- Slime Snacks
handlers.snack = function(d)
	sound("Ping", 1.8, 0.5)
	local char = Players.LocalPlayer.Character
	local head = char and char:FindFirstChild("Head") :: BasePart?
	if head then
		popText(head.Position + Vector3.new(0, 3, 0), d.icon .. " +" .. d.count, Color3.fromRGB(255, 200, 120))
	end
end
handlers.fed = function(d)
	if d.pos then
		burst(d.pos + Vector3.new(0, 3, 0), d.color, 18, { speed = 10 })
		popText(d.pos + Vector3.new(0, 6, 0), d.icon .. " " .. d.n .. "/" .. d.of, d.color)
		sound("Snap", 1.4 + d.n * 0.1, 0.6, d.pos)
	end
end
handlers.evolve = function(d)
	if d.pos then
		pillar(d.pos, d.color)
		ring(d.pos, d.color, 16)
		burst(d.pos + Vector3.new(0, 4, 0), d.color, 70, { speed = 24, size = 1.4 })
		sound("Whoosh", 1.2, 0.8, d.pos)
	end
end
handlers.evolved = function(d)
	confetti(90)
	flash(Color3.fromRGB(255, 220, 140), 0.35, 0.5)
	announce(d.icon .. " EVOLVED!", Color3.fromRGB(255, 200, 100), d.name .. (if d.new then " · NEW in your Diet Book!" else ""), nil, 3)
	sound("Ping", 1, 0.9)
	task.delay(0.15, sound, "Ping", 1.35, 0.9)
end

handlers.nemesis = function(d)
	flash(Color3.fromRGB(150, 40, 200), 0.4, 0.6)
	shake(1)
	sound("Whoosh", 0.4, 1)
	announce("☠️ NEMESIS!", Color3.fromRGB(200, 90, 255), d.name .. " robbed you twice. You're faster near them and their bounty pays +50%.", nil, 3.5)
end
handlers.avenged = function(d)
	local mine = d.id == Players.LocalPlayer.UserId
	if mine then
		confetti(120)
		flash(Color3.fromRGB(255, 215, 60), 0.4, 0.6)
		announce("AVENGED!", Color3.fromRGB(255, 215, 60), "You got even with " .. d.on .. "!", nil, 3)
		sound("Ping", 0.9, 0.9)
		task.delay(0.15, sound, "Ping", 1.2, 0.9)
		task.delay(0.3, sound, "Ping", 1.5, 0.9)
	else
		sound("Ping", 1.4, 0.4)
	end
end
handlers.bounty = function(d)
	confetti(60)
	announce("BOUNTY!", Color3.fromRGB(255, 215, 60), "+" .. Util.Money(d.amount), nil, 1.6)
	sound("Ping", 1.2, 0.8)
	task.delay(0.12, sound, "Ping", 1.6, 0.8)
end

-- King Slime boss
handlers.kingSpawn = function(d)
	announce("👑 KING SLIME!", Color3.fromRGB(150, 255, 100), "Slap it together for big rewards!", nil, 3)
	flash(Color3.fromRGB(150, 255, 100), 0.4, 0.6)
	sound("Whoosh", 0.5, 1)
	task.delay(1.2, function()
		shake(2)
		burst(d.pos + Vector3.new(0, 2, 0), Color3.fromRGB(150, 255, 100), 90, { speed = 30, size = 1.8 })
		ring(d.pos, Color3.fromRGB(150, 255, 100), 30)
		sound("Snap", 0.3, 1, d.pos)
	end)
end
handlers.kingIncoming = function(d)
	-- A dark shadow grows on the ground where the King will land.
	local shadow = Instance.new("Part")
	shadow.Shape = Enum.PartType.Cylinder
	shadow.Anchored = true
	shadow.CanCollide = false
	shadow.CanQuery = false
	shadow.Material = Enum.Material.SmoothPlastic
	shadow.Color = Color3.fromRGB(20, 10, 30)
	shadow.Transparency = 0.9
	shadow.Size = Vector3.new(0.2, 2, 2)
	shadow.CFrame = CFrame.new(d.pos.X, 0.15, d.pos.Z) * CFrame.Angles(0, 0, math.pi / 2)
	shadow.Parent = fxFolder
	TweenService:Create(shadow, TweenInfo.new(d.seconds + 1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = Vector3.new(0.2, Config.King.size * 1.4, Config.King.size * 1.4), Transparency = 0.35 }):Play()
	Debris:AddItem(shadow, d.seconds + 1.5)
	announce("👑 INCOMING!", Color3.fromRGB(150, 255, 100), "Something big is falling near spawn...", nil, d.seconds)
	sound("Whoosh", 0.4, 0.8)
end
local kingFlash: Highlight? = nil
handlers.kingHit = function(d)
	local king = workspace:FindFirstChild("KingSlime")
	if king then
		if not kingFlash or kingFlash.Parent ~= king then
			local hl = Instance.new("Highlight")
			hl.FillColor = Color3.new(1, 1, 1)
			hl.OutlineTransparency = 1
			hl.Parent = king
			kingFlash = hl
		end
		local h = kingFlash :: Highlight
		h.FillTransparency = 0.2
		TweenService:Create(h, TweenInfo.new(0.25), { FillTransparency = 1 }):Play()
	end
	burst(d.pos, Color3.fromRGB(190, 255, 120), 10 + d.damage * 4, { speed = 14 })
	popText(d.pos, "-" .. d.damage, Color3.fromRGB(255, 255, 255))
	sound("Snap", 1.2 + math.random() * 0.4, 0.6, d.pos)
end
handlers.stomp = function(d)
	ring(d.pos, Color3.fromRGB(150, 255, 100), d.range * 2)
	burst(d.pos, Color3.fromRGB(150, 255, 100), 30, { speed = 20 })
	sound("Snap", 0.35, 1, d.pos)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and (root.Position - d.pos).Magnitude < d.range * 3 then
		shake(1.2)
	end
end
handlers.kingDefeated = function(d)
	confetti(120)
	flash(Color3.fromRGB(255, 220, 80), 0.5, 0.8)
	announce("KING DEFEATED!", Color3.fromRGB(255, 220, 80), "Rewards for everyone who helped!", nil, 3)
	burst(d.pos, Color3.fromRGB(150, 255, 100), 120, { speed = 35, size = 2 })
	burst(d.pos, Color3.fromRGB(255, 215, 60), 60, { speed = 25 })
	pillar(d.pos, Color3.fromRGB(255, 215, 60))
	for i = 0, 4 do
		task.delay(0.12 * i, sound, "Ping", 0.8 + i * 0.2, 0.8)
	end
end
handlers.kingEnrage = function(d)
	flash(Color3.fromRGB(255, 80, 50), 0.4, 0.6)
	announce("ENRAGED!", Color3.fromRGB(255, 90, 60), "The King Slime is almost down!", nil, 1.8)
	burst(d.pos, Color3.fromRGB(255, 90, 60), 60, { speed = 25 })
	sound("Whoosh", 0.6, 1)
end
handlers.kingReward = function(d)
	local medal = if d.rank == 1 then "🥇" elseif d.rank == 2 then "🥈" elseif d.rank == 3 then "🥉" else "👑"
	task.delay(2.5, announce, medal .. " #" .. d.rank .. " of " .. d.of, Color3.fromRGB(255, 220, 80), d.damage .. " damage · " .. d.text, nil, 2.5)
end
handlers.rookieEnd = function()
	flash(Color3.fromRGB(255, 200, 90), 0.3, 0.5)
	announce("ROOKIE SHIELD OFF", Color3.fromRGB(255, 200, 90), "Lock your base when thieves come!", nil, 2.5)
end
handlers.kingEscape = function(d)
	burst(d.pos, Color3.fromRGB(150, 255, 100), 40, { speed = 20 })
	sound("Whoosh", 0.6, 1)
end

handlers.fuseStart = function(d)
	burst(d.pos + Vector3.new(0, 6, 0), Color3.fromRGB(150, 255, 120), 50, { speed = 16 })
	burst(d.pos + Vector3.new(0, 6, 0), Color3.fromRGB(200, 120, 255), 30, { speed = 12 })
	ring(d.pos, Color3.fromRGB(150, 255, 120), 12)
	sound("Snap", 0.4, 0.8, d.pos)
end

-- Server events: tint the world, announce, and drop themed things from the sky.
local Lighting = game:GetService("Lighting")
local defaultTint = Color3.fromRGB(255, 248, 255)
handlers.event = function(d)
	local def = Config.Events[d.key]
	if not def then
		return
	end
	announce(def.title .. "!", def.tint, def.desc, nil, 3)
	flash(def.tint, 0.5, 0.8)
	confetti(80)
	sound("Whoosh", 0.8, 1)
	for i = 0, 3 do
		task.delay(0.15 * i, sound, "Ping", 0.9 + i * 0.2, 0.8)
	end
end
task.spawn(function()
	local cc = Lighting:WaitForChild("ColorCorrection", 10) or Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	local current = ""
	while true do
		task.wait(1)
		local e = workspace:GetAttribute("Event")
		local active = e and (workspace:GetAttribute("EventUntil") or 0) > workspace:GetServerTimeNow() and Config.Events[e]
		local key = if active then e else ""
		if key ~= current and cc and cc:IsA("ColorCorrectionEffect") then
			current = key
			TweenService:Create(cc, TweenInfo.new(2), { TintColor = if active then active.tint else defaultTint }):Play()
		end
	end
end)

-- ===== Slime Storm =====
-- Rain falls around the camera and lightning flashes the sky while the weekly Storm runs.
handlers.stormStart = function()
	flash(Color3.new(1, 1, 1), 0.8, 0.5)
	sound("Whoosh", 0.5, 1)
end
do
	local rainPart = Instance.new("Part")
	rainPart.Name = "StormRain"
	rainPart.Anchored = true
	rainPart.CanCollide = false
	rainPart.CanQuery = false
	rainPart.CanTouch = false
	rainPart.Transparency = 1
	rainPart.Size = Vector3.new(70, 1, 70)
	local rain = Instance.new("ParticleEmitter")
	rain.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	rain.Texture = "rbxasset://textures/particles/smoke_main.dds"
	rain.Color = ColorSequence.new(Color3.fromRGB(210, 220, 255))
	rain.Size = NumberSequence.new(0.6)
	rain.Squash = NumberSequence.new(2.5)
	rain.Transparency = NumberSequence.new(0.1)
	rain.Lifetime = NumberRange.new(0.8, 1)
	rain.Speed = NumberRange.new(55, 65)
	rain.EmissionDirection = Enum.NormalId.Bottom
	rain.Rate = 700
	rain.LightEmission = 0.3
	rain.Parent = rainPart
	local nextBolt = 0
	local wasOn = false
	RunService.Heartbeat:Connect(function()
		local on = workspace:GetAttribute("Event") == "SlimeStorm" and (workspace:GetAttribute("EventUntil") or 0) > workspace:GetServerTimeNow()
		if on ~= wasOn then
			-- Storm clouds: a darker, moodier sky while it runs.
			wasOn = on
			TweenService:Create(Lighting, TweenInfo.new(3), { ExposureCompensation = if on then -0.7 else 0 }):Play()
		end
		if not on then
			rainPart.Parent = nil
			return
		end
		rainPart.Parent = workspace
		rainPart.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 28, 0))
		if os.clock() > nextBolt then
			nextBolt = os.clock() + 6 + math.random() * 9
			flash(Color3.fromRGB(220, 220, 255), 0.55, 0.25)
			task.delay(0.12, flash, Color3.fromRGB(220, 220, 255), 0.35, 0.2)
			task.delay(0.4 + math.random(), sound, "Whoosh", 0.35, 0.8)
		end
	end)
end

-- ===== Blackout =====
-- Lights out: dark world, a flashlight on you, a faint glow on every pen slime,
-- and a heartbeat when the Gloom gets close.
local darkProps = {
	Brightness = 0,
	ClockTime = 0.5,
	Ambient = Color3.fromRGB(14, 10, 26),
	OutdoorAmbient = Color3.fromRGB(22, 16, 40),
	ExposureCompensation = -0.4,
}
local savedLighting: { [string]: any }? = nil
local savedAtmosphere: number? = nil
local glowConn: RBXScriptConnection? = nil
local myLights: { Instance } = {}

local function addSlimeGlow(model: Instance)
	local body = model:IsA("Model") and model.PrimaryPart
	if body and not body:FindFirstChild("BlackoutGlow") then
		local l = Instance.new("PointLight")
		l.Name = "BlackoutGlow"
		l.Color = body.Color
		l.Range = 9
		l.Brightness = 0.8
		l.Parent = body
	end
end

local function addMyLights()
	for _, l in myLights do
		l:Destroy()
	end
	table.clear(myLights)
	local root = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local spot = Instance.new("SpotLight")
	spot.Name = "Flashlight"
	spot.Face = Enum.NormalId.Front
	spot.Angle = 70
	spot.Range = 45
	spot.Brightness = 4
	spot.Color = Color3.fromRGB(255, 240, 210)
	spot.Shadows = true
	spot.Parent = root
	local aura = Instance.new("PointLight")
	aura.Name = "SelfLight"
	aura.Range = 12
	aura.Brightness = 0.7
	aura.Color = Color3.fromRGB(180, 170, 255)
	aura.Parent = root
	myLights = { spot, aura }
end

local function setDark(on: boolean)
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if on then
		if savedLighting then
			return
		end
		local saved = {}
		for k in darkProps do
			saved[k] = (Lighting :: any)[k]
		end
		savedLighting = saved
		TweenService:Create(Lighting, TweenInfo.new(1.5), darkProps):Play()
		if atm then
			savedAtmosphere = atm.Density
			TweenService:Create(atm, TweenInfo.new(1.5), { Density = 0.55 }):Play()
		end
		for _, m in CollectionService:GetTagged("PenSlime") do
			addSlimeGlow(m)
		end
		glowConn = CollectionService:GetInstanceAddedSignal("PenSlime"):Connect(function(m)
			task.defer(addSlimeGlow, m)
		end)
		addMyLights()
	else
		if not savedLighting then
			return
		end
		TweenService:Create(Lighting, TweenInfo.new(2), savedLighting):Play()
		savedLighting = nil
		if atm and savedAtmosphere then
			TweenService:Create(atm, TweenInfo.new(2), { Density = savedAtmosphere }):Play()
		end
		if glowConn then
			glowConn:Disconnect()
			glowConn = nil
		end
		for _, m in CollectionService:GetTagged("PenSlime") do
			local g = m:IsA("Model") and m.PrimaryPart and m.PrimaryPart:FindFirstChild("BlackoutGlow")
			if g then
				g:Destroy()
			end
		end
		for _, l in myLights do
			l:Destroy()
		end
		table.clear(myLights)
	end
end
local function blackoutActive(): boolean
	return (workspace:GetAttribute("BlackoutUntil") or 0) > workspace:GetServerTimeNow()
end
workspace:GetAttributeChangedSignal("BlackoutUntil"):Connect(function()
	setDark(blackoutActive())
end)
Players.LocalPlayer.CharacterAdded:Connect(function(char)
	char:WaitForChild("HumanoidRootPart", 10)
	if blackoutActive() then
		addMyLights()
	end
end)
task.defer(function()
	if blackoutActive() then
		setDark(true)
	end
end)
-- Heartbeat: faster and louder the closer the Gloom is.
task.spawn(function()
	while true do
		local gloom = workspace:FindFirstChild("Gloom") :: Model?
		local root = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if gloom and gloom.PrimaryPart and root then
			local d = (gloom.PrimaryPart.Position - root.Position).Magnitude
			if d < 60 then
				local near = 1 - d / 60
				sound("Snap", 0.22, 0.25 + near * 0.6)
				task.delay(0.18, sound, "Snap", 0.2, 0.2 + near * 0.5)
				if d < 20 then
					shake(0.4 * near)
				end
				task.wait(1.1 - near * 0.7)
				continue
			end
		end
		task.wait(0.5)
	end
end)
handlers.blackoutWarn = function(d)
	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	announce("⚡ FLICKER...", Color3.fromRGB(200, 200, 255), "A Blackout is coming. Get home or get ready!", nil, 2.5)
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < d.seconds and cc do
			cc.Brightness = -0.35
			task.wait(math.random(4, 14) / 100)
			cc.Brightness = 0
			task.wait(math.random(20, 70) / 100)
		end
	end)
	sound("Whoosh", 0.3, 0.8)
end
handlers.blackout = function()
	flash(Color3.new(0, 0, 0), 0.9, 1.2)
	shake(1)
	sound("Whoosh", 0.25, 1)
	announce("🌑 BLACKOUT!", Color3.fromRGB(170, 140, 255), "Locks are down! Steal in the dark, but stay away from the Gloom!", nil, 3.5)
	setDark(true)
end
handlers.blackoutEnd = function()
	setDark(false)
	flash(Color3.fromRGB(255, 250, 220), 0.5, 0.8)
	announce("💡 POWER'S BACK", Color3.fromRGB(255, 240, 160), "Lock your base!", nil, 2)
	sound("Ping", 1.1, 0.7)
end
handlers.gloomCatch = function(d)
	burst(d.pos, Color3.fromRGB(30, 0, 50), 40, { speed = 18, size = 1.6 })
	sound("Oof", 0.7, 0.6, d.pos)
end
handlers.gloomCaught = function(d)
	flash(Color3.new(0, 0, 0), 1, 1.4)
	shake(3)
	sound("Whoosh", 0.4, 1)
	announce("👻 BOO!", Color3.fromRGB(255, 60, 90), if d.dropped then "The Gloom got you! Your stolen slime hopped home." else "The Gloom sent you home!", nil, 2.5)
end

local EVENT_DROPS = {
	LavaStorm = { colors = { Color3.fromRGB(255, 90, 20), Color3.fromRGB(255, 160, 40) }, size = { 18, 34 }, rate = 0.15, fire = true },
	CandyParty = { colors = { Color3.fromRGB(255, 130, 200), Color3.fromRGB(150, 230, 255), Color3.fromRGB(255, 240, 120) }, size = { 8, 16 }, rate = 0.08 },
	GoldenHour = { colors = { Color3.fromRGB(255, 215, 60) }, size = { 4, 10 }, rate = 0.1 },
}
task.spawn(function()
	while true do
		local e = workspace:GetAttribute("Event")
		local style = e and (workspace:GetAttribute("EventUntil") or 0) > workspace:GetServerTimeNow() and EVENT_DROPS[e]
		if not style then
			task.wait(1)
			continue
		end
		task.wait(style.rate)
		local drop = Instance.new("Part")
		drop.Shape = Enum.PartType.Ball
		drop.Anchored = true
		drop.CanCollide = false
		drop.CanQuery = false
		drop.Material = Enum.Material.Neon
		drop.Color = style.colors[math.random(1, #style.colors)]
		drop.Size = Vector3.one * (math.random(style.size[1], style.size[2]) / 10)
		local x, z = math.random(-210, 210), math.random(-140, 140)
		drop.Position = Vector3.new(x + 20, 90, z)
		drop.Parent = fxFolder
		if style.fire then
			local f = Instance.new("Fire")
			f.Heat = 12
			f.Size = drop.Size.X * 2
			f.Color = drop.Color
			f.Parent = drop
		end
		local fall = math.random(15, 25) / 10
		TweenService:Create(drop, TweenInfo.new(fall, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = Vector3.new(x, 0.5, z) }):Play()
		task.delay(fall, function()
			if drop.Parent then
				burst(drop.Position, drop.Color, if style.fire then 14 else 6, { speed = 10, size = 0.9 })
				drop:Destroy()
			end
		end)
	end
end)

FxEvent.OnClientEvent:Connect(function(kind, data)
	local h = handlers[kind]
	if h then
		local ok, err = pcall(h, data or {})
		if not ok then
			warn("[Effects]", kind, err)
		end
	end
end)

-- ===== Ambient animation =====
type Anim = { inst: Instance, base: CFrame, phase: number }
local penSlimes: { [Model]: Anim } = {}
local floaters: { [BasePart]: Anim } = {}
local spinners: { [Model]: Anim } = {}
local pulsers: { [BasePart]: Color3 } = {}
local rainbows: { [BasePart]: boolean } = {}

local function track(tag, map, getBase)
	local function add(inst)
		task.defer(function()
			if inst.Parent then
				map[inst] = getBase(inst)
			end
		end)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(add)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(inst)
		map[inst] = nil
	end)
	for _, inst in CollectionService:GetTagged(tag) do
		add(inst)
	end
end

track("PenSlime", penSlimes, function(m)
	return { inst = m, base = m:GetPivot(), phase = math.random() * 10 }
end)
track("Float", floaters, function(p)
	return { inst = p, base = p.CFrame, phase = math.random() * 10 }
end)
track("Spin", spinners, function(m)
	return { inst = m, base = m:GetPivot(), phase = 0 }
end)
local sirens: { [Instance]: boolean } = {}
track("Siren", sirens, function()
	return true
end)
track("Pulse", pulsers, function(p)
	return p.Color
end)
track("Rainbow", rainbows, function()
	return true
end)

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	local camPos = camera.CFrame.Position
	for m, a in penSlimes do
		if not m.Parent or not m.PrimaryPart then
			penSlimes[m] = nil
			continue
		end
		if (a.base.Position - camPos).Magnitude > 140 then
			continue
		end
		-- Bounce with a little squash-like tilt; bigger slimes bounce slower.
		local size = m:GetAttribute("Size") or 3
		local speed = 6 / math.sqrt(size)
		local hop = math.abs(math.sin(t * speed + a.phase))
		local wobble = math.sin(t * speed * 0.5 + a.phase) * 0.12
		m:PivotTo(a.base * CFrame.new(0, hop * size * 0.3, 0) * CFrame.Angles(0, wobble, wobble * 0.5))
	end
	for p, a in floaters do
		if not p.Parent then
			floaters[p] = nil
			continue
		end
		p.CFrame = a.base * CFrame.new(0, math.sin(t + a.phase) * 1.5, 0) * CFrame.Angles(0, t * 0.8, 0)
	end
	for p in sirens do
		if not p.Parent then
			sirens[p] = nil
		elseif (p :: BasePart).Transparency < 1 then
			local bp = p :: BasePart
			bp.CFrame = CFrame.new(bp.Position) * CFrame.Angles(0, t * 9, 0)
		end
	end
	for m, a in spinners do
		if not m.Parent then
			spinners[m] = nil
			continue
		end
		m:PivotTo(a.base * CFrame.Angles(0, t * 1.5, 0))
	end
	local pulse = (math.sin(t * 3) + 1) / 2
	for p, base in pulsers do
		if not p.Parent then
			pulsers[p] = nil
			continue
		end
		p.Color = base:Lerp(Color3.new(1, 1, 1), pulse * 0.45)
	end
	for p in rainbows do
		if not p.Parent then
			rainbows[p] = nil
			continue
		end
		p.Color = Color3.fromHSV((t * 0.25) % 1, 0.75, 1)
	end
end)

-- ===== Slime Rain: glowing drops fall from the sky over the belt =====
local dropColors = { Color3.fromRGB(120, 255, 160), Color3.fromRGB(255, 120, 220), Color3.fromRGB(120, 180, 255), Color3.fromRGB(255, 220, 80) }
task.spawn(function()
	while true do
		task.wait(0.06)
		local untilT = workspace:GetAttribute("RainUntil") or 0
		if untilT > workspace:GetServerTimeNow() then
			local drop = Instance.new("Part")
			drop.Shape = Enum.PartType.Ball
			drop.Anchored = true
			drop.CanCollide = false
			drop.CanQuery = false
			drop.Material = Enum.Material.Neon
			drop.Color = dropColors[math.random(1, #dropColors)]
			drop.Size = Vector3.one * (math.random(10, 22) / 10)
			local x, z = math.random(-130, 130), math.random(-40, 40)
			drop.Position = Vector3.new(x, 80, z)
			drop.Parent = fxFolder
			local fall = math.random(12, 20) / 10
			TweenService:Create(drop, TweenInfo.new(fall, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = Vector3.new(x, 0.5, z) }):Play()
			task.delay(fall, function()
				if drop.Parent then
					burst(drop.Position, drop.Color, 6, { speed = 8, size = 0.8 })
					drop:Destroy()
				end
			end)
		end
	end
end)
