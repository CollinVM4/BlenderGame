--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Economy = require(Shared.Constants.Economy)
local Ingredients = require(Shared.Constants.Ingredients)
local Item = require(Shared.IngredientItem)
local Types = require(Shared.Types)

local Summary = {}
-- Color requirements use the ingredients’ tags, independently of the rendered tint.
local colorTags = { Red = true, Yellow = true, Green = true, Blue = true, Purple = true } :: { [string]: boolean }

type Batch = { Ingredients: { string }, IngredientItems: { Types.IngredientItem }? }

export type Bonuses = {
    Color: string?,
    Identical: string?,
    ColorValue: number,
    IdenticalValue: number,
    StolenValue: number,
    StolenCount: number,
    ByIngredient: { number },
}

export type Details = {
    Ingredients: { string },
    Tint: Color3,
    Colors: string,
    Description: string,
    BaseValue: number,
    RipenessValue: number,
    MysteryValue: number,
    ComboColor: string?,
    ComboIngredient: string?,
    ColorValue: number,
    IdenticalValue: number,
    StolenValue: number,
    StolenCount: number,
    Value: number,
}

-- The live counter uses the same match as the final bonus, starting at two accepted ingredients.
function Summary.GetCombos(ids: { string }): (string?, string?)
    if #ids < 2 or #ids > Economy.MaxIngredients then
        return nil, nil
    end
    local first = Ingredients[ids[1]]
    local color: string? = nil
    for _, tag in first.Tags do
        if not colorTags[tag] then
            continue
        end
        local shared = true
        for index = 2, #ids do
            if not table.find(Ingredients[ids[index]].Tags, tag) then
                shared = false
                break
            end
        end
        if shared then
            color = tag
            break
        end
    end
    for index = 2, #ids do
        if Ingredients[ids[index]].Id ~= first.Id then
            return color, nil
        end
    end
    return color, first.Id
end

function Summary.GetBonuses(batch: Batch): Bonuses
    local config = Economy.SmoothieBonuses
    local ids = batch.Ingredients
    local color, identical
    if #ids == Economy.MaxIngredients then
        color, identical = Summary.GetCombos(ids)
    end

    local bonuses: Bonuses = {
        Color = color,
        Identical = identical,
        ColorValue = 0,
        IdenticalValue = 0,
        StolenValue = 0,
        StolenCount = 0,
        ByIngredient = {},
    }
    for index, id in ids do
        local base = Ingredients[id].Value
        local unit = batch.IngredientItems and batch.IngredientItems[index]
        local colorValue = if color then base * config.SharedColor else 0
        local identicalValue = if identical then base * config.IdenticalIngredient else 0
        local stolenValue = 0
        if unit and unit.WasStolen == true then
            stolenValue = base * config.StolenIngredient
            bonuses.StolenCount += 1
        end
        bonuses.ColorValue += colorValue
        bonuses.IdenticalValue += identicalValue
        bonuses.StolenValue += stolenValue
        bonuses.ByIngredient[index] = colorValue + identicalValue + stolenValue
    end
    return bonuses
end

function Summary.Build(smoothie: Types.Smoothie, now: number): Details
    local base, mystery, ripeness = 0, 0, 0
    for index, id in smoothie.Ingredients do
        local ingredient = Ingredients[id]
        if ingredient.Rarity == "Mystery" then
            mystery += ingredient.Value
        else
            base += ingredient.Value
        end
        ripeness += Item.GetSmoothieIngredientValue(smoothie, index, now) - ingredient.Value
    end
    local colorNames, traits = {}, {}
    for _, tag in smoothie.Tags do
        if colorTags[tag] then
            table.insert(colorNames, tag)
        elseif #traits < 3 then
            table.insert(traits, tag)
        end
    end
    local bonuses = Summary.GetBonuses(smoothie)
    return {
        Ingredients = table.clone(smoothie.Ingredients),
        Tint = smoothie.Color,
        Colors = if #colorNames > 0 then table.concat(colorNames, " / ") else "None",
        Description = if #traits > 0 then table.concat(traits, " • ") else "Mixed blend",
        BaseValue = base,
        RipenessValue = ripeness,
        MysteryValue = mystery,
        ComboColor = bonuses.Color,
        ComboIngredient = bonuses.Identical,
        ColorValue = bonuses.ColorValue,
        IdenticalValue = bonuses.IdenticalValue,
        StolenValue = bonuses.StolenValue,
        StolenCount = bonuses.StolenCount,
        Value = base + ripeness + mystery + bonuses.ColorValue + bonuses.IdenticalValue + bonuses.StolenValue,
    }
end

return Summary
