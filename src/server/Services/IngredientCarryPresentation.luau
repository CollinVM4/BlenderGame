--!strict
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.IngredientCarry)
local WorldUtil = require(script.Parent.WorldUtil)
local Presentation = {}

-- Measure every oriented part in character-local space, including off-center
-- PrimaryParts. The lowest corner, rather than the root center, clears the head.
function Presentation.Offset(visual: Instance, characterRoot: BasePart): CFrame
    local ingredientRoot = WorldUtil.Part(visual)
    assert(ingredientRoot, "Carried ingredient needs a BasePart")
    local degrees = Config.RotationDegrees
    local rotation = CFrame.Angles(math.rad(degrees.X), math.rad(degrees.Y), math.rad(degrees.Z))
    local lowest = math.huge
    local parts = visual:GetDescendants()
    table.insert(parts, visual)
    for _, part in parts do
        if part:IsA("BasePart") then
            local at = rotation * ingredientRoot.CFrame:ToObjectSpace(part.CFrame)
            local half = part.Size * 0.5
            local radiusY = math.abs(at.RightVector.Y) * half.X
                + math.abs(at.UpVector.Y) * half.Y
                + math.abs(at.LookVector.Y) * half.Z
            lowest = math.min(lowest, at.Position.Y - radiusY)
        end
    end
    local head = characterRoot.Parent and characterRoot.Parent:FindFirstChild("Head")
    local top = characterRoot.Size.Y * 0.5 + 1.5
    if head and head:IsA("BasePart") then
        local at = characterRoot.CFrame:ToObjectSpace(head.CFrame)
        top = at.Position.Y
            + (
                    math.abs(at.RightVector.Y) * head.Size.X
                    + math.abs(at.UpVector.Y) * head.Size.Y
                    + math.abs(at.LookVector.Y) * head.Size.Z
                )
                * 0.5
    end
    return CFrame.new(0, top + math.max(0, Config.HeightAboveHead) - lowest, -Config.ForwardOffset) * rotation
end

-- Keep the Tool for activation/lifecycle, but omit a named Handle so Roblox
-- cannot create a competing RightGrip. All placement is server-owned.
function Presentation.Attach(visual: Instance, tool: Tool, root: BasePart): (CFrame, () -> ())
    local ingredientRoot = WorldUtil.Part(visual)
    assert(ingredientRoot, "Carried ingredient needs a BasePart")
    local offset = Presentation.Offset(visual, root)
    local physical = visual :: any
    local rootToPivot = ingredientRoot.CFrame:ToObjectSpace(physical:GetPivot())
    physical:PivotTo(root.CFrame * offset * rootToPivot)
    local anchor = Instance.new("Part")
    anchor.Name = "CarryAnchor"
    anchor.Size = Vector3.new(0.1, 0.1, 0.1)
    anchor.Transparency = 1
    anchor.CanCollide = false
    anchor.CanTouch = false
    anchor.CanQuery = false
    anchor.Massless = true
    anchor.CFrame = root.CFrame * offset
    anchor.Parent = tool
    local parts = visual:GetDescendants()
    table.insert(parts, visual)
    for _, part in parts do
        game:GetService("CollectionService"):RemoveTag(part, "IngredientWorldItem")
        if part:IsA("ProximityPrompt") then
            part:Destroy()
        elseif part:IsA("BasePart") then
            part.Anchored = false
            part.CanCollide = false
            part.CanTouch = false
            part.Massless = true
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = anchor
            weld.Part1 = part
            weld.Parent = anchor
        end
    end
    visual.Parent = tool
    local carryWeld = Instance.new("Weld")
    carryWeld.Name = "OverheadCarry"
    carryWeld.Part0 = root
    carryWeld.Part1 = anchor
    carryWeld.C0 = offset
    carryWeld.Parent = anchor

    -- Static R6/R15 arm pose: welds override Animate without animation assets or
    -- per-frame updates. Save Enabled so cleanup restores the original rig state.
    local posed: { { Motor: Motor6D, Enabled: boolean, Weld: Weld } } = {}
    local character = root.Parent
    if character then
        for _, joint in character:GetDescendants() do
            if not joint:IsA("Motor6D") or not joint.Part0 or not joint.Part1 then
                continue
            end
            local shoulder = joint.Name == "Right Shoulder"
                or joint.Name == "Left Shoulder"
                or joint.Name == "RightShoulder"
                or joint.Name == "LeftShoulder"
            local lowerArm = joint.Name == "RightElbow"
                or joint.Name == "LeftElbow"
                or joint.Name == "RightWrist"
                or joint.Name == "LeftWrist"
            if not shoulder and not lowerArm then
                continue
            end
            local weld = Instance.new("Weld")
            weld.Name = "OverheadArmPose"
            weld.Part0 = joint.Part0
            weld.Part1 = joint.Part1
            weld.C0 = if shoulder
                then CFrame.new(joint.C0.Position) * CFrame.Angles(math.pi, 0, 0) * joint.C0.Rotation
                else joint.C0
            weld.C1 = joint.C1
            table.insert(posed, { Motor = joint, Enabled = joint.Enabled, Weld = weld })
            joint.Enabled = false
            weld.Parent = tool
        end
    end
    return offset * rootToPivot,
        function()
            for _, pose in posed do
                pose.Weld:Destroy()
                if pose.Motor.Parent then
                    pose.Motor.Enabled = pose.Enabled
                end
            end
        end
end

return Presentation
