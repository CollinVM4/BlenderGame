-- Optional special discoveries. Exact multisets unlock a name, never permission to serve.
local Recipes: { [string]: { Ingredients: { string }, RequiredProgress: number, Color: Color3, Pay: number } } = {
    ["Protein Shake"] = {
        Ingredients = { "Banana", "Banana", "Ice" },
        RequiredProgress = 60,
        Color = Color3.fromRGB(139, 69, 19),
        Pay = 40,
    },
    ["Fruit Smoothie"] = {
        Ingredients = { "Strawberry", "Banana", "Ice" },
        RequiredProgress = 8, -- Legacy metadata; BlendService uses Economy.RequiredProgress.
        Color = Color3.fromRGB(255, 105, 180),
        Pay = 25,
    },
}

return Recipes
