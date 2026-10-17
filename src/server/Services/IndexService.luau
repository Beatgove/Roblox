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
	for _, skin in Config.BaseSkins do
		if skin.need > 0 and count == skin.need then
			Net.Notify(player, "🎨 New base skin unlocked: " .. skin.name .. "! Tap the paint stand by your door to use it.", "epic")
		end
	end
	for _, m in Config.IndexMilestones do
		local key = tostring(m.count)
		if count >= m.count and not data.indexRewards[key] then
			-- Deferred so the reward lands after the new slime finishes rendering; the flag is set
			-- when it's actually granted so leaving in that second can't lose it.
			task.delay(1, function()
				if player.Parent and not data.indexRewards[key] then
					data.indexRewards[key] = true
					local text = Rewards.Grant(player, m)
					Net.Notify(player, "📖 INDEX " .. m.count .. " REACHED! Reward: " .. text, "epic")
					Net.Fx(player, "milestone", { title = "INDEX " .. m.count .. "!", sub = text })
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
