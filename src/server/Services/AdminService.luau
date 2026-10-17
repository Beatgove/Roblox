-- Live-ops tools, like the big studios run their games: admins type "/admin ..." in chat and
-- the command runs in every server at once (MessagingService), plus a weekly Admin Abuse
-- hour that every server starts on its own from the clock. Only events and spawns are
-- exposed, never cash or slimes, so a leaked admin account can't wreck the economy.

local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local TextService = game:GetService("TextService")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Net = require(script.Parent.Net)

local AdminService = {}

local TOPIC = "SAS_Admin"
local A = Config.AdminAbuse
local services: any = nil
local adminCache: { [number]: boolean } = {}

local function isAdmin(player: Player): boolean
	local id = player.UserId
	if adminCache[id] ~= nil then
		return adminCache[id]
	end
	local yes = table.find(Config.Admins, id) ~= nil
	if game.CreatorType == Enum.CreatorType.User then
		yes = yes or id == game.CreatorId
	else
		local ok, rank = pcall(player.GetRankInGroup, player, game.CreatorId)
		yes = yes or (ok and rank >= Config.AdminGroupRank)
	end
	yes = yes or (game:GetService("RunService"):IsStudio() and id > 0 and #Players:GetPlayers() == 1)
	adminCache[id] = yes
	return yes
end

-- Back-to-back events for `minutes`, with a King Slime visit and box rain between them.
local abuseUntil = 0
local function adminAbuse(minutes: number, byName: string?)
	local endsAt = os.time() + minutes * 60
	if endsAt <= abuseUntil then
		return
	end
	local fresh = abuseUntil < os.time()
	abuseUntil = endsAt
	workspace:SetAttribute("AdminAbuseUntil", workspace:GetServerTimeNow() + (endsAt - os.time()))
	if not fresh then
		return -- extended the one already running
	end
	Net.Banner("🛠️ ADMIN ABUSE" .. (if byName then " by " .. byName else "") .. "! Events, King Slimes and boxes for " .. minutes .. " minutes!", 12, "event")
	task.spawn(function()
		local keys = table.clone(Config.EventKeys)
		local i = 0
		while os.time() < abuseUntil do
			i += 1
			if i % #keys == 1 then
				for k = #keys, 2, -1 do
					local j = math.random(1, k)
					keys[k], keys[j] = keys[j], keys[k]
				end
			end
			local left = abuseUntil - os.time()
			services.EventService.Run(keys[(i - 1) % #keys + 1], math.min(A.eventSeconds, left), "Admin Abuse")
			for _ = 1, 3 do
				pcall(services.EventDropService.SpawnNow, keys[(i - 1) % #keys + 1])
			end
			if i % 3 == 0 then
				pcall(services.BossService.SpawnNow)
			end
			task.wait(math.min(A.eventSeconds, left) + 5)
		end
		workspace:SetAttribute("AdminAbuseUntil", nil)
		Net.Banner("🛠️ Admin Abuse is over. Thanks for playing! Same time next week.", 8, "event")
	end)
end

-- Runs a command in this server. Returns a short result for the admin.
local function run(cmd: string, args: { string }, byName: string?): string
	if cmd == "event" then
		local key = args[1]
		if not (key and Config.Events[key]) then
			return "Events: " .. table.concat(Config.EventKeys, ", ")
		end
		services.EventService.Run(key, (tonumber(args[2]) or 5) * 60, byName)
		return "Started " .. key
	elseif cmd == "abuse" then
		adminAbuse(math.clamp(tonumber(args[1]) or 15, 1, 120), byName)
		return "Admin Abuse on"
	elseif cmd == "king" then
		services.BossService.SpawnNow()
		return "King Slime spawned"
	elseif cmd == "storm" then
		services.StormService.RunNow((tonumber(args[1]) or 10) * 60)
		return "Slime Storm started"
	elseif cmd == "blackout" then
		services.BlackoutService.RunNow()
		return "Blackout started"
	elseif cmd == "drop" then
		for _ = 1, math.clamp(tonumber(args[1]) or 5, 1, 20) do
			pcall(services.EventDropService.SpawnNow, workspace:GetAttribute("Event") or "GoldenHour")
		end
		return "Boxes dropped"
	elseif cmd == "say" then
		-- Already filtered for broadcast by the sending server.
		Net.Banner("📢 " .. table.concat(args, " "), 8, "event")
		return "Announced"
	end
	return "Commands: event <Key> [min], abuse [min], king, storm [min], blackout, drop [n], say <text>. Add 'here' first to run in this server only."
end

local function broadcast(cmd: string, args: { string }, byName: string)
	local ok = pcall(MessagingService.PublishAsync, MessagingService, TOPIC, { cmd = cmd, args = args, by = byName, job = game.JobId })
	return ok
end

local function onCommand(player: Player, text: string)
	if not isAdmin(player) then
		return
	end
	local words = string.split(text, " ")
	table.remove(words, 1) -- "/admin"
	local here = words[1] == "here"
	if here then
		table.remove(words, 1)
	end
	local cmd = string.lower(words[1] or "help")
	table.remove(words, 1)
	if cmd == "say" then
		local ok, filtered = pcall(function()
			local result = TextService:FilterStringAsync(table.concat(words, " "), player.UserId)
			return result:GetNonChatStringForBroadcastAsync()
		end)
		if not ok then
			Net.Notify(player, "Couldn't filter that message, try again.", "bad")
			return
		end
		words = { filtered }
	end
	local result = run(cmd, words, player.DisplayName)
	if not here and cmd ~= "help" and result ~= "" then
		if not broadcast(cmd, words, player.DisplayName) then
			result ..= " (this server only: couldn't reach the others)"
		else
			result ..= " in every server"
		end
	end
	Net.Notify(player, "🛠️ " .. result, "info")
end

local function nextAbuse(now: number): number?
	local best: number? = nil
	for _, t in A.times do
		for d = 0, 7 do
			local dayStart = (math.floor(now / 86400) + d) * 86400
			local wday = (os.date("!*t", dayStart) :: any).wday
			local at = dayStart + t.hour * 3600
			if wday == t.wday and at + A.minutes * 60 > now and (not best or at < best) then
				best = at
			end
		end
	end
	return best
end

function AdminService.Start(s)
	services = s
	local command = Instance.new("TextChatCommand")
	command.Name = "AdminCommand"
	command.PrimaryAlias = "/admin"
	command.Parent = TextChatService
	command.Triggered:Connect(function(source: TextSource, text: string)
		local player = Players:GetPlayerByUserId(source.UserId)
		if player then
			task.spawn(onCommand, player, text)
		end
	end)
	task.spawn(function()
		local ok = pcall(MessagingService.SubscribeAsync, MessagingService, TOPIC, function(msg)
			local d = msg.Data
			if type(d) == "table" and d.job ~= game.JobId and type(d.cmd) == "string" and type(d.args) == "table" then
				pcall(run, d.cmd, d.args, d.by)
			end
		end)
		if not ok then
			warn("[AdminService] cross-server commands unavailable")
		end
	end)
	-- Weekly Admin Abuse from the clock, with warnings beforehand.
	task.spawn(function()
		local warned: { [string]: boolean } = {}
		while true do
			local now = os.time()
			local at = nextAbuse(now)
			if at then
				if now >= at then
					adminAbuse(math.max(1, math.ceil((at + A.minutes * 60 - now) / 60)))
				else
					for _, m in A.warnMinutes do
						local key = at .. ":" .. m
						if not warned[key] and at - now <= m * 60 and at - now > m * 60 - 30 then
							warned[key] = true
							Net.Banner("🛠️ ADMIN ABUSE starts in " .. m .. " minute" .. (if m == 1 then "" else "s") .. "!", 8, "event")
						end
					end
				end
				workspace:SetAttribute("AdminAbuseNext", at)
			end
			task.wait(20)
		end
	end)
end

return AdminService
