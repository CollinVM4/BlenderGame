--!strict
local Display = require(script.Parent.UpgradeDisplay)
local Gui = {}
local ink = Color3.fromRGB(245, 248, 255)
local muted = Color3.fromRGB(186, 198, 216)
local accent = Color3.fromRGB(57, 119, 83)

local function round(object: GuiObject)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = object
end

local function label(parent: Instance, name: string, text: string, size: number): TextLabel
    local result = Instance.new("TextLabel")
    result.Name = name
    result.BackgroundTransparency = 1
    result.Size = UDim2.new(1, 0, 0, size + 8)
    result.Font = Enum.Font.GothamBold
    result.TextSize = size
    result.TextColor3 = ink
    result.TextXAlignment = Enum.TextXAlignment.Left
    result.Text = text
    result.Parent = parent
    return result
end

local function button(parent: Instance, name: string, text: string): TextButton
    local result = Instance.new("TextButton")
    result.Name = name
    result.Size = UDim2.new(1, 0, 0, 36)
    result.BackgroundColor3 = accent
    result.Font = Enum.Font.GothamBold
    result.TextColor3 = ink
    result.TextSize = 14
    result.Text = text
    result.AutoButtonColor = true
    round(result)
    result.Parent = parent
    return result
end

local function stack(parent: Instance, padding: number)
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, padding)
    layout.Parent = parent
end

local function pad(parent: Instance, amount: number)
    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, amount)
    padding.PaddingBottom = UDim.new(0, amount)
    padding.PaddingLeft = UDim.new(0, amount)
    padding.PaddingRight = UDim.new(0, amount)
    padding.Parent = parent
end

function Gui.Create(playerGui: PlayerGui)
    local screen = Instance.new("ScreenGui")
    screen.Name = "UpgradesGui"
    screen.ResetOnSpawn = false
    screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screen.DisplayOrder = 10

    local hud = Instance.new("Frame")
    hud.Name = "CashHud"
    hud.AnchorPoint = Vector2.new(1, 0)
    hud.Position = UDim2.new(1, -16, 0, 12)
    hud.Size = UDim2.fromOffset(174, 96)
    hud.BackgroundColor3 = Color3.fromRGB(28, 36, 50)
    round(hud)
    pad(hud, 10)
    stack(hud, 4)
    hud.Parent = screen
    local cash = label(hud, "Cash", "$ —", 24)
    cash.TextScaled = true
    local cashTextBounds = Instance.new("UITextSizeConstraint")
    cashTextBounds.MinTextSize = 12
    cashTextBounds.MaxTextSize = 24
    cashTextBounds.Parent = cash
    cash.LayoutOrder = 1
    local toggle = button(hud, "Toggle", "UPGRADES")
    toggle.LayoutOrder = 2

    local panel = Instance.new("Frame")
    panel.Name = "Panel"
    panel.AnchorPoint = Vector2.new(1, 0)
    panel.Position = UDim2.new(1, -16, 0, 120)
    panel.Size = UDim2.new(1, -32, 1, -136)
    panel.BackgroundColor3 = Color3.fromRGB(28, 36, 50)
    panel.Visible = false
    round(panel)
    local bounds = Instance.new("UISizeConstraint")
    bounds.MaxSize = Vector2.new(352, 490)
    bounds.Parent = panel
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(83, 100, 120)
    stroke.Transparency = 0.4
    stroke.Parent = panel
    pad(panel, 12)
    panel.Parent = screen
    local title = label(panel, "Title", "UPGRADES", 22)
    title.Size = UDim2.new(1, -44, 0, 36)
    local close = button(panel, "Close", "X")
    close.AnchorPoint = Vector2.new(1, 0)
    close.Position = UDim2.fromScale(1, 0)
    close.Size = UDim2.fromOffset(36, 36)

    local list = Instance.new("ScrollingFrame")
    list.Name = "Rows"
    list.Position = UDim2.fromOffset(0, 46)
    list.Size = UDim2.new(1, 0, 1, -46)
    list.BackgroundTransparency = 1
    list.BorderSizePixel = 0
    list.ScrollBarThickness = 4
    list.ScrollingDirection = Enum.ScrollingDirection.Y
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.CanvasSize = UDim2.new()
    stack(list, 10)
    list.Parent = panel
    local rows: { [string]: { Level: TextLabel, Stat: TextLabel, Purchase: TextButton } } = {}
    for index, track in Display.Tracks do
        local row = Instance.new("Frame")
        row.Name = track.Id
        row.LayoutOrder = index
        row.Size = UDim2.new(1, -8, 0, 132)
        row.BackgroundColor3 = Color3.fromRGB(41, 52, 70)
        round(row)
        pad(row, 10)
        stack(row, 2)
        row.Parent = list
        local name = label(row, "Name", track.Name, 15)
        name.LayoutOrder = 1
        local level = label(row, "Level", "Loading…", 12)
        level.TextColor3 = muted
        level.LayoutOrder = 2
        local stat = label(row, "Stat", "—", 18)
        stat.LayoutOrder = 3
        local purchase = button(row, "Purchase", "LOADING…")
        purchase.LayoutOrder = 4
        rows[track.Id] = { Level = level, Stat = stat, Purchase = purchase }
    end
    toggle.Activated:Connect(function()
        panel.Visible = not panel.Visible
    end)
    close.Activated:Connect(function()
        panel.Visible = false
    end)
    screen.Parent = playerGui
    return { Screen = screen, Cash = cash, Rows = rows }
end

return Gui
