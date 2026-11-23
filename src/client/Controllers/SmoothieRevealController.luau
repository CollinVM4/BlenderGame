--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Summary = require(Shared.SmoothieSummary)
local Ingredients = require(Shared.Constants.Ingredients)
local Style = require(Shared.Constants.DialogueTextStyle)
local Audio = require(Shared.Constants.GameplayAudio)
local Money = require(Shared.MoneyFormat)
local Viewport = require(script.Parent.Parent.UI.IngredientViewport)

local Controller = {}
local active: ScreenGui? = nil

local function clear()
    if active then
        active:Destroy()
        active = nil
    end
end

local function label(
    parent: GuiObject,
    content: string,
    y: number,
    height: number,
    fontSize: number,
    color: Color3?
): TextLabel
    local text = Instance.new("TextLabel")
    text.BackgroundTransparency = 1
    text.Position = UDim2.fromScale(0.04, y)
    text.Size = UDim2.fromScale(0.92, height)
    text.Text = content
    Style.Apply(text, fontSize)
    text.TextColor3 = color or Style.White
    text.TextScaled = true
    local limit = Instance.new("UITextSizeConstraint")
    limit.MaxTextSize = fontSize
    limit.Parent = text
    text.Parent = parent
    return text
end

local function show(playerGui: PlayerGui, details: Summary.Details)
    clear()
    local gui = Instance.new("ScreenGui")
    gui.Name = "SmoothieReveal"
    gui.ResetOnSpawn = true
    gui.DisplayOrder = 12
    active = gui

    local panel = Instance.new("Frame")
    panel.AnchorPoint = Vector2.new(0.5, 0)
    panel.Position = UDim2.fromScale(0.5, 0.09)
    panel.Size = UDim2.new(0.86, 0, 0.51, 0)
    panel.BackgroundColor3 = Style.Dark
    panel.BackgroundTransparency = 0.12
    panel.Parent = gui
    local constraint = Instance.new("UISizeConstraint")
    constraint.MaxSize = Vector2.new(332, 222)
    constraint.Parent = panel
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 16)
    corner.Parent = panel
    local border = Instance.new("UIStroke")
    border.Color = details.Tint:Lerp(Color3.new(1, 1, 1), 0.28)
    border.Thickness = 2
    border.Parent = panel
    local scale = Instance.new("UIScale")
    scale.Scale = 0.92
    scale.Parent = panel

    label(panel, "Blend value", 0.035, 0.09, 15)
    local value = label(panel, "$0", 0.12, 0.17, 43, Style.Gold)
    local beat = label(panel, "", 0.284, 0.10, 17)
    local colors = label(panel, "Order colors: " .. details.Colors, 0.40, 0.10, 17)
    colors.Position = UDim2.fromScale(0.12, 0.40)
    colors.Size = UDim2.fromScale(0.84, 0.10)
    colors.TextXAlignment = Enum.TextXAlignment.Left
    local swatch = Instance.new("Frame")
    swatch.AnchorPoint = Vector2.new(0, 0.5)
    swatch.Position = UDim2.fromScale(0.06, 0.45)
    swatch.Size = UDim2.fromOffset(12, 12)
    swatch.BackgroundColor3 = details.Tint
    swatch.BorderSizePixel = 0
    swatch.Parent = panel
    local swatchCorner = Instance.new("UICorner")
    swatchCorner.CornerRadius = UDim.new(1, 0)
    swatchCorner.Parent = swatch
    label(panel, details.Description, 0.51, 0.10, 15)

    for index, id in details.Ingredients do
        local slot = Instance.new("Frame")
        slot.BackgroundTransparency = 1
        slot.Position = UDim2.fromScale(0.04 + (index - 1) * 0.31, 0.62)
        slot.Size = UDim2.fromScale(0.30, 0.35)
        slot.Parent = panel
        local image = Instance.new("ImageLabel")
        image.BackgroundTransparency = 1
        image.Size = UDim2.fromScale(1, 0.68)
        image.Parent = slot
        local definition = Ingredients[id]
        Viewport.Create(image, if definition then definition.Id else id)
        label(slot, if definition then definition.DisplayName or id else id, 0.65, 0.35, 14)
    end

    local tick = Instance.new("Sound")
    tick.SoundId, tick.Volume = Audio.IngredientPickupSoundId, 0.28
    tick.Parent = gui
    gui.Parent = playerGui
    local entrance = TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = 1 })
    entrance:Play()

    local function playTick(pitch: number)
        tick:Stop()
        tick.PlaybackSpeed = pitch
        tick.TimePosition = 0
        tick:Play()
    end

    task.spawn(function()
        local total = 0
        local function count(amount: number, duration: number, heading: string)
            if amount <= 0 or active ~= gui or not gui.Parent then
                return
            end
            beat.Text = heading
            local elapsed, lastTick = 0, -1
            repeat
                local progress = math.min(elapsed / duration, 1)
                value.Text = Money.Full(math.round(total + amount * progress))
                local step = math.floor(progress * 4)
                if step ~= lastTick then
                    playTick(0.95 + step * 0.10)
                    lastTick = step
                end
                if progress == 1 then
                    break
                end
                elapsed += RunService.Heartbeat:Wait()
            until active ~= gui or not gui.Parent
            total += amount
        end
        local modifiers = {}
        count(details.BaseValue, 0.42, "Base value")
        if details.RipenessValue > 0 then
            local text = "Ripeness +" .. Money.Full(math.round(details.RipenessValue))
            table.insert(modifiers, text)
            count(details.RipenessValue, 0.30, text)
        end
        if details.MysteryValue > 0 then
            local text = "Mystery +" .. Money.Full(math.round(details.MysteryValue))
            table.insert(modifiers, text)
            count(details.MysteryValue, 0.34, "Mystery ingredients +" .. Money.Full(math.round(details.MysteryValue)))
        end
        if active ~= gui or not gui.Parent then
            return
        end
        value.Text = Money.Full(math.round(details.Value))
        beat.Text = table.concat(modifiers, "  •  ")
        local pop = Instance.new("UIScale")
        pop.Scale = 1.12
        pop.Parent = value
        TweenService:Create(pop, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = 1 }):Play()
        task.wait(1.75)
        if active == gui and gui.Parent then
            local exit = TweenService:Create(panel, TweenInfo.new(0.2), { Position = UDim2.fromScale(0.5, -0.55) })
            exit:Play()
            exit.Completed:Wait()
            if active == gui then
                clear()
            end
        end
    end)
end

function Controller.Init()
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
    player.CharacterRemoving:Connect(clear)
    local remote = Shared.Events:WaitForChild("SmoothieDispensed") :: RemoteEvent
    remote.OnClientEvent:Connect(function(details: Summary.Details)
        show(playerGui, details)
    end)
end

return Controller
