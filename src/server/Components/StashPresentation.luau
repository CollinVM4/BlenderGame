--!strict
-- Cosmetic Instances only: never register, spawn, or consume world inventory here.
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local SmoothieGeometry = require(script.Parent.Parent.Services.SmoothieGeometry)
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Constants.Economy).NormalStash
local MoneyFormat = require(Shared.MoneyFormat)
local IngredientName = require(Shared.IngredientName)
local Item = require(Shared.IngredientItem)
local RipenessStyle = require(Shared.Constants.RipenessPresentation)
local Presentation = {}
local FilledIndicatorColor = Color3.fromRGB(0, 255, 0)
local EmptyIndicatorColor = Color3.fromRGB(117, 0, 0)

local function refreshIndicators(slot: BasePart, state: any)
    -- The resolver supplies the interaction base; authored indicators may be its
    -- siblings inside the slot model, or descendants of a standalone slot part.
    local parent = slot.Parent
    local root: Instance = if parent
            and parent:IsA("Model")
            and (
                parent.PrimaryPart == slot
                or parent:FindFirstChild("SlotIndicator") ~= nil
                or string.match(parent.Name, "^LockedSlot%d+$")
                or string.match(parent.Name, "^Slot%d+$")
            )
        then parent
        else slot
    local indicators: { { Part: BasePart, X: number, Y: number, Z: number, Order: number } } = {}
    for order, child in root:GetDescendants() do
        if child:IsA("BasePart") and child.Name == "SlotIndicator" then
            local offset = child.Position - slot.Position
            table.insert(indicators, {
                Part = child,
                X = offset:Dot(slot.CFrame.RightVector),
                Y = offset:Dot(slot.CFrame.UpVector),
                Z = offset:Dot(slot.CFrame.LookVector * -1),
                Order = order,
            })
        end
    end
    table.sort(indicators, function(a, b)
        if a.X ~= b.X then
            return a.X < b.X
        elseif a.Y ~= b.Y then
            return a.Y < b.Y
        elseif a.Z ~= b.Z then
            return a.Z < b.Z
        end
        return a.Order < b.Order
    end)
    local protected = (slot:GetAttribute("StashLogicalSlotIndex") or slot:GetAttribute("SlotIndex") or 0)
        <= Config.Protected
    local capacity = if state then state.Capacity else nil
    if type(capacity) ~= "number" or capacity ~= capacity then
        capacity = if protected then 1 else Config.IngredientCapacity
    end
    local occupied = if state and state.ItemType == "Smoothie"
        then state.Count
        elseif state and type(state.Ingredients) == "table" then #state.Ingredients
        else 0
    local filled = math.clamp(math.floor(occupied), 0, math.min(#indicators, math.max(0, math.floor(capacity))))
    for index, indicator in indicators do
        indicator.Part.Color = if index <= filled then FilledIndicatorColor else EmptyIndicatorColor
    end
end

local function showValue(slot: BasePart, folder: Folder, surface: CFrame, value: number)
    local gui = Instance.new("BillboardGui")
    gui.Name = "SlotValue"
    gui.Adornee = slot
    gui.Size = UDim2.fromOffset(180, 44)
    gui.StudsOffsetWorldSpace = surface.Position - slot.Position + Vector3.new(0, 5, 0)
    gui.AlwaysOnTop = true
    gui.ResetOnSpawn = false
    gui.MaxDistance = RipenessStyle.StashMaxDistance

    local label = Instance.new("TextLabel")
    label.Name = "Value"
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 28
    label.TextColor3 = Color3.fromRGB(100, 235, 120)
    label.Text = MoneyFormat.Compact(value)
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.new(0, 0, 0)
    stroke.Thickness = 3
    stroke.Parent = label
    label.Parent = gui
    gui.Parent = folder
end

-- Footprint and height are relative to the display plane's smaller dimension.
-- Size limits are in studs: clamp the target footprint, not the source scale,
-- so both tiny and huge templates can reach the same visible size.
local DisplayFootprintScale = 0.30
local DisplayMaxHeightScale = 0.90 -- Safety cap for unusually tall/thin meshes.
local DisplayMinSize = 0.25
local DisplayMaxSize = 4.0 -- Also caps height; height safety takes precedence.
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
function Presentation.Refresh(slot: BasePart?, state: any, ingredients: any)
    if not slot then
        return
    end
    if
        type(state) ~= "table"
        or type(state.Count) ~= "number"
        or state.Count ~= state.Count
        or state.Count < 0
        or state.Count % 1 ~= 0
        or (state.IngredientId and type(state.Ingredients) ~= "table")
    then
        state = nil
    end
    if state and state.IngredientId then
        for index = 1, state.Count do
            local unit = state.Ingredients[index]
            if type(unit) ~= "table" or type(unit.IngredientId) ~= "string" then
                state = nil
                break
            end
        end
    end
    Presentation.Clear(slot)
    refreshIndicators(slot, state)
    slot:SetAttribute("StashIngredientId", state and state.IngredientId)
    slot:SetAttribute("StashItemType", state and state.ItemType)
    slot:SetAttribute("StashCapacity", state and state.Capacity or Config.IngredientCapacity)
    slot:SetAttribute("StashCount", state and state.Count or 0)
    slot:SetAttribute(
        "StashProtected",
        state and state.Protected
            or (slot:GetAttribute("StashLogicalSlotIndex") or slot:GetAttribute("SlotIndex") or 0)
                <= Config.Protected
    )
    if not state or state.Count == 0 or (not state.IngredientId and not state.Smoothie) then
        return
    end
    local folder = Instance.new("Folder")
    folder.Name = "StashDisplay"
    folder.Parent = slot
    local surface, width, depth, thickness, normalAxis = displaySurface(slot)
    showValue(slot, folder, surface, state.Value)
    local slotSize = math.min(width, depth)
    local itemSize = math.clamp(slotSize * DisplayFootprintScale, DisplayMinSize, DisplayMaxSize)
    local maxHeight = math.min(slotSize * DisplayMaxHeightScale, DisplayMaxSize)
    local shouldPrintDiagnostic = DisplayDiagnostics
        and not diagnosticPrinted
        and RunService:IsStudio()
        and slot:GetAttribute("SlotIndex") == DiagnosticSlotIndex
    local spacing = itemSize * DisplaySpacing
    local layout = Layouts[state.Count]
    for i = 1, state.Count do
        local proxy = if state.ItemType == "Smoothie"
            then SmoothieGeometry.CreateVisual(state.Smoothie)
            else ingredients.CreateVisual(state.Ingredients[i].IngredientId, state.Ingredients[i])
        if not proxy then
            continue
        end
        if state.ItemType ~= "Smoothie" then
            local unit = state.Ingredients[i]
            Item.ApplySourceMetadata(proxy, unit)
            if unit.IngredientId == "PlayerHead" then
                proxy.Name =
                    IngredientName.Resolve("PlayerHead", "Player Head", unit.SourceUserId, unit.SourceDisplayName)
            end
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
        -- The identity-oriented wrapper's X/Z axes become the display plane's
        -- X/Z axes at placement, so these bounds already reflect display orientation.
        local footprint = math.max(size.X, size.Z)
        local scaleFactor = math.min(itemSize / math.max(footprint, 0.000001), maxHeight / math.max(size.Y, 0.000001))
        model:ScaleTo(scaleFactor)
        local _, scaled = model:GetBoundingBox()
        if shouldPrintDiagnostic and not diagnosticPrinted then
            diagnosticPrinted = true
            print(
                string.format(
                    "[StashPresentation] %s Size=%s normalAxis=%s thickness=%.3f usableWidth=%.3f usableDepth=%.3f originalBounds=%s horizontalFootprint=%.6f targetFootprint=%.3f scaleFactor=%.6g scaledBounds=%s topSurfaceCenter=%s",
                    slot:GetFullName(),
                    tostring(slot.Size),
                    normalAxis,
                    thickness,
                    width,
                    depth,
                    tostring(size),
                    footprint,
                    itemSize,
                    scaleFactor,
                    tostring(scaled),
                    tostring(surface.Position)
                )
            )
        end
        local offset = layout[i] * spacing
        local lift = if i == 5 then itemSize * DisplayFifthLift else 0
        local target = surface * CFrame.new(offset.X, DisplayHeightOffset + scaled.Y / 2 + lift, offset.Z)
        model:PivotTo(target)
        model.Parent = folder
    end
end
return Presentation
