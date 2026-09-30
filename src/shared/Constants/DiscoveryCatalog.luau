--!strict
local Ingredients = require(script.Parent.Ingredients)
local CustomerRequests = require(script.Parent.CustomerRequests)
local DiscoveryCatalog = {}
DiscoveryCatalog.RarityOrder = table.freeze({ Common = 1, Uncommon = 2, Rare = 3, Mystery = 4 })
export type IngredientEntry = { Id: string, DisplayName: string, Rarity: string, Value: number, JumpLocation: number }
export type SpecialCustomerEntry = { Id: string, DisplayName: string, MinJumpTier: number }

function DiscoveryCatalog.GetSpecialCustomer(id: string): SpecialCustomerEntry?
    local mapping = CustomerRequests.NPCs[id]
    if not mapping or not (mapping.Type == "Special" or (not mapping.Type and mapping.RequestId)) then
        return nil
    end
    local request, reason = CustomerRequests.GetForNPC(id)
    if reason then
        return nil
    end
    return { Id = id, DisplayName = mapping.DisplayName or id, MinJumpTier = if request then request.MinJumpTier else 0 }
end

-- Complete ordered catalogs, independent of any player's unlocked entries.
function DiscoveryCatalog.GetIngredients(): { IngredientEntry }
    local entries: { IngredientEntry } = {}
    for id, definition in Ingredients do
        local entry: IngredientEntry = {
            Id = id,
            DisplayName = definition.DisplayName or id,
            Rarity = definition.Rarity or "Common",
            Value = definition.Value,
            JumpLocation = definition.JumpLocation,
        }
        table.insert(entries, entry)
    end
    local order: { [string]: number } = DiscoveryCatalog.RarityOrder
    table.sort(entries, function(a, b)
        local left, right = order[a.Rarity], order[b.Rarity]
        return if left == right then a.Id < b.Id else left < right
    end)
    return entries
end

function DiscoveryCatalog.GetSpecialCustomers(): { SpecialCustomerEntry }
    local entries: { SpecialCustomerEntry } = {}
    for id in CustomerRequests.NPCs do
        local entry = DiscoveryCatalog.GetSpecialCustomer(id)
        if entry then
            table.insert(entries, entry)
        end
    end
    table.sort(entries, function(a, b)
        return if a.MinJumpTier == b.MinJumpTier then a.Id < b.Id else a.MinJumpTier < b.MinJumpTier
    end)
    return entries
end
return DiscoveryCatalog
