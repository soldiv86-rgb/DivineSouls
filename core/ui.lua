local UI = {}
UI.__index = UI

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ACCENT = Color3.fromRGB(255, 140, 40)

-- ============ INTERNAL HELPERS ============
-- Small shared helpers so widgets don't repeat the same 4-line UICorner /
-- UIStroke / drag boilerplate over and over. Purely organizational -
-- behavior is identical to writing it out by hand each time.

local function corner(inst, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = inst
	return c
end

local function stroke(inst, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color or ACCENT
	s.Thickness = thickness or 1
	s.Transparency = transparency or 0
	s.Parent = inst
	return s
end

-- Makes `target` draggable via `handle`. onClick fires if the input ended
-- without moving past the drag threshold (used for the floating open button,
-- which is both draggable and clickable).
local function makeDraggable(handle, target, onClick)
	local dragging, dragStart, startPos, moved = false, nil, nil, false

	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			moved = false
			dragStart = input.Position
			startPos = target.Position
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			if not moved and onClick then onClick() end
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			if math.abs(delta.X) > 5 or math.abs(delta.Y) > 5 then moved = true end
			target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
end

-- Binds a horizontal track+knob pair to a numeric range. Used by AddSlider
-- and AddColorPicker's RGB channels so the drag math only lives in one place.
local function bindHorizontalDrag(track, knob, onDrag)
	local sliding = false
	knob.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then sliding = true end
	end)
	UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then sliding = false end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if sliding and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local rel = i.Position.X - track.AbsolutePosition.X
			local a = math.clamp(rel / track.AbsoluteSize.X, 0, 1)
			onDrag(a)
		end
	end)
	-- also allow click-anywhere-on-track to jump to that position
	track.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			local rel = i.Position.X - track.AbsolutePosition.X
			onDrag(math.clamp(rel / track.AbsoluteSize.X, 0, 1))
		end
	end)
end

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
	corner(self.Main, 12)
	stroke(self.Main, ACCENT, 1.2)

	-- Sidebar
	self.Sidebar = Instance.new("Frame")
	self.Sidebar.Size = UDim2.new(0, 160, 1, 0)
	self.Sidebar.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
	self.Sidebar.BorderSizePixel = 0
	self.Sidebar.Parent = self.Main
	corner(self.Sidebar, 12)

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
	corner(headerBar, 9)

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
	corner(closeBtn, 7)

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
	corner(openBtn, 11)
	stroke(openBtn, ACCENT, 1.4)

	local isOpen = true
	closeBtn.MouseButton1Click:Connect(function()
		self.Main.Visible = false
		isOpen = false
	end)

	makeDraggable(openBtn, openBtn, function()
		isOpen = not isOpen
		self.Main.Visible = isOpen
	end)

	makeDraggable(headerBar, self.Main, nil)

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
	corner(btn, 8)
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

function UI:CreateCard(parent, titleText, defaultOpen)
	defaultOpen = defaultOpen ~= false
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = Color3.fromRGB(18, 18, 20)
	card.BorderSizePixel = 0
	card.Parent = parent
	corner(card, 10)
	stroke(card, ACCENT, 1, 0.7)

	local header = Instance.new("TextButton")
	header.Size = UDim2.new(1, 0, 0, 36)
	header.BackgroundColor3 = Color3.fromRGB(24, 22, 20)
	header.Text = ""
	header.AutoButtonColor = false
	header.Parent = card
	corner(header, 10)

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

-- ============ FLOATING PANEL HELPERS ============
-- Shared by Dropdown, MultiSelectDropdown and ColorPicker so each one
-- doesn't reinvent "box you click that opens an overlay panel".

function UI:_createSelectorBox(parent, height)
	local box = Instance.new("TextButton")
	box.Size = UDim2.new(1, 0, 0, height or 34)
	box.BackgroundColor3 = Color3.fromRGB(24, 24, 26)
	box.Text = ""
	box.AutoButtonColor = false
	box.Parent = parent
	corner(box, 8)

	local boxText = Instance.new("TextLabel")
	boxText.Size = UDim2.new(1, -40, 1, 0)
	boxText.Position = UDim2.new(0, 10, 0, 0)
	boxText.BackgroundTransparency = 1
	boxText.TextColor3 = Color3.fromRGB(230, 180, 110)
	boxText.Font = Enum.Font.Gotham
	boxText.TextSize = 13
	boxText.TextXAlignment = Enum.TextXAlignment.Left
	boxText.ClipsDescendants = true
	boxText.Parent = box

	local chevron = Instance.new("TextLabel")
	chevron.Size = UDim2.new(0, 24, 1, 0)
	chevron.Position = UDim2.new(1, -30, 0, 0)
	chevron.BackgroundTransparency = 1
	chevron.Text = "▼"
	chevron.TextColor3 = ACCENT
	chevron.Font = Enum.Font.GothamBold
	chevron.TextSize = 16
	chevron.Parent = box

	return box, boxText, chevron
end

function UI:_createFloatingPanel(w, h)
	local panel = Instance.new("Frame")
	panel.Size = UDim2.new(0, w, 0, h)
	panel.BackgroundColor3 = Color3.fromRGB(18, 18, 20)
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.ZIndex = 50
	panel.Parent = self.ScreenGui
	corner(panel, 8)
	stroke(panel, ACCENT, 1, 0.6)
	return panel
end

-- Returns a setOpen(bool) function. Positions the panel just below `box`.
function UI:_toggleFloatingPanel(box, panel, chevron)
	local open = false
	local function setOpen(state)
		open = state
		if open then
			local absPos = box.AbsolutePosition
			local absSize = box.AbsoluteSize
			panel.Position = UDim2.new(0, absPos.X, 0, absPos.Y + absSize.Y + 4)
		end
		panel.Visible = open
		if chevron then chevron.Text = open and "▲" or "▼" end
	end
	box.MouseButton1Click:Connect(function() setOpen(not open) end)
	return setOpen
end

-- ============ WIDGETS ============

function UI:AddToggle(parent, text, default, callback)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 34)
	frame.BackgroundColor3 = Color3.fromRGB(24, 24, 26)
	frame.BorderSizePixel = 0
	frame.Parent = parent
	corner(frame, 8)

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
	corner(toggle, 999)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 14, 0, 14)
	knob.Position = default and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
	knob.BackgroundColor3 = Color3.fromRGB(255, 220, 160)
	knob.BorderSizePixel = 0
	knob.Parent = toggle
	corner(knob, 999)

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
	return frame, function() return state end
end

function UI:AddSlider(parent, label, minV, maxV, default, callback)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 52)
	frame.BackgroundColor3 = Color3.fromRGB(24, 24, 26)
	frame.BorderSizePixel = 0
	frame.Parent = parent
	corner(frame, 8)

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
	corner(box, 5)

	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, -20, 0, 5)
	track.Position = UDim2.new(0, 10, 0, 32)
	track.BackgroundColor3 = Color3.fromRGB(40, 35, 30)
	track.BorderSizePixel = 0
	track.Parent = frame
	corner(track, 999)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = ACCENT
	fill.BorderSizePixel = 0
	fill.Parent = track
	corner(fill, 999)

	local knob = Instance.new("TextButton")
	knob.Size = UDim2.new(0, 13, 0, 13)
	knob.BackgroundColor3 = Color3.fromRGB(255, 180, 80)
	knob.Text = ""
	knob.AutoButtonColor = false
	knob.Parent = track
	corner(knob, 999)

	local currentVal = default
	local function set(val)
		val = math.clamp(val, minV, maxV)
		val = math.floor(val * 100 + 0.5) / 100
		currentVal = val
		local a = (val - minV) / (maxV - minV)
		fill.Size = UDim2.new(a, 0, 1, 0)
		knob.Position = UDim2.new(a, -6, 0.5, -6)
		box.Text = tostring(val)
		if callback then callback(val) end
	end

	bindHorizontalDrag(track, knob, function(a)
		set(minV + (maxV - minV) * a)
	end)

	box.FocusLost:Connect(function()
		local n = tonumber(box.Text)
		if n then set(n) else box.Text = tostring(currentVal) end
	end)

	set(default)
	return frame, function() return currentVal end
end

-- Single-select dropdown. For multi-select, use AddMultiSelectDropdown.
function UI:AddDropdown(parent, label, options, default, onChange)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(1, 0, 0, 54)
	container.BackgroundTransparency = 1
	container.Parent = parent

	local labelLbl = Instance.new("TextLabel")
	labelLbl.Size = UDim2.new(1, 0, 0, 18)
	labelLbl.BackgroundTransparency = 1
	labelLbl.Text = label
	labelLbl.TextColor3 = Color3.fromRGB(200, 160, 100)
	labelLbl.Font = Enum.Font.Gotham
	labelLbl.TextSize = 12
	labelLbl.TextXAlignment = Enum.TextXAlignment.Left
	labelLbl.Parent = container

	local boxHolder = Instance.new("Frame")
	boxHolder.Size = UDim2.new(1, 0, 0, 34)
	boxHolder.Position = UDim2.new(0, 0, 0, 20)
	boxHolder.BackgroundTransparency = 1
	boxHolder.Parent = container

	local box, boxText, chevron = self:_createSelectorBox(boxHolder, 34)
	local current = default or options[1]
	boxText.Text = current or "..."

	local panel = self:_createFloatingPanel(220, math.clamp(#options * 34 + 12, 40, 260))
	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, -12, 1, -12)
	list.Position = UDim2.new(0, 6, 0, 6)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 3
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ZIndex = 51
	list.Parent = panel
	local layout = Instance.new("UIListLayout", list)
	layout.Padding = UDim.new(0, 4)

	local setOpen = self:_toggleFloatingPanel(box, panel, chevron)
	local rows = {}

	local function refreshHighlight()
		for name, row in pairs(rows) do
			local isSel = name == current
			row.BackgroundColor3 = isSel and Color3.fromRGB(30, 22, 15) or Color3.fromRGB(24, 24, 26)
			row.TextColor3 = isSel and Color3.fromRGB(255, 170, 60) or Color3.fromRGB(230, 200, 150)
		end
	end

	for _, name in ipairs(options) do
		local row = Instance.new("TextButton")
		row.Size = UDim2.new(1, 0, 0, 30)
		row.Text = name
		row.Font = Enum.Font.Gotham
		row.TextSize = 13
		row.AutoButtonColor = false
		row.ZIndex = 52
		row.Parent = list
		corner(row, 6)
		rows[name] = row

		row.MouseButton1Click:Connect(function()
			current = name
			boxText.Text = name
			setOpen(false)
			refreshHighlight()
			if onChange then onChange(current) end
		end)
	end
	refreshHighlight()

	return container, function() return current end
end

-- Compact collapsible multi-select: shows selected items as text,
-- expands into a floating searchable checklist when tapped.
function UI:AddMultiSelectDropdown(parent, label, options, selectedSet, colorFor, onChange)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(1, 0, 0, 54)
	container.BackgroundTransparency = 1
	container.Parent = parent

	local labelLbl = Instance.new("TextLabel")
	labelLbl.Size = UDim2.new(1, 0, 0, 18)
	labelLbl.BackgroundTransparency = 1
	labelLbl.Text = label
	labelLbl.TextColor3 = Color3.fromRGB(200, 160, 100)
	labelLbl.Font = Enum.Font.Gotham
	labelLbl.TextSize = 12
	labelLbl.TextXAlignment = Enum.TextXAlignment.Left
	labelLbl.Parent = container

	local boxHolder = Instance.new("Frame")
	boxHolder.Size = UDim2.new(1, 0, 0, 34)
	boxHolder.Position = UDim2.new(0, 0, 0, 20)
	boxHolder.BackgroundTransparency = 1
	boxHolder.Parent = container

	local box, boxText, chevron = self:_createSelectorBox(boxHolder, 34)

	local function updateBoxText()
		local names = {}
		for _, name in ipairs(options) do
			if selectedSet[name] then table.insert(names, name) end
		end
		boxText.Text = (#names == 0) and "..." or table.concat(names, ", ")
	end
	updateBoxText()

	local panel = self:_createFloatingPanel(260, 300)

	local search = Instance.new("TextBox")
	search.Size = UDim2.new(1, -16, 0, 30)
	search.Position = UDim2.new(0, 8, 0, 8)
	search.BackgroundColor3 = Color3.fromRGB(28, 28, 30)
	search.PlaceholderText = "Search.."
	search.Text = ""
	search.TextColor3 = Color3.fromRGB(255, 200, 140)
	search.PlaceholderColor3 = Color3.fromRGB(120, 100, 80)
	search.Font = Enum.Font.Gotham
	search.TextSize = 13
	search.ClearTextOnFocus = false
	search.ZIndex = 51
	search.Parent = panel
	corner(search, 6)

	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, -16, 1, -46)
	list.Position = UDim2.new(0, 8, 0, 44)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 3
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ZIndex = 51
	list.Parent = panel
	local listLayout = Instance.new("UIListLayout", list)
	listLayout.Padding = UDim.new(0, 4)

	local rows = {}
	local function rebuildRows(filter)
		for _, r in ipairs(rows) do r:Destroy() end
		rows = {}
		for _, name in ipairs(options) do
			if filter == "" or name:lower():find(filter:lower(), 1, true) then
				local row = Instance.new("TextButton")
				row.Size = UDim2.new(1, 0, 0, 32)
				row.BackgroundColor3 = Color3.fromRGB(24, 24, 26)
				row.Text = ""
				row.AutoButtonColor = false
				row.ZIndex = 52
				row.Parent = list
				corner(row, 6)

				local bar = Instance.new("Frame")
				bar.Size = UDim2.new(0, 4, 1, -10)
				bar.Position = UDim2.new(0, 5, 0, 5)
				bar.BackgroundColor3 = colorFor and colorFor(name) or ACCENT
				bar.BorderSizePixel = 0
				bar.Visible = selectedSet[name] == true
				bar.ZIndex = 53
				bar.Parent = row
				corner(bar, 2)

				local rowLabel = Instance.new("TextLabel")
				rowLabel.Size = UDim2.new(1, -24, 1, 0)
				rowLabel.Position = UDim2.new(0, 18, 0, 0)
				rowLabel.BackgroundTransparency = 1
				rowLabel.Text = name
				rowLabel.TextColor3 = Color3.fromRGB(230, 200, 150)
				rowLabel.Font = Enum.Font.Gotham
				rowLabel.TextSize = 13
				rowLabel.TextXAlignment = Enum.TextXAlignment.Left
				rowLabel.ZIndex = 53
				rowLabel.Parent = row

				row.MouseButton1Click:Connect(function()
					selectedSet[name] = not selectedSet[name]
					bar.Visible = selectedSet[name] == true
					updateBoxText()
					if onChange then onChange(name, selectedSet[name], selectedSet) end
				end)

				table.insert(rows, row)
			end
		end
	end
	rebuildRows("")

	search:GetPropertyChangedSignal("Text"):Connect(function()
		rebuildRows(search.Text)
	end)

	self:_toggleFloatingPanel(box, panel, chevron)

	return container
end

-- Click a button, then press any key to bind it. Returns a getter for the
-- current KeyCode (or nil if unbound).
function UI:AddKeybind(parent, text, default, callback)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 34)
	frame.BackgroundColor3 = Color3.fromRGB(24, 24, 26)
	frame.BorderSizePixel = 0
	frame.Parent = parent
	corner(frame, 8)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -90, 1, 0)
	label.Position = UDim2.new(0, 10, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(230, 180, 110)
	label.Font = Enum.Font.Gotham
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = frame

	local keyBtn = Instance.new("TextButton")
	keyBtn.Size = UDim2.new(0, 76, 0, 24)
	keyBtn.Position = UDim2.new(1, -84, 0.5, -12)
	keyBtn.BackgroundColor3 = Color3.fromRGB(40, 35, 30)
	keyBtn.Text = default and default.Name or "None"
	keyBtn.TextColor3 = Color3.fromRGB(255, 200, 120)
	keyBtn.Font = Enum.Font.GothamMedium
	keyBtn.TextSize = 12
	keyBtn.AutoButtonColor = false
	keyBtn.Parent = frame
	corner(keyBtn, 6)

	local listening = false
	local currentKey = default

	keyBtn.MouseButton1Click:Connect(function()
		if listening then return end
		listening = true
		keyBtn.Text = "..."
		keyBtn.BackgroundColor3 = ACCENT
	end)

	UserInputService.InputBegan:Connect(function(input)
		if not listening then return end
		if input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode == Enum.KeyCode.Escape then
				currentKey = nil
				keyBtn.Text = "None"
			else
				currentKey = input.KeyCode
				keyBtn.Text = currentKey.Name
			end
			keyBtn.BackgroundColor3 = Color3.fromRGB(40, 35, 30)
			listening = false
			if callback then callback(currentKey) end
		end
	end)

	return frame, function() return currentKey end
end

-- RGB color picker: swatch opens a small floating panel with 3 sliders.
function UI:AddColorPicker(parent, label, default, callback)
	default = default or ACCENT

	local container = Instance.new("Frame")
	container.Size = UDim2.new(1, 0, 0, 34)
	container.BackgroundColor3 = Color3.fromRGB(24, 24, 26)
	container.BorderSizePixel = 0
	container.Parent = parent
	corner(container, 8)

	local labelLbl = Instance.new("TextLabel")
	labelLbl.Size = UDim2.new(1, -55, 1, 0)
	labelLbl.Position = UDim2.new(0, 10, 0, 0)
	labelLbl.BackgroundTransparency = 1
	labelLbl.Text = label
	labelLbl.TextColor3 = Color3.fromRGB(230, 180, 110)
	labelLbl.Font = Enum.Font.Gotham
	labelLbl.TextSize = 13
	labelLbl.TextXAlignment = Enum.TextXAlignment.Left
	labelLbl.Parent = container

	local swatch = Instance.new("TextButton")
	swatch.Size = UDim2.new(0, 34, 0, 20)
	swatch.Position = UDim2.new(1, -44, 0.5, -10)
	swatch.BackgroundColor3 = default
	swatch.Text = ""
	swatch.AutoButtonColor = false
	swatch.Parent = container
	corner(swatch, 6)
	stroke(swatch, Color3.new(1, 1, 1), 1, 0.7)

	local panel = self:_createFloatingPanel(210, 130)
	local r, g, b = math.floor(default.R * 255), math.floor(default.G * 255), math.floor(default.B * 255)
	local currentColor = default

	local function updateColor()
		currentColor = Color3.fromRGB(r, g, b)
		swatch.BackgroundColor3 = currentColor
		if callback then callback(currentColor) end
	end

	local function buildChannel(yPos, channelName, initial, setFn)
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -16, 0, 30)
		row.Position = UDim2.new(0, 8, 0, yPos)
		row.BackgroundTransparency = 1
		row.ZIndex = 51
		row.Parent = panel

		local chLabel = Instance.new("TextLabel")
		chLabel.Size = UDim2.new(0, 16, 0, 14)
		chLabel.BackgroundTransparency = 1
		chLabel.Text = channelName
		chLabel.TextColor3 = Color3.fromRGB(220, 160, 90)
		chLabel.Font = Enum.Font.GothamBold
		chLabel.TextSize = 11
		chLabel.TextXAlignment = Enum.TextXAlignment.Left
		chLabel.ZIndex = 52
		chLabel.Parent = row

		local track = Instance.new("Frame")
		track.Size = UDim2.new(1, 0, 0, 5)
		track.Position = UDim2.new(0, 0, 0, 18)
		track.BackgroundColor3 = Color3.fromRGB(40, 35, 30)
		track.BorderSizePixel = 0
		track.ZIndex = 51
		track.Parent = row
		corner(track, 999)

		local fill = Instance.new("Frame")
		fill.Size = UDim2.new(initial / 255, 0, 1, 0)
		fill.BackgroundColor3 = ACCENT
		fill.BorderSizePixel = 0
		fill.ZIndex = 52
		fill.Parent = track
		corner(fill, 999)

		local knob = Instance.new("TextButton")
		knob.Size = UDim2.new(0, 12, 0, 12)
		knob.Position = UDim2.new(initial / 255, -6, 0.5, -6)
		knob.BackgroundColor3 = Color3.fromRGB(255, 220, 160)
		knob.Text = ""
		knob.AutoButtonColor = false
		knob.ZIndex = 53
		knob.Parent = track
		corner(knob, 999)

		bindHorizontalDrag(track, knob, function(a)
			local val = math.floor(a * 255 + 0.5)
			fill.Size = UDim2.new(a, 0, 1, 0)
			knob.Position = UDim2.new(a, -6, 0.5, -6)
			setFn(val)
			updateColor()
		end)
	end

	buildChannel(0, "R", r, function(v) r = v end)
	buildChannel(34, "G", g, function(v) g = v end)
	buildChannel(68, "B", b, function(v) b = v end)

	swatch.MouseButton1Click:Connect(function()
		local absPos = swatch.AbsolutePosition
		local absSize = swatch.AbsoluteSize
		panel.Position = UDim2.new(0, absPos.X - 176, 0, absPos.Y + absSize.Y + 4)
		panel.Visible = not panel.Visible
	end)

	return container, function() return currentColor end
end

-- Single-line text input with a label.
function UI:AddTextbox(parent, label, placeholder, default, callback)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 34)
	frame.BackgroundColor3 = Color3.fromRGB(24, 24, 26)
	frame.BorderSizePixel = 0
	frame.Parent = parent
	corner(frame, 8)

	local labelLbl = Instance.new("TextLabel")
	labelLbl.Size = UDim2.new(0.4, -10, 1, 0)
	labelLbl.Position = UDim2.new(0, 10, 0, 0)
	labelLbl.BackgroundTransparency = 1
	labelLbl.Text = label
	labelLbl.TextColor3 = Color3.fromRGB(230, 180, 110)
	labelLbl.Font = Enum.Font.Gotham
	labelLbl.TextSize = 13
	labelLbl.TextXAlignment = Enum.TextXAlignment.Left
	labelLbl.Parent = frame

	local box = Instance.new("TextBox")
	box.Size = UDim2.new(0.6, -10, 0, 24)
	box.Position = UDim2.new(0.4, 0, 0.5, -12)
	box.BackgroundColor3 = Color3.fromRGB(35, 30, 25)
	box.PlaceholderText = placeholder or ""
	box.Text = default or ""
	box.TextColor3 = Color3.fromRGB(255, 200, 120)
	box.PlaceholderColor3 = Color3.fromRGB(120, 100, 80)
	box.Font = Enum.Font.Gotham
	box.TextSize = 12
	box.ClearTextOnFocus = false
	box.Parent = frame
	corner(box, 6)

	box.FocusLost:Connect(function(enterPressed)
		if callback then callback(box.Text, enterPressed) end
	end)

	return frame, function() return box.Text end
end

-- Small uppercase caption for breaking a card's contents into groups.
function UI:AddSectionLabel(parent, text)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0, 18)
	lbl.BackgroundTransparency = 1
	lbl.Text = text:upper()
	lbl.TextColor3 = Color3.fromRGB(150, 110, 70)
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 11
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = parent
	return lbl
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
	corner(btn, 8)

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

-- Segmented button group for choosing between a small fixed set of options.
function UI:AddMethodSelector(parent, labelText, options, currentValue, onChange)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 34)
	frame.BackgroundColor3 = Color3.fromRGB(24, 24, 26)
	frame.BorderSizePixel = 0
	frame.Parent = parent
	corner(frame, 8)

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
		corner(b, 6)
		buttons[optName] = b

		b.MouseButton1Click:Connect(function()
			currentValue = optName
			for name, btn in pairs(buttons) do
				btn.BackgroundColor3 = (name == currentValue) and ACCENT or Color3.fromRGB(40, 35, 30)
			end
			onChange(optName)
		end)
	end

	return frame, function() return currentValue end
end

-- Toast notification, slides in from bottom-right and auto-dismisses.
-- Usage: UIInstance:Notify("Saved", "Your settings were saved.", 3)
function UI:Notify(titleText, bodyText, duration)
	duration = duration or 3

	local notif = Instance.new("Frame")
	notif.Size = UDim2.new(0, 260, 0, 64)
	notif.Position = UDim2.new(1, 20, 1, -84)
	notif.BackgroundColor3 = Color3.fromRGB(18, 18, 20)
	notif.BorderSizePixel = 0
	notif.ZIndex = 100
	notif.Parent = self.ScreenGui
	corner(notif, 10)
	stroke(notif, ACCENT, 1.2, 0.3)

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0, 3, 1, -16)
	bar.Position = UDim2.new(0, 8, 0, 8)
	bar.BackgroundColor3 = ACCENT
	bar.BorderSizePixel = 0
	bar.ZIndex = 101
	bar.Parent = notif
	corner(bar, 2)

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(1, -28, 0, 20)
	titleLbl.Position = UDim2.new(0, 18, 0, 8)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Text = titleText
	titleLbl.TextColor3 = Color3.fromRGB(255, 170, 60)
	titleLbl.Font = Enum.Font.GothamBold
	titleLbl.TextSize = 13
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.ZIndex = 101
	titleLbl.Parent = notif

	local bodyLbl = Instance.new("TextLabel")
	bodyLbl.Size = UDim2.new(1, -28, 0, 32)
	bodyLbl.Position = UDim2.new(0, 18, 0, 28)
	bodyLbl.BackgroundTransparency = 1
	bodyLbl.Text = bodyText or ""
	bodyLbl.TextColor3 = Color3.fromRGB(200, 170, 140)
	bodyLbl.Font = Enum.Font.Gotham
	bodyLbl.TextSize = 12
	bodyLbl.TextXAlignment = Enum.TextXAlignment.Left
	bodyLbl.TextWrapped = true
	bodyLbl.ZIndex = 101
	bodyLbl.Parent = notif

	TweenService:Create(notif, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(1, -280, 1, -84)
	}):Play()

	task.delay(duration, function()
		local t = TweenService:Create(notif, TweenInfo.new(0.25), {Position = UDim2.new(1, 20, 1, -84)})
		t:Play()
		t.Completed:Connect(function() notif:Destroy() end)
	end)
end

return UI
