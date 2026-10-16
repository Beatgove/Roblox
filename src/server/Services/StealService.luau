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

local StealService = {}

local carrying: { [Player]: boolean } = {}
-- Ends a thief's carry early (slapped, tased): the slime bounces home.
local dropFns: { [Player]: () -> () } = {}

function StealService.IsCarrying(player: Player): boolean
	return carrying[player] == true
end

function StealService.Drop(player: Player)
	local fn = dropFns[player]
	if fn then
		fn()
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
	local model = SlimeModel.Create(slime.id, stage, slime.mut, slime.stars)
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
local function bounceHome(slime, fromPos: Vector3, owner: Player, fallback: Player?)
	local target = PlotService.NextPenPosition(owner)
	if not target then
		if fallback and fallback.Parent then
			PlotService.AddSlime(fallback, slime)
		end
		return
	end
	local stage = Util.Stage(os.time() - slime.born)
	local model = SlimeModel.Create(slime.id, stage, slime.mut, slime.stars)
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
			if owner.Parent and PlotService.GetPlot(owner) then
				PlotService.AddSlime(owner, slime)
				Net.Notify(owner, "Your " .. Config.DisplayName(slime.id, slime.mut, slime.stars) .. " bounced back home!", "good")
			elseif fallback and fallback.Parent then
				PlotService.AddSlime(fallback, slime)
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
	if PlotService.IsLocked(victimPlot) then
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
	local name = Config.DisplayName(slime.id, slime.mut, slime.stars)

	local stage = Util.Stage(os.time() - slime.born)
	local carried = attachToHead(char, slime, stage)
	local marks = markThief(char)
	-- Gear (Speed Coil) keeps a little of its boost while carrying.
	humanoid.WalkSpeed = Config.CarryWalkSpeed + (humanoid:GetAttribute("CarryBonus") or 0)
	thief:SetAttribute("Carrying", name)

	Net.Notify(thief, "You grabbed " .. name .. "! Run back to your base!", "epic")
	Net.Notify(victim, "🚨 " .. thief.DisplayName .. " is stealing your " .. name .. "! Catch them!", "bad")
	Net.Fx(victim, "alarm", { thief = thief.DisplayName })
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
		carrying[thief] = nil
		dropFns[thief] = nil
		if thief.Parent then
			thief:SetAttribute("Carrying", nil)
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

		if outcome == "success" then
			PlotService.AddSlime(thief, slime)
			local data = DataService.Get(thief)
			if data then
				data.steals += 1
			end
			Signals.Progress(thief, "steal")
			Net.Notify(thief, "STOLEN! " .. name .. " is yours now.", "epic")
			Net.Fx(thief, "stealWin", {})
			if victim.Parent then
				Net.Notify(victim, thief.DisplayName .. " stole your " .. name .. ". Get revenge!", "bad")
				Net.Fx(victim, "stolen", {})
			end
		elseif victim.Parent and PlotService.GetPlot(victim) then
			if thief.Parent then
				local reason = if outcome == "tagged"
					then "CAUGHT! The owner took it back!"
					elseif outcome == "slapped" then "SLAPPED! You dropped the slime!"
					else "You dropped the slime!"
				Net.Notify(thief, reason, "bad")
				Net.Fx(thief, "caught", {})
			end
			if outcome == "tagged" then
				Net.Notify(victim, "You caught " .. thief.DisplayName .. "!", "good")
				Net.Fx(victim, "stealWin", {})
			end
			bounceHome(slime, dropPos, victim, nil)
		elseif thief.Parent then
			-- Owner left mid-raid: the thief keeps it.
			PlotService.AddSlime(thief, slime)
		end
	end

	dropFns[thief] = function()
		finish("slapped")
	end

	local started = os.clock()
	task.spawn(function()
		while not finished do
			task.wait(0.2)
			if not thief.Parent or died or not root.Parent then
				finish("dropped")
				break
			end
			if os.clock() - started > Config.CarryTimeoutSeconds then
				finish("timeout")
				break
			end
			if PlotService.InPlot(thiefPlot, root.Position) then
				finish("success")
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
	Players.PlayerRemoving:Connect(function(p)
		carrying[p] = nil
		dropFns[p] = nil
	end)
end

return StealService
