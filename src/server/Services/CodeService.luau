-- Redeemable codes (Config.Codes). Each code works once per player.

local Config = require(game.ReplicatedStorage.Shared.Config)
local Util = require(game.ReplicatedStorage.Shared.Util)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local DispenserService = require(script.Parent.DispenserService)
local Net = require(script.Parent.Net)

local CodeService = {}

local lastTry: { [Player]: number } = {}

local function redeem(player: Player, raw: any): (boolean, string)
	if typeof(raw) ~= "string" or #raw > 40 then
		return false, "That's not a valid code."
	end
	local t = os.clock()
	if lastTry[player] and t - lastTry[player] < 1 then
		return false, "Slow down!"
	end
	lastTry[player] = t

	local data = DataService.Get(player)
	if not data then
		return false, "Still loading, try again in a second."
	end
	local key = raw:upper():gsub("%s+", "")
	local code = Config.Codes[key]
	if not code then
		return false, "Invalid code."
	end
	if code.expires and os.time() >= code.expires then
		return false, "That code has expired."
	end
	if data.codes[key] then
		return false, "You already used this code."
	end
	if code.slime and not PlotService.HasFreeSlot(player) then
		return false, "Free up a pen first, this code gives a slime!"
	end

	data.codes[key] = true
	local parts = {}
	if code.cash or code.incomeSeconds then
		local amount = math.max(code.cash or 0, math.floor(PlotService.IncomePerSecond(player) * (code.incomeSeconds or 0)))
		PlotService.AddCash(player, amount)
		table.insert(parts, "+" .. Util.Money(amount))
	end
	if code.luckMinutes then
		DispenserService.GiveLuck(player, code.luckMinutes * 60)
		table.insert(parts, code.luckMinutes .. " min 5x LUCK")
	end
	if code.slime then
		PlotService.AddSlime(player, { id = code.slime, born = os.time() })
		Net.Fx(player, "reveal", { name = Config.SlimeName(code.slime), rarity = Config.SlimeById[code.slime].rarity })
		table.insert(parts, code.slime .. " slime")
	end
	Net.Fx(player, "code", {})
	DataService.Save(player)
	return true, code.msg or table.concat(parts, " + ")
end

function CodeService.Start()
	Net.RedeemCode.OnServerInvoke = function(player, raw)
		local ok, ok2, msg = pcall(redeem, player, raw)
		if not ok then
			warn("[CodeService]", ok2)
			return false, "Something went wrong, try again."
		end
		return ok2, msg
	end
	game:GetService("Players").PlayerRemoving:Connect(function(p)
		lastTry[p] = nil
	end)
end

return CodeService
