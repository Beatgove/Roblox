-- The weekly Slime Storm: a 20-minute live event at fixed UTC times (Config.Storm.times).
-- Every server computes the same schedule from the clock, so it starts everywhere at once
-- with no cross-server messaging. A server that opens mid-Storm joins in for the time left.
-- The Storm is an ordinary Config.Events entry, so traits, drops, luck and cash just work.

local Config = require(game.ReplicatedStorage.Shared.Config)
local Net = require(script.Parent.Net)
local EventService = require(script.Parent.EventService)
local BossService = require(script.Parent.BossService)

local StormService = {}

local S = Config.Storm
local LENGTH = S.minutes * 60

-- Start time (unix seconds) of the next Storm that hasn't ended yet.
function StormService.Next(now: number): number
	local best = math.huge
	local midnight = now - now % 86400
	for day = -1, 7 do
		local dayStart = midnight + day * 86400
		local wday = (os.date("!*t", dayStart) :: any).wday
		for _, t in S.times do
			if t.wday == wday then
				local start = dayStart + t.hour * 3600
				if start + LENGTH > now and start < best then
					best = start
				end
			end
		end
	end
	return best
end

-- Tracked here, not read back from the shared Event attribute: another event started during
-- the Storm (by an admin) must not make this loop restart the Storm every second.
local stormUntil = 0
local function stormActive(): boolean
	return os.time() < stormUntil
end

function StormService.Active(): boolean
	return stormActive() and workspace:GetAttribute("Event") == "SlimeStorm"
end

function StormService.SecondsLeft(): number
	return math.max(0, stormUntil - os.time())
end

local function begin(seconds: number)
	stormUntil = os.time() + seconds
	EventService.Run("SlimeStorm", seconds)
	Net.FxAll("stormStart", {})
	-- The King crashes the party, unless he's already here.
	if (workspace:GetAttribute("KingUntil") or 0) <= workspace:GetServerTimeNow() then
		task.delay(20, BossService.SpawnNow)
	end
end

function StormService.Start()
	task.spawn(function()
		local warned: { [string]: boolean } = {}
		while true do
			local now = os.time()
			local start = StormService.Next(now)
			workspace:SetAttribute("NextStorm", start)
			if now >= start then
				if not stormActive() then
					begin(start + LENGTH - now)
				end
			else
				for _, m in S.warnMinutes do
					local key = start .. ":" .. m
					if not warned[key] and start - now <= m * 60 then
						warned[key] = true
						Net.Banner("⛈️ The SLIME STORM hits in " .. m .. (if m == 1 then " minute" else " minutes") .. "! Storm-only slimes are coming.", 8, "storm")
					end
				end
			end
			task.wait(1)
		end
	end)
end

-- For the Studio debug hook: a Storm right now.
function StormService.RunNow(seconds: number?)
	begin(seconds or LENGTH)
end

return StormService
