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
    check(inventory.GetHeldSmoothie(p) == nil, "equipped-only queries still ignore lower smoothies")
    inventory.ThrowHeld(p)
    check(
        inventory.GetCarryCount(p) == 2 and inventory.GetHeldIngredientId(p) == "Banana",
        "one throw removes only the newest ingredient"
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

do
    local p = player()
    grant(p, "selected")
    local selectedTool = tool(p)
    grant(p, "older")
    grant(p, "newer")
    local newestTool = tool(p)
    p.Character:FindFirstChildOfClass("Humanoid"):EquipTool(selectedTool)
    check(blend.ConsumeCup(p).BlendId == "selected", "serving prioritizes the equipped cup")
    carry(p)
    check(blend.GetCup(p, newestTool) == nil, "explicit Tool lookup still requires the equipped cup")
    check(blend.ConsumeCup(p).BlendId == "newer", "serve falls back to the newest Backpack cup")
    check(blend.ConsumeCup(p).BlendId == "older", "a second serve can use the remaining Backpack cup")
    check(blend.ConsumeCup(p) == nil and inventory.GetCarryCount(p) == 1, "serving leaves the ingredient alone")
    grant(p, "stored")
    setup(press(p, "STORE"), "stash smoothie")
    check(blend.ConsumeCup(p) == nil and slot(p).Smoothie.BlendId == "stored", "serving requires a carried smoothie")
end
