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

function Rewards.Tier(value: number): number
    for tier = #Config.TierMinimums, 2, -1 do
        if value >= Config.TierMinimums[tier] then
            return tier
        end
    end
    return 1
end

-- RNG is injected only by server callers; no client-supplied rolls or rewards.
function Rewards.Roll(tier: number, rng: any, definition: (string) -> any): string
    local pool = Config.RewardPools[tier]
    local total = 0
    for _, entry in pool do
        assert(entry.Id ~= "PlayerHead" and entry.Id ~= "Player_Head", "Player heads cannot be rewards")
        assert(definition(entry.Id) and entry.Weight > 0, "Invalid Muncher reward")
        total += entry.Weight
    end
    assert(total == 10000, "Muncher pool must total 10000 basis points")
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
