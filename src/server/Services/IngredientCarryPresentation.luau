--!strict
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.IngredientCarry)
local Item = require(game:GetService("ReplicatedStorage").Shared.IngredientItem)
local MoneyFormat = require(game:GetService("ReplicatedStorage").Shared.MoneyFormat)
local WorldUtil = require(script.Parent.WorldUtil)
local Presentation = {}

local function headTop(characterRoot: BasePart): number
    local head = characterRoot.Parent and characterRoot.Parent:FindFirstChild("Head")
    if head and head:IsA("BasePart") then
        local at = characterRoot.CFrame:ToObjectSpace(head.CFrame)
        return at.Position.Y
            + (
                    math.abs(at.RightVector.Y) * head.Size.X
                    + math.abs(at.UpVector.Y) * head.Size.Y
                    + math.abs(at.LookVector.Y) * head.Size.Z
                )
                * 0.5
    end
    return characterRoot.Size.Y * 0.5 + 1.5
end

-- Called only by inventory synchronization, using its private held records.
-- Height uses the same measured stack extents as Attach, without waiting for weld physics.
function Presentation.RefreshValue(player: Player, stack: { any })
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root or not root:IsA("BasePart") then
        return
    end
    local previous = root:FindFirstChild("CarryValue")
    if #stack == 0 then
        if previous then
            previous:Destroy()
        end
        return
    end
    local total, height = 0, 0
    for _, item in stack do
        if item.Smoothie then
            total += Item.GetSmoothieValue(item.Smoothie, workspace:GetServerTimeNow())
        else
            total += Item.GetIngredientValue(item.Item, workspace:GetServerTimeNow())
            height += item.Height
        end
    end
    local gui = if previous then previous :: BillboardGui else Instance.new("BillboardGui")
    local staleDetails = gui:FindFirstChild("RipenessDetails")
    if staleDetails then
        staleDetails:Destroy()
    end
    gui.Size = UDim2.fromOffset(180, 44)
    if not previous then
        gui.Name = "CarryValue"
        gui.Adornee = root
        gui.AlwaysOnTop = true
        gui.ResetOnSpawn = false
        gui.MaxDistance = 100
        local label = Instance.new("TextLabel")
        label.Name = "Value"
        label.Size = UDim2.fromScale(1, 1)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBold
        label.TextSize = 28
        label.TextColor3 = Color3.fromRGB(100, 235, 120)
        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.new(0, 0, 0)
        stroke.Thickness = 3
        stroke.Parent = label
        label.Parent = gui
        gui.Parent = root
    end
    local top = headTop(root) + math.max(0, Config.HeightAboveHead) + math.max(0, height - Config.StackGap)
    gui.StudsOffsetWorldSpace = Vector3.new(0, top + 1, -Config.ForwardOffset)
    local label = gui:FindFirstChild("Value") :: TextLabel
    label.Size = UDim2.fromScale(1, 1)
    label.Text = MoneyFormat.Compact(total)
end

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
    local top = headTop(characterRoot)
    return CFrame.new(0, top + math.max(0, Config.HeightAboveHead) - lowest + (stackHeight or 0), -Config.ForwardOffset)
        * rotation,
        highest - lowest + Config.StackGap
end

-- Visuals live on the character independently of Backpack selection.
-- All placement is server-owned; no hand grip is created.
function Presentation.Attach(
    visual: Instance,
    host: Instance,
    root: BasePart,
    stackHeight: number?
): (CFrame, () -> (), number, (number) -> ())
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
    anchor.Parent = host
    local parts = visual:GetDescendants()
    table.insert(parts, visual)
    -- The successful pickup consumed the authoritative world object. Its cloned
    -- visual releases every part before creating any carry welds.
    for _, part in parts do
        if part:IsA("BasePart") then
            part.Anchored = false
        end
    end
    visual:SetAttribute("FrozenUntilPickup", nil)
    for _, part in parts do
        game:GetService("CollectionService"):RemoveTag(part, "IngredientWorldItem")
        if part:IsA("ProximityPrompt") then
            part:Destroy()
        elseif part:IsA("BasePart") then
            part.CanCollide = false
            part.CanTouch = false
            part.Massless = true
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = anchor
            weld.Part1 = part
            weld.Parent = anchor
        end
    end
    visual.Parent = host
    local carryWeld = Instance.new("Weld")
    carryWeld.Name = "OverheadCarry"
    carryWeld.Part0 = root
    carryWeld.Part1 = anchor
    carryWeld.C0 = offset
    carryWeld.Parent = anchor

    return offset * rootToPivot,
        function()
            anchor:Destroy()
            visual:Destroy()
        end,
        height,
        function(amount: number)
            carryWeld.C0 = CFrame.new(0, -amount, 0) * carryWeld.C0
        end
end

return Presentation
