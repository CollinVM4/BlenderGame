local config = loadModule("Muncher")
local rewards = loadModule("MuncherRewards")
local catalog = loadModule("Ingredients")
for _, case in
    {
        { 1, 1 },
        { 999, 1 },
        { 1000, 1 },
        { 4999, 1 },
        { 5000, 2 },
        { 19999, 2 },
        { 20000, 3 },
        { 49999, 3 },
        { 50000, 4 },
        {
            165000,
            4,
        },
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
-- Prior casino pools are review baselines, not alternate production odds.
local previousPools = {
    { 9900, 50, 20, 10, 20 },
    { 7600, 1800, 500, 50, 50 },
    { 6000, 2500, 1200, 200, 100 },
    { 4500, 2600, 1700, 1000, 200 },
}
-- Reward policy owns normalization, interpolation, jackpot and value guardrails.
for tier, jackpot in { 20, 50, 100, 200 } do
    local floorValue, ceiling = config.TierMinimums[tier], config.TierMaximums[tier]
    local values = { floorValue, (floorValue + ceiling) / 2, ceiling }
    local base = config.RewardPools[tier]
    local baseSum = 0
    for _, entry in base do
        check(
            catalog[entry.Id] ~= nil and entry.Id ~= "PlayerHead" and entry.Id ~= "Player_Head",
            "valid static catalog output"
        )
        check(tier == 1 or catalog[entry.Id].Value >= floorValue * 0.5, "no insulting sub-half-floor outputs")
        baseSum += entry.Weight
    end
    check(baseSum == 10000, "base weights normalized")
    local previousEV = 0
    for sample, value in values do
        local sum, ev, dragon, bottom, top = 0, 0, 0, 0, 0
        local win, push, loss, previousWin = 0, 0, 0, 0
        local effective = rewards.Weights(tier, value)
        for index, entry in effective do
            sum += entry.Weight
            local output = catalog[entry.Id].Value
            if output > value then
                win += entry.Weight
                local old = previousPools[tier]
                local oldBottom, oldTop = old[1] + old[2], old[3] + old[4]
                local t = (sample - 1) / 2
                previousWin += old[index] * (if index == 5
                    then 1
                    elseif index <= 2 then 1 - t * 0.5
                    else 1 + t * 0.5 * oldBottom / oldTop)
            elseif output == value then
                push += entry.Weight
            else
                loss += entry.Weight
            end
            ev += entry.Weight * catalog[entry.Id].Value / 10000
            if entry.Id == "Dragon_Fruit" then
                dragon += entry.Weight
            elseif index <= 2 then
                bottom += entry.Weight
            else
                top += entry.Weight
            end
        end
        check(math.abs(sum - 10000) < 0.000001 and dragon == jackpot, "effective weights normalized; fixed jackpot")
        local t = (sample - 1) / 2
        local baseBottom = base[1].Weight + base[2].Weight
        check(
            math.abs(bottom - baseBottom * (1 - t * 0.7)) < 0.000001
                and math.abs(top - (10000 - jackpot - baseBottom + t * 0.7 * baseBottom)) < 0.000001,
            "exact requested proportional 70% bottom-mass transfer"
        )
        check(ev >= previousEV, "higher input earns a better effective pool")
        previousEV = ev
        if tier == 1 and sample == 1 then
            -- Approved sub-$1,053 Cheap lottery exception; floor returns Rock 99%.
            local minimumEV = catalog.Rock.Value * 0.998 + catalog.Dragon_Fruit.Value * 0.002
            check(
                minimumEV == 1328 and minimumEV > value * 1.1,
                "Cheap floor explicitly exempt from 110% guardrail with fixed jackpot"
            )
        else
            check(ev <= value * 1.1, "110% cap at non-exempt floor, midpoint and ceiling")
        end
        for _, roll in { 0, 0.2, 0.7, 0.95, 0.999999 } do
            local result = rewards.Roll(tier, {
                NextNumber = function()
                    return roll
                end,
            }, function(id)
                return catalog[id]
            end, value)
            check(catalog[result] ~= nil, "deterministic effective weighted selection")
        end
        -- Probe both sides of an interpolated fractional-bp boundary, and jackpot.
        for _, boundary in { { effective[1].Weight / 10000, 1, 2 }, { 1 - jackpot / 10000, 4, 5 } } do
            for _, side in { -1, 1 } do
                local result = rewards.Roll(tier, {
                    NextNumber = function()
                        return boundary[1] + side * 0.000000001
                    end,
                }, function(id)
                    return catalog[id]
                end, value)
                check(
                    result == effective[if side < 0 then boundary[2] else boundary[3]].Id,
                    "fractional-bp and fixed jackpot selection boundaries remain exact"
                )
            end
        end
        check(math.abs(win + push + loss - 10000) < 0.000001, "win/push/loss exhaust outcomes")
        -- Fixed jackpot and output ceilings make strict improvement impossible here.
        local fixedWin = (tier == 1 and (sample == 1 or sample == 3)) or (tier == 4 and sample >= 2)
        check(
            if fixedWin then math.abs(win - previousWin) < 0.000001 else win > previousWin + 100,
            "material win improvement where fixed output/jackpot constraints permit"
        )
        print(
            string.format(
                "Tier %d input %.2f EV %.2f (%.2f%%) W/P/L %.4f/%.4f/%.4f%%; previous win %.4f%%",
                tier,
                value,
                ev,
                ev / value * 100,
                win / 100,
                push / 100,
                loss / 100,
                previousWin / 100
            )
        )
    end
    check(
        rewards.Weights(tier, floorValue - 1)[1].Weight == base[1].Weight
            and math.abs(rewards.Weights(tier, ceiling + 1)[1].Weight - base[1].Weight * 0.3) < 0.000001,
        "interpolation clamps to tier bounds"
    )
end
-- Sub-$1,053 exemption is recorded, not broadened to hide the infeasible interval.
check(config.RewardPools[1][1].Weight == 9900, "Cheap floor returns Rock 99%")
local cutoffEV = 0
for _, entry in rewards.Weights(1, 1053) do
    cutoffEV += catalog[entry.Id].Value * entry.Weight / 10000
end
check(cutoffEV > 1053 * 1.1, "KNOWN CONSTRAINT CONFLICT: $1,053 is outside exemption but cannot meet cap")
-- All other current catalog inputs are above that infeasible interval.
for id, definition in catalog do
    if id ~= "PlayerHead" and id ~= "Player_Head" and definition.Value >= 1053 then
        local value, ev = definition.Value, 0
        for _, entry in rewards.Weights(rewards.Tier(value), value) do
            ev += catalog[entry.Id].Value * entry.Weight / 10000
        end
        check(ev <= value * 1.1, "non-exempt catalog input preserves 110% cap")
    end
end
check(
    rewards.Weights(1, config.TierMaximums[1])[1].Weight < config.RewardPools[1][1].Weight,
    "Cheap Rock probability falls with input value"
)

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
