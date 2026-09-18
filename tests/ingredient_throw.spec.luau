-- Throw contracts use real inventory/ingredient services and arbitrary avatar geometry.
data.SetCash(player, 10000)
local upgrades = loadModule("Upgrades")
for tier = 2, #upgrades.CarryCapacity do
    setup(data.PurchaseUpgrade(player, "CarryCapacity", tier), "unlock space for three ingredients")
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
for _, dimensions in { vec(2, 2, 1), vec(8, 0.5, 6), vec(1, 9, 1) } do
    root.Size, head.Size = dimensions, dimensions
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
    character:FindFirstChildOfClass("Tool").Activated:Fire()
    services.CollectionService.AddTag = publish
    check(#released == 1, "one Throw action publishes exactly one world item")
    local thrown = released[1]
    check(ingredients.GetRecord(thrown).Id == "Tire", "newest pickup throws first")
    services.Debris.AddItem = addDebris
    local localFrame = root.CFrame:ToObjectSpace(thrown:GetPivot())
    check((localFrame.Position - vec(0, 2, -5)).Magnitude < 0.0001, "origin is fixed in HRP space for every avatar")
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
    for _, child in survivorTool:GetChildren() do
        if child.Name ~= "CarryAnchor" and child:IsA("BasePart") then
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
    check(ingredients.GetRecord(inventory.ThrowHeld(player)).Id == "Banana", "second pickup stays usable")
    check(ingredients.GetRecord(inventory.ThrowHeld(player)).Id == "Strawberry", "first pickup stays usable")
end
root.CFrame, root.Size, head.CFrame, head.Size = oldRootFrame, oldRootSize, oldHeadFrame, oldHeadSize
