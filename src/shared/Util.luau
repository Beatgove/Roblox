local Config = require(script.Parent.Config)

local Util = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

function Util.Format(n: number): string
	n = math.floor(n)
	if n < 1000 then
		return tostring(n)
	end
	local i = 1
	local v = n
	while v >= 1000 and i < #SUFFIXES do
		v /= 1000
		i += 1
	end
	if v >= 100 then
		return string.format("%d%s", math.floor(v), SUFFIXES[i])
	end
	return string.format("%.1f%s", math.floor(v * 10) / 10, SUFFIXES[i])
end

function Util.Money(n: number): string
	return "$" .. Util.Format(n)
end

-- Growth stage (1..#GrowthStages) for a slime of the given age in seconds.
function Util.Stage(ageSeconds: number): number
	local stage = 1
	for i, t in Config.GrowthStages do
		if ageSeconds >= t then
			stage = i
		end
	end
	return stage
end

-- Seconds until the next stage, or nil at max stage.
function Util.TimeToNextStage(ageSeconds: number): number?
	local stage = Util.Stage(ageSeconds)
	local nextT = Config.GrowthStages[stage + 1]
	if not nextT then
		return nil
	end
	return nextT - ageSeconds
end

function Util.Duration(sec: number): string
	sec = math.max(0, math.floor(sec))
	if sec >= 3600 then
		return string.format("%dh %dm", sec // 3600, (sec % 3600) // 60)
	elseif sec >= 60 then
		return string.format("%dm %ds", sec // 60, sec % 60)
	end
	return string.format("%ds", sec)
end

return Util
