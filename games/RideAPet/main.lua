-- Ride A Pet - Game Module
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer

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

-------------------------------------------------
-- HELPERS
-------------------------------------------------
local function getHRP()
	local character = player.Character
	if not character then return nil end
	return character:FindFirstChild("HumanoidRootPart")
end

local function getBasePosition()
	local baseplate = workspace:FindFirstChild("Plots")
		and workspace.Plots:FindFirstChild("Plot")
		and workspace.Plots.Plot:FindFirstChild("Baseplate")
	if not baseplate then
		warn("[RideAPet] Could not find workspace.Plots.Plot.Baseplate")
		return nil
	end
	return baseplate.Position + Vector3.new(0, 3, 0)
end

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
	Settings.AutoFarmEnabled = s
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
	Settings.GoMethod = v
	saveSettings()
end)
window:AddMethodSelector(farmCard, "Return to Base", {"Tween", "MultiTeleport"}, Settings.ReturnMethod, function(v)
	Settings.ReturnMethod = v
	saveSettings()
end)

-- MOVEMENT
local movementCard = window:CreateCard(eggLeft, "MOVEMENT", true)

window:AddButton(movementCard, "Instant Return to Base", Color3.fromRGB(255, 120, 30), function()
	local hrp = getHRP()
	local basePos = getBasePosition()
	if not hrp or not basePos then return end
	hrp.CFrame = CFrame.new(basePos)
end)

window:AddButton(movementCard, "Multi-Teleport to Base", Color3.fromRGB(200, 90, 20), function()
	local hrp = getHRP()
	local basePos = getBasePosition()
	if not hrp or not basePos then return end

	local startPos = hrp.Position
	local steps = Settings.MultiStepSteps
	local delay = Settings.MultiStepDelay

	for i = 1, steps do
		hrp = getHRP()
		if not hrp then break end
		local alpha = i / steps
		local stepPos = startPos:Lerp(basePos, alpha)
		hrp.CFrame = CFrame.new(stepPos)
		task.wait(delay)
	end
end)

window:AddSlider(movementCard, "Multi-Teleport Delay (s)", 0.2, 1.2, Settings.MultiStepDelay, function(v)
	Settings.MultiStepDelay = v
	saveSettings()
end)

window:AddButton(movementCard, "Smooth Tween to Base", Color3.fromRGB(255, 140, 40), function()
	local hrp = getHRP()
	local basePos = getBasePosition()
	if not hrp or not basePos then return end

	local tween = TweenService:Create(
		hrp,
		TweenInfo.new(Settings.TweenDuration, Enum.EasingStyle.Linear),
		{ CFrame = CFrame.new(basePos) }
	)
	tween:Play()
end)

window:AddSlider(movementCard, "Tween Speed (s)", 2, 12, Settings.TweenDuration, function(v)
	Settings.TweenDuration = v
	saveSettings()
end)

-- ADDITIONAL
local additionalCard = window:CreateCard(eggLeft, "ADDITIONAL", true)
window:AddToggle(additionalCard, "Auto Refresh", Settings.AutoRefreshEnabled, function(s)
	Settings.AutoRefreshEnabled = s
	saveSettings()
end)
window:AddToggle(additionalCard, "Egg ESP", Settings.ESPEnabled, function(s)
	Settings.ESPEnabled = s
	saveSettings()
end)

-- RARITIES + EGG LIST (right column)
local rarityCard = window:CreateCard(eggRight, "RARITIES", true)
window:AddMultiSelectDropdown(rarityCard, "Rarities", Rarities, enabledRarities,
	function(name) return RarityColors[name] end,
	function(name, state)
		Settings.EnabledRarities = enabledRarities
		saveSettings()
		refreshEggs()
	end)

local searchRow = Instance.new("Frame")
searchRow.Size = UDim2.new(1, 0, 0, 36)
searchRow.BackgroundTransparency = 1
searchRow.Parent = eggRight

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
eggScroll.Size = UDim2.new(1, 0, 1, -160)
eggScroll.Position = UDim2.new(0, 0, 0, 175)
eggScroll.BackgroundTransparency = 1
eggScroll.BorderSizePixel = 0
eggScroll.ScrollBarThickness = 3
eggScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
eggScroll.Parent = eggRight
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
				local hrp = getHRP()
				if not hrp then return end

				local targetPart = egg:IsA("BasePart") and egg or egg:FindFirstChildWhichIsA("BasePart")
				if not targetPart then return end

				hrp.CFrame = CFrame.new(targetPart.Position + Vector3.new(0, 3, 0))
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

print("Ride A Pet module loaded")
