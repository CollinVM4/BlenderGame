local config = loadModule("CustomerRequests")
local customer = loadModule("CustomerService")
local selection = loadModule("CustomerOrderSelection")
local groups = { "Color", "Trait", "Combo", "Restriction", "Ingredient", "Recipe", "Wildcard" }
local orderCount = 10000

-- Fixed-seed generator with integer products below the exact range of a double.
local function randomFrom(seed)
    return function()
        seed = (seed * 16807) % 2147483647
        return seed / 2147483647
    end
end

local function generate(eligible, useHistory, seed)
    local history = {}
    local random = randomFrom(seed)
    return function()
        local wildcard = selection.RollWildcard(authoredWildcardChances[1], random)
        local orderRoll = random() -- Pair both modes with the same order and wildcard rolls.
        if wildcard then
            return nil, "Wildcard"
        end
        local candidate = selection.Pick(eligible, history, orderRoll)
        if useHistory then
            selection.Remember(history, candidate)
        end
        return candidate, candidate.Group
    end
end

local function simulate(tier, eligible, useHistory)
    local nextOrder = generate(eligible, useHistory, 8317 + tier)
    local counts = {}
    local previous, previousGroup
    local exactIds, exactRequirements, sameGroups, ingredientRepeats, adjacentSpecific = 0, 0, 0, 0, 0
    local groupRun, requirementRun, longestGroup, longestRequirement, longestWildcard = 0, 0, 0, 0, 0
    local longGroupRuns, longWildcardRuns = 0, 0
    for _ = 1, orderCount do
        local candidate, group = nextOrder()
        counts[group] = (counts[group] or 0) + 1
        if candidate and previous then
            adjacentSpecific += 1
            exactIds += if candidate.Request.Id == previous.Request.Id then 1 else 0
            sameGroups += if group == previousGroup then 1 else 0
            for id in candidate.RequiredIngredients do
                if previous.RequiredIngredients[id] then
                    ingredientRepeats += 1
                    break
                end
            end
        end
        local sameRequirement = candidate and previous and candidate.RequirementKey == previous.RequirementKey
        if sameRequirement then
            exactRequirements += 1
        end
        requirementRun = if sameRequirement then requirementRun + 1 elseif candidate then 1 else 0
        longestRequirement = math.max(longestRequirement, requirementRun)
        groupRun = if group == previousGroup then groupRun + 1 else 1
        if group == "Wildcard" then
            longestWildcard = math.max(longestWildcard, groupRun)
            longWildcardRuns += if groupRun == 3 then 1 else 0
        else
            longestGroup = math.max(longestGroup, groupRun)
            longGroupRuns += if groupRun == 3 then 1 else 0
        end
        previous, previousGroup = candidate, group
    end

    local frequencies = {}
    for _, group in groups do
        table.insert(frequencies, string.format("%s %.2f%%", group, 100 * (counts[group] or 0) / orderCount))
    end
    print(
        string.format(
            "JL%d %s (%d): %s",
            tier,
            if useHistory then "weighted" else "uniform",
            orderCount,
            table.concat(frequencies, " | ")
        )
    )
    print(
        string.format(
            "  %d adjacent specific pairs: exact ID %.2f%% | exact requirements %.2f%% | same type %.2f%% | named ingredient overlap %.2f%%",
            adjacentSpecific,
            100 * exactIds / adjacentSpecific,
            100 * exactRequirements / adjacentSpecific,
            100 * sameGroups / adjacentSpecific,
            100 * ingredientRepeats / adjacentSpecific
        )
    )
    print(
        string.format(
            "  Longest streaks: exact requirements %d | specific type %d (%d streaks of 3+) | wildcard %d (%d streaks of 3+)",
            longestRequirement,
            longestGroup,
            longGroupRuns,
            longestWildcard,
            longWildcardRuns
        )
    )
    return {
        Wildcards = counts.Wildcard,
        ExactRequirements = exactRequirements,
        SameGroups = sameGroups,
        IngredientRepeats = ingredientRepeats,
    }
end

local function firstFive(eligible, useHistory)
    local total = 0
    for seed = 70001, 71000 do
        local nextOrder = generate(eligible, useHistory, seed * 4099)
        local seen = {}
        for _ = 1, 5 do
            local candidate, group = nextOrder()
            if candidate and not seen[group] then
                seen[group] = true
                total += 1
            end
        end
    end
    return total / 1000
end

check(authoredWildcardChances[1] == 0.11, "regular simulation exercises the authored wildcard rate")
for tier = 0, 3 do
    local pool = selection.Prepare(customer.GetEligibleRegularRequests(tier))
    local uniform = simulate(tier, pool, false)
    local weighted = simulate(tier, pool, true)
    check(weighted.Wildcards == uniform.Wildcards, "history leaves wildcard rolls independent")
    check(
        math.abs(weighted.Wildcards / orderCount - authoredWildcardChances[1]) < 0.01,
        "observed wildcard rate near target"
    )
    check(weighted.ExactRequirements < uniform.ExactRequirements, "fewer consecutive exact requirements")
    check(weighted.SameGroups < uniform.SameGroups, "fewer consecutive orders of the same type")
    check(weighted.IngredientRepeats < uniform.IngredientRepeats, "less overlap in named ingredients")
    if tier == 0 then
        print(
            string.format(
                "  Fresh JL0 plots, first five arrivals: %.2f uniform vs %.2f weighted distinct specific types on average",
                firstFive(pool, false),
                firstFive(pool, true)
            )
        )
    end

    local restrictionCount, minBase, maxBase = 0, math.huge, 0
    for _, candidate in pool do
        if candidate.Group == "Restriction" then
            restrictionCount += 1
            minBase = math.min(minBase, candidate.Request.BasePayout)
            maxBase = math.max(maxBase, candidate.Request.BasePayout)
        end
    end
    print(string.format("  %d eligible restrictions, $%d–$%d base per order", restrictionCount, minBase, maxBase))
end
