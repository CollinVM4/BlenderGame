--!strict
local Events = game:GetService("ReplicatedStorage").Shared.Events
local GameplaySfx = {}
export type Event = "IngredientPickup" | "IngredientPlant" | "IngredientThrow" | "BatSwing"
local remote: RemoteEvent?

function GameplaySfx.Init()
    if remote then
        return
    end
    local existing = Events:FindFirstChild("GameplaySfx")
    if existing then
        assert(existing:IsA("RemoteEvent"), "GameplaySfx must be a RemoteEvent")
        remote = existing
    else
        local event = Instance.new("RemoteEvent")
        event.Name = "GameplaySfx"
        event.Parent = Events
        remote = event
    end
end

-- Server output only. There is deliberately no OnServerEvent listener.
function GameplaySfx.Emit(event: Event, position: Vector3)
    if remote then
        remote:FireAllClients(event, position)
    end
end

return GameplaySfx
