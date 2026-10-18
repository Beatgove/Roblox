-- King Slime: a giant co-op boss that crashes into the middle of the map every 12 minutes.
-- Everyone slaps (or zaps) it together while it hops around and stomps players away.
-- Beat it before it escapes and everyone who hit it gets paid; the top hitter also gets a
-- lucky Dispenser roll. Thieves and victims end up on the same side for a minute.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Rewards = require(script.Parent.Rewards)
local Signals = require(script.Parent.Signals)
local Net = require(script.Parent.Net)

local BossService = {}

local K = Config.King

type Boss = {
	model: Model,
	body: BasePart,
	hp: number,
	maxHp: number,
	hits: { [Player]: number },
	alive: boolean,
	fill: Frame,
	hpText: TextLabel,
}

local boss: Boss? = nil

local function part(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local function build(): Boss
	local model = Instance.new("Model")
	model.Name = "KingSlime"
	local size = K.size
	local body = part({
		Name = "Body",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * size,
		Color = Color3.fromRGB(120, 230, 90),
		Material = Enum.Material.Glass,
		Transparency = 0.15,
		CanQuery = true,
	})
	body.Parent = model
	model.PrimaryPart = body
	local function attach(p: BasePart, offset: CFrame)
		p.CFrame = body.CFrame * offset
		p.Parent = model
	end
	-- Inner glow and face
	attach(part({ Shape = Enum.PartType.Ball, Size = Vector3.one * size * 0.7, Color = Color3.fromRGB(190, 255, 120), Material = Enum.Material.Neon, Transparency = 0.5 }), CFrame.new())
	for _, side in { -1, 1 } do
		attach(part({ Shape = Enum.PartType.Ball, Size = Vector3.one * size * 0.2, Color = Color3.new(1, 1, 1), Material = Enum.Material.SmoothPlastic }), CFrame.new(side * size * 0.18, size * 0.1, -size * 0.42))
		attach(part({ Shape = Enum.PartType.Ball, Size = Vector3.one * size * 0.1, Color = Color3.fromRGB(20, 10, 30), Material = Enum.Material.SmoothPlastic }), CFrame.new(side * size * 0.18, size * 0.1, -size * 0.5))
		-- Angry brows
		attach(part({ Size = Vector3.new(size * 0.22, size * 0.05, size * 0.05), Color = Color3.fromRGB(30, 60, 20) }), CFrame.new(side * size * 0.18, size * 0.24, -size * 0.45) * CFrame.Angles(0, 0, side * 0.35))
	end
	-- Crown
	local crownY = size * 0.5
	attach(part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(size * 0.18, size * 0.55, size * 0.55), Color = Color3.fromRGB(255, 205, 50), Material = Enum.Material.Neon }), CFrame.new(0, crownY, 0) * CFrame.Angles(0, 0, math.pi / 2))
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2
		attach(part({ Size = Vector3.new(size * 0.09, size * 0.22, size * 0.09), Color = Color3.fromRGB(255, 205, 50), Material = Enum.Material.Neon }), CFrame.new(math.cos(a) * size * 0.22, crownY + size * 0.17, math.sin(a) * size * 0.22))
		attach(part({ Shape = Enum.PartType.Ball, Size = Vector3.one * size * 0.07, Color = Color3.fromRGB(255, 60, 120), Material = Enum.Material.Neon }), CFrame.new(math.cos(a) * size * 0.22, crownY + size * 0.3, math.sin(a) * size * 0.22))
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= body then
			local w = Instance.new("WeldConstraint")
			w.Part0 = body
			w.Part1 = d
			w.Parent = d
		end
	end
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(150, 255, 100)
	light.Range = 30
	light.Brightness = 2
	light.Parent = body

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(300, 64)
	gui.StudsOffset = Vector3.new(0, size * 0.9, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 250
	gui.Parent = body
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.5, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 215, 60)
	title.TextStrokeTransparency = 0
	title.Text = "👑 KING SLIME"
	title.Parent = gui
	local back = Instance.new("Frame")
	back.Position = UDim2.new(0.05, 0, 0.55, 0)
	back.Size = UDim2.new(0.9, 0, 0.4, 0)
	back.BackgroundColor3 = Color3.fromRGB(30, 15, 40)
	back.Parent = gui
	Instance.new("UICorner", back).CornerRadius = UDim.new(0.5, 0)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(120, 255, 90)
	fill.Parent = back
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0.5, 0)
	local hpText = Instance.new("TextLabel")
	hpText.Size = UDim2.fromScale(1, 1)
	hpText.BackgroundTransparency = 1
	hpText.Font = Enum.Font.FredokaOne
	hpText.TextScaled = true
	hpText.TextColor3 = Color3.new(1, 1, 1)
	hpText.TextStrokeTransparency = 0
	hpText.Parent = back

	local maxHp = K.baseHp + K.hpPerPlayer * #Players:GetPlayers()
	return { model = model, body = body, hp = maxHp, maxHp = maxHp, hits = {}, alive = true, fill = fill, hpText = hpText }
end

local function updateBar(b: Boss)
	b.fill.Size = UDim2.fromScale(math.clamp(b.hp / b.maxHp, 0, 1), 1)
	b.hpText.Text = math.max(b.hp, 0) .. " / " .. b.maxHp
	workspace:SetAttribute("KingHp", math.max(b.hp, 0))
end

local function groundCFrame(pos: Vector3): CFrame
	return CFrame.new(pos.X, K.size / 2, pos.Z)
end

local function finish(b: Boss, defeated: boolean)
	if not b.alive then
		return
	end
	b.alive = false
	boss = nil
	workspace:SetAttribute("KingUntil", nil)
	workspace:SetAttribute("KingHp", nil)
	workspace:SetAttribute("KingMaxHp", nil)
	local pos = b.body.Position
	if defeated then
		Net.FxAll("kingDefeated", { pos = pos })
		local ranking, total = {}, 0
		for p, n in b.hits do
			total += n
			table.insert(ranking, { player = p, damage = n })
		end
		table.sort(ranking, function(x, y)
			return x.damage > y.damage
		end)
		for rank, r in ranking do
			local p = r.player
			if p.Parent then
				local share = r.damage / math.max(total, 1)
				local text = Rewards.Grant(p, { cashSeconds = math.floor(K.rewardSeconds * (0.5 + share)), cashMin = K.rewardMin })
				Signals.Progress(p, "boss")
				Net.Fx(p, "kingReward", { rank = rank, of = #ranking, damage = r.damage, text = text })
				Net.Notify(p, string.format("👑 King Slime defeated! You were #%d of %d (%d damage): %s", rank, #ranking, r.damage, text), "epic")
			end
		end
		local top = ranking[1] and ranking[1].player
		if top and top.Parent then
			Net.NotifyAll("👑 " .. top.DisplayName .. " was the King Slime's top slapper!", "epic")
			Rewards.Grant(top, { freeRoll = true, rollLuck = K.topRollLuck })
		end
	else
		Net.FxAll("kingEscape", { pos = pos })
		Net.NotifyAll("👑 The King Slime got away! It'll be back...", "bad")
	end
	if defeated then
		task.delay(0.6, function()
			b.model:Destroy()
		end)
	else
		-- Leaps away into the sky.
		task.spawn(function()
			local from = b.model:GetPivot()
			for i = 1, 30 do
				b.model:PivotTo(from + Vector3.new(0, (i / 30) ^ 2 * 150, 0))
				task.wait(1 / 30)
			end
			b.model:Destroy()
		end)
	end
end

-- Gear calls this first: returns true if the swing/zap hit the King instead of a player.
function BossService.TryHit(player: Player, from: Vector3, range: number, damage: number): boolean
	local b = boss
	if not b or not b.alive then
		return false
	end
	local dist = (b.body.Position - from).Magnitude - K.size / 2
	if dist > range then
		return false
	end
	b.hp -= damage
	b.hits[player] = (b.hits[player] or 0) + damage
	updateBar(b)
	Net.FxAll("kingHit", { pos = from:Lerp(b.body.Position, 0.6), damage = damage })
	if b.hp <= 0 then
		finish(b, true)
	end
	return true
end

local function hopTo(b: Boss, target: Vector3, height: number, duration: number)
	local start = b.body.Position
	local t0 = os.clock()
	local done = false
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not b.alive or not b.model.Parent then
			conn:Disconnect()
			done = true
			return
		end
		local a = math.min((os.clock() - t0) / duration, 1)
		local flat = Vector3.new(start.X, 0, start.Z):Lerp(Vector3.new(target.X, 0, target.Z), a)
		local cf = groundCFrame(flat) + Vector3.new(0, math.sin(a * math.pi) * height, 0)
		local look = Vector3.new(target.X - start.X, 0, target.Z - start.Z)
		b.model:PivotTo(if look.Magnitude > 0.1 then CFrame.lookAt(cf.Position, cf.Position + look) else cf)
		if a >= 1 then
			conn:Disconnect()
			done = true
		end
	end)
	while not done do
		task.wait()
	end
end

local function stomp(b: Boss)
	local pos = b.body.Position
	Net.FxAll("stomp", { pos = Vector3.new(pos.X, 0.5, pos.Z), range = K.stompRange })
	for _, p in Players:GetPlayers() do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local offset = (root.Position - pos) * Vector3.new(1, 0, 1)
			if offset.Magnitude < K.stompRange then
				local dir = if offset.Magnitude > 0.1 then offset.Unit else Vector3.new(1, 0, 0)
				Net.Fx(p, "knock", { dir = dir, force = K.stompForce, text = "STOMPED!" })
			end
		end
	end
end

local function randomSpot(): Vector3
	return K.pos + Vector3.new((math.random() * 2 - 1) * K.roamX, 0, (math.random() * 2 - 1) * K.roamZ)
end

local function spawnKing()
	if boss or #Players:GetPlayers() == 0 then
		return
	end
	local land = randomSpot()
	-- Heads-up: a shadow grows where it will land, so players can gather (or run).
	Net.NotifyAll("👑 Something BIG is falling from the sky...", "epic")
	Net.FxAll("kingIncoming", { pos = land, seconds = K.warnSeconds })
	task.wait(K.warnSeconds)

	local b = build()
	boss = b
	b.model:PivotTo(groundCFrame(land) + Vector3.new(0, 120, 0))
	b.model.Parent = workspace
	updateBar(b)
	workspace:SetAttribute("KingUntil", workspace:GetServerTimeNow() + K.lifeSeconds)
	workspace:SetAttribute("KingMaxHp", b.maxHp)
	Net.NotifyAll("👑 THE KING SLIME HAS ARRIVED! Slap it together for big rewards!", "epic")
	Net.FxAll("kingSpawn", { pos = land })
	-- Crash down from the sky.
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local a = math.min((os.clock() - t0) / 1.2, 1)
		if b.model.Parent then
			b.model:PivotTo(groundCFrame(land) + Vector3.new(0, 120 * (1 - a * a), 0))
		end
		if a >= 1 then
			conn:Disconnect()
		end
	end)
	task.wait(1.25)
	stomp(b)
	local ends = os.clock() + K.lifeSeconds
	local hop = 0
	local enraged = false
	while b.alive and os.clock() < ends do
		task.wait(if enraged then K.hopEvery * 0.6 else K.hopEvery)
		if not b.alive then
			break
		end
		if not enraged and b.hp <= b.maxHp * K.enrageAt then
			enraged = true
			b.body.Color = Color3.fromRGB(255, 90, 60)
			b.fill.BackgroundColor3 = Color3.fromRGB(255, 90, 60)
			Net.FxAll("kingEnrage", { pos = b.body.Position })
			Net.NotifyAll("👑 The King Slime is ENRAGED! Finish it off!", "epic")
		end
		hop += 1
		local big = enraged or hop % K.stompEvery == 0
		hopTo(b, randomSpot(), if big then 14 else 5, if big then 1.1 else 0.6)
		if big and b.alive then
			stomp(b)
		end
	end
	finish(b, false)
end

function BossService.Start()
	task.spawn(function()
		task.wait(K.firstDelay)
		while true do
			local ok, err = pcall(spawnKing)
			if not ok then
				warn("[BossService]", err)
				boss = nil
			end
			task.wait(K.everySeconds)
		end
	end)
end

-- Used by AdminService (/admin king) and DebugService. To test in Studio, run
-- game.ServerStorage.Debug:Invoke("king") from the Server command bar: requiring this
-- module there gives a separate copy whose King can't be hit.
function BossService.SpawnNow()
	task.spawn(spawnKing)
end

return BossService
