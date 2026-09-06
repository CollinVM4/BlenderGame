--!strict
-- Shared RemoteEvent used to request sprint start/stop and sync stamina back to the client
local remoteEvent: RemoteEvent? = nil

return function(): RemoteEvent
    if remoteEvent == nil then
        local existing = script:FindFirstChild("SprintRequest")
        if existing and existing:IsA("RemoteEvent") then
            remoteEvent = existing
        else
            local newEvent = Instance.new("RemoteEvent")
            newEvent.Name = "SprintRequest"
            newEvent.Parent = script
            remoteEvent = newEvent
        end
    end

    return remoteEvent :: RemoteEvent
end
