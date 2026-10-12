--!strict
local Ingredients = require(script.Parent.Ingredients)

local FarmEligibility = {}

-- This ingredient opt-out never overrides ownership, distance, row, or action checks.
-- Omitted/true preserves legacy eligibility, including existing Mystery definitions.
function FarmEligibility.CanPlant(definition: Ingredients.IngredientDefinition?): boolean
    return definition ~= nil and definition.Farmable ~= false
end

return FarmEligibility
