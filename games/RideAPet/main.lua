-- Ride A Pet - Game Module
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local VirtualInputManager = game:GetService("VirtualInputManager")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Load the shared UI library
local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/soldiv86-rgb/DivineSouls/main/core/ui.lua"))()

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
	AutoFarmDelay = 1.2,
	CollectHoldTime = 0.75,
	GoMethod = "MultiTeleport",
	ReturnMethod = "Tween",
	AutoPlaceBestPet = false,
	AutoFeed = false,
	DesiredAge = 50,
	AutoHatch = false,
	AutoPlaceEgg = false,
	MinEggKG = 30000,
	SelectedEggs = {},
	AutoBuy = false,
	WebhookEnabled = false,
	WebhookURL = "",
	WebhookInterval = 15,
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

local currentSearch = ""
local selectedEggs = Settings.SelectedEggs or {}
local enabledRarities = Settings.EnabledRarities
local eggButtons = {}
local espObjects = {}
local espEnabled = Settings.ESPEnabled
local autoRefreshEnabled = Settings.AutoRefreshEnabled
local goMethod = Settings.GoMethod
local returnMethod = Settings.ReturnMethod

-- Auto Farm state
local autoFarmEnabled = Settings.AutoFarmEnabled
local autoFarmRunning = false
local farmStartTime = 0
local eggsCollected = 0
local lastCollectedRarity = "-"
local currentAction = "Idle"
local currentTarget = "-"

-------------------------------------------------
-- HELPERS
-------------------------------------------------
local function getHRP()
	local character = player.Character
	if not character then return nil end
	return character:FindFirstChild("HumanoidRootPart")
end

-- Dynamically finds the plot owned by this player, instead of a hardcoded path.
-- Falls back to the fixed path if dynamic lookup doesn't find anything.
local function getBase()
	local plots = workspace:FindFirstChild("Plots")
	if plots then
		for _, plot in ipairs(plots:GetChildren()) do
			local data = plot:FindFirstChild("Data")
			if data then
				local ownerValue = data:FindFirstChild("Owner")
				if ownerValue and ownerValue:IsA("ObjectValue") then
					local owner = ownerValue.Value
					local isMine = (typeof(owner) == "string" and owner == player.Name)
						or (typeof(owner) == "Instance" and owner == player)
					if isMine then
						return plot:FindFirstChild("Baseplate")
							or plot:FindFirstChild("Base")
							or plot:FindFirstChildWhichIsA("BasePart")
							or plot:FindFirstChild("Spawn")
							or plot.PrimaryPart
					end
				end
			end
		end
	end

	-- Fallback: fixed path, in case this game doesn't use per-player Data/Owner
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

-- Holds down the egg's collect prompt for Settings.CollectHoldTime seconds
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

	-- Fallback if there's no ProximityPrompt: simulate holding E
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

-- Picks the highest-priority (rarest enabled) egg currently rendered
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

				currentAction = "Holding to collect"
				updateStatusPanel()
				collectEgg(egg)
				task.wait(0.2)

				eggsCollected += 1
				lastCollectedRarity = rarity

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
local window = UI.new("Ride A Pet", "Script Hub")

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
end)
window:AddToggle(petCard, "Auto Feed", Settings.AutoFeed, function(s)
	Settings.AutoFeed = s
	saveSettings()
end)
window:AddSlider(petCard, "Feed Until Desired Age", 1, 999, Settings.DesiredAge, function(v)
	Settings.DesiredAge = v
	saveSettings()
end)

local eggCard = window:CreateCard(autoLeft, "EGGS", true)
window:AddToggle(eggCard, "Auto Hatch", Settings.AutoHatch, function(s)
	Settings.AutoHatch = s
	saveSettings()
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
end)

-------------------------------------------------
-- EGG TAB
-------------------------------------------------
local eggLeft, eggRight = window:CreateColumns(eggTab, 0.42)

-- AUTO FARM
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

-- MOVEMENT
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

-- ADDITIONAL
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

-- EGG LIST (right column)
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
window:AddSlider(webhookCard, "Send Interval (minutes)", 5, 60, Settings.WebhookInterval, function(v)
	Settings.WebhookInterval = v
	saveSettings()
end)

-------------------------------------------------
-- AUTO REFRESH LOOP
-------------------------------------------------
task.spawn(function()
	while task.wait(Settings.AutoRefreshInterval) do
		if autoRefreshEnabled then
			refreshEggs()
		end
	end
end)

if autoFarmEnabled then startAutoFarm() end

print("Ride A Pet module loaded")
