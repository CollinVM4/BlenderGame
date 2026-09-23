-- Ingredient slot contracts through real inventory, stash and blender services.
local p, humanoid = player(1)
local backpack = p:FindFirstChildOfClass("Backpack")
local function slots()
    local result = {}
    for _, parent in { backpack, p.Character } do
        for _, child in parent:GetChildren() do
            if child:IsA("Tool") and child:GetAttribute("IngredientId") then
                table.insert(result, child)
            end
        end
    end
    return result
end
carry(p, "Strawberry")
local strawberry = tool(p)
check(#slots() == 1 and inventory.GetCarryCount(p) == 1, "one pickup is one slot")
carry(p, "Ice")
local ice = tool(p)
carry(p, "Cherries")
local cherries = tool(p)
check(#slots() == 3 and inventory.GetCarryCount(p) == 3, "three ingredients have three slots")
local identities = {}
for _, t in slots() do
    local id = t:GetAttribute("IngredientId")
    check(t.Name == (ingredients.GetDefinition(id).DisplayName or id), "slot names match ingredient definitions")
    local identity = t:GetAttribute("CarryItemId")
    check(identity ~= nil and not identities[identity], "each slot has a distinct carry identity")
    identities[identity] = true
    check(not t.RequiresHandle and #t:GetChildren() == 0, "passive slots have no hand geometry or scripts")
    t.Activated:Fire()
end
check(inventory.GetCarryCount(p) == 3, "Tool activation cannot throw ingredients")
humanoid:EquipTool(strawberry)
check(#slots() == 3 and inventory.GetCarryCount(p) == 3, "selecting an older slot retains all items")
strawberry.Parent = backpack
strawberry.Unequipped:Fire()
check(#slots() == 3 and inventory.GetCarryCount(p) == 3, "unequip retains inventory")
check(inventory.ThrowHeld(p) == nil, "no selected carry Tool cannot throw")
humanoid:EquipTool(strawberry)
-- Attributes are presentation only, never authorization for contents.
cherries:SetAttribute("IngredientId", "Tire")
local thrown = inventory.ThrowHeld(p)
check(
    ingredients.GetRecord(thrown).Id == "Cherries",
    "ingredient throw stays newest-first despite selection or attribute tampering"
)
check(
    cherries.Destroyed and not ice.Destroyed and not strawberry.Destroyed and #slots() == 2,
    "throw removes only matching slot"
)
local input = references[p].BlenderInput
input.Overlaps = { thrown }
check(blend.TryInput(p, thrown, input), "blender accepts released ingredient")
check(#slots() == 2 and not ice.Destroyed and not strawberry.Destroyed, "blender consumption preserves unrelated slots")
check(not blend.TryInput(p, thrown, input), "blender consumption cannot replay")
humanoid:EquipTool(ice)
check(inventory.Deposit(p, "Ice", 3), "stash accepts selected ingredient")
check(ice.Destroyed and #slots() == 1 and not strawberry.Destroyed, "stash removes exactly its carried slot")
check(inventory.Withdraw(p, 3), "withdraw returns stash unit to carry")
local returned = tool(p)
check(
    returned ~= ice and returned:GetAttribute("CarryItemId") ~= ice:GetAttribute("CarryItemId"),
    "withdraw creates a fresh distinct carry slot"
)
check(
    returned:GetAttribute("IngredientId") == "Ice" and #slots() == 2 and slot(p).Count == 0,
    "withdraw synchronizes stash and carry"
)
inventory.ClearHeld(p)
carry(p, "Apple")
local first = tool(p)
carry(p, "Apple")
local second = tool(p)
check(first ~= second and #slots() == 2, "duplicate ingredients have distinct slots")
check(
    first:GetAttribute("IngredientId") == "Apple" and second:GetAttribute("IngredientId") == "Apple",
    "duplicate slots preserve ingredient ID"
)
check(
    inventory.Deposit(p, "Apple", 3) and inventory.Deposit(p, "Apple", 3),
    "duplicate carried slots still stack in stash"
)
check(slot(p).Count == 2 and #slots() == 0, "stash stack consumes both individual slots")
check(
    inventory.Withdraw(p, 3) and inventory.Withdraw(p, 3) and #slots() == 2,
    "stack withdrawals restore distinct slots"
)
inventory.ClearHeld(p)
-- Smoothies retain individual hand Tools and exact selected-item semantics.
carry(p, "Banana")
local banana = tool(p)
grant(p, "older")
local older = tool(p)
grant(p, "newer")
local newer = tool(p)
humanoid:EquipTool(older)
local world = dependency.SmoothieWorldItemService
local released = inventory.ThrowHeld(p)
check(world.GetData(released).BlendId == "older", "smoothie throw still follows exact selection")
check(older.Destroyed and not newer.Destroyed and not banana.Destroyed, "smoothie throw preserves other slots")
check(
    newer:FindFirstChild("Handle") ~= nil and newer:GetAttribute("IngredientId") == nil,
    "smoothie hand Tool remains unchanged"
)
humanoid:EquipTool(newer)
check(inventory.Deposit(p, "Banana", 3) == false, "ingredient deposit cannot claim selected smoothie")
check(inventory.ConsumeHeldSmoothie(p).BlendId == "newer", "smoothie remains consumable")
inventory.ClearHeld(p)
-- Shared slot changes preserve smoothie stash metadata and capacity rejection.
grant(p, "stash-smoothie")
local storedTool = tool(p)
setup(inventory.InteractStash(p, 4, p), "stash smoothie")
check(
    storedTool.Destroyed and inventory.GetSnapshot(p).Stash[4].Smoothie.BlendId == "stash-smoothie",
    "smoothie stash keeps server metadata"
)
now += 1.3
setup(inventory.InteractStash(p, 4, p), "take smoothie")
check(
    inventory.GetHeldSmoothie(p).BlendId == "stash-smoothie" and inventory.GetSnapshot(p).Stash[4].Count == 0,
    "smoothie withdrawal preserves identity"
)
for index = 2, inventory.GetCarryCapacity(p) do
    grant(p, "capacity-" .. index)
end
check(not inventory.GrantSmoothie(p, smoothie("overflow")), "smoothies still obey shared configured carry capacity")
inventory.ClearHeld(p)
