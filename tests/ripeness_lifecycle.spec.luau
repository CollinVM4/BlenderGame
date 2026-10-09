dependency.PlayerDataService.HasEntitlement = function()
    return false
end
local owner, enemy = player(2), player(2)
local signals = 0
local setAttribute = owner.SetAttribute
owner.SetAttribute = function(self, name, value)
    if name == "RipenessTutorialShown" and value == true then
        signals += 1
    end
    setAttribute(self, name, value)
end
grant(owner, "tutorial-smoothie")
setup(press(owner, "STORE", 1), "store smoothie")
check(signals == 0, "smoothie store does not signal ripeness")
carry(owner, "Strawberry")
check(not inventory.Deposit(owner, "Strawberry", 1) and signals == 0, "failed store does not signal")
setup(inventory.Deposit(owner, "Strawberry", 3), "store first strawberry")
local first = slot(owner).Ingredients[1].ItemId
check(signals == 1, "first successful ingredient store signals once")
now += 40
carry(owner, "Strawberry")
setup(inventory.Deposit(owner, "Strawberry", 3), "second strawberry")
now += 55
carry(owner, "Strawberry")
setup(inventory.Deposit(owner, "Strawberry", 3), "third strawberry")
now += 25
local refreshed = 0
inventory.StashChanged:Connect(function(p)
    if p == owner then
        refreshed += 1
    end
end)
services.RunService.Heartbeat:Fire(1)
check(refreshed == 1, "idle threshold crossing publishes stash refresh")
local snapshot = slot(owner)
check(snapshot.Value == 9750 and snapshot.Ingredients[1].IsRipe, "mixed stack total uses individual ripeness")
check(
    snapshot.Ingredients[2].RipenessStoredAt ~= snapshot.Ingredients[3].RipenessStoredAt,
    "snapshot exposes independent timestamps"
)
snapshot.Ingredients[2].IsRipe = true
check(not slot(owner).Ingredients[2].IsRipe, "snapshot cannot mutate authoritative units")
setup(inventory.Withdraw(enemy, 3, owner), "steal ripe item first")
local carryRoot = enemy.Character:FindFirstChild("HumanoidRootPart")
local heldValue = carryRoot:FindFirstChild("CarryValue")
check(
    heldValue:FindFirstChild("Value").Text == "$4K" and not heldValue:FindFirstChild("RipenessDetails"),
    "stolen ripe ingredient shows only formatted effective value"
)
local thrown = inventory.ThrowHeld(enemy)
local ripe = ingredients.GetRecord(thrown).Item
check(ripe.ItemId == first and ripe.IsRipe and ripe.RipenessStoredAt == nil, "steal and throw preserve ripe identity")
check(
    thrown:GetAttribute("IsRipe") == true and thrown:GetAttribute("EffectiveIngredientValue") == 3750,
    "thrown ripe ingredient exposes persistent world metadata and effective value"
)
setup(inventory.CarryWorldItem(enemy, thrown), "pick ripe item back up")
check(
    carryRoot:FindFirstChild("CarryValue"):FindFirstChild("Value").Text == "$4K"
        and not carryRoot:FindFirstChild("CarryValue"):FindFirstChild("RipenessDetails"),
    "world pickup restores ripe carried value without metadata"
)
setup(inventory.Deposit(enemy, "Strawberry", 3), "store ripe item with new owner")
check(slot(enemy).Ingredients[1].IsRipe and slot(enemy).Value == 3750, "new stash retains ripe value")
setup(inventory.Withdraw(enemy, 3, owner), "steal most-aged fresh next")
local partialWorld = inventory.ThrowHeld(enemy)
local partial = ingredients.GetRecord(partialWorld).Item
check(partial.RipenessStoredSeconds == 80 and not partial.IsRipe, "theft commits most-aged fresh progress")
now += 300
setup(inventory.CarryWorldItem(enemy, partialWorld), "partial world pickup")
setup(inventory.Deposit(enemy, "Strawberry", 4), "resume partial in another stash")
now += 39
check(not slot(enemy, 4).Ingredients[1].IsRipe, "carrying and world time did not age partial")
now += 1
check(slot(enemy, 4).Ingredients[1].IsRipe, "partial resumes and resolves lazily")
check(signals == 1, "subsequent stores do not repeat tutorial")

-- Ripe unit survives the real world -> blender -> cup -> stash -> theft path.
setup(inventory.Withdraw(enemy, 3), "take original ripe unit")
local source = inventory.ThrowHeld(enemy)
local input = references[enemy].BlenderInput
input.Overlaps = { source }
setup(blend.TryInput(enemy, source, input), "blend ripe source")
for _ = 1, 2 do
    local fresh = ingredients.Spawn("Strawberry", frame(), nil, true)
    input.Overlaps = { fresh }
    setup(blend.TryInput(enemy, fresh, input), "blend fresh source")
end
setup(
    blend.AddProgress(enemy, references[enemy].TurbineWheel, loadModule("Economy").RequiredProgress),
    "finish mixed smoothie"
)
setup(blend.Dispense(enemy, references[enemy].TurbineWheel), "dispense mixed smoothie")
local cup = inventory.GetHeldSmoothie(enemy)
check(
    cup.IngredientItems[1].ItemId == first and cup.IngredientItems[1].IsRipe,
    "cup preserves physical ingredient metadata"
)
local result = smoothieItem.Result(cup)
local request = {
    RequiredIngredients = { "Strawberry", "Strawberry", "Strawberry" },
    ExactIngredients = true,
    RequiredTags = {},
    BasePayout = 250,
}
local evaluation = customer.EvaluateOrder(result, request)
local payout, raw = customer.CalculateOrderPayout(enemy, result, request, evaluation)
check(
    raw == 9750 and evaluation.Grade == "A" and payout == 12500,
    "specific payout applies grade after effective per-unit subtotal"
)
request.Wildcard = true
local wildcard = loadModule("CustomerRequests").WildcardRequest
local wildPayout, wildRaw =
    customer.CalculateOrderPayout(enemy, result, wildcard, customer.EvaluateOrder(result, wildcard))
check(wildRaw == 9750 and wildPayout == 10000, "wildcard keeps 1.0 grade multiplier")
now += 1
setup(press(enemy, "TAKE", 5), "store mixed smoothie")
check(slot(enemy, 5).Value == 9750, "smoothie stash value uses same helper")
setup(inventory.Withdraw(owner, 5, enemy), "steal mixed smoothie")
check(inventory.GetHeldSmoothie(owner).IngredientItems[1].IsRipe, "smoothie transfer keeps per-unit ripeness")

-- Failed withdrawal keeps the original aging interval intact.
local rollback = player(2)
carry(rollback, "Strawberry")
setup(inventory.Deposit(rollback, "Strawberry", 3), "seed rollback")
now += 40
local backpack = rollback:FindFirstChildOfClass("Backpack")
backpack.Parent = nil
check(not inventory.Withdraw(rollback, 3), "failed equip rejects withdrawal")
backpack.Parent = rollback
now += 80
check(slot(rollback).Ingredients[1].IsRipe, "failed withdrawal loses no stash time")

-- The legacy count-facing API also reserves physical units internally.
local legacy = player()
local legacyUnit = loadModule("IngredientItem").New("Strawberry", "legacy-partial")
legacyUnit.RipenessStoredSeconds = 45
local legacyWorld = ingredients.Spawn("Strawberry", frame(), nil, true, { Item = legacyUnit })
setup(inventory.ClaimWorldItem(legacy, legacyWorld), "legacy claim")
local released = inventory.ReleaseUnit(legacy, "Strawberry")
check(ingredients.GetRecord(released).Item.RipenessStoredSeconds == 45, "legacy release retains partial progress")
setup(inventory.ClaimWorldItem(legacy, released), "legacy reclaim")
local dropped = inventory.DropOne(legacy)
check(ingredients.GetRecord(dropped).Item.ItemId == "legacy-partial", "legacy drop retains physical identity")
