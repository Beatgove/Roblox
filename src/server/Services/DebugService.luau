-- Studio-only test hooks. In a Play test, run from the command bar (Server view):
--   game.ServerStorage.Debug:Invoke("king")
-- Commands: king | cash N | rebirth N | xp N | event Key | fuse | bounty N | gift | slimes N | slime Id | snacks N | feed Slot | blackout | relic [Key] | arcade | tower | drop EventKey
-- Never exists in live servers.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(game.ReplicatedStorage.Shared.Config)

local DebugService = {}

function DebugService.Start(services)
	if not RunService:IsStudio() then
		return
	end
	local fn = Instance.new("BindableFunction")
	fn.Name = "Debug"
	fn.OnInvoke = function(cmd: string, arg: any, playerName: string?)
		local player = if playerName then Players:FindFirstChild(playerName) :: Player? else Players:GetPlayers()[1]
		if not player then
			return "no player"
		end
		local data = services.DataService.Get(player)
		local n = tonumber(arg)
		if cmd == "king" then
			services.BossService.SpawnNow()
		elseif cmd == "cash" then
			services.PlotService.AddCash(player, n or 1e6)
		elseif cmd == "rebirth" then
			data.rebirths = n or (data.rebirths + 1)
			local plot = services.PlotService.GetPlot(player)
			if plot then
				services.BaseDecor.Apply(plot.model, plot.cframe, data.rebirths, data.baseSkin)
			end
			services.PlotService.Sync(player)
		elseif cmd == "skin" then
			data.baseSkin = arg or "Classic"
			local plot = services.PlotService.GetPlot(player)
			if plot then
				services.BaseDecor.Apply(plot.model, plot.cframe, data.rebirths, data.baseSkin)
			end
		elseif cmd == "xp" then
			services.LevelService.AddXP(player, n or 500)
		elseif cmd == "event" then
			services.EventService.Run(arg or "LavaStorm", 60)
		elseif cmd == "fuse" then
			if data.fuse.active then
				data.fuse.endsAt = os.time()
				player:SetAttribute("Fuse", game:GetService("HttpService"):JSONEncode({ active = true, endsAt = os.time() }))
			end
		elseif cmd == "bounty" then
			services.BountyService.Add(player, n or 5000)
		elseif cmd == "slimes" then
			for _ = 1, n or 3 do
				services.PlotService.AddSlime(player, { id = "Goop", born = os.time() - 3600 })
			end
		elseif cmd == "slime" then
			services.PlotService.AddSlime(player, { id = arg or "Goop", born = os.time() - 3600 })
		elseif cmd == "snacks" then
			for _, key in Config.SnackOrder do
				services.SnackService.Give(player, key, n or 5, true)
			end
		elseif cmd == "lock" then
			services.PlotService.Lock(player, n or 30, true)
		elseif cmd == "season" then
			services.SeasonService.AddXP(player, n or 500)
		elseif cmd == "storm" then
			services.StormService.RunNow(n)
		elseif cmd == "tutorial" then
			services.TutorialService.Reset(player)
		elseif cmd == "drop" then
			for _ = 1, n or 1 do
				services.EventDropService.SpawnNow(if n then "GoldenHour" else (arg or "GoldenHour"))
			end
		elseif cmd == "arcade" then
			services.ArcadeService.PlayAny(player)
		elseif cmd == "tower" then
			data.towerAt = 0
		elseif cmd == "relic" then
			services.RelicService.Give(player, arg, "debug")
		elseif cmd == "blackout" then
			services.BlackoutService.RunNow()
		elseif cmd == "feed" then
			services.SnackService.Feed(player, n or 1)
		elseif cmd == "gift" then
			player:SetAttribute("GiftStart", workspace:GetServerTimeNow() - 3600)
		else
			return "unknown command"
		end
		return "ok " .. cmd
	end
	fn.Parent = ServerStorage
end

return DebugService
