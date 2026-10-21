-- Holidays (Config.Holidays): special events on the calendar. Every server works out from
-- the UTC date which holiday is on and sets workspace "Holiday" / "HolidayUntil". While one
-- is on, Roller adds its slimes and traits, EventService mixes in its own event, the clients
-- change the sky and the music, and this dresses up the map. Halloween also puts a candy
-- bowl at every base door: knock on another player's base for a trick or a treat.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Net = require(script.Parent.Net)
local Rewards = require(script.Parent.Rewards)
local MapBuilder = require(script.Parent.MapBuilder)
local PlotService = require(script.Parent.PlotService)
local Passes = require(script.Parent.Passes)
local DataService = require(script.Parent.DataService)

local HolidayService = {}

local current: string? = nil
local forced: string? = nil -- set from the Studio debug hook ("off" = none)
local decor: Folder? = nil
local knocked: { [Player]: { [Model]: number } } = {}

-- Unix time (UTC) of a { month, day } date in a given year.
local function utc(year: number, d): number
	local localGuess = os.time({ year = year, month = d.month, day = d.day, hour = 0 })
	local offset = os.time(os.date("!*t", localGuess) :: any) - localGuess
	return localGuess - offset
end

-- The holiday on right now and when it ends.
local function onNow(): (string?, number)
	if forced then
		if forced == "off" then
			return nil, 0
		end
		return forced, os.time() + 3 * 86400
	end
	local t = os.time()
	local year = (os.date("!*t", t) :: any).year
	for key, h in Config.Holidays do
		for _, y in { year - 1, year } do
			local from = utc(y, h.from)
			local to = utc(if h.to.month < h.from.month then y + 1 else y, h.to)
			if t >= from and t < to then
				return key, to
			end
		end
	end
	return nil, 0
end

local function part(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = decor
	return p
end

-- ===== Halloween decorations =====

-- A jack-o'-lantern sitting on the ground, its face looking along `look`.
local function pumpkin(pos: Vector3, look: Vector3, size: number)
	local cf = CFrame.lookAt(pos + Vector3.new(0, size * 0.42, 0), pos + Vector3.new(0, size * 0.42, 0) + look)
	local body = part({ Name = "Pumpkin", Shape = Enum.PartType.Ball, Size = Vector3.one * size, CFrame = cf, Color = Color3.fromRGB(255, 125, 20), Material = Enum.Material.SmoothPlastic })
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(1.15, 0.85, 1.15)
	mesh.Parent = body
	part({ Name = "PumpkinStem", Size = Vector3.new(size * 0.12, size * 0.25, size * 0.12), CFrame = cf * CFrame.new(0, size * 0.45, 0) * CFrame.Angles(0, 0, 0.2), Color = Color3.fromRGB(90, 140, 50), Material = Enum.Material.Wood, CanCollide = false })
	local glow = Color3.fromRGB(255, 220, 90)
	for _, s in { -1, 1 } do
		part({ Name = "PumpkinEye", Size = Vector3.new(size * 0.16, size * 0.14, size * 0.05), CFrame = cf * CFrame.new(s * size * 0.2, size * 0.08, -size * 0.55) * CFrame.Angles(0, 0, s * 0.6), Color = glow, Material = Enum.Material.Neon, CanCollide = false })
	end
	for k = -2, 2 do
		part({ Name = "PumpkinGrin", Size = Vector3.new(size * 0.1, size * (if k % 2 == 0 then 0.1 else 0.16), size * 0.05), CFrame = cf * CFrame.new(k * size * 0.1, -size * 0.13 + math.abs(k) * size * 0.03, -size * 0.55), Color = glow, Material = Enum.Material.Neon, CanCollide = false })
	end
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 50)
	light.Range = size * 3.5
	light.Brightness = 1.5
	light.Shadows = false
	light.Parent = body
	return body
end

local function gravestone(pos: Vector3, yaw: number)
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, math.rad(math.random(-8, 8)))
	local stone = Color3.fromRGB(140, 140, 155)
	part({ Name = "Grave", Size = Vector3.new(3, 3.6, 0.8), CFrame = cf * CFrame.new(0, 1.8, 0), Color = stone, Material = Enum.Material.Slate })
	part({ Name = "GraveTop", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 3, 3), CFrame = cf * CFrame.new(0, 3.6, 0) * CFrame.Angles(0, math.pi / 2, 0), Color = stone, Material = Enum.Material.Slate })
	local face = part({ Name = "GraveText", Size = Vector3.new(2.4, 1.2, 0.05), CFrame = cf * CFrame.new(0, 2.6, -0.43), Transparency = 1, CanCollide = false })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = face
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(60, 60, 70)
	t.Text = "RIP"
	t.Parent = gui
	part({ Name = "GraveDirt", Size = Vector3.new(3.4, 0.3, 4), CFrame = cf * CFrame.new(0, 0.15, -2.2), Color = Color3.fromRGB(90, 65, 45), Material = Enum.Material.Ground, CanCollide = false })
end

-- A floating cartoon ghost; the client's "Float" tag makes it bob.
local function ghost(pos: Vector3)
	local body = part({ Name = "Ghost", Shape = Enum.PartType.Ball, Size = Vector3.new(4, 5, 4), Position = pos, Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, Transparency = 0.35, CanCollide = false, CanQuery = false, CastShadow = false })
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = body
	for _, s in { -1, 1 } do
		local eye = part({ Name = "GhostEye", Shape = Enum.PartType.Ball, Size = Vector3.new(0.6, 0.9, 0.3), Position = pos + Vector3.new(s * 0.7, 0.6, -1.8), Color = Color3.fromRGB(20, 20, 30), CanCollide = false, CanQuery = false })
		local w = Instance.new("WeldConstraint")
		w.Part0 = body
		w.Part1 = eye
		w.Parent = body
		eye.Anchored = false
	end
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(200, 220, 255)
	light.Range = 12
	light.Brightness = 1
	light.Parent = body
	CollectionService:AddTag(body, "Float")
end

-- Swaps a set of map parts to holiday colours (and back, from their saved colour).
local function recolor(names: { [string]: boolean }, colors: { Color3 }?)
	local map = workspace:FindFirstChild("Map")
	local folder = map and map:FindFirstChild("Decor")
	if not folder then
		return
	end
	local i = 0
	for _, p in folder:GetChildren() do
		if p:IsA("BasePart") and names[p.Name] then
			if p:GetAttribute("BaseColor") == nil then
				p:SetAttribute("BaseColor", p.Color)
			end
			i += 1
			local c = if colors then colors[i % #colors + 1] else p:GetAttribute("BaseColor")
			p.Color = c
			local light = p:FindFirstChildOfClass("PointLight")
			if light then
				light.Color = c
			end
		end
	end
end

-- Candy bowls at every base door for trick-or-treat.
local function candyBowls()
	local tt = Config.Holidays.Halloween.trickOrTreat
	local odds = {}
	local total = 0
	for _, o in tt.outcomes do
		total += o.weight
	end
	for _, o in tt.outcomes do
		table.insert(odds, o.label .. " " .. math.floor(o.weight / total * 100 + 0.5) .. "%")
	end
	for _, plot in PlotService.AllPlots() do
		local door = plot.model:FindFirstChild("Door") :: BasePart?
		if not door then
			continue
		end
		-- Just outside the door, to the side of the path (door local -Z is outside).
		local base = CFrame.new(door.Position.X, 0, door.Position.Z) * door.CFrame.Rotation
		local stand = part({ Name = "CandyStand", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 1.6, 1.6), CFrame = base * CFrame.new(15, 1.5, -3) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(60, 35, 80), Material = Enum.Material.Wood })
		local bowl = pumpkin((base * CFrame.new(15, 2.3, -3)).Position, base.LookVector, 2.6)
		bowl.Name = "CandyBowl"
		for k = 1, 5 do
			part({ Name = "Candy", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.5, Position = bowl.Position + Vector3.new(math.cos(k) * 0.6, 1.1, math.sin(k) * 0.6),
				Color = ({ Color3.fromRGB(255, 80, 150), Color3.fromRGB(120, 220, 255), Color3.fromRGB(255, 230, 80), Color3.fromRGB(140, 255, 120), Color3.fromRGB(200, 120, 255) })[k], Material = Enum.Material.Neon, CanCollide = false })
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "TrickOrTreat"
		prompt.ActionText = "Trick or Treat!"
		prompt.ObjectText = table.concat(odds, " · ")
		prompt.HoldDuration = 0.4
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = stand
		prompt.Triggered:Connect(function(player)
			HolidayService.Knock(player, plot)
		end)
	end
end

local function halloween()
	-- Jack-o'-lanterns along both picket fences, facing the street, clear of the base paths.
	for _, side in { 1, -1 } do
		for x = -192, 192, 24 do
			local clear = math.abs(x) > 12
			for _, px in MapBuilder.PlotXs do
				clear = clear and math.abs(x - px) > 12
			end
			if clear then
				pumpkin(Vector3.new(x, 0, side * 17.5), Vector3.new(0, 0, -side), 2.4)
			end
		end
	end
	-- Two giant pumpkins by the spawn.
	for _, x in { -22, 22 } do
		pumpkin(Vector3.new(x, 0, -40), Vector3.new(-x, 0, 20).Unit, 9)
	end
	-- Little graveyards in the gardens between the bases.
	for _, side in { 1, -1 } do
		for i = 1, #MapBuilder.PlotXs - 1 do
			local x = (MapBuilder.PlotXs[i] + MapBuilder.PlotXs[i + 1]) / 2
			for _, k in { -1, 1 } do
				gravestone(Vector3.new(x + k * 8, 0, side * (MapBuilder.PlotZ - 12)), if side == 1 then 0 else math.pi)
			end
		end
	end
	-- Ghosts floating over the street.
	for _, x in { -165, -110, -55, 55, 110, 165 } do
		ghost(Vector3.new(x, 17, if x % 2 == 0 then 6 else -6))
	end
	-- Orange and purple street lights and bunting.
	recolor({ Bulb = true }, { Color3.fromRGB(255, 85, 0), Color3.fromRGB(120, 40, 255) })
	recolor({ BuntingFlag = true }, { Color3.fromRGB(255, 130, 30), Color3.fromRGB(40, 30, 50), Color3.fromRGB(150, 80, 220) })
	candyBowls()
end

local DECORATE = { Halloween = halloween }

local function undecorate()
	if decor then
		decor:Destroy()
		decor = nil
	end
	recolor({ Bulb = true, BuntingFlag = true }, nil)
end

local function setHoliday(key: string?, untilT: number)
	workspace:SetAttribute("HolidayUntil", untilT)
	if key == current then
		return
	end
	current = key
	workspace:SetAttribute("Holiday", key)
	undecorate()
	if key and DECORATE[key] then
		local folder = Instance.new("Folder")
		folder.Name = "HolidayDecor"
		folder.Parent = workspace:FindFirstChild("Map") or workspace
		decor = folder
		DECORATE[key]()
	end
	if key then
		local h = Config.Holidays[key]
		Net.Banner(h.title .. " IS HERE! " .. h.desc, 10, "event")
	end
end

-- A player knocked on another player's base door.
function HolidayService.Knock(player: Player, plot)
	if current ~= "Halloween" then
		return
	end
	local tt = Config.Holidays.Halloween.trickOrTreat
	if plot.owner == nil then
		Net.Notify(player, "Nobody's home! Knock on a base that has an owner.", "info")
		return
	end
	if plot.owner == player then
		Net.Notify(player, "That's your own candy! Go trick-or-treat at the other bases.", "info")
		return
	end
	-- When they last knocked at this owner's door is saved (by owner), so rejoining
	-- doesn't reset the wait.
	local data = DataService.Get(player)
	if not data then
		return
	end
	if type(data.knocks) ~= "table" then
		data.knocks = {}
	end
	for key, t in data.knocks do
		if os.time() - t > tt.cooldown then
			data.knocks[key] = nil -- keep the list short
		end
	end
	local ownerKey = tostring(plot.owner.UserId)
	knocked[player] = knocked[player] or {}
	local last = math.max(knocked[player][plot.model] or 0, data.knocks[ownerKey] or 0)
	-- The Candy Bucket pass halves the wait and doubles every treat.
	local bucket = Passes.Owns(player, "CandyBucket")
	local wait = last + (if bucket then tt.cooldown / 2 else tt.cooldown) - os.time()
	if wait > 0 then
		Net.Notify(player, "You already got candy here. Come back in " .. math.ceil(wait / 60) .. " min, or try another base!", "info")
		return
	end
	knocked[player][plot.model] = os.time()
	data.knocks[ownerKey] = os.time()
	local total = 0
	for _, o in tt.outcomes do
		total += o.weight
	end
	local r = math.random() * total
	local pick = tt.outcomes[#tt.outcomes]
	for _, o in tt.outcomes do
		r -= o.weight
		if r <= 0 then
			pick = o
			break
		end
	end
	local owner = plot.owner
	if pick.trick then
		Net.Fx(player, "boo", {})
		Net.Notify(player, "👻 TRICK! " .. owner.DisplayName .. "'s base had a ghost in the candy bowl!", "info")
	else
		local reward = pick.reward
		if bucket then
			reward = table.clone(reward)
			reward.cashSeconds = reward.cashSeconds and reward.cashSeconds * 2
			reward.cashMin = reward.cashMin and reward.cashMin * 2
			reward.snacks = reward.snacks and reward.snacks * 2
		end
		local got = Rewards.Grant(player, reward) .. (if bucket then " (🍬 x2)" else "")
		Net.Fx(player, "dropGrab", { title = pick.label .. "!", text = got, color = Color3.fromRGB(255, 140, 30), pos = player.Character and player.Character:GetPivot().Position or Vector3.zero, lucky = false })
	end
	Net.Notify(owner, "🍬 " .. player.DisplayName .. " came trick-or-treating at your base!", "info")
end

-- For the Studio debug hook: "off", a holiday key, or nil to follow the calendar again.
function HolidayService.Force(key: string?)
	forced = key
	setHoliday(onNow())
end

function HolidayService.Start()
	setHoliday(onNow())
	task.spawn(function()
		while true do
			task.wait(30)
			setHoliday(onNow())
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		task.delay(8, function()
			local h = current and Config.Holidays[current]
			if h and player.Parent then
				local left = (workspace:GetAttribute("HolidayUntil") or 0) - os.time()
				Net.Notify(player, h.title .. " is on for " .. math.max(1, math.floor(left / 86400)) .. " more days! " .. h.desc, "epic")
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		knocked[player] = nil
	end)
end

return HolidayService
