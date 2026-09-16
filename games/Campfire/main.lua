-- Campfire/Driftwood Game - Script Hub
-- Built from a Game Data Miner scan (73 remotes, no plot/backpack system
-- detected - this game tracks everything through leaderstats instead).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/soldiv86-rgb/DivineSouls/main/core/ui.lua"))()

local window -- forward-declared so early functions (webhook) close over it correctly

-------------------------------------------------
-- REMOTE RESOLUTION
-- Paths as strings, exactly as the Miner reported them (minus the
-- "ReplicatedStorage." prefix). Centralizing this here means if this game
-- ever reorganizes its folders, there's exactly one place to fix it.
-------------------------------------------------
local function resolveRemote(dotPath)
	local inst = ReplicatedStorage
	for part in dotPath:gmatch("[^%.]+") do
		inst = inst and inst:FindFirstChild(part)
	end
	return inst
end

-- Fires a remote by dot-path, swallowing errors so one missing/renamed
-- remote can't take down an entire automation loop. Returns true/false.
local function fireRemote(dotPath, ...)
	local remote = resolveRemote(dotPath)
	if not remote then
		warn("[ScriptHub] Remote not found (may have been renamed): " .. dotPath)
		return false
	end
	local ok, err = pcall(function(...)
		remote:FireServer(...)
	end, ...)
	if not ok then
		warn("[ScriptHub] FireServer failed for " .. dotPath .. ": " .. tostring(err))
	end
	return ok
end

-------------------------------------------------
-- SETTINGS
-------------------------------------------------
local SAVE_FILE = "CampfireHub_Settings.json"
local Settings = {
	UseNativeAutoFarm = false,      -- fires AutoFarmNetwork.ToggleRequest - the game's OWN autofarm, if it has one
	AutoPickupDriftwood = false,    -- fires DriftwoodNetwork.AutoPickupBatch on a loop
	AutoPickupStick = false,        -- fires StickNetwork.AwakenAutoPickupBatch on a loop
	AutoParticipateEvents = false,  -- fires the Snow/Submerge/Ember/Charcoal/Awaken Request remotes on a loop
	AutoPress = false,              -- fires DrywoodNetwork.PressRequest rapidly (looks like a clicker mechanic)
	AutoRebirth = false,            -- fires RebirthNetwork.Request on a loop
	AutoPrestige = false,           -- fires CampfirePrestigeNetwork.Request on a loop
	AutoRedeemCommunity = false,    -- fires CommunityRewardsNetwork.RedeemRequest on a loop
	WebhookEnabled = false,
	WebhookURL = "",
	WebhookInterval = 5,
}

local function loadSettings()
	if isfile and readfile and isfile(SAVE_FILE) then
		local ok, data = pcall(function() return HttpService:JSONDecode(readfile(SAVE_FILE)) end)
		if ok and type(data) == "table" then
			for k, v in pairs(data) do
				if Settings[k] ~= nil then Settings[k] = v end
			end
		end
	end
end

local function saveSettings()
	if writefile then
		local ok, encoded = pcall(function() return HttpService:JSONEncode(Settings) end)
		if ok then pcall(writefile, SAVE_FILE, encoded) end
	end
end
loadSettings()

local scriptStartTime = os.clock()

-------------------------------------------------
-- STATS
-- Cash and Playtime are StringValues holding an already-formatted display
-- string ("1.01B", "39m 1s"), per the Miner scan - no number parsing needed.
-------------------------------------------------
local function getStats()
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	local playtime = leaderstats and leaderstats:FindFirstChild("Playtime")
	return (cash and tostring(cash.Value)) or "N/A", (playtime and tostring(playtime.Value)) or "N/A"
end

local function getActiveAutomations()
	local active = {}
	if Settings.UseNativeAutoFarm then table.insert(active, "Native Auto Farm") end
	if Settings.AutoPickupDriftwood then table.insert(active, "Auto Pickup Driftwood") end
	if Settings.AutoPickupStick then table.insert(active, "Auto Pickup Sticks") end
	if Settings.AutoParticipateEvents then table.insert(active, "Auto Events") end
	if Settings.AutoPress then table.insert(active, "Auto Press") end
	if Settings.AutoRebirth then table.insert(active, "Auto Rebirth") end
	if Settings.AutoPrestige then table.insert(active, "Auto Prestige") end
	if Settings.AutoRedeemCommunity then table.insert(active, "Auto Community Rewards") end
	if #active == 0 then return "None" end
	return table.concat(active, ", ")
end

-------------------------------------------------
-- AUTOMATION LOOPS
-- Every loop below is a best-effort guess based on the remote's name and
-- Request/Result pairing pattern - none of these had a confirmed argument
-- shape from the scan, so they're all fired with zero arguments. If a loop
-- doesn't seem to do anything in-game, that remote almost certainly needs
-- an argument (an item id, a target reference, etc.) - use the Remote Spy
-- in the Dev tab to capture the real call and we'll wire it precisely.
-------------------------------------------------
local runningFlags = {}
local function startLoop(key, interval, action)
	if runningFlags[key] then return end
	runningFlags[key] = true
	task.spawn(function()
		while Settings[key] do
			action()
			task.wait(interval)
		end
		runningFlags[key] = false
	end)
end

local function startAutoPickupDriftwood()
	startLoop("AutoPickupDriftwood", 3, function()
		fireRemote("DriftwoodNetwork.AutoPickupBatch")
	end)
end

local function startAutoPickupStick()
	startLoop("AutoPickupStick", 3, function()
		fireRemote("StickNetwork.AwakenAutoPickupBatch")
	end)
end

local EventRemotes = {
	"SnowNetwork.Request",
	"SubmergeNetwork.Request",
	"EmberNetwork.Request",
	"CharcoalNetwork.Request",
	"AwakenNetwork.Request",
}
local function startAutoEvents()
	startLoop("AutoParticipateEvents", 5, function()
		for _, path in ipairs(EventRemotes) do
			fireRemote(path)
			task.wait(0.2)
		end
	end)
end

local function startAutoPress()
	startLoop("AutoPress", 0.3, function()
		fireRemote("DrywoodNetwork.PressRequest")
	end)
end

local function startAutoRebirth()
	startLoop("AutoRebirth", 10, function()
		fireRemote("RebirthNetwork.Request")
	end)
end

local function startAutoPrestige()
	startLoop("AutoPrestige", 15, function()
		fireRemote("CampfirePrestigeNetwork.Request")
	end)
end

local function startAutoRedeemCommunity()
	startLoop("AutoRedeemCommunity", 30, function()
		fireRemote("CommunityRewardsNetwork.RedeemRequest")
	end)
end

-------------------------------------------------
-- WEBHOOK (same verified-send pattern as the Ride A Pet hub)
-------------------------------------------------
local function getAvatarThumbnail(httpRequest)
	local ok, result = pcall(function()
		local res = httpRequest({
			Url = string.format(
				"https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=%d&size=150x150&format=Png&isCircular=false",
				player.UserId
			),
			Method = "GET",
		})
		local decoded = HttpService:JSONDecode(res.Body)
		return decoded.data and decoded.data[1] and decoded.data[1].imageUrl
	end)
	return ok and result or nil
end

local function postToDiscord(httpRequest, payload)
	local ok, response = pcall(function()
		return httpRequest({
			Url = Settings.WebhookURL,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = HttpService:JSONEncode(payload),
		})
	end)
	if not ok then return false, "Request errored: " .. tostring(response) end

	local status = response and response.StatusCode
	local success = response and response.Success ~= false and (not status or (status >= 200 and status < 300))
	if not success then
		local reason = (response and response.Body) or (response and response.StatusMessage) or "no response"
		return false, string.format("Discord returned status %s: %s", tostring(status), tostring(reason))
	end
	return true
end

local function sendWebhook(isTest)
	if Settings.WebhookURL == "" then
		if isTest then window:Notify("Webhook", "No webhook URL set.", 3) end
		return
	end

	local httpRequest = (syn and syn.request) or (http and http.request) or http_request or request
	if not httpRequest then
		if isTest then window:Notify("Webhook", "No HTTP request function available in this executor.", 4) end
		return
	end

	local elapsed = math.floor(os.clock() - scriptStartTime)
	local hours = math.floor(elapsed / 3600)
	local mins = math.floor((elapsed % 3600) / 60)
	local secs = elapsed % 60
	local uptimeStr = string.format("%02d:%02d:%02d", hours, mins, secs)

	local cash, playtime = getStats()
	local avatarUrl = getAvatarThumbnail(httpRequest)

	local embed = {
		title = isTest and "Script Hub - Test Webhook" or "Script Hub - Status Update",
		color = 16744224, -- orange
		fields = {
			{ name = "Uptime", value = uptimeStr, inline = true },
			{ name = "Cash", value = cash, inline = true },
			{ name = "Playtime", value = playtime, inline = true },
			{ name = "Active Automations", value = getActiveAutomations(), inline = false },
		},
		author = { name = player.Name },
		footer = { text = "Script Hub" },
		timestamp = DateTime.now():ToIsoDate(),
	}
	if avatarUrl then embed.thumbnail = { url = avatarUrl } end

	local sent, err = postToDiscord(httpRequest, { embeds = { embed } })
	if isTest then
		window:Notify("Webhook", sent and "Test message sent!" or ("Failed: " .. tostring(err)), sent and 3 or 6)
	elseif not sent then
		warn("[ScriptHub] Webhook send failed: " .. tostring(err))
	end
end

-------------------------------------------------
-- REMOTE SPY (Dev tool)
-- Hooks FireServer so that when you manually do something in-game (buy an
-- upgrade, roll a title, etc.), the exact remote + arguments get logged
-- here. This is how we'll get real argument shapes for the remotes that
-- can't be safely automated blind (anything ID-based).
-------------------------------------------------
local spyEnabled = false
local spyLog = {}
local spySupported = (hookmetamethod ~= nil) and (getnamecallmethod ~= nil)
local originalNamecall

local function spyLine(text)
	table.insert(spyLog, os.date("%H:%M:%S") .. "  " .. text)
	if #spyLog > 300 then table.remove(spyLog, 1) end
end

if spySupported then
	originalNamecall = hookmetamethod(game, "__namecall", function(self, ...)
		local method = getnamecallmethod()
		if spyEnabled and method == "FireServer" and (self:IsA("RemoteEvent") or self:IsA("RemoteFunction")) then
			local args = { ... }
			local ok, formatted = pcall(function()
				local parts = {}
				for i = 1, select("#", ...) do
					local v = args[i]
					if typeof(v) == "Instance" then
						table.insert(parts, v:GetFullName())
					else
						table.insert(parts, tostring(v))
					end
				end
				return table.concat(parts, ", ")
			end)
			spyLine(self:GetFullName() .. "  FireServer(" .. (ok and formatted or "?") .. ")")
		end
		return originalNamecall(self, ...)
	end)
end

-------------------------------------------------
-- BUILD WINDOW
-------------------------------------------------
window = UI.new("Script Hub", "Campfire")

local automationTab = window:CreateTab("Automation")
local progressionTab = window:CreateTab("Progression")
local devTab = window:CreateTab("Dev Tools")
local settingsTab = window:CreateTab("Settings")

-------------------------------------------------
-- AUTOMATION TAB
-------------------------------------------------
local autoLeft, autoRight = window:CreateColumns(automationTab, 0.5)

local statusCard = window:CreateCard(autoLeft, "STATUS", true)
local cashLabel = Instance.new("TextLabel")
cashLabel.Size = UDim2.new(1, 0, 0, 18)
cashLabel.BackgroundTransparency = 1
cashLabel.Text = "Cash: -"
cashLabel.TextColor3 = Color3.fromRGB(230, 180, 110)
cashLabel.Font = Enum.Font.Gotham
cashLabel.TextSize = 13
cashLabel.TextXAlignment = Enum.TextXAlignment.Left
cashLabel.Parent = statusCard

local playtimeLabel = cashLabel:Clone()
playtimeLabel.Text = "Playtime: -"
playtimeLabel.Parent = statusCard

task.spawn(function()
	while true do
		local cash, playtime = getStats()
		cashLabel.Text = "Cash: " .. cash
		playtimeLabel.Text = "Playtime: " .. playtime
		task.wait(1)
	end
end)

local farmCard = window:CreateCard(autoLeft, "FARMING", true)
window:AddToggle(farmCard, "Use Native Auto Farm", Settings.UseNativeAutoFarm, function(s)
	Settings.UseNativeAutoFarm = s
	saveSettings()
	fireRemote("AutoFarmNetwork.ToggleRequest", s)
end)
window:AddToggle(farmCard, "Auto Pickup Driftwood", Settings.AutoPickupDriftwood, function(s)
	Settings.AutoPickupDriftwood = s
	saveSettings()
	if s then startAutoPickupDriftwood() end
end)
window:AddToggle(farmCard, "Auto Pickup Sticks", Settings.AutoPickupStick, function(s)
	Settings.AutoPickupStick = s
	saveSettings()
	if s then startAutoPickupStick() end
end)
window:AddToggle(farmCard, "Auto Press (Drywood)", Settings.AutoPress, function(s)
	Settings.AutoPress = s
	saveSettings()
	if s then startAutoPress() end
end)

local eventsCard = window:CreateCard(autoRight, "EVENTS", true)
window:AddToggle(eventsCard, "Auto Participate in Events", Settings.AutoParticipateEvents, function(s)
	Settings.AutoParticipateEvents = s
	saveSettings()
	if s then startAutoEvents() end
end)
window:AddSectionLabel(eventsCard, "Covers: Snow, Submerge, Ember, Charcoal, Awaken")

window:AddToggle(eventsCard, "Auto Redeem Community Rewards", Settings.AutoRedeemCommunity, function(s)
	Settings.AutoRedeemCommunity = s
	saveSettings()
	if s then startAutoRedeemCommunity() end
end)

-------------------------------------------------
-- PROGRESSION TAB
-------------------------------------------------
local progCard = window:CreateCard(progressionTab, "REBIRTH & PRESTIGE", true)
window:AddToggle(progCard, "Auto Rebirth", Settings.AutoRebirth, function(s)
	Settings.AutoRebirth = s
	saveSettings()
	if s then startAutoRebirth() end
end)
window:AddToggle(progCard, "Auto Campfire Prestige", Settings.AutoPrestige, function(s)
	Settings.AutoPrestige = s
	saveSettings()
	if s then startAutoPrestige() end
end)
window:AddSectionLabel(progCard, "Both fire with no arguments - the server should reject them if requirements aren't met yet")

local upgradesCard = window:CreateCard(progressionTab, "UPGRADES (not wired yet)", true)
window:AddSectionLabel(upgradesCard, "UpgradeNetwork, UpgradeTreeNetwork, MonsterDamageTierNetwork and DriftwoodTierNetwork all need an item/tier id we don't have yet.")
window:AddSectionLabel(upgradesCard, "Use the Remote Spy in Dev Tools: buy one upgrade manually, then send me the logged line.")

-------------------------------------------------
-- DEV TOOLS TAB
-------------------------------------------------
local spyCard = window:CreateCard(devTab, "REMOTE SPY", true)

if not spySupported then
	window:AddSectionLabel(spyCard, "hookmetamethod/getnamecallmethod aren't available in this executor - Remote Spy can't run here.")
else
	window:AddToggle(spyCard, "Enable Spy", false, function(s)
		spyEnabled = s
	end)

	local logScroll = Instance.new("ScrollingFrame")
	logScroll.Size = UDim2.new(1, 0, 0, 260)
	logScroll.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
	logScroll.BorderSizePixel = 0
	logScroll.ScrollBarThickness = 4
	logScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	logScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	logScroll.Parent = spyCard
	Instance.new("UICorner", logScroll).CornerRadius = UDim.new(0, 8)
	local logPad = Instance.new("UIPadding", logScroll)
	logPad.PaddingLeft = UDim.new(0, 8)
	logPad.PaddingTop = UDim.new(0, 8)

	local logLabel = Instance.new("TextLabel")
	logLabel.Size = UDim2.new(1, -16, 0, 0)
	logLabel.AutomaticSize = Enum.AutomaticSize.Y
	logLabel.BackgroundTransparency = 1
	logLabel.Font = Enum.Font.Code
	logLabel.TextSize = 12
	logLabel.TextColor3 = Color3.fromRGB(230, 180, 110)
	logLabel.TextXAlignment = Enum.TextXAlignment.Left
	logLabel.TextYAlignment = Enum.TextYAlignment.Top
	logLabel.TextWrapped = true
	logLabel.Text = "(waiting for calls - enable the spy, then use something in-game)"
	logLabel.Parent = logScroll

	task.spawn(function()
		while true do
			if spyEnabled and #spyLog > 0 then
				logLabel.Text = table.concat(spyLog, "\n")
			end
			task.wait(0.5)
		end
	end)

	window:AddButton(spyCard, "Copy Log", Color3.fromRGB(255, 140, 40), function()
		if setclipboard then
			setclipboard(table.concat(spyLog, "\n"))
			window:Notify("Remote Spy", "Log copied.", 2)
		else
			window:Notify("Remote Spy", "setclipboard isn't available in this executor.", 4)
		end
	end)
	window:AddButton(spyCard, "Clear Log", Color3.fromRGB(90, 40, 20), function()
		spyLog = {}
		logLabel.Text = "(cleared)"
	end)
end

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

-------------------------------------------------
-- BACKGROUND LOOPS
-------------------------------------------------
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

if Settings.AutoPickupDriftwood then startAutoPickupDriftwood() end
if Settings.AutoPickupStick then startAutoPickupStick() end
if Settings.AutoParticipateEvents then startAutoEvents() end
if Settings.AutoPress then startAutoPress() end
if Settings.AutoRebirth then startAutoRebirth() end
if Settings.AutoPrestige then startAutoPrestige() end
if Settings.AutoRedeemCommunity then startAutoRedeemCommunity() end
if Settings.UseNativeAutoFarm then fireRemote("AutoFarmNetwork.ToggleRequest", true) end

print("[ScriptHub] Loaded. " .. (spySupported and "Remote Spy available in Dev Tools." or "Remote Spy unsupported in this executor."))
