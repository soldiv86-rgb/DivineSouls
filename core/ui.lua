local UI = {}
UI.__index = UI

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ACCENT = Color3.fromRGB(255, 140, 40)

-- ============ WINDOW ============
function UI.new(title, subtitle)
	local self = setmetatable({}, UI)
	self.Tabs = {}
	self.TabButtons = {}

	if playerGui:FindFirstChild("ScriptHubUI") then
		playerGui.ScriptHubUI:Destroy()
	end

	self.ScreenGui = Instance.new("ScreenGui")
	self.ScreenGui.Name = "ScriptHubUI"
	self.ScreenGui.ResetOnSpawn = false
	self.ScreenGui.Parent = playerGui

	self.Main = Instance.new("Frame")
	self.Main.Size = UDim2.new(0, 880, 0, 580)
	self.Main.Position = UDim2.new(0.5, -440, 0.5, -290)
	self.Main.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
	self.Main.BorderSizePixel = 0
	self.Main.Active = true
	self.Main.Parent = self.ScreenGui
	Instance.new("UICorner", self.Main).CornerRadius = UDim.new(0, 12)
	local ms = Instance.new("UIStroke", self.Main)
	ms.Color = ACCENT
	ms.Thickness = 1.2

	-- Sidebar
	self.Sidebar = Instance.new("Frame")
	self.Sidebar.Size = UDim2.new(0, 160, 1, 0)
	self.Sidebar.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
	self.Sidebar.BorderSizePixel = 0
	self.Sidebar.Parent = self.Main
	Instance.new("UICorner", self.Sidebar).CornerRadius = UDim.new(0, 12)

	local sideCover = Instance.new("Frame")
	sideCover.Size = UDim2.new(0, 20, 1, 0)
	sideCover.Position = UDim2.new(1, -20, 0, 0)
	sideCover.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
	sideCover.BorderSizePixel = 0
	sideCover.Parent = self.Sidebar

	local sideTitle = Instance.new("TextLabel")
	sideTitle.Size = UDim2.new(1, -20, 0, 28)
	sideTitle.Position = UDim2.new(0, 14, 0, 16)
	sideTitle.BackgroundTransparency = 1
	sideTitle.Text = title or "Script Hub"
	sideTitle.TextColor3 = Color3.fromRGB(255, 160, 50)
	sideTitle.Font = Enum.Font.GothamBold
	sideTitle.TextSize = 17
	sideTitle.TextXAlignment = Enum.TextXAlignment.Left
	sideTitle.Parent = self.Sidebar

	if subtitle then
		local sideSub = Instance.new("TextLabel")
		sideSub.Size = UDim2.new(1, -20, 0, 16)
		sideSub.Position = UDim2.new(0, 14, 0, 42)
		sideSub.BackgroundTransparency = 1
		sideSub.Text = subtitle
		sideSub.TextColor3 = Color3.fromRGB(180, 120, 60)
		sideSub.Font = Enum.Font.Gotham
		sideSub.TextSize = 12
		sideSub.TextXAlignment = Enum.TextXAlignment.Left
		sideSub.Parent = self.Sidebar
	end

	-- Content area (right of sidebar)
	self.Content = Instance.new("Frame")
	self.Content.Size = UDim2.new(1, -175, 1, -20)
	self.Content.Position = UDim2.new(0, 168, 0, 10)
	self.Content.BackgroundTransparency = 1
	self.Content.Parent = self.Main

	local headerBar = Instance.new("Frame")
	headerBar.Size = UDim2.new(1, 0, 0, 40)
	headerBar.BackgroundColor3 = Color3.fromRGB(18, 18, 20)
	headerBar.BorderSizePixel = 0
	headerBar.Parent = self.Content
	Instance.new("UICorner", headerBar).CornerRadius = UDim.new(0, 9)

	local headerTitle = Instance.new("TextLabel")
	headerTitle.Size = UDim2.new(1, -50, 1, 0)
	headerTitle.Position = UDim2.new(0, 14, 0, 0)
	headerTitle.BackgroundTransparency = 1
	headerTitle.Text = title or "Script Hub"
	headerTitle.TextColor3 = Color3.fromRGB(255, 170, 60)
	headerTitle.Font = Enum.Font.GothamBold
	headerTitle.TextSize = 16
	headerTitle.TextXAlignment = Enum.TextXAlignment.Left
	headerTitle.Parent = headerBar

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 30, 0, 26)
	closeBtn.Position = UDim2.new(1, -38, 0.5, -13)
	closeBtn.BackgroundColor3 = Color3.fromRGB(40, 20, 10)
	closeBtn.Text = "×"
	closeBtn.TextColor3 = Color3.fromRGB(255, 160, 80)
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 17
	closeBtn.AutoButtonColor = false
	closeBtn.Parent = headerBar
	Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 7)

	-- Floating open/close button
	local openBtn = Instance.new("TextButton")
	openBtn.Size = UDim2.new(0, 46, 0, 46)
	openBtn.Position = UDim2.new(0, 30, 0, 100)
	openBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
	openBtn.Text = (title or "SH"):sub(1, 2):upper()
	openBtn.TextColor3 = Color3.fromRGB(255, 160, 50)
	openBtn.Font = Enum.Font.GothamBold
	openBtn.TextSize = 14
	openBtn.Parent = self.ScreenGui
	Instance.new("UICorner", openBtn).CornerRadius = UDim.new(0, 11)
	local os_ = Instance.new("UIStroke", openBtn)
	os_.Color = ACCENT
	os_.Thickness = 1.4

	local isOpen = true
	closeBtn.MouseButton1Click:Connect(function()
		self.Main.Visible = false
		isOpen = false
	end)

	local openDragging, openDragStart, openStartPos, openMoved = false, nil, nil, false
	openBtn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			openDragging = true
			openMoved = false
			openDragStart = input.Position
			openStartPos = openBtn.Position
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if openDragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			openDragging = false
			if not openMoved then
				isOpen = not isOpen
				self.Main.Visible = isOpen
			end
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if openDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - openDragStart
			if math.abs(delta.X) > 5 or math.abs(delta.Y) > 5 then openMoved = true end
			openBtn.Position = UDim2.new(openStartPos.X.Scale, openStartPos.X.Offset + delta.X, openStartPos.Y.Scale, openStartPos.Y.Offset + delta.Y)
		end
	end)

	-- Drag main window by header
	local dragging, dragStart, startPos = false, nil, nil
	headerBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = self.Main.Position
		end
	end)
	headerBar.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			self.Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)

	self._nextTabY = 70
	return self
end

-- ============ TABS ============
function UI:CreateTab(name)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, -16, 0, 36)
	btn.Position = UDim2.new(0, 8, 0, self._nextTabY)
	btn.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
	btn.Text = "  " .. name
	btn.TextColor3 = Color3.fromRGB(200, 140, 70)
	btn.Font = Enum.Font.Gotham
	btn.TextSize = 14
	btn.TextXAlignment = Enum.TextXAlignment.Left
	btn.AutoButtonColor = false
	btn.Parent = self.Sidebar
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
	self._nextTabY = self._nextTabY + 42

	local page = Instance.new("Frame")
	page.Size = UDim2.new(1, 0, 1, -50)
	page.Position = UDim2.new(0, 0, 0, 48)
	page.BackgroundTransparency = 1
	page.Visible = false
	page.Parent = self.Content

	self.Tabs[name] = page
	self.TabButtons[name] = btn

	btn.MouseButton1Click:Connect(function()
		self:SetActiveTab(name)
	end)

	if not self._activeSet then
		self:SetActiveTab(name)
		self._activeSet = true
	end

	return page
end

function UI:SetActiveTab(name)
	for tabName, page in pairs(self.Tabs) do
		page.Visible = (tabName == name)
	end
	for tabName, btn in pairs(self.TabButtons) do
		if tabName == name then
			btn.BackgroundColor3 = Color3.fromRGB(30, 22, 15)
			btn.TextColor3 = Color3.fromRGB(255, 170, 60)
		else
			btn.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
			btn.TextColor3 = Color3.fromRGB(180, 120, 60)
		end
	end
end

-- Split a tab page into two scrolling columns (left/right)
function UI:CreateColumns(tabPage, leftRatio)
	leftRatio = leftRatio or 0.48
	local left = Instance.new("ScrollingFrame")
	left.Size = UDim2.new(leftRatio, 0, 1, 0)
	left.BackgroundTransparency = 1
	left.BorderSizePixel = 0
	left.ScrollBarThickness = 4
	left.AutomaticCanvasSize = Enum.AutomaticSize.Y
	left.Parent = tabPage
	local ll = Instance.new("UIListLayout", left)
	ll.Padding = UDim.new(0, 12)
	local lp = Instance.new("UIPadding", left)
	lp.PaddingTop = UDim.new(0, 4)
	lp.PaddingBottom = UDim.new(0, 10)
	lp.PaddingRight = UDim.new(0, 6)

	local right = Instance.new("Frame")
	right.Size = UDim2.new(1 - leftRatio - 0.02, 0, 1, 0)
	right.Position = UDim2.new(leftRatio + 0.02, 0, 0, 0)
	right.BackgroundTransparency = 1
	right.Parent = tabPage

	return left, right
end

-- ============ WIDGETS ============
function UI:CreateCard(parent, titleText, defaultOpen)
	defaultOpen = defaultOpen ~= false
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = Color3.fromRGB(18, 18, 20)
	card.BorderSizePixel = 0
	card.Parent = parent
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
	local stroke = Instance.new("UIStroke", card)
	stroke.Color = ACCENT
	stroke.Thickness = 1
	stroke.Transparency = 0.7

	local header = Instance.new("TextButton")
	header.Size = UDim2.new(1, 0, 0, 36)
	header.BackgroundColor3 = Color3.fromRGB(24, 22, 20)
	header.Text = ""
	header.AutoButtonColor = false
	header.Parent = card
	Instance.new("UICorner", header).CornerRadius = UDim.new(0, 10)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -50, 1, 0)
	title.Position = UDim2.new(0, 14, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = titleText
	title.TextColor3 = Color3.fromRGB(255, 160, 50)
	title.Font = Enum.Font.GothamMedium
	title.TextSize = 14
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header

	local arrow = Instance.new("TextLabel")
	arrow.Size = UDim2.new(0, 30, 1, 0)
	arrow.Position = UDim2.new(1, -35, 0, 0)
	arrow.BackgroundTransparency = 1
	arrow.Text = defaultOpen and "▼" or "▶"
	arrow.TextColor3 = ACCENT
	arrow.Font = Enum.Font.GothamBold
	arrow.TextSize = 14
	arrow.Parent = header

	local contentFrame = Instance.new("Frame")
	contentFrame.Size = UDim2.new(1, 0, 0, 0)
	contentFrame.AutomaticSize = Enum.AutomaticSize.Y
	contentFrame.BackgroundTransparency = 1
	contentFrame.Visible = defaultOpen
	contentFrame.Parent = card

	local pad = Instance.new("UIPadding", contentFrame)
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)

	local list = Instance.new("UIListLayout", contentFrame)
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder

	local isOpen = defaultOpen
	header.MouseButton1Click:Connect(function()
		isOpen = not isOpen
		contentFrame.Visible = isOpen
		arrow.Text = isOpen and "▼" or "▶"
	end)

	return contentFrame
end

function UI:AddToggle(parent, text, default, callback)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 34)
	frame.BackgroundColor3 = Color3.fromRGB(24, 24, 26)
	frame.BorderSizePixel = 0
	frame.Parent = parent
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -55, 1, 0)
	label.Position = UDim2.new(0, 10, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(230, 180, 110)
	label.Font = Enum.Font.Gotham
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = frame

	local toggle = Instance.new("TextButton")
	toggle.Size = UDim2.new(0, 40, 0, 20)
	toggle.Position = UDim2.new(1, -48, 0.5, -10)
	toggle.BackgroundColor3 = default and ACCENT or Color3.fromRGB(45, 40, 35)
	toggle.Text = ""
	toggle.AutoButtonColor = false
	toggle.Parent = frame
	Instance.new("UICorner", toggle).CornerRadius = UDim.new(1, 0)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 14, 0, 14)
	knob.Position = default and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
	knob.BackgroundColor3 = Color3.fromRGB(255, 220, 160)
	knob.BorderSizePixel = 0
	knob.Parent = toggle
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

	local state = default
	toggle.MouseButton1Click:Connect(function()
		state = not state
		TweenService:Create(toggle, TweenInfo.new(0.18), {
			BackgroundColor3 = state and ACCENT or Color3.fromRGB(45, 40, 35)
		}):Play()
		TweenService:Create(knob, TweenInfo.new(0.18), {
			Position = state and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
		}):Play()
		if callback then callback(state) end
	end)
	return frame
end

function UI:AddSlider(parent, label, minV, maxV, default, callback)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 52)
	frame.BackgroundColor3 = Color3.fromRGB(24, 24, 26)
	frame.BorderSizePixel = 0
	frame.Parent = parent
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -60, 0, 16)
	title.Position = UDim2.new(0, 10, 0, 5)
	title.BackgroundTransparency = 1
	title.Text = label
	title.TextColor3 = Color3.fromRGB(220, 160, 90)
	title.Font = Enum.Font.Gotham
	title.TextSize = 12
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local box = Instance.new("TextBox")
	box.Size = UDim2.new(0, 50, 0, 16)
	box.Position = UDim2.new(1, -58, 0, 5)
	box.BackgroundColor3 = Color3.fromRGB(35, 30, 25)
	box.Text = tostring(default)
	box.TextColor3 = Color3.fromRGB(255, 200, 120)
	box.Font = Enum.Font.Gotham
	box.TextSize = 12
	box.ClearTextOnFocus = false
	box.Parent = frame
	Instance.new("UICorner", box).CornerRadius = UDim.new(0, 5)

	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, -20, 0, 5)
	track.Position = UDim2.new(0, 10, 0, 32)
	track.BackgroundColor3 = Color3.fromRGB(40, 35, 30)
	track.BorderSizePixel = 0
	track.Parent = frame
	Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = ACCENT
	fill.BorderSizePixel = 0
	fill.Parent = track
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

	local knob = Instance.new("TextButton")
	knob.Size = UDim2.new(0, 13, 0, 13)
	knob.BackgroundColor3 = Color3.fromRGB(255, 180, 80)
	knob.Text = ""
	knob.AutoButtonColor = false
	knob.Parent = track
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

	local sliding = false
	local function set(val)
		val = math.clamp(val, minV, maxV)
		val = math.floor(val * 100 + 0.5) / 100
		local a = (val - minV) / (maxV - minV)
		fill.Size = UDim2.new(a, 0, 1, 0)
		knob.Position = UDim2.new(a, -6, 0.5, -6)
		box.Text = tostring(val)
		if callback then callback(val) end
	end

	knob.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then sliding = true end
	end)
	UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then sliding = false end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if sliding and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local rel = i.Position.X - track.AbsolutePosition.X
			set(minV + (maxV - minV) * math.clamp(rel / track.AbsoluteSize.X, 0, 1))
		end
	end)
	box.FocusLost:Connect(function()
		local n = tonumber(box.Text)
		if n then set(n) else box.Text = tostring(default) end
	end)
	set(default)
	return frame
end

function UI:AddButton(parent, text, color, callback)
	color = color or ACCENT
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 34)
	btn.BackgroundColor3 = color
	btn.Text = text
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Font = Enum.Font.GothamMedium
	btn.TextSize = 13
	btn.AutoButtonColor = false
	btn.Parent = parent
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.15), {
			BackgroundColor3 = Color3.new(math.min(color.R + 0.1, 1), math.min(color.G + 0.08, 1), math.min(color.B + 0.05, 1))
		}):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = color}):Play()
	end)
	btn.MouseButton1Click:Connect(function()
		if callback then callback() end
	end)
	return btn
end

-- Generalized to any number of options (original was hardcoded to Tween/Multi)
function UI:AddMethodSelector(parent, labelText, options, currentValue, onChange)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 34)
	frame.BackgroundColor3 = Color3.fromRGB(24, 24, 26)
	frame.BorderSizePixel = 0
	frame.Parent = parent
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.34, 0, 1, 0)
	label.Position = UDim2.new(0, 10, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = labelText
	label.TextColor3 = Color3.fromRGB(230, 180, 110)
	label.Font = Enum.Font.Gotham
	label.TextSize = 12
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = frame

	local buttons = {}
	local slotWidth = (1 - 0.36) / #options

	for i, optName in ipairs(options) do
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(slotWidth - 0.02, -2, 0, 24)
		b.Position = UDim2.new(0.36 + (i - 1) * slotWidth, 0, 0.5, -12)
		b.BackgroundColor3 = (currentValue == optName) and ACCENT or Color3.fromRGB(40, 35, 30)
		b.Text = optName
		b.TextColor3 = Color3.fromRGB(255, 255, 255)
		b.Font = Enum.Font.GothamMedium
		b.TextSize = 11
		b.AutoButtonColor = false
		b.Parent = frame
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
		buttons[optName] = b

		b.MouseButton1Click:Connect(function()
			currentValue = optName
			for name, btn in pairs(buttons) do
				btn.BackgroundColor3 = (name == currentValue) and ACCENT or Color3.fromRGB(40, 35, 30)
			end
			onChange(optName)
		end)
	end

	return frame
end

return UI
