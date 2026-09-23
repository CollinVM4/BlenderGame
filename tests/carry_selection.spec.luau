-- Selection contracts share the real inventory/stash service and ordered held records.
local function fill(ids)
    local p, humanoid = player(1)
    local tools = {}
    for _, id in ids or { "Onion", "Carrot", "Cherries" } do
        carry(p, id)
        table.insert(tools, tool(p))
    end
    return p, humanoid, tools
end
local function unequip(p)
    local t = tool(p)
    if t then
        t.Parent = p:FindFirstChildOfClass("Backpack")
        t.Unequipped:Fire()
    end
end
for _, index in { 2, 1 } do
    local p, humanoid, tools = fill()
    local identity = tools[index]:GetAttribute("CarryItemId")
    humanoid:EquipTool(tools[index])
    check(
        tools[index]:GetAttribute("CarryItemId") == identity and inventory.GetCarryCount(p) == 3,
        "selection preserves identity and ownership"
    )
    local thrown = inventory.ThrowHeld(p, identity)
    check(ingredients.GetRecord(thrown).Id == ({ "Onion", "Carrot" })[index], "throw chooses exact selected ingredient")
    for i, t in tools do
        check((t.Destroyed == true) == (i == index), "only selected Tool retires")
    end
    check(tool(p) ~= tools[index], "removed selected Tool cannot remain selected")
    unequip(p)
    check(
        ingredients.GetRecord(inventory.ThrowHeld(p)).Id == "Cherries",
        "selection never reorders newest-first fallback"
    )
    inventory.ClearHeld(p)
end
do
    local p, humanoid, tools = fill()
    humanoid:EquipTool(tools[1])
    unequip(p)
    check(inventory.GetCarryCount(p) == 3, "unequip retains all carried items")
    check(p:GetAttribute("HeldIngredientId") == "Cherries", "prompt metadata reports unselected action fallback")
    check(ingredients.GetRecord(inventory.ThrowHeld(p)).Id == "Cherries", "no selected Tool throws newest ingredient")
    inventory.ClearHeld(p)
end
for _, action in { "throw", "stash" } do
    local p, humanoid, tools = fill({ "Apple", "Apple", "Ice" })
    humanoid:EquipTool(tools[1])
    if action == "throw" then
        setup(inventory.ThrowHeld(p, tools[1]:GetAttribute("CarryItemId")), "throw first duplicate")
    else
        setup(inventory.InteractStash(p, 3, p), "stash first duplicate")
        check(slot(p).IngredientId == "Apple" and slot(p).Count == 1, "stash receives one duplicate")
    end
    check(
        tools[1].Destroyed and not tools[2].Destroyed and not tools[3].Destroyed,
        action .. " resolves duplicate by exact identity"
    )
    inventory.ClearHeld(p)
end
local foreign, _, foreignTools = fill()
for _, invalid in { -1, 999999999, "Carrot", {}, 0 / 0, math.huge, 1.5, foreignTools[1]:GetAttribute("CarryItemId") } do
    local p, humanoid, tools = fill()
    humanoid:EquipTool(tools[1])
    local thrown = inventory.ThrowHeld(p, invalid)
    check(
        ingredients.GetRecord(thrown).Id == "Cherries",
        "invalid or foreign ID falls back to caller's newest ingredient"
    )
    check(
        not tools[1].Destroyed and not tools[2].Destroyed and tools[3].Destroyed,
        "invalid ID cannot remove a different reservation"
    )
    check(
        inventory.GetCarryCount(foreign) == 3 and not foreignTools[1].Destroyed,
        "foreign ownership remains untouched"
    )
    inventory.ClearHeld(p)
end
inventory.ClearHeld(foreign)
for _, selected in { true, false } do
    local p, humanoid, tools = fill()
    humanoid:EquipTool(tools[2])
    if not selected then
        unequip(p)
    end
    check(inventory.InteractStash(p, 3, p), "stash stores with selection or fallback")
    check(
        slot(p).IngredientId == (if selected then "Carrot" else "Cherries"),
        "stash uses same selection precedence as throw"
    )
    check(
        tools[if selected then 2 else 3].Destroyed and inventory.GetCarryCount(p) == 2,
        "stash removes exactly resolved item"
    )
    inventory.ClearHeld(p)
end
-- Selected smoothies still take priority; no unselected smoothie fallback is introduced.
do
    local p, humanoid, tools = fill({ "Onion" })
    grant(p, "selected-smoothie")
    local selected = tool(p)
    grant(p, "other-smoothie")
    local other = tool(p)
    humanoid:EquipTool(selected)
    local thrown = inventory.ThrowHeld(p, tools[1]:GetAttribute("CarryItemId"))
    check(
        dependency.SmoothieWorldItemService.GetData(thrown).BlendId == "selected-smoothie",
        "ingredient hint cannot override selected smoothie"
    )
    check(not other.Destroyed and not tools[1].Destroyed, "smoothie removal preserves other items")
    inventory.ClearHeld(p)
    grant(p, "unselected-smoothie")
    unequip(p)
    check(inventory.ThrowHeld(p) == nil, "unselected smoothies are not an ingredient fallback")
    inventory.ClearHeld(p)
end
