-- Background music: plays Config.Music tracks one after another in a shuffled order. While an
-- event runs (Golden Hour, Blackout, Slime Rain, the Slime King...) its own track from
-- Config.EventMusic fades in and loops, then the main list comes back when it ends.
-- The 🎵 button in the bottom-right corner turns it on and off.

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(game.ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer
local tracks = Config.Music or {}
local eventTracks = Config.EventMusic or {}
if #tracks == 0 then
	return
end

local VOLUME = Config.MusicVolume or 0.3
local FADE = 1.5
local enabled = true

local sound = Instance.new("Sound")
sound.Name = "BackgroundMusic"
sound.Volume = 0
sound.Parent = SoundService

-- Shuffle once, then play through the list in a loop.
local order = {}
for i = 1, #tracks do
	table.insert(order, math.random(1, #order + 1), i)
end
local pos = 0
local mode: string? = nil -- the event whose track is playing, nil for the main list
local switching = 0

local function fadeTo(volume: number, seconds: number)
	local t = TweenService:Create(sound, TweenInfo.new(seconds), { Volume = volume })
	t:Play()
	return t
end

local function start(id: string, looped: boolean)
	sound.SoundId = id
	sound.Looped = looped
	sound.TimePosition = 0
	sound:Play()
	if enabled then
		fadeTo(VOLUME, FADE)
	end
end

-- During a holiday its own playlist (Config.HolidayMusic) replaces the main one.
local function playlist()
	local holiday = workspace:GetAttribute("Holiday")
	local list = holiday and Config.HolidayMusic and Config.HolidayMusic[holiday]
	return if list and #list > 0 then list else tracks
end

local function playNext()
	local list = playlist()
	if list ~= tracks then
		start(list[math.random(1, #list)].id, false)
		return
	end
	pos = pos % #order + 1
	start(tracks[order[pos]].id, false)
end

-- Which event's music should be on right now. The boss and the Blackout win over the rest.
local function wantedMode(): string?
	local now = workspace:GetServerTimeNow()
	if (workspace:GetAttribute("KingUntil") or 0) > now and eventTracks.King then
		return "King"
	end
	if (workspace:GetAttribute("BlackoutUntil") or 0) > now and eventTracks.Blackout then
		return "Blackout"
	end
	local event = workspace:GetAttribute("Event")
	if event and (workspace:GetAttribute("EventUntil") or 0) > now and eventTracks[event] then
		return event
	end
	if (workspace:GetAttribute("RainUntil") or 0) > now and eventTracks.SlimeRain then
		return "SlimeRain"
	end
	return nil
end

-- Fade out whatever is playing, then start the new mode's track.
local function switchTo(newMode: string?)
	mode = newMode
	switching += 1
	local ticket = switching
	if sound.IsPlaying and sound.Volume > 0 then
		fadeTo(0, FADE).Completed:Wait()
	end
	if ticket ~= switching then
		return
	end
	if newMode then
		start(eventTracks[newMode].id, true)
	else
		playNext()
	end
end

sound.Ended:Connect(function()
	if mode == nil then
		local ticket = switching
		task.wait(1.5)
		if ticket == switching and mode == nil then
			playNext()
		end
	end
end)

-- The toggle button.
local gui = Instance.new("ScreenGui")
gui.Name = "MusicToggle"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")
local button = Instance.new("TextButton")
button.AnchorPoint = Vector2.new(1, 1)
button.Position = UDim2.new(1, -12, 1, -12)
button.Size = UDim2.fromOffset(40, 40)
button.BackgroundColor3 = Color3.fromRGB(40, 34, 60)
button.BackgroundTransparency = 0.25
button.Font = Enum.Font.GothamBold
button.TextSize = 20
button.TextColor3 = Color3.new(1, 1, 1)
button.Text = "🎵"
button.Parent = gui
Instance.new("UICorner", button).CornerRadius = UDim.new(1, 0)
local strike = Instance.new("Frame")
strike.AnchorPoint = Vector2.new(0.5, 0.5)
strike.Position = UDim2.fromScale(0.5, 0.5)
strike.Size = UDim2.new(0.8, 0, 0, 3)
strike.Rotation = -45
strike.BackgroundColor3 = Color3.fromRGB(255, 90, 110)
strike.BorderSizePixel = 0
strike.Visible = false
strike.Parent = button

button.Activated:Connect(function()
	enabled = not enabled
	strike.Visible = not enabled
	fadeTo(if enabled then VOLUME else 0, 0.6)
end)

task.wait(3) -- let the game load first
mode = wantedMode()
if mode then
	start(eventTracks[mode].id, true)
else
	playNext()
end
while true do
	task.wait(1)
	local want = wantedMode()
	if want ~= mode then
		task.spawn(switchTo, want)
	end
end
