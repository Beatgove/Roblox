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
Net.RollEvent = remote("Roll") -- client -> server: () use the Slime Dispenser
Net.ClaimDailyEvent = remote("ClaimDaily") -- client -> server: () claim today's login reward
Net.BuyGearEvent = remote("BuyGear") -- client -> server: (gearKey)
Net.ClaimGiftEvent = remote("ClaimGift") -- client -> server: (giftIndex)
Net.ClaimQuestEvent = remote("ClaimQuest") -- client -> server: (questIndex)
Net.BuyUpgradeEvent = remote("BuyUpgrade") -- client -> server: (upgradeKey)
Net.FuseStartEvent = remote("FuseStart") -- client -> server: ({ slot, slot, slot })
Net.FuseClaimEvent = remote("FuseClaim") -- client -> server: ()
Net.HoldTightEvent = remote("HoldTight") -- client -> server: (token) answer a squirm while carrying

Net.RedeemCode = Instance.new("RemoteFunction") -- client -> server: (code) -> (ok, message)
Net.RedeemCode.Name = "RedeemCode"
Net.RedeemCode.Parent = folder

function Net.Fx(player: Player, kind: string, data)
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
