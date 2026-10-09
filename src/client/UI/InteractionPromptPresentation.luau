--!strict
local UserInputService = game:GetService("UserInputService")
local Style = require(script.Parent.WorldBillboardStyle)
local TextStyle = require(game:GetService("ReplicatedStorage").Shared.Constants.DialogueTextStyle)
local TouchTargets = require(script.Parent.MobilePromptTouchTargets)
local Debug = require(game:GetService("ReplicatedStorage").Shared.MobilePromptDebug)
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
    TouchWidth: number?,
    TouchHeight: number?,
    TouchCenterY: number?,
    Available: (() -> boolean)?,
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
    local stashPrompt = prompt:GetAttribute("PlayerStashPrompt") == true
    local gui = Instance.new("BillboardGui")
    gui.Name = "InteractionPromptDisplay"
    gui.Adornee = origin
    Style.ApplyBillboard(gui, config)
    gui.Active = true

    -- A transparent button preserves touch/click input through the prompt's API.
    local paddedTouch = inputType == Enum.ProximityPromptInputType.Touch and config.TouchWidth ~= nil
    local inputButton = if paddedTouch then nil else Instance.new("TextButton")
    local text = (inputButton or Instance.new("TextLabel")) :: TextLabel
    text.Name = "Action"
    if paddedTouch then
        text.Active = false
    end
    Style.ApplyText(text, config)
    if origin.Name == "DispenserTextOrigin" or stashPrompt or prompt:GetAttribute("JackedNoobPrompt") == true then
        TextStyle.Apply(text, config.TextSize or 24)
    end
    if config.CustomerAction and not stashPrompt then
        -- Shared input behavior, with a compact customer-only visual treatment.
        local billboard = gui :: BillboardGui
        billboard.Size = UDim2.fromOffset(220, 44)
        billboard.StudsOffset = Vector3.zero
        billboard.SizeOffset = Vector2.new(0, -(22 + 12) / 44) -- Top edge 12px below the shared rig anchor.
        if config.CustomerAction == "Serve" and origin:IsA("Attachment") then
            local root = origin.Parent
            if root and root:IsA("BasePart") then
                -- Center at the waist, scaled with the rig, without moving the shared anchor.
                billboard.StudsOffsetWorldSpace = Vector3.new(0, root.Size.Y * 0.25 - origin.Position.Y, 0)
                billboard.SizeOffset = Vector2.new(0, 0)
            end
        end
        text.Font = TextStyle.Font
        text.TextSize = 21
        text.TextColor3 = if config.CustomerAction == "TakeOrder" then TextStyle.Gold else Color3.fromRGB(120, 235, 255)
        TextStyle.Outline(text)
    end
    if inputButton then
        inputButton.AutoButtonColor = false
    end
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
    local alive = true
    local function release()
        if activeInput then
            activeInput = nil
            if paddedTouch then
                text.TextTransparency = 0
            end
            if prompt.Parent then
                prompt:InputHoldEnd()
            end
        end
    end
    local function begin(input: InputObject)
        local reason: string? = nil
        if not alive then
            reason = "hidden view"
        elseif activeInput then
            reason = "prompt already held by another finger"
        elseif not prompt.Enabled then
            reason = "disabled prompt"
        elseif not prompt:IsDescendantOf(workspace) then
            reason = "invalid source: prompt outside Workspace"
        elseif config.Available and not config.Available() then
            reason = "invalid source: ingredient registration, identity or ownership changed"
        end
        if reason then
            if paddedTouch then
                Debug.Log(prompt, "REJECTED", reason)
            end
            return
        end
        activeInput = input
        -- Immediate, display-only feedback. Inventory still waits for the server.
        if paddedTouch then
            text.TextTransparency = 0.25
        end
        if paddedTouch then
            Debug.Log(prompt, "HOLD BEGIN", "client HoldDuration=" .. tostring(prompt.HoldDuration))
        end
        prompt:InputHoldBegin()
    end
    local unregister: (() -> ())? = nil
    if paddedTouch then
        local target = Instance.new("TextButton")
        target.Name = "TouchTarget"
        target.Text = ""
        target.BackgroundTransparency = 1
        target.AutoButtonColor = false
        target.Active = true
        target.Selectable = false
        target.ZIndex = text.ZIndex + 1
        target.AnchorPoint = Vector2.new(0.5, 0.5)
        target.Position = UDim2.new(0.5, 0, 0, config.TouchCenterY or (config.Height or 56) / 2)
        target.Size = UDim2.fromOffset(assert(config.TouchWidth), config.TouchHeight or 80)
        target.Parent = gui
        unregister = TouchTargets.Register(prompt, gui, target, begin, config.Available)
    else
        table.insert(
            connections,
            text.InputBegan:Connect(function(input)
                local touch = input.UserInputType == Enum.UserInputType.Touch
                local click = input.UserInputType == Enum.UserInputType.MouseButton1 and prompt.ClickablePrompt
                if touch or click then
                    begin(input)
                end
            end)
        )
    end
    table.insert(
        connections,
        UserInputService.InputEnded:Connect(function(input)
            if input == activeInput then
                release()
            end
        end)
    )
    if paddedTouch then
        table.insert(
            connections,
            UserInputService.InputChanged:Connect(function(input)
                if input == activeInput and input.UserInputState == Enum.UserInputState.Cancel then
                    release()
                end
            end)
        )
        table.insert(
            connections,
            prompt.Triggered:Connect(function()
                Debug.Log(prompt, "TRIGGERED", "client native event; server dispatch is logged separately")
            end)
        )
    end
    table.insert(connections, UserInputService.WindowFocusReleased:Connect(release))
    refresh()
    return function()
        alive = false
        if unregister then
            unregister()
        end
        for _, connection in connections do
            connection:Disconnect()
        end
        release()
        gui:Destroy()
    end,
        gui
end

return Presentation
