local function equip()
    local item = ingredients.Spawn("Banana", translate(), nil, true)
    setup(inventory.CarryWorldItem(player, item), "carry fixture pickup")
    return character:FindFirstChildOfClass("Tool")
end
local tool = equip()
local originalSpawn = ingredients.Spawn
ingredients.Spawn = function()
    return nil
end
check(
    inventory.ThrowHeld(player) == nil and inventory.GetHeldIngredientId(player) == "Banana",
    "failed spawn retains held reservation"
)
check(not tool.Destroyed, "failed release retains held visual")
ingredients.Spawn = originalSpawn
tool.Unequipped:Fire()
check(inventory.GetHeldIngredientId(player) == nil, "unequip releases reservation")
-- Death/reset/destroy are covered by the full-stack lifecycle matrix below.

check(inventory.GetCarryCapacity(player) == 1, "default capacity one")
local function pickup(id)
    local object = ingredients.Spawn(id, translate(), nil, true)
    return inventory.CarryWorldItem(player, object), object
end
local function fill()
    for _, id in { "Strawberry", "Banana", "Tire" } do
        setup(pickup(id), "pickup " .. id)
    end
end
check(pickup("Banana"), "default first pickup")
local accepted, rejected = pickup("Tire")
check(not accepted and ingredients.GetRecord(rejected) ~= nil, "capacity one rejection preserves world item")
inventory.DropHeld(player)
check(not data.PurchaseUpgrade(player, "CarryCapacity", 2), "insufficient cash rejected")
check(inventory.GetCarryCapacity(player) == 1 and data.GetCash(player) == 0, "failed purchase unchanged")
data.SetCash(player, 1000)
check(not data.PurchaseUpgrade(player, "CarryCapacity", 3), "cannot skip tier")
check(data.PurchaseUpgrade(player, "CarryCapacity", 2), "buy second capacity")
check(inventory.GetCarryCapacity(player) == 2 and data.GetCash(player) == 900, "capacity two costs 100")
check(not data.PurchaseUpgrade(player, "CarryCapacity", 2) and data.GetCash(player) == 900, "duplicate does not charge")
check(pickup("Strawberry") and pickup("Banana"), "capacity two holds two")
check(not pickup("Tire"), "capacity two rejects third")
inventory.DropHeld(player)
check(data.PurchaseUpgrade(player, "CarryCapacity", 3), "buy third capacity")
check(inventory.GetCarryCapacity(player) == 3 and data.GetCash(player) == 650, "capacity three costs 250")
check(
    not data.PurchaseUpgrade(player, "CarryCapacity", 4) and data.GetCash(player) == 650,
    "max rejects without charge"
)
fill()
accepted, rejected = pickup("Banana")
check(not accepted and ingredients.GetRecord(rejected) ~= nil, "fourth rejected intact")
local stackTool = character:FindFirstChildOfClass("Tool")
local previousY = -math.huge
local anchors = 0
for _, child in stackTool:GetChildren() do
    if child.Name == "CarryAnchor" then
        local position = child:FindFirstChild("OverheadCarry").C0.Position
        check(position.Y > previousY and position.X == 0 and position.Z == 0, "strictly vertical ordered stack")
        previousY = position.Y
        anchors += 1
    end
end
check(anchors == 3, "three attached visuals")
stackTool.Activated:Fire()
check(
    inventory.GetCarryCount(player) == 2 and inventory.GetHeldIngredientId(player) == "Banana",
    "one activation removes only newest Tire"
)
-- Following throws prove survivors remain usable, without requiring Tool identity.
check(ingredients.GetRecord(inventory.ThrowHeld(player)).Id == "Banana", "next throw Banana")
check(ingredients.GetRecord(inventory.ThrowHeld(player)).Id == "Strawberry", "last throw Strawberry")
check(inventory.GetCarryCount(player) == 0, "throw empties stack")
local spawned = {}
local spawn = ingredients.Spawn
ingredients.Spawn = function(...)
    local object = spawn(...)
    table.insert(spawned, object)
    return object
end
for _, event in { "combat", "death", "reset", "unequip", "destroy" } do
    fill()
    table.clear(spawned)
    if event == "combat" then
        inventory.DropOne(player)
    elseif event == "death" then
        humanoid.Died:Fire()
    elseif event == "reset" then
        player.CharacterRemoving:Fire(character)
    elseif event == "unequip" then
        character:FindFirstChildOfClass("Tool").Unequipped:Fire()
    else
        character:FindFirstChildOfClass("Tool"):Destroy()
    end
    check(
        #spawned == 3 and inventory.GetCarryCount(player) == 0 and player:GetAttribute("CarryCount") == 0,
        event .. " drops all and clears state"
    )
    for _, object in spawned do
        check(ingredients.GetRecord(object).Claimable, "dropped item remains valid and claimable")
    end
    check(
        inventory.GetCarryCapacity(player) == 3 and player:GetAttribute("CarryCapacity") == 3,
        "capacity survives lifecycle"
    )
end
ingredients.Spawn = spawn
print("PASS: " .. count .. " carry capacity assertions.")

local nextCharacter = instance("Model")
local nextRoot = part("HumanoidRootPart", nextCharacter, vec(2, 2, 1), translate())
part("Head", nextCharacter, vec(2, 1, 1), translate(0, 2, 0))
local nextHumanoid = instance("Humanoid")
nextHumanoid.Parent, nextHumanoid.Health, nextHumanoid.Died = nextCharacter, 100, signal()
function nextHumanoid:EquipTool(value)
    value.Parent = nextCharacter
end
player.Character = nextCharacter
check(
    inventory.GetCarryCount(player) == 0 and inventory.GetCarryCapacity(player) == 3,
    "new character retains capacity with empty hands"
)
fill()
check(
    nextCharacter:FindFirstChildOfClass("Tool") ~= nil and inventory.GetCarryCount(player) == 3,
    "respawn can carry three"
)
inventory.DropHeld(player)
print("PASS: " .. count .. " total carry assertions including respawn.")
