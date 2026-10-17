-- Slime Season: a free monthly reward track. Playing earns Season XP (quests, bounties,
-- the King, mini games, steals...), every 100 XP unlocks a tier, and tier 30 is the
-- season-exclusive slime. Everything resets on the 1st of each month (UTC).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Config = require(game.ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Rewards = require(script.Parent.Rewards)
local Signals = require(script.Parent.Signals)
local Net = require(script.Parent.Net)
local Analytics = require(script.Parent.Analytics)

local SeasonService = {}

local S = Config.Season

local function currentId(): string
	return os.date("!%Y-%m") :: string
end

-- Unix time the current season ends (midnight UTC on the 1st of next month).
local function endsAt(): number
	local t = os.date("!*t") :: any
	local y, m = t.year, t.month + 1
	if m > 12 then
		y, m = y + 1, 1
	end
	-- os.time reads a table as local time; correct by the server's UTC offset.
	local localGuess = os.time({ year = y, month = m, day = 1, hour = 0 })
	local offset = os.time(os.date("!*t", localGuess) :: any) - localGuess
	return localGuess - offset
end

local function ensure(data)
	local id = currentId()
	if data.season.id ~= id then
		data.season = { id = id, xp = 0, claimed = {} }
	end
	return data.season
end

local function sync(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local season = ensure(data)
	local claimed = {}
	for k in season.claimed do
		table.insert(claimed, tonumber(k))
	end
	player:SetAttribute("Season", HttpService:JSONEncode({ xp = season.xp, claimed = claimed, endsAt = endsAt() }))
end

function SeasonService.AddXP(player: Player, amount: number)
	local data = DataService.Get(player)
	if not data or amount <= 0 then
		return
	end
	local season = ensure(data)
	local before = season.xp // S.tierXP
	season.xp += amount
	local after = math.min(season.xp // S.tierXP, #S.tiers)
	if after > before and before < #S.tiers then
		Net.Notify(player, "🌟 Season tier " .. after .. " unlocked! Open 🌟 SEASON to claim it.", "epic")
		Net.Fx(player, "seasonTier", { tier = after })
		Analytics.Custom(player, "SeasonTier", after)
	end
	sync(player)
end

local function claim(player: Player, tier: any)
	local data = DataService.Get(player)
	if not data or type(tier) ~= "number" or tier % 1 ~= 0 or not S.tiers[tier] then
		return
	end
	local season = ensure(data)
	local key = tostring(tier)
	if season.claimed[key] or season.xp // S.tierXP < tier then
		return
	end
	season.claimed[key] = true
	local text = Rewards.Grant(player, S.tiers[tier].reward)
	Net.Notify(player, "🌟 Season tier " .. tier .. ": " .. text, "good")
	Net.Fx(player, "seasonClaim", { tier = tier })
	sync(player)
end

function SeasonService.OnPlayer(player: Player)
	sync(player)
end

function SeasonService.Start()
	Net.On(Net.ClaimSeasonEvent, claim)
	Signals.Quest.Event:Connect(function(player: Player, kind: string)
		local pts = S.points[kind]
		if pts then
			SeasonService.AddXP(player, pts)
		end
	end)
	-- Roll everyone over to the new season at midnight on the 1st.
	task.spawn(function()
		local id = currentId()
		while true do
			task.wait(60)
			if currentId() ~= id then
				id = currentId()
				for _, p in Players:GetPlayers() do
					sync(p)
				end
				Net.NotifyAll("🌟 A new Slime Season has started! Fresh rewards in 🌟 SEASON.", "epic")
			end
		end
	end)
end

return SeasonService
