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
check(not tool.RequiresHandle and not tool:FindFirstChild("Handle"), "Tool keeps activation without default hand grip")
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
