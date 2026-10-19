--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local State = require(script.Parent.Parent.UI.CashRewardState)
local Animation = require(script.Parent.Parent.UI.CashRewardAnimation)
local Debug = require(script.Parent.Parent.UI.CashRewardDebug)
local Controller = {}
local started = false

function Controller.Init()
    if started then
        return
    end
    started = true
    local accept = State.New()
    local player = Players.LocalPlayer
    player.CharacterRemoving:Connect(Animation.Clear)
    task.spawn(function()
        local events = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Events")
        local remote = events:WaitForChild("GameplayPresentation") :: RemoteEvent
        remote.OnClientEvent:Connect(function(moment: any, owner: any, payload: any)
            local accepted, reason = accept(moment, owner, payload, player.UserId)
            Debug.Log(player, string.format("received %s owner=%s: %s", tostring(moment), tostring(owner), reason))
            if accepted then
                Animation.Play(player)
            end
        end)
    end)
end

return Controller
