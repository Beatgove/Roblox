-- Raiding: grab a slime from someone else's base and carry it home.
-- Thieves glow red with a THIEF tag. If the owner catches them (or they drop it),
-- the slime bounces its way back home to its pen.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Util = require(game.ReplicatedStorage.Shared.Util)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local SlimeModel = require(script.Parent.SlimeModel)
local Net = require(script.Parent.Net)
local Signals = require(script.Parent.Signals)
local BountyService = require(script.Parent.BountyService)
local NemesisService = require(script.Parent.NemesisService)
local PhoneAlerts = require(script.Parent.PhoneAlerts)

local StealService = {}

local carrying: { [Player]: boolean } = {}
-- Ends a thief's carry early (slapped, tased): the slime bounces home.
local dropFns: { [Player]: (string?) -> () } = {}
-- Squirm: the token the thief must send back (HoldTight) before the deadline.
local squirms: { [Player]: { token: number, deadline: number } } = {}
local squirmToken = 0
-- Revenge: victim -> { thief, untilT } (os.clock time).
local revenge: { [Player]: { thief: Player, untilT: number } } = {}

local function hasRevenge(player: Player, on: Player): boolean
	local r = revenge[player]
	return r ~= nil and r.thief == on and r.untilT > os.clock()
end

local function setRevenge(victim: Player, thief: Player?)
	if thief then
		revenge[victim] = { thief = thief, untilT = os.clock() + Config.RevengeSeconds }
		victim:SetAttribute("RevengeUserId", thief.UserId)
		victim:SetAttribute("RevengeName", thief.DisplayName)
		victim:SetAttribute("RevengeUntil", workspace:GetServerTimeNow() + Config.RevengeSeconds)
	else
		revenge[victim] = nil
		victim:SetAttribute("RevengeUserId", nil)
		victim:SetAttribute("RevengeName", nil)
		victim:SetAttribute("RevengeUntil", nil)
	end
end

function StealService.IsCarrying(player: Player): boolean
	return carrying[player] == true
end

function StealService.Drop(player: Player, reason: string?)
	local fn = dropFns[player]
	if fn then
		fn(reason)
	end
end

local HOP_DISTANCE = 7
local HOP_TIME = 0.38
local HOP_HEIGHT = 4

local function attachToHead(char: Model, slime, stage: number): Model?
	local head = char:FindFirstChild("Head") :: BasePart?
	if not head then
		return nil
	end
	local model = SlimeModel.Create(slime.id, stage, slime.mut, slime.stars, slime.traits, slime.diet)
	local body = model.PrimaryPart
	local size = body.Size.Y
	model:PivotTo(head.CFrame * CFrame.new(0, head.Size.Y / 2 + size / 2 + 0.3, 0))
	body.Anchored = false
	body.Massless = true
	local w = Instance.new("WeldConstraint")
	w.Part0 = head
	w.Part1 = body
	w.Parent = body
	model.Name = "CarriedSlime"
	model.Parent = char
	return model
end

local function markThief(char: Model): { Instance }
	local marks = {}
	local h = Instance.new("Highlight")
	h.Name = "ThiefGlow"
	h.FillColor = Color3.fromRGB(255, 40, 60)
	h.FillTransparency = 0.6
	h.OutlineColor = Color3.fromRGB(255, 255, 255)
	h.Parent = char
	table.insert(marks, h)
	local head = char:FindFirstChild("Head")
	if head then
		local gui = Instance.new("BillboardGui")
		gui.Name = "ThiefTag"
		gui.Size = UDim2.fromOffset(160, 40)
		gui.StudsOffset = Vector3.new(0, 7, 0)
		gui.AlwaysOnTop = true
		gui.MaxDistance = 200
		gui.Parent = head
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.Text = "🚨 THIEF! 🚨"
		t.TextColor3 = Color3.fromRGB(255, 60, 70)
		t.TextStrokeTransparency = 0
		t.Parent = gui
		table.insert(marks, gui)
	end
	return marks
end

-- Animates a slime hopping from `fromPos` back to the owner's next free pen, then puts it there.
-- Slimes hopping home are in nobody's save until they land. If their owner leaves first,
-- StealService.ReturnBouncing puts them straight back into the owner's data before it saves.
local bouncing: { [Player]: { [any]: boolean } } = {}
-- Slimes being carried off right now, by owner: calling the function ends that carry and
-- hands the slime back, so it can be saved with its owner if they (or the server) leave.
local carriedFrom: { [Player]: { [Player]: () -> any } } = {}

function StealService.ReturnBouncing(owner: Player)
	local list = bouncing[owner] or {}
	bouncing[owner] = nil
	local carries = carriedFrom[owner]
	if carries then
		for _, takeBack in carries do
			local slime = takeBack()
			if slime then
				list[slime] = true
			end
		end
	end
	carriedFrom[owner] = nil
	local data = DataService.Get(owner)
	if not data then
		return
	end
	for slime in list do
		if #data.slimes < PlotService.Slots(owner) then
			table.insert(data.slimes, slime)
		else
			data.cash += PlotService.SellValue(slime)
		end
	end
end

local function bounceHome(slime, fromPos: Vector3, owner: Player, fallback: Player?)
	bouncing[owner] = bouncing[owner] or {}
	bouncing[owner][slime] = true
	-- Hands the slime over once; false if the owner left and it already went back to their save.
	local function land(): boolean
		local list = bouncing[owner]
		if not list or not list[slime] then
			return false
		end
		list[slime] = nil
		return true
	end
	local target = PlotService.NextPenPosition(owner)
	if not target then
		PlotService.Transit(owner, -1)
		if not land() then
			return
		end
		if owner.Parent and PlotService.GetPlot(owner) then
			PlotService.AddOrPay(owner, slime)
		elseif fallback and fallback.Parent then
			PlotService.AddOrPay(fallback, slime)
		end
		return
	end
	local stage = Util.Stage(os.time() - slime.born)
	local model = SlimeModel.Create(slime.id, stage, slime.mut, slime.stars, slime.traits, slime.diet)
	local r = model.PrimaryPart.Size.Y / 2
	model.PrimaryPart.Label.Info.Text = "Bouncing home!"
	local ground = Vector3.new(0, r + 0.5, 0)
	local start = Vector3.new(fromPos.X, 0, fromPos.Z) + ground
	local finish = Vector3.new(target.X, 0, target.Z) + ground + Vector3.new(0, 0.3, 0)
	local flat = Vector3.new(finish.X - start.X, 0, finish.Z - start.Z)
	local hops = math.max(3, math.ceil(flat.Magnitude / HOP_DISTANCE))
	local facing = if flat.Magnitude > 0.1 then CFrame.lookAt(Vector3.zero, flat.Unit) else CFrame.identity
	model:PivotTo(CFrame.new(start) * facing)
	model.Parent = workspace

	local t0 = os.clock()
	local total = hops * HOP_TIME
	local lastHop = 0
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local elapsed = os.clock() - t0
		local alpha = math.min(elapsed / total, 1)
		local hopIndex = math.floor(elapsed / HOP_TIME)
		local hopAlpha = (elapsed % HOP_TIME) / HOP_TIME
		local height = math.sin(hopAlpha * math.pi) * HOP_HEIGHT
		model:PivotTo(CFrame.new(start:Lerp(finish, alpha) + Vector3.new(0, height, 0)) * facing)
		if hopIndex > lastHop then
			lastHop = hopIndex
			Net.FxAll("hop", { pos = model.PrimaryPart.Position - Vector3.new(0, r, 0) })
		end
		if alpha >= 1 then
			conn:Disconnect()
			model:Destroy()
			PlotService.Transit(owner, -1)
			if not land() then
				return
			end
			if owner.Parent and PlotService.GetPlot(owner) then
				if PlotService.AddOrPay(owner, slime) then
					Net.Notify(owner, "Your " .. Config.DisplayName(slime.id, slime.mut, slime.stars, slime.traits, slime.diet) .. " bounced back home!", "good")
				end
			elseif fallback and fallback.Parent then
				PlotService.AddOrPay(fallback, slime)
			end
		end
	end)
end

local function startSteal(thief: Player, victim: Player, slot: number)
	if carrying[thief] then
		Net.Notify(thief, "You're already carrying a slime!", "bad")
		return
	end
	local victimPlot = PlotService.GetPlot(victim)
	local thiefPlot = PlotService.GetPlot(thief)
	if not victimPlot or not thiefPlot then
		return
	end
	local isRevenge = hasRevenge(thief, victim)
	if not isRevenge and PlotService.IsRookie(victim) then
		Net.Notify(thief, "🐣 " .. victim.DisplayName .. " is new here. Their Rookie Shield protects them for now!", "bad")
		Net.Fx(thief, "deny", {})
		return
	end
	if PlotService.IsLocked(victimPlot) and not isRevenge then
		Net.Notify(thief, "That base is shielded!", "bad")
		Net.Fx(thief, "deny", {})
		return
	end
	if not PlotService.HasFreeSlot(thief) then
		Net.Notify(thief, "Your pens are full, you have nowhere to put it!", "bad")
		Net.Fx(thief, "deny", {})
		return
	end
	local char = thief.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not char or not humanoid or humanoid.Health <= 0 or not root then
		return
	end

	local slime = PlotService.RemoveSlime(victim, slot)
	if not slime then
		return
	end
	carrying[thief] = true
	PlotService.Transit(victim, 1)
	local name = Config.DisplayName(slime.id, slime.mut, slime.stars, slime.traits, slime.diet)

	local stage = Util.Stage(os.time() - slime.born)
	local carried = attachToHead(char, slime, stage)
	local marks = markThief(char)
	-- Gear (Speed Coil) keeps a little of its boost while carrying.
	-- Revenge steals run at full speed.
	humanoid.WalkSpeed = if isRevenge then (humanoid:GetAttribute("BaseSpeed") or 16) else Config.CarryWalkSpeed + (humanoid:GetAttribute("CarryBonus") or 0)
	thief:SetAttribute("Carrying", name)
	thief:SetAttribute("StealingFrom", victim.UserId) -- victim's HUD tracks them; their base siren goes off
	thief:SetAttribute("RevengeCarry", isRevenge)
	-- Stealing ends your own Rookie Shield.
	local thiefData = DataService.Get(thief)
	if thiefData and PlotService.IsRookie(thief) then
		thiefData.rookieOff = true
		PlotService.Sync(thief)
		Net.Notify(thief, "🐣 You stole, so your Rookie Shield is gone. Fair's fair!", "info")
	end
	local rarityOrder = Config.RarityByName[Config.SlimeById[slime.id].rarity].order
	local victimData = DataService.Get(victim)
	local slippery = Config.HasRelic(victimData, "SlipperySlimes")
	if not isRevenge and Config.HasRelic(victimData, "StickyFloor") then
		humanoid.WalkSpeed *= 0.8
		thief:SetAttribute("CarrySlow", 0.8)
		Net.Notify(thief, "🍯 Sticky Floor! This base slows thieves down.", "bad")
	end

	Net.Notify(thief, "You grabbed " .. name .. "! Run back to your base!", "epic")
	Net.Notify(victim, "🚨 " .. thief.DisplayName .. " is stealing your " .. name .. "! Catch them!", "bad")
	Net.Fx(victim, "alarm", { thief = thief.DisplayName, slime = name })
	Net.Fx(thief, "grab", {})

	local finished = false
	local died = false
	local diedConn = humanoid.Died:Connect(function()
		died = true
	end)

	local function finish(outcome: string)
		if finished then
			return
		end
		finished = true
		diedConn:Disconnect()
		if carriedFrom[victim] then
			carriedFrom[victim][thief] = nil
		end
		carrying[thief] = nil
		dropFns[thief] = nil
		squirms[thief] = nil
		if thief.Parent then
			thief:SetAttribute("Carrying", nil)
			thief:SetAttribute("StealingFrom", nil)
			thief:SetAttribute("RevengeCarry", nil)
			thief:SetAttribute("CarrySlow", nil)
		end
		local dropPos = if carried and carried.PrimaryPart then carried.PrimaryPart.Position else root.Position
		if carried then
			carried:Destroy()
		end
		for _, m in marks do
			m:Destroy()
		end
		if humanoid.Parent then
			humanoid.WalkSpeed = humanoid:GetAttribute("BaseSpeed") or 16
		end

		if outcome == "returned" then
			-- The owner is leaving: ReturnBouncing saves the slime with them.
			if thief.Parent then
				Net.Notify(thief, victim.DisplayName .. " left, so the slime went home with them.", "bad")
			end
		elseif outcome == "success" and not PlotService.AddSlime(thief, slime) then
			-- The thief's pens filled during the run: the slime goes back to its owner.
			Net.Notify(thief, "Your pens are full! The slime hopped back home.", "bad")
			if victim.Parent and PlotService.GetPlot(victim) then
				bounceHome(slime, dropPos, victim, thief)
			else
				PlotService.Transit(victim, -1)
				PlotService.AddOrPay(thief, slime)
			end
		elseif outcome == "success" then
			PlotService.Transit(victim, -1)
			local data = DataService.Get(thief)
			if data then
				data.steals += 1
			end
			Signals.Progress(thief, "steal")
			Net.Notify(thief, "STOLEN! " .. name .. " is yours now.", "epic")
			Net.Fx(thief, "stealWin", {})
			if isRevenge then
				setRevenge(thief, nil)
				Net.NotifyAll("😤 " .. thief.DisplayName .. " got REVENGE on " .. victim.DisplayName .. "!", "epic")
			else
				BountyService.Add(thief, PlotService.SellValue(slime) * Config.BountyShare)
			end
			if victim.Parent then
				NemesisService.Record(victim, thief)
				if Config.HasRelic(DataService.Get(victim), "Insurance") then
					local payout = math.floor(PlotService.SellValue(slime) * 0.25)
					PlotService.AddCash(victim, payout, "StealPayout")
					Net.Notify(victim, "📄 Insurance paid you " .. Util.Money(payout) .. " for the stolen slime.", "good")
				end
				Net.Notify(victim, thief.DisplayName .. " stole your " .. name .. (if isRevenge then " back!" else ". REVENGE: their shield can't stop you for " .. Util.Duration(Config.RevengeSeconds) .. "!"), "bad")
				Net.Fx(victim, "stolen", {})
				PhoneAlerts.Stolen(victim, thief, slime.id)
				if not isRevenge then
					setRevenge(victim, thief)
					Net.Fx(victim, "revenge", { name = thief.DisplayName })
					Net.Notify(thief, "😤 " .. victim.DisplayName .. " wants REVENGE! Your shield won't stop them for " .. Util.Duration(Config.RevengeSeconds) .. ".", "bad")
				end
			end
		elseif victim.Parent and PlotService.GetPlot(victim) then
			if thief.Parent then
				local reason = if outcome == "tagged"
					then "CAUGHT! The owner took it back!"
					elseif outcome == "slapped" then "SLAPPED! You dropped the slime!"
					elseif outcome == "squirmed" then "It SQUIRMED out of your hands!"
					elseif outcome == "gloom" then "👻 The Gloom scared the slime right out of your hands!"
					else "You dropped the slime!"
				Net.Notify(thief, reason, "bad")
				Net.Fx(thief, "caught", {})
			end
			if outcome == "tagged" then
				Net.Notify(victim, "You caught " .. thief.DisplayName .. "!", "good")
				Net.Fx(victim, "stealWin", {})
			end
			bounceHome(slime, dropPos, victim, nil)
		else
			-- Owner left mid-raid: the thief keeps it.
			PlotService.Transit(victim, -1)
			if thief.Parent then
				PlotService.AddOrPay(thief, slime)
			end
		end
	end

	dropFns[thief] = function(reason: string?)
		finish(reason or "slapped")
	end
	carriedFrom[victim] = carriedFrom[victim] or {}
	carriedFrom[victim][thief] = function()
		if finished then
			return nil
		end
		finish("returned")
		return slime
	end

	local started = os.clock()
	local nextSquirm = started + Config.SquirmEverySeconds
	-- Speed check samples: WalkSpeed is set here but the client controls its own character,
	-- so this is the only thing stopping a speed hack or teleport home with a slime.
	local function flat(v: Vector3): Vector3
		return Vector3.new(v.X, 0, v.Z)
	end
	local lastPos, lastAt = flat(root.Position), os.clock()
	local windowPos, windowAt = lastPos, lastAt
	local strikes = 0
	task.spawn(function()
		while not finished do
			task.wait(0.2)
			if not thief.Parent or died or not root.Parent then
				finish("dropped")
				break
			end
			-- Speed check, every tick: distance this tick and over the current window (up to 1s)
			-- against what their WalkSpeed allows. One slip is forgiven (a phone's lag spike);
			-- two in a row, or one huge jump, is a hack and the slime drops home. A tick with a
			-- slip can't count as reaching home. Knockback and server moves get grace (Net).
			local at, pos = os.clock(), flat(root.Position)
			local allowed = math.max(humanoid.WalkSpeed, 16) * Config.CarrySpeedSlack
			local tick = (pos - lastPos).Magnitude
			local slipped = false
			local grace = Net.MoveGrace(thief)
			if grace then
				-- Moved by the server or knocked back: fast is fine, but only near where that
				-- move put them. Never counts as reaching home during the window.
				if (pos - flat(grace.origin)).Magnitude > grace.radius + allowed * (at - grace.at) then
					strikes = 2
				else
					windowPos, windowAt, strikes = pos, at, 0
					slipped = true
				end
			elseif tick > Config.CarryTeleportStuds then
				strikes = 2
			else
				slipped = tick > math.max(12, allowed * (at - lastAt) * 2)
					or (pos - windowPos).Magnitude > allowed * (at - windowAt) + 8
				strikes = if slipped then strikes + 1 else 0
			end
			if strikes >= 2 then
				warn(string.format("[StealService] %s moved too fast while carrying (%.0f studs/s allowed); dropped", thief.Name, allowed))
				finish("dropped")
				break
			end
			if not slipped and at - windowAt >= 1 then
				windowPos, windowAt = pos, at
			end
			lastPos, lastAt = pos, at
			if strikes > 0 or grace then
				continue
			end
			if PlotService.InPlot(thiefPlot, root.Position) then
				finish("success")
				break
			end
			-- Slippery slimes: answer the squirm in time or it wriggles free.
			local sq = squirms[thief]
			if sq and os.clock() > sq.deadline then
				finish("squirmed")
				break
			end
			if not sq and os.clock() >= nextSquirm then
				nextSquirm = os.clock() + Config.SquirmEverySeconds
				if math.random() < Config.SquirmChance(rarityOrder) * (if slippery then 2 else 1) then
					squirmToken += 1
					squirms[thief] = { token = squirmToken, deadline = os.clock() + Config.SquirmWindow + 0.3 }
					Net.Fx(thief, "squirm", { token = squirmToken, window = Config.SquirmWindow })
					Net.FxAll("squirmAll", { pos = root.Position + Vector3.new(0, 4, 0) })
				end
			end
			if os.clock() - started > Config.CarryTimeoutSeconds then
				finish("timeout")
				break
			end
			local vChar = victim.Parent and victim.Character
			local vRoot = vChar and vChar:FindFirstChild("HumanoidRootPart") :: BasePart?
			if os.clock() - started > 1 and vRoot and (vRoot.Position - root.Position).Magnitude <= Config.OwnerTagDistance then
				finish("tagged")
				break
			end
		end
	end)
end

function StealService.Start()
	PlotService.StealRequested.Event:Connect(startSteal)
	Net.On(Net.HoldTightEvent, function(player, token)
		local sq = squirms[player]
		if sq and token == sq.token then
			squirms[player] = nil
			Net.Fx(player, "held", {})
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		carrying[p] = nil
		dropFns[p] = nil
		squirms[p] = nil
		revenge[p] = nil -- (carriedFrom[p] is cleared by ReturnBouncing, which Main calls on leave)
		for victim, r in revenge do
			if r.thief == p then
				setRevenge(victim, nil)
			end
		end
	end)
end

return StealService
