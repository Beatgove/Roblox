-- Player settings (the ⚙️ menu), the community-group perk and the one-time favourite prompt.
-- Settings are saved with the player's data and handed to the client as a JSON attribute,
-- so they follow the player to every server and device.

local HttpService = game:GetService("HttpService")

local Config = require(game.ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Net = require(script.Parent.Net)

local SettingsService = {}

-- Only known keys of the right type survive; numbers are clamped to 0..1.
local function clean(input: any)
	local out = {}
	for key, default in Config.DefaultSettings do
		local v = if type(input) == "table" then input[key] else nil
		if type(default) == "number" then
			out[key] = if type(v) == "number" and v == v then math.clamp(math.round(v * 10) / 10, 0, 1) else default
		else
			out[key] = if type(v) == "boolean" then v else default
		end
	end
	return out
end

local function publish(player: Player, data)
	player:SetAttribute("Settings", HttpService:JSONEncode(data.settings))
	player:SetAttribute("AskedFavorite", data.askedFavorite == true)
end

function SettingsService.OnPlayer(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	data.settings = clean(data.settings)
	publish(player, data)
	if Config.GroupId > 0 then
		task.spawn(function()
			local ok, inGroup = pcall(player.IsInGroup, player, Config.GroupId)
			if ok and inGroup and player.Parent then
				player:SetAttribute("InGroup", true)
			end
		end)
	end
end

function SettingsService.Start()
	Net.On(Net.SaveSettingsEvent, function(player, input)
		local data = DataService.Get(player)
		if data then
			data.settings = clean(input)
			publish(player, data)
		end
	end)
	Net.On(Net.FavoriteAskedEvent, function(player)
		local data = DataService.Get(player)
		if data and not data.askedFavorite then
			data.askedFavorite = true
			publish(player, data)
		end
	end)
end

return SettingsService
