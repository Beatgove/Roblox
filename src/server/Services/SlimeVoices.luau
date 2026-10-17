-- Slime voices: Roblox's text-to-speech says every slime's silly name. One AudioTextToSpeech
-- per slime lives in ReplicatedStorage.SlimeVoices; the server loads them once (text-to-speech
-- only loads on the server) and clients play them through their own speakers when a slime is
-- bought (see Effects.client "voice").

local Config = require(game.ReplicatedStorage.Shared.Config)

local SlimeVoices = {}

-- A few voices, and higher pitch for small slimes, deeper for the big ones.
local VOICES = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "10" }
local PITCH = { Common = 1.25, Uncommon = 1.2, Rare = 1.1, Epic = 1.05, Legendary = 1, Mythic = 0.95, Divine = 0.9, Secret = 0.85, Exclusive = 1.1 }

local folder: Folder

local function load(def, index: number)
	local tts: any = Instance.new("AudioTextToSpeech" :: any)
	tts.Name = def.id
	tts.Text = Config.SlimeName(def.id)
	tts.Pitch = PITCH[def.rarity] or 1
	tts.Speed = 1.1
	tts.Volume = 1.5
	tts.Parent = folder
	-- Roblox rate-limits text-to-speech, so retry with a pause, then fall back to voice 1.
	for attempt = 1, 4 do
		tts.VoiceId = if attempt <= 3 then VOICES[(index - 1) % #VOICES + 1] else "1"
		local ok, status = pcall(function()
			return tts:LoadAsync()
		end)
		if ok and status == Enum.AssetFetchStatus.Success then
			return
		end
		task.wait(3 * attempt)
	end
	warn("[SlimeVoices] couldn't load a voice for", def.id)
end

function SlimeVoices.Start()
	folder = Instance.new("Folder")
	folder.Name = "SlimeVoices"
	folder.Parent = game.ReplicatedStorage
	task.spawn(function()
		-- One at a time, gently, so the requests stay under the limit.
		for i, def in Config.Slimes do
			load(def, i)
			task.wait(0.5)
		end
	end)
end

return SlimeVoices
