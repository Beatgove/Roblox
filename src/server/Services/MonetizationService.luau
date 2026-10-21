-- Game passes and developer products. ProcessReceipt is idempotent: each
-- PurchaseId is recorded in the player's save so a retry never grants twice.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Util = require(game.ReplicatedStorage.Shared.Util)
local DataService = require(script.Parent.DataService)
local Passes = require(script.Parent.Passes)
local PlotService = require(script.Parent.PlotService)
local ConveyorService = require(script.Parent.ConveyorService)
local DispenserService = require(script.Parent.DispenserService)
local Net = require(script.Parent.Net)
local EventService = require(script.Parent.EventService)
local StormService = require(script.Parent.StormService)
local Rewards = require(script.Parent.Rewards)

local MonetizationService = {}

local productById: { [number]: any } = {}
for key, product in Config.Products do
	product.key = key
	if product.id ~= 0 then
		productById[product.id] = product
	end
end

local function grantProduct(player: Player, product): boolean
	if product.kind == "Cash" then
		local amount = math.max(product.min, PlotService.IncomePerSecond(player) * product.seconds)
		PlotService.AddCash(player, amount, "RobuxCash")
		Net.Notify(player, "+" .. Util.Money(amount) .. " cash! Thanks for the support!", "epic")
	elseif product.kind == "Luck" then
		DispenserService.GiveLuck(player, product.seconds)
		Net.Notify(player, "🍀 5x LUCK for " .. Util.Duration(product.seconds) .. "! Go roll the Dispenser!", "epic")
	elseif product.kind == "Lock" then
		PlotService.Lock(player, product.seconds, true)
		Net.Notify(player, "Shield up for " .. Util.Duration(product.seconds) .. "!", "epic")
	elseif product.kind == "Grow" then
		PlotService.GrowAll(player)
		Net.Notify(player, "All your slimes grew a stage!", "epic")
	elseif product.kind == "Rain" then
		ConveyorService.StartRain(Config.RainDurationSeconds, player.DisplayName)
	elseif product.kind == "Event" then
		local left = StormService.SecondsLeft()
		if StormService.Active() and left > 0 then
			-- Don't cut the Slime Storm short: the bought event starts right after it.
			local name = player.DisplayName
			task.delay(left + 3, function()
				EventService.Run(product.event, nil, name)
			end)
			Net.Notify(player, "⛈️ Your event starts as soon as the Slime Storm ends (" .. Util.Duration(left) .. "). Thanks for the support!", "epic")
		else
			EventService.Run(product.event, nil, player.DisplayName)
		end
	elseif product.kind == "Pack" then
		local got = Rewards.Grant(player, product.reward)
		Net.Notify(player, product.name .. ": " .. got .. "! Thanks for the support!", "epic")
	else
		return false
	end
	return true
end

local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player or not DataService.Get(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- Studio has no DataStore unless API access is on, so test purchases still go through there.
	local studio = RunService:IsStudio()
	if DataService.HasReceipt(player, receipt.PurchaseId) then
		-- Granted earlier but maybe not saved yet: only confirm once it is.
		if studio or DataService.Save(player) then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- If their data didn't load it would never save: leave the purchase for Roblox to retry
	-- next session rather than take Robux for something that vanishes.
	if not DataService.CanSave(player) and not studio then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local product = productById[receipt.ProductId]
	if not product then
		warn("[Monetization] unknown product", receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok, granted = pcall(grantProduct, player, product)
	if not ok or not granted then
		warn("[Monetization] grant failed", granted)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	DataService.MarkReceipt(player, receipt.PurchaseId)
	-- Only confirm once the grant (and the receipt id) is saved. If the save fails, Roblox
	-- calls again later; the receipt id stops a second grant in this session.
	if not DataService.Save(player) and not studio then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function addVipTag(player: Player, char: Model)
	if not Passes.Owns(player, "VIP") then
		return
	end
	local head = char:WaitForChild("Head", 10)
	if not head or head:FindFirstChild("VipTag") then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "VipTag"
	gui.Size = UDim2.fromOffset(120, 30)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 80
	gui.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = "⭐ VIP"
	label.TextColor3 = Color3.fromRGB(255, 210, 60)
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
end

function MonetizationService.OnPlayer(player: Player)
	player.CharacterAdded:Connect(function(char)
		addVipTag(player, char)
	end)
	if player.Character then
		task.spawn(addVipTag, player, player.Character)
	end
end

function MonetizationService.Start()
	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local key = Passes.KeyForId(passId)
		if not key then
			return
		end
		Passes.Grant(player, key)
		PlotService.Render(player)
		if player.Character then
			addVipTag(player, player.Character)
		end
		Net.Notify(player, "Unlocked " .. Config.GamePasses[key].name .. "! Thank you!", "epic")
	end)
end

return MonetizationService
