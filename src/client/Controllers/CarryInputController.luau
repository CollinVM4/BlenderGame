--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local Controller = {}
local started = false

function Controller.Init()
    if started then
        return
    end
    started = true
    local player = Players.LocalPlayer
    local remote = ReplicatedStorage.Shared.Events:WaitForChild("GameplayRequest") :: RemoteEvent
    local function throw(_action: string, state: Enum.UserInputState): Enum.ContextActionResult
        if not player:GetAttribute("HeldItemType") or UserInputService:GetFocusedTextBox() then
            return Enum.ContextActionResult.Pass
        end
        if state == Enum.UserInputState.Begin then
            -- No client-provided item identity, contents, or launch position.
            remote:FireServer("ThrowHeld")
        end
        return Enum.ContextActionResult.Sink
    end
    ContextActionService:BindAction("ThrowHeld", throw, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
    ContextActionService:SetTitle("ThrowHeld", "Throw")
end

return Controller
