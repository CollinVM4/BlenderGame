-- Presentation only: clearance, launch placement, arm/Tool geometry.
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

local function equip()
    local item = ingredients.Spawn("Banana", translate(), nil, true)
    setup(inventory.CarryWorldItem(player, item), "authoritative pickup equips visual")
    local tool = character:FindFirstChildOfClass("Tool")
    return tool
end
local function restored()
    for _, motor in motors do
        check(motor.Enabled == (motor.Name ~= "LeftWrist"), "original motor state restored")
    end
end
local tool = equip()
local freshValue = root:FindFirstChild("CarryValue")
check(freshValue and freshValue:FindFirstChild("Value").Text == "$2K", "fresh Banana shows one carried value")
check(not freshValue:FindFirstChild("RipenessDetails"), "fresh carry has no rarity or Ripeness row")
check(not tool.RequiresHandle and not tool:FindFirstChild("Handle"), "passive Tool has no default hand grip")
for _, motor in motors do
    check(motor.Enabled == (motor.Name ~= "LeftWrist"), "carry leaves arm motors unchanged")
end
check(not tool:FindFirstChild("OverheadArmPose"), "no custom arm pose")
inventory.ThrowHeld(player)
restored()
equip()
local dropped = inventory.DropHeld(player)
check(dropped:GetPivot().Position.Y == root.CFrame.Position.Y + 2, "drop height unchanged")
check(dropped:GetPivot().Position.Z == root.CFrame.Position.Z - 3, "drop forward placement unchanged")
restored()
equip()
inventory.ClearHeld(player)
restored()

-- Overhead stack stays visible and vertical regardless of hotbar selection.
local function visualFor(t)
    for _, host in character:GetChildren() do
        if
            host.Name == "IngredientCarryVisuals"
            and host:GetAttribute("CarryItemId") == t:GetAttribute("CarryItemId")
        then
            return host
        end
    end
    error("missing overhead visual")
end
local slots, hosts, positions = {}, {}, {}
for _, id in { "Strawberry", "Ice", "Cherries" } do
    setup(inventory.CarryWorldItem(player, ingredients.Spawn(id, translate(), nil, true)), "stack visual pickup")
    local t = character:FindFirstChildOfClass("Tool")
    table.insert(slots, t)
    local host = visualFor(t)
    table.insert(hosts, host)
    table.insert(positions, host:FindFirstChild("CarryAnchor"):FindFirstChild("OverheadCarry").C0.Position)
end
for index, position in positions do
    check(position.X == 0 and position.Z == 0, "overhead stack remains vertical")
    if index > 1 then
        check(position.Y > positions[index - 1].Y, "pickup order increases overhead height")
    end
end
local definitions = loadModule("Ingredients")
local money = loadModule("MoneyFormat")
local valueGui = root:FindFirstChild("CarryValue")
local fullValue = definitions.Strawberry.Value + definitions.Ice.Value + definitions.Cherries.Value
check(valueGui:FindFirstChild("Value").Text == money.Compact(fullValue), "carried ingredient total uses one monetary label")
check(not valueGui:FindFirstChild("RipenessDetails"), "ingredient stack has no rarity or Fresh/Ripe row")
humanoid:EquipTool(slots[1])
slots[1].Parent = backpack
slots[1].Unequipped:Fire()
check(valueGui:FindFirstChild("Value").Text == money.Compact(fullValue), "hotbar selection preserves carried value")
for index, host in hosts do
    check(host:IsDescendantOf(character), "unequipped ingredients remain visible on character")
    local position = host:FindFirstChild("CarryAnchor"):FindFirstChild("OverheadCarry").C0.Position
    check((position - positions[index]).Magnitude < 1e-6, "selection never moves overhead items")
end
-- Stash removal uses the same per-record removal/reflow path.
local fixture = instance("Model")
local stashPart = part("Slot", fixture, vec(1, 1, 1), translate())
stashPart:SetAttribute("SlotIndex", 1)
inventory.Init({
    IngredientService = ingredients,
    PlayerDataService = data,
    TycoonService = {
        GetPlot = function()
            return fixture
        end,
        GetFixtures = function()
            return { fixture }
        end,
        GetOwner = function()
            return player
        end,
    },
})
humanoid:EquipTool(slots[2])
setup(inventory.Deposit(player, "Ice", 1), "stash middle visual")
check(
    hosts[2].Destroyed and not hosts[1].Destroyed and not hosts[3].Destroyed,
    "only removed item's overhead visual disappears"
)
local lower = hosts[1]:FindFirstChild("CarryAnchor"):FindFirstChild("OverheadCarry").C0.Position
local upper = hosts[3]:FindFirstChild("CarryAnchor"):FindFirstChild("OverheadCarry").C0.Position
check((lower - positions[1]).Magnitude < 1e-6, "middle removal preserves lower visual position")
check(math.abs(upper.Y - positions[2].Y) < 1e-6, "middle removal closes exactly the removed stack gap")
check(valueGui:FindFirstChild("Value").Text == money.Compact(fullValue - definitions.Ice.Value)
    and not valueGui:FindFirstChild("RipenessDetails"), "stash deposit updates value without metadata")
inventory.ClearHeld(player)
check(hosts[1].Destroyed and hosts[3].Destroyed, "clear retires remaining overhead visuals")
check(not root:FindFirstChild("CarryValue"), "empty inventory hides carried value")

carry.RefreshValue(player, {
    { Smoothie = { BlendId = "carry-value", Ingredients = { "Strawberry", "Strawberry", "Banana" } } },
})
check(
    root:FindFirstChild("CarryValue"):FindFirstChild("Value").Text
        == money.Compact(definitions.Strawberry.Value * 2 + definitions.Banana.Value),
    "held smoothie contributes composition subtotal including duplicates"
)
carry.RefreshValue(player, {
    { Smoothie = { BlendId = "carry-value", Ingredients = { "Strawberry", "Strawberry", "Banana" } } },
    { Id = "Strawberry", Item = loadModule("IngredientItem").New("Strawberry", "held-only"), Height = 1 },
})
check(root:FindFirstChild("CarryValue"):FindFirstChild("Value").Text
    == money.Compact(definitions.Strawberry.Value * 3 + definitions.Banana.Value),
    "mixed carry totals smoothie and ingredient effective values")
local ripeBanana = loadModule("IngredientItem").New("Banana", "ripe-held")
ripeBanana.IsRipe = true
carry.RefreshValue(player, { { Id = "Banana", Item = ripeBanana, Height = 1 } })
local ripeValue = root:FindFirstChild("CarryValue")
check(ripeValue:FindFirstChild("Value").Text == "$2.5K", "ripe Banana uses shared effective value")
check(not ripeValue:FindFirstChild("RipenessDetails"), "ripe carry shows value without rarity or Ripe text")
inventory.ClearHeld(player)
