--!strict
-- Shared RemoteEvent used to request sprint start/stop and sync stamina back to the client
local remoteEvent: RemoteEvent? = nil
local RunService = game:GetService("RunService")

return function(): RemoteEvent
    if remoteEvent == nil then
        local existing = script:FindFirstChild("SprintRequest")
        if existing and existing:IsA("RemoteEvent") then
            remoteEvent = existing
        else
            if not RunService:IsServer() then
                remoteEvent = script:WaitForChild("SprintRequest") :: RemoteEvent
                return remoteEvent :: RemoteEvent
            end
            local newEvent = Instance.new("RemoteEvent")
            newEvent.Name = "SprintRequest"
            newEvent.Parent = script
            remoteEvent = newEvent
        end
    end

    return remoteEvent :: RemoteEvent
end
