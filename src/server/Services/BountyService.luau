-- Bounties: every successful steal puts cash on the thief's head. Anyone who slaps, zaps or
-- traps a WANTED player cashes it in. Thieves become targets, and defenders get paid.

local Players = game:GetService("Players")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Util = require(game.ReplicatedStorage.Shared.Util)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local Signals = require(script.Parent.Signals)
local Net = require(script.Parent.Net)
local NemesisService = require(script.Parent.NemesisService)

local BountyService = {}

local bounties: { [Player]: number } = {}

local function updateTag(player: Player)
	local amount = bounties[player] or 0
	player:SetAttribute("Bounty", amount)
	local head = player.Character and player.Character:FindFirstChild("Head")
	if not head then
		return
	end
	local gui = head:FindFirstChild("BountyTag") :: BillboardGui?
	if amount <= 0 then
		if gui then
			gui:Destroy()
		end
		return
	end
	if not gui then
		local g = Instance.new("BillboardGui")
		g.Name = "BountyTag"
		g.Size = UDim2.fromOffset(200, 30)
		g.StudsOffset = Vector3.new(0, 5.2, 0)
		g.AlwaysOnTop = true
		g.MaxDistance = 150
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(255, 215, 60)
		label.TextStrokeTransparency = 0
		label.Parent = g
		g.Parent = head
		gui = g
	end
	((gui :: BillboardGui):FindFirstChild("Text") :: TextLabel).Text = "💰 WANTED " .. Util.Money(amount)
end

function BountyService.Get(player: Player): number
	return bounties[player] or 0
end

function BountyService.Add(player: Player, amount: number)
	amount = math.floor(amount)
	if amount <= 0 then
		return
	end
	local before = bounties[player] or 0
	bounties[player] = before + amount
	updateTag(player)
	-- Big bounties get announced so the whole server starts hunting.
	for _, step in { 10000, 1000000, 1000000000 } do
		if before < step and bounties[player] >= step then
			Net.NotifyAll("💰 " .. player.DisplayName .. " is WANTED for " .. Util.Money(bounties[player]) .. "! Slap them to claim it!", "epic")
			break
		end
	end
	Net.Notify(player, "💰 You're WANTED! Bounty: " .. Util.Money(bounties[player]) .. ". Don't get slapped!", "bad")
end

-- Called when `attacker` lands a slap, zap or trap on `target`.
function BountyService.Claim(attacker: Player, target: Player)
	local amount = bounties[target]
	if attacker == target or not amount or amount <= 0 then
		return
	end
	-- Paid out of the thief's own cash, so bounties never create money (no farming with a friend).
	local thiefData = DataService.Get(target)
	local cap = math.max(Config.BountyMinPayout, PlotService.IncomePerSecond(attacker) * Config.BountyMaxIncomeSeconds)
	-- Busting your Nemesis pays +50% (still out of their pocket).
	local isNemesis = NemesisService.Is(attacker, target)
	if isNemesis then
		amount *= Config.Nemesis.bountyMult
		cap *= Config.Nemesis.bountyMult
	end
	local paid = math.floor(math.min(amount, cap, if thiefData then thiefData.cash else 0))
	bounties[target] = nil
	updateTag(target)
	if paid <= 0 then
		Net.Notify(attacker, "You busted " .. target.DisplayName .. ", but they're broke. No bounty to collect!", "info")
		return
	end
	if thiefData then
		thiefData.cash -= paid
		PlotService.Sync(target)
	end
	PlotService.AddCash(attacker, paid)
	Signals.Progress(attacker, "bounty")
	Net.Fx(attacker, "bounty", { amount = paid })
	Net.Notify(attacker, "💰 BOUNTY CLAIMED on " .. (if isNemesis then "your Nemesis " else "") .. target.DisplayName .. "! +" .. Util.Money(paid), "epic")
	Net.Notify(target, attacker.DisplayName .. " claimed the bounty on your head!", "bad")
	if paid >= 10000 then
		Net.NotifyAll("💰 " .. attacker.DisplayName .. " collected a " .. Util.Money(paid) .. " bounty on " .. target.DisplayName .. "!", "epic")
	end
end

function BountyService.Start()
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(char)
			char:WaitForChild("Head", 10)
			updateTag(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		bounties[p] = nil
	end)
end

return BountyService
