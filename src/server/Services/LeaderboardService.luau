-- Global leaderboards next to spawn: all-time top earners and top thieves across every server.
-- Being on a board is a big reason players grind (and post screenshots).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Util = require(game.ReplicatedStorage.Shared.Util)
local DataService = require(script.Parent.DataService)

local LeaderboardService = {}

local REFRESH_SECONDS = 120
local ROWS = 10

local BOARDS = {
	{ key = "Earned", title = "💰 TOP EARNERS", field = "totalEarned", money = true, pos = Vector3.new(-15, 0, -25), color = Color3.fromRGB(255, 205, 60) },
	{ key = "Steals", title = "🦹 TOP THIEVES", field = "steals", money = false, pos = Vector3.new(15, 0, -25), color = Color3.fromRGB(255, 90, 110) },
}

local names: { [number]: string } = {}

local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	names[userId] = if ok and name then name else "Player"
	return names[userId]
end

local function buildBoard(def)
	local face = Vector3.new(0, 7, -20)
	local board = Instance.new("Part")
	board.Name = def.key .. "Board"
	board.Anchored = true
	board.Size = Vector3.new(11, 14, 0.6)
	board.CFrame = CFrame.lookAt(def.pos + Vector3.new(0, 8, 0), Vector3.new(face.X, 8, face.Z))
	board.Color = Color3.fromRGB(30, 20, 50)
	board.Material = Enum.Material.SmoothPlastic
	board.Parent = workspace:FindFirstChild("Map") or workspace

	local trim = Instance.new("Part")
	trim.Name = "Trim"
	trim.Anchored = true
	trim.CanCollide = false
	trim.Size = board.Size + Vector3.new(0.6, 0.6, -0.2)
	trim.CFrame = board.CFrame * CFrame.new(0, 0, 0.2)
	trim.Color = def.color
	trim.Material = Enum.Material.Neon
	trim.Parent = board

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = board
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.12, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = def.color
	title.Text = def.title
	title.Parent = gui
	local rows = {}
	for i = 1, ROWS do
		local row = Instance.new("TextLabel")
		row.Position = UDim2.new(0.05, 0, 0.13 + (i - 1) * 0.085, 0)
		row.Size = UDim2.new(0.9, 0, 0.075, 0)
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.GothamBold
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = if i == 1 then Color3.fromRGB(255, 220, 80) elseif i <= 3 then Color3.fromRGB(230, 230, 255) else Color3.fromRGB(190, 180, 220)
		row.Text = if i == 1 then "Loads in the live game..." else ""
		row.Parent = gui
		rows[i] = row
	end
	return rows
end

local function refresh(def, store, rows)
	-- Push everyone online first so the board includes this server.
	for _, p in Players:GetPlayers() do
		local data = DataService.Get(p)
		if data and DataService.CanSave(p) then -- a failed load would post a blank score over their real one
			pcall(function()
				store:SetAsync("u_" .. p.UserId, math.floor(data[def.field] or 0))
			end)
		end
	end
	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, ROWS)
	end)
	if not ok or not pages then
		return
	end
	local entries = pages:GetCurrentPage()
	for i = 1, ROWS do
		local e = entries[i]
		if e then
			local userId = tonumber(string.sub(e.key, 3)) or 0
			local value = if def.money then Util.Money(e.value) else Util.Format(e.value)
			rows[i].Text = string.format("#%d  %s  ·  %s", i, nameOf(userId), value)
		else
			rows[i].Text = ""
		end
	end
end

function LeaderboardService.Start()
	for _, def in BOARDS do
		local rows = buildBoard(def)
		local ok, store = pcall(function()
			return DataStoreService:GetOrderedDataStore("Top_" .. def.key)
		end)
		if ok and store then
			task.spawn(function()
				task.wait(10)
				while true do
					refresh(def, store, rows)
					task.wait(REFRESH_SECONDS)
				end
			end)
		end
	end
end

return LeaderboardService
