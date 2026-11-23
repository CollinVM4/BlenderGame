--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Ingredients = require(Shared.Constants.Ingredients)
local Item = require(Shared.IngredientItem)
local Types = require(Shared.Types)

local Summary = {}
-- Color requirements use the ingredients’ tags, independently of the rendered tint.
local colorTags = { Red = true, Yellow = true, Green = true, Blue = true, Purple = true } :: { [string]: boolean }

export type Details = {
    Ingredients: { string },
    Tint: Color3,
    Colors: string,
    Description: string,
    BaseValue: number,
    RipenessValue: number,
    MysteryValue: number,
    Value: number,
}

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
    return {
        Ingredients = table.clone(smoothie.Ingredients),
        Tint = smoothie.Color,
        Colors = if #colorNames > 0 then table.concat(colorNames, " / ") else "None",
        Description = if #traits > 0 then table.concat(traits, " • ") else "Mixed blend",
        BaseValue = base,
        RipenessValue = ripeness,
        MysteryValue = mystery,
        Value = base + ripeness + mystery,
    }
end

return Summary
