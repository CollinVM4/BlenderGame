-- Mixed carry integration: selected removal preserves usable survivors.
do
    local p = player()
    carry(p)
    grant(p, "lower-smoothie")
    local lowerTool = tool(p)
    grant(p, "top-smoothie")
    local t = tool(p)
    check(inventory.ConsumeHeldSmoothie(p).BlendId == "top-smoothie", "serve selects top smoothie")
    carry(p, "Strawberry")
    check(inventory.GetHeldSmoothie(p) == nil and blend.ConsumeCup(p) == nil, "ingredient cannot serve lower smoothie")
    tool(p).Activated:Fire()
    check(
        inventory.GetCarryCount(p) == 2 and inventory.GetHeldIngredientId(p) == "Banana",
        "one activation removes only the selected ingredient"
    )
    p.Character:FindFirstChildOfClass("Humanoid"):EquipTool(lowerTool)
    check(inventory.ConsumeHeldSmoothie(p).BlendId == "lower-smoothie", "last smoothie consumed")
    inventory.ClearHeld(p)
    grant(p, "new-tool")
    t.Activated:Fire()
    t.Unequipped:Fire()
    check(inventory.GetCarryCount(p) == 1, "old tool events cannot affect new stack")
    inventory.ClearHeld(p)
end
