-- Gear (like the Steal a Brainrot gear shop): Slap Hand, Speed Coil, Gravity Coil, Slime Trap
-- and Slime Taser. Bought once with cash, kept forever, given as tools on every spawn.
-- Slapping or zapping a thief makes them drop your slime, which bounces home.

local Players = game:GetService("Players")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Util = require(game.ReplicatedStorage.Shared.Util)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local StealService = require(script.Parent.StealService)
local Signals = require(script.Parent.Signals)
local BountyService = require(script.Parent.BountyService)
local BossService = require(script.Parent.BossService)
local Net = require(script.Parent.Net)

local GearService = {}

local DEFAULT_SPEED = 16
local DEFAULT_JUMP = 7.2

local cooldowns: { [Player]: { [string]: number } } = {}
local traps: { [Player]: BasePart } = {}
local frozen: { [Model]: boolean } = {}

local function ready(player: Player, key: string, seconds: number): boolean
	cooldowns[player] = cooldowns[player] or {}
	local t = os.clock()
	local last = cooldowns[player][key]
	if last and t - last < seconds then
		return false
	end
	cooldowns[player][key] = t
	return true
end

local function rootOf(player: Player): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- The closest other player in front of `player` within `range` studs.
local function targetInFront(player: Player, range: number, minDot: number): Player?
	local root = rootOf(player)
	if not root then
		return nil
	end
	local best, bestDist = nil, range
	for _, other in Players:GetPlayers() do
		local r = other ~= player and rootOf(other)
		local hum = r and other.Character:FindFirstChildOfClass("Humanoid")
		if r and hum and hum.Health > 0 then
			local offset = r.Position - root.Position
			local dist = offset.Magnitude
			if dist < bestDist and (dist < 3 or root.CFrame.LookVector:Dot(offset.Unit) > minDot) then
				best, bestDist = other, dist
			end
		end
	end
	return best
end

-- Freezes a character in place for `seconds` (anchoring replicates even for client-owned parts).
local function freeze(player: Player, seconds: number)
	local char = player.Character
	local root = rootOf(player)
	if not char or not root or frozen[char] then
		return
	end
	frozen[char] = true
	root.Anchored = true
	Net.Fx(player, "frozen", { seconds = seconds })
	task.delay(seconds, function()
		frozen[char] = nil
		if root.Parent then
			root.Anchored = false
		end
	end)
end

local function hitThief(attacker: Player, target: Player)
	BountyService.Claim(attacker, target)
	if StealService.IsCarrying(target) then
		StealService.Drop(target)
		Net.Notify(attacker, "You knocked the slime out of " .. target.DisplayName .. "'s hands!", "epic")
	end
end

local function useSlap(player: Player, def)
	if not ready(player, "Slap", def.cooldown) then
		return
	end
	local root = rootOf(player)
	if not root then
		return
	end
	Net.FxAll("swing", { pos = root.Position })
	local target = targetInFront(player, def.range, 0.2)
	local tRoot = target and rootOf(target)
	-- Slap the King Slime unless a player is closer (so you can still slap a thief beside it).
	local king = workspace:FindFirstChild("KingSlime") :: Model?
	local kingDist = if king then (king:GetPivot().Position - root.Position).Magnitude - Config.King.size / 2 else math.huge
	if (not tRoot or kingDist < (tRoot.Position - root.Position).Magnitude) and BossService.TryHit(player, root.Position, def.range, Config.King.slapDamage) then
		return
	end
	if not target or not tRoot then
		return
	end
	local dir = (tRoot.Position - root.Position) * Vector3.new(1, 0, 1)
	dir = if dir.Magnitude > 0.1 then dir.Unit else root.CFrame.LookVector
	Net.FxAll("slap", { pos = tRoot.Position })
	Net.Fx(target, "knock", { dir = dir, force = def.force })
	Signals.Progress(player, "slap")
	hitThief(player, target)
end

local function useTrap(player: Player, def)
	local root = rootOf(player)
	if not root then
		return
	end
	if not ready(player, "Trap", def.cooldown) then
		Net.Notify(player, "Trap is recharging...", "bad")
		return
	end
	if traps[player] then
		traps[player]:Destroy()
	end
	local trap = Instance.new("Part")
	trap.Name = "SlimeTrap"
	trap.Shape = Enum.PartType.Cylinder
	trap.Size = Vector3.new(0.4, 6, 6)
	trap.CFrame = CFrame.new(root.Position.X, 0.25, root.Position.Z) * CFrame.Angles(0, 0, math.pi / 2)
	trap.Anchored = true
	trap.CanCollide = false
	trap.Material = Enum.Material.Neon
	trap.Color = def.color
	trap.Transparency = 0.25
	trap.Parent = workspace
	traps[player] = trap
	Net.FxAll("trapPlaced", { pos = trap.Position })
	trap.Touched:Connect(function(hit)
		local victim = Players:GetPlayerFromCharacter(hit.Parent)
		if not victim or victim == player or not trap.Parent then
			return
		end
		Net.FxAll("trapped", { pos = trap.Position })
		Net.Notify(victim, "You stepped in " .. player.DisplayName .. "'s Slime Trap!", "bad")
		Net.Notify(player, "Your trap caught " .. victim.DisplayName .. "!", "good")
		trap:Destroy()
		BountyService.Claim(player, victim)
		freeze(victim, def.freeze)
	end)
	task.delay(def.life, function()
		if trap.Parent then
			trap:Destroy()
		end
	end)
end

local function useTaser(player: Player, def)
	local root = rootOf(player)
	if not root then
		return
	end
	if not ready(player, "Taser", def.cooldown) then
		Net.Notify(player, "Taser is recharging...", "bad")
		return
	end
	local target = targetInFront(player, def.range, 0.85)
	local tRoot = target and rootOf(target)
	if not target and BossService.TryHit(player, root.Position, def.range, Config.King.taserDamage) then
		local king = workspace:FindFirstChild("KingSlime") :: Model?
		Net.FxAll("zap", { from = root.Position, to = if king then king:GetPivot().Position else root.Position })
		return
	end
	if not target or not tRoot then
		Net.FxAll("zap", { from = root.Position, to = root.Position + root.CFrame.LookVector * def.range })
		return
	end
	Net.FxAll("zap", { from = root.Position, to = tRoot.Position })
	Net.Notify(target, "ZAPPED by " .. player.DisplayName .. "!", "bad")
	hitThief(player, target)
	freeze(target, def.stun)
end

local function setMovement(player: Player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	local tool = char:FindFirstChildOfClass("Tool")
	local key = tool and tool:GetAttribute("Gear")
	local speed = if key == "SpeedCoil" then Config.Gear.SpeedCoil.walkSpeed else DEFAULT_SPEED
	hum:SetAttribute("BaseSpeed", speed)
	hum:SetAttribute("CarryBonus", if key == "SpeedCoil" then 6 else 0)
	hum.UseJumpPower = false
	hum.JumpHeight = if key == "GravityCoil" then Config.Gear.GravityCoil.jumpHeight else DEFAULT_JUMP
	if not StealService.IsCarrying(player) or player:GetAttribute("RevengeCarry") then
		hum.WalkSpeed = speed
	else
		hum.WalkSpeed = (Config.CarryWalkSpeed + (hum:GetAttribute("CarryBonus") or 0)) * (player:GetAttribute("CarrySlow") or 1)
	end
end

local function makeTool(player: Player, key: string): Tool
	local def = Config.Gear[key]
	local tool = Instance.new("Tool")
	tool.Name = def.name
	tool.ToolTip = def.desc
	tool.CanBeDropped = false
	tool:SetAttribute("Gear", key)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = if key == "Slap" then Vector3.new(1.6, 0.4, 1.8) elseif key == "Trap" then Vector3.new(1.4, 0.4, 1.4) else Vector3.new(0.6, 0.6, 2.4)
	handle.Color = def.color
	handle.Material = Enum.Material.Neon
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	local light = Instance.new("PointLight")
	light.Color = def.color
	light.Range = 6
	light.Parent = handle

	tool.Equipped:Connect(function()
		setMovement(player)
	end)
	tool.Unequipped:Connect(function()
		task.defer(setMovement, player)
	end)
	tool.Activated:Connect(function()
		if key == "Slap" then
			useSlap(player, def)
		elseif key == "Trap" then
			useTrap(player, def)
		elseif key == "Taser" then
			useTaser(player, def)
		end
	end)
	return tool
end

function GearService.Give(player: Player)
	local data = DataService.Get(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not data or not backpack then
		return
	end
	data.gear.Slap = true
	local have = {}
	for _, container in { backpack, player.Character } do
		if container then
			for _, t in container:GetChildren() do
				if t:IsA("Tool") and t:GetAttribute("Gear") then
					have[t:GetAttribute("Gear")] = true
				end
			end
		end
	end
	for _, key in Config.GearOrder do
		if data.gear[key] and not have[key] then
			makeTool(player, key).Parent = backpack
		end
	end
	local list = {}
	for _, key in Config.GearOrder do
		if data.gear[key] then
			table.insert(list, key)
		end
	end
	player:SetAttribute("GearOwned", table.concat(list, ","))
end

local function buy(player: Player, key: string)
	local def = typeof(key) == "string" and Config.Gear[key]
	local data = DataService.Get(player)
	if not def or not data then
		return
	end
	if data.gear[key] then
		Net.Notify(player, "You already own the " .. def.name .. "!", "info")
		return
	end
	if data.rebirths < def.rebirth then
		Net.Notify(player, def.name .. " unlocks at Rebirth " .. def.rebirth, "bad")
		Net.Fx(player, "deny", {})
		return
	end
	if data.cash < def.price then
		Net.Notify(player, "The " .. def.name .. " costs " .. Util.Money(def.price), "bad")
		Net.Fx(player, "deny", {})
		return
	end
	data.cash -= def.price
	data.gear[key] = true
	PlotService.Sync(player)
	GearService.Give(player)
	Net.Fx(player, "gear", { name = def.name })
	Net.Notify(player, "Got the " .. def.name .. "! It's in your hotbar.", "epic")
end

function GearService.OnPlayer(player: Player)
	player.CharacterAdded:Connect(function(char)
		char:WaitForChild("Humanoid", 10)
		GearService.Give(player)
		setMovement(player)
	end)
	if player.Character then
		GearService.Give(player)
	end
end

function GearService.Start()
	Net.BuyGearEvent.OnServerEvent:Connect(buy)
	Players.PlayerRemoving:Connect(function(p)
		cooldowns[p] = nil
		if traps[p] then
			traps[p]:Destroy()
			traps[p] = nil
		end
	end)
end

return GearService
