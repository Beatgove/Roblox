-- Sends a Roblox experience notification ("Bob stole your Dragon! Get it back...") to a
-- player's phone / Roblox app when someone steals from them, so AFK players come back.
-- Does nothing until Config.PhoneAlerts is set up (string ID, API key secret, HTTP on).

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Config = require(game.ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)

local PhoneAlerts = {}

local P = Config.PhoneAlerts

local function send(player: Player, messageId: string, parameters: { [string]: any }, launchData: string, category: string)
	local okSecret, secret = pcall(HttpService.GetSecret, HttpService, P.secretName)
	if not okSecret then
		return
	end
	local body = HttpService:JSONEncode({
		source = { universe = "universes/" .. game.GameId },
		payload = { message_id = messageId, type = "MOMENT", parameters = parameters },
		join_experience = { launch_data = launchData },
		analytics_data = { category = category },
	})
	local ok, res = pcall(HttpService.RequestAsync, HttpService, {
		Url = "https://apis.roblox.com/cloud/v2/users/" .. player.UserId .. "/notifications",
		Method = "POST",
		Headers = { ["x-api-key"] = secret :: any, ["Content-Type"] = "application/json" },
		Body = body,
	})
	if not ok then
		warn("[PhoneAlerts] request failed:", res)
	elseif not res.Success then
		warn("[PhoneAlerts]", res.StatusCode, res.Body)
	end
end

function PhoneAlerts.Stolen(victim: Player, thief: Player, slimeName: string)
	if P.stolenMessageId == "" or RunService:IsStudio() then
		return
	end
	local data = DataService.Get(victim)
	if not data or os.time() - (data.lastPhoneAlert or 0) < P.everyHours * 3600 then
		return
	end
	data.lastPhoneAlert = os.time()
	task.spawn(send, victim, P.stolenMessageId, {
		thief = { string_value = thief.DisplayName },
		slime = { string_value = slimeName },
	}, "revenge", "stolen")
end

return PhoneAlerts
