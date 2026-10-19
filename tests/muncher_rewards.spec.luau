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
for tier, jackpot in { 20, 50, 100, 200 } do
    local sum, ev, dragon = 0, 0, 0
    for _, entry in config.RewardPools[tier] do
        check(
            catalog[entry.Id] ~= nil and entry.Id ~= "PlayerHead" and entry.Id ~= "Player_Head",
            "valid catalog output, never dynamic head"
        )
        sum += entry.Weight
        ev += entry.Weight * catalog[entry.Id].Value / 10000
        if entry.Id == "Dragon_Fruit" then
            dragon += entry.Weight
        end
    end
    check(sum == 10000 and dragon == jackpot, "normalized exact mystery odds")
    check(
        ev < (if tier == 1 then catalog.Apple.Value else config.TierMinimums[tier]),
        "provisional expected return below representative input value"
    )
    for _, roll in { 0, 0.2, 0.7, 0.95, 0.999999 } do
        local result = rewards.Roll(tier, {
            NextNumber = function()
                return roll
            end,
        }, function(id)
            return catalog[id]
        end)
        check(catalog[result] ~= nil, "deterministic weighted selection")
    end
    print(string.format("Tier %d provisional EV: %.2f", tier, ev))
end

check(catalog.PlayerHead == catalog.Player_Head, "legacy dynamic-head lookup retains authored catalog name")
local entries = 0
for id in catalog do
    if id == "PlayerHead" or id == "Player_Head" then
        entries += 1
    end
end
check(entries == 1, "head compatibility does not duplicate discovery catalog entries")
