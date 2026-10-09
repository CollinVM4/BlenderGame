local discovery = loadModule("DiscoveryService")
discovery.Init({ PlayerDataService = dataService })
shared.Events:FindFirstChild("DiscoveryAdded").FireClient = function() end
dependency.DiscoveryService = discovery
local p, humanoid = player(3)
discovery.PlayerAdded(p)
local loose = ingredients.Spawn("Strawberry", frame(), nil, true)
check(not discovery.HasIngredient(p, "Strawberry"), "spawn alone does not discover")
check(inventory.CarryWorldItem(p, loose) and discovery.HasIngredient(p, "Strawberry"), "committed pickup discovers")
local other = player(3)
discovery.PlayerAdded(other)
check(not discovery.HasIngredient(other, "Strawberry"), "nearby player does not discover")
check(press(p, "STORE", 3), "deposit acquired ingredient")
check(
    inventory.Withdraw(other, 3, p) and discovery.HasIngredient(other, "Strawberry"),
    "stash theft discovers for acquirer"
)
check(inventory.AddUnit(p, "Tire") and discovery.HasIngredient(p, "Tire"), "server grant discovers")
local claimed = ingredients.Spawn("Milk", frame(), nil, true)
check(
    inventory.ClaimWorldItem(p, claimed) and discovery.HasIngredient(p, "Milk"),
    "legacy claim discovers after consume"
)
local failed = ingredients.Spawn("Apple", frame(), nil, true)
local consume = ingredients.Consume
ingredients.Consume = function()
    return false
end
check(
    not inventory.CarryWorldItem(p, failed) and not discovery.HasIngredient(p, "Apple"),
    "failed consume cannot discover"
)
ingredients.Consume = consume
humanoid.EquipTool = function()
    error("failed equip")
end
check(
    not inventory.CarryWorldItem(p, failed) and not discovery.HasIngredient(p, "Apple"),
    "failed equip cannot discover"
)
