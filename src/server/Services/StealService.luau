-- Raiding: grab a slime from someone else's base and carry it home.
-- The owner can take it back by catching the thief, and dying or timing out returns it.

local Players = game:GetService("Players")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Util = require(game.ReplicatedStorage.Shared.Util)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local SlimeModel = require(script.Parent.SlimeModel)
local Net = require(script.Parent.Net)

local StealService = {}

local carrying: { [Player]: boolean } = {}

local function attachToHead(char: Model, slimeId: string, stage: number): Model?
	local head = char:FindFirstChild("Head") :: BasePart?
	if not head then
		return nil
	end
	local model = SlimeModel.Create(slimeId, stage)
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
		return
	end
	if not PlotService.HasFreeSlot(thief) then
		Net.Notify(thief, "Your pens are full, you have nowhere to put it!", "bad")
		return
	end
	local char = thief.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or humanoid.Health <= 0 or not root then
		return
	end

	local slime = PlotService.RemoveSlime(victim, slot)
	if not slime then
		return
	end
	carrying[thief] = true

	local stage = Util.Stage(os.time() - slime.born)
	local carried = attachToHead(char, slime.id, stage)
	local oldSpeed = humanoid.WalkSpeed
	humanoid.WalkSpeed = Config.CarryWalkSpeed
	thief:SetAttribute("Carrying", slime.id)

	Net.Notify(thief, "You grabbed " .. slime.id .. "! Run back to your base!", "epic")
	Net.Notify(victim, thief.DisplayName .. " is stealing your " .. slime.id .. "! Catch them!", "bad")

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
		if thief.Parent then
			thief:SetAttribute("Carrying", nil)
		end
		if carried then
			carried:Destroy()
		end
		if humanoid.Parent then
			humanoid.WalkSpeed = oldSpeed
		end

		if outcome == "success" then
			PlotService.AddSlime(thief, slime)
			local data = DataService.Get(thief)
			if data then
				data.steals += 1
			end
			Net.Notify(thief, "Stolen! " .. slime.id .. " is yours now.", "epic")
			if victim.Parent then
				Net.Notify(victim, thief.DisplayName .. " stole your " .. slime.id .. ". Get revenge!", "bad")
			end
		else
			if victim.Parent and PlotService.GetPlot(victim) then
				PlotService.AddSlime(victim, slime)
				Net.Notify(victim, "Your " .. slime.id .. " came back!", "good")
			elseif thief.Parent then
				-- Owner left mid-raid: the thief keeps it.
				PlotService.AddSlime(thief, slime)
				return
			end
			if thief.Parent then
				local reason = if outcome == "tagged" then "The owner caught you!" else "You dropped the slime!"
				Net.Notify(thief, reason, "bad")
			end
		end
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
			if vRoot and (vRoot.Position - root.Position).Magnitude <= Config.OwnerTagDistance then
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
	end)
end

return StealService
