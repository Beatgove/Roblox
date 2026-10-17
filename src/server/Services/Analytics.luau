-- Thin wrapper around Roblox AnalyticsService so a failing call never breaks gameplay.
-- Shows up in Creator Hub > Analytics: the onboarding funnel (where new players quit)
-- and custom events (rebirths, steals, minigames...).

local AnalyticsService = game:GetService("AnalyticsService")

local Signals = require(script.Parent.Signals)

local Analytics = {}

function Analytics.Onboarding(player: Player, step: number, name: string)
	pcall(AnalyticsService.LogOnboardingFunnelStepEvent, AnalyticsService, player, step, name)
end

function Analytics.Custom(player: Player, name: string, value: number?)
	pcall(AnalyticsService.LogCustomEvent, AnalyticsService, player, name, value or 1)
end

-- Gameplay moments worth counting (keep this list short: Roblox caps custom event names).
local TRACKED = { steal = "Steal", rebirth = "Rebirth", minigame = "Minigame", boss = "KingSlime", fuse = "Fuse", evolve = "Evolve", avenge = "Avenge" }

function Analytics.Start()
	Signals.Quest.Event:Connect(function(player: Player, kind: string)
		local name = TRACKED[kind]
		if name then
			Analytics.Custom(player, name)
		end
	end)
end

return Analytics
