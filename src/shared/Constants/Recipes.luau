-- protein shake and fruit smoothie recipes
local Recipes = {
    ["Protein Shake"] = {
        RequiredProgress = 60,
        Color = Color3.fromRGB(139, 69, 19),
        Pay = 40,
    },
    ["Fruit Smoothie"] = {
        RequiredProgress = 8, -- Harder to blend
        Color = Color3.fromRGB(255, 105, 180),
        Pay = 25,
    },
}

return Recipes