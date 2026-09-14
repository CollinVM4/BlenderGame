-- Mixed carry integration: removing the bottom ingredient preserves usable survivors.
do
    local p = player()
    carry(p)
    grant(p, "lower-smoothie")
    grant(p, "top-smoothie")
    local t = tool(p)
    inventory.DropHeld(p)
    check(inventory.GetCarryCount(p) == 2, "lower ingredient dropped, smoothies remain")
    check(inventory.ConsumeHeldSmoothie(p).BlendId == "top-smoothie", "serve selects top smoothie")
    carry(p, "Strawberry")
    check(inventory.GetHeldSmoothie(p) == nil and blend.ConsumeCup(p) == nil, "ingredient cannot serve lower smoothie")
    tool(p).Activated:Fire()
    check(
        inventory.GetCarryCount(p) == 1 and inventory.GetHeldSmoothie(p).BlendId == "lower-smoothie",
        "one activation removes only the selected ingredient"
    )
    check(inventory.ThrowHeld(p) == nil and inventory.GetCarryCount(p) == 1, "smoothie throw deferred without loss")
    check(inventory.ConsumeHeldSmoothie(p).BlendId == "lower-smoothie", "last smoothie consumed")
    grant(p, "new-tool")
    t.Activated:Fire()
    t.Unequipped:Fire()
    check(inventory.GetCarryCount(p) == 1, "old tool events cannot affect new stack")
    inventory.ClearHeld(p)
end
