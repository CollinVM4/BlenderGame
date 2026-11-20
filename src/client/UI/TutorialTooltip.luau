--!strict
local UserInputService = game:GetService("UserInputService")
local Constants = game:GetService("ReplicatedStorage").Shared.Constants
local Style = require(Constants.DialogueTextStyle)
local RipenessStyle = require(Constants.RipenessPresentation)
local Text = require(script.Parent.RipenessTutorialText)

local Tooltip = {}
local READ_SECONDS = 12

local function label(parent: Frame, name: string, text: string, size: number): TextLabel
    local object = Instance.new("TextLabel")
    object.Name = name
    object.BackgroundTransparency = 1
    object.TextXAlignment = Enum.TextXAlignment.Left
    object.Text = text
    Style.Apply(object, size)
    object.TextScaled = true
    object.TextWrapped = true
    local constraint = Instance.new("UITextSizeConstraint")
    constraint.MinTextSize = 13
    constraint.MaxTextSize = size
    constraint.Parent = object
    object.Parent = parent
    return object
end

function Tooltip.Show(playerGui: PlayerGui)
    local gui = Instance.new("ScreenGui")
    gui.Name = "RipenessTutorial"
    gui.ResetOnSpawn = false
    gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
    gui.DisplayOrder = 15

    local card = Instance.new("Frame")
    card.Name = "Card"
    local touch = UserInputService.PreferredInput == Enum.PreferredInput.Touch
    -- The main tutorial uses the top on desktop and sits above the hotbar on touch.
    card.AnchorPoint = Vector2.new(0.5, if touch then 0 else 1)
    card.Position = if touch then UDim2.new(0.5, 0, 0, 12) else UDim2.fromScale(0.5, 0.8)
    card.Size = UDim2.new(1, -24, 0, 156)
    card.BackgroundColor3 = Style.Dark
    card.BackgroundTransparency = 0.06
    card.BorderSizePixel = 0
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)
    Instance.new("UISizeConstraint", card).MaxSize = Vector2.new(356, 156)
    local outline = Instance.new("UIStroke")
    outline.Color = Style.Gold
    outline.Transparency = 0.45
    outline.Parent = card
    card.Parent = gui

    local title = label(card, "Title", "RIPEN INGREDIENTS", 22)
    title.Position = UDim2.fromOffset(14, 8)
    title.Size = UDim2.new(1, -28, 0, 28)

    local body = label(card, "Instructions", Text.Rich(), 18)
    body.RichText = true
    body.Position = UDim2.fromOffset(14, 40)
    body.Size = UDim2.new(1, -28, 0, 54)

    local dot = Instance.new("Frame")
    dot.Name = "RipePip"
    dot.AnchorPoint = Vector2.new(0, 0.5)
    dot.Position = UDim2.new(0, 14, 1, -32)
    dot.Size = UDim2.fromOffset(15, 15)
    dot.BackgroundColor3 = RipenessStyle.IndicatorGold
    dot.BorderSizePixel = 0
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
    dot.Parent = card

    local legend = label(card, "RipeLegend", "Gold dot = ripe", 16)
    legend.Position = UDim2.new(0, 36, 1, -43)
    legend.Size = UDim2.new(1, -146, 0, 22)

    local button = Instance.new("TextButton")
    button.Name = "Dismiss"
    button.Text = "GOT IT"
    button.Font = Style.Font
    button.TextSize = 17
    button.TextColor3 = Style.Dark
    button.BackgroundColor3 = Style.Gold
    button.BorderSizePixel = 0
    button.AnchorPoint = Vector2.new(1, 1)
    button.Position = UDim2.new(1, -12, 1, -10)
    button.Size = UDim2.fromOffset(88, 44)
    button.Active = true
    button.Selectable = true
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)
    button.Parent = card

    local function dismiss()
        if gui.Parent then
            gui:Destroy()
        end
    end
    button.Activated:Connect(dismiss)
    gui.Parent = playerGui
    task.delay(READ_SECONDS, dismiss)
end

return Tooltip
