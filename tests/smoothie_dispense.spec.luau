-- Authoritative dispensing home; independently runnable from legacy smoothie state.
do
    local p = player(1) -- Base carry tier: the configured three-item capacity.
    local button = references[p].TurbineWheel
    check(not blend.Dispense(p, button), "empty blender is not ready")
    local first = complete(p)
    local outsider = player(1)
    check(not blend.Dispense(outsider, button), "foreign player cannot dispense owned batch")
    p.Near = false
    check(not blend.Dispense(p, button), "distance validation still rejects remote dispensing")
    p.Near = true
    local poured, _, result = blend.Dispense(p, button)
    check(
        poured and result and result.BlendId == first,
        "successful dispense returns the committed batch for the reveal"
    )
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
    local ok, reason, failedResult = blend.Dispense(p, button)
    check(
        not ok and reason == "Inventory full" and failedResult == nil and inventory.GetCarryCount(p) == 3,
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
    local items = loadModule("IngredientItem")
    local ingredients = loadModule("Ingredients")
    local summary = loadModule("SmoothieSummary")
    local data = smoothie("breakdown", { "Apple", "Dragon_Fruit", "Banana" })
    local ripe = items.New("Apple", "ripe-apple")
    ripe.IsRipe = true
    data.IngredientItems = { ripe, items.New("Dragon_Fruit", "dragon"), items.New("Banana", "banana") }
    local details = summary.Build(smoothieItem.Result(data), now)
    check(details.BaseValue == ingredients.Apple.Value + ingredients.Banana.Value, "base excludes mystery contribution")
    check(details.MysteryValue == ingredients.Dragon_Fruit.Value, "mystery uses the real ingredient value")
    check(details.RipenessValue == items.GetIngredientValue(ripe, now) - ingredients.Apple.Value, "ripe premium")
    check(details.Value == items.GetSmoothieValue(data, now), "every beat adds up to the server's blend value")
    check(details.Colors == "Red / Yellow", "colors come from grading tags, regardless of cup tint")
    check(details.Description:find("Fruit", 1, true) ~= nil, "blend description reflects ingredient traits")
end
