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

-- Placement queries model endpoint clearance, never the fictional launch path.
local throw = loadModule("IngredientThrow")
local oldRay, oldBlock, oldOverlap = workspaceFake.Raycast, workspaceFake.Blockcast, workspaceFake.GetPartBoundsInBox
workspaceFake.Raycast = function()
    error("throw placement must not raycast")
end
workspaceFake.Blockcast = function()
    error("throw placement must not sweep")
end
check(
    not string.find(sources.IngredientThrow, "Blockcast", 1, true)
        and not string.find(sources.IngredientThrow, ":Raycast", 1, true),
    "placement source contains no sweep or vertical raycast"
)
local wall = instance("Part")
wall.Name = "Wall"
local item = part("PlacementItem", nil, vec(0.5, 0.5, 0.5), translate())
local itemRadius = item.Size.Magnitude * 0.5 + 0.25
local minimum = root.Size.Z * 0.5 + itemRadius + 0.25
local start = root.CFrame.Position + vec(0, math.max(2, itemRadius), 0)
local function candidate(angle, distance)
    local facing = root.CFrame.LookVector
    local radians = math.rad(angle)
    return start
        + vec(
                facing.X * math.cos(radians) + facing.Z * math.sin(radians),
                0,
                -facing.X * math.sin(radians) + facing.Z * math.cos(radians)
            )
            * distance
end
-- Every preference can win; all earlier candidates are occupied. Include fractional minimum.
local distances = { 5, 4, 3, 2, minimum }
for _, winningAngle in { 0, 20, -20, 40, -40 } do
    for winningIndex, winningDistance in distances do
        local expectedQueries = (table.find({ 0, 20, -20, 40, -40 }, winningAngle) - 1) * #distances + winningIndex
        local queries = 0
        workspaceFake.GetPartBoundsInBox = function(_, at, size, params)
            queries += 1
            if queries == 1 and winningAngle == 0 and winningIndex == 1 then
                check(
                    params.FilterType == env.Enum.RaycastFilterType.Exclude
                        and params.FilterDescendantsInstances[1] == character
                        and params.RespectCanCollide == true,
                    "placement queries exclude the character and respect collisions"
                )
                check((size - vec(1, 1, 1)).Magnitude < 0.0001, "small item uses real extents plus clearance")
            end
            return if (at.Position - candidate(winningAngle, winningDistance)).Magnitude < 0.0001 then {} else { wall }
        end
        local origin, reason = throw.FindOrigin(root, character, item)
        check(
            origin ~= nil and (origin.Position - candidate(winningAngle, winningDistance)).Magnitude < 0.0001,
            "first clear ladder candidate wins"
        )
        check(queries == expectedQueries, "straight then signed angles exhaust descending distances in order")
        check(
            reason == string.format("clear distance=%.3f angle=%d", winningDistance, winningAngle),
            "clear diagnostics identify winning distance and angle"
        )
    end
end
-- Enclosed throws still release inventory and keep their original facing impulse.
local messages = {}
env.print = function(message)
    table.insert(messages, message)
end
player:SetAttribute("ThrowDebug", true)
for _, forced in { false, true } do
    table.clear(messages)
    fill()
    workspaceFake.GetPartBoundsInBox = function(_, at)
        local side = (at.Position - root.CFrame.Position):Dot(root.CFrame.RightVector)
        return if not forced and side < -0.1 then {} else { wall }
    end
    local before = #services.CollectionService:GetTagged("IngredientWorldItem")
    local thrown = inventory.ThrowHeld(player, nil, true)
    check(
        thrown ~= nil and inventory.GetCarryCount(player) == 2,
        "blocked straight placement releases exactly one item"
    )
    check(
        #services.CollectionService:GetTagged("IngredientWorldItem") == before + 1,
        "blocked straight placement publishes item"
    )
    check(
        (thrown.AssemblyLinearVelocity - (root.CFrame.LookVector * 25 + vec(0, 18, 0))).Magnitude < 0.0001,
        "angled and forced placements preserve facing impulse"
    )
    local relative = root.CFrame:ToObjectSpace(thrown:GetPivot()).Position
    if forced then
        local radius = thrown.Size.Magnitude * 0.5 + 0.25
        local expectedMinimum = root.Size.Z * 0.5 + radius + 0.25
        check(
            math.abs(relative.X) < 0.0001 and math.abs(relative.Z + expectedMinimum) < 0.0001,
            "every candidate occupied forces straight minimum spawn"
        )
        check(
            string.find(table.concat(messages, "\n"), "placement forced distance=", 1, true) ~= nil,
            "forced diagnostic emitted"
        )
    else
        check(relative.X < -0.1, "blocked straight line chooses angled spawn")
        check(string.find(table.concat(messages, "\n"), "angle=20", 1, true) ~= nil, "angled diagnostic emitted")
    end
    inventory.ClearHeld(player)
end
player:SetAttribute("ThrowDebug", false)
local beforeLogs = #messages
throw.Trace(player, "disabled")
check(#messages == beforeLogs, "diagnostics are opt-in")
-- Purchased active munchers, including busy ones and other plots, resolve vacuum arrivals.
local plot = instance("Model")
services.CollectionService:AddTag(plot, "PlayerPlot")
local muncher = instance("Model")
muncher.Name, muncher.Parent = "Muncher", plot
local mouth = part("Mouth", muncher, vec(4, 4, 4), translate(candidate(0, 5)))
for _, state in { "active", "busy", "unpurchased", "inactive", "unset" } do
    muncher:SetAttribute("Purchased", if state == "unset" then nil else state ~= "unpurchased")
    muncher:SetAttribute("Active", if state == "unset" then nil else state ~= "inactive")
    muncher:SetAttribute("Phase", if state == "busy" then "Processing" else "Idle")
    workspaceFake.GetPartBoundsInBox = function(_, _, _, params)
        for _, excluded in params.FilterDescendantsInstances do
            if mouth:IsDescendantOf(excluded) then
                return {}
            end
        end
        return { mouth }
    end
    local origin, reason = throw.FindOrigin(root, character, item)
    local excluded = state == "active" or state == "busy"
    check(
        origin ~= nil and (origin.Position - candidate(0, if excluded then 5 else minimum)).Magnitude < 0.0001,
        state .. " muncher uses straight clear spawn or forced minimum"
    )
    check(
        reason
            == (
                if excluded
                    then "clear distance=5.000 angle=0"
                    else string.format("placement forced distance=%.3f", minimum)
            ),
        state .. " muncher diagnostic"
    )
end
services.CollectionService:RemoveTag(plot, "PlayerPlot")
plot:Destroy()
-- An oriented thin multipart item with an offset pivot must query its actual box.
local model = instance("Model")
model.CFrame = translate(8, 3, 2) * env.CFrame.Angles(0, math.pi / 3, 0)
part("Long", model, vec(6, 1, 0.5), model.CFrame * translate(2, 0, 0) * env.CFrame.Angles(0, math.pi / 2, 0))
part("Tip", model, vec(1, 1, 1), model.CFrame * translate(2, 0, 3))
local savedFrame = root.CFrame
root.CFrame = root.CFrame * env.CFrame.Angles(0.2, 0.7, 0)
workspaceFake.GetPartBoundsInBox = function(_, at, size)
    check((size - vec(1.5, 1.5, 7)).Magnitude < 0.0001, "rotated multipart bounds are tight rather than radius cube")
    check((at.RightVector - root.CFrame.RightVector).Magnitude < 0.0001, "clearance box follows spawn rotation")
    -- The query center is offset from the returned pivot in its rotated frame.
    return {}
end
local origin = throw.FindOrigin(root, character, model)
-- Radius is max(center distance + part half diagonal), independent of tight query bounds.
local modelRadius = math.max(2 + vec(6, 1, 0.5).Magnitude * 0.5, vec(2, 0, 3).Magnitude + math.sqrt(3) * 0.5) + 0.25
check(
    math.abs(origin.Position.Y - root.CFrame.Position.Y - math.max(2, modelRadius)) < 0.0001,
    "spawn uses single radius-based height"
)
local queriedFrame
workspaceFake.GetPartBoundsInBox = function(_, at)
    queriedFrame = at
    return {}
end
origin = throw.FindOrigin(root, character, model)
check(
    (origin:ToObjectSpace(queriedFrame).Position - vec(2, 0, 0.25)).Magnitude < 0.0001,
    "off-center bounds follow returned pivot without shifting spawn"
)
local displacement = origin.Position - root.CFrame.Position
check(
    math.abs(
        vec(displacement.X, 0, displacement.Z).Unit:Dot(vec(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit)
            - 1
    ) < 0.0001,
    "placement direction is flattened root facing"
)
root.CFrame = savedFrame
model:Destroy()
-- Large but valid rigs prefer minimum directly; never add a second shorter distance.
local normalSize = root.Size
root.Size = vec(2, 2, 12)
local wideMinimum = 6 + itemRadius + 0.25
local attempts = 0
workspaceFake.GetPartBoundsInBox = function(_, at)
    attempts += 1
    local offset = at.Position - root.CFrame.Position
    check(math.abs(vec(offset.X, 0, offset.Z).Magnitude - wideMinimum) < 0.0001, "large rig candidates stay at minimum")
    return { wall }
end
local wideOrigin, wideReason = throw.FindOrigin(root, character, item)
check(attempts == 5 and wideOrigin ~= nil, "large rig tries one minimum candidate per angle then forces spawn")
check(
    wideReason == string.format("placement forced distance=%.3f", wideMinimum),
    "large rig forced distance is minimum"
)
root.Size = normalSize
-- The only placement rejection is an excessive avatar/item minimum; reservation survives.
local savedSize = root.Size
root.Size = vec(2, 2, 80)
workspaceFake.GetPartBoundsInBox = function()
    error("oversized clearance must reject before querying candidates")
end
local rejected, reason = throw.FindOrigin(root, character, item)
check(rejected == nil and reason == "avatar/item clearance exceeds safe distance", "minimum above MAX_DISTANCE rejects")
fill()
check(
    inventory.ThrowHeld(player, nil, false) == nil and inventory.GetCarryCount(player) == 3,
    "degenerate rig retains inventory"
)
inventory.ClearHeld(player)
root.Size = savedSize
item:Destroy()
workspaceFake.Raycast, workspaceFake.Blockcast, workspaceFake.GetPartBoundsInBox = oldRay, oldBlock, oldOverlap
data.GetUpgrade = getUpgrade
