local UI = {}
UI.__index = UI

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

function UI.new(title)
	local self = setmetatable({}, UI)

	-- Main ScreenGui
	self.ScreenGui = Instance.new("ScreenGui")
	self.ScreenGui.Name = "ScriptHub"
	self.ScreenGui.ResetOnSpawn = false
	self.ScreenGui.Parent = player:WaitForChild("PlayerGui")

	-- Main window frame
	self.Main = Instance.new("Frame")
	self.Main.Size = UDim2.new(0, 400, 0, 300)
	self.Main.Position = UDim2.new(0.5, -200, 0.5, -150)
	self.Main.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	self.Main.BorderSizePixel = 0
	self.Main.Parent = self.ScreenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = self.Main

	-- Title bar
	local titleBar = Instance.new("TextLabel")
	titleBar.Size = UDim2.new(1, 0, 0, 40)
	titleBar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	titleBar.Text = title or "Script Hub"
	titleBar.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleBar.Font = Enum.Font.GothamBold
	titleBar.TextSize = 16
	titleBar.Parent = self.Main

	local titleCorner = Instance.new("UICorner")
	titleCorner.CornerRadius = UDim.new(0, 8)
	titleCorner.Parent = titleBar

	-- Tab container (left side)
	self.TabContainer = Instance.new("Frame")
	self.TabContainer.Size = UDim2.new(0, 100, 1, -40)
	self.TabContainer.Position = UDim2.new(0, 0, 0, 40)
	self.TabContainer.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	self.TabContainer.Parent = self.Main

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.Padding = UDim.new(0, 5)
	tabLayout.Parent = self.TabContainer

	-- Content area (right side, where each tab's buttons/toggles show up)
	self.ContentArea = Instance.new("Frame")
	self.ContentArea.Size = UDim2.new(1, -100, 1, -40)
	self.ContentArea.Position = UDim2.new(0, 100, 0, 40)
	self.ContentArea.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	self.ContentArea.Parent = self.Main

	self.Tabs = {}
	return self
end

function UI:CreateTab(name)
	local tabButton = Instance.new("TextButton")
	tabButton.Size = UDim2.new(1, 0, 0, 35)
	tabButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	tabButton.Text = name
	tabButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	tabButton.Font = Enum.Font.Gotham
	tabButton.TextSize = 14
	tabButton.Parent = self.TabContainer

	local tabPage = Instance.new("ScrollingFrame")
	tabPage.Size = UDim2.new(1, 0, 1, 0)
	tabPage.BackgroundTransparency = 1
	tabPage.Visible = false
	tabPage.CanvasSize = UDim2.new(0, 0, 0, 0)
	tabPage.AutomaticCanvasSize = Enum.AutomaticSize.Y
	tabPage.Parent = self.ContentArea

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.Parent = tabPage

	tabButton.MouseButton1Click:Connect(function()
		for _, page in pairs(self.Tabs) do
			page.Visible = false
		end
		tabPage.Visible = true
	end)

	self.Tabs[name] = tabPage

	-- Show the first tab created by default
	if not self.ActiveTabSet then
		tabPage.Visible = true
		self.ActiveTabSet = true
	end

	return tabPage
end

function UI:AddButton(tabPage, text, callback)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, -20, 0, 35)
	button.Position = UDim2.new(0, 10, 0, 0)
	button.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Font = Enum.Font.Gotham
	button.TextSize = 14
	button.Parent = tabPage

	button.MouseButton1Click:Connect(function()
		if callback then callback() end
	end)

	return button
end

function UI:AddToggle(tabPage, text, default, callback)
	local state = default or false

	local toggle = Instance.new("TextButton")
	toggle.Size = UDim2.new(1, -20, 0, 35)
	toggle.Position = UDim2.new(0, 10, 0, 0)
	toggle.BackgroundColor3 = state and Color3.fromRGB(0, 150, 80) or Color3.fromRGB(50, 50, 50)
	toggle.Text = text .. (state and " [ON]" or " [OFF]")
	toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
	toggle.Font = Enum.Font.Gotham
	toggle.TextSize = 14
	toggle.Parent = tabPage

	toggle.MouseButton1Click:Connect(function()
		state = not state
		toggle.BackgroundColor3 = state and Color3.fromRGB(0, 150, 80) or Color3.fromRGB(50, 50, 50)
		toggle.Text = text .. (state and " [ON]" or " [OFF]")
		if callback then callback(state) end
	end)

	return toggle
end

return UI
