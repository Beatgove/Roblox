-- First-time guide: brand new players get one pinned objective at a time (buy, collect,
-- lock) with an arrow pointing at the spot, then a small reward. Each step is also an
-- onboarding funnel step in Analytics, so we can see exactly where new players quit.

local Config = require(game.ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local Rewards = require(script.Parent.Rewards)
local Signals = require(script.Parent.Signals)
local Net = require(script.Parent.Net)
local Analytics = require(script.Parent.Analytics)

local TutorialService = {}

local DONE = 99

local function target(player: Player, step: number): Vector3?
	local plot = PlotService.GetPlot(player)
	if not plot then
		return nil
	end
	local kind = Config.Tutorial[step].kind
	if kind == "buy" then
		-- The stretch of belt right in front of your base.
		return Vector3.new(plot.cframe.Position.X, 3, 0)
	elseif kind == "collect" then
		return (plot.model:FindFirstChild("Collector") :: BasePart).Position
	elseif kind == "lock" then
		local button = plot.model:FindFirstChild("LockButton")
		return if button and button:IsA("BasePart") then button.Position elseif button then (button :: Model):GetPivot().Position else nil
	end
	return nil
end

local function sync(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local step = data.tutorial
	if step >= 1 and step <= #Config.Tutorial then
		player:SetAttribute("TutorialStep", step)
		player:SetAttribute("TutorialText", Config.Tutorial[step].text)
		player:SetAttribute("TutorialTarget", target(player, step))
	else
		player:SetAttribute("TutorialStep", nil)
		player:SetAttribute("TutorialText", nil)
		player:SetAttribute("TutorialTarget", nil)
	end
end

local function advance(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local step = data.tutorial
	Analytics.Onboarding(player, step + 1, Config.Tutorial[step].kind)
	data.tutorial += 1
	if data.tutorial > #Config.Tutorial then
		data.tutorial = DONE
		local text = Rewards.Grant(player, Config.TutorialReward)
		Net.Fx(player, "tutorialDone", { text = text })
		Analytics.Onboarding(player, #Config.Tutorial + 2, "done")
	else
		Net.Fx(player, "tutorialStep", { step = data.tutorial })
	end
	sync(player)
end

function TutorialService.OnPlayer(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	if data.tutorial == 0 then
		data.tutorial = 1
		Analytics.Onboarding(player, 1, "joined")
	end
	sync(player)
end

function TutorialService.Start()
	Signals.Quest.Event:Connect(function(player: Player, kind: string, amount: number)
		local data = DataService.Get(player)
		local step = data and Config.Tutorial[data.tutorial]
		if step and (kind == step.kind or kind == step.alt) and (kind ~= "collect" or amount > 0) then
			advance(player)
		end
	end)
end

-- For the Studio debug hook: restart the guide.
function TutorialService.Reset(player: Player)
	local data = DataService.Get(player)
	if data then
		data.tutorial = 0
		TutorialService.OnPlayer(player)
	end
end

return TutorialService
