-- Egg Upgrade Tee- Game Module


local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

-- Load the shared UI library
local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/soldiv86-rgb/DivineSouls/main/core/ui.lua"))()

-------------------------------------------------
-- SETTINGS
-------------------------------------------------
-- Filename includes the PlaceId so this never collides with another game's
-- save file if you keep multiple game modules around.
local SAVE_FILE = "EggUpgradeTree_Settings.json"

local Settings = {
	AutoClickEnabled = false,
	AutoClickInterval = 0.2,
	AutoClickArg = "",              -- CONFIGURE: leave blank unless KeycapPressed needs an argument

	AutoBuyEnabled = false,
	AutoBuyInterval = 5,
	AutoBuyTargets = {"1", "2", "3"}, -- CONFIGURE: whatever BuyMaxEvent actually expects (ids/names)

	AutoBoosterEnabled = false,
	AutoBoosterInterval = 30,

	AutoSupernovaEnabled = false,
	SupernovaStat = "Points",
	SupernovaThreshold = 1000000,

	AutoLoopEnabled = false,
	LoopStat = "SupernovaTier",
	LoopThreshold = 10,

	WebhookEnabled = false,
	WebhookReportEnabled = false,
	WebhookURL = "",
	WebhookInterval = 15,            -- minutes, for the periodic stat snapshot
	WebhookStats = {"Points", "XP", "Level", "Prestige"},
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
-- STATS  (Players.<Name>.Values.<StatName> - confirmed by the miner report)
-------------------------------------------------
local KNOWN_STATS = {
	"Points", "Gamma", "Delta", "Omega", "XP", "Level", "Prestige", "Power",
	"Steel", "Keycap", "SpacePoints", "StarLevels", "StarXP", "SpacePrestige",
	"Loops", "DarkMatter", "SupernovaTier", "Nova", "MaxNova", "NovaSpent",
}

local function getValuesFolder()
	return player:FindFirstChild("Values")
end

local function getStat(name)
	local vf = getValuesFolder()
	if not vf then return 0 end
	local obj = vf:FindFirstChild(name)
	return (obj and obj.Value) or 0
end

-------------------------------------------------
-- REMOTES  (paths copied verbatim from the miner report)
-------------------------------------------------
-- entry.parent tells us which folder under ReplicatedStorage each remote
-- lives in; resolved fresh (FindFirstChild) on every call rather than cached,
-- so a remote that loads in late doesn't get stuck "missing" forever.
local REMOTE_LIST = {
	{ name = "CmdrEvent", parent = "CmdrClient" },
	{ name = "CmdrFunction", parent = "CmdrClient" },
	{ name = "AdminDevToolsEvent", parent = "Remotes" },
	{ name = "TutorialGiveEggs", parent = "Remotes" },
	{ name = "RedeemZoneMaxEvent", parent = "Remotes" },
	{ name = "ActivateBoosterEvent", parent = "Remotes" },
	{ name = "AnalyticsFunnelEvent", parent = "Remotes" },
	{ name = "SupernovaRespecEvent", parent = "Remotes" },
	{ name = "SupernovaEvent", parent = "Remotes" },
	{ name = "BoostHUDEvent", parent = "Remotes" },
	{ name = "TutorialCompletedEvent", parent = "Remotes" },
	{ name = "AdminGrantBoostEvent", parent = "Remotes" },
	{ name = "AchievementUnlocked", parent = "Remotes" },
	{ name = "SettingsLoaded", parent = "Remotes" },
	{ name = "UpdateSetting", parent = "Remotes" },
	{ name = "GetSlotPreview", parent = "Remotes" },
	{ name = "RequestSlotSwap", parent = "Remotes" },
	{ name = "LoopEvent", parent = "Remotes" },
	{ name = "StarExperienceGain", parent = "Remotes" },
	{ name = "KeycapPressed", parent = "Remotes" },
	{ name = "GetVisibleInfo", parent = "Remotes" },
	{ name = "SoundPlayEvent", parent = "Remotes" },
	{ name = "SendPlayerAchievements", parent = "Remotes" },
	{ name = "GiftProductEvent", parent = "Remotes" },
	{ name = "PurchaseDeniedEvent", parent = "Remotes" },
	{ name = "BuyOneEvent", parent = "Remotes" },
	{ name = "BuyMaxEvent", parent = "Remotes" },
	{ name = "TeleportEvent", parent = "Remotes" },
	{ name = "TeleportTransition", parent = "Remotes" },
	{ name = "UpdateUpgrade", parent = "Remotes" },
	{ name = "GetUpgradeInfo", parent = "Remotes" },
}

local remoteFolders = {
	Remotes = ReplicatedStorage:FindFirstChild("Remotes"),
	CmdrClient = ReplicatedStorage:FindFirstChild("CmdrClient"),
}

local function getRemoteByName(name)
	for _, entry in ipairs(REMOTE_LIST) do
		if entry.name == name then
			local folder = remoteFolders[entry.parent]
			return folder and folder:FindFirstChild(name)
		end
	end
	return nil
end

-- "" / nil -> nil, "true"/"false" -> boolean, numeric strings -> number,
-- anything else stays a string. Used by the Remote Tester and by the
-- config boxes for AutoBuyTargets / AutoClickArg.
local function parseArg(text)
	if text == nil or text == "" then return nil end
	if text == "true" then return true end
	if text == "false" then return false end
	local n = tonumber(text)
	if n then return n end
	return text
end

-------------------------------------------------
-- DISCORD WEBHOOK  (same working pattern as RideAPet - black/orange embed)
-------------------------------------------------
local function httpRequest(opts)
	local requestFn = (syn and syn.request) or (http and http.request) or http_request or request
		or (fluxus and fluxus.request)
	if requestFn then
		local ok, res = pcall(requestFn, opts)
		if ok then return res end
	end
	local ok, res = pcall(function()
		HttpService:PostAsync(opts.Url, opts.Body, Enum.HttpContentType.ApplicationJson)
		return true
	end)
	if ok then return res end
	warn("[GameMod] Webhook send failed - no working HTTP method available")
	return nil
end

local Webhook = {}
local ACCENT_COLOR = 0xFF8C28 -- orange, matches the UI's accent

function Webhook.Send(title, fields, color)
	if not Settings.WebhookEnabled then return end
	if not Settings.WebhookURL or Settings.WebhookURL == "" then
		warn("[GameMod] Webhook is enabled but no URL is set in Settings tab")
		return
	end

	local embedFields = {}
	for _, f in ipairs(fields or {}) do
		table.insert(embedFields, { name = f[1], value = tostring(f[2]), inline = f[3] ~= false })
	end

	local payload = {
		username = "Game Miner Bot",
		embeds = { {
			title = title,
			color = color or ACCENT_COLOR,
			fields = embedFields,
			footer = { text = "DivineSouls • Simulator" },
		} },
	}

	local ok, encoded = pcall(function() return HttpService:JSONEncode(payload) end)
	if not ok then return end

	task.spawn(function()
		httpRequest({
			Url = Settings.WebhookURL,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = encoded,
		})
	end)
end

-------------------------------------------------
-- AUTOMATION LOOPS
-------------------------------------------------
local autoClickRunning = false
local function startAutoClick()
	if autoClickRunning then return end
	autoClickRunning = true
	task.spawn(function()
		while Settings.AutoClickEnabled do
			local remote = getRemoteByName("KeycapPressed")
			if remote then
				local arg = parseArg(Settings.AutoClickArg)
				local ok, err = pcall(function()
					if arg ~= nil then remote:FireServer(arg) else remote:FireServer() end
				end)
				if not ok then warn("[GameMod] KeycapPressed failed: " .. tostring(err)) end
			end
			task.wait(Settings.AutoClickInterval)
		end
		autoClickRunning = false
	end)
end

local autoBuyRunning = false
local function startAutoBuy()
	if autoBuyRunning then return end
	autoBuyRunning = true
	task.spawn(function()
		while Settings.AutoBuyEnabled do
			local remote = getRemoteByName("BuyMaxEvent")
			if remote then
				for _, target in ipairs(Settings.AutoBuyTargets) do
					if not Settings.AutoBuyEnabled then break end
					local ok, err = pcall(function()
						remote:FireServer(parseArg(target))
					end)
					if not ok then
						warn("[GameMod] BuyMaxEvent(" .. tostring(target) .. ") failed: " .. tostring(err))
					end
					task.wait(0.3)
				end
			end
			task.wait(Settings.AutoBuyInterval)
		end
		autoBuyRunning = false
	end)
end

local autoBoosterRunning = false
local function startAutoBooster()
	if autoBoosterRunning then return end
	autoBoosterRunning = true
	task.spawn(function()
		while Settings.AutoBoosterEnabled do
			local remote = getRemoteByName("ActivateBoosterEvent")
			if remote then
				local ok, err = pcall(function() remote:FireServer() end)
				if not ok then warn("[GameMod] ActivateBoosterEvent failed: " .. tostring(err)) end
			end
			task.wait(Settings.AutoBoosterInterval)
		end
		autoBoosterRunning = false
	end)
end

-- Threshold-based auto-prestige. You choose which stat and how high it must
-- get before firing - safer than me guessing the real currency for you,
-- and it means this can double as "auto Supernova" for whichever resource
-- your game actually gates it behind once you find out.
local autoSupernovaRunning = false
local function startAutoSupernova()
	if autoSupernovaRunning then return end
	autoSupernovaRunning = true
	task.spawn(function()
		while Settings.AutoSupernovaEnabled do
			if getStat(Settings.SupernovaStat) >= Settings.SupernovaThreshold then
				local remote = getRemoteByName("SupernovaEvent")
				if remote then
					local ok, err = pcall(function() remote:FireServer() end)
					if not ok then warn("[GameMod] SupernovaEvent failed: " .. tostring(err)) end
					task.wait(3) -- give the server a moment before rechecking the stat
				end
			end
			task.wait(2)
		end
		autoSupernovaRunning = false
	end)
end

local autoLoopRunning = false
local function startAutoLoop()
	if autoLoopRunning then return end
	autoLoopRunning = true
	task.spawn(function()
		while Settings.AutoLoopEnabled do
			if getStat(Settings.LoopStat) >= Settings.LoopThreshold then
				local remote = getRemoteByName("LoopEvent")
				if remote then
					local ok, err = pcall(function() remote:FireServer() end)
					if not ok then warn("[GameMod] LoopEvent failed: " .. tostring(err)) end
					task.wait(3)
				end
			end
			task.wait(2)
		end
		autoLoopRunning = false
	end)
end

-------------------------------------------------
-- BUILD WINDOW
-------------------------------------------------
-- CONFIGURE: swap "Simulator" for the real game name once you know it.
-- guiName is explicit so this can run alongside another game's UI (e.g.
-- Ride A Pet's) in the same session without either one destroying the
-- other's ScreenGui.
local window = UI.new("Simulator", "Script Hub", "GameMinerUI_83506318058022")

local dashboardTab = window:CreateTab("Dashboard")
local automationTab = window:CreateTab("Automation")
local testerTab = window:CreateTab("Remote Tester")
local settingsTab = window:CreateTab("Settings")

-------------------------------------------------
-- DASHBOARD TAB  (fully working - reads real Values folder, no guessing)
-------------------------------------------------
local dashLeft, dashRight = window:CreateColumns(dashboardTab, 0.5)

local statsCard = window:CreateCard(dashLeft, "LIVE STATS", true)
local statLabels = {}
for _, statName in ipairs(KNOWN_STATS) do
	local row = Instance.new("TextLabel")
	row.Size = UDim2.new(1, 0, 0, 20)
	row.BackgroundTransparency = 1
	row.Text = statName .. ": -"
	row.TextColor3 = Color3.fromRGB(230, 180, 110)
	row.Font = Enum.Font.Gotham
	row.TextSize = 13
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.Parent = statsCard
	statLabels[statName] = row
end

task.spawn(function()
	while true do
		for _, statName in ipairs(KNOWN_STATS) do
			local lbl = statLabels[statName]
			if lbl then
				lbl.Text = statName .. ": " .. tostring(getStat(statName))
			end
		end
		task.wait(1)
	end
end)

local infoCard = window:CreateCard(dashRight, "ABOUT THIS GAME", true)
local infoText = Instance.new("TextLabel")
infoText.Size = UDim2.new(1, 0, 0, 140)
infoText.BackgroundTransparency = 1
infoText.Text = "No backpack items or owned plot were found by the miner, "
	.. "so this game is likely a pure stat/remote-driven incremental "
	.. "(clicking/typing based on the KeycapPressed remote and Keycap stat). "
	.. "Use the Remote Tester tab to confirm what each action needs before "
	.. "relying on the automation toggles in the Automation tab."
infoText.TextWrapped = true
infoText.TextColor3 = Color3.fromRGB(200, 170, 140)
infoText.Font = Enum.Font.Gotham
infoText.TextSize = 13
infoText.TextXAlignment = Enum.TextXAlignment.Left
infoText.TextYAlignment = Enum.TextYAlignment.Top
infoText.Parent = infoCard

-------------------------------------------------
-- AUTOMATION TAB
-------------------------------------------------
local autoLeft, autoRight = window:CreateColumns(automationTab, 0.48)

local clickCard = window:CreateCard(autoLeft, "AUTO CLICK (KeycapPressed)", true)
window:AddToggle(clickCard, "Auto Click", Settings.AutoClickEnabled, function(s)
	Settings.AutoClickEnabled = s
	saveSettings()
	if s then startAutoClick() end
end)
window:AddSlider(clickCard, "Click Interval (s)", 0.05, 2.0, Settings.AutoClickInterval, function(v)
	Settings.AutoClickInterval = v
	saveSettings()
end)
window:AddTextbox(clickCard, "Extra Arg (optional)", "leave blank if not needed", Settings.AutoClickArg, function(text)
	Settings.AutoClickArg = text
	saveSettings()
end)

local buyCard = window:CreateCard(autoLeft, "AUTO BUY (BuyMaxEvent)", true)
window:AddToggle(buyCard, "Auto Buy", Settings.AutoBuyEnabled, function(s)
	Settings.AutoBuyEnabled = s
	saveSettings()
	if s then startAutoBuy() end
end)
window:AddTextbox(buyCard, "Targets (comma-separated ids/names)", "1, 2, 3", table.concat(Settings.AutoBuyTargets, ", "), function(text)
	local items = {}
	for name in text:gmatch("[^,]+") do
		table.insert(items, (name:gsub("^%s*(.-)%s*$", "%1")))
	end
	Settings.AutoBuyTargets = items
	saveSettings()
end)
window:AddSlider(buyCard, "Buy Check Interval (s)", 1, 60, Settings.AutoBuyInterval, function(v)
	Settings.AutoBuyInterval = v
	saveSettings()
end)

local boosterCard = window:CreateCard(autoRight, "AUTO BOOSTER", true)
window:AddToggle(boosterCard, "Auto Activate Booster", Settings.AutoBoosterEnabled, function(s)
	Settings.AutoBoosterEnabled = s
	saveSettings()
	if s then startAutoBooster() end
end)
window:AddSlider(boosterCard, "Check Interval (s)", 5, 120, Settings.AutoBoosterInterval, function(v)
	Settings.AutoBoosterInterval = v
	saveSettings()
end)

local prestigeCard = window:CreateCard(autoRight, "AUTO PRESTIGE (Supernova / Loop)", true)
window:AddToggle(prestigeCard, "Auto Supernova", Settings.AutoSupernovaEnabled, function(s)
	Settings.AutoSupernovaEnabled = s
	saveSettings()
	if s then startAutoSupernova() end
end)
window:AddDropdown(prestigeCard, "Supernova Trigger Stat", KNOWN_STATS, Settings.SupernovaStat, function(v)
	Settings.SupernovaStat = v
	saveSettings()
end)
window:AddTextbox(prestigeCard, "Supernova Threshold", "e.g. 1000000", tostring(Settings.SupernovaThreshold), function(text)
	Settings.SupernovaThreshold = tonumber(text) or Settings.SupernovaThreshold
	saveSettings()
end)

window:AddToggle(prestigeCard, "Auto Loop", Settings.AutoLoopEnabled, function(s)
	Settings.AutoLoopEnabled = s
	saveSettings()
	if s then startAutoLoop() end
end)
window:AddDropdown(prestigeCard, "Loop Trigger Stat", KNOWN_STATS, Settings.LoopStat, function(v)
	Settings.LoopStat = v
	saveSettings()
end)
window:AddTextbox(prestigeCard, "Loop Threshold", "e.g. 10", tostring(Settings.LoopThreshold), function(text)
	Settings.LoopThreshold = tonumber(text) or Settings.LoopThreshold
	saveSettings()
end)

local manualCard = window:CreateCard(autoRight, "MANUAL ACTIONS", true)
window:AddButton(manualCard, "Redeem Zone Max", Color3.fromRGB(255, 140, 40), function()
	local remote = getRemoteByName("RedeemZoneMaxEvent")
	if remote then pcall(function() remote:FireServer() end) end
end)
window:AddButton(manualCard, "Supernova Respec", Color3.fromRGB(200, 90, 20), function()
	local remote = getRemoteByName("SupernovaRespecEvent")
	if remote then pcall(function() remote:FireServer() end) end
end)

local zoneIdBox
_, zoneIdBox = window:AddTextbox(manualCard, "Zone Id", "e.g. 5", "1", function() end)
window:AddButton(manualCard, "Teleport to Zone", Color3.fromRGB(255, 120, 30), function()
	local remote = getRemoteByName("TeleportEvent")
	if remote then
		pcall(function() remote:FireServer(parseArg(zoneIdBox())) end)
	end
end)

-------------------------------------------------
-- REMOTE TESTER TAB
-------------------------------------------------
local testerLeft, testerRight = window:CreateColumns(testerTab, 0.5)

local testerCard = window:CreateCard(testerLeft, "FIRE / INVOKE A REMOTE", true)

local remoteNames = {}
for _, entry in ipairs(REMOTE_LIST) do
	table.insert(remoteNames, entry.name)
end

local selectedRemoteName = remoteNames[1]
window:AddDropdown(testerCard, "Remote", remoteNames, selectedRemoteName, function(v)
	selectedRemoteName = v
end)

local getArg1, getArg2, getArg3
_, getArg1 = window:AddTextbox(testerCard, "Arg 1 (optional)", "number, true/false, or text", "", function() end)
_, getArg2 = window:AddTextbox(testerCard, "Arg 2 (optional)", "number, true/false, or text", "", function() end)
_, getArg3 = window:AddTextbox(testerCard, "Arg 3 (optional)", "number, true/false, or text", "", function() end)

local resultCard = window:CreateCard(testerRight, "RESULT", true)
local resultLabel = Instance.new("TextLabel")
resultLabel.Size = UDim2.new(1, 0, 0, 160)
resultLabel.BackgroundTransparency = 1
resultLabel.Text = "Result: (nothing fired yet)"
resultLabel.TextWrapped = true
resultLabel.TextColor3 = Color3.fromRGB(200, 170, 140)
resultLabel.Font = Enum.Font.Gotham
resultLabel.TextSize = 13
resultLabel.TextXAlignment = Enum.TextXAlignment.Left
resultLabel.TextYAlignment = Enum.TextYAlignment.Top
resultLabel.Parent = resultCard

window:AddButton(testerCard, "Fire / Invoke", Color3.fromRGB(255, 140, 40), function()
	local remote = getRemoteByName(selectedRemoteName)
	if not remote then
		resultLabel.Text = "Result: remote not found (" .. tostring(selectedRemoteName) .. ")"
		return
	end

	local args = {}
	for _, getter in ipairs({ getArg1, getArg2, getArg3 }) do
		local parsed = parseArg(getter())
		if parsed ~= nil then table.insert(args, parsed) end
	end

	local ok, result = pcall(function()
		if remote:IsA("RemoteFunction") then
			return remote:InvokeServer(table.unpack(args))
		else
			remote:FireServer(table.unpack(args))
			return "fired (RemoteEvent has no return value)"
		end
	end)

	if ok then
		local ok2, resultText = pcall(function()
			if typeof(result) == "table" then
				return HttpService:JSONEncode(result)
			end
			return tostring(result)
		end)
		resultLabel.Text = "Result: " .. (ok2 and resultText or "(unprintable result)")
	else
		resultLabel.Text = "Error: " .. tostring(result)
	end
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
window:AddToggle(webhookCard, "Send Periodic Stat Reports", Settings.WebhookReportEnabled, function(s)
	Settings.WebhookReportEnabled = s
	saveSettings()
end)
window:AddSlider(webhookCard, "Report Interval (minutes)", 1, 60, Settings.WebhookInterval, function(v)
	Settings.WebhookInterval = v
	saveSettings()
end)

local webhookStatsSet = {}
for _, s in ipairs(Settings.WebhookStats or {}) do webhookStatsSet[s] = true end

window:AddMultiSelectDropdown(webhookCard, "Stats to Report", KNOWN_STATS, webhookStatsSet, nil, function()
	local arr = {}
	for _, s in ipairs(KNOWN_STATS) do
		if webhookStatsSet[s] then table.insert(arr, s) end
	end
	Settings.WebhookStats = arr
	saveSettings()
end)

window:AddButton(webhookCard, "Send Test Message", Color3.fromRGB(255, 140, 40), function()
	Webhook.Send("🔔 Test Message", {
		{ "Status", "Webhook connected successfully!" },
	})
end)

-------------------------------------------------
-- PERIODIC STAT SNAPSHOT LOOP
-------------------------------------------------
task.spawn(function()
	while true do
		task.wait((Settings.WebhookInterval or 15) * 60)
		if Settings.WebhookEnabled and Settings.WebhookReportEnabled then
			local fields = {}
			for _, statName in ipairs(Settings.WebhookStats) do
				table.insert(fields, { statName, getStat(statName) })
			end
			Webhook.Send("📊 Stat Snapshot", fields)
		end
	end
end)

-------------------------------------------------
-- STARTUP: resume any loops that were enabled last session
-------------------------------------------------
if Settings.AutoClickEnabled then startAutoClick() end
if Settings.AutoBuyEnabled then startAutoBuy() end
if Settings.AutoBoosterEnabled then startAutoBooster() end
if Settings.AutoSupernovaEnabled then startAutoSupernova() end
if Settings.AutoLoopEnabled then startAutoLoop() end

print("Egg Upgrade Tree Loaded!")
