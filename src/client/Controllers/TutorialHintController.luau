--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local Banner = require(script.Parent.Parent.UI.AnnouncementBanner)
local Text = require(script.Parent.Parent.UI.TutorialHintText)
local Carry = require(script.Parent.CarryInputController)
local Presentation = require(script.Parent.TutorialPresentationState)
local Controller = {}
local initialized = false
local connections: { RBXScriptConnection } = {}
local presentationConnections: { RBXScriptConnection } = {}
local function stopPresentation()
    for _, connection in presentationConnections do
        connection:Disconnect()
    end
    table.clear(presentationConnections)
end
local surface: Banner.Surface? = nil
local displayed: string? = nil
local exitingUntil: number? = nil
local removingCharacter: Model? = nil
local function clearSurface()
    if surface then
        surface.Destroy()
        surface = nil
    end
    displayed, exitingUntil = nil, nil
end
local function refresh()
    local player = Players.LocalPlayer
    local now = os.clock()
    local textAllowed, presentationReady, stage = Presentation.Read(player)
    local gui = player:FindFirstChildOfClass("PlayerGui")
    local character = player.Character
    local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
    local active = Presentation.IsActive(player, stage) and type(stage) == "string"
    if not active or not textAllowed then
        stopPresentation()
        clearSurface()
        return
    end
    if #presentationConnections == 0 then
        table.insert(presentationConnections, Banner.PriorityChanged:Connect(refresh))
        table.insert(presentationConnections, Input:GetPropertyChangedSignal("PreferredInput"):Connect(refresh))
        table.insert(presentationConnections, RunService.Heartbeat:Connect(refresh))
    end
    if surface and (not gui or not surface.Gui:IsDescendantOf(gui)) then
        clearSurface()
    end
    local visible = presentationReady
        and character ~= nil
        and character ~= removingCharacter
        and character:IsDescendantOf(workspace)
        and humanoid ~= nil
        and humanoid.Health > 0
        and not Banner.IsGlobalActive()
    if not visible or not gui then
        if surface then
            surface.Hide() -- Priority is synchronous: never overlap even during exit.
        end
        displayed, exitingUntil = nil, nil
        return
    end
    local button = Carry.GetThrowButtonLabel():gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
    local hint = Text.Get(stage :: string, Input.PreferredInput, button)
    if not hint then
        clearSurface()
        return
    end
    local text = '<font color="#FFE073">' .. hint .. "</font>"
    if not surface then
        surface = Banner.Create(gui :: PlayerGui, "TutorialHint")
    end
    local banner = surface :: Banner.Surface
    if text == displayed and not exitingUntil then
        return
    end
    if stage == "Dispenser" then
        exitingUntil = nil -- Smoothie readiness shows collection immediately, including during another exit.
    elseif displayed and not exitingUntil then
        banner.Exit()
        exitingUntil = now + 0.18
        return
    end
    if exitingUntil and now < exitingUntil then
        return
    end
    banner.Show(text)
    displayed, exitingUntil = text, nil
end
function Controller.Destroy()
    initialized = false
    stopPresentation()
    clearSurface()
    for _, connection in connections do
        connection:Disconnect()
    end
    table.clear(connections)
end
function Controller.Init()
    if initialized then
        return
    end
    initialized = true
    local player = Players.LocalPlayer
    table.insert(
        connections,
        player.CharacterRemoving:Connect(function(character)
            removingCharacter = character
            if character then
                Presentation.CharacterRemoving(character)
            end
            clearSurface()
        end)
    )
    table.insert(
        connections,
        player.CharacterAdded:Connect(function()
            removingCharacter = nil
            Presentation.CharacterAdded()
            refresh()
        end)
    )
    for _, attribute in
        {
            "FarmTutorialStage",
            "TutorialStage",
            "TutorialOrderIndex",
            "TutorialActive",
            "TutorialHintReady",
            "PlotSessionId",
        }
    do
        table.insert(connections, player:GetAttributeChangedSignal(attribute):Connect(refresh))
    end
    table.insert(connections, script.Destroying:Connect(Controller.Destroy))
    refresh()
end
return Controller
