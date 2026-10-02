--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Item = require(Shared.IngredientItem)
local Types = require(Shared.Types)
local StashValue = {}
function StashValue.GetEffectiveIngredientValue(item: Types.IngredientItem): number
    Item.Resolve(item, workspace:GetServerTimeNow())
    return Item.GetIngredientValue(item, workspace:GetServerTimeNow())
end
function StashValue.Calculate(slot: any): number
    if slot.ItemType == "Smoothie" and slot.Smoothie then
        return Item.GetSmoothieValue(slot.Smoothie, workspace:GetServerTimeNow())
    end
    local total = 0
    for _, item in slot.Ingredients do
        total += StashValue.GetEffectiveIngredientValue(item)
    end
    return total
end
return StashValue
