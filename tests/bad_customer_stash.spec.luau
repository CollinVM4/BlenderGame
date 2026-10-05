-- Real authoritative inventory boundary: only unlocked ingredient entries disappear.
local owner = player(3)
local other = player(3)
local authority = dependency.TycoonService
local id = authority.GetSessionId(owner)
local function store(p, ingredient, index)
    setup(inventory.GrantIngredient(p, ingredient), "grant source unit")
    setup(inventory.Deposit(p, ingredient, index), "store source unit")
end
store(owner, "Banana", 1)
store(owner, "Apple", 2)
store(owner, "Strawberry", 3)
store(owner, "Banana", 3)
store(other, "Apple", 3)
grant(owner, "protected-smoothie")
setup(inventory.Deposit(owner, "ignored", 4) == false, "legacy ingredient deposit never deposits smoothie")
setup(press(owner, 4), "store smoothie in unlocked slot")
setup(inventory.GrantIngredient(owner, "Ice"), "retain carried ingredient")
local before = inventory.GetSnapshot(owner)
local unit = inventory.RemoveThiefIngredient(owner, id)
local after = inventory.GetSnapshot(owner)
check(unit ~= nil and after.Stash[3].Count == 1, "exactly one unlocked ingredient removed")
check(after.Stash[1].Count == 1 and after.Stash[2].Count == 1, "both protected slots retained")
check(after.Stash[4].Smoothie.BlendId == before.Stash[4].Smoothie.BlendId, "unprotected smoothie storage excluded")
check(inventory.GetSnapshot(other).Stash[3].Count == 1, "other plot stash retained")
check(after.CarryCount == before.CarryCount, "carried inventory unchanged")
local remaining = after.Stash[3].Ingredients[1].ItemId
check(unit.ItemId ~= remaining, "removed ingredient is one persistent entry")
check(not inventory.RemoveThiefIngredient(owner, authority.GetSessionId(other)), "foreign session token cannot remove")
setup(inventory.RemoveThiefIngredient(owner, id), "remove final eligible entry")
check(slot(owner, 3).Count == 0 and slot(owner, 3).ItemType == nil, "empty slot cleared through inventory lifecycle")
check(not inventory.RemoveThiefIngredient(owner, id), "empty ingredient stash is no-op")
-- The original record crosses thief custody -> registry -> pickup -> throw -> stash.
local recoveryOwner = player(3)
local itemState = loadModule("IngredientItem")
for _, age in { 40, loadModule("Ripeness").RipenessSeconds } do
    store(recoveryOwner, "Strawberry", 3)
    local original = slot(recoveryOwner).Ingredients[1]
    now += age
    local custody, observed = nil, false
    local listener = inventory.StashChanged:Connect(function(p)
        if p == recoveryOwner then
            observed = custody ~= nil and slot(p).Count == 0
        end
    end)
    local stolenUnit = inventory.RemoveThiefIngredient(
        recoveryOwner,
        authority.GetSessionId(recoveryOwner),
        function(unit)
            custody = unit
        end
    )
    listener:Disconnect()
    check(
        observed and custody == stolenUnit and stolenUnit.ItemId == original.ItemId,
        "exact stolen identity transferred before stash signals"
    )
    check(
        stolenUnit.RipenessStoredSeconds == age and stolenUnit.RipenessStoredAt == nil,
        "theft freezes accumulated stash age without resetting it"
    )
    local value = itemState.GetIngredientValue(stolenUnit, now)
    now += 300
    local world = inventory.ReleaseThiefIngredient(stolenUnit, frame(2, 3, 4))
    local record = ingredients.GetRecord(world)
    check(
        record.Claimable and record.Owner == nil and record.Item.ItemId == original.ItemId,
        "recovery publishes the original unit into the normal loose registry"
    )
    check(
        record.Item.IsRipe == stolenUnit.IsRipe
            and record.Item.RipenessStoredSeconds == age
            and world:GetAttribute("EffectiveIngredientValue") == value,
        "world recovery preserves ripe/fresh progress and value"
    )
    check(
        slot(recoveryOwner).Count == 0 and inventory.GetCarryCount(recoveryOwner) == 0,
        "recovery does not automatically restore stash or carried inventory"
    )
    setup(inventory.CarryWorldItem(recoveryOwner, world), "normal pickup of recovered stolen unit")
    check(
        ingredients.GetRecord(world) == nil and inventory.GetCarryCount(recoveryOwner) == 1,
        "normal pickup transfers world ownership exactly once"
    )
    local thrown = inventory.ThrowHeld(recoveryOwner)
    check(
        ingredients.GetRecord(thrown).Item.ItemId == original.ItemId,
        "recovered ingredient supports ordinary throw with same identity"
    )
    setup(inventory.CarryWorldItem(recoveryOwner, thrown), "pick thrown recovered unit")
    setup(inventory.Deposit(recoveryOwner, "Strawberry", 3), "physically restore stolen unit to stash")
    check(
        slot(recoveryOwner).Ingredients[1].ItemId == original.ItemId
            and slot(recoveryOwner).Ingredients[1].RipenessStoredSeconds == age,
        "physical stash recovery preserves original identity and age"
    )
    setup(inventory.RemoveThiefIngredient(recoveryOwner, authority.GetSessionId(recoveryOwner)), "clear next case")
end
store(recoveryOwner, "Apple", 3)
local cleanupDrop = inventory.ReleaseThiefIngredient(
    inventory.RemoveThiefIngredient(recoveryOwner, authority.GetSessionId(recoveryOwner)),
    frame()
)
ingredients.ClearLooseIngredients()
check(ingredients.GetRecord(cleanupDrop) == nil, "recovered loot follows ordinary loose cleanup")
-- Dismissal never reaches the real inventory or blender consumption APIs.
complete(owner)
grant(owner, "prepared-cup-to-keep")
local readyBatch = blend.GetSnapshot(owner)
local ownedCup = inventory.GetHeldSmoothie(owner)
setup(customer.ActivateForPlayer(owner), "activate customer business")
local legitimate = customer.SpawnForPlayer(owner)
setup(legitimate, "spawn legitimate customer")
flush()
setup(customer.TakeOrder(owner, legitimate), "take legitimate order")
check(customer.DismissCustomer(owner, legitimate, "RejectedByOwner"), "dismiss real-inventory order")
check(inventory.GetHeldSmoothie(owner).BlendId == ownedCup.BlendId, "dismissal preserves prepared held smoothie")
check(
    blend.GetSnapshot(owner).Result.BlendId == readyBatch.Result.BlendId,
    "dismissal preserves completed blender batch"
)
check(slot(owner, 1).Count == 1 and slot(owner, 2).Count == 1, "dismissal preserves stored ingredients")
check(not customer.Serve(owner, legitimate), "dismissed real order cannot consume later")
print("PASS bad customer authoritative stash removal", count, "assertions;", setupCount, "setup")
