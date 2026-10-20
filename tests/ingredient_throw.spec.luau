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
    workspaceFake.GetPartBoundsInBox = function(_, queryFrame, _, params)
        queries += 1
        check(
            params.FilterDescendantsInstances[1] == character and params.RespectCanCollide,
            "volume excludes own accessories and carry geometry"
        )
        return if (gate == "initial")
                or (
                    gate == "destination"
                    and (queryFrame.Position - root.CFrame.Position):Dot(root.CFrame.LookVector) > 0.01
                )
            then { wall }
            else {}
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
-- Only purchased, active receptors can resolve a point-blank spawn inside their geometry.
do
    local throw = loadModule("IngredientThrow")
    local plot = instance("Model")
    plot.Name, plot.Parent = "ReceptorPlot", workspaceFake
    services.CollectionService:AddTag(plot, "PlayerPlot")
    local muncher = instance("Model")
    muncher.Name, muncher.Parent = "Muncher", plot
    local mouth = instance("Part")
    mouth.Name, mouth.Parent = "mouth", muncher
    local otherPlot = instance("Model")
    otherPlot.Name, otherPlot.Parent = "OtherPlot", workspaceFake
    services.CollectionService:AddTag(otherPlot, "PlayerPlot")
    local otherMuncher = instance("Model")
    otherMuncher.Name, otherMuncher.Parent = "Muncher", otherPlot
    otherMuncher:SetAttribute("Purchased", true)
    otherMuncher:SetAttribute("Active", true)
    local otherMouth = instance("Part")
    otherMouth.Name, otherMouth.Parent = "mouth", otherMuncher
    local otherPlayer = instance("Model")
    otherPlayer.Name = "OtherPlayer"
    local body = instance("Part")
    body.Name, body.Parent = "Torso", otherPlayer
    local item = instance("Part")
    item.Size = vec(1, 1, 1)
    for _, state in { "active", "busy", "unpurchased", "inactive", "unset", "other-receptor", "wall", "player" } do
        muncher:SetAttribute("Purchased", if state == "unset" then nil else state ~= "unpurchased")
        muncher:SetAttribute("Active", if state == "unset" then nil else state ~= "inactive")
        muncher:SetAttribute("Phase", if state == "busy" then "Processing" else "Idle")
        local blocker = if state == "wall"
            then wall
            elseif state == "player" then body
            elseif state == "other-receptor" then otherMouth
            else mouth
        local accepted = state == "active" or state == "busy" or state == "other-receptor"
        for _, gate in { "height", "initial", "path", "destination" } do
            local function obstruction(params)
                check(
                    params.FilterType == env.Enum.RaycastFilterType.Exclude
                        and params.FilterDescendantsInstances[1] == character
                        and params.RespectCanCollide == true,
                    "receptor clearance preserves character exclusion and collidable world queries"
                )
                for _, excluded in params.FilterDescendantsInstances do
                    if blocker == excluded or blocker:IsDescendantOf(excluded) then
                        return nil
                    end
                end
                return blocker
            end
            workspaceFake.Raycast = function(_, _, _, params)
                local hit = obstruction(params)
                return if gate == "height" and hit then { Instance = hit } else nil
            end
            workspaceFake.Blockcast = function(_, _, _, _, params)
                local hit = obstruction(params)
                return if gate == "path" and hit then { Instance = hit } else nil
            end
            local queries = 0
            workspaceFake.GetPartBoundsInBox = function(_, queryFrame, _, params)
                queries += 1
                local hit = obstruction(params)
                return if hit
                        and (
                            (gate == "initial")
                            or (
                                gate == "destination"
                                and (queryFrame.Position - root.CFrame.Position):Dot(root.CFrame.LookVector) > 0.01
                            )
                        )
                    then { hit }
                    else {}
            end
            local origin, reason = throw.FindOrigin(root, character, item)
            check((origin ~= nil) == accepted, state .. " receptor clearance at " .. gate)
            check(
                string.find(
                    reason,
                    if accepted then "clear origin=" else "obstructed by " .. blocker:GetFullName(),
                    1,
                    true
                ) ~= nil,
                state .. " clearance diagnostics identify the result at " .. gate
            )
        end
    end
    workspaceFake.Raycast, workspaceFake.Blockcast, workspaceFake.GetPartBoundsInBox = oldRay, oldBlock, oldOverlap
    services.CollectionService:RemoveTag(plot, "PlayerPlot")
    services.CollectionService:RemoveTag(otherPlot, "PlayerPlot")
    plot:Destroy()
    otherPlot:Destroy()
    otherPlayer:Destroy()
    item:Destroy()
end

data.GetUpgrade = getUpgrade

-- Low cover retries the complete clearance contract at successively lower heights.
do
    local throw = loadModule("IngredientThrow")
    local item = instance("Part")
    item.Size = vec(0.5, 0.5, 0.5)
    local nominal = math.max(2, item.Size.Magnitude / 2 + 0.25)
    for _, clearHeight in { nominal, 1.5, 1.0, 0.5 } do
        workspaceFake.Raycast = function(_, _, displacement)
            return if displacement.Y > clearHeight then { Instance = wall } else nil
        end
        workspaceFake.GetPartBoundsInBox = function(_, at)
            return if at.Position.Y - root.CFrame.Position.Y > clearHeight then { wall } else {}
        end
        workspaceFake.Blockcast = oldBlock
        local origin, reason = throw.FindOrigin(root, character, item)
        check(
            origin ~= nil and math.abs(origin.Position.Y - root.CFrame.Position.Y - clearHeight) < 0.001,
            "first fully clear launch height succeeds"
        )
        check(
            string.find(reason, string.format("launchHeight=%.3f", clearHeight), 1, true) ~= nil,
            "clear-origin trace identifies successful launch height"
        )
    end
    -- A clear vertical ray is insufficient when the awning overlaps the volume.
    workspaceFake.Raycast = oldRay
    workspaceFake.GetPartBoundsInBox = function(_, at)
        return if at.Position.Y - root.CFrame.Position.Y > 1.0 then { wall } else {}
    end
    local underAwning = throw.FindOrigin(root, character, item)
    check(
        underAwning ~= nil and underAwning.Position.Y == root.CFrame.Position.Y + 1,
        "initial-volume awning obstruction retries lower launch"
    )
    workspaceFake.Raycast = function(_, _, displacement)
        return if displacement.Y >= nominal then { Instance = wall } else nil
    end
    workspaceFake.GetPartBoundsInBox = function()
        return { wall }
    end
    local enclosed, reason = throw.FindOrigin(root, character, item)
    check(
        enclosed == nil and reason == "launch height obstructed by Workspace.Wall",
        "sealed position rejects with nominal reason despite different lower failures"
    )
    workspaceFake.Raycast, workspaceFake.Blockcast, workspaceFake.GetPartBoundsInBox = oldRay, oldBlock, oldOverlap
    item:Destroy()
end
