--!strict
-- Paths are plot-relative except the shared Central Market. Folder assemblies expand into visible parts.
local CollectionService = game:GetService("CollectionService")
local Targets = {}
local paths: { [string]: { { string } } } = {
    ClaimPlot = { { "PlotIdentity", "ClaimVisual" } },
    Ladder = { { "Ladder" } },
    Blender = { { "Blender", "Glass" } },
    Turbine = {
        { "Turbine Wheel", "turbine", "anchor" },
        { "Turbine Wheel", "turbine", "blade" },
        { "Turbine Wheel", "turbine", "stem" },
    },
    Dispenser = { { "Dispenser" } },
    BuyRow = { { "Farm", "Row1", "PurchasePoint1" } },
    Counter = { { "Customer Area", "Counter", "Base Structure", "Base" } },
}
-- Raw authored roots are also available to the opt-in presentation diagnostics.
function Targets.GetRoots(plot: Instance?, stage: string, stashSlot: number?): { Instance }
    local roots: { Instance } = {}
    if stage == "Market" or stage == "MarketJump" then
        local market = workspace:FindFirstChild("Central Market")
        local base = if market
            then market:FindFirstChild(if stage == "MarketJump" then "JUMP1HIGHLIGHT" else "CentralMarketBase")
            else nil
        return if base and base:IsA("BasePart") then { base } else roots
    end
    if not plot or not plot:IsDescendantOf(workspace) then
        return roots
    end
    if stage == "Plant" or stage == "Harvest" then
        local farm = plot:FindFirstChild("Farm")
        local row = if farm then farm:FindFirstChild("Row1") else nil
        if stage == "Harvest" and row then
            for _, reference in row:GetChildren() do
                if reference.Name == "TutorialHarvestTarget" and reference:IsA("ObjectValue") then
                    local product = reference.Value
                    if product and product:IsDescendantOf(workspace) and not table.find(roots, product) then
                        table.insert(roots, product)
                    end
                end
            end
            if #roots > 0 then
                return roots
            end
        end
        local visual = if row then row:FindFirstChild("Visual") else nil
        if visual then
            for _, name in { "Pebble", "plank2", "Pebble & plank2" } do
                local spot = visual:FindFirstChild(name)
                if spot then
                    table.insert(roots, spot)
                end
            end
            if #roots == 0 then
                table.insert(roots, visual)
            end
        end
        return roots
    end
    if stage == "Stash" then
        if not stashSlot then
            return roots
        end
        local fixtures = {}
        for _, fixture in CollectionService:GetTagged("PlayerStash") do
            if fixture:IsDescendantOf(plot) then
                table.insert(fixtures, fixture)
            end
        end
        local stash = if #fixtures == 1 then fixtures[1] else plot:FindFirstChild("Stash")
        if not stash then
            return roots
        end
        local slots = {}
        for _, part in stash:GetDescendants() do
            if part:IsA("BasePart") and part:GetAttribute("SlotIndex") == stashSlot then
                table.insert(slots, part)
            end
        end
        local authoredSlot = stash:FindFirstChild("Slot" .. stashSlot)
        if
            #slots ~= 1
            or not authoredSlot
            or (slots[1] ~= authoredSlot and not slots[1]:IsDescendantOf(authoredSlot))
        then
            return roots
        end
        -- Exact authored slot and nested lowercase base. A slot Model already
        -- includes its base, so it receives just one local gleam.
        local slotTarget = if authoredSlot:IsA("Model") or authoredSlot:IsA("BasePart") then authoredSlot else slots[1]
        table.insert(roots, slotTarget)
        local base = authoredSlot:FindFirstChild("base")
        if base and base:IsA("BasePart") and base ~= slotTarget and not slotTarget:IsA("Model") then
            table.insert(roots, base)
        end
        return roots
    end
    local targetStage = if stage == "DrainBatch" then "Dispenser" elseif stage == "FinishBatch" then "Turbine" else stage
    local stagePaths: { { string } } = paths[targetStage] or {}
    for _, path in stagePaths do
        local object: Instance? = plot
        for _, name in path do
            object = if object then object:FindFirstChild(name) else nil
        end
        if object then
            table.insert(roots, object)
        end
    end
    return roots
end
function Targets.Resolve(plot: Instance?, stage: string, stashSlot: number?, customer: Instance?): { Instance }
    local result: { Instance } = {}
    if stage ~= "Market" and stage ~= "MarketJump" and (not plot or not plot:IsDescendantOf(workspace)) then
        return result
    end
    if stage == "Serve" or stage == "Order" or stage == "NextCustomer" then
        if
            customer
            and customer:IsDescendantOf(workspace)
            and customer:GetAttribute("PlotSessionId") == plot:GetAttribute("PlotSessionId")
        then
            table.insert(result, customer)
        end
        return result
    end
    local function add(object: Instance?)
        if not object then
            return
        end
        if object:IsA("Model") or object:IsA("BasePart") then
            table.insert(result, object)
        else
            for _, part in object:GetDescendants() do
                if part:IsA("BasePart") and part.Transparency < 1 then
                    table.insert(result, part)
                end
            end
        end
    end
    for _, object in Targets.GetRoots(plot, stage, stashSlot) do
        add(object)
    end
    return result
end
local function stationary(object: Instance?): boolean
    if not object or not object:IsA("BasePart") then
        return false
    end
    local root = object.AssemblyRootPart
    return object.Anchored or (root and root.Anchored) == true
end
local function stableMarker(object: Instance?): (BasePart | Attachment)?
    if object and object:IsA("Attachment") and stationary(object.Parent) then
        return object
    elseif object and object:IsA("BasePart") and stationary(object) then
        return object
    end
    return nil
end
local function stemTarget(plot: Instance): (BasePart | Attachment)?
    local wheel = plot:FindFirstChild("Turbine Wheel")
        or plot:FindFirstChild("Turbine", true)
        or plot:FindFirstChild("turbine", true)
    if not wheel then
        return nil
    end
    -- Never use the TurbineWheel tag: it intentionally identifies spinning geometry.
    for _, name in { "stem", "Stem", "shaft", "Shaft" } do
        local stem = wheel:FindFirstChild(name, true)
        if stem and stem:IsA("BasePart") and stationary(stem) then
            for _, markerName in { "TurbineBeamTarget", "TurbinePromptOrigin" } do
                local marker = stableMarker(stem:FindFirstChild(markerName))
                if marker then
                    return marker
                end
            end
            return stem
        end
    end
    return nil -- Retry when the stationary stem replicates; never substitute a blade/proxy.
end
local function dispenserTarget(plot: Instance): (BasePart | Attachment)?
    local marker = stableMarker(plot:FindFirstChild("DispenserTextOrigin", true))
    if marker then
        return marker
    end
    local dispenser = plot:FindFirstChild("Dispenser")
    if not dispenser then
        return nil
    end
    for _, child in dispenser:GetDescendants() do
        if child:IsA("ProximityPrompt") and child.Parent and child.Parent:IsA("Attachment") then
            local origin = stableMarker(child.Parent)
            if origin then
                return origin
            end
        end
    end
    if dispenser:IsA("BasePart") and stationary(dispenser) then
        return dispenser
    end
    for _, child in dispenser:GetDescendants() do
        if child:IsA("BasePart") and stationary(child) then
            return child
        end
    end
    return nil
end
-- Resolve inside the validated plot, or the exact shared Market root.
function Targets.ResolveBeam(
    plot: Instance?,
    stage: string,
    stashSlot: any,
    objective: Instance?
): (BasePart | Attachment)?
    if stage == "Market" or stage == "MarketJump" then
        local base = Targets.GetRoots(nil, stage)[1]
        return if base == objective and base and base:IsA("BasePart") then base else nil
    end
    if not plot or not plot:IsDescendantOf(workspace) then
        return nil
    end
    if stage == "Turbine" or stage == "FinishBatch" then
        return stemTarget(plot)
    elseif stage == "Dispenser" or stage == "DrainBatch" then
        return dispenserTarget(plot)
    end
    if not objective or not objective:IsDescendantOf(workspace) then
        return nil
    end
    if stage == "Order" or stage == "Serve" or stage == "NextCustomer" then
        if objective:GetAttribute("PlotSessionId") ~= plot:GetAttribute("PlotSessionId") then
            return nil
        end
    elseif stage == "Harvest" then
        if not table.find(Targets.GetRoots(plot, stage), objective) then
            return nil
        end
    elseif not objective:IsDescendantOf(plot) then
        return nil
    end
    local target = objective
    if stage == "Blender" then
        for _, input in CollectionService:GetTagged("BlenderInput") do
            if input:IsA("BasePart") and input:IsDescendantOf(plot) then
                local marker = input:FindFirstChild("VacuumTarget")
                return if marker and marker:IsA("Attachment") then marker else input
            end
        end
    elseif stage == "Stash" then
        if type(stashSlot) ~= "number" or Targets.GetRoots(plot, stage, stashSlot)[1] ~= objective then
            return nil
        end
    end
    if target:IsA("Attachment") and target.Parent and target.Parent:IsA("BasePart") then
        return target
    end
    -- Reuse the attachment actually used by a prompt before choosing geometry.
    for _, child in target:GetDescendants() do
        if
            child:IsA("ProximityPrompt")
            and child.Parent
            and child.Parent:IsA("Attachment")
            and child.Parent.Parent
            and child.Parent.Parent:IsA("BasePart")
        then
            return child.Parent
        end
    end
    if target:IsA("BasePart") then
        return target
    end
    local root = target:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") then
        return root
    end
    local part = target:FindFirstChildWhichIsA("BasePart", true)
    return if part and part:IsA("BasePart") then part else nil
end
return Targets
