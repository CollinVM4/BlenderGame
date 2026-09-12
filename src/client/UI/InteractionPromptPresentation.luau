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
}

-- One visible view; the caller owns PromptShown/PromptHidden and calls cleanup.
function Presentation.Create(
    prompt: ProximityPrompt,
    origin: Attachment,
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
