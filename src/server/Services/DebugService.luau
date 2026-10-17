-- Studio-only test hooks. In a Play test, run from the command bar (Server view):
--   game.ServerStorage.Debug:Invoke("king")
-- Commands: king | cash N | rebirth N | xp N | event Key | fuse | bounty N | gift | slimes N | move I,Pen | slime Id | snacks N | feed Slot | blackout | relic [Key] | arcade | tower | drop EventKey | route X,Z | walk Id,X
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
		elseif cmd == "move" then
			-- "move" with arg "slimeIndex,pen": pick a slime up and drop it on a pen. Returns where slimes 1 and 2 sit.
			local a, b = string.match(tostring(arg), "(%d+),(%d+)")
			services.PlotService.PickUp(player, tonumber(a))
			services.PlotService.MoveTo(player, tonumber(b))
			local p1, p2 = services.PlotService.PadFor(player, 1), services.PlotService.PadFor(player, 2)
			return (if p1 then p1.Name else "-") .. " " .. (if p2 then p2.Name else "-") .. " slots " .. services.PlotService.Slots(player)
		elseif cmd == "route" then
			-- "route" with arg "fromX,fromZ": lists anything solid or visible a walking slime would
			-- pass through on the way to each pen. Returns the number of hits.
			local fx, fz = string.match(tostring(arg), "(-?[%d.]+),(-?[%d.]+)")
			local from = Vector3.new(tonumber(fx) or 0, 0, tonumber(fz) or 0)
			local params = OverlapParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { player.Character, workspace:FindFirstChild("BeltSlimes") }
			local hits, seen = 0, {}
			for pen = 1, Config.MaxSlots do
				local route = services.PlotService.WalkRoute(player, pen, from)
				for i = 2, if route then #route else 0 do
					local a, b = route[i - 1], route[i]
					local len = (b - a).Magnitude
					if len < 0.5 then
						continue
					end
					-- A box as wide as a big slime, from just above the floor to head height.
					local box = CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, 2.6, 0)
					for _, p in workspace:GetPartBoundsInBox(box, Vector3.new(4, 4, len), params) do
						if p.Transparency < 1 and not seen[p] and p.Size.Y > 0.35 and not p:FindFirstAncestor("Slimes") and p.Name ~= "Stair" and p.Name ~= "Floor" then
							seen[p] = true
							hits += 1
							print("ROUTE HIT pen", pen, "leg", i, p:GetFullName(), p.Size, p.Position)
						end
					end
				end
			end
			return hits
		elseif cmd == "slime" then
			services.PlotService.AddSlime(player, { id = arg or "Goop", born = os.time() - 3600 })
		elseif cmd == "walk" then
			-- "walk" with arg "Id,X": a slime bought off the belt at x = X hops to its pen and says its name.
			local id, x = string.match(tostring(arg), "(%w+),(-?[%d.]+)")
			local from = Vector3.new(tonumber(x) or 0, 3, 0)
			services.Net.FxAll("voice", { id = id, buyer = player.UserId, pos = from })
			services.PlotService.AddSlime(player, { id = id or "Goop", born = os.time() }, from)
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
