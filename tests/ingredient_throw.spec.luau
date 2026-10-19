-- Throw contracts use real inventory/ingredient services and arbitrary avatar geometry.
-- Carry capacity is fixture setup; progression belongs to its own suites.
local upgrades = loadModule("Upgrades")
local getUpgrade = data.GetUpgrade
function data.GetUpgrade(p, name)
    return if p == player and name == "CarryCapacity" then #upgrades.CarryCapacity else getUpgrade(p, name)
end
local function fill()
    for _, id in { "Strawberry", "Banana", "Tire" } do
        local object = ingredients.Spawn(id, translate(), nil, true)
        setup(inventory.CarryWorldItem(player, object), "pickup " .. id)
    end
end
-- Same HRP frame, radically different avatar dimensions and overhead placements.
local head = character:FindFirstChild("Head")
local oldRootFrame, oldRootSize, oldHeadFrame, oldHeadSize = root.CFrame, root.Size, head.CFrame, head.Size
root.CFrame = translate(12, 8, -4) * env.CFrame.Angles(0, math.pi / 2, 0)
local torso = part("UpperTorso", character, vec(2, 2, 1), root.CFrame)
for _, dimensions in { vec(2, 2, 1), vec(12, 0.5, 12), vec(1, 9, 1) } do
    root.Size, head.Size = oldRootSize, dimensions
    torso.Size, torso.CFrame = dimensions, root.CFrame
    for _, motor in motors do
        motor.Part1.CFrame = root.CFrame
    end
    head.CFrame = root.CFrame * translate(0, dimensions.Y, 0)
    fill()
    local expired = {}
    local addDebris = services.Debris.AddItem
    services.Debris.AddItem = function(self, object, lifetime)
        if object:IsA("NoCollisionConstraint") then
            check(lifetime == 0.2, "thrower exclusion expires after short grace")
            table.insert(expired, object)
        else
            addDebris(self, object, lifetime)
        end
    end
    local released = {}
    local publish = services.CollectionService.AddTag
    services.CollectionService.AddTag = function(self, object, tag)
        if tag == "IngredientWorldItem" then
            check(inventory.GetCarryCount(player) == 2, "carry removed before world publication")
            table.insert(released, object)
        end
        publish(self, object, tag)
    end
    inventory.ThrowHeld(player, nil, false)
    services.CollectionService.AddTag = publish
    check(#released == 1, "one Throw action publishes exactly one world item")
    local thrown = released[1]
    check(ingredients.GetRecord(thrown).Id == "Tire", "equipped newest pickup throws first")
    services.Debris.AddItem = addDebris
    local localFrame = root.CFrame:ToObjectSpace(thrown:GetPivot())
    check(
        localFrame.Position.Z < -dimensions.Z * 0.5 - thrown.Size.Magnitude * 0.5,
        "spawn clears avatar front and ingredient bounds for every avatar"
    )
    check(localFrame.Position.Y >= 2, "spawn remains above root without using head height")
    check(
        (thrown.AssemblyLinearVelocity - (root.CFrame.LookVector * 25 + vec(0, 18, 0))).Magnitude < 0.0001,
        "throw speed and facing preserved"
    )
    check(
        inventory.GetCarryCount(player) == 2 and player:GetAttribute("CarryCount") == 2,
        "unusual avatar loses exactly one reservation"
    )
    local survivorTool = character:FindFirstChildOfClass("Tool")
    local survivorCount = 0
    for _, child in character:GetDescendants() do
        if child.Parent.Name == "IngredientCarryVisuals" and child.Name ~= "CarryAnchor" and child:IsA("BasePart") then
            survivorCount += 1
        end
    end
    check(survivorCount == 2, "two ingredient visuals remain carried")
    local targets = {}
    for _, constraint in expired do
        check(
            constraint.Part0 == thrown and constraint.Part1:IsDescendantOf(character),
            "exclusions target only thrower"
        )
        targets[constraint.Part1] = true
    end
    for _, child in character:GetDescendants() do
        if child:IsA("BasePart") then
            check(targets[child], "every body and remaining carried part excluded")
            if child:IsDescendantOf(survivorTool) then
                check(
                    child.Massless and child.CanCollide == false,
                    "remaining carry visuals are massless and noncolliding"
                )
            end
        end
    end
    for _, constraint in expired do
        constraint:Destroy() -- Debris expiry boundary; CLI does not simulate physics/time.
    end
    check(
        ingredients.GetRecord(thrown) ~= nil and not thrown.Anchored and thrown.CanQuery,
        "world item remains active after grace"
    )
    local equipped = character:FindFirstChildOfClass("Tool")
    equipped.Parent = backpack
    equipped.Unequipped:Fire()
    check(
        ingredients.GetRecord(inventory.ThrowHeld(player, nil, false)).Id == "Banana",
        "unequipped throw falls back to newest remaining pickup"
    )
    check(
        ingredients.GetRecord(inventory.ThrowHeld(player, nil, false)).Id == "Strawberry",
        "first pickup stays usable"
    )
end
root.CFrame, root.Size, head.CFrame, head.Size = oldRootFrame, oldRootSize, oldHeadFrame, oldHeadSize
torso:Destroy()

-- Input resolves an older equipped ingredient from its server-owned CarryItemId.
fill()
local selectedTool
for _, tool in backpack:GetChildren() do
    if tool:GetAttribute("IngredientId") == "Banana" then
        selectedTool = tool
    end
end
setup(selectedTool ~= nil, "older ingredient Tool available")
humanoid:EquipTool(selectedTool)
local selectedThrow = inventory.ThrowHeld(player, nil, false)
check(ingredients.GetRecord(selectedThrow).Id == "Banana", "equipped ingredient wins over newest pickup")
check(inventory.GetCarryCount(player) == 2, "equipped throw releases exactly one ingredient")
local equipped = character:FindFirstChildOfClass("Tool")
equipped.Parent = backpack
equipped.Unequipped:Fire()
check(
    ingredients.GetRecord(inventory.ThrowHeld(player, nil, false)).Id == "Tire",
    "equipped selection preserves newest fallback order"
)
check(
    ingredients.GetRecord(inventory.ThrowHeld(player, nil, false)).Id == "Strawberry",
    "oldest remaining ingredient stays usable"
)

for _, motor in motors do
    motor.Part1.CFrame = root.CFrame
end
-- Accessories affect physical spawn clearance; overhead stacks do not drive it.
local accessory = instance("Accessory")
accessory.Name, accessory.Parent = "WideCostume", character
local handle = part("Handle", accessory, vec(4, 2, 12), root.CFrame)
handle.CanCollide, handle.CanQuery = false, false
fill()
local thrown = inventory.ThrowHeld(player, nil, true)
check(
    root.CFrame:ToObjectSpace(thrown:GetPivot()).Position.Z < -6 - thrown.Size.Magnitude * 0.5,
    "large accessory cleared even when it is nonqueryable"
)
inventory.ClearHeld(player)
accessory:Destroy()

-- Boundary doubles model engine query outcomes, not Roblox physical simulation.
local oldRay, oldBlock, oldOverlap = workspaceFake.Raycast, workspaceFake.Blockcast, workspaceFake.GetPartBoundsInBox
local wall = instance("Part")
wall.Name = "Wall"
function wall:GetFullName()
    return "Workspace.Wall"
end
local messages = {}
env.print = function(message)
    table.insert(messages, message)
end
player:SetAttribute("ThrowDebug", true)
for _, gate in { "height", "initial", "path", "destination" } do
    table.clear(messages)
    fill()
    workspaceFake.Raycast = function(_, _, _, params)
        check(
            params.FilterDescendantsInstances[1] == character and params.RespectCanCollide,
            "height excludes thrower's full character"
        )
        return if gate == "height" then { Instance = wall } else nil
    end
    workspaceFake.Blockcast = function(_, _, _, _, params)
        check(
            params.FilterDescendantsInstances[1] == character and params.RespectCanCollide,
            "sweep excludes self but retains world collisions"
        )
        return if gate == "path" then { Instance = wall } else nil
    end
    local queries = 0
    workspaceFake.GetPartBoundsInBox = function(_, _, _, params)
        queries += 1
        check(
            params.FilterDescendantsInstances[1] == character and params.RespectCanCollide,
            "volume excludes own accessories and carry geometry"
        )
        return if (gate == "initial" and queries == 1) or (gate == "destination" and queries > 1) then { wall } else {}
    end
    local before = #services.CollectionService:GetTagged("IngredientWorldItem")
    check(inventory.ThrowHeld(player, nil, true) == nil, gate .. " obstruction rejects throw")
    check(inventory.GetCarryCount(player) == 3, gate .. " rejection preserves all owned ingredients")
    check(
        #services.CollectionService:GetTagged("IngredientWorldItem") == before,
        gate .. " rejection publishes no item"
    )
    check(
        string.find(table.concat(messages, "\n"), "Workspace.Wall", 1, true) ~= nil,
        "opt-in diagnostics name obstruction"
    )
    inventory.ClearHeld(player)
end
workspaceFake.Raycast, workspaceFake.Blockcast, workspaceFake.GetPartBoundsInBox = oldRay, oldBlock, oldOverlap
fill()
check(inventory.ThrowHeld(player, nil, false) ~= nil, "throw recovers immediately after obstruction removed")
inventory.ClearHeld(player)
player:SetAttribute("ThrowDebug", false)
local beforeLogs = #messages
loadModule("IngredientThrow").Trace(player, "disabled")
check(#messages == beforeLogs, "diagnostics are opt-in")
-- Nominal five-stud placement can fall back closer without crossing a wall.
fill()
workspaceFake.Blockcast = function(_, _, _, displacement)
    return if displacement.Magnitude > 4 then { Instance = wall } else nil
end
local nearby = inventory.ThrowHeld(player, nil, false)
check(
    nearby ~= nil and (nearby:GetPivot().Position - root.CFrame.Position).Magnitude < 5,
    "near wall uses safe closer spawn"
)
workspaceFake.Blockcast = oldBlock
inventory.ClearHeld(player)
data.GetUpgrade = getUpgrade
