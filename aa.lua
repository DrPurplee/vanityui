-- VanityUI.lua
-- Compact keyboard-driven Roblox UI library inspired by FiveM-style menus.
-- Standalone build intended to be hosted on GitHub and loaded as a single file.

local VanityUI = {}
VanityUI.__index = VanityUI

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local DEFAULT_THEME = {
    Background = Color3.fromRGB(15, 15, 18),
    BackgroundSecondary = Color3.fromRGB(24, 24, 28),
    Item = Color3.fromRGB(28, 28, 32),
    ItemHover = Color3.fromRGB(42, 42, 48),
    Selected = Color3.fromRGB(238, 238, 238),
    SelectedText = Color3.fromRGB(16, 16, 18),
    Text = Color3.fromRGB(235, 235, 235),
    MutedText = Color3.fromRGB(150, 150, 160),
    Accent = Color3.fromRGB(255, 255, 255),
    Border = Color3.fromRGB(70, 70, 78),
}

local function mergeTheme(custom)
    local out = {}
    for k, v in pairs(DEFAULT_THEME) do out[k] = v end
    if custom then
        for k, v in pairs(custom) do out[k] = v end
    end
    return out
end

local function new(className, props)
    local obj = Instance.new(className)
    for k, v in pairs(props or {}) do
        obj[k] = v
    end
    return obj
end

local function tween(obj, info, props)
    local tw = TweenService:Create(obj, info, props)
    tw:Play()
    return tw
end

local function round(parent, radius)
    return new("UICorner", {
        Parent = parent,
        CornerRadius = UDim.new(0, radius or 4),
    })
end

local function stroke(parent, color, transparency, thickness)
    return new("UIStroke", {
        Parent = parent,
        Color = color,
        Transparency = transparency or 0,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
end

local function safeCall(fn, ...)
    if typeof(fn) ~= "function" then return end
    local ok, err = pcall(fn, ...)
    if not ok then
        warn("[VanityUI] Callback error:", err)
    end
end

local function clamp(v, a, b)
    return math.max(a, math.min(b, v))
end

local Menu = {}
Menu.__index = Menu

local Page = {}
Page.__index = Page

local SubMenu = {}
SubMenu.__index = SubMenu

local Item = {}
Item.__index = Item

function VanityUI:CreateMenu(config)
    config = config or {}
    local self = setmetatable({}, Menu)

    self.Title = config.Title or "Vanity"
    self.Subtitle = config.Subtitle or "MENU"
    self.Banner = config.Banner
    self.Width = config.Width or 410
    self.HeaderHeight = config.HeaderHeight or 118
    self.Visible = config.Visible ~= false
    self.Keybind = config.Keybind or Enum.KeyCode.Insert
    self.Theme = mergeTheme(config.Theme)
    self.Pages = {}
    self.PageIndex = 1
    self.OpenStack = {}
    self.SelectedIndex = 1
    self.ItemHeight = config.ItemHeight or 34
    self.MaxVisibleItems = config.MaxVisibleItems or 11
    self.Destroyed = false

    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    local existing = playerGui:FindFirstChild("VanityUI")
    if existing then existing:Destroy() end

    self.Gui = new("ScreenGui", {
        Name = "VanityUI",
        Parent = playerGui,
        IgnoreGuiInset = true,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })

    self.Root = new("Frame", {
        Parent = self.Gui,
        Name = "Root",
        Size = UDim2.fromOffset(self.Width, 520),
        Position = config.Position or UDim2.new(0, 40, 0.5, -260),
        BackgroundColor3 = self.Theme.Background,
        BackgroundTransparency = 0.05,
        BorderSizePixel = 0,
        Visible = self.Visible,
        ClipsDescendants = true,
    })
    round(self.Root, 6)
    stroke(self.Root, self.Theme.Border, 0.35, 1)

    self.Header = new("Frame", {
        Parent = self.Root,
        Name = "Header",
        Size = UDim2.new(1, 0, 0, self.HeaderHeight),
        BackgroundColor3 = self.Theme.BackgroundSecondary,
        BorderSizePixel = 0,
        Active = true,
    })

    if self.Banner then
        self.BannerImage = new("ImageLabel", {
            Parent = self.Header,
            Name = "Banner",
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Image = self.Banner,
            ScaleType = Enum.ScaleType.Crop,
        })
        new("UIGradient", {
            Parent = self.BannerImage,
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.05),
                NumberSequenceKeypoint.new(0.7, 0.15),
                NumberSequenceKeypoint.new(1, 0.55),
            }),
            Rotation = 90,
        })
    end

    self.TitleLabel = new("TextLabel", {
        Parent = self.Header,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(18, 16),
        Size = UDim2.new(1, -36, 0, 45),
        Font = Enum.Font.GothamBold,
        Text = self.Title,
        TextColor3 = self.Theme.Text,
        TextSize = 28,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
    })

    self.SubtitleLabel = new("TextLabel", {
        Parent = self.Header,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(20, 58),
        Size = UDim2.new(1, -40, 0, 22),
        Font = Enum.Font.GothamMedium,
        Text = string.upper(self.Subtitle),
        TextColor3 = self.Theme.MutedText,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    self.TabBar = new("Frame", {
        Parent = self.Root,
        Name = "TabBar",
        Position = UDim2.fromOffset(0, self.HeaderHeight),
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = self.Theme.BackgroundSecondary,
        BorderSizePixel = 0,
    })

    self.TabList = new("UIListLayout", {
        Parent = self.TabBar,
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 2),
        SortOrder = Enum.SortOrder.LayoutOrder,
    })

    new("UIPadding", {
        Parent = self.TabBar,
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8),
    })

    self.Content = new("Frame", {
        Parent = self.Root,
        Name = "Content",
        Position = UDim2.fromOffset(0, self.HeaderHeight + 38),
        Size = UDim2.new(1, 0, 1, -(self.HeaderHeight + 38 + 32)),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
    })

    self.Footer = new("Frame", {
        Parent = self.Root,
        Name = "Footer",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = self.Theme.BackgroundSecondary,
        BorderSizePixel = 0,
    })

    self.FooterLeft = new("TextLabel", {
        Parent = self.Footer,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(0.7, -12, 1, 0),
        Font = Enum.Font.Gotham,
        Text = "↑ ↓ navigate  •  ← → change  •  Enter select  •  Backspace back",
        TextColor3 = self.Theme.MutedText,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    self.Counter = new("TextLabel", {
        Parent = self.Footer,
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -12, 0, 0),
        Size = UDim2.new(0.3, 0, 1, 0),
        Font = Enum.Font.GothamMedium,
        Text = "0 / 0",
        TextColor3 = self.Theme.Text,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Right,
    })

    self:_setupDragging()
    self:_setupInput()
    self:_updateCanvasHeight()

    return self
end

function Menu:_setupDragging()
    local dragging = false
    local dragStart
    local startPos

    self.Header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = self.Root.Position
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            self.Root.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
end

function Menu:_setupInput()
    self.InputConnection = UserInputService.InputBegan:Connect(function(input, processed)
        if processed or self.Destroyed then return end

        if input.KeyCode == self.Keybind then
            self:SetVisible(not self.Visible)
            return
        end

        if not self.Visible then return end

        if input.KeyCode == Enum.KeyCode.Up then
            self:MoveSelection(-1)
        elseif input.KeyCode == Enum.KeyCode.Down then
            self:MoveSelection(1)
        elseif input.KeyCode == Enum.KeyCode.Left then
            self:ChangeSelected(-1)
        elseif input.KeyCode == Enum.KeyCode.Right then
            self:ChangeSelected(1)
        elseif input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter then
            self:ActivateSelected()
        elseif input.KeyCode == Enum.KeyCode.Backspace then
            self:Back()
        elseif input.KeyCode == Enum.KeyCode.Q then
            self:PreviousTab()
        elseif input.KeyCode == Enum.KeyCode.E then
            self:NextTab()
        end
    end)
end

function Menu:_updateCanvasHeight()
    local visibleRows = self.MaxVisibleItems
    local desired = self.HeaderHeight + 38 + 32 + visibleRows * self.ItemHeight + 18
    self.Root.Size = UDim2.fromOffset(self.Width, desired)
end

function Menu:CreateTab(name, icon)
    local page = setmetatable({}, Page)
    page.Menu = self
    page.Name = name or ("Tab " .. tostring(#self.Pages + 1))
    page.Icon = icon
    page.Items = {}
    page.SubMenus = {}

    page.Button = new("TextButton", {
        Parent = self.TabBar,
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(92, 28),
        Font = Enum.Font.GothamMedium,
        Text = page.Name,
        TextColor3 = self.Theme.MutedText,
        TextSize = 12,
    })
    round(page.Button, 4)

    page.Frame = new("ScrollingFrame", {
        Parent = self.Content,
        Name = page.Name,
        Size = UDim2.fromScale(1, 1),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = self.Theme.Border,
        Visible = false,
    })

    page.List = new("UIListLayout", {
        Parent = page.Frame,
        Padding = UDim.new(0, 2),
        SortOrder = Enum.SortOrder.LayoutOrder,
    })

    new("UIPadding", {
        Parent = page.Frame,
        PaddingTop = UDim.new(0, 8),
        PaddingBottom = UDim.new(0, 8),
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8),
    })

    page.Button.MouseButton1Click:Connect(function()
        self:SetTab(table.find(self.Pages, page) or 1)
    end)

    table.insert(self.Pages, page)
    if #self.Pages == 1 then
        self:SetTab(1)
    else
        self:_refreshTabs()
    end

    return page
end

function Menu:_refreshTabs()
    for i, page in ipairs(self.Pages) do
        local selected = i == self.PageIndex
        page.Frame.Visible = selected and #self.OpenStack == 0
        tween(page.Button, TweenInfo.new(0.12), {
            BackgroundTransparency = selected and 0 or 1,
            BackgroundColor3 = self.Theme.ItemHover,
            TextColor3 = selected and self.Theme.Text or self.Theme.MutedText,
        })
    end
end

function Menu:SetTab(index)
    if #self.Pages == 0 then return end
    self.PageIndex = clamp(index, 1, #self.Pages)
    self.OpenStack = {}
    self.SelectedIndex = 1
    self:_refreshTabs()
    self:_renderSelection()
end

function Menu:NextTab()
    if #self.OpenStack > 0 or #self.Pages == 0 then return end
    local i = self.PageIndex + 1
    if i > #self.Pages then i = 1 end
    self:SetTab(i)
end

function Menu:PreviousTab()
    if #self.OpenStack > 0 or #self.Pages == 0 then return end
    local i = self.PageIndex - 1
    if i < 1 then i = #self.Pages end
    self:SetTab(i)
end

function Menu:GetCurrentContainer()
    if #self.OpenStack > 0 then
        return self.OpenStack[#self.OpenStack]
    end
    return self.Pages[self.PageIndex]
end

function Menu:GetCurrentItems()
    local container = self:GetCurrentContainer()
    return container and container.Items or {}
end

function Menu:MoveSelection(direction)
    local items = self:GetCurrentItems()
    if #items == 0 then return end
    self.SelectedIndex += direction
    if self.SelectedIndex < 1 then self.SelectedIndex = #items end
    if self.SelectedIndex > #items then self.SelectedIndex = 1 end
    self:_renderSelection()
end

function Menu:ChangeSelected(direction)
    local item = self:GetCurrentItems()[self.SelectedIndex]
    if item and item.Change then
        item:Change(direction)
    end
end

function Menu:ActivateSelected()
    local item = self:GetCurrentItems()[self.SelectedIndex]
    if item and item.Activate then
        item:Activate()
    end
end

function Menu:_renderSelection()
    local items = self:GetCurrentItems()
    for i, item in ipairs(items) do
        item:SetSelected(i == self.SelectedIndex)
    end

    self.Counter.Text = string.format("%d / %d", #items == 0 and 0 or self.SelectedIndex, #items)

    local selected = items[self.SelectedIndex]
    if selected and selected.Frame and selected.Frame.Parent and selected.Frame.Parent:IsA("ScrollingFrame") then
        local sf = selected.Frame.Parent
        local y = selected.Frame.AbsolutePosition.Y - sf.AbsolutePosition.Y + sf.CanvasPosition.Y
        local top = sf.CanvasPosition.Y
        local bottom = top + sf.AbsoluteWindowSize.Y
        if y < top then
            sf.CanvasPosition = Vector2.new(0, math.max(0, y - 8))
        elseif y + self.ItemHeight > bottom then
            sf.CanvasPosition = Vector2.new(0, math.max(0, y - sf.AbsoluteWindowSize.Y + self.ItemHeight + 8))
        end
    end
end

function Menu:OpenSubMenu(submenu)
    local current = self:GetCurrentContainer()
    if current and current.Frame then current.Frame.Visible = false end
    table.insert(self.OpenStack, submenu)
    submenu.Frame.Visible = true
    self.SelectedIndex = 1
    self:_renderSelection()
end

function Menu:Back()
    if #self.OpenStack > 0 then
        local current = self.OpenStack[#self.OpenStack]
        current.Frame.Visible = false
        table.remove(self.OpenStack, #self.OpenStack)
        local target = self:GetCurrentContainer()
        if target and target.Frame then target.Frame.Visible = true end
        self.SelectedIndex = 1
        self:_renderSelection()
    else
        self:SetVisible(false)
    end
end

function Menu:SetVisible(state)
    self.Visible = state and true or false
    self.Root.Visible = self.Visible
end

function Menu:Toggle()
    self:SetVisible(not self.Visible)
end

function Menu:SetTitle(text)
    self.Title = tostring(text)
    self.TitleLabel.Text = self.Title
end

function Menu:Destroy()
    self.Destroyed = true
    if self.InputConnection then self.InputConnection:Disconnect() end
    if self.Gui then self.Gui:Destroy() end
end

function Menu:Notify(config)
    config = typeof(config) == "table" and config or { Text = tostring(config) }
    local duration = config.Duration or 3

    if not self.NotificationHolder then
        self.NotificationHolder = new("Frame", {
            Parent = self.Gui,
            AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.new(1, -24, 1, -24),
            Size = UDim2.fromOffset(320, 400),
            BackgroundTransparency = 1,
        })
        new("UIListLayout", {
            Parent = self.NotificationHolder,
            FillDirection = Enum.FillDirection.Vertical,
            VerticalAlignment = Enum.VerticalAlignment.Bottom,
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
            Padding = UDim.new(0, 8),
        })
    end

    local card = new("Frame", {
        Parent = self.NotificationHolder,
        Size = UDim2.fromOffset(300, 72),
        BackgroundColor3 = self.Theme.BackgroundSecondary,
        BackgroundTransparency = 0.02,
        BorderSizePixel = 0,
    })
    round(card, 6)
    stroke(card, self.Theme.Border, 0.3, 1)

    new("TextLabel", {
        Parent = card,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(12, 8),
        Size = UDim2.new(1, -24, 0, 20),
        Font = Enum.Font.GothamBold,
        Text = config.Title or "VanityUI",
        TextColor3 = self.Theme.Text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    new("TextLabel", {
        Parent = card,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(12, 28),
        Size = UDim2.new(1, -24, 0, 34),
        Font = Enum.Font.Gotham,
        Text = config.Text or "Notification",
        TextWrapped = true,
        TextColor3 = self.Theme.MutedText,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
    })

    card.BackgroundTransparency = 1
    tween(card, TweenInfo.new(0.16), { BackgroundTransparency = 0.02 })

    task.delay(duration, function()
        if card and card.Parent then
            tween(card, TweenInfo.new(0.18), { BackgroundTransparency = 1 })
            task.wait(0.2)
            if card then card:Destroy() end
        end
    end)
end

local function createContainerFrame(menu, parent, name)
    local frame = new("ScrollingFrame", {
        Parent = parent,
        Name = name,
        Size = UDim2.fromScale(1, 1),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = menu.Theme.Border,
        Visible = false,
    })
    new("UIListLayout", {
        Parent = frame,
        Padding = UDim.new(0, 2),
        SortOrder = Enum.SortOrder.LayoutOrder,
    })
    new("UIPadding", {
        Parent = frame,
        PaddingTop = UDim.new(0, 8),
        PaddingBottom = UDim.new(0, 8),
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8),
    })
    return frame
end

local function makeItem(container, kind, label, callback)
    local menu = container.Menu
    local item = setmetatable({}, Item)
    item.Menu = menu
    item.Container = container
    item.Kind = kind
    item.Label = label or kind
    item.Callback = callback
    item.Selected = false

    item.Frame = new("TextButton", {
        Parent = container.Frame,
        AutoButtonColor = false,
        Size = UDim2.new(1, 0, 0, menu.ItemHeight - 2),
        BackgroundColor3 = menu.Theme.Item,
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        Text = "",
    })
    round(item.Frame, 3)

    item.NameLabel = new("TextLabel", {
        Parent = item.Frame,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(0.62, -10, 1, 0),
        Font = Enum.Font.GothamMedium,
        Text = item.Label,
        TextColor3 = menu.Theme.Text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    item.ValueLabel = new("TextLabel", {
        Parent = item.Frame,
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -10, 0, 0),
        Size = UDim2.new(0.36, 0, 1, 0),
        Font = Enum.Font.Gotham,
        Text = "",
        TextColor3 = menu.Theme.MutedText,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Right,
    })

    item.Frame.MouseEnter:Connect(function()
        local idx = table.find(container.Items, item)
        if idx then
            menu.SelectedIndex = idx
            menu:_renderSelection()
        end
    end)

    item.Frame.MouseButton1Click:Connect(function()
        local idx = table.find(container.Items, item)
        if idx then menu.SelectedIndex = idx end
        item:Activate()
        menu:_renderSelection()
    end)

    table.insert(container.Items, item)
    menu:_renderSelection()
    return item
end

function Item:SetSelected(state)
    self.Selected = state
    local menu = self.Menu
    tween(self.Frame, TweenInfo.new(0.08), {
        BackgroundColor3 = state and menu.Theme.Selected or menu.Theme.Item,
        BackgroundTransparency = state and 0 or 0.1,
    })
    self.NameLabel.TextColor3 = state and menu.Theme.SelectedText or menu.Theme.Text
    self.ValueLabel.TextColor3 = state and menu.Theme.SelectedText or menu.Theme.MutedText
end

function Page:Section(text)
    local label = new("TextLabel", {
        Parent = self.Frame,
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Text = string.upper(text or "SECTION"),
        TextColor3 = self.Menu.Theme.MutedText,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    return label
end

function SubMenu:Section(text)
    return Page.Section(self, text)
end

local function addButton(container, text, callback)
    local item = makeItem(container, "Button", text, callback)
    item.ValueLabel.Text = "›"
    function item:Activate()
        safeCall(self.Callback)
    end
    return item
end

function Page:Button(text, callback) return addButton(self, text, callback) end
function SubMenu:Button(text, callback) return addButton(self, text, callback) end

local function addToggle(container, text, default, callback)
    local item = makeItem(container, "Toggle", text, callback)
    item.Value = default and true or false
    function item:Refresh()
        self.ValueLabel.Text = self.Value and "ON" or "OFF"
    end
    function item:Set(value, fire)
        self.Value = value and true or false
        self:Refresh()
        if fire ~= false then safeCall(self.Callback, self.Value) end
    end
    function item:Activate() self:Set(not self.Value) end
    function item:Change() self:Set(not self.Value) end
    item:Refresh()
    return item
end

function Page:Toggle(text, default, callback) return addToggle(self, text, default, callback) end
function SubMenu:Toggle(text, default, callback) return addToggle(self, text, default, callback) end

local function addSlider(container, text, minValue, maxValue, default, step, callback)
    local item = makeItem(container, "Slider", text, callback)
    item.Min = minValue or 0
    item.Max = maxValue or 100
    item.Step = step or 1
    item.Value = clamp(default or item.Min, item.Min, item.Max)
    function item:Refresh()
        self.ValueLabel.Text = tostring(self.Value)
    end
    function item:Set(v, fire)
        local steps = math.floor(((v - self.Min) / self.Step) + 0.5)
        self.Value = clamp(self.Min + steps * self.Step, self.Min, self.Max)
        self:Refresh()
        if fire ~= false then safeCall(self.Callback, self.Value) end
    end
    function item:Change(dir) self:Set(self.Value + self.Step * dir) end
    function item:Activate() safeCall(self.Callback, self.Value) end
    item:Refresh()
    return item
end

function Page:Slider(text, minValue, maxValue, default, step, callback)
    return addSlider(self, text, minValue, maxValue, default, step, callback)
end
function SubMenu:Slider(text, minValue, maxValue, default, step, callback)
    return addSlider(self, text, minValue, maxValue, default, step, callback)
end

local function addList(container, text, values, defaultIndex, callback)
    local item = makeItem(container, "List", text, callback)
    item.Values = values or {"None"}
    item.Index = clamp(defaultIndex or 1, 1, math.max(1, #item.Values))
    function item:Refresh()
        self.ValueLabel.Text = "‹ " .. tostring(self.Values[self.Index]) .. " ›"
    end
    function item:SetIndex(index, fire)
        if #self.Values == 0 then return end
        if index < 1 then index = #self.Values end
        if index > #self.Values then index = 1 end
        self.Index = index
        self:Refresh()
        if fire ~= false then safeCall(self.Callback, self.Values[self.Index], self.Index) end
    end
    function item:Change(dir) self:SetIndex(self.Index + dir) end
    function item:Activate() safeCall(self.Callback, self.Values[self.Index], self.Index) end
    item:Refresh()
    return item
end

function Page:List(text, values, defaultIndex, callback) return addList(self, text, values, defaultIndex, callback) end
function SubMenu:List(text, values, defaultIndex, callback) return addList(self, text, values, defaultIndex, callback) end

local function addKeybind(container, text, defaultKey, callback)
    local item = makeItem(container, "Keybind", text, callback)
    item.Key = defaultKey or Enum.KeyCode.Unknown
    item.Capturing = false
    function item:Refresh()
        self.ValueLabel.Text = self.Capturing and "..." or self.Key.Name
    end
    function item:Set(key, fire)
        self.Key = key
        self.Capturing = false
        self:Refresh()
        if fire ~= false then safeCall(self.Callback, key) end
    end
    function item:Activate()
        if self.Capturing then return end
        self.Capturing = true
        self:Refresh()
        local conn
        conn = UserInputService.InputBegan:Connect(function(input, processed)
            if processed then return end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                conn:Disconnect()
                self:Set(input.KeyCode)
            end
        end)
    end
    item:Refresh()
    return item
end

function Page:Keybind(text, defaultKey, callback) return addKeybind(self, text, defaultKey, callback) end
function SubMenu:Keybind(text, defaultKey, callback) return addKeybind(self, text, defaultKey, callback) end

local function addTextbox(container, text, default, callback)
    local item = makeItem(container, "Textbox", text, callback)
    item.Value = tostring(default or "")
    item.ValueLabel.Text = item.Value ~= "" and item.Value or "type..."
    function item:Activate()
        self.ValueLabel.Visible = false
        local box = new("TextBox", {
            Parent = self.Frame,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -8, 0.5, 0),
            Size = UDim2.new(0.42, 0, 0, 24),
            BackgroundColor3 = self.Menu.Theme.BackgroundSecondary,
            BorderSizePixel = 0,
            Font = Enum.Font.Gotham,
            Text = self.Value,
            PlaceholderText = "type...",
            TextColor3 = self.Menu.Theme.Text,
            PlaceholderColor3 = self.Menu.Theme.MutedText,
            TextSize = 11,
            ClearTextOnFocus = false,
        })
        round(box, 3)
        box:CaptureFocus()
        local done
        done = box.FocusLost:Connect(function(enterPressed)
            done:Disconnect()
            self.Value = box.Text
            self.ValueLabel.Text = self.Value ~= "" and self.Value or "type..."
            self.ValueLabel.Visible = true
            box:Destroy()
            safeCall(self.Callback, self.Value, enterPressed)
        end)
    end
    return item
end

function Page:Textbox(text, default, callback) return addTextbox(self, text, default, callback) end
function SubMenu:Textbox(text, default, callback) return addTextbox(self, text, default, callback) end

local function addSubMenu(container, text)
    local menu = container.Menu
    local sub = setmetatable({}, SubMenu)
    sub.Menu = menu
    sub.Parent = container
    sub.Name = text
    sub.Items = {}
    sub.Frame = createContainerFrame(menu, menu.Content, "SubMenu_" .. text)

    local item = makeItem(container, "SubMenu", text)
    item.ValueLabel.Text = "›"
    function item:Activate()
        menu:OpenSubMenu(sub)
    end

    sub.TriggerItem = item
    table.insert(container.SubMenus or {}, sub)
    return sub
end

function Page:SubMenu(text) return addSubMenu(self, text) end
function SubMenu:SubMenu(text)
    self.SubMenus = self.SubMenus or {}
    return addSubMenu(self, text)
end

function Page:Label(text, rightText)
    local item = makeItem(self, "Label", text)
    item.ValueLabel.Text = rightText or ""
    function item:Activate() end
    function item:Change() end
    return item
end

function SubMenu:Label(text, rightText)
    return Page.Label(self, text, rightText)
end

function Page:Separator()
    local sep = new("Frame", {
        Parent = self.Frame,
        Size = UDim2.new(1, 0, 0, 6),
        BackgroundTransparency = 1,
    })
    new("Frame", {
        Parent = sep,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 4, 0.5, 0),
        Size = UDim2.new(1, -8, 0, 1),
        BackgroundColor3 = self.Menu.Theme.Border,
        BackgroundTransparency = 0.55,
        BorderSizePixel = 0,
    })
    return sep
end

function SubMenu:Separator()
    return Page.Separator(self)
end

return setmetatable({}, VanityUI)
