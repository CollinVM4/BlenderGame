--!strict
local Players = game:GetService("Players")
local CAS = game:GetService("ContextActionService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Constants.UnstuckConfig)
local getEvent = require(Shared.Events.UnstuckEvents)
local PanelManager = require(script.Parent.Parent.UI.PanelManager)
local player = Players.LocalPlayer
local Controller = {}
local started = false
function Controller.Init()
    if started then
        return
    end
    started = true
    local remote = getEvent()
    local gui = Instance.new("ScreenGui")
    gui.Name = "UnstuckGui"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 5
    gui.Parent = player:WaitForChild("PlayerGui")
    local button = Instance.new("TextButton")
    button.Name = "Unstuck"
    button.AnchorPoint = Vector2.new(0.5, 0)
    button.Position = UDim2.fromScale(0.5, 0.16)
    button.Size = UDim2.fromOffset(180, 48)
    button.BackgroundColor3 = Color3.fromRGB(247, 191, 71)
    button.TextColor3 = Color3.fromRGB(42, 35, 27)
    button.Font = Enum.Font.FredokaOne
    button.TextSize = 22
    button.Text = "UNSTUCK"
    button.Selectable = true
    button.Visible = false
    button.Parent = gui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = button
    local hint = Instance.new("TextLabel")
    hint.Name = "Eligibility"
    hint.BackgroundTransparency = 1
    hint.Position = UDim2.new(0, -40, 1, 4)
    hint.Size = UDim2.new(1, 80, 0, 32)
    hint.Font = Enum.Font.FredokaOne
    hint.TextSize = 14
    hint.TextColor3 = Color3.new(1, 1, 1)
    hint.TextStrokeTransparency = 0.3
    hint.TextWrapped = true
    hint.Text = "Stuck after a hit? (U / D-pad Up)"
    hint.Parent = button
    local feedback = Instance.new("TextLabel")
    feedback.Name = "RecoveryFeedback"
    feedback.AnchorPoint = Vector2.new(0.5, 0)
    feedback.Position = UDim2.new(0.5, 0, 0.16, 52)
    feedback.Size = UDim2.fromOffset(260, 40)
    feedback.BackgroundTransparency = 1
    feedback.Font = hint.Font
    feedback.TextSize = 18
    feedback.TextColor3 = hint.TextColor3
    feedback.TextStrokeTransparency = hint.TextStrokeTransparency
    feedback.TextWrapped = true
    feedback.Visible = false
    feedback.Parent = gui
    local feedbackUntil = 0
    local shown = false
    local pendingUntil = 0
    local bound = false
    local function request()
        if shown and os.clock() >= pendingUntil then
            pendingUntil = os.clock() + Config.RequestIntervalSeconds
            remote:FireServer("Recover")
        end
    end
    local function render(visible: boolean)
        shown = visible
        button.Visible = visible
        if visible and not bound then
            bound = true
            CAS:BindAction("UnstuckRecovery", function(_, state)
                if state == Enum.UserInputState.Begin then
                    request()
                end
                return Enum.ContextActionResult.Sink
            end, false, Enum.KeyCode.U, Enum.KeyCode.DPadUp)
        elseif not visible and bound then
            bound = false
            CAS:UnbindAction("UnstuckRecovery")
        end
    end
    button.Activated:Connect(request)
    remote.OnClientEvent:Connect(function(result: string, recoveredCharacter: Model?)
        if result == "Unstuck!" or result == "Returned to your plot!" then
            if recoveredCharacter ~= player.Character then
                return
            end
            render(false)
            feedback.Text = result
            feedbackUntil = os.clock() + Config.FeedbackSeconds
            feedback.Visible = PanelManager.GetActive() == nil
            local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            if
                recoveredCharacter == player.Character
                and h
                and h.Health > 0
                and player:GetAttribute("Stunned") ~= true
            then
                -- Humanoid state transitions must also run on the owning client.
                h.PlatformStand = false
                h.AutoRotate = true
                h:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        else
            hint.Text = result
        end
    end)
    player.CharacterAdded:Connect(function()
        feedbackUntil = 0
        feedback.Visible = false
        render(false)
    end)
    player:GetAttributeChangedSignal("UnstuckEligible"):Connect(function()
        if player:GetAttribute("UnstuckEligible") ~= true then
            render(false)
        end
    end)
    task.spawn(function()
        local lastPosition: Vector3? = nil
        local lastCharacter: Model? = nil
        while true do
            task.wait(Config.SampleSeconds)
            feedback.Visible = os.clock() < feedbackUntil and PanelManager.GetActive() == nil
            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local part = character and character:FindFirstChild("HumanoidRootPart")
            local root = if part and part:IsA("BasePart") then part else nil
            local live = humanoid ~= nil and humanoid.Health > 0 and root ~= nil
            if character ~= lastCharacter then
                lastPosition = nil
                lastCharacter = character
            end
            local moved = root ~= nil
                and lastPosition ~= nil
                and (root.Position - lastPosition).Magnitude > Config.MaxDisplacement
            if player:GetAttribute("UnstuckWatching") == true and live then
                -- Input is an intent hint only; server measures displacement/obstruction.
                remote:FireServer((humanoid :: Humanoid).MoveDirection.Magnitude > 0.05)
            end
            render(
                live
                    and not moved
                    and player:GetAttribute("UnstuckEligible") == true
                    and player:GetAttribute("Stunned") ~= true
                    and PanelManager.GetActive() == nil
            )
            lastPosition = if root then root.Position else nil
        end
    end)
end
return Controller
