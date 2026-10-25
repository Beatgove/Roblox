-- Roblox PolicyService rules per player. Some countries ban paid random items, so for those
-- players the Dispenser and Fuse Machine (random results bought with cash, which Robux can buy) are off.

local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")

local Policy = {}

local restricted: { [Player]: boolean } = {}

-- True when this player can't use paid random items. If Roblox can't be reached we play safe
-- and say restricted, without caching, so the next try asks again.
function Policy.PaidRandomRestricted(player: Player): boolean
	local cached = restricted[player]
	if cached ~= nil then
		return cached
	end
	local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
	if not ok or typeof(info) ~= "table" then
		return true
	end
	local value = info.ArePaidRandomItemsRestricted == true
	restricted[player] = value
	return value
end

-- Look it up on join so the first roll doesn't wait on it.
Players.PlayerAdded:Connect(function(player)
	Policy.PaidRandomRestricted(player)
end)
Players.PlayerRemoving:Connect(function(player)
	restricted[player] = nil
end)

return Policy
