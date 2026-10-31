local authoredIngredients = instance("Folder")
authoredIngredients.Name, authoredIngredients.Parent = "Ingredients", storage
for _, id in { "Apple", "Banana", "Melon", "Crab" } do
    part(id, authoredIngredients)
end
-- Actual inventory grants, including an injected failure after a successful unit.
local p, humanoid = player(1)
for _ = 1, inventory.GetCarryCapacity(p) do
    setup(inventory.GrantIngredient(p, "Apple"), "fill normal carry")
end
local capacity = inventory.GetCarryCapacity(p)
check(not inventory.GrantIngredient(p, "Apple"), "ordinary direct grant rejects full carry")
local award = inventory.PrepareIngredientReward(p, { "Apple", "Banana", "Apple" })
setup(award, "prepare full-capacity PantryPack")
check(award(), "all three pack units commit at full capacity")
check(
    inventory.GetCarryCount(p) == capacity + 3 and p:GetAttribute("CarryCount") == capacity + 3,
    "actual excess count published"
)
check(inventory.GetCarryCapacity(p) == capacity, "overfill never purchases capacity")
for _, id in { "Melon", "Crab" } do
    local single = inventory.PrepareIngredientReward(p, { id })
    check(single and single(), "single-item prize overfills")
end
local overhead = 0
for _, model in p.Character:GetChildren() do
    if model.Name == "IngredientCarryVisuals" then
        overhead += 1
    end
end
check(overhead == inventory.GetCarryCount(p), "overhead includes every excess ingredient")
check(not inventory.PrepareIngredientReward(p, { "Steak" }), "Lucky never relies on generated fallback art")
local before = inventory.GetCarryCount(p)
local realGrant = inventory.GrantIngredient
local grants = 0
inventory.GrantIngredient = function(...)
    grants += 1
    if grants == 2 then
        return false
    end
    return realGrant(...)
end
local rollback = inventory.PrepareIngredientReward(p, { "Apple", "Banana", "Apple" })
check(rollback and not rollback(), "injected second grant failure rejects batch")
check(inventory.GetCarryCount(p) == before and not rollback(), "rollback leaves no partial award and cannot replay")
inventory.GrantIngredient = realGrant
local visual = ingredients.CreateVisual
ingredients.CreateVisual = function(id)
    return if id == "Banana" then nil else visual(id)
end
check(not inventory.PrepareIngredientReward(p, { "Apple", "Banana" }), "all visuals validated before commit")
check(inventory.GetCarryCount(p) == before, "preparation failure awards nothing")
ingredients.CreateVisual = visual
-- Native Backpack selection reaches an item beyond the purchased carry limit.
local tool = p.Character:FindFirstChildOfClass("Tool")
local selected = tool:GetAttribute("CarryItemId")
check(inventory.ThrowHeld(p, selected) ~= nil, "excess equipped ingredient can be thrown")
check(inventory.GetCarryCount(p) == before - 1, "throw consumes one overfill item")
for _, container in { p.Character, p:FindFirstChildOfClass("Backpack") } do
    for _, candidate in container:GetChildren() do
        if candidate:IsA("Tool") and candidate:GetAttribute("IngredientId") == "Apple" then
            humanoid:EquipTool(candidate)
            break
        end
    end
end
check(inventory.Deposit(p, "Apple", 1), "store uses storage capacity while carry remains overfull")
check(not inventory.GrantIngredient(p, "Apple"), "ordinary capacity gate remains after reducing excess")
local stash = inventory.GetSnapshot(p)
check(stash.Stash[1].Ingredients[1].Origin == "Unknown", "Lucky ingredient retains Unknown provenance")
print("PASS: Lucky overfill and rollback")

local serving, serverHumanoid = player(1)
setup(inventory.GrantSmoothie(serving, smoothie("overfill-serve")), "carry cup before prize")
local cupTool = serving.Character:FindFirstChildOfClass("Tool")
local pack = inventory.PrepareIngredientReward(serving, { "Apple", "Apple", "Apple" })
check(pack and pack(), "cup holder overfills with pack")
serverHumanoid:EquipTool(cupTool)
check(inventory.ConsumeHeldSmoothie(serving) ~= nil, "overfull player can serve equipped cup")
