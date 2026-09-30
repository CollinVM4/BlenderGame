cache.StudioServices = {
    Wrap = function(_, service)
        return service
    end,
}
local data = loadModule("PlayerDataService")
local discovery = loadModule("DiscoveryService")
discovery.Init({ PlayerDataService = data })
local remote = shared.Events:FindFirstChild("DiscoveryAdded")
local events = {}
remote.FireClient = function(_, recipient, event)
    table.insert(events, { Player = recipient, Payload = event })
end
local p, other = instance("Player"), instance("Player")
data.AddPlayer(p)
data.AddPlayer(other)
discovery.PlayerAdded(p)
discovery.PlayerAdded(other)
check(next(discovery.GetSnapshot(p).Ingredients) == nil, "new players start empty")
check(discovery.DiscoverIngredient(p, "Strawberry"), "first ingredient discovery")
check(not discovery.DiscoverIngredient(p, "Strawberry"), "ingredient discovery is idempotent")
check(not discovery.DiscoverIngredient(p, "invalid"), "invalid ingredient rejected")
check(discovery.DiscoverSpecialCustomer(p, "caseoh"), "first special encounter")
check(not discovery.DiscoverSpecialCustomer(p, "caseoh"), "special encounter is idempotent")
check(not discovery.DiscoverSpecialCustomer(p, "WalterWhite"), "display name is not a canonical ID")
local requests = loadModule("CustomerRequests")
requests.NPCs.testRegular = { Type = "Regular", RequestId = "Caseoh" }
check(not discovery.DiscoverSpecialCustomer(p, "testRegular"), "explicit regular mapping cannot unlock a special")
check(not discovery.DiscoverSpecialCustomer(p, "invalid"), "invalid customer rejected")
check(#events == 2 and events[1].Player == p and events[2].Player == p, "only new discoveries notify their owner")
check(events[1].Payload.Kind == "Ingredient" and events[1].Payload.Id == "Strawberry", "ingredient delta shape")
check(events[2].Payload.Kind == "SpecialCustomer" and events[2].Payload.Id == "caseoh", "customer delta shape")
local snapshotRemote = shared.Events:FindFirstChild("DiscoverySnapshot")
local snapshot = snapshotRemote.OnServerInvoke(p, other)
check(snapshot.Ingredients.Strawberry and snapshot.SpecialCustomers.caseoh, "initial snapshot includes both categories")
check(next(snapshotRemote.OnServerInvoke(other, p).Ingredients) == nil, "caller cannot request another player's data")
snapshot.Ingredients.Strawberry = nil
snapshot.SpecialCustomers.caseoh = nil
check(discovery.HasIngredient(p, "Strawberry") and discovery.HasSpecialCustomer(p, "caseoh"), "snapshot is isolated")
local saved = data.GetSnapshot(p)
check(
    saved.Discovery.Ingredients.Strawberry and saved.Discovery.SpecialCustomers.caseoh,
    "canonical player snapshot owns discovery"
)
saved.Discovery.Ingredients.Strawberry = nil
check(discovery.HasIngredient(p, "Strawberry"), "player data snapshot is isolated")
-- Simulate an older constructor with no Discovery field; the service still owns initialization.
cache.PlayerDataService = nil
sources.PlayerDataService =
    string.gsub(sources.PlayerDataService, "        Discovery = { Ingredients = {}, SpecialCustomers = {} },", "")
local legacy = loadModule("PlayerDataService")
legacy.AddPlayer(other)
local migrated = legacy.GetDiscoveryState(other)
check(
    next(migrated.Ingredients) == nil and next(migrated.SpecialCustomers) == nil,
    "missing discovery initializes safely"
)
migrated.Ingredients.Strawberry = true
migrated.SpecialCustomers = nil
check(
    legacy.GetDiscoveryState(other).Ingredients.Strawberry
        and next(legacy.GetDiscoveryState(other).SpecialCustomers) == nil,
    "partial migration preserves discoveries"
)
discovery.PlayerRemoving(p)
check(
    not discovery.DiscoverIngredient(p, "Banana") and next(discovery.GetSnapshot(p).Ingredients) == nil,
    "removed player is inactive"
)
data.RemovePlayer(p)
check(data.GetDiscoveryState(p) == nil, "player cleanup releases canonical state")
data.AddPlayer(p)
discovery.PlayerAdded(p)
check(not discovery.HasIngredient(p, "Strawberry"), "fresh in-memory session has no stale discovery")
local catalog = loadModule("DiscoveryCatalog")
local ingredientsCatalog = catalog.GetIngredients()
local definitions = loadModule("Ingredients")
local size = 0
for _ in definitions do
    size += 1
end
check(#ingredientsCatalog == size, "catalog includes every ingredient, even locked entries")
local previous = 0
for _, entry in ingredientsCatalog do
    local rank = catalog.RarityOrder[entry.Rarity]
    check(
        rank >= previous
            and entry.Value == definitions[entry.Id].Value
            and entry.JumpLocation == definitions[entry.Id].JumpLocation,
        "catalog orders canonical ingredient metadata by rarity"
    )
    previous = rank
end
previous = -1
for _, entry in catalog.GetSpecialCustomers() do
    check(
        entry.Id ~= "testRegular" and entry.MinJumpTier >= previous,
        "special catalog excludes regulars and sorts by jump"
    )
    check(
        entry.MinJumpTier == requests.GetForNPC(entry.Id).MinJumpTier,
        "jump requirement comes from canonical request"
    )
    previous = entry.MinJumpTier
end
