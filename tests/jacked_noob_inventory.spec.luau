local owner = player(1)
check(inventory.GrantIngredient(owner, "Protein"), "server grants one carried Protein")
local heldTool = tool(owner)
check(inventory.GetCarryCount(owner) == 1 and heldTool:GetAttribute("IngredientId") == "Protein", "normal carry identity")
setup(inventory.GrantIngredient(owner, "Protein"), "second carry slot")
setup(inventory.GrantIngredient(owner, "Protein"), "third carry slot")
check(not inventory.GrantIngredient(owner, "Protein") and inventory.GetCarryCount(owner) == 3, "real carry capacity blocks another reward")
setup(inventory.Deposit(owner, "Protein", 3), "stash granted Protein")
local stored = slot(owner).Ingredients[1]
check(stored.IngredientId == "Protein" and type(stored.ItemId) == "string" and stored.ItemId ~= "", "persistent per-item metadata")
local original = stored.ItemId
now += loadModule("Ripeness").RipenessSeconds
check(slot(owner).Ingredients[1].IsRipe, "granted Protein follows normal ripeness")
inventory.ClearHeld(owner)
setup(inventory.Withdraw(owner, 3), "withdraw ripe Protein")
local world = inventory.ThrowHeld(owner)
check(ingredients.GetRecord(world).Item.ItemId == original and ingredients.GetRecord(world).Item.IsRipe, "world lifecycle preserves identity")
