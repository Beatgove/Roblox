-- Creates the RemoteEvents the client listens to and wraps the common calls.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

local folder = Instance.new("Folder")
folder.Name = "Remotes"
folder.Parent = ReplicatedStorage

local function remote(name: string): RemoteEvent
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = folder
	return r
end

Net.NotifyEvent = remote("Notify") -- server -> client: (text, kind)
Net.RebirthEvent = remote("Rebirth") -- client -> server: ()
Net.BannerEvent = remote("Banner") -- server -> all: (text, seconds, kind "rain" | "event")
Net.FxEvent = remote("Fx") -- server -> client: (kind, data) visual/sound effects
Net.ClaimDailyEvent = remote("ClaimDaily") -- client -> server: () claim today's login reward
Net.BuyGearEvent = remote("BuyGear") -- client -> server: (gearKey)
Net.ClaimGiftEvent = remote("ClaimGift") -- client -> server: (giftIndex)
Net.ClaimQuestEvent = remote("ClaimQuest") -- client -> server: (questIndex)
Net.BuyUpgradeEvent = remote("BuyUpgrade") -- client -> server: (upgradeKey)
Net.FuseStartEvent = remote("FuseStart") -- client -> server: ({ slot, slot, slot })
Net.FuseClaimEvent = remote("FuseClaim") -- client -> server: ()
Net.HoldTightEvent = remote("HoldTight") -- client -> server: (token) answer a squirm while carrying
Net.BuySnackEvent = remote("BuySnack") -- client -> server: (snackKey) buy one at the Snack Bar
Net.PickSnackEvent = remote("PickSnack") -- client -> server: (snackKey) which snack "Feed" uses
Net.EquipRelicEvent = remote("EquipRelic") -- client -> server: (relicKey)
Net.ReelEvent = remote("Reel") -- client -> server: (token) reel in a fish after a bite
Net.UnequipRelicEvent = remote("UnequipRelic") -- client -> server: (relicKey)
Net.ClaimSeasonEvent = remote("ClaimSeason") -- client -> server: (tier)
Net.SaveSettingsEvent = remote("SaveSettings") -- client -> server: ({ music, sfx, lowFx, shake })
Net.FavoriteAskedEvent = remote("FavoriteAsked") -- client -> server: () the favourite prompt was shown

Net.RedeemCode = Instance.new("RemoteFunction") -- client -> server: (code) -> (ok, message)
Net.RedeemCode.Name = "RedeemCode"
Net.RedeemCode.Parent = folder

-- Every client -> server remote goes through Net.On: a per-player, per-remote token bucket
-- drops spam (exploit scripts fire remotes thousands of times a second), oversized tables
-- are refused before any handler loops over them, and a handler error is logged once with
-- the remote's name instead of breaking the connection. Handlers still validate their own
-- arguments; this is the shared first line of defence.
local BURST, REFILL = 8, 4 -- up to 8 calls at once, then 4 per second per remote
local buckets: { [Player]: { [string]: { n: number, t: number } } } = {}
local dropped: { [Player]: number } = {}

local function tooBig(v: any, depth: number): boolean
	if type(v) ~= "table" then
		return type(v) == "string" and #v > 200
	end
	if depth > 2 then
		return true
	end
	local n = 0
	for _, x in v do
		n += 1
		if n > 32 or tooBig(x, depth + 1) then
			return true
		end
	end
	return false
end

local function allow(player: Player, name: string): boolean
	local mine = buckets[player]
	if not mine then
		mine = {}
		buckets[player] = mine
	end
	local now = os.clock()
	local b = mine[name]
	if not b then
		b = { n = BURST, t = now }
		mine[name] = b
	end
	b.n = math.min(BURST, b.n + (now - b.t) * REFILL)
	b.t = now
	if b.n < 1 then
		return false
	end
	b.n -= 1
	return true
end

function Net.On(r: RemoteEvent, handler: (Player, ...any) -> ())
	r.OnServerEvent:Connect(function(player: Player, ...)
		local args = table.pack(...)
		local bad = args.n > 4
		for i = 1, math.min(args.n, 4) do
			bad = bad or tooBig(args[i], 0)
		end
		if bad or not allow(player, r.Name) then
			dropped[player] = (dropped[player] or 0) + 1
			if dropped[player] == 50 then
				warn("[Net] dropping spam from", player.Name, "on", r.Name)
			end
			return
		end
		local ok, err = pcall(handler, player, ...)
		if not ok then
			warn("[Net]", r.Name, "handler failed for", player.Name, ":", err)
		end
	end)
end

game:GetService("Players").PlayerRemoving:Connect(function(player)
	buckets[player] = nil
	dropped[player] = nil
end)

-- Knockback is applied on the client, so the server gives the player a short window where
-- fast movement is expected (StealService's carry speed check reads it).
-- The grace is anchored: `origin` is where the move lands (or starts, for a knock) and
-- `radius` how far from it the move can take them, so a hacker can't use the window to
-- teleport somewhere else.
export type Grace = { untilT: number, origin: Vector3, radius: number, at: number }
local moveGrace: { [Player]: Grace } = {}
game:GetService("Players").PlayerRemoving:Connect(function(player)
	moveGrace[player] = nil
end)
-- Call before the server moves a character itself (PivotTo), so it isn't read as a hack.
function Net.GrantMoveGrace(player: Player, seconds: number, origin: Vector3, radius: number)
	moveGrace[player] = { untilT = os.clock() + seconds, origin = origin, radius = radius, at = os.clock() }
end
function Net.MoveGrace(player: Player): Grace?
	local g = moveGrace[player]
	return if g and g.untilT > os.clock() then g else nil
end

function Net.Fx(player: Player, kind: string, data)
	if kind == "knock" then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			Net.GrantMoveGrace(player, 2.5, root.Position, 50)
		end
	end
	Net.FxEvent:FireClient(player, kind, data)
end

function Net.FxAll(kind: string, data)
	Net.FxEvent:FireAllClients(kind, data)
end

-- kind: "info" | "good" | "bad" | "epic"
function Net.Notify(player: Player, text: string, kind: string?)
	Net.NotifyEvent:FireClient(player, text, kind or "info")
end

function Net.NotifyAll(text: string, kind: string?)
	Net.NotifyEvent:FireAllClients(text, kind or "info")
end

function Net.Banner(text: string, seconds: number, kind: string?)
	Net.BannerEvent:FireAllClients(text, seconds, kind or "rain")
end

return Net
