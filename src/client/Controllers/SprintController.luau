--!strict
-- Detects sprint input (keyboard Shift) and requests sprint start/stop from the server
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local getSprintEvent = require(ReplicatedStorage.Shared.Events.SprintEvents)

local SprintController = {}

local function requestSprint(sprintEvent: RemoteEvent, wantsToSprint: boolean)
    sprintEvent:FireServer(wantsToSprint)
end

function SprintController.Init()
    local sprintEvent = getSprintEvent()
    local localPlayer = Players.LocalPlayer

    UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
        if gameProcessedEvent then
            return
        end
        if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
            requestSprint(sprintEvent, true)
        end
    end)

    UserInputService.InputEnded:Connect(function(input: InputObject, gameProcessedEvent: boolean)
        if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
            requestSprint(sprintEvent, false)
        end
    end)

    -- TODO: mobile onscreen sprint button and console/gamepad input (e.g. thumbstick click) should
    -- also call requestSprint(sprintEvent, true/false) here once those input modalities are built

    sprintEvent.OnClientEvent:Connect(function(isSprinting: boolean, staminaCurrent: number, staminaMax: number)
        if localPlayer then
            localPlayer:SetAttribute("StaminaCurrent", staminaCurrent)
            localPlayer:SetAttribute("StaminaMax", staminaMax)
            localPlayer:SetAttribute("IsSprinting", isSprinting)
        end
    end)
end

return SprintController
