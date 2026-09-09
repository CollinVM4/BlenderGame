--!strict
-- Cosmetic Instances only: never register, spawn, or consume world inventory here.
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Presentation = {}

-- DisplayScale is the item's longest bounding-box dimension relative to the
-- derived display plane's smaller dimension. HeightOffset is clearance in studs.
local DisplayScale = 0.16
local DisplayHeightOffset = 0.12
local DisplaySpacing = 1.08 -- Center-to-center spacing in item-size units.
local DisplayFifthLift = 0.65 -- Fifth item's extra height in item-size units.

-- Temporary: print geometry once for the first occupied Slot3 in Studio.
local DisplayDiagnostics = true
local DiagnosticSlotIndex = 3
local diagnosticPrinted = false

local function displaySurface(slot: BasePart)
    local axes = { slot.CFrame.RightVector, slot.CFrame.UpVector, slot.CFrame.LookVector * -1 }
    local sizes = { slot.Size.X, slot.Size.Y, slot.Size.Z }
    local names = { "X", "Y", "Z" }
    local normalIndex = 1
    for index = 2, 3 do
        if math.abs(axes[index]:Dot(Vector3.yAxis)) > math.abs(axes[normalIndex]:Dot(Vector3.yAxis)) then
            normalIndex = index
        end
    end
    local normal = axes[normalIndex]
    if normal:Dot(Vector3.yAxis) < 0 then
        normal *= -1
    end
    local widthIndex = if normalIndex == 1 then 2 else 1
    local depthIndex = 6 - normalIndex - widthIndex
    local tangent = axes[widthIndex]
    -- Complete a right-handed frame with local Y pointing out of the top face.
    -- The second tangent is the remaining slot axis, with the appropriate sign.
    local depthTangent = tangent:Cross(normal)
    local thickness = sizes[normalIndex]
    local topCenter = slot.Position + normal * (thickness / 2)
    return CFrame.fromMatrix(topCenter, tangent, normal, depthTangent),
        sizes[widthIndex],
        sizes[depthIndex],
        thickness,
        names[normalIndex]
end

-- Display-plane X/Z layouts, centered around their horizontal centroid.
local Layouts = {
    { Vector3.new(0, 0, 0) },
    { Vector3.new(-0.5, 0, 0), Vector3.new(0.5, 0, 0) },
    { Vector3.new(-0.5, 0, 1 / 3), Vector3.new(0.5, 0, 1 / 3), Vector3.new(0, 0, -2 / 3) },
    { Vector3.new(-0.5, 0, -0.5), Vector3.new(0.5, 0, -0.5), Vector3.new(-0.5, 0, 0.5), Vector3.new(0.5, 0, 0.5) },
    -- Move the four lower items forward slightly to balance the raised back item.
    {
        Vector3.new(-0.5, 0, -0.4),
        Vector3.new(0.5, 0, -0.4),
        Vector3.new(-0.5, 0, 0.6),
        Vector3.new(0.5, 0, 0.6),
        Vector3.new(0, 0, -0.4),
    },
}
function Presentation.Clear(slot: BasePart)
    local old = slot:FindFirstChild("StashDisplay")
    if old then
        old:Destroy()
    end
end
function Presentation.Refresh(slot: BasePart, state: any, ingredients: any)
    Presentation.Clear(slot)
    slot:SetAttribute("StashIngredientId", state and state.IngredientId)
    slot:SetAttribute("StashCount", state and state.Count or 0)
    slot:SetAttribute("StashProtected", state and state.Protected or slot:GetAttribute("SlotIndex") <= 2)
    if not state or not state.IngredientId or state.Count == 0 then
        return
    end
    local folder = Instance.new("Folder")
    folder.Name = "StashDisplay"
    folder.Parent = slot
    local surface, width, depth, thickness, normalAxis = displaySurface(slot)
    local itemSize = math.min(width, depth) * DisplayScale
    if
        DisplayDiagnostics
        and not diagnosticPrinted
        and RunService:IsStudio()
        and slot:GetAttribute("SlotIndex") == DiagnosticSlotIndex
    then
        diagnosticPrinted = true
        print(
            string.format(
                "[StashPresentation] %s Size=%s normalAxis=%s thickness=%.3f usableWidth=%.3f usableDepth=%.3f targetItemSize=%.3f topSurfaceCenter=%s",
                slot:GetFullName(),
                tostring(slot.Size),
                normalAxis,
                thickness,
                width,
                depth,
                itemSize,
                tostring(surface.Position)
            )
        )
    end
    local spacing = itemSize * DisplaySpacing
    local layout = Layouts[state.Count]
    for i = 1, state.Count do
        local proxy = ingredients.CreateVisual(state.IngredientId)
        if not proxy then
            continue
        end
        local descendants = proxy:GetDescendants()
        table.insert(descendants, proxy)
        for _, child in descendants do
            for _, tag in CollectionService:GetTags(child) do
                CollectionService:RemoveTag(child, tag)
            end
            child:SetAttribute("SlotIndex", nil)
            child:SetAttribute("WorldItemId", nil)
            child:SetAttribute("IngredientId", nil)
            child:SetAttribute("OwnerUserId", nil)
            if child:IsA("ProximityPrompt") or child:IsA("ClickDetector") or child:IsA("LuaSourceContainer") then
                child:Destroy()
            elseif child:IsA("BasePart") then
                child.PivotOffset = CFrame.new()
                child.Anchored = true
                child.CanCollide = false
                child.CanQuery = false
                child.CanTouch = false
            end
        end
        -- Remove the source pivot's translation/orientation before measuring.
        -- A fresh wrapper with no PrimaryPart gives all templates the same axes.
        local physical = proxy :: any
        physical:PivotTo(CFrame.new())
        local model = Instance.new("Model")
        model.Name = "DisplayIngredient"
        model.WorldPivot = CFrame.new()
        proxy.Parent = model
        local bounds, size = model:GetBoundingBox()
        -- Center the wrapper pivot on actual geometry, independent of authored
        -- pivots. Uniform scaling can enlarge small templates as well as shrink.
        model.WorldPivot = bounds
        model:ScaleTo(itemSize / math.max(size.X, size.Y, size.Z, 0.01))
        local _, scaled = model:GetBoundingBox()
        local offset = layout[i] * spacing
        local lift = if i == 5 then itemSize * DisplayFifthLift else 0
        local target = surface * CFrame.new(offset.X, DisplayHeightOffset + scaled.Y / 2 + lift, offset.Z)
        model:PivotTo(target)
        model.Parent = folder
    end
end
return Presentation
