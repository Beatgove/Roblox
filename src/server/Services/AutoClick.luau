-- Auto clicking is a paid perk (the Auto Clicker pass). With the pass, the server itself
-- reels in fish, whacks slimes at the arcade and holds on to squirming slimes. Without it,
-- reactions that are faster than a person can manage, or robotically even, are refused,
-- which is what macros and auto-clicker apps look like from the server.

local Players = game:GetService("Players")

local Net = require(script.Parent.Net)
local Passes = require(script.Parent.Passes)

local AutoClick = {}

local MIN_REACTION = 0.12 -- seconds after the prompt appears, network ping taken off
local SAMPLES = 6 -- reactions looked at for robotic evenness
local MIN_SPREAD = 0.02 -- a person's reaction times vary by more than this

local history: { [Player]: { [string]: { number } } } = {}
local flagged: { [Player]: { [string]: boolean } } = {}
local warnedAt: { [Player]: number } = {}

Players.PlayerRemoving:Connect(function(p)
	history[p] = nil
	flagged[p] = nil
	warnedAt[p] = nil
end)

function AutoClick.Has(player: Player): boolean
	return Passes.Owns(player, "AutoClicker")
end

local function warnPlayer(player: Player)
	if (warnedAt[player] or 0) > os.clock() - 30 then
		return
	end
	warnedAt[player] = os.clock()
	Net.Notify(player, "🤖 Looks like an auto clicker! Auto clicking needs the Auto Clicker pass (Shop).", "bad")
end

-- Called with how long the player took to respond to a prompt (server clock). Returns false
-- when it doesn't look like a person, and the click should be ignored.
function AutoClick.Check(player: Player, kind: string, reaction: number): boolean
	if AutoClick.Has(player) then
		return true
	end
	local mine = flagged[player]
	if mine and mine[kind] then
		warnPlayer(player)
		return false
	end
	local okPing, ping = pcall(player.GetNetworkPing, player)
	local adjusted = reaction - (if okPing and type(ping) == "number" then ping else 0)
	if adjusted < MIN_REACTION then
		warnPlayer(player)
		return false
	end
	history[player] = history[player] or {}
	local list = history[player][kind] or {}
	history[player][kind] = list
	table.insert(list, reaction)
	if #list > SAMPLES then
		table.remove(list, 1)
	end
	if #list == SAMPLES then
		local mean = 0
		for _, r in list do
			mean += r
		end
		mean /= SAMPLES
		local var = 0
		for _, r in list do
			var += (r - mean) ^ 2
		end
		if math.sqrt(var / SAMPLES) < MIN_SPREAD then
			flagged[player] = flagged[player] or {}
			flagged[player][kind] = true -- for the rest of this session
			warn("[AutoClick] robotic timing from", player.Name, "on", kind)
			warnPlayer(player)
			return false
		end
	end
	return true
end

return AutoClick
