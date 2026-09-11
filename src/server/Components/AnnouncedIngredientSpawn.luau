--!strict
local Events = game:GetService("ReplicatedStorage").Shared.Events
local IngredientSpawn = require(script.Parent.IngredientSpawn)
local AnnouncedIngredientSpawn = {}
local started = false

function AnnouncedIngredientSpawn.Init(services: any)
    if started then
        return
    end
    started = true
    local existing = Events:FindFirstChild("RareIngredientSpawned")
    local remote: RemoteEvent
    if existing then
        assert(existing:IsA("RemoteEvent"), "RareIngredientSpawned must be a RemoteEvent")
        remote = existing
    else
        remote = Instance.new("RemoteEvent")
        remote.Name = "RareIngredientSpawned"
        remote.Parent = Events
    end
    -- No inbound listener: clients cannot select stock, timing, or announce events.
    IngredientSpawn.Bind(services, "AnnouncedIngredientSpawn", function(station, id)
        local location = station:GetAttribute("LocationName")
        remote:FireAllClients({
            Type = "RareIngredientSpawned",
            IngredientId = id,
            DisplayName = services.IngredientService.GetDefinition(id).DisplayName,
            LocationName = if typeof(location) == "string" and location ~= "" then location else station.Name,
        })
    end)
end

return AnnouncedIngredientSpawn
