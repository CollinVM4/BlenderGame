--!strict
local TweenService = game:GetService("TweenService")
local Style = require(game:GetService("ReplicatedStorage").Shared.Constants.DialogueTextStyle)
export type Surface = {
    Gui: ScreenGui,
    Label: TextLabel,
    Show: (string) -> (),
    Exit: () -> (),
    Hide: () -> (),
    Destroy: () -> (),
}
local Banner = {}
local priority = Instance.new("BindableEvent")
local globalActive = false
Banner.PriorityChanged = priority.Event
function Banner.IsGlobalActive(): boolean
    return globalActive
end
function Banner.SetGlobalActive(active: boolean)
    if globalActive ~= active then
        globalActive = active
        priority:Fire()
    end
end
function Banner.Create(playerGui: PlayerGui, name: string): Surface
    local gui = Instance.new("ScreenGui")
    gui.Name = name
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = false
    gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
    gui.DisplayOrder = 20
    local label = Instance.new("TextLabel")
    label.Name = "Announcement"
    label.AnchorPoint = Vector2.new(0.5, 0)
    local resting = UDim2.fromScale(0.5, 0.065)
    label.Position = resting
    label.Size = UDim2.new(0.92, 0, 0, 104)
    label.BackgroundTransparency = 1
    Style.Apply(label, 32)
    label.TextWrapped, label.TextScaled, label.RichText = true, true, true
    label.Visible = false
    label.Parent = gui
    local width = Instance.new("UISizeConstraint")
    width.MaxSize = Vector2.new(780, 104)
    width.Parent = label
    local textSize = Instance.new("UITextSizeConstraint")
    textSize.MinTextSize, textSize.MaxTextSize = 18, 32
    textSize.Parent = label
    local stroke = Style.Outline(label)
    local scale = Instance.new("UIScale")
    scale.Parent = label
    gui.Parent = playerGui
    local tweens: { Tween } = {}
    local function cancel()
        for _, tween in tweens do
            tween:Cancel()
        end
        table.clear(tweens)
    end
    local function tween(object: Instance, info: TweenInfo, properties: any)
        local animation = TweenService:Create(object, info, properties)
        table.insert(tweens, animation)
        animation:Play()
    end
    return {
        Gui = gui,
        Label = label,
        Show = function(text: string)
            cancel()
            label.Text = text
            label.Position = resting - UDim2.fromOffset(0, 14)
            label.TextTransparency, stroke.Transparency, scale.Scale = 1, 1, 0.93
            label.Visible = true
            local enter = TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
            tween(label, enter, { Position = resting, TextTransparency = 0 })
            tween(scale, enter, { Scale = 1 })
            tween(stroke, TweenInfo.new(0.16), { Transparency = 0 })
        end,
        Exit = function()
            cancel()
            local exit = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            tween(label, exit, { Position = resting - UDim2.fromOffset(0, 10), TextTransparency = 1 })
            tween(stroke, exit, { Transparency = 1 })
        end,
        Hide = function()
            cancel()
            label.Visible = false
        end,
        Destroy = function()
            cancel()
            gui:Destroy()
        end,
    }
end
return Banner
