--!strict
-- One resolver shared by server validation and prompt binding. Authored names stay intact.
local Slots = {}
function Slots.Expansion(plot: Instance): Instance?
    return plot:FindFirstChild("UpgradeStash")
end
function Slots.Resolve(fixture: Instance, expansion: Instance?): { [number]: BasePart }
    local slots: { [number]: BasePart } = {}
    local counts: { [number]: number } = {}
    for _, object in fixture:GetDescendants() do
        local index = object:GetAttribute("SlotIndex")
        if object:IsA("BasePart") and type(index) == "number" and index % 1 == 0 and index >= 1 and index <= 5 then
            counts[index] = (counts[index] or 0) + 1
            slots[index] = object
        end
    end
    for index, count in counts do
        if count ~= 1 then
            slots[index] = nil
        end
    end
    if expansion then
        for index = 6, 10 do
            local object = expansion:FindFirstChild("Slot" .. index)
            local part: BasePart? = nil
            if object and object:IsA("BasePart") then
                part = object
            elseif object and object:IsA("Model") and object.PrimaryPart then
                part = object.PrimaryPart
            elseif object then
                -- Multipart slots can identify their interaction surface with the existing
                -- logical SlotIndex (6-10). A single-part container needs no attribute.
                local candidates: { BasePart } = {}
                local marked: { BasePart } = {}
                for _, child in object:GetDescendants() do
                    if child:IsA("BasePart") then
                        table.insert(candidates, child)
                        if child:GetAttribute("SlotIndex") == index then
                            table.insert(marked, child)
                        end
                    end
                end
                part = if #marked == 1
                    then marked[1]
                    elseif #marked == 0 and #candidates == 1 then candidates[1]
                    else nil
            end
            if part then
                slots[index] = part
            end
        end
    end
    return slots
end
return Slots
