--!strict
local Ingredients: { [string]: { DisplayName: string, Tags: { string }, BlendColor: Color3, Rarity: string } } = {
    Strawberry = {
        DisplayName = "Strawberry",
        Tags = { "Fruit", "Sweet", "Red" },
        BlendColor = Color3.fromRGB(235, 65, 80),
        Rarity = "Common",
    },
    Banana = {
        DisplayName = "Banana",
        Tags = { "Fruit", "Sweet", "Yellow" },
        BlendColor = Color3.fromRGB(250, 225, 105),
        Rarity = "Common",
    },
    Ice = { DisplayName = "Ice", Tags = { "Cold" }, BlendColor = Color3.fromRGB(190, 235, 255), Rarity = "Common" },
    Spinach = {
        DisplayName = "Spinach",
        Tags = { "Healthy", "Green" },
        BlendColor = Color3.fromRGB(70, 150, 65),
        Rarity = "Common",
    },
    Tire = {
        DisplayName = "Tire",
        Tags = { "Gross", "Weird" },
        BlendColor = Color3.fromRGB(45, 45, 50),
        Rarity = "Uncommon",
    },
    Noob = {
        DisplayName = "Noob",
        Tags = { "Weird", "Character" },
        BlendColor = Color3.fromRGB(245, 210, 55),
        Rarity = "Rare",
    },
}
return Ingredients
