--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local CustomerRequests = require(Shared.Constants.CustomerRequests)

local OrderSelection = {}

export type Candidate = {
    Request: CustomerRequests.Request,
    Group: string,
    RequirementKey: string,
    RequiredIngredients: { [string]: boolean },
}

local function sortedKey(values: { string }?, normalizeCase: boolean): string
    local keys: { string } = {}
    local entries: { string } = values or {}
    for _, value in entries do
        local key = string.format("%q", if normalizeCase then string.lower(value) else value)
        if not table.find(keys, key) then
            table.insert(keys, key)
        end
    end
    table.sort(keys)
    return table.concat(keys, ",")
end

function OrderSelection.Prepare(requests: { CustomerRequests.Request }): { Candidate }
    local candidates: { Candidate } = {}
    for _, request in requests do
        local slots: { string } = {}
        local requiredIngredients: { [string]: boolean } = {}
        local requirements: { CustomerRequests.IngredientRequirement } = request.RequiredIngredients or {}
        for _, requirement in requirements do
            local alternatives: { string } = if type(requirement) == "string" then { requirement } else requirement
            table.insert(slots, "[" .. sortedKey(alternatives, false) .. "]")
            for _, ingredientId in alternatives do
                requiredIngredients[ingredientId] = true
            end
        end
        -- Sort slots without dropping duplicates. Two copies of one ingredient affect the recipe.
        table.sort(slots)
        table.insert(candidates, {
            Request = request,
            Group = request.RequestGroup or "Ungrouped",
            RequirementKey = table.concat({
                sortedKey(request.RequiredTags, true),
                sortedKey(request.ForbiddenTags, true),
                table.concat(slots),
                sortedKey(request.ForbiddenIngredients, false),
                if request.ExactIngredients then "exact" else "flexible",
            }, "|"),
            RequiredIngredients = requiredIngredients,
        })
    end
    return candidates
end

local function weight(candidate: Candidate, history: { Candidate }): number
    local latest = history[#history]
    if not latest then
        return 1
    end

    local result = if candidate.Group == latest.Group then CustomerRequests.RepeatedRequestGroupWeight else 1
    for _, previous in history do
        if candidate.Request.Id == previous.Request.Id or candidate.RequirementKey == previous.RequirementKey then
            result *= CustomerRequests.RepeatedRequestWeight
            break
        end
    end
    for ingredientId in candidate.RequiredIngredients do
        if latest.RequiredIngredients[ingredientId] then
            result *= CustomerRequests.RepeatedRequestIngredientWeight
            break
        end
    end
    return result
end

function OrderSelection.Pick(eligible: { Candidate }, history: { Candidate }, roll: number): Candidate
    local weights: { number } = {}
    local total = 0
    for index, candidate in eligible do
        local candidateWeight = weight(candidate, history)
        weights[index] = candidateWeight
        total += candidateWeight
    end

    local remaining = roll * total
    for index, candidateWeight in weights do
        if remaining < candidateWeight then
            return eligible[index]
        end
        remaining -= candidateWeight
    end
    -- Guard against rounding at the upper boundary of the final interval.
    return eligible[#eligible]
end

function OrderSelection.Remember(history: { Candidate }, candidate: Candidate)
    table.insert(history, candidate)
    if #history > CustomerRequests.RegularRequestRecencyWindow then
        table.remove(history, 1)
    end
end

function OrderSelection.RollWildcard(chance: number, nextNumber: () -> number): boolean
    return chance > 0 and nextNumber() < chance
end

return OrderSelection
