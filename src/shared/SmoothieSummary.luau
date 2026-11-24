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

function Summary.GetBonuses(batch: Batch): Bonuses
    local config = Economy.SmoothieBonuses
    local color, identical
    local ids = batch.Ingredients
    if #ids == Economy.MaxIngredients then
        local first, second, third = Ingredients[ids[1]], Ingredients[ids[2]], Ingredients[ids[3]]
        for _, tag in first.Tags do
            if colorTags[tag] and table.find(second.Tags, tag) and table.find(third.Tags, tag) then
                color = tag
                break
            end
        end
        if first.Id == second.Id and first.Id == third.Id then
            identical = first.Id
        end
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
