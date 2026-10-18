-- Event weather: every event changes the sky to match it. The clouds, the air colour, the
-- time of day and something falling or floating around the camera all blend in when the
-- event starts and blend back out when it ends. The Slime Storm's rain and lightning and the
-- Blackout's darkness live in Effects.client; this adds their clouds on top. During a holiday
-- (Halloween...) its own sky shows whenever no event is running.

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local camera = workspace.CurrentCamera
local clouds = workspace.Terrain:WaitForChild("Clouds", 10) :: Clouds?
local atm = Lighting:WaitForChild("Atmosphere", 10) :: Atmosphere?

local function seq(...: Color3): ColorSequence
	local colors = { ... }
	if #colors == 1 then
		return ColorSequence.new(colors[1])
	end
	local keys = {}
	for i, c in colors do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), c))
	end
	return ColorSequence.new(keys)
end

-- clouds = Clouds props, air = Atmosphere colours/haze, time = ClockTime, fall = particles
-- around the camera (rise = they float up instead of falling).
local PROFILES = {
	GoldenHour = {
		clouds = { Cover = 0.6, Density = 0.5, Color = Color3.fromRGB(255, 215, 150) },
		air = { Color = Color3.fromRGB(255, 220, 160), Decay = Color3.fromRGB(230, 150, 80), Haze = 1.2 },
		time = 17.4,
		fall = { texture = SPARKLE, color = seq(Color3.fromRGB(255, 225, 120)), rate = 60, speed = 3, size = 0.35, light = 0.6, rise = true },
	},
	LavaStorm = {
		clouds = { Cover = 0.85, Density = 0.8, Color = Color3.fromRGB(90, 60, 55) },
		air = { Color = Color3.fromRGB(235, 130, 90), Decay = Color3.fromRGB(150, 50, 25), Haze = 1.2 },
		time = 18.2,
		fall = { texture = FIRE, color = seq(Color3.fromRGB(255, 160, 60), Color3.fromRGB(255, 70, 20)), rate = 90, speed = 6, size = 0.3, light = 0.8, rise = true },
	},
	CandyParty = {
		clouds = { Cover = 0.65, Density = 0.55, Color = Color3.fromRGB(255, 190, 230) },
		air = { Color = Color3.fromRGB(255, 205, 235), Decay = Color3.fromRGB(200, 140, 230), Haze = 0.8 },
		time = 15,
		fall = {
			texture = SPARKLE,
			color = seq(Color3.fromRGB(255, 120, 190), Color3.fromRGB(120, 220, 255), Color3.fromRGB(255, 240, 120), Color3.fromRGB(170, 255, 150)),
			rate = 120, speed = 9, size = 0.3, light = 0.2,
		},
	},
	CashFrenzy = {
		clouds = { Cover = 0.35, Density = 0.4, Color = Color3.fromRGB(240, 255, 240) },
		air = { Color = Color3.fromRGB(215, 245, 215), Decay = Color3.fromRGB(110, 170, 110), Haze = 0.3 },
		time = 13,
		fall = { texture = SPARKLE, color = seq(Color3.fromRGB(120, 230, 120), Color3.fromRGB(255, 220, 90)), rate = 80, speed = 8, size = 0.4, light = 0.3 },
	},
	LuckyHour = {
		clouds = { Cover = 0.55, Density = 0.5, Color = Color3.fromRGB(195, 255, 200) },
		air = { Color = Color3.fromRGB(185, 240, 190), Decay = Color3.fromRGB(80, 170, 110), Haze = 1 },
		time = 10,
		fall = { texture = SPARKLE, color = seq(Color3.fromRGB(110, 240, 130), Color3.fromRGB(200, 255, 170)), rate = 90, speed = 2.5, size = 0.4, light = 0.6, rise = true },
	},
	SlimeStorm = {
		clouds = { Cover = 0.95, Density = 0.9, Color = Color3.fromRGB(80, 80, 105) },
		air = { Color = Color3.fromRGB(150, 150, 185), Decay = Color3.fromRGB(70, 70, 110), Haze = 2.2 },
	},
	Blackout = {
		clouds = { Cover = 0.9, Density = 0.85, Color = Color3.fromRGB(40, 35, 60) },
	},
	SlimeRain = {
		clouds = { Cover = 0.75, Density = 0.6, Color = Color3.fromRGB(200, 240, 210) },
		air = { Color = Color3.fromRGB(205, 240, 220), Decay = Color3.fromRGB(110, 170, 150), Haze = 0.9 },
	},
	PumpkinNight = {
		clouds = { Cover = 0.8, Density = 0.7, Color = Color3.fromRGB(110, 70, 120) },
		air = { Color = Color3.fromRGB(240, 150, 90), Decay = Color3.fromRGB(110, 40, 120), Haze = 1.6 },
		time = 18.6,
		fall = { texture = SPARKLE, color = seq(Color3.fromRGB(255, 150, 40), Color3.fromRGB(170, 90, 255)), rate = 70, speed = 2.5, size = 0.4, light = 0.7, rise = true },
	},
	-- Holidays: how the sky looks all holiday long when no event is running.
	Halloween = {
		clouds = { Cover = 0.7, Density = 0.6, Color = Color3.fromRGB(190, 140, 200) },
		air = { Color = Color3.fromRGB(235, 175, 150), Decay = Color3.fromRGB(120, 60, 140), Haze = 1.4 },
		time = 17.7,
	},
	King = {
		clouds = { Cover = 0.9, Density = 0.85, Color = Color3.fromRGB(85, 55, 105) },
		air = { Color = Color3.fromRGB(175, 130, 200), Decay = Color3.fromRGB(80, 30, 90), Haze = 1.8 },
		time = 18.4,
		fall = { texture = SMOKE, color = seq(Color3.fromRGB(150, 90, 200)), rate = 25, speed = 2, size = 1.2, light = 0.3, rise = true },
	},
}

-- What the sky looks like with no event, read once from the map's own setup.
local base = {
	clouds = clouds and { Cover = clouds.Cover, Density = clouds.Density, Color = clouds.Color },
	air = atm and { Color = atm.Color, Decay = atm.Decay, Haze = atm.Haze },
	time = Lighting.ClockTime,
}

-- The particle emitter that follows the camera.
local holder = Instance.new("Part")
holder.Name = "EventWeather"
holder.Anchored = true
holder.CanCollide = false
holder.CanQuery = false
holder.CanTouch = false
holder.Transparency = 1
holder.Size = Vector3.new(80, 1, 80)
local emitter = Instance.new("ParticleEmitter")
emitter.Enabled = false
emitter.Lifetime = NumberRange.new(4, 6)
emitter.SpreadAngle = Vector2.new(10, 10)
emitter.Rotation = NumberRange.new(0, 360)
emitter.RotSpeed = NumberRange.new(-60, 60)
emitter.Parent = holder
local rising = false

-- Same order as the music: the boss and the Blackout win over the rest.
local function wantedMode(): string?
	local now = workspace:GetServerTimeNow()
	if (workspace:GetAttribute("KingUntil") or 0) > now then
		return "King"
	end
	if (workspace:GetAttribute("BlackoutUntil") or 0) > now then
		return "Blackout"
	end
	local event = workspace:GetAttribute("Event")
	if event and (workspace:GetAttribute("EventUntil") or 0) > now and PROFILES[event] then
		return event
	end
	if (workspace:GetAttribute("RainUntil") or 0) > now then
		return "SlimeRain"
	end
	local holiday = workspace:GetAttribute("Holiday")
	if holiday and PROFILES[holiday] then
		return holiday
	end
	return nil
end

local function apply(mode: string?)
	local p = mode and PROFILES[mode] or {}
	local info = TweenInfo.new(3, Enum.EasingStyle.Sine)
	local c = p.clouds or base.clouds
	if clouds and c then
		TweenService:Create(clouds, info, c):Play()
	end
	local a = p.air or base.air
	if atm and a then
		TweenService:Create(atm, info, a):Play()
	end
	-- The Blackout sets its own time of day, so leave the clock alone while it runs.
	if mode ~= "Blackout" and (workspace:GetAttribute("BlackoutUntil") or 0) <= workspace:GetServerTimeNow() then
		TweenService:Create(Lighting, info, { ClockTime = p.time or base.time }):Play()
	end
	local f = p.fall
	emitter.Enabled = f ~= nil
	if f then
		emitter.Texture = f.texture
		emitter.Color = f.color
		-- Low Graphics (⚙️ menu) keeps a third; BaseRate lets the menu rescale it live.
		emitter:SetAttribute("BaseRate", f.rate)
		emitter.Rate = if game:GetService("Players").LocalPlayer:GetAttribute("OptLowFx") then f.rate / 3 else f.rate
		emitter.Speed = NumberRange.new(f.speed * 0.8, f.speed * 1.2)
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.15, f.size),
			NumberSequenceKeypoint.new(0.85, f.size),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.LightEmission = f.light
		emitter.EmissionDirection = if f.rise then Enum.NormalId.Top else Enum.NormalId.Bottom
		rising = f.rise == true
		holder.Parent = workspace
	else
		holder.Parent = nil
	end
end

RunService.RenderStepped:Connect(function()
	if holder.Parent then
		-- Falling things start above the camera; floating ones start around your feet.
		holder.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, if rising then -6 else 30, 0))
	end
end)

local mode: string? = nil
while true do
	local want = wantedMode()
	if want ~= mode then
		mode = want
		apply(want)
	end
	task.wait(1)
end
