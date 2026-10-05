--!strict
local Style = require(game:GetService("ReplicatedStorage").Shared.Constants.DialogueTextStyle)
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.StandIdentity)
local Input = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local UI = {}

function UI.Create(parent: Instance, save: () -> (), close: () -> ())
    local gui = Instance.new("ScreenGui")
    gui.Name, gui.ResetOnSpawn, gui.Enabled = "StandNameEditor", false, false
    gui.DisplayOrder = 30
    gui.Parent = parent
    local area = Instance.new("Frame")
    area.Name, area.BackgroundTransparency = "UsableArea", 1
    area.Size, area.Parent = UDim2.fromScale(1, 1), gui
    local panel = Instance.new("Frame")
    panel.Name = "RenameCard"
    panel.AnchorPoint = Vector2.new(0.5, 1)
    panel.Position = UDim2.new(0.5, 0, 1, -20)
    panel.Size = UDim2.new(0.9, 0, 0, 154)
    panel.BackgroundColor3 = Color3.fromRGB(25, 29, 38)
    panel.BackgroundTransparency = 0.28
    panel.BorderSizePixel = 0
    panel.Parent = area
    local scale = Instance.new("UIScale")
    scale.Parent = panel
    local size = Instance.new("UISizeConstraint")
    size.MaxSize = Vector2.new(320, 154)
    size.Parent = panel
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
    local border = Instance.new("UIStroke")
    border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    border.Color, border.Thickness, border.Transparency = Color3.fromRGB(170, 180, 198), 1, 0.7
    border.Parent = panel
    local function label(text: string, y: number): TextLabel
        local result = Instance.new("TextLabel")
        result.Size, result.Position = UDim2.new(1, -24, 0, 24), UDim2.fromOffset(12, y)
        result.BackgroundTransparency = 1
        Style.Apply(result, 18)
        Style.Outline(result).Thickness = 1
        result.Text, result.Parent = text, panel
        return result
    end
    local title = label("NAME YOUR STAND", 10)
    title.Size = UDim2.new(1, -60, 0, 24)
    local box = Instance.new("TextBox")
    box.Name = "StandName"
    box.Size, box.Position = UDim2.new(1, -24, 0, 36), UDim2.fromOffset(12, 38)
    box.BackgroundColor3 = Color3.fromRGB(244, 243, 248)
    box.BackgroundTransparency = 0.06
    box.BorderSizePixel = 0
    box.TextColor3, box.Font, box.TextSize = Style.Dark, Style.Font, 18
    box.ClearTextOnFocus, box.MultiLine = false, false
    box.Selectable = true
    box.Text, box.Parent = "", panel
    local selection = Instance.new("Frame")
    selection.Name = "InputSelection"
    selection.BackgroundTransparency, selection.BorderSizePixel = 1, 0
    selection.Size, selection.Parent = UDim2.fromScale(1, 1), box
    box.SelectionImageObject = selection
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 8)
    local function button(text: string, callback: () -> ()): TextButton
        local result = Instance.new("TextButton")
        -- Slim visual face inside a larger transparent tap/controller target.
        result.BackgroundTransparency, result.BorderSizePixel = 1, 0
        result.Size, result.ZIndex = UDim2.fromOffset(40, 40), 2
        Style.Apply(result, 16)
        Style.Outline(result).Thickness = 1
        result.Text, result.Parent = text, panel
        result.Activated:Connect(callback)
        return result
    end
    local function face(buttonObject: TextButton, color: Color3, transparency: number)
        local fill = Instance.new("Frame")
        fill.Name = "ButtonFace"
        fill.Size = UDim2.new(buttonObject.Size.X.Scale, buttonObject.Size.X.Offset, 0, 28)
        fill.Position = UDim2.new(
            buttonObject.Position.X.Scale,
            buttonObject.Position.X.Offset,
            buttonObject.Position.Y.Scale,
            buttonObject.Position.Y.Offset + 6
        )
        fill.BackgroundColor3, fill.BackgroundTransparency = color, transparency
        fill.BorderSizePixel, fill.ZIndex, fill.Parent = 0, 1, panel
        Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 8)
    end
    local saveButton = button("SAVE", save)
    saveButton.Size, saveButton.Position = UDim2.new(0.6, -16, 0, 40), UDim2.fromOffset(12, 90)
    face(saveButton, Color3.fromRGB(92, 116, 102), 0.12)
    -- Both dismissal controls call the same callback: keep name, close, return camera.
    local skip = button("SKIP", close)
    skip.Size, skip.Position = UDim2.new(0.4, -16, 0, 40), UDim2.new(0.6, 4, 0, 90)
    skip.TextColor3 = Color3.fromRGB(211, 215, 223)
    face(skip, Color3.fromRGB(135, 144, 159), 0.85)
    local x = button("X", close)
    x.Size, x.Position = UDim2.fromOffset(36, 36), UDim2.new(1, -40, 0, 4)
    x.TextColor3 = Color3.fromRGB(211, 215, 223)
    local status = label("", 132)
    status.Size = UDim2.new(1, -24, 0, 20)
    status.TextSize, status.TextWrapped = 12, true
    local counter = label("", 74)
    counter.Name, counter.TextSize = "CharacterCounter", 11
    counter.Size = UDim2.new(1, -24, 0, 16)
    counter.TextXAlignment = Enum.TextXAlignment.Right
    local editing = false
    local function updateText()
        if editing then
            return
        end
        editing = true
        local limited = Config.Truncate(box.Text)
        if limited ~= box.Text then
            local cursor, selection = box.CursorPosition, box.SelectionStart
            box.Text = limited
            -- TextBox caret/selection offsets are bytes, even for Unicode text.
            box.CursorPosition = math.min(cursor, #limited + 1)
            box.SelectionStart = math.min(selection, #limited + 1)
        end
        local count = Config.Count(limited) or 0
        counter.Text = string.format("%d/%d", count, Config.MaxCharacters)
        counter.TextTransparency = if count == Config.MaxCharacters then 0.05 else 0.35
        editing = false
    end
    box:GetPropertyChangedSignal("Text"):Connect(updateText)
    updateText()

    local controls: { GuiObject } = { box, saveButton, skip, x }
    for _, control in controls do
        control.Selectable = true
    end
    box.NextSelectionDown, box.NextSelectionUp = saveButton, x
    saveButton.NextSelectionUp, saveButton.NextSelectionRight = box, skip
    saveButton.NextSelectionDown, saveButton.NextSelectionLeft = x, skip
    skip.NextSelectionUp, skip.NextSelectionLeft = box, saveButton
    skip.NextSelectionDown, skip.NextSelectionRight = x, saveButton
    x.NextSelectionDown, x.NextSelectionUp = box, skip
    x.NextSelectionLeft, x.NextSelectionRight = box, box
    local previousSelection: GuiObject? = nil
    local function placePanel()
        local height = area.AbsoluteSize.Y
        local bottom = height - 20
        if gui.Enabled and Input.OnScreenKeyboardVisible then
            local keyboard = Input.OnScreenKeyboardPosition
            local keyboardSize = Input.OnScreenKeyboardSize
            if keyboardSize.Y > 0 then
                local keyboardTop = if keyboard.Y > 0
                    then keyboard.Y
                    else area.AbsolutePosition.Y + height - keyboardSize.Y
                bottom = math.min(bottom, keyboardTop - area.AbsolutePosition.Y - 8)
            end
        end
        if gui.Enabled and Input.OnScreenKeyboardVisible then
            scale.Scale = math.clamp((bottom - 8) / 154, 0.1, 1)
            panel.Position = UDim2.new(0.5, 0, 0, math.max(8, bottom))
        else
            scale.Scale = 1
            panel.Position = UDim2.new(0.5, 0, 1, -20)
        end
    end
    for _, property in { "OnScreenKeyboardVisible", "OnScreenKeyboardPosition", "OnScreenKeyboardSize" } do
        Input:GetPropertyChangedSignal(property):Connect(placePanel)
    end
    area:GetPropertyChangedSignal("AbsoluteSize"):Connect(placePanel)
    area:GetPropertyChangedSignal("AbsolutePosition"):Connect(placePanel)
    gui:GetPropertyChangedSignal("Enabled"):Connect(function()
        if gui.Enabled then
            previousSelection = GuiService.SelectedObject
            if Input.GamepadEnabled then
                GuiService.SelectedObject = box
            end
        elseif GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
            GuiService.SelectedObject = if previousSelection and previousSelection.Parent
                then previousSelection
                else nil
        end
        placePanel()
    end)
    box.FocusLost:Connect(function(enter)
        if enter then
            save()
        end
    end)
    box.ReturnPressedFromOnScreenKeyboard:Connect(save)
    return { Gui = gui, Box = box, Status = status, Save = saveButton }
end

return UI
