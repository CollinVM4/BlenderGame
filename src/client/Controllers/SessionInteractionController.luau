--!strict
-- Preserve native/custom prompt presentation while carrying the actor's request revision.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Controller = {}
local started = false
function Controller.Init()
    if started then
        return
    end
    started = true
    task.spawn(function()
        local events = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Events")
        local remote = events:WaitForChild("GameplayRequest") :: RemoteEvent
        ProximityPromptService.PromptTriggered:Connect(function(prompt)
            if prompt:GetAttribute("SessionInteraction") ~= true then
                return
            end
            local player = Players.LocalPlayer
            remote:FireServer("PlotInteraction", prompt, nil, {
                PlotSessionId = player:GetAttribute("PlotSessionId"),
                MembershipRevision = player:GetAttribute("PlotMembershipRevision"),
            })
        end)
    end)
end
return Controller
