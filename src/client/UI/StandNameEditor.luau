--!strict
local Style = require(game:GetService("ReplicatedStorage").Shared.Constants.DialogueTextStyle)
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.StandIdentity)
local Input = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local UI = {}

export type View = {
    Gui: ScreenGui,
    Box: TextBox,
    Status: TextLabel,
    Save: TextButton,
    Show: () -> (),
    Hide: (string?) -> (),
    TraceSelection: (string) -> (),
}

function UI.Create(parent: Instance, save: () -> (), close: () -> ()): View
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
    -- Opt in on this ScreenGui in a Studio client; silent in normal play.
    local function debugEnabled(): boolean
        return RunService:IsStudio() and gui:GetAttribute("DebugSelection") == true
    end
    local function traceSelection(reason: string)
        if not debugEnabled() then
            return
        end
        local selected = GuiService.SelectedObject
        print(
            "[StandNameSelection]",
            reason,
            "SelectedObject=",
            selected,
            "FullName=",
            if selected then selected:GetFullName() else "nil",
            "LastInputType=",
            Input:GetLastInputType(),
            "PreferredInput=",
            Input.PreferredInput,
            "Focused=",
            box:IsFocused()
        )
    end
    local function button(text: string, callback: () -> ()): TextButton
        local result = Instance.new("TextButton")
        -- Slim visual face inside a larger transparent tap/controller target.
        result.BackgroundTransparency, result.BorderSizePixel = 1, 0
        result.Size, result.ZIndex = UDim2.fromOffset(40, 40), 2
        Style.Apply(result, 16)
        Style.Outline(result).Thickness = 1
        result.Text, result.Parent = text, panel
        result.Activated:Connect(function()
            traceSelection(text)
            callback()
        end)
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
    local editorOwnsSelection = false
    local selectionResolved = true
    local closing = true
    local function controllerNavigation(): boolean
        return Input.PreferredInput == Enum.PreferredInput.Gamepad
    end
    local function validDestination(target: GuiObject?): boolean
        if
            not target
            or not target:IsA("GuiObject")
            or not target:IsDescendantOf(parent)
            or target:IsDescendantOf(gui)
            or not target.Selectable
        then
            return false
        end
        local ancestor: Instance? = target
        while ancestor and ancestor ~= parent do
            if ancestor:IsA("GuiObject") and not ancestor.Visible then
                return false
            end
            if
                (ancestor:IsA("ScreenGui") or ancestor:IsA("BillboardGui") or ancestor:IsA("SurfaceGui"))
                and not ancestor.Enabled
            then
                return false
            end
            ancestor = ancestor.Parent
        end
        return true
    end
    local function resolveEditorSelection()
        if selectionResolved then
            return
        end
        selectionResolved = true
        local selected = GuiService.SelectedObject
        local inside = selected ~= nil and selected:IsDescendantOf(gui)
        -- An unchanged pre-editor HUD selection is stale for pointer input.
        -- A different outside selection belongs to another UI and must survive.
        if selected and not inside and selected ~= previousSelection then
            previousSelection = nil
            editorOwnsSelection = false
            return
        end
        if inside then
            editorOwnsSelection = true
        end
        if controllerNavigation() then
            if editorOwnsSelection and (inside or selected == nil) then
                GuiService.SelectedObject = if validDestination(previousSelection) then previousSelection else nil
            end
        elseif inside or (selected ~= nil and selected == previousSelection) then
            GuiService.SelectedObject = nil
        end
        previousSelection = nil
        editorOwnsSelection = false
    end
    local function hide(reason: string?)
        if selectionResolved or closing then
            return
        end
        closing = true
        traceSelection(reason or "Close")
        traceSelection("before ReleaseFocus")
        if box:IsFocused() then
            box:ReleaseFocus()
        end
        traceSelection("after ReleaseFocus")
        resolveEditorSelection()
        traceSelection("before Gui.Enabled=false")
        gui.Enabled = false
        traceSelection("after Gui.Enabled=false")
        if debugEnabled() then
            task.spawn(function()
                RunService.Heartbeat:Wait()
                traceSelection("next Heartbeat")
            end)
        end
    end
    local function enterControllerNavigation()
        if not gui.Enabled or closing or not controllerNavigation() then
            return
        end
        local selected = GuiService.SelectedObject
        if selected == nil or selected == previousSelection or selected:IsDescendantOf(gui) then
            editorOwnsSelection = true
            GuiService.SelectedObject = box
        end
    end
    Input:GetPropertyChangedSignal("PreferredInput"):Connect(enterControllerNavigation)
    local function beginEditorSelection()
        if not selectionResolved then
            return
        end
        previousSelection = GuiService.SelectedObject
        editorOwnsSelection, selectionResolved, closing = false, false, false
        traceSelection("editor opening")
    end
    local function show()
        -- Capture synchronously; correctness must not depend on Enabled signal timing.
        beginEditorSelection()
        gui.Enabled = true
        enterControllerNavigation()
    end
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
            if selectionResolved then
                beginEditorSelection()
                enterControllerNavigation()
            end
        else
            hide("externally hidden")
        end
        placePanel()
    end)
    box.Focused:Connect(function()
        traceSelection("TextBox Focused")
    end)
    box.FocusLost:Connect(function(enter)
        traceSelection("TextBox FocusLost")
        if enter and not closing then
            save()
        end
    end)
    box.ReturnPressedFromOnScreenKeyboard:Connect(function()
        traceSelection("keyboard Save")
        if not closing then
            save()
        end
    end)
    return {
        Gui = gui,
        Box = box,
        Status = status,
        Save = saveButton,
        Show = show,
        Hide = hide,
        TraceSelection = traceSelection,
    }
end

return UI
