-- Blender acceptance must remain available while thrower collision grace is active.
local templates = instance("Folder")
templates.Name, templates.Parent = "Ingredients", storage
local template = instance("Model")
template.Name, template.Parent = "Banana", templates
local fruit = part("Fruit", template, vec(2, 2, 2), translate())
fruit.CanCollide = true
part("Stem", template, vec(1, 1, 1), translate(0, 2, 0)).CanCollide = true
local object = ingredients.Spawn("Banana", translate(), nil, true)
setup(inventory.CarryWorldItem(player, object), "carry multipart ingredient")
local thrown = inventory.ThrowHeld(player)
for _, child in thrown:GetDescendants() do
    if child:IsA("BasePart") then
        check(not child.Anchored and child.CanQuery, "multipart throw immediately physical and queryable")
        check(child:FindFirstChildOfClass("NoCollisionConstraint") ~= nil, "every thrown part has character grace")
    end
end
check(thrown:FindFirstChild("Fruit").CanCollide, "authored world collisions retained during grace")
local input = instance("Part")
local blend = loadModule("BlendService")
blend.Init({
    IngredientService = ingredients,
    TycoonService = sessionTestAuthority,
})
local plot = assignTestSession(player)
input.Name, input.Parent = "BlenderInput", plot
services.CollectionService:AddTag(input, "BlenderInput")
blend.Reset(player)
input.Overlaps = { thrown:FindFirstChild("Fruit"), thrown:FindFirstChild("Stem") }
check(blend.TryInput(player, thrown, input), "blender accepts thrown ingredient before grace expires")
check(#blend.GetSnapshot(player).Ingredients == 1, "multipart throw adds one blender ingredient")
check(not blend.TryInput(player, thrown, input), "same thrown item cannot be consumed twice")
