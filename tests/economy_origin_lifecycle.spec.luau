-- Real server record creation, inventory release/theft, stash and blender boundaries.
dependency.PlayerDataService.HasEntitlement = function()
    return false
end
local owner = player(2)
local thief = player(2)
local items = loadModule("IngredientItem")
local function worldUnit(origin)
    return ingredients.Spawn("Melon", frame(), nil, true, { Origin = origin })
end
local farm = worldUnit("Farm")
local farmId = ingredients.GetRecord(farm).Item.ItemId
setup(inventory.CarryWorldItem(owner, farm), "carry farm unit")
local dropped = inventory.DropHeld(owner)
check(dropped and ingredients.GetRecord(dropped).Item.Origin == "Farm", "inventory drop retains farm origin")
setup(inventory.CarryWorldItem(owner, dropped), "farm re-pickup")
local redrop = inventory.DropHeld(owner)
check(
    ingredients.GetRecord(redrop).Item.ItemId == farmId and ingredients.GetRecord(redrop).Item.Origin == "Farm",
    "farm provenance survives repeated release"
)
redrop:Destroy()
local market = worldUnit("Market")
local marketId = ingredients.GetRecord(market).Item.ItemId
setup(inventory.CarryWorldItem(owner, market), "carry market loot")
check(
    inventory.DropCarriedIngredients(owner, "BatStun", vec(0, 0, -1)) == 1,
    "authoritative theft knock-loose boundary"
)
local loose
for _, object in services.CollectionService:GetTagged("IngredientWorldItem") do
    local record = ingredients.GetRecord(object)
    if record and record.Item.ItemId == marketId then
        loose = object
    end
end
setup(loose ~= nil and inventory.CarryWorldItem(thief, loose), "another player picks stolen loot")
local stolenDrop = inventory.DropHeld(thief)
check(
    ingredients.GetRecord(stolenDrop).Item.Origin == "Market",
    "stolen and dropped market loot retains premium source"
)
setup(inventory.CarryWorldItem(owner, stolenDrop), "third pickup keeps record")
setup(inventory.Deposit(owner, "Melon", 3), "stash market ingredient")
check(slot(owner).Ingredients[1].Origin == "Market", "stash stores provenance")
setup(inventory.Withdraw(owner, 3), "withdraw market ingredient")
local thrown = inventory.ThrowHeld(owner)
check(ingredients.GetRecord(thrown).Item.Origin == "Market", "stash-to-throw preserves provenance")
local input = references[owner].BlenderInput
input.Overlaps = { thrown }
setup(blend.TryInput(owner, thrown, input), "blend preserved market unit")
for _, origin in { "Farm", "Muncher" } do
    local object = worldUnit(origin)
    input.Overlaps = { object }
    setup(blend.TryInput(owner, object, input), "blend home output")
end
setup(
    blend.AddProgress(owner, references[owner].TurbineWheel, loadModule("Economy").RequiredProgress),
    "finish provenance blend"
)
setup(blend.Dispense(owner, references[owner].TurbineWheel), "dispense provenance blend")
local result = inventory.GetHeldSmoothie(owner)
check(
    result.IngredientItems[1].Origin == "Market"
        and result.IngredientItems[2].Origin == "Farm"
        and result.IngredientItems[3].Origin == "Muncher",
    "carry stash blend cup retains ordered origins"
)
inventory.ClearHeld(owner)
for _, origin in { "Farm", "Market", "Muncher", "Event", "Unknown" } do
    local record = items.New("Melon", "existing-" .. origin, origin)
    local object = ingredients.Spawn("Melon", frame(), nil, true, { Item = record, Origin = "Market" })
    check(
        ingredients.GetRecord(object).Item.Origin == origin and record.Origin == origin,
        "existing record overrides fresh-origin option"
    )
    object:Destroy()
end
local missing = items.New("Melon", "legacy")
missing.Origin = nil
local object = ingredients.Spawn("Melon", frame(), nil, true, { Item = missing, Origin = "Market" })
check(ingredients.GetRecord(object).Item.Origin == nil, "respawn cannot launder legacy missing origin")
object:Destroy()
local granted = {}
for _ = 1, 3 do
    setup(inventory.GrantIngredient(owner, "Melon"), "grant unknown provenance")
    local output = inventory.DropHeld(owner)
    local unit = ingredients.GetRecord(output).Item
    check(unit.Origin == "Unknown", "grant creates Unknown unit")
    table.insert(granted, unit)
    output:Destroy()
end
local request = { RequiredTags = { "Sweet" }, BasePayout = 250 }
local amount = customer.CalculateOrderPayout(
    owner,
    { Ingredients = { "Melon", "Melon", "Melon" }, IngredientItems = granted },
    request
)
check(amount == math.round((135000 + 250) * 1.25), "granted high-tier ingredients pay value without source bonus")
print("PASS: origin lifecycle")
