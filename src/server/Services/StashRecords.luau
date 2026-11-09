--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Types = require(Shared.Types)
local Ingredients = require(Shared.Constants.Ingredients)
local Item = require(Shared.IngredientItem)
local SmoothieItem = require(script.Parent.SmoothieItem)
local Capacity = require(Shared.Constants.Economy).NormalStash.IngredientCapacity
local Records = {}

local function encodeUnit(unit: Types.IngredientItem): any
    return {
        IngredientId = unit.IngredientId,
        ItemId = unit.ItemId,
        Origin = unit.Origin,
        MuncherGeneration = unit.MuncherGeneration,
        RipenessStoredSeconds = Item.GetStoredRipenessSeconds(unit, workspace:GetServerTimeNow()),
        IsRipe = Item.IsRipe(unit, workspace:GetServerTimeNow()),
        SourceUserId = unit.SourceUserId,
        SourceDisplayName = unit.SourceDisplayName,
        SourceUsername = unit.SourceUsername,
        AnnouncementOwnership = if unit.AnnouncementOwnership
            then { LastOwnerUserId = unit.AnnouncementOwnership.LastOwnerUserId }
            else nil,
    }
end

local function decodeUnit(source: any, stored: boolean): Types.IngredientItem
    assert(type(source) == "table" and Ingredients[source.IngredientId], "Invalid persisted ingredient")
    assert(type(source.ItemId) == "string" and type(source.RipenessStoredSeconds) == "number", "Invalid persisted unit")
    local unit = encodeUnit(source)
    if stored then
        Item.EnterStash(unit, workspace:GetServerTimeNow())
    end
    return unit
end

function Records.Encode(stash: { [number]: Types.StashSlot }): any
    local slots = {}
    for index = 1, 10 do
        local source = stash[index]
        local record: any = { Ingredients = {} }
        if source then
            for _, unit in source.Ingredients do
                table.insert(record.Ingredients, encodeUnit(unit))
            end
            if source.Smoothie then
                record.Smoothie = {
                    BlendId = source.Smoothie.BlendId,
                    Ingredients = table.clone(source.Smoothie.Ingredients),
                }
                if source.Smoothie.IngredientItems then
                    record.Smoothie.IngredientItems = {}
                    for _, unit in source.Smoothie.IngredientItems do
                        table.insert(record.Smoothie.IngredientItems, encodeUnit(unit))
                    end
                end
            end
        end
        slots[index] = record
    end
    return slots
end

function Records.Decode(records: any): { [number]: Types.StashSlot }
    local stash: { [number]: Types.StashSlot } = {}
    for key in records do
        assert(type(key) == "number" and key % 1 == 0 and key >= 1 and key <= 10, "Invalid persisted slot")
    end
    for index = 1, 10 do
        local source = records[index] or { Ingredients = {} }
        assert(type(source.Ingredients) == "table" and #source.Ingredients <= Capacity, "Invalid persisted capacity")
        local slot: Types.StashSlot = {
            SlotIndex = index,
            Ingredients = {},
            Count = 0,
            Capacity = Capacity,
            Protected = false, -- always re-resolved from authored server metadata
        }
        for _, unit in source.Ingredients do
            table.insert(slot.Ingredients, decodeUnit(unit, true))
        end
        slot.Count = #slot.Ingredients
        if source.Smoothie then
            assert(slot.Count == 0 and SmoothieItem.Valid(source.Smoothie), "Invalid persisted smoothie")
            local smoothie = SmoothieItem.Copy(source.Smoothie)
            if smoothie.IngredientItems then
                for i, unit in smoothie.IngredientItems do
                    smoothie.IngredientItems[i] = decodeUnit(unit, false)
                end
            end
            slot.Smoothie, slot.ItemType, slot.Count, slot.Capacity = smoothie, "Smoothie", 1, 1
        elseif slot.Count > 0 then
            slot.ItemType = "Ingredient"
            slot.IngredientId = slot.Ingredients[slot.Count].IngredientId
        end
        stash[index] = slot
    end
    return stash
end

return Records
