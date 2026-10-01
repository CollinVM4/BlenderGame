--!strict
-- Output-only announcements. Acquisition tokens follow units, never equipped Tools.
local Events = game:GetService("ReplicatedStorage").Shared.Events
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Service = {}
local deps: any
local remote: RemoteEvent?
local world: { [Instance]: Types.AnnouncementOwnership? } = {}
setmetatable(world, { __mode = "k" })

function Service.Init(services: any)
    deps = services
    local existing = Events:FindFirstChild("RareIngredientSpawned")
    if existing then
        assert(existing:IsA("RemoteEvent"), "RareIngredientSpawned must be a RemoteEvent")
        remote = existing
    else
        local event = Instance.new("RemoteEvent")
        event.Name = "RareIngredientSpawned" -- Keep the existing transport and client bootstrap.
        event.Parent = Events
        remote = event
    end
end

function Service.Publish(payload: any)
    if remote then
        remote:FireAllClients(payload)
    end
end

local function isMystery(id: string): boolean
    local definition = deps.IngredientService.GetDefinition(id)
    return definition ~= nil and definition.Rarity == "Mystery"
end

function Service.TrackSpawn(object: Instance, id: string)
    if isMystery(id) then
        world[object] = {}
    end
end

function Service.GetOwnership(object: Instance): Types.AnnouncementOwnership?
    return world[object]
end

function Service.TrackWorld(object: Instance, ownership: Types.AnnouncementOwnership?)
    world[object] = ownership
end

function Service.Acquired(player: Player, ownership: Types.AnnouncementOwnership?)
    if not ownership or ownership.LastOwnerUserId == player.UserId then
        return
    end
    ownership.LastOwnerUserId = player.UserId
    Service.Publish({ Type = "MysteryAcquired", DisplayName = player.DisplayName, SoundType = "Mystery", Priority = 10 })
end

function Service.Spawned(station: Instance, id: string)
    local location = station:GetAttribute("LocationName")
    Service.Publish({
        Type = "RareIngredientSpawned",
        IngredientId = id,
        DisplayName = deps.IngredientService.GetDefinition(id).DisplayName,
        Mystery = isMystery(id),
        LocationName = if typeof(location) == "string" and location ~= "" then location else station.Name,
        SoundType = "Mystery",
        Priority = if isMystery(id) then 10 else 0,
    })
end

function Service.Served(player: Player, ingredientIds: { string }, payout: number)
    for _, id in ingredientIds do
        if isMystery(id) then
            Service.Publish({
                Type = "MysteryServed",
                DisplayName = player.DisplayName,
                Payout = payout,
                SoundType = "Mystery",
                Priority = 10,
            })
            return
        end
    end
end

return Service
