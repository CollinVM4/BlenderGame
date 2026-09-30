--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Types = require(Shared.Types)
local Ingredients = require(Shared.Constants.Ingredients)
local Catalog = require(Shared.Constants.DiscoveryCatalog)
local DiscoveryService = {}
local deps: any
local active: { [Player]: boolean } = {}
local discovered: RemoteEvent

local function state(player: Player): Types.DiscoveryState?
    return if active[player] then deps.PlayerDataService.GetDiscoveryState(player) else nil
end
function DiscoveryService.GetSnapshot(player: Player): Types.DiscoveryState
    local source = state(player)
    return {
        Ingredients = if source then table.clone(source.Ingredients) else {},
        SpecialCustomers = if source then table.clone(source.SpecialCustomers) else {},
    }
end
function DiscoveryService.Init(services: any)
    deps = services
    discovered = Instance.new("RemoteEvent")
    discovered.Name = "DiscoveryAdded"
    discovered.Parent = Shared.Events
    local snapshot = Instance.new("RemoteFunction")
    snapshot.Name = "DiscoverySnapshot"
    snapshot.OnServerInvoke = function(player: Player): Types.DiscoveryState
        -- Roblox supplies the caller; arguments cannot select a different player's state.
        return DiscoveryService.GetSnapshot(player)
    end
    snapshot.Parent = Shared.Events
end
function DiscoveryService.PlayerAdded(player: Player)
    if deps.PlayerDataService.GetDiscoveryState(player) then
        active[player] = true
    end
end
function DiscoveryService.PlayerRemoving(player: Player)
    active[player] = nil
end
DiscoveryService.RemovePlayer = DiscoveryService.PlayerRemoving

local function discover(player: Player, kind: "Ingredient" | "SpecialCustomer", id: string): boolean
    local source = state(player)
    if not source then
        return false
    end
    local entries = if kind == "Ingredient" then source.Ingredients else source.SpecialCustomers
    if entries[id] then
        return false
    end
    entries[id] = true
    local event: Types.DiscoveryEvent = { Kind = kind, Id = id }
    discovered:FireClient(player, event)
    return true
end
function DiscoveryService.DiscoverIngredient(player: Player, id: string): boolean
    if type(id) ~= "string" or not Ingredients[id] then
        return false
    end
    return discover(player, "Ingredient", id)
end
function DiscoveryService.DiscoverSpecialCustomer(player: Player, id: string): boolean
    if type(id) ~= "string" or not Catalog.GetSpecialCustomer(id) then
        return false
    end
    return discover(player, "SpecialCustomer", id)
end
function DiscoveryService.HasIngredient(player: Player, id: string): boolean
    local source = state(player)
    return source ~= nil and source.Ingredients[id] == true
end
function DiscoveryService.HasSpecialCustomer(player: Player, id: string): boolean
    local source = state(player)
    return source ~= nil and source.SpecialCustomers[id] == true
end
return require(script.Parent.StudioServices).Wrap("DiscoveryService", DiscoveryService)
