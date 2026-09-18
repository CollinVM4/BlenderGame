do
    for capacity = 1, 3 do
        local p = player(capacity)
        for index = 1, capacity do
            grant(p, "capacity-" .. index)
        end
        check(inventory.GetCarryCount(p) == capacity, "smoothies use normal upgrade capacity")
        check(not inventory.GrantSmoothie(p, smoothie("overflow")), "capacity rejects extra smoothie")
        inventory.ClearHeld(p)
    end
    -- All-smoothie capacity is covered by the capacity loop above.
    for _, order in { { "I", "I", "S" }, { "I", "S", "S" } } do
        local p = player()
        for index, kind in order do
            if kind == "I" then
                carry(p)
            else
                grant(p, "mixed-" .. index)
            end
        end
        check(
            inventory.GetCarryCount(p) == 3 and not inventory.GrantSmoothie(p, smoothie("full")),
            "mixed full capacity"
        )
        inventory.ClearHeld(p)
    end
    local p = player()
    local original = smoothie("copied")
    check(inventory.GrantSmoothie(p, original), "metadata grant")
    original.Ingredients[1] = "Tire"
    local snapshot = inventory.GetHeldSmoothie(p)
    check(snapshot.Ingredients[1] == "Strawberry", "grant copies metadata")
    snapshot.Ingredients[2] = "Tire"
    check(inventory.GetHeldSmoothie(p).Ingredients[2] == "Banana", "read copies metadata")
    check(not inventory.GrantSmoothie(p, smoothie("bad", { "Banana", "Banana" })), "reject fewer than three")
    check(not inventory.GrantSmoothie(p, smoothie("bad", { "Banana", "Banana", "unknown" })), "reject unknown IDs")
    inventory.ClearHeld(p)
end

for _, lifecycle in { "unequip", "death", "character", "destroy" } do
    local p, h = player()
    grant(p, "bottom")
    carry(p)
    grant(p, "top")
    local t = tool(p)
    if lifecycle == "unequip" then
        t.Parent = p:FindFirstChildOfClass("Backpack")
        t.Unequipped:Fire()
        check(inventory.GetCarryCount(p) == 3, "unequip retains selectable smoothies and overhead ingredients")
        inventory.CleanupCharacter(p)
    elseif lifecycle == "death" then
        h.Died:Fire()
    elseif lifecycle == "character" then
        p.CharacterRemoving:Fire(p.Character)
    else
        t:Destroy()
        check(inventory.GetCarryCount(p) == 2, "destroying one Tool preserves other reservations")
        inventory.CleanupCharacter(p)
    end
    check(inventory.GetCarryCount(p) == 0, lifecycle .. " cleanup clears all, including lower smoothie")
end

do
    local p, h = player()
    carry(p)
    grant(p, "stash-roundtrip")
    local t = tool(p)
    check(press(p), "store smoothie over ingredient")
    local saved = slot(p)
    check(
        saved.ItemType == "Smoothie" and saved.Count == 1 and saved.Capacity == 1 and saved.IngredientId == nil,
        "smoothie slot shape"
    )
    check(not press(p) and slot(p).Count == 1, "smoothie STORE burst never reverses or stores ingredient")
    check(not inventory.Deposit(p, "Banana", 3), "ingredient cannot stack into smoothie slot")
    grant(p, "second")
    check(not press(p), "second smoothie cannot stack")
    inventory.ConsumeHeldSmoothie(p)
    check(inventory.Deposit(p, "Banana", 4), "ingredient remains stashable")
    saved.Smoothie.Ingredients[1] = "Tire"
    check(inventory.Withdraw(p, 3), "take smoothie")
    local taken = inventory.GetHeldSmoothie(p)
    check(
        taken.BlendId == "stash-roundtrip" and table.concat(taken.Ingredients, ",") == "Strawberry,Banana,Strawberry",
        "roundtrip IDs/order/duplicates exact and snapshot isolated"
    )
    check(slot(p).Count == 0 and slot(p).Smoothie == nil and slot(p).ItemType == nil, "empty slot clears metadata")
    now += 1
    check(not press(p, 4), "smoothie cannot enter ingredient slot")
    check(press(p, 3), "restore smoothie to empty slot")
    check(not press(p, 3), "exhausted STORE cannot reverse")
    check(press(p, 3), "later press can TAKE")
    check(not press(p, 3) and inventory.GetCarryCount(p) == 1, "exhausted TAKE cannot reverse")
    check(press(p, 1), "store protected slot")
    -- Generic foreign/protected access is covered by stash transaction tests.
    template.Parent = nil
    check(
        not inventory.Withdraw(p, 1) and slot(p, 1).Smoothie.BlendId == taken.BlendId,
        "failed geometry preserves stored smoothie"
    )
    template.Parent = storage
    local backpack = p:FindFirstChildOfClass("Backpack")
    backpack.Parent = nil
    check(not inventory.Withdraw(p, 1), "failed equip rolls back stash withdrawal")
    check(
        slot(p, 1).Count == 1 and slot(p, 1).Capacity == 1 and slot(p, 1).Smoothie.BlendId == taken.BlendId,
        "rollback restores complete slot"
    )
    backpack.Parent = p
    -- Shared alive/distance authorization is owned by stash_interaction.
    check(inventory.Withdraw(p, 1), "retry succeeds")
    inventory.ClearHeld(p)
end

do
    local p = player()
    local button = references[p].TurbineWheel
    local first = complete(p)
    check(blend.Dispense(p, button), "first dispense")
    check(
        inventory.GetHeldSmoothie(p).BlendId == first and inventory.GetCarryCount(p) == 1,
        "exactly one authoritative reservation"
    )
    check(not blend.Dispense(p, button) and inventory.GetCarryCount(p) == 1, "same batch cannot dispense twice")
    flush()
    check(blend.GetSnapshot(p).State == "EMPTY" and not blend.Dispense(p, button), "reset cannot replay batch")
    local second = complete(p)
    check(blend.Dispense(p, button) and inventory.GetCarryCount(p) == 2, "existing smoothie permits second batch")
    check(first ~= second and inventory.GetHeldSmoothie(p).BlendId == second, "distinct batch identity")
    flush()
    carry(p)
    local third = complete(p)
    local ok, reason = blend.Dispense(p, button)
    check(
        not ok and reason == "Inventory full" and inventory.GetCarryCount(p) == 3,
        "full inventory fails without loss"
    )
    flush()
    check(
        blend.GetSnapshot(p).State == "COMPLETE" and blend.GetSnapshot(p).Result.BlendId == third,
        "failed dispense preserves completed batch"
    )
    inventory.ThrowHeld(p)
    template.Parent = nil
    check(
        not blend.Dispense(p, button) and blend.GetSnapshot(p).State == "COMPLETE",
        "missing template leaves batch retryable"
    )
    template.Parent = storage
    local grantMethod = inventory.GrantSmoothie
    local attempts = 0
    inventory.GrantSmoothie = function(owner, data)
        attempts += 1
        check(not blend.Dispense(owner, button), "reentrant dispense rejected")
        return grantMethod(owner, data)
    end
    check(blend.Dispense(p, button) and attempts == 1 and inventory.GetCarryCount(p) == 3, "retry grants exactly once")
    inventory.GrantSmoothie = grantMethod
    check(inventory.ConsumeHeldSmoothie(p).BlendId == third, "third smoothie identity")
    check(inventory.ConsumeHeldSmoothie(p).BlendId == second, "second smoothie survives later dispense")
    check(inventory.ConsumeHeldSmoothie(p).BlendId == first, "first smoothie survives later dispense")
    check(inventory.ConsumeHeldSmoothie(p) == nil, "no extra smoothie")
    flush()
end

do
    local p = player()
    local requests = loadModule("CustomerRequests").Definitions
    local savedRequests = table.clone(requests)
    table.clear(requests)
    requests[1] = { Id = "TestRed", DisplayText = "Red", RequiredTags = { "Red" }, BasePayout = 25, MinJumpTier = 0 }
    grant(p, "unselected")
    grant(p, "served")
    check(customer.SpawnForPlayer(p) ~= nil, "customer spawns")
    flush()
    flush()
    check(customer.GetSnapshot(p).Ready, "customer ready")
    local t = tool(p)
    t:SetAttribute("Ingredients", "Tire,Tire,Tire")
    t:SetAttribute("BlendId", "forged")
    check(blend.GetCup(p).BlendId == "served", "tool attributes do not authorize contents")
    check(not blend.GetCup(p, instance("Tool")), "foreign Tool rejected")
    local valid = customer.ValidateRequest(blend.GetCup(p), requests[1])
    check(
        valid and table.concat(blend.GetCup(p).Ingredients, ",") == "Strawberry,Banana,Strawberry",
        "serve validation reads authoritative three IDs"
    )
    local consume = inventory.ConsumeHeldSmoothie
    inventory.ConsumeHeldSmoothie = function(owner)
        check(not customer.Serve(owner), "reentrant serve cannot pay")
        return consume(owner)
    end
    check(customer.Serve(p), "customer serves top smoothie")
    inventory.ConsumeHeldSmoothie = consume
    check(dataService.GetCash(p) == 25 and completedServes == 1, "one payout and completion")
    check(inventory.GetHeldSmoothie(p).BlendId == "unselected", "lower smoothie and shared tool survive serving")
    check(not customer.Serve(p) and dataService.GetCash(p) == 25, "repeated request cannot double pay")
    carry(p)
    check(customer.SpawnForPlayer(p) ~= nil, "next customer spawns")
    flush()
    flush()
    check(
        not customer.Serve(p) and inventory.GetCarryCount(p) == 2 and customer.GetSnapshot(p).Ready,
        "ingredient cannot serve or lose pending customer"
    )
    inventory.ClearHeld(p)
    table.clear(requests)
    for _, request in savedRequests do
        table.insert(requests, request)
    end
end
print("PASS: " .. count .. " smoothie foundation checks (mocked Roblox boundary).")
