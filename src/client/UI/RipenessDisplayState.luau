--!strict
local Ripeness = require(game:GetService("ReplicatedStorage").Shared.Constants.Ripeness)
local State = {}

export type ItemView = { Id: string, Index: number, Ripe: boolean, Progress: number }

function State.Progress(pad: BasePart, index: number, now: number): number
    local prefix = "StashItem" .. index
    if pad:GetAttribute(prefix .. "IsRipe") == true then
        return 1
    end
    local storedSeconds = pad:GetAttribute(prefix .. "StoredSeconds")
    local accumulated = if typeof(storedSeconds) == "number" then storedSeconds else 0
    local storedAt = pad:GetAttribute(prefix .. "StoredAt")
    local elapsed = if typeof(storedAt) == "number" then math.max(0, now - storedAt) else 0
    local duration = pad:GetAttribute("RipenessSeconds")
    return math.clamp((accumulated + elapsed) / (if typeof(duration) == "number" then duration else Ripeness.RipenessSeconds), 0, 1)
end

function State.Read(pad: BasePart, now: number): ({ ItemView }, string)
    local slotCount = pad:GetAttribute("StashCount")
    local count = if typeof(slotCount) == "number" then slotCount else 0
    local items: { ItemView } = {}
    local signature: { string } = {}
    for index = 1, count do
        local prefix = "StashItem" .. index
        local id = pad:GetAttribute(prefix .. "Id")
        if typeof(id) == "string" then
            local ripe = pad:GetAttribute(prefix .. "IsRipe") == true
            table.insert(items, { Id = id, Index = index, Ripe = ripe, Progress = State.Progress(pad, index, now) })
            table.insert(signature, id .. ":" .. tostring(ripe))
        end
    end
    table.sort(items, function(a, b)
        if a.Ripe ~= b.Ripe then
            return a.Ripe
        end
        if a.Progress ~= b.Progress then
            return a.Progress > b.Progress
        end
        return a.Id < b.Id
    end)
    return items, table.concat(signature, "|")
end

return State
