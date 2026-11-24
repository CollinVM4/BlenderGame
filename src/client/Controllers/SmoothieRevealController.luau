--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Summary = require(Shared.SmoothieSummary)
local Ingredients = require(Shared.Constants.Ingredients)
local Style = require(Shared.Constants.DialogueTextStyle)
local ComboStyle = require(Shared.Constants.SmoothieComboStyle)
local Audio = require(Shared.Constants.GameplayAudio)
local Money = require(Shared.MoneyFormat)
local Viewport = require(script.Parent.Parent.UI.IngredientViewport)
local CupReveal = require(script.Parent.Parent.UI.SmoothieCupReveal)

local Controller = {}
local active: ScreenGui? = nil
local palette = {
    Ripe = Color3.fromRGB(152, 255, 107),
    Mystery = Color3.fromRGB(235, 144, 255),
    Stolen = Color3.fromRGB(255, 128, 111),
}

local function burst(panel: Frame, color: Color3)
    for index = 1, 8 do
        local angle = (index / 8) * 2 * math.pi
        local chip = Instance.new("Frame")
        chip.AnchorPoint = Vector2.new(0.5, 0.5)
        chip.Position = UDim2.fromScale(0.5, 0.25)
        chip.Size = UDim2.fromOffset(8, 8)
        chip.Rotation = index * 33
        chip.BackgroundColor3 = if index % 2 == 0 then color else Style.Gold
        chip.BorderSizePixel = 0
        chip.Parent = panel
        TweenService:Create(chip, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = UDim2.fromScale(0.5 + math.cos(angle) * 0.38, 0.25 + math.sin(angle) * 0.25),
            BackgroundTransparency = 1,
            Rotation = chip.Rotation + 95,
        }):Play()
        task.delay(0.35, function()
            chip:Destroy()
        end)
    end
end

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
    panel.Position = UDim2.fromScale(0.5, 0.12)
    panel.Size = UDim2.fromScale(0.89, 0.57)
    panel.BackgroundColor3 = Color3.new(0, 0, 0)
    panel.BackgroundTransparency = 0.35
    panel.Parent = gui
    local constraint = Instance.new("UISizeConstraint")
    constraint.MaxSize = Vector2.new(418, 268)
    constraint.Parent = panel
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 16)
    corner.Parent = panel
    local border = Instance.new("UIStroke")
    border.Color = details.Tint:Lerp(Style.White, 0.35)
    border.Transparency = 0.45
    border.Thickness = 2
    border.Parent = panel
    local scale = Instance.new("UIScale")
    scale.Scale = 0.92
    scale.Parent = panel

    local detailsPanel = Instance.new("Frame")
    detailsPanel.Name = "BlendDetails"
    detailsPanel.BackgroundTransparency = 1
    detailsPanel.Size = UDim2.fromScale(1, 1)
    detailsPanel.Parent = panel
    local ingredientScales: { UIScale } = {}
    label(detailsPanel, "BLEND VALUE", 0.025, 0.08, 19)
    local value = label(detailsPanel, "$0", 0.095, 0.235, 64, Style.Gold)
    value.ZIndex = 3
    Style.Outline(value).Thickness = 4.5
    local valueScale = Instance.new("UIScale")
    valueScale.Parent = value
    local beat = label(detailsPanel, "", 0.32, 0.12, 25)
    beat.ZIndex = 3
    Style.Outline(beat).Thickness = 3.5
    local categoryText = if #details.Categories > 0 then table.concat(details.Categories, ", ") else "Mixed blend"
    local categories = label(detailsPanel, "Categories: " .. categoryText, 0.44, 0.20, 18)
    categories.Position = UDim2.fromScale(0.12, 0.44)
    categories.Size = UDim2.fromScale(0.84, 0.20)
    categories.TextXAlignment = Enum.TextXAlignment.Left
    categories.TextWrapped = true
    local swatch = Instance.new("Frame")
    swatch.AnchorPoint = Vector2.new(0, 0.5)
    swatch.Position = UDim2.fromScale(0.06, 0.54)
    swatch.Size = UDim2.fromOffset(12, 12)
    swatch.BackgroundColor3 = details.Tint
    swatch.BorderSizePixel = 0
    swatch.Parent = detailsPanel
    local swatchCorner = Instance.new("UICorner")
    swatchCorner.CornerRadius = UDim.new(1, 0)
    swatchCorner.Parent = swatch

    for index, id in details.Ingredients do
        local slot = Instance.new("Frame")
        slot.BackgroundTransparency = 1
        slot.Position = UDim2.fromScale(0.04 + (index - 1) * 0.31, 0.66)
        slot.Size = UDim2.fromScale(0.30, 0.31)
        slot.Parent = detailsPanel
        local image = Instance.new("ImageLabel")
        image.BackgroundTransparency = 1
        image.Size = UDim2.fromScale(1, 0.68)
        image.Parent = slot
        local definition = Ingredients[id]
        Viewport.Create(image, if definition then definition.Id else id)
        label(slot, if definition then definition.DisplayName or id else id, 0.65, 0.35, 16)
        local ingredientScale = Instance.new("UIScale")
        ingredientScale.Scale = 0
        ingredientScale.Parent = slot
        table.insert(ingredientScales, ingredientScale)
    end

    local tick = Instance.new("Sound")
    tick.SoundId, tick.Volume = Audio.IngredientPickupSoundId, 0.28
    tick.Parent = gui
    local showcase = CupReveal.Mount(panel, details.Tint)
    detailsPanel.Visible = showcase == nil
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
        if showcase then
            playTick(0.86)
            task.wait(CupReveal.Duration)
            if active ~= gui or not gui.Parent then
                return
            end
            showcase:Destroy()
            detailsPanel.Visible = true
        end
        for index, ingredientScale in ingredientScales do
            task.delay((index - 1) * 0.07, function()
                if active == gui and gui.Parent then
                    TweenService:Create(ingredientScale, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = 1 })
                        :Play()
                end
            end)
        end
        local total = 0
        local modifiers: { string } = {}
        local pulse: Tween? = nil
        local function pop(amount: number)
            if pulse then
                pulse:Cancel()
            end
            valueScale.Scale = amount
            local tween = TweenService:Create(valueScale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 })
            pulse = tween
            tween:Play()
        end
        local function count(amount: number, heading: string, duration: number, color: Color3, modifier: boolean?)
            if amount <= 0 or active ~= gui or not gui.Parent then
                return
            end
            beat.TextColor3 = color
            value.TextColor3 = color
            if modifier then
                table.insert(modifiers, heading)
                beat.Text = heading .. "  +" .. Money.Full(math.round(amount))
                pop(1.12)
            else
                beat.Text = heading
            end
            local elapsed, lastTick = 0, -1
            repeat
                local progress = math.min(elapsed / duration, 1)
                value.Text = Money.Full(math.round(total + amount * progress))
                local step = math.floor(progress * (if modifier then 2 else 4))
                if step ~= lastTick then
                    playTick((if modifier then 1.12 else 0.92) + step * 0.12)
                    lastTick = step
                end
                if progress == 1 then
                    break
                end
                elapsed += RunService.Heartbeat:Wait()
            until active ~= gui or not gui.Parent
            total += amount
        end
        count(details.BaseValue, "BASE", 0.39, Style.Gold)
        count(details.RipenessValue, "RIPE", 0.29, palette.Ripe, true)
        count(details.MysteryValue, "MYSTERY", 0.29, palette.Mystery, true)
        local stolen = if details.StolenCount > 1 then "STOLEN ×" .. tostring(details.StolenCount) else "STOLEN"
        count(details.StolenValue, stolen, 0.29, palette.Stolen, true)
        local comboColor = details.ComboColor
        if comboColor then
            count(
                details.ColorValue,
                string.upper(comboColor) .. " ×3",
                0.31,
                ComboStyle.Colors[comboColor] or Style.White,
                true
            )
        end
        local identical = if details.ComboIngredient then Ingredients[details.ComboIngredient] else nil
        if identical then
            local name = string.upper(identical.DisplayName or identical.Id)
            count(details.IdenticalValue, name .. " ×3", 0.31, ComboStyle.Identical, true)
        end
        if active ~= gui or not gui.Parent then
            return
        end
        if #modifiers > 0 then
            burst(panel, beat.TextColor3)
        end
        value.Text = Money.Full(math.round(details.Value))
        value.TextColor3 = Style.Gold
        beat.TextColor3 = Style.White
        beat.Text = table.concat(modifiers, "  •  ")
        pop(1.19)
        task.wait(4)
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
