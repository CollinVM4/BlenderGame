local world = dependency.SmoothieWorldItemService
local p, other = player(), player()
local original = smoothie("world-exact")
setup(inventory.GrantSmoothie(p, original), "carry source")
local object = inventory.DropHeld(p)
check(
    object and inventory.GetCarryCount(p) == 0 and world.GetData(object),
    "drop transfers reservation to one world item"
)
check(
    services.CollectionService:HasTag(object, "SmoothieWorldItem") and not ingredients.GetRecord(object),
    "separate world registration"
)
check(ingredients.Resolve(object.PrimaryPart) == nil, "blender ingredient resolution ignores smoothie")
check(object:FindFirstChild("Details") ~= nil, "world reconstructed from asset")
for index = 1, 3 do
    check(object:GetAttribute("IngredientId" .. index) == original.Ingredients[index], "ordered prompt data")
end
object:SetAttribute("IngredientId1", "Tire")
local copy = world.GetData(object)
copy.Ingredients[1] = "Tire"
local full = player(1)
grant(full, "full")
check(
    not inventory.CarryWorldSmoothie(full, object) and world.GetData(object) ~= nil,
    "capacity failure retains world item"
)
local savedTemplateName = template.Name
template.Name = "MissingAsset"
check(
    not inventory.CarryWorldSmoothie(other, object) and world.GetData(object) ~= nil,
    "failed reconstruction retains object"
)
template.Name = savedTemplateName
local grantOriginal = inventory.GrantSmoothie
local rivalResult
inventory.GrantSmoothie = function(owner, data)
    rivalResult = inventory.CarryWorldSmoothie(other, object)
    return grantOriginal(owner, data)
end
check(inventory.CarryWorldSmoothie(p, object), "successful pickup")
inventory.GrantSmoothie = grantOriginal
check(rivalResult == false and inventory.GetCarryCount(other) == 0, "reentrant competing player cannot claim")
local received = inventory.GetHeldSmoothie(p)
check(
    received.BlendId == original.BlendId
        and table.concat(received.Ingredients, ",") == table.concat(original.Ingredients, ","),
    "exact data survives metadata tampering and roundtrip"
)
check(
    not inventory.CarryWorldSmoothie(other, object) and world.GetData(object) == nil,
    "consumed world item cannot replay"
)
local thrown = inventory.ThrowHeld(p)
check(
    thrown and world.GetData(thrown).BlendId == original.BlendId and inventory.GetCarryCount(p) == 0,
    "throw conserves smoothie"
)
local fake = instance("Model")
fake.Parent = workspace
services.CollectionService:AddTag(fake, "SmoothieWorldItem")
check(world.GetData(fake) == nil, "tag alone cannot register authoritative contents")

local retained = player()
grant(retained, "failed-drop")
template.Name = "MissingAsset"
check(
    inventory.DropHeld(retained) == nil and inventory.GetHeldSmoothie(retained).BlendId == "failed-drop",
    "failed world spawn preserves carried reservation"
)
template.Name = savedTemplateName
check(world.Spawn(smoothie("invalid", { "Banana" }), frame()) == nil, "invalid contents cannot register")

-- Central throw selects the equipped smoothie reservation, not acquisition order.
do
    local owner, humanoid = player()
    carry(owner, "Banana")
    local ingredientTool = tool(owner)
    grant(owner, "selected-older")
    local olderTool = tool(owner)
    grant(owner, "newer-survivor")
    local newerTool = tool(owner)
    check(olderTool ~= newerTool and olderTool ~= ingredientTool, "smoothies have independent selectable Tools")
    check(
        olderTool:FindFirstChild("Handle") and not olderTool:FindFirstChild("CarryAnchor"),
        "smoothie is hand-held without overhead attachment"
    )
    check(
        owner.Character:FindFirstChild("IngredientCarryVisuals") ~= nil,
        "ingredients stay in character while smoothie equipped"
    )
    humanoid:EquipTool(olderTool)
    local spawn = world.Spawn
    local spawned = {}
    world.Spawn = function(data, at)
        local result = spawn(data, at)
        if result then
            table.insert(spawned, result)
        end
        return result
    end
    template.Name = "MissingAsset"
    inventory.ThrowHeld(owner)
    check(
        #spawned == 0
            and inventory.GetCarryCount(owner) == 3
            and inventory.GetHeldSmoothie(owner).BlendId == "selected-older",
        "failed click throw preserves selected smoothie and inventory"
    )
    template.Name = savedTemplateName
    newerTool.Activated:Fire()
    check(#spawned == 0, "backpack Tool activation cannot throw equipped smoothie")
    inventory.ThrowHeld(owner)
    check(
        #spawned == 1 and inventory.GetCarryCount(owner) == 2,
        "one click removes exactly selected smoothie and spawns one world item"
    )
    local data = world.GetData(spawned[1])
    check(
        data.BlendId == "selected-older" and table.concat(data.Ingredients, ",") == "Strawberry,Banana,Strawberry",
        "click throw preserves identity and ordered duplicates"
    )
    olderTool.Activated:Fire()
    check(
        #spawned == 1 and inventory.GetHeldSmoothie(owner).BlendId == "newer-survivor",
        "retired Tool cannot throw surviving smoothie"
    )
    humanoid:EquipTool(ingredientTool)
    check(
        owner.Character:FindFirstChild("IngredientCarryVisuals") ~= nil,
        "selecting ingredient retains overhead presentation"
    )
    inventory.ThrowHeld(owner)
    check(
        inventory.GetCarryCount(owner) == 1 and inventory.GetHeldSmoothie(owner).BlendId == "newer-survivor",
        "ingredient throw survives smoothie removal"
    )
    inventory.ThrowHeld(owner)
    check(#spawned == 2 and inventory.GetCarryCount(owner) == 0, "remaining smoothie remains throwable")
    world.Spawn = spawn
end
