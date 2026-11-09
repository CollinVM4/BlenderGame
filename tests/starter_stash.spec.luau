-- Authoritative starter records + real membership, theft and persistence boundary.
local tycoon = dependency.TycoonService
tycoon.Init({
    SessionStarted = inventory.InitializeTutorialStash,
    MemberChanged = inventory.BindPlayer,
    SessionEnded = inventory.CleanupSession,
})
local starter = loadModule("StarterStash")
local persistence = loadModule("StashPersistence")
local records = loadModule("StashRecords")
local function verify(actor)
    local snapshot = inventory.GetSnapshot(actor)
    local identities = {}
    for index, group in starter do
        local state = snapshot.Stash[index]
        check(
            state.SlotIndex == index and state.Count == 3 and state.Capacity == 3,
            "five ordered full ingredient slots"
        )
        check(state.Protected == (index <= 2), "only authored first two slots protected")
        for i, id in group.Ingredients do
            local unit = state.Ingredients[i]
            check(
                unit.IngredientId == id and table.find(ingredients.GetDefinition(id).Tags, group.Tag),
                "canonical category and ID"
            )
            check(not identities[unit.ItemId], "distinct unit identity even for duplicate ingredient IDs")
            identities[unit.ItemId] = true
        end
    end
    return identities
end
local owner, enemy = player(), player()
local ownerIds, enemyIds = verify(owner), verify(enemy)
for id in ownerIds do
    check(not enemyIds[id], "separate fresh owners have independent inventory")
end
check(
    not inventory.CanWithdraw(enemy, owner, 1) and not inventory.CanWithdraw(enemy, owner, 2),
    "locked starters never grant theft"
)
check(inventory.CanWithdraw(enemy, owner, 3), "ordinary starter slot initially eligible for theft")
setup(inventory.Withdraw(enemy, 3, owner), "steal cold starter normally")
check(slot(owner, 3).Count == 2 and inventory.GetStashRaidState(owner).State == "RaidActive", "normal raid opens")
inventory.ClearHeld(enemy)
now += 7
check(not inventory.CanWithdraw(enemy, owner, 4), "raid protection covers remaining unprotected starters")
now += 30
check(inventory.CanWithdraw(enemy, owner, 4), "normal protection expiry permits theft")
for index = 1, 5 do
    while slot(owner, index).Count > 0 do
        setup(inventory.Withdraw(owner, index), "owner drains starter stash")
        inventory.ClearHeld(owner)
    end
end
inventory.CleanupCharacter(owner)
inventory.InitializeTutorialStash(owner)
check(
    slot(owner, 1).Count == 0 and slot(owner, 5).Count == 0,
    "empty stash stays empty after reset/repeated initialization"
)
local plot = tycoon.GetPlot(owner)
tycoon.RemovePlayer(owner)
inventory.RemovePlayer(owner)
inventory.AddPlayer(owner)
setup(tycoon.AssignPlot(owner, plot), "reclaim same plot")
check(slot(owner, 1).Count == 0 and slot(owner, 5).Count == 0, "persisted emptied stash is not refilled on reclaim")
local teammate = player()
tycoon.RemovePlayer(teammate)
setup(tycoon.JoinSession(teammate, owner, tycoon.GetRequestContext(owner)), "teammate joins empty stash")
check(not inventory.InitializeTutorialStash(teammate), "teammate cannot seed shared stash")
check(slot(owner, 3).Count == 0, "teammate join does not refill owner stash")
-- Promotion keeps the same shared ledger and founding-owner save key.
carry(owner, "Apple")
setup(inventory.Deposit(owner, "Apple", 1), "store after initial grant was exhausted")
local keptId = slot(owner, 1).Ingredients[1].ItemId
tycoon.RemovePlayer(owner, function()
    inventory.RemovePlayer(owner)
end)
check(slot(teammate, 1).Ingredients[1].ItemId == keptId, "promotion preserves exact shared records")
tycoon.RemovePlayer(teammate)
local saved = storedStashes["Player_" .. owner.UserId]
check(
    saved.Slots[1].Ingredients[1].ItemId == keptId and saved.Lock == nil,
    "promoted session saves to founding owner's progression"
)
inventory.AddPlayer(owner)
setup(tycoon.AssignPlot(owner, plot), "founder returns")
check(
    slot(owner, 1).Ingredients[1].ItemId == keptId and slot(owner, 2).Count == 0,
    "restore preserves deposits and empty slots"
)
tycoon.RemovePlayer(owner)

-- A new module instance represents a new server; only the DataStore survives.
cache.StashPersistence = nil
local otherServer = loadModule("StashPersistence")
cache.StashPersistence = persistence
local creates = 0
local reopened = otherServer.Open(owner.UserId, function()
    creates += 1
    error("must never seed existing progression")
end)
setup(reopened, "new server loads saved progression")
local restored = records.Decode(reopened.Slots)
check(
    creates == 0 and restored[1].Ingredients[1].ItemId == keptId and restored[2].Count == 0,
    "server restart preserves one-time grant and exact contents"
)
otherServer.Close(reopened)

local active = persistence.Open(90001, function()
    return {}
end)
setup(active, "lease acquired")
check(not otherServer.Open(90001, function()
    error("locked record cannot create")
end), "second server cannot load active stash")
storedStashes.Player_90001.Lock.ExpiresAt = os.time() - 1
local replacement = otherServer.Open(90001, function()
    error("expired record still exists")
end)
setup(replacement, "expired server lease recovered")
persistence.Stage(active, { { Ingredients = {} } })
check(not persistence.Save(active), "stale server cannot overwrite replacement lease")
otherServer.Close(replacement)

storedStashes.Player_90002 = { Version = 1, Slots = {}, OtherField = "preserve" }
local existing = persistence.Open(90002, function()
    error("empty existing record cannot create")
end)
setup(existing, "existing empty record loads")
persistence.Close(existing)
check(
    storedStashes.Player_90002.OtherField == "preserve" and next(storedStashes.Player_90002.Slots) == nil,
    "existing empty record and unrelated fields preserved"
)
storedStashes.Player_90003 = { Legacy = "unknown schema" }
check(not persistence.Open(90003, function()
    error("unknown record cannot create")
end), "unknown existing schema fails closed")
check(storedStashes.Player_90003.Legacy == "unknown schema", "unknown existing record never overwritten")
storeFailure = true
check(not persistence.Open(90004, function()
    error("failed read cannot create")
end), "DataStore failure grants nothing")
storeFailure = false
check(storedStashes.Player_90004 == nil, "failed read never writes a default record")

-- Real inventory restore must reject a changed live ledger after a yielding load.
local late = player()
tycoon.RemovePlayer(late)
local latePlot = fixtures[late].Parent
beforeStoreUpdate = function()
    inventory.RemovePlayer(late)
    inventory.AddPlayer(late)
end
check(not tycoon.AssignPlot(late, latePlot), "late restore rejects replaced inventory")
check(slot(late, 1).Count == 0 and slot(late, 5).Count == 0, "late restore cannot overwrite live state")

-- Bad persisted payloads stay intact and cannot become a replacement starter kit.
local malformed = records.Encode(records.Decode({}))
malformed[1].Ingredients = { { IngredientId = "ImaginaryFruit", ItemId = "bad", RipenessStoredSeconds = 0 } }
check(not pcall(records.Decode, malformed), "invalid saved IDs fail validation")
local unit = loadModule("IngredientItem").New("Ice", "ripeness-roundtrip", "Farm")
unit.RipenessStoredSeconds = 12
local roundtrip = records.Decode({ { Ingredients = { unit } } })
check(
    roundtrip[1].Ingredients[1].Origin == "Farm" and roundtrip[1].Ingredients[1].RipenessStoredSeconds == 12,
    "restore preserves origin and accumulated ripeness"
)

-- Save retries carry the newest staged state, including mutations during a write.
local buffered = persistence.Open(90005, function()
    return {}
end)
setup(buffered, "open save retry case")
persistence.Stage(buffered, records.Encode(roundtrip))
storeFailure = true
check(not persistence.Save(buffered), "failed save reports failure")
storeFailure = false
beforeStoreUpdate = function()
    persistence.Stage(buffered, {})
end
setup(persistence.Save(buffered), "retry first snapshot")
setup(persistence.Save(buffered), "flush newer snapshot")
check(next(storedStashes.Player_90005.Slots) == nil, "mutation during an in-flight write survives subsequent save")
persistence.Close(buffered)
local emptyReload = otherServer.Open(90005, function()
    error("never refill emptied persistence")
end)
setup(emptyReload, "load emptied stash on another server")
check(next(emptyReload.Slots) == nil, "another server restores persisted empty stash")
otherServer.Close(emptyReload)

local savedSlots = records.Decode({})
savedSlots[1].Smoothie = smoothie("persisted-cup")
savedSlots[1].Smoothie.IngredientItems = {
    loadModule("IngredientItem").New("Strawberry", "cup-1", "Market"),
    loadModule("IngredientItem").New("Banana", "cup-2", "Farm"),
    loadModule("IngredientItem").New("Strawberry", "cup-3", "Unknown"),
}
local cupReload = records.Decode(records.Encode(savedSlots))[1]
check(
    cupReload.Count == 1 and cupReload.Capacity == 1 and cupReload.Smoothie.BlendId == "persisted-cup",
    "stored cups retain single-item capacity and identity"
)
check(cupReload.Smoothie.IngredientItems[2].Origin == "Farm", "stored cup unit provenance survives persistence")

local generate = services.HttpService.GenerateGUID
local attempts = 0
services.HttpService.GenerateGUID = function(...)
    attempts += 1
    if attempts == 5 then
        error("injected preparation failure")
    end
    return generate(...)
end
local failed = player()
services.HttpService.GenerateGUID = generate
check(
    tycoon.GetSessionId(failed) == nil and storedStashes["Player_" .. failed.UserId] == nil,
    "preparation failure commits neither partial stash nor persistent grant"
)
setup(tycoon.AssignPlot(failed, fixtures[failed].Parent), "retry fresh claim after preparation recovery")
verify(failed)
tycoon.RemovePlayer(failed)

local departing = player()
tycoon.RemovePlayer(departing)
local departingPlot = fixtures[departing].Parent
local departure = inventory.StashChanged:Connect(function(actor)
    if actor == departing and tycoon.GetSessionId(actor) then
        tycoon.RemovePlayer(actor)
    end
end)
check(not tycoon.AssignPlot(departing, departingPlot), "departure during initialization cannot report a live claim")
departure:Disconnect()
check(
    tycoon.GetSessionId(departing) == nil and slot(departing, 1).Count == 0,
    "departing claim releases the live stash"
)
setup(tycoon.AssignPlot(departing, departingPlot), "rejoin after interrupted claim")
verify(departing)
