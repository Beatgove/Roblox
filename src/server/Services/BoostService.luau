-- Friend boost: +10% income for each friend in the server (up to +50%).
-- Playing with friends is one of the strongest growth loops on Roblox.

local Players = game:GetService("Players")

local Config = require(game.ReplicatedStorage.Shared.Config)
local PlotService = require(script.Parent.PlotService)

local BoostService = {}

local friendCache: { [string]: boolean } = {}

local function areFriends(a: Player, b: Player): boolean
	local key = if a.UserId < b.UserId then a.UserId .. "_" .. b.UserId else b.UserId .. "_" .. a.UserId
	if friendCache[key] == nil then
		local ok, result = pcall(function()
			return a:IsFriendsWith(b.UserId)
		end)
		friendCache[key] = ok and result == true
	end
	return friendCache[key]
end

local function refresh()
	local all = Players:GetPlayers()
	for _, p in all do
		local friends = 0
		for _, other in all do
			if other ~= p and areFriends(p, other) then
				friends += 1
			end
		end
		local boost = math.min(friends * Config.FriendBoost, Config.MaxFriendBoost)
		if p:GetAttribute("FriendBoost") ~= boost then
			p:SetAttribute("FriendBoost", boost)
			p:SetAttribute("Friends", friends)
			PlotService.Sync(p)
		end
	end
end

function BoostService.Start()
	Players.PlayerAdded:Connect(function()
		task.delay(3, refresh)
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(refresh)
	end)
	task.spawn(function()
		while true do
			task.wait(30)
			refresh()
		end
	end)
end

return BoostService
