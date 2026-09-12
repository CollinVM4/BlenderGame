--!strict
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.IngredientCarry)
local WorldUtil = require(script.Parent.WorldUtil)
local Presentation = {}

-- Measure every oriented part in character-local space, including off-center
-- PrimaryParts. The lowest corner, rather than the root center, clears the head.
function Presentation.Offset(visual: Instance, characterRoot: BasePart, stackHeight: number?): (CFrame, number)
    local ingredientRoot = WorldUtil.Part(visual)
    assert(ingredientRoot, "Carried ingredient needs a BasePart")
    local degrees = Config.RotationDegrees
    local rotation = CFrame.Angles(math.rad(degrees.X), math.rad(degrees.Y), math.rad(degrees.Z))
    local lowest = math.huge
    local highest = -math.huge
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
            highest = math.max(highest, at.Position.Y + radiusY)
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
    return CFrame.new(0, top + math.max(0, Config.HeightAboveHead) - lowest + (stackHeight or 0), -Config.ForwardOffset)
        * rotation,
        highest - lowest + Config.StackGap
end

-- Keep the Tool for activation/lifecycle, but omit a named Handle so Roblox
-- cannot create a competing RightGrip. All placement is server-owned.
function Presentation.Attach(
    visual: Instance,
    tool: Tool,
    root: BasePart,
    stackHeight: number?
): (CFrame, () -> (), number)
    local ingredientRoot = WorldUtil.Part(visual)
    assert(ingredientRoot, "Carried ingredient needs a BasePart")
    local offset, height = Presentation.Offset(visual, root, stackHeight)
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

    return offset * rootToPivot, function()
        anchor:Destroy()
        visual:Destroy()
    end, height
end

return Presentation
