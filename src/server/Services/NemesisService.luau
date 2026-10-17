-- Nemesis: whoever steals from you twice in one session becomes your Nemesis.
-- Only you see the skull over their head. You run faster when they're close,
-- bounties on them pay +50%, and stealing one back from them is an AVENGED! moment.
-- The mark only ever helps the victim, never the thief.

local Players = game:GetService("Players")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Net = require(script.Parent.Net)
local Signals = require(script.Parent.Signals)

local NemesisService = {}

-- victim -> thief -> steals this session
local stolenBy: { [Player]: { [Player]: number } } = {}
local nemesis: { [Player]: Player } = {}

local function set(victim: Player, thief: Player?)
	if not thief then
		-- Drop the chase boost if it was on.
		local hum = victim.Character and victim.Character:FindFirstChildOfClass("Humanoid")
		local base = hum and (hum:GetAttribute("BaseSpeed") or 16)
		if hum and base and math.abs(hum.WalkSpeed - base * Config.Nemesis.chaseSpeed) < 0.05 then
			hum.WalkSpeed = base
		end
		victim:SetAttribute("NemesisNear", nil)
	end
	nemesis[victim] = thief :: any
	victim:SetAttribute("NemesisUserId", thief and thief.UserId)
	victim:SetAttribute("NemesisName", thief and thief.DisplayName)
end

function NemesisService.Is(victim: Player, thief: Player): boolean
	return nemesis[victim] == thief
end

-- A successful steal: `thief` took a slime from `victim`.
function NemesisService.Record(victim: Player, thief: Player)
	-- Getting one back from your Nemesis avenges you.
	if nemesis[thief] == victim then
		set(thief, nil)
		local counts = stolenBy[thief]
		if counts then
			counts[victim] = nil
		end
		Signals.Progress(thief, "avenge")
		Net.FxAll("avenged", { id = thief.UserId, name = thief.DisplayName, on = victim.DisplayName })
		Net.NotifyAll("☠️ " .. thief.DisplayName .. " AVENGED themselves on their Nemesis " .. victim.DisplayName .. "!", "epic")
		Net.Notify(victim, "☠️ " .. thief.DisplayName .. " got even. You're no longer their Nemesis.", "info")
		return
	end
	local counts = stolenBy[victim] or {}
	stolenBy[victim] = counts
	counts[thief] = (counts[thief] or 0) + 1
	if counts[thief] >= Config.Nemesis.steals and nemesis[victim] ~= thief then
		set(victim, thief)
		Net.Fx(victim, "nemesis", { name = thief.DisplayName })
		Net.Notify(victim, "☠️ " .. thief.DisplayName .. " is now your NEMESIS. You're faster near them and their bounty pays +50%!", "epic")
		Net.Notify(thief, "☠️ You've become " .. victim.DisplayName .. "'s NEMESIS. Watch your back!", "bad")
	end
end

function NemesisService.Start()
	-- Chasing your Nemesis: a speed boost while they're close and you're not carrying.
	task.spawn(function()
		while true do
			task.wait(0.4)
			for victim, thief in nemesis do
				local char = victim.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
				local troot = thief.Character and thief.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if hum and root and hum.Health > 0 and not victim:GetAttribute("Carrying") then
					local base = hum:GetAttribute("BaseSpeed") or 16
					local near = troot ~= nil and (troot.Position - root.Position).Magnitude <= Config.Nemesis.chaseRange
					local want = if near then base * Config.Nemesis.chaseSpeed else base
					if math.abs(hum.WalkSpeed - want) > 0.05 and (hum.WalkSpeed == base or hum.WalkSpeed == base * Config.Nemesis.chaseSpeed) then
						hum.WalkSpeed = want
					end
					victim:SetAttribute("NemesisNear", near)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		stolenBy[p] = nil
		nemesis[p] = nil
		for victim, thief in nemesis do
			if thief == p then
				set(victim, nil)
			end
		end
		for _, counts in stolenBy do
			counts[p] = nil
		end
	end)
end

return NemesisService
