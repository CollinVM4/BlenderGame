local CollectionService = game:GetService("CollectionService")

local BlenderKill = {}

local TAG = "KillZone"

local function connectKillPart(part: Instance)
    if not part:IsA("BasePart") then
        return
    end

    if part:GetAttribute("KillZoneConnected") then
        return
    end

    part:SetAttribute("KillZoneConnected", true)

    part.Touched:Connect(function(hit)
        local character = hit:FindFirstAncestorOfClass("Model")
        if not character then
            return
        end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Health > 0 then
            humanoid.Health = 0
        end
    end)
end

function BlenderKill.Init()
    for _, instance in CollectionService:GetTagged(TAG) do
        connectKillPart(instance)
    end

    CollectionService:GetInstanceAddedSignal(TAG):Connect(connectKillPart)
end

return BlenderKill