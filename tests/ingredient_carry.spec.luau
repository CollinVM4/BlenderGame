-- Rotation-capable CFrame boundary for geometry tests (the general suite only
-- models translations). This is not a simulation of Roblox weld physics.
local function cf(position, right, up, back)
    local value = {
        Position = position,
        RightVector = right,
        UpVector = up,
        LookVector = back * -1,
    }
    local function transform(v)
        return right * v.X + up * v.Y + back * v.Z
    end
    function value:ToObjectSpace(other)
        local function inverse(v)
            return vec(v:Dot(right), v:Dot(up), v:Dot(back))
        end
        return cf(
            inverse(other.Position - position),
            inverse(other.RightVector),
            inverse(other.UpVector),
            inverse(other.LookVector * -1)
        )
    end
    return setmetatable(value, {
        __index = function(_, key)
            if key == "Rotation" then
                return cf(vec(0, 0, 0), right, up, back)
            end
            return nil
        end,
        __mul = function(_, other)
            return cf(
                position + transform(other.Position),
                transform(other.RightVector),
                transform(other.UpVector),
                transform(other.LookVector * -1)
            )
        end,
    })
end
local function translate(x, y, z)
    local position = if type(x) == "table" then x else vec(x or 0, y or 0, z or 0)
    return cf(position, vec(1, 0, 0), vec(0, 1, 0), vec(0, 0, 1))
end
env.CFrame = {
    new = translate,
    Angles = function(x, y, z)
        return cf(vec(0, 0, 0), vec(1, 0, 0), vec(0, math.cos(x), math.sin(x)), vec(0, -math.sin(x), math.cos(x)))
            * cf(vec(0, 0, 0), vec(math.cos(y), 0, -math.sin(y)), vec(0, 1, 0), vec(math.sin(y), 0, math.cos(y)))
            * cf(vec(0, 0, 0), vec(math.cos(z), math.sin(z), 0), vec(-math.sin(z), math.cos(z), 0), vec(0, 0, 1))
    end,
}
local function part(name, parent, size, at)
    local result = instance("Part")
    result.Name, result.Parent, result.Size, result.CFrame = name, parent, size, at
    return result
end
local character = instance("Model")
local root = part("HumanoidRootPart", character, vec(2, 2, 1), translate(10, 5, 20))
part("Head", character, vec(2, 1, 1), translate(10, 7, 20))
local config = loadModule("IngredientCarry")
local carry = loadModule("IngredientCarryPresentation")
local fruit = part("Fruit", nil, vec(8, 10, 6), translate())
local offset = carry.Offset(fruit, root)
check(math.abs(offset.Position.Y - 7.85) < 1e-6, "large BasePart bottom clears head by configured gap")
local model = instance("Model")
local primary = part("Stem", model, vec(1, 1, 1), translate(0, 8, 0))
model.PrimaryPart = primary
part("Body", model, vec(8, 10, 6), translate())
check(
    math.abs(carry.Offset(model, root).Position.Y - 15.85) < 1e-6,
    "off-center PrimaryPart preserves full model clearance"
)
config.ForwardOffset = 1.25
config.HeightAboveHead = 0.6
config.RotationDegrees = vec(0, 0, 90)
local rotated = carry.Offset(model, root)
check(math.abs(rotated.Position.Y - 7.1) < 1e-6, "90-degree ingredient rotation uses rotated extents")
check(rotated.Position.Z == -1.25, "positive forward tuning moves toward character front")
config.HeightAboveHead, config.ForwardOffset, config.RotationDegrees = 0.35, 0, vec(0, 0, 0)
model.PrimaryPart = nil
check(math.abs(carry.Offset(model, root).Position.Y - 15.85) < 1e-6, "model without PrimaryPart uses fallback root")

local motors = {}
for _, name in
    {
        "Right Shoulder",
        "Left Shoulder",
        "RightShoulder",
        "LeftShoulder",
        "RightElbow",
        "LeftElbow",
        "RightWrist",
        "LeftWrist",
    }
do
    local motor = instance("Motor6D")
    motor.Name, motor.Parent, motor.Part0 = name, root, root
    motor.Part1 = part(name .. "Arm", character, vec(1, 2, 1), translate())
    motor.C0, motor.C1, motor.Enabled = translate(1, 1, 0), translate(0, 1, 0), name ~= "LeftWrist"
    table.insert(motors, motor)
end
local player = instance("Player")
player.Character, player.Near = character, true
local humanoid = instance("Humanoid")
humanoid.Parent, humanoid.Health, humanoid.Died = character, 100, signal()
function humanoid:EquipTool(tool)
    tool.Parent = character
end
local backpack = instance("Backpack")
backpack.Parent = player
local inventory = loadModule("InventoryService")
local ingredients = loadModule("IngredientService")
local data = loadModule("PlayerDataService")
data.AddPlayer(player)
inventory.Init({ IngredientService = ingredients, PlayerDataService = data })
inventory.AddPlayer(player)
local function equip()
    local item = ingredients.Spawn("Banana", translate(), nil, true)
    check(inventory.CarryWorldItem(player, item), "authoritative pickup equips visual")
    local tool = character:FindFirstChildOfClass("Tool")
    check(
        not tool.RequiresHandle and not tool:FindFirstChild("Handle"),
        "Tool keeps activation without default hand grip"
    )
    for _, motor in motors do
        check(motor.Enabled == (motor.Name ~= "LeftWrist"), "carry leaves arm motors unchanged")
    end
    check(not tool:FindFirstChild("OverheadArmPose"), "no custom arm pose")
    return tool
end
local function restored()
    for _, motor in motors do
        check(motor.Enabled == (motor.Name ~= "LeftWrist"), "original motor state restored")
    end
end
local tool = equip()
local launch = root.CFrame * tool:FindFirstChild("CarryAnchor"):FindFirstChild("OverheadCarry").C0
root.CFrame = root.CFrame * translate(3, 0, 0)
local thrown = inventory.ThrowHeld(player)
check(math.abs(thrown:GetPivot().Position.Y - launch.Position.Y) < 1e-6, "throw starts at overhead height")
check(thrown:GetPivot().Position.X == launch.Position.X + 3, "throw follows current character location")
check(thrown.AssemblyLinearVelocity.Y == 18 and thrown.AssemblyLinearVelocity.Z == -25, "throw velocity unchanged")
restored()
equip()
local dropped = inventory.DropHeld(player)
check(dropped:GetPivot().Position.Y == root.CFrame.Position.Y + 2, "drop height unchanged")
check(dropped:GetPivot().Position.Z == root.CFrame.Position.Z - 3, "drop forward placement unchanged")
restored()
equip()
inventory.ClearHeld(player)
restored()
tool = equip()
local originalSpawn = ingredients.Spawn
ingredients.Spawn = function()
    return nil
end
check(
    inventory.ThrowHeld(player) == nil and inventory.GetHeldIngredientId(player) == "Banana",
    "failed spawn retains held reservation"
)
check(motors[1].Enabled and not tool.Destroyed, "failed release retains visual without changing arms")
ingredients.Spawn = originalSpawn
tool.Unequipped:Fire()
check(inventory.GetHeldIngredientId(player) == nil, "unequip releases reservation")
restored()
equip()
player.CharacterRemoving:Fire(character)
check(inventory.GetHeldIngredientId(player) == nil, "character removal releases reservation")
restored()
equip():Destroy()
check(inventory.GetHeldIngredientId(player) == nil, "external Tool destruction releases reservation")
restored()
equip()
humanoid.Died:Fire()
check(inventory.GetHeldIngredientId(player) == nil, "death releases reservation")
restored()
print("PASS: " .. count .. " overhead carry assertions.")

check(inventory.GetCarryCapacity(player) == 1, "default capacity one")
local function pickup(id)
    local object = ingredients.Spawn(id, translate(), nil, true)
    return inventory.CarryWorldItem(player, object), object
end
local function fill()
    for _, id in { "Strawberry", "Banana", "Tire" } do
        check(pickup(id), "pickup " .. id)
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
check(not stackTool.Destroyed, "remaining ingredients retain equipped tool")
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
