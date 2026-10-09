--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local MobileControlLayout = require(script.Parent.Parent.UI.MobileControlLayout)
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
        local character = player.Character
        if character then
            for _, child in character:GetChildren() do
                if
                    child:IsA("Tool")
                    and (
                        typeof(child:GetAttribute("BatLevel")) == "number"
                        or child:GetAttribute("IceGunWeapon") == true
                    )
                then
                    -- Leave primary input available to Tool.Activated, including on touch.
                    return Enum.ContextActionResult.Pass
                end
            end
        end
        if player:GetAttribute("Stunned") == true then
            return Enum.ContextActionResult.Sink
        end
        if (player:GetAttribute("CarryCount") or 0) <= 0 or UserInputService:GetFocusedTextBox() then
            return Enum.ContextActionResult.Pass
        end
        if state == Enum.UserInputState.Begin then
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
    -- The existing CAS Throw button and console trigger share this intentional path.
    -- Do not bind touch-world/primary mouse input to the mobile button's action.
    ContextActionService:BindAction("ThrowHeld", throw, true, Enum.KeyCode.ButtonR2)
    ContextActionService:BindAction("ThrowHeldMouse", function(action, state)
        if UserInputService.TouchEnabled then
            -- Touch may also generate primary mouse input. UI, joystick and camera
            -- gestures must never turn that synthesized input into a throw.
            return Enum.ContextActionResult.Pass
        end
        return throw(action, state)
    end, false, Enum.UserInputType.MouseButton1)
    ContextActionService:SetTitle("ThrowHeld", "Throw")
    MobileControlLayout.Register("ThrowHeld")
end

return Controller
