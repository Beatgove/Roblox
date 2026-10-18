-- Branded loading screen: replaces Roblox's grey default with the game's own title, a
-- bouncing slime, a progress bar and gameplay tips. It runs from ReplicatedFirst, so it
-- shows before anything else loads, and fades out once the HUD is ready (or on SKIP).

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local FONT = Enum.Font.FredokaOne
local OUTLINE = Color3.fromRGB(20, 10, 35)
local SLIME_COLORS = {
	Color3.fromRGB(120, 255, 160),
	Color3.fromRGB(255, 100, 170),
	Color3.fromRGB(90, 180, 255),
	Color3.fromRGB(255, 205, 60),
	Color3.fromRGB(190, 120, 255),
}
local TIPS = {
	"Lock your base before you go raiding!",
	"Stolen slimes squirm. Tap HOLD ON in time or they hop home.",
	"Slimes keep growing while you're offline.",
	"Robbed? You have 90 seconds of Revenge to hit back.",
	"Every steal puts a bounty on the thief. Slap them to claim it!",
	"The King Slime crashes in every few minutes. Slap it with everyone!",
	"Play with friends: +10% cash for each friend in your server.",
	"Rebirth for a permanent income boost and an extra pen.",
	"Fuse three slimes into a rarer one at the Fuse Machine.",
	"Feed slimes snacks to unlock their diet forms.",
}

local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 100
gui.Parent = playerGui
ReplicatedFirst:RemoveDefaultLoadingScreen()

local function stroke(parent: Instance, th: number)
	local s = Instance.new("UIStroke")
	s.Color = OUTLINE
	s.Thickness = th
	s.Parent = parent
	return s
end

local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.new(1, 1, 1)
bg.BorderSizePixel = 0
bg.Parent = gui
local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new(Color3.fromRGB(70, 40, 120), Color3.fromRGB(22, 14, 40))
grad.Rotation = 90
grad.Parent = bg

-- Drifting background blobs.
local blobs = {}
for i = 1, 14 do
	local b = Instance.new("Frame")
	local size = math.random(30, 90)
	b.Size = UDim2.fromOffset(size, size)
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Position = UDim2.fromScale(math.random(), math.random())
	b.BackgroundColor3 = SLIME_COLORS[(i - 1) % #SLIME_COLORS + 1]
	b.BackgroundTransparency = 0.8
	b.BorderSizePixel = 0
	b.Parent = bg
	Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
	table.insert(blobs, { frame = b, speed = 0.01 + math.random() * 0.02, phase = math.random() * 6 })
end

local content = Instance.new("Frame")
content.AnchorPoint = Vector2.new(0.5, 0.5)
content.Position = UDim2.fromScale(0.5, 0.5)
content.Size = UDim2.fromOffset(640, 420)
content.BackgroundTransparency = 1
content.Parent = bg
local contentScale = Instance.new("UIScale")
contentScale.Parent = content
local function fit()
	local vp = workspace.CurrentCamera.ViewportSize
	contentScale.Scale = math.clamp(math.min(vp.X / 700, vp.Y / 460), 0.45, 1.6)
end
fit()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)

-- The slime: a body that squashes as it lands, with eyes and a shine.
local slime = Instance.new("Frame")
slime.AnchorPoint = Vector2.new(0.5, 1)
slime.Position = UDim2.new(0.5, 0, 0, 150)
slime.Size = UDim2.fromOffset(110, 90)
slime.BackgroundColor3 = SLIME_COLORS[1]
slime.BorderSizePixel = 0
slime.Parent = content
Instance.new("UICorner", slime).CornerRadius = UDim.new(0.5, 0)
stroke(slime, 4)
local shine = Instance.new("Frame")
shine.Size = UDim2.fromScale(0.22, 0.16)
shine.Position = UDim2.fromScale(0.18, 0.14)
shine.BackgroundColor3 = Color3.new(1, 1, 1)
shine.BackgroundTransparency = 0.35
shine.BorderSizePixel = 0
shine.Parent = slime
Instance.new("UICorner", shine).CornerRadius = UDim.new(1, 0)
for _, x in { 0.32, 0.68 } do
	local eye = Instance.new("Frame")
	eye.AnchorPoint = Vector2.new(0.5, 0.5)
	eye.Size = UDim2.fromScale(0.12, 0.2)
	eye.Position = UDim2.fromScale(x, 0.45)
	eye.BackgroundColor3 = OUTLINE
	eye.BorderSizePixel = 0
	eye.Parent = slime
	Instance.new("UICorner", eye).CornerRadius = UDim.new(1, 0)
end
local shadow = Instance.new("Frame")
shadow.AnchorPoint = Vector2.new(0.5, 0.5)
shadow.Position = UDim2.new(0.5, 0, 0, 152)
shadow.Size = UDim2.fromOffset(100, 14)
shadow.BackgroundColor3 = Color3.new(0, 0, 0)
shadow.BackgroundTransparency = 0.6
shadow.BorderSizePixel = 0
shadow.Parent = content
Instance.new("UICorner", shadow).CornerRadius = UDim.new(1, 0)

local function text(t: string, size: UDim2, pos: UDim2, color: Color3, th: number)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextScaled = true
	l.TextColor3 = color
	l.Text = t
	l.Size = size
	l.Position = pos
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.Parent = content
	stroke(l, th)
	return l
end
local title = text("STEAL A SLIME", UDim2.fromOffset(620, 96), UDim2.new(0.5, 0, 0, 170), Color3.fromRGB(120, 255, 160), 5)
local titleGrad = Instance.new("UIGradient")
titleGrad.Color = ColorSequence.new(Color3.fromRGB(190, 255, 200), Color3.fromRGB(60, 220, 120))
titleGrad.Rotation = 90
titleGrad.Parent = title

local barBack = Instance.new("Frame")
barBack.AnchorPoint = Vector2.new(0.5, 0)
barBack.Position = UDim2.new(0.5, 0, 0, 290)
barBack.Size = UDim2.fromOffset(420, 22)
barBack.BackgroundColor3 = Color3.fromRGB(40, 28, 70)
barBack.BorderSizePixel = 0
barBack.Parent = content
Instance.new("UICorner", barBack).CornerRadius = UDim.new(1, 0)
stroke(barBack, 3)
local barFill = Instance.new("Frame")
barFill.Size = UDim2.fromScale(0.02, 1)
barFill.BackgroundColor3 = Color3.fromRGB(120, 255, 160)
barFill.BorderSizePixel = 0
barFill.Parent = barBack
Instance.new("UICorner", barFill).CornerRadius = UDim.new(1, 0)

local status = text("Loading slimes...", UDim2.fromOffset(420, 22), UDim2.new(0.5, 0, 0, 318), Color3.fromRGB(220, 210, 245), 2)
local tip = text("", UDim2.fromOffset(600, 30), UDim2.new(0.5, 0, 0, 360), Color3.new(1, 1, 1), 2)

local skip = Instance.new("TextButton")
skip.AnchorPoint = Vector2.new(1, 1)
skip.Position = UDim2.new(1, -20, 1, -20)
skip.Size = UDim2.fromOffset(110, 44)
skip.BackgroundColor3 = Color3.fromRGB(110, 100, 140)
skip.Font = FONT
skip.TextScaled = true
skip.TextColor3 = Color3.new(1, 1, 1)
skip.Text = "SKIP ▶"
skip.Visible = false
skip.Parent = bg
Instance.new("UICorner", skip).CornerRadius = UDim.new(0, 12)
stroke(skip, 3)

-- ===== Animation =====
local started = os.clock()
local progress = 0.02
local done = false
local tipIndex = math.random(1, #TIPS)
tip.Text = "💡 " .. TIPS[tipIndex]
local lastTip = started
local colorIndex = 1

local conn = RunService.RenderStepped:Connect(function(dt)
	local t = os.clock() - started
	-- Hop: up with a sine, squash on landing.
	local phase = (t * 1.6) % 1
	local height = math.sin(phase * math.pi) * 70
	local squash = if phase < 0.12 or phase > 0.88 then 1.25 else 1
	slime.Position = UDim2.new(0.5, 0, 0, 150 - height)
	slime.Size = UDim2.fromOffset(110 * squash, 90 / squash)
	shadow.Size = UDim2.fromOffset(100 - height * 0.6, 14)
	if phase < 0.02 and t - lastTip > 0.2 then
		colorIndex = colorIndex % #SLIME_COLORS + 1
		slime.BackgroundColor3 = SLIME_COLORS[colorIndex]
	end
	for _, b in blobs do
		local p = b.frame.Position
		local y = p.Y.Scale - b.speed * dt
		b.frame.Position = UDim2.fromScale(p.X.Scale + math.sin(t + b.phase) * 0.0005, if y < -0.1 then 1.1 else y)
	end
	if t - lastTip > 3.5 then
		lastTip = t
		tipIndex = tipIndex % #TIPS + 1
		tip.Text = "💡 " .. TIPS[tipIndex]
	end
	barFill.Size = UDim2.fromScale(barFill.Size.X.Scale + (progress - barFill.Size.X.Scale) * math.min(dt * 6, 1), 1)
end)

task.delay(4, function()
	skip.Visible = true
end)
skip.Activated:Connect(function()
	done = true
end)

-- Real progress: assets still queued, then the game and HUD being ready.
local peakQueue = 1
task.spawn(function()
	while not done do
		local queue = ContentProvider.RequestQueueSize
		peakQueue = math.max(peakQueue, queue)
		local assets = 1 - queue / peakQueue
		local stage = if game:IsLoaded() then 0.35 else 0
		local hud = if playerGui:FindFirstChild("Hud") then 0.25 else 0
		progress = math.max(progress, math.min(0.4 * assets + stage + hud, 1))
		status.Text = if not game:IsLoaded() then "Loading slimes..." elseif hud == 0 then "Building your base..." else "Ready!"
		task.wait(0.1)
	end
end)

if not game:IsLoaded() then
	game.Loaded:Wait()
end
local deadline = os.clock() + 20
while not done and not playerGui:FindFirstChild("Hud") and os.clock() < deadline do
	task.wait(0.1)
end
-- Always show at least a beat so it never just flickers.
while not done and os.clock() - started < 2.5 do
	task.wait(0.1)
end
done = true
progress = 1
task.wait(0.35)

local fade = TweenInfo.new(0.5)
TweenService:Create(bg, fade, { BackgroundTransparency = 1 }):Play()
for _, d in bg:GetDescendants() do
	if d:IsA("TextLabel") or d:IsA("TextButton") then
		TweenService:Create(d, fade, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
	elseif d:IsA("Frame") then
		TweenService:Create(d, fade, { BackgroundTransparency = 1 }):Play()
	elseif d:IsA("UIStroke") then
		TweenService:Create(d, fade, { Transparency = 1 }):Play()
	end
end
TweenService:Create(contentScale, fade, { Scale = contentScale.Scale * 1.15 }):Play()
task.wait(0.55)
conn:Disconnect()
gui:Destroy()
