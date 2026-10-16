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
Net.BannerEvent = remote("Banner") -- server -> all: (text, seconds)

-- kind: "info" | "good" | "bad" | "epic"
function Net.Notify(player: Player, text: string, kind: string?)
	Net.NotifyEvent:FireClient(player, text, kind or "info")
end

function Net.NotifyAll(text: string, kind: string?)
	Net.NotifyEvent:FireAllClients(text, kind or "info")
end

function Net.Banner(text: string, seconds: number)
	Net.BannerEvent:FireAllClients(text, seconds)
end

return Net
