--!strict
local UserInputService = game:GetService("UserInputService")
local Style = require(script.Parent.WorldBillboardStyle)
local Presentation = {}

export type Settings = {
    ActionText: string?,
    KeyText: string?,
    MaxDistance: number?,
    Width: number?,
    Height: number?,
    TextSize: number?,
    InputOnly: boolean?,
    CustomerAction: string?,
}

-- One visible view; the caller owns PromptShown/PromptHidden and calls cleanup.
function Presentation.Create(
    prompt: ProximityPrompt,
    origin: Attachment | BasePart | Model,
    parent: Instance,
    inputType: Enum.ProximityPromptInputType,
    settings: Settings?
): (() -> (), BillboardGui)
    local config: Settings = settings or {}
    local gui = Instance.new("BillboardGui")
    gui.Name = "InteractionPromptDisplay"
    gui.Adornee = origin
    Style.ApplyBillboard(gui, config)
    gui.Active = true

    -- A transparent button preserves touch/click input through the prompt's API.
    local text = Instance.new("TextButton")
    text.Name = "Action"
    Style.ApplyText(text, config)
    if config.CustomerAction then
        -- Shared input behavior, with a compact customer-only visual treatment.
        gui.Size = UDim2.fromOffset(220, 44)
        gui.StudsOffset = Vector3.zero
        gui.SizeOffset = Vector2.new(0, -(22 + 12) / 44) -- Top edge 12px below the shared rig anchor.
        if config.CustomerAction == "Serve" and origin:IsA("Attachment") then
            local root = origin.Parent
            if root and root:IsA("BasePart") then
                -- Center at the waist, scaled with the rig, without moving the shared anchor.
                gui.StudsOffsetWorldSpace = Vector3.new(0, root.Size.Y * 0.25 - origin.Position.Y, 0)
                gui.SizeOffset = Vector2.new(0, 0)
            end
        end
        text.Font = Enum.Font.FredokaOne
        text.TextSize = 21
        text.TextColor3 = if config.CustomerAction == "TakeOrder"
            then Color3.fromRGB(255, 222, 115)
            else Color3.fromRGB(120, 235, 255)
        text.TextStrokeTransparency = 1
        local outline = Instance.new("UIStroke")
        outline.Color = Color3.fromRGB(18, 22, 30)
        outline.Thickness = 2.5
        outline.Parent = text
    end
    text.AutoButtonColor = false
    text.Parent = gui
    gui.Parent = parent

    local connections: { RBXScriptConnection } = {}
    local holding = false
    local function refresh()
        local key = config.KeyText
        if not key then
            if inputType == Enum.ProximityPromptInputType.Touch then
                key = "TAP"
            elseif inputType == Enum.ProximityPromptInputType.Gamepad then
                key = prompt.GamepadKeyCode.Name
            else
                key = UserInputService:GetStringForKeyCode(prompt.KeyboardKeyCode)
                if key == "" then
                    key = prompt.KeyboardKeyCode.Name
                end
            end
        end
        text.Text = string.format(
            "[%s] %s%s",
            key or "",
            if holding then "HOLD " else "",
            config.ActionText or prompt.ActionText
        )
        if config.InputOnly then
            text.Text = string.format("%s[%s]", if holding then "HOLD " else "", key or "")
        end
    end
    for _, property in { "ActionText", "KeyboardKeyCode", "GamepadKeyCode" } do
        table.insert(connections, prompt:GetPropertyChangedSignal(property):Connect(refresh))
    end
    table.insert(
        connections,
        prompt.PromptButtonHoldBegan:Connect(function()
            holding = true
            refresh()
        end)
    )
    table.insert(
        connections,
        prompt.PromptButtonHoldEnded:Connect(function()
            holding = false
            refresh()
        end)
    )
    local activeInput: InputObject? = nil
    local function release()
        if activeInput then
            activeInput = nil
            prompt:InputHoldEnd()
        end
    end
    table.insert(
        connections,
        text.InputBegan:Connect(function(input)
            local touch = input.UserInputType == Enum.UserInputType.Touch
            local click = input.UserInputType == Enum.UserInputType.MouseButton1 and prompt.ClickablePrompt
            if not activeInput and (touch or click) then
                activeInput = input
                prompt:InputHoldBegin()
            end
        end)
    )
    table.insert(
        connections,
        UserInputService.InputEnded:Connect(function(input)
            if input == activeInput then
                release()
            end
        end)
    )
    table.insert(connections, UserInputService.WindowFocusReleased:Connect(release))
    refresh()
    return function()
        for _, connection in connections do
            connection:Disconnect()
        end
        release()
        gui:Destroy()
    end,
        gui
end

return Presentation
