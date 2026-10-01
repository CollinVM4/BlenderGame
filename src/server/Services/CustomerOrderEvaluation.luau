--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local CustomerRequests = require(Shared.Constants.CustomerRequests)
local Economy = require(Shared.Constants.Economy)
local Ingredients = require(Shared.Constants.Ingredients)
local Types = require(Shared.Types)

export type Evaluation = {
    Grade: Types.Grade?,
    IsWildcard: boolean,
    MatchCount: number,
    TotalSlots: number,
    RequirementsCovered: boolean,
    RestrictionViolated: boolean,
    IsValid: boolean,
    IsFulfilled: boolean,
    Reason: string,
}

local CustomerOrderEvaluation = {}

local function emptyResult(request: CustomerRequests.Request, reason: string): Evaluation
    local isWildcard = request.Wildcard == true
    return {
        Grade = if isWildcard then nil else "D",
        IsWildcard = isWildcard,
        MatchCount = 0,
        TotalSlots = 0,
        RequirementsCovered = false,
        RestrictionViolated = false,
        IsValid = false,
        IsFulfilled = false,
        Reason = reason,
    }
end

local function matchesTag(tags: { [string]: boolean }, requestedTag: string): boolean
    local normalized = string.lower(requestedTag)
    if tags[normalized] then
        return true
    end
    local group = CustomerRequests.TagGroups[normalized]
    if group then
        for member in group do
            if tags[member] then
                return true
            end
        end
    end
    return false
end

local function matchesRequirement(id: string, requirement: CustomerRequests.IngredientRequirement): boolean
    return if type(requirement) == "string" then requirement == id else table.find(requirement, id) ~= nil
end

function CustomerOrderEvaluation.Evaluate(
    result: Types.Smoothie,
    request: CustomerRequests.Request
): Evaluation
    local ids = result.Ingredients
    local requirements: { CustomerRequests.IngredientRequirement } = request.RequiredIngredients or {}
    local isWildcard = request.Wildcard == true
    if #ids == 0 then
        return emptyResult(request, "Empty smoothie")
    end
    if #ids < Economy.MaxIngredients then
        return emptyResult(request, "Not enough ingredients")
    end
    if #ids > Economy.MaxIngredients then
        return emptyResult(request, "Too many ingredients")
    end

    local ingredientTags: { [number]: { [string]: boolean } } = {}
    for index, id in ids do
        local definition = Ingredients[id]
        if not definition then
            return emptyResult(request, "Unknown ingredient: " .. id)
        end
        local tags: { [string]: boolean } = {}
        for _, tag in definition.Tags do
            tags[string.lower(tag)] = true
        end
        ingredientTags[index] = tags
    end

    if isWildcard then
        return {
            Grade = nil,
            IsWildcard = true,
            MatchCount = #ids,
            TotalSlots = #ids,
            RequirementsCovered = true,
            RestrictionViolated = false,
            IsValid = true,
            IsFulfilled = true,
            Reason = "Wildcard fulfilled",
        }
    end
    local requiredTags: { string } = request.RequiredTags or {}
    if #requiredTags == 0 and #requirements == 0 then
        return emptyResult(request, "Empty request")
    end
    if request.ExactIngredients and #requirements == 0 then
        return emptyResult(request, "ExactIngredients requires at least one RequiredIngredient")
    end

    local restrictionReason: string? = nil
    local forbiddenTags: { string } = request.ForbiddenTags or {}
    for _, forbiddenTag in forbiddenTags do
        for _, tags in ingredientTags do
            if tags[string.lower(forbiddenTag)] then
                restrictionReason = "Contains forbidden tag: " .. forbiddenTag
                break
            end
        end
        if restrictionReason then
            break
        end
    end
    local forbiddenIngredients: { string } = request.ForbiddenIngredients or {}
    if not restrictionReason then
        for _, id in ids do
            if table.find(forbiddenIngredients, id) then
                restrictionReason = "Contains forbidden ingredient: " .. id
                break
            end
        end
    end
    local allTagsCovered = true
    local missingTag: string? = nil
    for _, requiredTag in requiredTags do
        local covered = false
        for _, tags in ingredientTags do
            if matchesTag(tags, requiredTag) then
                covered = true
                break
            end
        end
        if not covered then
            allTagsCovered = false
            missingTag = missingTag or requiredTag
        end
    end

    -- Find the maximum one-to-one assignment between physical ingredients and request slots.
    local assignedSlots: { [number]: number } = {}
    local function assignSlot(slot: number, visited: { [number]: boolean }): boolean
        local requirement = requirements[slot]
        for index, id in ids do
            if matchesRequirement(id, requirement) and not visited[index] then
                visited[index] = true
                local previousSlot = assignedSlots[index]
                if not previousSlot or assignSlot(previousSlot, visited) then
                    assignedSlots[index] = slot
                    return true
                end
            end
        end
        return false
    end
    local matchedSlots = 0
    for slot in requirements do
        if assignSlot(slot, {}) then
            matchedSlots += 1
        end
    end
    local allIngredientSlotsCovered = matchedSlots == #requirements

    local relevantCount = 0
    for index, id in ids do
        local relevant = false
        for _, requiredTag in requiredTags do
            if matchesTag(ingredientTags[index], requiredTag) then
                relevant = true
                break
            end
        end
        if not relevant then
            for _, requirement in requirements do
                if matchesRequirement(id, requirement) then
                    relevant = true
                    break
                end
            end
        end
        if relevant then
            relevantCount += 1
        end
    end
    local matchCount = if request.ExactIngredients then matchedSlots else relevantCount
    local exactCountMatches = not request.ExactIngredients or #ids == #requirements
    local requirementsCovered = allTagsCovered and allIngredientSlotsCovered and exactCountMatches
    local reason = "Request requirements matched"
    if not allTagsCovered then
        reason = "Missing required tag: " .. (missingTag :: string)
    elseif not allIngredientSlotsCovered then
        for slot, requirement in requirements do
            if not assignSlot(slot, {}) then
                local description = if type(requirement) == "string"
                    then requirement
                    else table.concat(requirement, " or ")
                reason = "Missing required ingredient: " .. description
                break
            end
        end
    elseif not exactCountMatches then
        reason = "Exact ingredient mismatch"
    end
    if restrictionReason then
        return {
            Grade = "D",
            IsWildcard = false,
            MatchCount = matchCount,
            TotalSlots = if request.ExactIngredients then #requirements else #ids,
            RequirementsCovered = requirementsCovered,
            RestrictionViolated = true,
            IsValid = true,
            IsFulfilled = false,
            Reason = restrictionReason,
        }
    end

    local grade: Types.Grade
    if request.ExactIngredients then
        if matchCount == 0 then
            grade = "D"
        elseif matchCount == 1 then
            grade = "C"
        elseif matchCount < #requirements then
            grade = "B"
        elseif requirementsCovered then
            grade = "A"
        else
            grade = "C"
        end
    elseif matchCount == 0 then
        grade = "D"
    elseif matchCount >= 3 and requirementsCovered then
        grade = "A"
    elseif matchCount >= 2 and requirementsCovered then
        grade = "B"
    else
        grade = "C"
    end
    return {
        Grade = grade,
        IsWildcard = false,
        MatchCount = matchCount,
        TotalSlots = if request.ExactIngredients then #requirements else #ids,
        RequirementsCovered = requirementsCovered,
        RestrictionViolated = false,
        IsValid = true,
        IsFulfilled = grade == "A" or grade == "B",
        Reason = reason,
    }
end

return CustomerOrderEvaluation