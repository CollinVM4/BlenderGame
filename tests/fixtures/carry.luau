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
    for _, current in character:GetChildren() do
        if current:IsA("Tool") and current ~= tool then
            current.Parent = player:FindFirstChildOfClass("Backpack")
            current.Unequipped:Fire()
        end
    end
    tool.Parent = character
    tool.Equipped:Fire()
end
local backpack = instance("Backpack")
backpack.Parent = player
local inventory = loadModule("InventoryService")
local ingredients = loadModule("IngredientService")
local data = loadModule("PlayerDataService")
data.AddPlayer(player)
bindTestData(data)
assignTestSession(player)
inventory.Init({ IngredientService = ingredients, PlayerDataService = data })
inventory.AddPlayer(player)
