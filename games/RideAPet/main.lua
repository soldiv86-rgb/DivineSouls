-- Ride A Pet - Game Module
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local VirtualInputManager = game:GetService("VirtualInputManager")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Load the shared UI library
local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/soldiv86-rgb/DivineSouls/main/core/ui.lua"))()

local GameRemotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Game")

-- Forward-declared so functions defined earlier in the file (like
-- sendWebhook, which calls window:Notify) close over this local instead of
-- silently resolving to a nil global "window" that doesn't exist yet.
local window

-------------------------------------------------
-- SETTINGS
-------------------------------------------------
local SAVE_FILE = "RideAPet_Settings.json"
local Settings = {
	TweenDuration = 8.0,
	MultiStepDelay = 0.8,
	MultiStepSteps = 14,
	AutoRefreshInterval = 3,
	AutoFarmEnabled = false,
	AutoFarmDelay = 4,
	CollectHoldTime = 1,
	GoMethod = "MultiTeleport",
	ReturnMethod = "MultiTeleport",
	AutoPlaceBestPet = false,
	AutoFeed = false,
	DesiredAge = 50,
	AutoHatch = false,
	AutoPlaceEgg = false,
	MinEggKG = 30000,
	SelectedEggs = {},
	AutoBuy = false,
	FoodShopSelected = {},
	TrackShopSelected = {},
	WebhookEnabled = false,
	WebhookURL = "",
	WebhookInterval = 5,
	TrackedBackpackItems = {},
	ESPEnabled = true,
	AutoRefreshEnabled = false,
	EnabledRarities = {
		Ethereal = true, Divine = true, Mythic = true, Legendary = true,
		Epic = true, Rare = true, Common = true
	}
}

local function loadSettings()
	if isfile and readfile and isfile(SAVE_FILE) then
		local ok, data = pcall(function()
			return HttpService:JSONDecode(readfile(SAVE_FILE))
		end)
		if ok and type(data) == "table" then
			for k, v in pairs(data) do
				if Settings[k] ~= nil then Settings[k] = v end
			end
		end
	end
end

local function saveSettings()
	if writefile then
		local ok, encoded = pcall(function()
			return HttpService:JSONEncode(Settings)
		end)
		if ok then pcall(writefile, SAVE_FILE, encoded) end
	end
end
loadSettings()

-------------------------------------------------
-- GAME DATA
-------------------------------------------------
local Rarities = {"Ethereal", "Divine", "Mythic", "Legendary", "Epic", "Rare", "Common"}
local RarityPriority = {
	Ethereal = 7, Divine = 6, Mythic = 5, Legendary = 4,
	Epic = 3, Rare = 2, Common = 1
}
local RarityColors = {
	Ethereal  = Color3.fromRGB(175, 145, 255),
	Divine    = Color3.fromRGB(155, 175,  55),
	Mythic    = Color3.fromRGB(165,  70, 210),
	Legendary = Color3.fromRGB(255, 160,  40),
	Epic      = Color3.fromRGB(130,  85, 210),
	Rare      = Color3.fromRGB( 70, 150, 230),
	Common    = Color3.fromRGB(115,  75,  45),
}
local RarityEggs = {
	Ethereal = { "Cherub Egg" },
	Divine = { "Blackhole Egg", "Galaxy Egg", "Aurora Egg" },
	Mythic = { "Crystal Egg", "Skull Egg", "Dominus Egg", "Flaming Egg", "Sinister Egg", "Soul Egg" },
	Legendary = { "Glass Egg", "Golden Egg" },
	Epic = { "Mushroom Egg", "Flower Egg", "Slime Egg", "Ice Egg" },
	Rare = { "Cracked Egg", "Easter Egg", "Stone Egg", "Leaf Egg" },
	Common = { "Brown Egg", "White Egg" },
}

local FoodShopItems = {"Grass", "Bone", "Magic Apple", "Meat", "Dragonfruit"}
local TrackShopItems = {"Royal Radar", "Magic Radar", "Advanced Radar", "Angelic Radar"}

local currentSearch = ""
local selectedEggs = Settings.SelectedEggs
local enabledRarities = Settings.EnabledRarities
local foodShopSelected = Settings.FoodShopSelected
local trackShopSelected = Settings.TrackShopSelected
local eggButtons = {}
local espObjects = {}
local espEnabled = Settings.ESPEnabled
local autoRefreshEnabled = Settings.AutoRefreshEnabled
local goMethod = Settings.GoMethod
local returnMethod = Settings.ReturnMethod

local autoFarmEnabled = Settings.AutoFarmEnabled
local autoFarmRunning = false
local farmStartTime = 0
local eggsCollected = 0
local lastCollectedRarity = "-"
local currentAction = "Idle"
local currentTarget = "-"

local scriptStartTime = os.clock()

-------------------------------------------------
-- HELPERS
-------------------------------------------------
local function getHRP()
	local character = player.Character
	if not character then return nil end
	return character:FindFirstChild("HumanoidRootPart")
end

local function getOwnedPlot()
	local plots = workspace:FindFirstChild("Plots")
	if not plots then return nil end
	for _, plot in ipairs(plots:GetChildren()) do
		local data = plot:FindFirstChild("Data")
		if data then
			local ownerValue = data:FindFirstChild("Owner")
			if ownerValue and ownerValue:IsA("ObjectValue") then
				local owner = ownerValue.Value
				local isMine = (typeof(owner) == "string" and owner == player.Name)
					or (typeof(owner) == "Instance" and owner == player)
				if isMine then
					return plot
				end
			end
		end
	end
	return nil
end

local function getBase()
	local plot = getOwnedPlot()
	if plot then
		return plot:FindFirstChild("Baseplate")
			or plot:FindFirstChild("Base")
			or plot:FindFirstChildWhichIsA("BasePart")
			or plot:FindFirstChild("Spawn")
			or plot.PrimaryPart
	end

	local fallback = workspace:FindFirstChild("Plots")
		and workspace.Plots:FindFirstChild("Plot")
		and workspace.Plots.Plot:FindFirstChild("Baseplate")
	if not fallback then
		warn("[RideAPet] Could not find a base (dynamic lookup and fallback both failed)")
	end
	return fallback
end

local function teleportTo(target)
	local hrp = getHRP()
	if not hrp or not target then return end
	hrp.CFrame = target:GetPivot() * CFrame.new(0, 5, 0)
end

local function tweenTo(target)
	local hrp = getHRP()
	if not hrp or not target then return end
	TweenService:Create(hrp, TweenInfo.new(Settings.TweenDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = target:GetPivot() * CFrame.new(0, 5, 0)
	}):Play()
	task.wait(Settings.TweenDuration)
end

local function multiTeleportTo(target)
	local hrp = getHRP()
	if not hrp or not target then return end

	local start = hrp.Position
	local goal = (target:GetPivot() * CFrame.new(0, 3, 0)).Position
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { player.Character }

	for i = 1, Settings.MultiStepSteps do
		hrp = getHRP()
		if not hrp then break end
		local pos = start:Lerp(goal, i / Settings.MultiStepSteps)
		local ray = workspace:Raycast(pos + Vector3.new(0, 5, 0), Vector3.new(0, -20, 0), rayParams)
		if ray then
			pos = Vector3.new(pos.X, ray.Position.Y + 3, pos.Z)
		end
		hrp.CFrame = CFrame.new(pos)
		task.wait(Settings.MultiStepDelay)
	end
end

local function goToTarget(target)
	if goMethod == "MultiTeleport" then
		multiTeleportTo(target)
	else
		tweenTo(target)
	end
end

local function returnToBase()
	local base = getBase()
	if not base then return end
	if returnMethod == "MultiTeleport" then
		multiTeleportTo(base)
	else
		tweenTo(base)
	end
end

local function collectEgg(egg)
	local prompt = egg:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		pcall(function()
			prompt:InputHoldBegin()
			task.wait(Settings.CollectHoldTime)
			prompt:InputHoldEnd()
		end)
		return
	end
	pcall(function()
		VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
		task.wait(Settings.CollectHoldTime)
		VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
	end)
end

local function getEggRarity(eggName)
	for rarity, names in pairs(RarityEggs) do
		for _, name in ipairs(names) do
			if name == eggName then return rarity end
		end
	end
	return "Unknown"
end

local function getBestEgg()
	local rendered = workspace:FindFirstChild("RenderedEggs")
	if not rendered then return nil end
	local bestEgg, bestPriority = nil, -1
	for _, egg in ipairs(rendered:GetChildren()) do
		local rarity = getEggRarity(egg.Name)
		if enabledRarities[rarity] then
			local prio = RarityPriority[rarity] or 0
			if prio > bestPriority then
				bestPriority = prio
				bestEgg = egg
			end
		end
	end
	return bestEgg
end

local function getPetKGFromName(name)
	local numStr = name:match("%[([%d,]+) KG%]")
	if not numStr then return nil end
	return tonumber((numStr:gsub(",", "")))
end

local function getUnoccupiedNest()
	local plot = getOwnedPlot()
	local nests = plot and plot:FindFirstChild("Nests")
	if not nests then return nil end
	for _, nest in ipairs(nests:GetChildren()) do
		if nest:GetAttribute("Occupied") ~= true then
			return nest
		end
	end
	return nil
end

local function setAutobuyItem(category, itemName, state)
	GameRemotes:WaitForChild("Autobuy"):FireServer(category, itemName, state)
end

local function getMoneyStats()
	local currencies = playerGui:FindFirstChild("Reusable") and playerGui.Reusable:FindFirstChild("Currencies")
	if not currencies then return "N/A", "N/A" end
	local cash = currencies:FindFirstChild("CashAmount")
	local income = currencies:FindFirstChild("CashIncome")
	return cash and cash.Text or "N/A", income and income.Text or "N/A"
end

local function countBackpackItem(itemName)
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return 0 end
	local count = 0
	for _, tool in ipairs(backpack:GetChildren()) do
		if tool.Name == itemName then count += 1 end
	end
	return count
end

-- Scans the backpack for the highest-KG pet currently held, for the webhook embed.
local function getBiggestPet()
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return "N/A" end
	local bestName, bestKG = nil, -1
	for _, tool in ipairs(backpack:GetChildren()) do
		local kg = getPetKGFromName(tool.Name)
		if kg and kg > bestKG then
			bestKG = kg
			bestName = tool.Name
		end
	end
	return bestName or "N/A"
end

-- Builds a clean comma-separated list of which automations are currently on.
-- Avoids the nil-hole array issue you'd get from table.concat on a sparse table.
local function getActiveAutomations()
	local active = {}
	if autoFarmEnabled then table.insert(active, "Auto Farm") end
	if Settings.AutoFeed then table.insert(active, "Auto Feed") end
	if Settings.AutoHatch then table.insert(active, "Auto Hatch") end
	if Settings.AutoPlaceBestPet then table.insert(active, "Auto Place Pet") end
	if Settings.AutoPlaceEgg then table.insert(active, "Auto Place Egg") end
	if Settings.AutoBuy then table.insert(active, "Auto Buy") end
	if autoRefreshEnabled then table.insert(active, "Auto Refresh") end
	if #active == 0 then return "None" end
	return table.concat(active, ", ")
end

-- Fetches the player's headshot thumbnail for the webhook embed. Returns nil
-- (rather than throwing) if the thumbnail service call fails for any reason.
local function getAvatarThumbnail()
	local ok, url = pcall(function()
		return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
	end)
	if ok then return url end
	return nil
end

-- Returns the actual BasePart holding the egg's ProximityPrompt (and the
-- prompt itself), rather than the egg model as a whole. Large eggs can have
-- their interactive part sitting well away from the model's overall pivot.
local function getEggInteractPart(egg)
	local prompt = egg:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		return prompt.Parent, prompt
	end
	return egg:FindFirstChild("EggBase") or egg.PrimaryPart or egg:FindFirstChildWhichIsA("BasePart"), nil
end

-- goToTarget lands the character at the egg's pivot + 5 studs up, which is
-- fine for small/medium eggs but can leave HUGE eggs' prompts out of range,
-- since the pivot is the geometric center, not necessarily where the prompt
-- part sits. This snaps the character next to the real prompt part using
-- its own MaxActivationDistance, so it self-adjusts to any egg size.
local function ensureInRangeOfEgg(egg)
	local hrp = getHRP()
	if not hrp then return end
	local part, prompt = getEggInteractPart(egg)
	if not part or not part:IsA("BasePart") then return end

	local maxDist = (prompt and prompt.MaxActivationDistance) or 10
	local dist = (hrp.Position - part.Position).Magnitude
	if dist <= maxDist * 0.7 then return end -- already comfortably in range

	local direction = hrp.Position - part.Position
	if direction.Magnitude < 0.1 then
		direction = Vector3.new(0, 0, 1)
	end
	direction = direction.Unit

	local standoff = math.max(maxDist * 0.5, 3)
	local targetPos = part.Position + direction * standoff + Vector3.new(0, part.Size.Y / 2 + 2, 0)
	hrp.CFrame = CFrame.new(targetPos)
	task.wait(0.15)
end

-- Confirms the egg actually landed in the backpack before counting it,
-- instead of assuming the hold-to-collect input succeeded. Watches for the
-- backpack count of that egg name to tick up; falls back to "the egg
-- disappeared from workspace" as a secondary success signal, in case some
-- eggs route into a different reward instead of a same-named backpack tool.
local function collectEggConfirmed(egg)
	local countBefore = countBackpackItem(egg.Name)
	collectEgg(egg)

	for _ = 1, 10 do
		task.wait(0.15)
		if countBackpackItem(egg.Name) > countBefore then
			return true
		end
		if not egg.Parent then
			return true
		end
	end
	return false
end

-------------------------------------------------
-- STATUS PANEL (floating overlay, shown while Auto Farm runs)
-------------------------------------------------
if playerGui:FindFirstChild("RideAPetStatus") then
	playerGui.RideAPetStatus:Destroy()
end

local statusGui = Instance.new("ScreenGui")
statusGui.Name = "RideAPetStatus"
statusGui.ResetOnSpawn = false
statusGui.Parent = playerGui

local statusPanel = Instance.new("Frame")
statusPanel.Size = UDim2.new(0, 290, 0, 0)
statusPanel.AutomaticSize = Enum.AutomaticSize.Y
statusPanel.Position = UDim2.new(1, -310, 0, 20)
statusPanel.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
statusPanel.BorderSizePixel = 0
statusPanel.Visible = false
statusPanel.Parent = statusGui
Instance.new("UICorner", statusPanel).CornerRadius = UDim.new(0, 10)

local statusStroke = Instance.new("UIStroke", statusPanel)
statusStroke.Color = Color3.fromRGB(255, 140, 40)
statusStroke.Thickness = 1.2

local statusPadding = Instance.new("UIPadding", statusPanel)
statusPadding.PaddingTop = UDim.new(0, 12)
statusPadding.PaddingBottom = UDim.new(0, 12)
statusPadding.PaddingLeft = UDim.new(0, 14)
statusPadding.PaddingRight = UDim.new(0, 14)

local statusList = Instance.new("UIListLayout", statusPanel)
statusList.Padding = UDim.new(0, 4)

local function addStatusLabel(text, color, size)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, size or 18)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color or Color3.fromRGB(220, 180, 120)
	label.Font = Enum.Font.Gotham
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.Parent = statusPanel
	return label
end

local titleLabel = addStatusLabel("Ride A Pet • Auto Farm", Color3.fromRGB(255, 160, 50), 20)
titleLabel.Font = Enum.Font.GothamBold
local statusLabel = addStatusLabel("Status: Idle", Color3.fromRGB(180, 180, 180))
local actionLabel = addStatusLabel("Action: -")
local targetLabel = addStatusLabel("Target: -")
local collectedLabel = addStatusLabel("Eggs Collected: 0")
local lastRarityLabel = addStatusLabel("Last Rarity: -")
local uptimeLabel = addStatusLabel("Uptime: 00:00", Color3.fromRGB(180, 180, 180))
local settingsLabel = addStatusLabel("Go: Multi  |  Return: Tween  |  Hold: 0.75s", Color3.fromRGB(160, 140, 100))

local function updateStatusPanel()
	if not autoFarmEnabled then
		statusPanel.Visible = false
		return
	end
	statusPanel.Visible = true
	statusLabel.Text = "Status: Running"
	actionLabel.Text = "Action: " .. currentAction
	targetLabel.Text = "Target: " .. currentTarget
	collectedLabel.Text = "Eggs Collected: " .. eggsCollected
	lastRarityLabel.Text = "Last Rarity: " .. lastCollectedRarity

	local elapsed = math.floor(os.clock() - farmStartTime)
	local mins = math.floor(elapsed / 60)
	local secs = elapsed % 60
	uptimeLabel.Text = string.format("Uptime: %02d:%02d", mins, secs)

	settingsLabel.Text = string.format("Go: %s  |  Return: %s  |  Hold: %.2fs",
		goMethod == "MultiTeleport" and "Multi" or "Tween",
		returnMethod == "MultiTeleport" and "Multi" or "Tween",
		Settings.CollectHoldTime)
end

task.spawn(function()
	while task.wait(0.5) do
		if autoFarmEnabled then
			updateStatusPanel()
		else
			statusPanel.Visible = false
		end
	end
end)

-------------------------------------------------
-- AUTO FARM LOOP
-------------------------------------------------
local function startAutoFarm()
	if autoFarmRunning then return end
	autoFarmRunning = true
	farmStartTime = os.clock()
	eggsCollected = 0
	lastCollectedRarity = "-"
	currentAction = "Starting..."
	currentTarget = "-"

	task.spawn(function()
		while autoFarmEnabled do
			local egg = getBestEgg()
			if egg and egg.Parent then
				local rarity = getEggRarity(egg.Name)
				currentTarget = egg.Name .. " (" .. rarity .. ")"
				currentAction = "Going to egg"
				updateStatusPanel()
				goToTarget(egg)
				task.wait(0.25)
				ensureInRangeOfEgg(egg)
				currentAction = "Holding to collect"
				updateStatusPanel()
				local collected = collectEggConfirmed(egg)
				if collected then
					eggsCollected += 1
					lastCollectedRarity = rarity
				end
				currentAction = "Returning to base"
				updateStatusPanel()
				returnToBase()
				task.wait(Settings.AutoFarmDelay)
			else
				currentAction = "Waiting for eggs..."
				currentTarget = "-"
				updateStatusPanel()
				task.wait(1.5)
			end
		end
		autoFarmRunning = false
		currentAction = "Stopped"
		updateStatusPanel()
	end)
end

-------------------------------------------------
-- AUTO FEED LOOP
-------------------------------------------------
local autoFeedRunning = false
local function startAutoFeed()
	if autoFeedRunning then return end
	autoFeedRunning = true
	task.spawn(function()
		while Settings.AutoFeed do
			local plot = getOwnedPlot()
			local petsFolder = plot and plot:FindFirstChild("Pets")
			if petsFolder then
				for _, pet in ipairs(petsFolder:GetChildren()) do
					local age = pet:GetAttribute("Age")
					local petKey = pet:GetAttribute("PetKey")
					if age and petKey and age < Settings.DesiredAge then
						local backpack = player:FindFirstChild("Backpack")
						if backpack then
							for _, food in ipairs(backpack:GetChildren()) do
								local data = food:FindFirstChild("Data")
								local amount = data and data:FindFirstChild("Amount")
								if amount and amount.Value > 0 then
									GameRemotes:WaitForChild("FeedPet"):FireServer(petKey, food.Name)
									task.wait(0.3)
									break
								end
							end
						end
					end
				end
			end
			task.wait(2)
		end
		autoFeedRunning = false
	end)
end

-------------------------------------------------
-- AUTO HATCH LOOP
-------------------------------------------------
local autoHatchRunning = false
local function startAutoHatch()
	if autoHatchRunning then return end
	autoHatchRunning = true
	task.spawn(function()
		while Settings.AutoHatch do
			local plot = getOwnedPlot()
			local eggsFolder = plot and plot:FindFirstChild("Eggs")
			if eggsFolder then
				for _, egg in ipairs(eggsFolder:GetChildren()) do
					local eggKey = egg:GetAttribute("EggKey")
					if eggKey then
						GameRemotes:WaitForChild("Hatch"):FireServer({EggKey = eggKey})
						task.wait(0.3)
					end
				end
			end
			task.wait(2)
		end
		autoHatchRunning = false
	end)
end

-------------------------------------------------
-- AUTO PLACE BEST PET LOOP
-------------------------------------------------
local function placeBestPet()
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return end

	local bestTool, bestKG = nil, -1
	for _, tool in ipairs(backpack:GetChildren()) do
		local kg = getPetKGFromName(tool.Name)
		if kg and kg > bestKG then
			bestKG = kg
			bestTool = tool
		end
	end
	if not bestTool then return end

	local petKey = bestTool:GetAttribute("PetKey")
	if not petKey then return end

	local nest = getUnoccupiedNest()
	if not nest then return end

	local nestPart = nest:FindFirstChild("Model") or nest:FindFirstChildWhichIsA("BasePart", true)
	if not nestPart then return end

	local pos = nestPart:IsA("Model") and nestPart:GetPivot().Position or nestPart.Position
	GameRemotes:WaitForChild("PlacePet"):FireServer(petKey, pos.X, pos.Y, pos.Z)
end

local autoPlaceBestPetRunning = false
local function startAutoPlaceBestPet()
	if autoPlaceBestPetRunning then return end
	autoPlaceBestPetRunning = true
	task.spawn(function()
		while Settings.AutoPlaceBestPet do
			placeBestPet()
			task.wait(3)
		end
		autoPlaceBestPetRunning = false
	end)
end

-------------------------------------------------
-- WEBHOOK
-------------------------------------------------
-- isTest: when true, shows a UI notification with the send result (success/
-- failure) instead of failing silently, and labels the embed as a test.
local function sendWebhook(isTest)
	if Settings.WebhookURL == "" then
		if isTest then window:Notify("Webhook", "No webhook URL set.", 3) end
		return
	end

	local httpRequest = (syn and syn.request) or (http and http.request) or http_request or request
	if not httpRequest then
		warn("[RideAPet] No HTTP request function available in this executor - webhook can't send.")
		if isTest then window:Notify("Webhook", "No HTTP request function available in this executor.", 4) end
		return
	end

	local elapsed = math.floor(os.clock() - scriptStartTime)
	local hours = math.floor(elapsed / 3600)
	local mins = math.floor((elapsed % 3600) / 60)
	local secs = elapsed % 60
	local uptimeStr = string.format("%02d:%02d:%02d", hours, mins, secs)

	local totalMoney, moneyPerSec = getMoneyStats()

	local trackedLines = {}
	for name, selected in pairs(Settings.TrackedBackpackItems) do
		if selected then
			table.insert(trackedLines, name .. ": " .. countBackpackItem(name))
		end
	end
	local trackedText = #trackedLines > 0 and table.concat(trackedLines, "\n") or "None selected"

	local avatarUrl = getAvatarThumbnail()
	-- Orange while Auto Farm is running, grey when idle, so status is visible
	-- in Discord at a glance without opening the message.
	local embedColor = autoFarmEnabled and 16750632 or 10066329

	local embed = {
		title = isTest and "Ride A Pet - Test Webhook" or "Ride A Pet - Status Update",
		color = embedColor,
		fields = {
			{ name = "Uptime", value = uptimeStr, inline = true },
			{ name = "Total Money", value = tostring(totalMoney), inline = true },
			{ name = "Money / sec", value = tostring(moneyPerSec), inline = true },
			{ name = "Auto Farm", value = autoFarmEnabled and ("Running (" .. eggsCollected .. " eggs collected)") or "Off", inline = true },
			{ name = "Last Egg Rarity", value = lastCollectedRarity, inline = true },
			{ name = "Biggest Pet", value = getBiggestPet(), inline = true },
			{ name = "Active Automations", value = getActiveAutomations(), inline = false },
			{ name = "Tracked Backpack Items", value = trackedText, inline = false },
		},
		author = { name = player.Name },
		footer = { text = "Ride A Pet - Divine Souls Hub" },
		timestamp = DateTime.now():ToIsoDate(),
	}

	if avatarUrl then
		embed.thumbnail = { url = avatarUrl }
	end

	local payload = { embeds = { embed } }

	local ok = pcall(function()
		httpRequest({
			Url = Settings.WebhookURL,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = HttpService:JSONEncode(payload),
		})
	end)

	if isTest then
		window:Notify("Webhook", ok and "Test message sent!" or "Failed to send - check the URL.", 3)
	end
end

-------------------------------------------------
-- ESP (egg size labels)
-------------------------------------------------
local ESPFolder = Instance.new("Folder")
ESPFolder.Name = "RideAPetESP"
if CoreGui:FindFirstChild("RideAPetESP") then
	CoreGui.RideAPetESP:Destroy()
end
ESPFolder.Parent = CoreGui

local function getSizeLabel(egg)
	local s = egg:GetExtentsSize()
	local v = s.X * s.Y * s.Z
	if v > 80 then return "HUGE", Color3.fromRGB(255, 70, 70)
	elseif v > 40 then return "Large", Color3.fromRGB(255, 175, 50)
	elseif v > 18 then return "Medium", Color3.fromRGB(60, 255, 130)
	else return "Small", Color3.fromRGB(170, 170, 180) end
end

local function isEggAllowed(egg)
	return enabledRarities[getEggRarity(egg.Name)] == true
end

local function createESP(egg)
	if not espEnabled or not isEggAllowed(egg) then return end
	local id = tostring(egg:GetDebugId())
	if espObjects[id] then return end
	local part = egg:FindFirstChild("EggBase") or egg.PrimaryPart or egg:FindFirstChildWhichIsA("BasePart")
	if not part then return end

	local bb = Instance.new("BillboardGui")
	bb.Name = id
	bb.Adornee = part
	bb.Size = UDim2.new(0, 130, 0, 40)
	bb.StudsOffset = Vector3.new(0, 4, 0)
	bb.AlwaysOnTop = true
	bb.Parent = ESPFolder

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextStrokeTransparency = 0.3
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.Parent = bb

	local text, color = getSizeLabel(egg)
	label.Text = egg.Name .. "\n" .. text
	label.TextColor3 = color
	espObjects[id] = bb
end

task.spawn(function()
	while task.wait(0.7) do
		if not espEnabled then
			for _, g in pairs(espObjects) do g:Destroy() end
			espObjects = {}
			continue
		end
		local folder = workspace:FindFirstChild("RenderedEggs")
		if not folder then continue end
		local alive = {}
		for _, egg in ipairs(folder:GetChildren()) do
			if isEggAllowed(egg) then
				local id = tostring(egg:GetDebugId())
				alive[id] = true
				createESP(egg)
			end
		end
		for id, gui in pairs(espObjects) do
			if not alive[id] then
				gui:Destroy()
				espObjects[id] = nil
			end
		end
	end
end)

-------------------------------------------------
-- BUILD WINDOW
-------------------------------------------------
window = UI.new("Divine Souls", "Ride A Pet")

local automationTab = window:CreateTab("Automation")
local eggTab = window:CreateTab("Egg")
local otherTab = window:CreateTab("Other")
local settingsTab = window:CreateTab("Settings")

-------------------------------------------------
-- AUTOMATION TAB
-------------------------------------------------
local autoLeft, autoRight = window:CreateColumns(automationTab, 0.48)

local petCard = window:CreateCard(autoLeft, "PETS", true)
window:AddToggle(petCard, "Auto Place Best Pet", Settings.AutoPlaceBestPet, function(s)
	Settings.AutoPlaceBestPet = s
	saveSettings()
	if s then startAutoPlaceBestPet() end
end)
window:AddToggle(petCard, "Auto Feed", Settings.AutoFeed, function(s)
	Settings.AutoFeed = s
	saveSettings()
	if s then startAutoFeed() end
end)
window:AddSlider(petCard, "Feed Until Desired Age", 1, 999, Settings.DesiredAge, function(v)
	Settings.DesiredAge = v
	saveSettings()
end)

local eggCard = window:CreateCard(autoLeft, "EGGS", true)
window:AddToggle(eggCard, "Auto Hatch", Settings.AutoHatch, function(s)
	Settings.AutoHatch = s
	saveSettings()
	if s then startAutoHatch() end
end)
window:AddToggle(eggCard, "Auto Place Egg", Settings.AutoPlaceEgg, function(s)
	Settings.AutoPlaceEgg = s
	saveSettings()
end)
window:AddSlider(eggCard, "Minimum KG", 1000, 100000, Settings.MinEggKG, function(v)
	Settings.MinEggKG = v
	saveSettings()
end)

local allEggNames = {}
local eggNameToRarity = {}
for _, rarity in ipairs(Rarities) do
	for _, eggName in ipairs(RarityEggs[rarity] or {}) do
		table.insert(allEggNames, eggName)
		eggNameToRarity[eggName] = rarity
	end
end

window:AddMultiSelectDropdown(eggCard, "Select Eggs to Place", allEggNames, selectedEggs,
	function(eggName) return RarityColors[eggNameToRarity[eggName]] end,
	function(eggName, state)
		Settings.SelectedEggs = selectedEggs
		saveSettings()
	end)

local buyCard = window:CreateCard(autoRight, "AUTO BUY", true)
window:AddToggle(buyCard, "Enable Auto Buy", Settings.AutoBuy, function(s)
	Settings.AutoBuy = s
	saveSettings()
	for _, item in ipairs(FoodShopItems) do
		setAutobuyItem("Food", item, s and foodShopSelected[item] == true)
	end
	for _, item in ipairs(TrackShopItems) do
		setAutobuyItem("Gears", item, s and trackShopSelected[item] == true)
	end
end)
window:AddMultiSelectDropdown(buyCard, "Food Shop", FoodShopItems, foodShopSelected, nil, function(name, state)
	Settings.FoodShopSelected = foodShopSelected
	saveSettings()
	if Settings.AutoBuy then setAutobuyItem("Food", name, state) end
end)
window:AddMultiSelectDropdown(buyCard, "Track Shop", TrackShopItems, trackShopSelected, nil, function(name, state)
	Settings.TrackShopSelected = trackShopSelected
	saveSettings()
	if Settings.AutoBuy then setAutobuyItem("Gears", name, state) end
end)

-------------------------------------------------
-- EGG TAB
-------------------------------------------------
local eggLeft, eggRight = window:CreateColumns(eggTab, 0.42)

local farmCard = window:CreateCard(eggLeft, "AUTO FARM", true)
window:AddToggle(farmCard, "Auto Farm", Settings.AutoFarmEnabled, function(s)
	autoFarmEnabled = s
	Settings.AutoFarmEnabled = s
	if s then startAutoFarm() end
	saveSettings()
end)
window:AddSlider(farmCard, "Farm Delay (s)", 0.4, 4.0, Settings.AutoFarmDelay, function(v)
	Settings.AutoFarmDelay = v
	saveSettings()
end)
window:AddSlider(farmCard, "Collect Hold Time (s)", 0.3, 2.0, Settings.CollectHoldTime, function(v)
	Settings.CollectHoldTime = v
	saveSettings()
end)
window:AddMethodSelector(farmCard, "Go to Egg", {"Tween", "MultiTeleport"}, Settings.GoMethod, function(v)
	goMethod = v
	Settings.GoMethod = v
	saveSettings()
end)
window:AddMethodSelector(farmCard, "Return to Base", {"Tween", "MultiTeleport"}, Settings.ReturnMethod, function(v)
	returnMethod = v
	Settings.ReturnMethod = v
	saveSettings()
end)

local movementCard = window:CreateCard(eggLeft, "MOVEMENT", true)
window:AddButton(movementCard, "Instant Return to Base", Color3.fromRGB(255, 120, 30), function()
	local base = getBase()
	if base then teleportTo(base) end
end)
window:AddButton(movementCard, "Multi-Teleport to Base", Color3.fromRGB(200, 90, 20), function()
	local base = getBase()
	if base then multiTeleportTo(base) end
end)
window:AddSlider(movementCard, "Multi-Teleport Delay (s)", 0.2, 1.2, Settings.MultiStepDelay, function(v)
	Settings.MultiStepDelay = v
	saveSettings()
end)
window:AddButton(movementCard, "Smooth Tween to Base", Color3.fromRGB(255, 140, 40), function()
	local base = getBase()
	if base then tweenTo(base) end
end)
window:AddSlider(movementCard, "Tween Speed (s)", 2, 12, Settings.TweenDuration, function(v)
	Settings.TweenDuration = v
	saveSettings()
end)

local additionalCard = window:CreateCard(eggLeft, "ADDITIONAL", true)
window:AddToggle(additionalCard, "Auto Refresh", Settings.AutoRefreshEnabled, function(s)
	autoRefreshEnabled = s
	Settings.AutoRefreshEnabled = s
	saveSettings()
end)
window:AddToggle(additionalCard, "Egg ESP", Settings.ESPEnabled, function(s)
	espEnabled = s
	Settings.ESPEnabled = s
	saveSettings()
end)

local eggListCard = window:CreateCard(eggRight, "EGG LIST", true)
window:AddMultiSelectDropdown(eggListCard, "Rarities", Rarities, enabledRarities,
	function(name) return RarityColors[name] end,
	function(name, state)
		Settings.EnabledRarities = enabledRarities
		saveSettings()
		refreshEggs()
	end)

local searchRow = Instance.new("Frame")
searchRow.Size = UDim2.new(1, 0, 0, 36)
searchRow.BackgroundTransparency = 1
searchRow.Parent = eggListCard

local eggSearch = Instance.new("TextBox")
eggSearch.Size = UDim2.new(1, -100, 1, 0)
eggSearch.BackgroundColor3 = Color3.fromRGB(24, 24, 26)
eggSearch.PlaceholderText = "Search eggs..."
eggSearch.Text = ""
eggSearch.TextColor3 = Color3.fromRGB(255, 200, 140)
eggSearch.PlaceholderColor3 = Color3.fromRGB(140, 100, 60)
eggSearch.Font = Enum.Font.Gotham
eggSearch.TextSize = 13
eggSearch.ClearTextOnFocus = false
eggSearch.Parent = searchRow
Instance.new("UICorner", eggSearch).CornerRadius = UDim.new(0, 8)
local eggSearchPad = Instance.new("UIPadding", eggSearch)
eggSearchPad.PaddingLeft = UDim.new(0, 10)

local refreshBtn = Instance.new("TextButton")
refreshBtn.Size = UDim2.new(0, 90, 1, 0)
refreshBtn.Position = UDim2.new(1, -90, 0, 0)
refreshBtn.BackgroundColor3 = Color3.fromRGB(255, 140, 40)
refreshBtn.Text = "Refresh"
refreshBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
refreshBtn.Font = Enum.Font.GothamMedium
refreshBtn.TextSize = 13
refreshBtn.AutoButtonColor = false
refreshBtn.Parent = searchRow
Instance.new("UICorner", refreshBtn).CornerRadius = UDim.new(0, 8)

local eggScroll = Instance.new("ScrollingFrame")
eggScroll.Size = UDim2.new(1, 0, 0, 320)
eggScroll.BackgroundTransparency = 1
eggScroll.BorderSizePixel = 0
eggScroll.ScrollBarThickness = 3
eggScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
eggScroll.Parent = eggListCard
Instance.new("UIListLayout", eggScroll).Padding = UDim.new(0, 6)

function refreshEggs()
	for btn in pairs(eggButtons) do btn:Destroy() end
	eggButtons = {}
	local rendered = workspace:FindFirstChild("RenderedEggs")
	if not rendered then return end

	local allowed = {}
	for rarity, on in pairs(enabledRarities) do
		if on then
			for _, name in ipairs(RarityEggs[rarity] or {}) do
				allowed[name] = rarity
			end
		end
	end

	for _, egg in ipairs(rendered:GetChildren()) do
		local rarity = allowed[egg.Name]
		local matchesSearch = (currentSearch == "" or egg.Name:lower():find(currentSearch:lower(), 1, true))
		if rarity and matchesSearch then
			local color = RarityColors[rarity]
			local btn = window:AddButton(eggScroll, egg.Name, color, function()
				teleportTo(egg)
			end)
			eggButtons[btn] = true
		end
	end
end

eggSearch:GetPropertyChangedSignal("Text"):Connect(function()
	currentSearch = eggSearch.Text
	refreshEggs()
end)
refreshBtn.MouseButton1Click:Connect(function()
	refreshEggs()
end)
refreshEggs()

-------------------------------------------------
-- OTHER TAB
-------------------------------------------------
local serverCard = window:CreateCard(otherTab, "SERVER", true)
window:AddButton(serverCard, "Server Hop Now", Color3.fromRGB(255, 120, 30), function()
	TeleportService:Teleport(game.PlaceId, player)
end)

-------------------------------------------------
-- SETTINGS TAB
-------------------------------------------------
local webhookCard = window:CreateCard(settingsTab, "DISCORD WEBHOOK", true)
window:AddToggle(webhookCard, "Enable Webhook", Settings.WebhookEnabled, function(s)
	Settings.WebhookEnabled = s
	saveSettings()
end)
window:AddTextbox(webhookCard, "Webhook URL", "https://discord.com/api/webhooks/...", Settings.WebhookURL, function(text)
	Settings.WebhookURL = text
	saveSettings()
end)
window:AddSlider(webhookCard, "Send Interval (minutes)", 5, 60, Settings.WebhookInterval, function(v)
	Settings.WebhookInterval = v
	saveSettings()
end)
window:AddButton(webhookCard, "Send Test Webhook", Color3.fromRGB(255, 140, 40), function()
	sendWebhook(true)
end)
window:AddMultiSelectDropdown(webhookCard, "Track Backpack Items", allEggNames, Settings.TrackedBackpackItems, nil, function(name, state)
	saveSettings()
end)

-------------------------------------------------
-- BACKGROUND LOOPS
-------------------------------------------------
task.spawn(function()
	while task.wait(Settings.AutoRefreshInterval) do
		if autoRefreshEnabled then
			refreshEggs()
		end
	end
end)

-- Polls every second instead of one long task.wait(interval * 60), so
-- dragging the "Send Interval" slider takes effect almost immediately
-- instead of only applying after the current wait finishes.
task.spawn(function()
	local lastSent = os.clock()
	while true do
		task.wait(1)
		if Settings.WebhookEnabled and (os.clock() - lastSent) >= (Settings.WebhookInterval * 60) then
			sendWebhook()
			lastSent = os.clock()
		end
	end
end)

if autoFarmEnabled then startAutoFarm() end
if Settings.AutoFeed then startAutoFeed() end
if Settings.AutoHatch then startAutoHatch() end
if Settings.AutoPlaceBestPet then startAutoPlaceBestPet() end

print("Ride A Pet module loaded")
