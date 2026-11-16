--!strict
local TweenService = game:GetService("TweenService")
local Style = require(game:GetService("ReplicatedStorage").Shared.Constants.DialogueTextStyle)
export type Surface = {
    Gui: ScreenGui,
    Label: TextLabel,
    Show: (string) -> (),
    LayoutTutorial: (boolean) -> (),
    Exit: () -> (),
    Hide: () -> (),
    Destroy: () -> (),
}
local Banner = {}
local TOUCH_HINT_HEIGHT = 54
local HOTBAR_GAP = 8
local EMPTY_HOTBAR_OFFSET = 88

local function hotbarTop(playerGui: PlayerGui, gui: ScreenGui): number?
    local root = playerGui:FindFirstChild("BlenderHotbar")
    if not root or not root:IsA("ScreenGui") or not root.Enabled then
        return nil
    end
    local safe = root:FindFirstChild("SafeArea")
    if not safe or not safe:IsA("Frame") or not safe.Visible then
        return nil
    end
    local bar = safe:FindFirstChild("Hotbar")
    if not bar or not bar:IsA("Frame") or not bar.Visible or bar.AbsoluteSize.Y <= 0 then
        return nil
    end
    local top = bar.AbsolutePosition.Y - gui.AbsolutePosition.Y
    if top >= TOUCH_HINT_HEIGHT + HOTBAR_GAP and top < gui.AbsoluteSize.Y then
        return top
    end
    return nil
end

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
    local slide: Tween? = nil
    local touchTutorial = false
    local function stopSlide()
        if slide then
            slide:Cancel()
            slide = nil
        end
    end
    local function cancel()
        stopSlide()
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
    local function slideTo(info: TweenInfo, position: UDim2)
        local animation = TweenService:Create(label, info, { Position = position })
        slide = animation
        animation:Play()
    end
    return {
        Gui = gui,
        Label = label,
        LayoutTutorial = function(touch: boolean)
            local nextResting = UDim2.fromScale(0.5, 0.12)
            local widthScale, height = 0.9, 104
            if touch then
                local size = gui.AbsoluteSize
                if touchTutorial and (size.X <= 0 or size.Y <= 0) then
                    return
                end
                local top = hotbarTop(playerGui, gui)
                nextResting = if top
                    then UDim2.new(0.5, 0, 0, top - HOTBAR_GAP)
                    else UDim2.new(0.5, 0, 1, -EMPTY_HOTBAR_OFFSET)
                widthScale, height = if size.X > size.Y then 0.56 else 0.88, TOUCH_HINT_HEIGHT
            end
            if resting ~= nextResting or touchTutorial ~= touch then
                stopSlide()
                resting, touchTutorial = nextResting, touch
                label.AnchorPoint = Vector2.new(0.5, if touch then 1 else 0)
                label.TextYAlignment = if touch then Enum.TextYAlignment.Bottom else Enum.TextYAlignment.Center
                label.Position = resting
            end
            local size = UDim2.new(widthScale, 0, 0, height)
            if label.Size ~= size then
                label.Size = size
                width.MaxSize = Vector2.new(if touch then 600 else 780, height)
                textSize.MaxTextSize = if touch then 24 else 32
            end
        end,
        Show = function(text: string)
            cancel()
            label.Text = text
            label.Position = if touchTutorial then resting else resting - UDim2.fromOffset(0, 14)
            label.TextTransparency, stroke.Transparency, scale.Scale = 1, 1, 0.93
            label.Visible = true
            local enter = TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
            if not touchTutorial then
                slideTo(enter, resting)
            end
            tween(label, enter, { TextTransparency = 0 })
            tween(scale, enter, { Scale = 1 })
            tween(stroke, TweenInfo.new(0.16), { Transparency = 0 })
        end,
        Exit = function()
            cancel()
            local exit = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            if not touchTutorial then
                slideTo(exit, resting - UDim2.fromOffset(0, 10))
            end
            tween(label, exit, { TextTransparency = 1 })
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
