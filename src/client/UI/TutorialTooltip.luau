--!strict
local TweenService = game:GetService("TweenService")
local Style = require(game:GetService("ReplicatedStorage").Shared.Constants.DialogueTextStyle)
local Tooltip = {}

function Tooltip.Show(playerGui: PlayerGui, name: string, text: string)
    local gui = Instance.new("ScreenGui")
    gui.Name = name
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 15
    local card = Instance.new("CanvasGroup")
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.fromScale(0.5, 0.72)
    card.Size = UDim2.fromOffset(320, 78)
    card.BackgroundColor3 = Style.Dark
    card.BackgroundTransparency = 0.18
    card.GroupTransparency = 1
    card.BorderSizePixel = 0
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)
    card.Parent = gui
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, -20, 1, 0)
    label.Position = UDim2.fromOffset(10, 0)
    label.RichText = true
    label.Text = text
    Style.Apply(label, 20)
    label.TextWrapped = true
    label.Parent = card
    gui.Parent = playerGui
    -- One composited fade includes the background, lettering AND UIStroke.
    -- Fading TextTransparency alone leaves the shared opaque outline behind.
    local entrance = TweenService:Create(card, TweenInfo.new(0.18), { GroupTransparency = 0 })
    local exit: Tween? = nil
    gui.Destroying:Connect(function()
        entrance:Cancel()
        if exit then
            exit:Cancel()
        end
    end)
    entrance:Play()
    task.delay(4.3, function()
        if not gui.Parent then
            return
        end
        local tween = TweenService:Create(card, TweenInfo.new(0.45), { GroupTransparency = 1 })
        exit = tween
        tween.Completed:Once(function()
            gui:Destroy()
        end)
        tween:Play()
    end)
end

return Tooltip
