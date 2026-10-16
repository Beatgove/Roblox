-- Base upgrades: permanent cash sinks (Slime Food income, Stronger Shield, Bigger Base).

local Config = require(game.ReplicatedStorage.Shared.Config)
local Util = require(game.ReplicatedStorage.Shared.Util)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local Net = require(script.Parent.Net)

local UpgradeService = {}

local function buy(player: Player, key: string)
	local def = typeof(key) == "string" and Config.Upgrades[key]
	local data = DataService.Get(player)
	if not def or not data then
		return
	end
	local level = data.upgrades[key] or 0
	if level >= def.max then
		Net.Notify(player, def.name .. " is maxed out!", "info")
		return
	end
	local cost = Config.UpgradeCost(key, level)
	if data.cash < cost then
		Net.Notify(player, def.name .. " level " .. (level + 1) .. " costs " .. Util.Money(cost), "bad")
		Net.Fx(player, "deny", {})
		return
	end
	data.cash -= cost
	data.upgrades[key] = level + 1
	if key == "Pens" then
		PlotService.Render(player)
	else
		PlotService.Sync(player)
	end
	Net.Fx(player, "upgrade", { name = def.name, level = level + 1 })
	Net.Notify(player, "⬆️ " .. def.name .. " is now level " .. (level + 1) .. "!", "epic")
end

function UpgradeService.Start()
	Net.BuyUpgradeEvent.OnServerEvent:Connect(buy)
end

return UpgradeService
