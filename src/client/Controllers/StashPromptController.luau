--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Style = require(ReplicatedStorage.Shared.Constants.DialogueTextStyle)
local Economy = require(ReplicatedStorage.Shared.Constants.Economy)
local Controller = {}
local started = false

-- Cosmetic availability only; every press is validated against the server ledger.
function Controller.Unavailable(player: Player, slot: Instance, action: string): string?
    local session = player:GetAttribute("PlotSessionId")
    local friendly = session ~= nil and session == slot:GetAttribute("StashSessionId")
    local now = workspace:GetServerTimeNow()
    if not session or not slot:GetAttribute("StashSessionId") then
        return "UNAVAILABLE!"
    end
    if action == "STORE" then
        if not friendly then
            return "PROTECTED!"
        end
        local itemType = player:GetAttribute("HeldItemType")
        if not itemType then
            return "NOTHING TO STORE!"
        end
        local count = slot:GetAttribute("StashCount") or 0
        if
            count >= (slot:GetAttribute("StashCapacity") or 3)
            or (count > 0 and (itemType == "Smoothie" or slot:GetAttribute("StashItemType") == "Smoothie"))
        then
            return "SLOT FULL!"
        end
    else
        if
            not friendly
            and (
                slot:GetAttribute("StashProtected") == true
                or (
                    now >= (slot:GetAttribute("StashRaidEndsAt") or 0)
                    and now < (slot:GetAttribute("StashProtectionEndsAt") or 0)
                )
            )
        then
            return "PROTECTED!"
        end
        if (slot:GetAttribute("StashCount") or 0) == 0 then
            return "SLOT EMPTY!"
        end
        if (player:GetAttribute("CarryCount") or 0) >= (player:GetAttribute("CarryCapacity") or 3) then
            return "CARRY FULL!"
        end
    end
    return nil
end

function Controller.Init()
    if started then
        return
    end
    started = true
    task.spawn(function()
        local player = Players.LocalPlayer
        local playerGui = player:WaitForChild("PlayerGui")
        local remote = ReplicatedStorage.Shared:WaitForChild("Events"):WaitForChild("StashAction") :: RemoteFunction
        local gui = Instance.new("ScreenGui")
        gui.Name = "StashActions"
        gui.ResetOnSpawn = false
        gui.DisplayOrder = 15
        gui.Enabled = false
        local panel = Instance.new("Frame")
        panel.Name = "Actions"
        panel.AnchorPoint = Vector2.new(0.5, 1)
        -- Center lane avoids the right-hand Jump, Throw and Sprint controls.
        panel.Position = UDim2.fromScale(0.5, 0.72)
        panel.Size = UDim2.fromOffset(284, 112)
        panel.BackgroundTransparency = 1
        panel.Parent = gui
        local title = Instance.new("TextLabel")
        title.Name = "Count"
        title.Size = UDim2.fromOffset(284, 28)
        title.BackgroundTransparency = 1
        Style.Apply(title, 22)
        title.Parent = panel
        local feedback = Instance.new("TextLabel")
        feedback.Name = "Feedback"
        feedback.Position = UDim2.fromOffset(0, 88)
        feedback.Size = UDim2.fromOffset(284, 24)
        feedback.BackgroundTransparency = 1
        Style.Apply(feedback, 18)
        feedback.TextColor3 = Style.Gold
        feedback.Text = ""
        feedback.Parent = panel
        local buttons: { [string]: TextButton } = {}
        local scales: { [string]: UIScale } = {}
        local icons: { [string]: ImageLabel } = {}
        for i, action in { "STORE", "TAKE" } do
            local button = Instance.new("TextButton")
            button.Name = action
            button.Position = UDim2.fromOffset((i - 1) * 146, 30)
            button.Size = UDim2.fromOffset(138, 56)
            button.BackgroundColor3 = Style.Dark
            button.BackgroundTransparency = 0.12
            button.AutoButtonColor = false
            button.Selectable = true
            Style.Apply(button, 20)
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 12)
            corner.Parent = button
            local scale = Instance.new("UIScale")
            scale.Parent = button
            local icon = Instance.new("ImageLabel")
            icon.Name = "InputIcon"
            icon.Position = UDim2.fromOffset(12, 16)
            icon.Size = UDim2.fromOffset(24, 24)
            icon.BackgroundTransparency = 1
            icon.Visible = false
            icon.Parent = button
            icons[action] = icon
            scales[action] = scale
            button.Parent = panel
            buttons[action] = button
        end
        buttons.STORE.NextSelectionRight = buttons.TAKE
        buttons.STORE.NextSelectionLeft = buttons.TAKE
        buttons.TAKE.NextSelectionLeft = buttons.STORE
        buttons.TAKE.NextSelectionRight = buttons.STORE
        gui.Parent = playerGui
        local focusHighlight = Instance.new("Highlight")
        focusHighlight.Name = "StashFocus"
        focusHighlight.FillTransparency = 1
        focusHighlight.OutlineColor = Style.Gold
        focusHighlight.OutlineTransparency = 0.2
        focusHighlight.DepthMode = Enum.HighlightDepthMode.Occluded
        focusHighlight.Enabled = false
        focusHighlight.Parent = workspace
        local focused: ProximityPrompt? = nil
        local pending = false
        local requestId = 0
        local feedbackUntil = 0
        local inputType = Enum.ProximityPromptInputType.Keyboard
        local previousSelection: GuiObject? = nil
        local function ownsSelection(): boolean
            return GuiService.SelectedObject == buttons.STORE or GuiService.SelectedObject == buttons.TAKE
        end
        local function hide()
            focused = nil
            focusHighlight.Enabled = false
            focusHighlight.Adornee = nil
            gui.Enabled = false
            ContextActionService:UnbindAction("StashTAKE")
            if ownsSelection() then
                GuiService.SelectedObject = if previousSelection and previousSelection.Parent
                    then previousSelection
                    else nil
            end
            previousSelection = nil
        end
        local function message(text: string)
            feedback.Text = text
            feedbackUntil = os.clock() + 1.3
        end
        local function refresh()
            local prompt = focused
            local slot = if prompt then prompt.Parent else nil
            if not prompt or not slot then
                return
            end
            title.Text = string.format(
                "STASH %d/%d",
                tonumber(slot:GetAttribute("StashCount")) or 0,
                tonumber(slot:GetAttribute("StashCapacity")) or 3
            )
            for _, action in { "STORE", "TAKE" } do
                local unavailable = Controller.Unavailable(player, slot, action)
                local button = buttons[action]
                button.TextColor3 = if pending or unavailable then Color3.fromRGB(140, 145, 155) else Style.White
                local hint = if inputType == Enum.ProximityPromptInputType.Touch
                    then ""
                    elseif inputType == Enum.ProximityPromptInputType.Gamepad then "[" .. (if action
                            == "STORE"
                        then "X"
                        else "Y") .. "] "
                    else "[" .. (if action == "STORE" then "E" else "R") .. "] "
                local icon = icons[action]
                icon.Visible = inputType == Enum.ProximityPromptInputType.Gamepad
                if icon.Visible then
                    icon.Image = UserInputService:GetImageForKeyCode(
                        if action == "STORE" then Enum.KeyCode.ButtonX else Enum.KeyCode.ButtonY
                    )
                    icon.ImageColor3 = button.TextColor3
                    hint = ""
                end
                button.Text = hint .. action
            end
            if os.clock() >= feedbackUntil then
                feedback.Text = ""
            end
        end
        local function press(action: string)
            local prompt = focused
            if not prompt or not prompt.Parent or pending then
                return
            end
            -- Animation is local; counts and carried items are never predicted.
            scales[action].Scale = 0.94
            task.delay(0.08, function()
                scales[action].Scale = 1
            end)
            local reason = Controller.Unavailable(player, prompt.Parent, action)
            if reason then
                message(reason)
                return
            end
            pending = true
            requestId += 1
            local context = {
                PlotSessionId = player:GetAttribute("PlotSessionId"),
                MembershipRevision = player:GetAttribute("PlotMembershipRevision"),
                TargetSessionId = prompt.Parent:GetAttribute("StashSessionId"),
                RequestId = requestId,
            }
            refresh()
            task.spawn(function()
                local ok, success, rejection = pcall(function()
                    return remote:InvokeServer(prompt, action, context)
                end)
                pending = false
                if focused == prompt then
                    if not ok or not success then
                        message(if ok and type(rejection) == "string" then rejection else "UNAVAILABLE!")
                    end
                    refresh()
                end
            end)
        end
        for _, action in { "STORE", "TAKE" } do
            buttons[action].Activated:Connect(function()
                press(action)
            end)
        end
        ProximityPromptService.PromptShown:Connect(function(prompt, shownInput)
            if prompt:GetAttribute("PlayerStashPrompt") ~= true then
                hide()
                return
            end
            hide()
            focused = prompt
            focusHighlight.Adornee = prompt.Parent
            focusHighlight.Enabled = true
            inputType = shownInput
            gui.Enabled = true
            feedback.Text = ""
            feedbackUntil = 0
            previousSelection = GuiService.SelectedObject
            if inputType == Enum.ProximityPromptInputType.Gamepad then
                GuiService.SelectedObject = buttons.STORE
            end
            ContextActionService:BindAction("StashTAKE", function(_, state)
                if UserInputService:GetFocusedTextBox() or GuiService.MenuIsOpen then
                    return Enum.ContextActionResult.Pass
                end
                if state == Enum.UserInputState.Begin then
                    press("TAKE")
                end
                return Enum.ContextActionResult.Sink
            end, false, Enum.KeyCode.R, Enum.KeyCode.ButtonY)
            refresh()
        end)
        -- E / ButtonX already belong to the native focus prompt. Route its activation
        -- to explicit STORE rather than competing for the same input with CAS.
        ProximityPromptService.PromptTriggered:Connect(function(prompt, actor)
            if
                prompt == focused
                and actor == player
                and not UserInputService:GetFocusedTextBox()
                and not GuiService.MenuIsOpen
            then
                press("STORE")
            end
        end)
        ProximityPromptService.PromptHidden:Connect(function(prompt)
            if focused == prompt then
                hide()
            end
        end)
        UserInputService.LastInputTypeChanged:Connect(function(last)
            inputType = if last == Enum.UserInputType.Touch
                then Enum.ProximityPromptInputType.Touch
                elseif string.find(last.Name, "Gamepad") then Enum.ProximityPromptInputType.Gamepad
                else Enum.ProximityPromptInputType.Keyboard
            if focused and inputType == Enum.ProximityPromptInputType.Gamepad and not ownsSelection() then
                previousSelection = GuiService.SelectedObject
                GuiService.SelectedObject = buttons.STORE
            elseif inputType ~= Enum.ProximityPromptInputType.Gamepad and ownsSelection() then
                GuiService.SelectedObject = nil
            end
            refresh()
        end)
        RunService.Heartbeat:Connect(function()
            local prompt = focused
            if not prompt then
                return
            end
            local slot = prompt.Parent
            local character = player.Character
            local rootPart = if character then character:FindFirstChild("HumanoidRootPart") else nil
            local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
            if
                not slot
                or not slot:IsA("BasePart")
                or not prompt.Enabled
                or not prompt:IsDescendantOf(workspace)
                or not rootPart
                or not rootPart:IsA("BasePart")
                or not humanoid
                or humanoid.Health <= 0
                or (rootPart.Position - slot.Position).Magnitude > Economy.InteractionDistance
                or not player:GetAttribute("PlotSessionId")
            then
                hide()
                return
            end
            refresh()
        end)
    end)
end
return Controller
