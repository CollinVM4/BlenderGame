--!strict
-- Detects sprint input (keyboard Shift) and requests sprint start/stop from the server
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local getSprintEvent = require(ReplicatedStorage.Shared.Events.SprintEvents)

local SprintController = {}
local started = false
local requested = false
local heldShift: { [Enum.KeyCode]: boolean } = {}

local function requestSprint(sprintEvent: RemoteEvent, wantsToSprint: boolean)
    if requested == wantsToSprint then
        return
    end
    requested = wantsToSprint
    sprintEvent:FireServer(wantsToSprint)
end

function SprintController.Init()
    if started then
        return
    end
    started = true
    local sprintEvent = getSprintEvent()

    UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
        if gameProcessedEvent then
            return
        end
        if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
            heldShift[input.KeyCode] = true
            requestSprint(sprintEvent, true)
        end
    end)

    UserInputService.InputEnded:Connect(function(input: InputObject)
        if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
            heldShift[input.KeyCode] = nil
            requestSprint(sprintEvent, next(heldShift) ~= nil)
        end
    end)

    UserInputService.WindowFocusReleased:Connect(function()
        table.clear(heldShift)
        requestSprint(sprintEvent, false)
    end)

    -- TODO: mobile onscreen sprint button and console/gamepad input (e.g. thumbstick click) should
    -- also call requestSprint(sprintEvent, true/false) here once those input modalities are built

    -- Presentation reads the server-replicated StaminaCurrent/StaminaMax/IsSprinting attributes.
end

return SprintController
