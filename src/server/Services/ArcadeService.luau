-- Whack-a-Slime: a 30-second arcade round. Slimes pop out of 9 holes; click or tap them.
-- Golden ones are worth 3, bombs cost 2. Score turns into cash (and snacks / luck for big scores).

local Players = game:GetService("Players")

local Config = require(game.ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local Net = require(script.Parent.Net)
local Rewards = require(script.Parent.Rewards)
local Signals = require(script.Parent.Signals)

local ArcadeService = {}

local A = Config.Arcade
local MACHINES = 2

type Machine = { origin: CFrame, holes: { CFrame }, up: { [number]: Model }, player: Player?, score: number, screen: TextLabel, folder: Folder }
local machines: { Machine } = {}
local best = { name = "nobody yet", score = 0 }

local function part(parent: Instance, props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

local function updateScreen(m: Machine)
	if m.player then
		m.screen.Text = "🔨 " .. m.player.DisplayName .. "\nSCORE " .. m.score
	else
		m.screen.Text = "🔨 WHACK-A-SLIME\nBest today: " .. best.name .. " " .. best.score
	end
end

local function makeMole(kind: string, cf: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "Mole"
	local color = if kind == "golden" then Color3.fromRGB(255, 210, 60) elseif kind == "bomb" then Color3.fromRGB(40, 35, 50) else Color3.fromHSV(math.random(), 0.55, 1)
	local body = part(model, { Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.one * 2.4, CFrame = cf, Color = color,
		Material = if kind == "golden" then Enum.Material.Neon else Enum.Material.SmoothPlastic, CanCollide = false })
	model.PrimaryPart = body
	if kind == "bomb" then
		for i = 1, 6 do
			local a = i / 6 * math.pi * 2
			part(model, { Name = "Spike", Size = Vector3.new(0.4, 0.9, 0.4), CFrame = cf * CFrame.Angles(math.cos(a), 0, math.sin(a)) * CFrame.new(0, 1.3, 0), Color = Color3.fromRGB(255, 50, 60), Material = Enum.Material.Neon, CanCollide = false })
		end
	else
		for _, side in { -1, 1 } do
			part(model, { Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.new(0.35, 0.5, 0.2), CFrame = cf * CFrame.new(side * 0.4, 0.25, -1.08), Color = Color3.new(0.05, 0.05, 0.08), CanCollide = false })
		end
	end
	model:SetAttribute("Kind", kind)
	return model
end

local function finish(m: Machine)
	local player = m.player
	local score = math.max(0, m.score)
	m.player = nil
	for i, mole in m.up do
		mole:Destroy()
		m.up[i] = nil
	end
	if player and player.Parent then
		player:SetAttribute("ArcadeScore", nil)
		player:SetAttribute("ArcadeUntil", nil)
		local paid = math.min(score, A.maxPaidScore)
		local cash = math.max(paid * A.minPerPoint, math.floor(PlotService.IncomePerSecond(player) * paid * A.cashPerPoint))
		local reward: { [string]: any } = { cash = cash }
		if score >= A.snackAt then
			reward.snacks = 1
		end
		if score >= A.luckAt then
			reward.luckMinutes = 5
		end
		local text = if score > 0 then Rewards.Grant(player, reward, { minigame = true }) else "nothing this time"
		Signals.Progress(player, "minigame")
		local record = score > best.score
		if record then
			best = { name = player.DisplayName, score = score }
			Net.NotifyAll("🔨 " .. player.DisplayName .. " set a new Whack-a-Slime record: " .. score .. "!", "epic")
		end
		Net.Fx(player, "arcadeEnd", { score = score, text = text, record = record })
	end
	updateScreen(m)
end

local function play(m: Machine, player: Player)
	if m.player then
		if m.player ~= player then
			Net.Notify(player, m.player.DisplayName .. " is playing. Try the other machine!", "bad")
		end
		return
	end
	for _, other in machines do
		if other.player == player then
			return
		end
	end
	-- The rest is saved in data (os.time), so rejoining doesn't skip it.
	local data = DataService.Get(player)
	if not data then
		return
	end
	local rest = (data.arcadeAt or 0) + A.seconds + A.restSeconds - os.time()
	if rest > 0 then
		Net.Notify(player, "🔨 Catch your breath! Next round in " .. math.ceil(rest) .. "s.", "info")
		return
	end
	data.arcadeAt = os.time()
	m.player = player
	m.score = 0
	updateScreen(m)
	local endsAt = workspace:GetServerTimeNow() + A.seconds
	player:SetAttribute("ArcadeScore", 0)
	player:SetAttribute("ArcadeUntil", endsAt)
	Net.Fx(player, "arcadeStart", { seconds = A.seconds })
	local started = os.clock()
	task.spawn(function()
		while os.clock() - started < A.seconds and m.player == player and player.Parent do
			local t = (os.clock() - started) / A.seconds
			local upTime = A.upStart + (A.upEnd - A.upStart) * t
			-- Pop a slime in a random empty hole.
			local free = {}
			for i = 1, #m.holes do
				if not m.up[i] then
					table.insert(free, i)
				end
			end
			if #free > 0 then
				local i = free[math.random(1, #free)]
				local r = math.random()
				local kind = if r < A.bombChance then "bomb" elseif r < A.bombChance + A.goldenChance then "golden" else "normal"
				local mole = makeMole(kind, m.holes[i] * CFrame.new(0, 1.1, 0))
				local click = Instance.new("ClickDetector")
				click.MaxActivationDistance = 32
				click.Parent = mole.PrimaryPart
				click.MouseClick:Connect(function(who)
					if who ~= m.player or m.up[i] ~= mole then
						return
					end
					m.up[i] = nil
					local points = if kind == "golden" then 3 elseif kind == "bomb" then -2 else 1
					m.score = math.max(0, m.score + points)
					player:SetAttribute("ArcadeScore", m.score)
					updateScreen(m)
					Net.Fx(player, "whack", { pos = mole.PrimaryPart.Position, points = points, color = (mole.PrimaryPart :: BasePart).Color })
					mole:Destroy()
				end)
				mole.Parent = m.folder
				m.up[i] = mole
				task.delay(upTime, function()
					if m.up[i] == mole then
						m.up[i] = nil
						mole:Destroy()
					end
				end)
			end
			task.wait(math.max(0.22, upTime * 0.42))
		end
		if m.player == player then
			finish(m)
		end
	end)
end

local function buildMachine(index: number, origin: CFrame)
	local folder = Instance.new("Folder")
	folder.Name = "WhackASlime" .. index
	folder.Parent = workspace
	-- Booth: a raised table with 9 holes, a back screen and a start button in front.
	part(folder, { Name = "Base", Size = Vector3.new(16, 1, 18), CFrame = origin * CFrame.new(0, 0.5, 0), Color = Color3.fromRGB(60, 40, 90), Material = Enum.Material.SmoothPlastic })
	part(folder, { Name = "Table", Size = Vector3.new(12, 3, 12), CFrame = origin * CFrame.new(0, 2.5, 2), Color = Color3.fromRGB(255, 120, 200), Material = Enum.Material.SmoothPlastic })
	part(folder, { Name = "TableTop", Size = Vector3.new(12.4, 0.4, 12.4), CFrame = origin * CFrame.new(0, 4.2, 2), Color = Color3.fromRGB(255, 220, 90), Material = Enum.Material.Neon })
	local holes = {}
	for zi = -1, 1 do
		for xi = -1, 1 do
			local cf = origin * CFrame.new(xi * 3.6, 4.2, 2 + zi * 3.6)
			part(folder, { Name = "Hole", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 2.8, 2.8), CFrame = cf * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(25, 15, 35), Material = Enum.Material.SmoothPlastic })
			table.insert(holes, cf)
		end
	end
	local back = part(folder, { Name = "Screen", Size = Vector3.new(14, 7, 1), CFrame = origin * CFrame.new(0, 8, 8.5), Color = Color3.fromRGB(30, 20, 50), Material = Enum.Material.SmoothPlastic })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = back
	local screen = Instance.new("TextLabel")
	screen.Size = UDim2.fromScale(1, 1)
	screen.BackgroundTransparency = 1
	screen.Font = Enum.Font.FredokaOne
	screen.TextScaled = true
	screen.TextColor3 = Color3.fromRGB(255, 230, 120)
	screen.TextStrokeTransparency = 0.3
	screen.Parent = gui
	for _, x in { -7.5, 7.5 } do
		local bulb = part(folder, { Name = "Bulb", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.6, CFrame = origin * CFrame.new(x, 12, 8.5), Color = Color3.fromRGB(255, 90, 200), Material = Enum.Material.Neon })
		local l = Instance.new("PointLight")
		l.Color = bulb.Color
		l.Range = 14
		l.Parent = bulb
	end
	local start = part(folder, { Name = "StartPad", Size = Vector3.new(5, 0.6, 3), CFrame = origin * CFrame.new(0, 1.2, -6), Color = Color3.fromRGB(90, 255, 140), Material = Enum.Material.Neon })
	local m: Machine = { origin = origin, holes = holes, up = {}, player = nil, score = 0, screen = screen, folder = folder }
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Play (30s)"
	prompt.ObjectText = "🔨 Whack-a-Slime"
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = start
	prompt.Triggered:Connect(function(who)
		play(m, who)
	end)
	updateScreen(m)
	table.insert(machines, m)
end

-- Starts a round on the first free machine (used by the Studio debug hook).
function ArcadeService.PlayAny(player: Player)
	for _, m in machines do
		if not m.player then
			play(m, player)
			return
		end
	end
end

function ArcadeService.Start()
	for i = 1, MACHINES do
		-- Machines face the street (-X), side by side along Z.
		local pos = A.pos + Vector3.new(0, 0, (i - 1.5) * 20)
		buildMachine(i, CFrame.lookAt(pos, pos + Vector3.new(-1, 0, 0)))
	end
	Players.PlayerRemoving:Connect(function(p)
		for _, m in machines do
			if m.player == p then
				finish(m)
			end
		end
	end)
	-- Show who has the record on the machines.
	task.spawn(function()
		while true do
			task.wait(5)
			for _, m in machines do
				if not m.player then
					updateScreen(m)
				end
			end
		end
	end)
end

return ArcadeService
