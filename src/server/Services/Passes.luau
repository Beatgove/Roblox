-- Caches game pass ownership per player.

local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local Config = require(game.ReplicatedStorage.Shared.Config)

local Passes = {}

local owned: { [Player]: { [string]: boolean } } = {}
Passes.Changed = Instance.new("BindableEvent")

function Passes.Load(player: Player)
	local set = {}
	for key, pass in Config.GamePasses do
		if Config.StudioOwnsAllPasses and RunService:IsStudio() then
			set[key] = true
		elseif pass.id ~= 0 then
			local ok, result = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.id)
			set[key] = ok and result == true
		end
	end
	owned[player] = set
end

function Passes.Owns(player: Player, key: string): boolean
	local set = owned[player]
	return set ~= nil and set[key] == true
end

function Passes.Grant(player: Player, key: string)
	local set = owned[player]
	if set then
		set[key] = true
		Passes.Changed:Fire(player, key)
	end
end

function Passes.KeyForId(passId: number): string?
	for key, pass in Config.GamePasses do
		if pass.id == passId and pass.id ~= 0 then
			return key
		end
	end
	return nil
end

function Passes.Release(player: Player)
	owned[player] = nil
end

return Passes
