-- Slime Index milestones: rewards for discovering 5, 10, 15... different slimes.

local Config = require(game.ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local Rewards = require(script.Parent.Rewards)
local Signals = require(script.Parent.Signals)
local Net = require(script.Parent.Net)

local IndexService = {}

function IndexService.Check(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local count = PlotService.IndexCount(player)
	for _, m in Config.IndexMilestones do
		local key = tostring(m.count)
		if count >= m.count and not data.indexRewards[key] then
			data.indexRewards[key] = true
			-- Deferred so the reward lands after the new slime finishes rendering.
			task.delay(1, function()
				if player.Parent then
					local text = Rewards.Grant(player, m)
					Net.Notify(player, "📖 INDEX " .. m.count .. " REACHED! Reward: " .. text, "epic")
					Net.Fx(player, "daily", { day = 7 })
				end
			end)
		end
	end
end

function IndexService.Start()
	Signals.Quest.Event:Connect(function(player, kind)
		if kind == "index" then
			IndexService.Check(player)
		end
	end)
end

return IndexService
