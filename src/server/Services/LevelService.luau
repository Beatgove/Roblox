-- Player levels: XP for buying, rolling, stealing, merging, quests... Each level pays cash,
-- every 5th level adds luck, and titles show over your head (Slime Rookie -> Slime Legend).

local Config = require(game.ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Rewards = require(script.Parent.Rewards)
local Signals = require(script.Parent.Signals)
local Net = require(script.Parent.Net)
local Analytics = require(script.Parent.Analytics)

local LevelService = {}

local function titleFor(level: number)
	local best = Config.Titles[1]
	for _, t in Config.Titles do
		if level >= t.level then
			best = t
		end
	end
	return best
end

local function updateTag(player: Player)
	local data = DataService.Get(player)
	local head = player.Character and player.Character:FindFirstChild("Head")
	if not data or not head then
		return
	end
	local gui = head:FindFirstChild("LevelTag") :: BillboardGui?
	if not gui then
		local g = Instance.new("BillboardGui")
		g.Name = "LevelTag"
		g.Size = UDim2.fromOffset(200, 26)
		g.StudsOffset = Vector3.new(0, 3.6, 0)
		g.MaxDistance = 70
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextStrokeTransparency = 0.2
		label.Parent = g
		g.Parent = head
		gui = g
	end
	local t = titleFor(data.level)
	local label = (gui :: BillboardGui):FindFirstChild("Text") :: TextLabel
	label.Text = "Lv " .. data.level .. " · " .. t.name
	label.TextColor3 = t.color
end

local function sync(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	player:SetAttribute("Level", data.level)
	player:SetAttribute("XP", data.xp)
	player:SetAttribute("XPNeeded", Config.XPForLevel(data.level))
	player:SetAttribute("Title", titleFor(data.level).name)
end

function LevelService.AddXP(player: Player, amount: number)
	local data = DataService.Get(player)
	if not data or amount <= 0 then
		return
	end
	data.xp += amount
	local leveled = false
	while data.xp >= Config.XPForLevel(data.level) do
		data.xp -= Config.XPForLevel(data.level)
		data.level += 1
		leveled = true
		Analytics.Progress(player, "Level", data.level)
		local reward = { cashSeconds = 120, cashMin = 250 * data.level }
		if data.level % 5 == 0 then
			reward.luckMinutes = 10
		end
		local text = Rewards.Grant(player, reward)
		local before = titleFor(data.level - 1)
		local now = titleFor(data.level)
		Net.Fx(player, "levelUp", { level = data.level, title = if now ~= before then now.name else nil })
		Net.Notify(player, "⭐ LEVEL " .. data.level .. "! " .. text, "epic")
		if now ~= before then
			Net.NotifyAll(player.DisplayName .. " is now a " .. now.name .. "!", "epic")
		end
	end
	sync(player)
	if leveled then
		updateTag(player)
	end
end

function LevelService.OnPlayer(player: Player)
	sync(player)
	player.CharacterAdded:Connect(function(char)
		char:WaitForChild("Head", 10)
		updateTag(player)
	end)
	if player.Character then
		updateTag(player)
	end
end

function LevelService.Start()
	Signals.Quest.Event:Connect(function(player, kind, amount)
		if kind == "collect" then
			LevelService.AddXP(player, math.min(50, math.floor(amount * Config.XPPerCollect)))
		elseif Config.XP[kind] then
			LevelService.AddXP(player, Config.XP[kind] * (if kind == "slap" then 1 else amount))
		end
	end)
end

return LevelService
