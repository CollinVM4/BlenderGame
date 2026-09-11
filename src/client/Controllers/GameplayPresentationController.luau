--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameplayPresentationController = {}
local started = false

function GameplayPresentationController.Init()
    if started then
        return
    end
    started = true
    -- Waiting for server-created objects must not block other client controllers.
    task.spawn(function()
        local events = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Events")
        local remote = events:WaitForChild("GameplayPresentation")
        assert(remote:IsA("RemoteEvent"), "GameplayPresentation must be a RemoteEvent")
        remote.OnClientEvent:Connect(function(_moment: any, _ownerUserId: any, _payload: any)
            -- Drain all presentation messages, including future/unsupported kinds.
            -- Current visuals use replicated attributes and server-created UI/audio.
            -- Add cosmetic handlers here when implemented; never send gameplay requests
            -- or mutate authoritative state in response to these notifications.
        end)
    end)
end

return GameplayPresentationController
