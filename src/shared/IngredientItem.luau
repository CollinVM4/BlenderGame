--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Types = require(Shared.Types)
local Config = require(Shared.Constants.Ripeness)
local Ingredients = require(Shared.Constants.Ingredients)
local Item = {}

function Item.New(id: string, itemId: string): Types.IngredientItem
    return { IngredientId = id, ItemId = itemId, RipenessStoredSeconds = 0, IsRipe = false }
end

function Item.GetStoredRipenessSeconds(item: Types.IngredientItem, now: number): number
    if item.IsRipe then
        return Config.RipenessSeconds
    end
    return math.clamp(
        item.RipenessStoredSeconds + (if item.RipenessStoredAt then math.max(0, now - item.RipenessStoredAt) else 0),
        0,
        Config.RipenessSeconds
    )
end

function Item.GetRipenessProgress(item: Types.IngredientItem, now: number): number
    return Item.GetStoredRipenessSeconds(item, now) / Config.RipenessSeconds
end

function Item.IsRipe(item: Types.IngredientItem, now: number): boolean
    return item.IsRipe or Item.GetRipenessProgress(item, now) >= 1
end

-- Mutations are server-owned; clients can use the pure timing helpers above.
function Item.Resolve(item: Types.IngredientItem, now: number)
    if Item.IsRipe(item, now) then
        item.IsRipe = true
        item.RipenessStoredSeconds = Config.RipenessSeconds
        item.RipenessStoredAt = nil
    end
end

function Item.EnterStash(item: Types.IngredientItem, now: number)
    Item.Resolve(item, now)
    if not item.IsRipe and not item.RipenessStoredAt then
        item.RipenessStoredAt = now
    end
end

function Item.ExitStash(item: Types.IngredientItem, now: number)
    item.RipenessStoredSeconds = Item.GetStoredRipenessSeconds(item, now)
    item.RipenessStoredAt = nil
    Item.Resolve(item, now)
end

function Item.GetIngredientValue(item: Types.IngredientItem, now: number): number
    return Ingredients[item.IngredientId].Value * (if Item.IsRipe(item, now) then Config.RipenessValueMultiplier else 1)
end

function Item.CopyAll(items: { Types.IngredientItem }?): { Types.IngredientItem }?
    if not items then
        return nil
    end
    local copy = {}
    for _, item in items do
        table.insert(copy, table.clone(item))
    end
    return copy
end

-- Legacy ID-only smoothies represent fresh ingredients. New smoothies retain units.
function Item.GetSmoothieValue(
    data: { Ingredients: { string }, IngredientItems: { Types.IngredientItem }? },
    now: number
): number
    local total = 0
    for index, id in data.Ingredients do
        local unit = data.IngredientItems and data.IngredientItems[index]
        total += if unit then Item.GetIngredientValue(unit, now) else Ingredients[id].Value
    end
    return total
end

return Item
