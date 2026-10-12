--!strict
-- Intent boolean or destination-free recovery request. Server publishes eligibility.
local remoteEvent: RemoteEvent? = nil
local RunService = game:GetService("RunService")

return function(): RemoteEvent
    if remoteEvent == nil then
        local existing = script:FindFirstChild("UnstuckRequest")
        if existing and existing:IsA("RemoteEvent") then
            remoteEvent = existing
        else
            if not RunService:IsServer() then
                remoteEvent = script:WaitForChild("UnstuckRequest") :: RemoteEvent
                return remoteEvent :: RemoteEvent
            end
            local newEvent = Instance.new("RemoteEvent")
            newEvent.Name = "UnstuckRequest"
            newEvent.Parent = script
            remoteEvent = newEvent
        end
    end

    return remoteEvent :: RemoteEvent
end
