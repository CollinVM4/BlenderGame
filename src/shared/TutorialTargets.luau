--!strict
-- All paths are relative to one plot. Folder assemblies expand into visible parts.
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
    Counter = { { "Customer Area", "Counter", "Base Structure", "Base" } },
}
-- Raw authored roots are also available to the opt-in presentation diagnostics.
function Targets.GetRoots(plot: Instance?, stage: string, stashSlot: number?): { Instance }
    local roots: { Instance } = {}
    if not plot or not plot:IsDescendantOf(workspace) then
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
    local stagePaths: { { string } } = paths[stage] or {}
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
    if not plot or not plot:IsDescendantOf(workspace) then
        return result
    end
    if stage == "Serve" then
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
return Targets
