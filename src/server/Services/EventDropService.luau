-- Event drops: every event rains its own themed boxes into the street (golden crates in
-- Golden Hour, lava rocks in a Lava Storm, glow orbs in a Blackout...). They fall from the
-- sky, glow on the ground, and the first player to touch one gets what's inside.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Config = require(game.ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local Roller = require(script.Parent.Roller)
local Rewards = require(script.Parent.Rewards)
local Net = require(script.Parent.Net)

local EventDropService = {}

local E = Config.EventDrops
local folder: Folder
local claimed: { [Player]: number } = {} -- pickups during the current event
local currentKey: string? = nil

local LUCKY = { name = "Lucky Box", icon = "🎁", color = Color3.fromRGB(255, 120, 255), material = "Neon" }

local function activeKey(): string?
	if (workspace:GetAttribute("BlackoutUntil") or 0) > workspace:GetServerTimeNow() then
		return "Blackout"
	end
	local e = Roller.ActiveEvent()
	return if e and E.themes[e] then e else nil
end

local function rollLucky()
	local total = 0
	for _, l in E.lucky do
		total += l.weight
	end
	local r = math.random() * total
	for _, l in E.lucky do
		r -= l.weight
		if r <= 0 then
			return l
		end
	end
	return E.lucky[1]
end

-- Gives one random pen slime the trait that belongs to this event.
local function infuse(player: Player, eventKey: string): string?
	local trait
	for name, t in Config.Traits do
		if t.event == eventKey then
			trait = name
		end
	end
	local data = DataService.Get(player)
	if not trait or not data then
		return nil
	end
	local options = {}
	for i, s in data.slimes do
		if not (s.traits and table.find(s.traits, trait)) and #(s.traits or {}) < Config.MaxTraits then
			table.insert(options, i)
		end
	end
	if #options == 0 then
		return nil
	end
	local i = options[math.random(1, #options)]
	local s = data.slimes[i]
	s.traits = s.traits or {}
	table.insert(s.traits, trait)
	local plot = PlotService.GetPlot(player)
	local pad = plot and PlotService.PadFor(player, i)
	local def = Config.Traits[trait]
	if pad then
		Net.FxAll("strike", { pos = pad.Position, color = def.color, icon = def.icon })
	end
	task.delay(0.9, PlotService.Render, player)
	return def.icon .. " " .. s.id .. " got " .. trait .. " (x" .. def.mult .. ")"
end

local function spawnDrop(eventKey: string)
	local lucky = math.random() < E.luckyChance
	local theme = if lucky then LUCKY else E.themes[eventKey]
	local side = if math.random() < 0.5 then -1 else 1
	local ground = Vector3.new(math.random(-E.area.x, E.area.x), 1.6, side * math.random(E.area.zMin, E.area.zMax))
	local box = Instance.new("Part")
	box.Name = "EventDrop"
	box.Size = if eventKey == "Blackout" and not lucky then Vector3.one * 2.4 else Vector3.new(2.8, 2.8, 2.8)
	box.Shape = if eventKey == "Blackout" and not lucky then Enum.PartType.Ball else Enum.PartType.Block
	box.Anchored = true
	box.CanCollide = false
	box.CanQuery = false
	box.Color = theme.color
	box.Material = (Enum.Material :: any)[theme.material] or Enum.Material.SmoothPlastic
	box.CFrame = CFrame.new(ground + Vector3.new(0, 90, 0)) * CFrame.Angles(0, math.random() * 6, 0)
	local light = Instance.new("PointLight")
	light.Color = theme.color
	light.Range = 14
	light.Brightness = 1.6
	light.Parent = box
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(theme.color)
	sparkle.LightEmission = 1
	sparkle.Rate = if lucky then 20 else 8
	sparkle.Size = NumberSequence.new(0.6, 0)
	sparkle.Speed = NumberRange.new(1, 3)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Parent = box
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(6, 2)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.MaxDistance = 90
	gui.Parent = box
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = theme.color
	label.TextStrokeTransparency = 0
	label.Text = theme.icon .. " " .. theme.name
	label.Parent = gui
	if lucky then
		local hl = Instance.new("Highlight")
		hl.FillTransparency = 1
		hl.OutlineColor = Color3.fromRGB(255, 255, 255)
		hl.Parent = box
	end
	box.Parent = folder

	local landed = false
	local taken = false
	local fall = TweenService:Create(box, TweenInfo.new(2.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(ground) * CFrame.Angles(0, math.random() * 6, 0) })
	fall.Completed:Connect(function()
		if box.Parent then
			landed = true
			box.CanTouch = true
			Net.FxAll("dropLand", { pos = ground, color = theme.color, lucky = lucky })
			CollectionService:AddTag(box, "Float")
		end
	end)
	box.CanTouch = false
	fall:Play()

	box.Touched:Connect(function(hit)
		if taken or not landed then
			return
		end
		local model = hit:FindFirstAncestorOfClass("Model")
		local player = model and Players:GetPlayerFromCharacter(model)
		if not player then
			return
		end
		if (claimed[player] or 0) >= E.maxPerPlayer then
			if (player:GetAttribute("DropCapNotified") or 0) < os.clock() - 8 then
				player:SetAttribute("DropCapNotified", os.clock())
				Net.Notify(player, "You've grabbed " .. E.maxPerPlayer .. " drops this event. Leave some for the others!", "info")
			end
			return
		end
		taken = true
		claimed[player] = (claimed[player] or 0) + 1
		local parts = {}
		local title
		if lucky then
			local l = rollLucky()
			title = "🎁 LUCKY BOX: " .. l.label .. "!"
			table.insert(parts, Rewards.Grant(player, l.reward))
			Net.NotifyAll("🎁 " .. player.DisplayName .. " opened a Lucky Box: " .. l.label .. "!", if l.weight <= 15 then "epic" else "info")
		else
			title = theme.icon .. " " .. theme.name .. "!"
			table.insert(parts, Rewards.Grant(player, E.themes[eventKey].reward))
			if math.random() < E.traitChance then
				local t = infuse(player, eventKey)
				if t then
					table.insert(parts, t)
				end
			end
		end
		Net.Fx(player, "dropGrab", { title = title, text = table.concat(parts, " + "), color = theme.color, pos = box.Position, lucky = lucky })
		Net.FxAll("dropTaken", { pos = box.Position, color = theme.color })
		box:Destroy()
	end)
	task.delay(E.lifeSeconds, function()
		if box.Parent then
			box:Destroy()
		end
	end)
end

function EventDropService.Start()
	folder = Instance.new("Folder")
	folder.Name = "EventDrops"
	folder.Parent = workspace
	task.spawn(function()
		while true do
			task.wait(E.every)
			local key = activeKey()
			if key ~= currentKey then
				-- New event: everyone's pickup count starts fresh.
				currentKey = key
				table.clear(claimed)
			end
			if key and #Players:GetPlayers() > 0 then
				for _ = 1, E.perWave do
					spawnDrop(key)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		claimed[p] = nil
	end)
end

-- For the Studio debug hook.
function EventDropService.SpawnNow(key: string)
	spawnDrop(key)
end

return EventDropService
