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
