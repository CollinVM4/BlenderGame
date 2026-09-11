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
inventory.Init({
    IngredientService = ingredients,
    PlayerDataService = {
        GetUpgrade = function()
            return 1
        end,
    },
})
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
        check(not motor.Enabled, "arm motor temporarily overridden")
    end
    local shoulder = tool:FindFirstChild("OverheadArmPose")
    check(shoulder.C0.UpVector.Y < -0.99, "shoulder weld raises arm overhead")
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
check(not motors[1].Enabled and not tool.Destroyed, "failed release retains overhead pose and visual")
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
