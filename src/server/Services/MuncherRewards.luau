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

-- Generation is server item metadata, never supplied by the feed request.
function Rewards.Generation(attribute: any, fallback: any): number
    local generation = if attribute ~= nil then attribute else fallback
    return if type(generation) == "number"
            and generation >= 0
            and generation < math.huge
        then math.floor(generation)
        else 0
end

function Rewards.ChainStacks(generation: number): number
    return math.min(generation, Config.ChainNerfMaxStacks)
end

-- Clamp to available winning mass: exhausted wins become zero, never negative.
function Rewards.ChainWeights(
    pool: { { Id: string, Weight: number } },
    value: number,
    generation: number,
    definition: (string) -> any
): { { Id: string, Weight: number } }
    local shiftable = 0
    for _, entry in pool do
        if entry.Id ~= "Dragon_Fruit" and definition(entry.Id).Value > value then
            shiftable += entry.Weight
        end
    end
    local moved = math.min(Rewards.ChainStacks(generation) * Config.ChainNerfBasisPoints, shiftable)
    local effective = {}
    for index, entry in pool do
        local weight = entry.Weight
        if shiftable > 0 and entry.Id ~= "Dragon_Fruit" and definition(entry.Id).Value > value then
            weight *= 1 - moved / shiftable
        end
        if index == 1 then
            weight += moved
        end
        table.insert(effective, { Id = entry.Id, Weight = weight })
    end
    return effective
end

local function weightedRoll(pool: { { Id: string, Weight: number } }, total: number, rng: any): string
    local roll = rng:NextNumber() * total
    local cumulative = 0
    for _, entry in pool do
        cumulative += entry.Weight
        if entry.Weight > 0 and roll < cumulative then
            return entry.Id
        end
    end
    for index = #pool, 1, -1 do
        if pool[index].Weight > 0 then
            return pool[index].Id
        end
    end
    error("Empty Muncher reward selection")
end

-- RNG and the unmodified catalog input value come only from the server.
function Rewards.Roll(
    tier: number,
    rng: any,
    definition: (string) -> any,
    value: number?,
    generation: number?,
    pity: boolean?
): string
    local inputValue = value or Config.TierMinimums[tier]
    local pool = Rewards.Weights(tier, inputValue)
    local total = 0
    for _, entry in pool do
        assert(entry.Id ~= "PlayerHead" and entry.Id ~= "Player_Head", "Player heads cannot be rewards")
        assert(definition(entry.Id) and entry.Weight > 0, "Invalid Muncher reward")
        total += entry.Weight
    end
    assert(math.abs(total - 10000) < 0.000001, "Muncher pool must total 10000 basis points")
    if pity then
        local wins, winTotal = {}, 0
        for _, entry in pool do
            if definition(entry.Id).Value > inputValue then
                table.insert(wins, entry)
                winTotal += entry.Weight
            end
        end
        return if winTotal > 0 then weightedRoll(wins, winTotal, rng) else pool[#pool].Id
    end
    return weightedRoll(Rewards.ChainWeights(pool, inputValue, generation or 0, definition), total, rng)
end
return Rewards
