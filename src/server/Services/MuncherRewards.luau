--!strict
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.Muncher)
local Rewards = {}

function Rewards.BaseValue(id: string, definition: any): number?
    local value = if definition then definition.Value else nil
    if type(value) == "number" and value > 0 and value < math.huge then
        return value
    end
    if id == "PlayerHead" or id == "Player_Head" then
        return Config.PlayerHeadFallbackBaseValue
    end
    return nil
end

-- Compare catalog base values only; this label never participates in selection.
function Rewards.ResultKind(inputValue: number, outputValue: number): "Win" | "Lose" | "Push"
    return if outputValue > inputValue then "Win" elseif outputValue < inputValue then "Lose" else "Push"
end

function Rewards.Tier(value: number): number
    for tier = #Config.TierMinimums, 2, -1 do
        if value >= Config.TierMinimums[tier] then
            return tier
        end
    end
    return 1
end

-- Move up to 70% of non-jackpot bottom mass proportionally to the top half.
-- Fractional basis points retain the exact interpolation and jackpot probability.
function Rewards.Weights(tier: number, value: number): { { Id: string, Weight: number } }
    local pool = Config.RewardPools[tier]
    local split = math.floor((#pool - 1) / 2)
    local bottom, top = 0, 0
    for index, entry in pool do
        if entry.Id ~= "Dragon_Fruit" then
            if index <= split then
                bottom += entry.Weight
            else
                top += entry.Weight
            end
        end
    end
    local t =
        math.clamp((value - Config.TierMinimums[tier]) / (Config.TierMaximums[tier] - Config.TierMinimums[tier]), 0, 1)
    local moved = t * 0.7 * bottom
    local effective = {}
    for index, entry in pool do
        local weight = entry.Weight
        if entry.Id ~= "Dragon_Fruit" then
            weight *= if index <= split then 1 - t * 0.7 else 1 + moved / top
        end
        table.insert(effective, { Id = entry.Id, Weight = weight })
    end
    return effective
end

-- RNG and the unmodified catalog input value come only from the server.
function Rewards.Roll(tier: number, rng: any, definition: (string) -> any, value: number?): string
    local pool = Rewards.Weights(tier, value or Config.TierMinimums[tier])
    local total = 0
    for _, entry in pool do
        assert(entry.Id ~= "PlayerHead" and entry.Id ~= "Player_Head", "Player heads cannot be rewards")
        assert(definition(entry.Id) and entry.Weight > 0, "Invalid Muncher reward")
        total += entry.Weight
    end
    assert(math.abs(total - 10000) < 0.000001, "Muncher pool must total 10000 basis points")
    local roll = rng:NextNumber() * total
    local cumulative = 0
    for _, entry in pool do
        cumulative += entry.Weight
        if roll < cumulative then
            return entry.Id
        end
    end
    return pool[#pool].Id
end
return Rewards
