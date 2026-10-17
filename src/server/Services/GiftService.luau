-- Playtime gifts: presents that unlock after 2, 5, 10... minutes in a session.
-- Keeps people playing a little longer each visit (a staple of top simulators).

local Players = game:GetService("Players")

local Config = require(game.ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Rewards = require(script.Parent.Rewards)
local Signals = require(script.Parent.Signals)
local Net = require(script.Parent.Net)

local GiftService = {}

local joinedAt: { [Player]: number } = {}
local claimed: { [Player]: { [number]: boolean } } = {}

local function sync(player: Player)
	local list = {}
	for i in pairs(claimed[player] or {}) do
		table.insert(list, tostring(i))
	end
	player:SetAttribute("GiftsClaimed", table.concat(list, ","))
end

function GiftService.OnPlayer(player: Player)
	joinedAt[player] = os.time()
	claimed[player] = {}
	player:SetAttribute("GiftStart", workspace:GetServerTimeNow())
	sync(player)
end

local function claim(player: Player, i: number)
	local gift = typeof(i) == "number" and Config.PlaytimeGifts[i]
	local mine = claimed[player]
	if not gift or not mine or not DataService.Get(player) then
		return
	end
	if mine[i] then
		return
	end
	if os.time() - joinedAt[player] < gift.minutes * 60 then
		Net.Notify(player, "That gift isn't ready yet!", "bad")
		return
	end
	mine[i] = true
	sync(player)
	local text = Rewards.Grant(player, gift)
	Signals.Progress(player, "gift")
	Net.Fx(player, "gift", {})
	Net.Notify(player, "🎁 Gift opened: " .. text .. "!", "epic")
end

function GiftService.Start()
	Net.On(Net.ClaimGiftEvent, claim)
	Players.PlayerRemoving:Connect(function(p)
		joinedAt[p] = nil
		claimed[p] = nil
	end)
end

return GiftService
