local config = loadModule("Muncher")
local rewards = loadModule("MuncherRewards")
local catalog = loadModule("Ingredients")
for _, case in
    {
        { 1, 1 },
        { 1499, 1 },
        { 1500, 1 },
        { 3499, 1 },
        { 3500, 2 },
        { 5499, 2 },
        { 5500, 3 },
        { 7999, 3 },
        { 8000, 4 },
        { 45000, 4 },
    }
do
    check(rewards.Tier(case[1]) == case[2], "exact catalog value tier boundary")
end
check(rewards.BaseValue("PlayerHead", nil) == 5000, "head missing-catalog fallback")
check(rewards.BaseValue("PlayerHead", { Value = 15000 }) == 15000, "head prefers authoritative catalog")
check(rewards.BaseValue("Player_Head", { Value = 15000 }) == 15000, "catalog head alias supported")
check(rewards.BaseValue("Fake", { Value = 0 }) == nil, "invalid value rejected")
check(
    rewards.BaseValue("Apple", { Value = 1500, IsRipe = true, EffectiveIngredientValue = 999999 }) == 1500,
    "ripeness and metadata cannot change tier value"
)
-- Reward policy owns normalization, ascending catalog order, interpolation and jackpot.
local function definition(id)
    return catalog[id]
end
local function rng(roll)
    return {
        NextNumber = function()
            return roll
        end,
    }
end
for tier, jackpot in { 20, 50, 100, 200 } do
    local floorValue, ceiling = config.TierMinimums[tier], config.TierMaximums[tier]
    local base = config.RewardPools[tier]
    local baseSum, previousValue = 0, 0
    local split, baseBottom = math.floor((#base - 1) / 2), 0
    for index, entry in base do
        check(catalog[entry.Id] ~= nil, "every reward resolves to existing catalog")
        check(
            entry.Id ~= "PlayerHead"
                and entry.Id ~= "Player_Head"
                and entry.Id ~= "Gummy_Bear"
                and entry.Id ~= "Mystery",
            "reward exclusions"
        )
        check(catalog[entry.Id].Value >= previousValue, "pool ascending by catalog value")
        previousValue = catalog[entry.Id].Value
        baseSum += entry.Weight
        if index <= split then
            baseBottom += entry.Weight
        end
    end
    check(baseSum == 10000, "base weights normalized")
    check(base[#base].Id == "Dragon_Fruit" and base[#base].Weight == jackpot, "exact jackpot last")
    local previousEV = 0
    for sample, value in { floorValue, (floorValue + ceiling) / 2, ceiling } do
        local sum, ev, bottom = 0, 0, 0
        local effective = rewards.Weights(tier, value)
        for index, entry in effective do
            sum += entry.Weight
            ev += entry.Weight * catalog[entry.Id].Value / 10000
            if index <= split then
                bottom += entry.Weight
            end
        end
        check(
            math.abs(sum - 10000) < 0.000001 and effective[#effective].Weight == jackpot,
            "effective total and fixed jackpot"
        )
        check(
            math.abs(bottom - baseBottom * (1 - (sample - 1) / 2 * 0.7)) < 0.000001,
            "70% proportional interpolation adapts to pool length"
        )
        check(ev >= previousEV, "higher input improves effective pool")
        previousEV = ev
        print(string.format("Tier %d input %.2f EV %.2f (%.2f%%)", tier, value, ev, ev / value * 100))
        -- Probe fractional-bp boundaries, including the exact jackpot edge.
        for _, index in { 1, #effective - 1 } do
            local boundary = 0
            for i = 1, index do
                boundary += effective[i].Weight / 10000
            end
            for _, side in { -1, 1 } do
                check(
                    rewards.Roll(tier, rng(boundary + side * 1e-9), definition, value)
                        == effective[if side < 0 then index else index + 1].Id,
                    "weighted selection boundaries"
                )
            end
        end
        for _, generation in { 0, 1, 2, 5, 9 } do
            local nerfed = rewards.ChainWeights(effective, value, generation, definition)
            local available, shifted, nerfedTotal = 0, 0, 0
            for _, entry in effective do
                if entry.Id ~= "Dragon_Fruit" and catalog[entry.Id].Value > value then
                    available += entry.Weight
                end
            end
            local expected = math.min(math.min(generation, 5) * 500, available)
            check(
                math.abs(nerfed[1].Weight - effective[1].Weight - expected) < 1e-6,
                "chain adds exact available capped shift to lowest output"
            )
            for index, entry in nerfed do
                check(entry.Weight >= 0, "chain cannot create negative weights")
                nerfedTotal += entry.Weight
                if entry.Id ~= "Dragon_Fruit" and catalog[entry.Id].Value > value then
                    shifted += effective[index].Weight - entry.Weight
                    check(
                        math.abs(
                            entry.Weight
                                - effective[index].Weight * (if available > 0 then 1 - expected / available else 1)
                        ) < 1e-6,
                        "wins lose mass proportionally"
                    )
                elseif index ~= 1 then
                    check(entry.Weight == effective[index].Weight, "chain leaves pushes and other losses unchanged")
                end
            end
            check(
                math.abs(shifted - expected) < 1e-6 and math.abs(nerfedTotal - 10000) < 1e-6,
                "chain conserves total mass"
            )
            check(nerfed[#nerfed].Weight == jackpot, "chain preserves jackpot exactly")
            for step = 0, 100 do
                local result = rewards.Roll(tier, rng(step / 100 * 0.999999), definition, value, generation, true)
                check(
                    if value < 45000 then catalog[result].Value > value else result == "Dragon_Fruit",
                    "pity wins across RNG range or returns ceiling"
                )
                check(
                    result == rewards.Roll(tier, rng(step / 100 * 0.999999), definition, value, 0, true),
                    "pity ignores chain generation"
                )
            end
        end
    end
    check(
        rewards.Weights(tier, floorValue - 1)[1].Weight == base[1].Weight
            and math.abs(rewards.Weights(tier, ceiling + 1)[1].Weight - base[1].Weight * 0.3) < 1e-6,
        "interpolation clamps tier bounds"
    )
end
check(rewards.Generation(nil, nil) == 0, "natural and pre-pass items default generation zero")
check(
    rewards.Generation(2, 5) == 2 and rewards.Generation(nil, 5) == 5,
    "generation attribute precedes record fallback"
)
for _, invalid in { -1, math.huge, "forged" } do
    check(rewards.Generation(invalid, nil) == 0, "invalid generation cannot corrupt odds")
end

check(catalog.PlayerHead == catalog.Player_Head, "legacy dynamic-head lookup retains authored catalog name")
local entries = 0
for id in catalog do
    if id == "PlayerHead" or id == "Player_Head" then
        entries += 1
    end
end
check(entries == 1, "head compatibility does not duplicate discovery catalog entries")

-- Labels use the same catalog basis as tiering, including equal-value jackpot inputs.
for _, input in catalog do
    for tier, pool in config.RewardPools do
        for _, entry in pool do
            local output = catalog[entry.Id]
            local expected = if output.Value > input.Value
                then "Win"
                elseif output.Value < input.Value then "Lose"
                else "Push"
            check(
                rewards.ResultKind(input.Value, output.Value) == expected,
                "catalog value ordering labels every tier and jackpot"
            )
        end
    end
end
check(rewards.ResultKind(catalog.Rock.Value, catalog.Rock.Value) == "Push", "own Rock is a push")
check(rewards.ResultKind(catalog.Dragon_Fruit.Value, catalog.Dragon_Fruit.Value) == "Push", "equal jackpot is a push")

-- All bands remain accessible without special pickups.
for tier, id in { "Rock", "Mushrooms", "Milk", "Golden_Potato" } do
    check(rewards.Tier(catalog[id].Value) == tier, "ordinary ingredient reaches each tier")
end

-- Exact catalog EV, including pushes resetting the loss streak, not simulation.
local function expectation(value, generation)
    local tier = rewards.Tier(value)
    local base = rewards.Weights(tier, value)
    local effective = rewards.ChainWeights(base, value, generation, definition)
    local ev, loss, pityTotal, pityValue = 0, 0, 0, 0
    for index, entry in effective do
        local output = catalog[entry.Id].Value
        ev += entry.Weight * output / 10000
        if output < value then
            loss += entry.Weight / 10000
        elseif output > value then
            pityTotal += base[index].Weight
            pityValue += base[index].Weight * output
        end
    end
    local pityEV = if pityTotal > 0 then pityValue / pityTotal else catalog.Dragon_Fruit.Value
    local cycle = 0
    for losses = 0, config.PityLosses do
        cycle += loss ^ losses
    end
    local pityFrequency = loss ^ config.PityLosses / cycle
    return ev, pityEV, ev * (1 - pityFrequency) + pityEV * pityFrequency
end
for _, value in { 1500, 2000, 2500, 3500, 4500, 5000, 5500, 6000, 7000, 8000, 9000, 13000, 24000, 30000, 45000 } do
    local fresh, pity, repeated = expectation(value, 0)
    local chain, _, repeatedChain = expectation(value, 5)
    print(
        string.format(
            "ECONOMY input=%d tier=%d fresh=%.2f pity=%.2f repeat=%.2f gen5=%.2f repeatGen5=%.2f",
            value,
            rewards.Tier(value),
            fresh,
            pity,
            repeated,
            chain,
            repeatedChain
        )
    )
    if value == 1500 then
        check(repeated == fresh and chain < fresh, "floor pushes never build pity; generation lowers cheap premium")
        check(fresh < value * 1.15, "cheap fresh catalog premium stays below fifteen percent")
    elseif value == 3500 then
        check(
            repeated < value and repeatedChain < value,
            "Standard floor stays below input with pity at fresh and capped generation"
        )
    end
end

-- Reinsert every output, advancing the actual generation and per-machine loss streak.
-- This differs from supplying the same fresh input repeatedly.
for _, id in { "Rock", "Mushrooms" } do
    local distribution = { [id] = { [0] = 1 } }
    for generation = 0, 24 do
        local nextDistribution, ev, total = {}, 0, 0
        for inputId, streaks in distribution do
            local value = catalog[inputId].Value
            local base = rewards.Weights(rewards.Tier(value), value)
            for streak, probability in streaks do
                local pity = streak >= config.PityLosses
                local pool = if pity then base else rewards.ChainWeights(base, value, generation, definition)
                local eligible, weight = {}, 0
                for _, entry in pool do
                    if not pity or catalog[entry.Id].Value > value then
                        table.insert(eligible, entry)
                        weight += entry.Weight
                    end
                end
                if weight == 0 then
                    eligible, weight = { { Id = "Dragon_Fruit", Weight = 1 } }, 1
                end
                for _, entry in eligible do
                    local chance = probability * entry.Weight / weight
                    local output = catalog[entry.Id].Value
                    local losses = if not pity and output < value then streak + 1 else 0
                    nextDistribution[entry.Id] = nextDistribution[entry.Id] or {}
                    nextDistribution[entry.Id][losses] = (nextDistribution[entry.Id][losses] or 0) + chance
                    ev += chance * output
                    total += chance
                end
            end
        end
        check(math.abs(total - 1) < 1e-8, "reinserted output probability conserved under pity and generation")
        if generation == 0 or generation == 5 or generation == 24 then
            print(string.format("REINSERT start=%s rolls=%d expectedValue=%.2f", id, generation + 1, ev))
        end
        distribution = nextDistribution
    end
end
