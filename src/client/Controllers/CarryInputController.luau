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
        if (player:GetAttribute("CarryCount") or 0) <= 0 or UserInputService:GetFocusedTextBox() then
            return Enum.ContextActionResult.Pass
        end
        if state == Enum.UserInputState.Begin then
            local character = player.Character
            local tool = character and character:FindFirstChildOfClass("Tool")
            local selectedCarryItemId = nil
            if tool and tool:GetAttribute("IngredientId") ~= nil then
                local id = tool:GetAttribute("CarryItemId")
                if typeof(id) == "number" then
                    selectedCarryItemId = id
                end
            end
            -- The server validates this preference against its own held records.
            remote:FireServer("ThrowHeld", selectedCarryItemId)
        end
        return Enum.ContextActionResult.Sink
    end
    ContextActionService:BindAction("ThrowHeld", throw, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
    ContextActionService:SetTitle("ThrowHeld", "Throw")
end

return Controller
