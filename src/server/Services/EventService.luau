-- Server-wide events: every few minutes a random event (Golden Hour, Lava Storm, Candy Party,
-- Cash Frenzy, Lucky Hour) runs for everyone. Other services read Roller.ActiveEvent().

local Config = require(game.ReplicatedStorage.Shared.Config)
local Net = require(script.Parent.Net)

local EventService = {}

local last: string? = nil

function EventService.Run(key: string, seconds: number?, byName: string?)
	local def = Config.Events[key]
	if not def then
		return
	end
	local length = seconds or Config.EventSeconds
	last = key
	workspace:SetAttribute("Event", key)
	workspace:SetAttribute("EventStart", workspace:GetServerTimeNow())
	workspace:SetAttribute("EventUntil", workspace:GetServerTimeNow() + length)
	local who = if byName then byName .. " started " else ""
	Net.Banner(who .. def.title .. "! " .. def.desc, length, "event")
	Net.FxAll("event", { key = key })
end

function EventService.Start()
	task.spawn(function()
		while true do
			task.wait(Config.EventEverySeconds)
			-- The weekly Slime Storm owns the sky while it runs.
			if workspace:GetAttribute("Event") == "SlimeStorm" and (workspace:GetAttribute("EventUntil") or 0) > workspace:GetServerTimeNow() then
				continue
			end
			-- Never the same event twice in a row.
			local options = {}
			for _, k in Config.EventKeys do
				if k ~= last then
					table.insert(options, k)
				end
			end
			EventService.Run(options[math.random(1, #options)])
		end
	end)
end

return EventService
