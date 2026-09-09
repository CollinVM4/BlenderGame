--!strict
local Ingredients: { [string]: { Id: string, DisplayName: string, Tags: { string }, BlendColor: Color3, Rarity: string } } =
    {
        Strawberry = {
            Id = "Strawberry",
            DisplayName = "Strawberry",
            Tags = { "Fruit", "Sweet", "Red" },
            BlendColor = Color3.fromRGB(235, 65, 80),
            Rarity = "Common",
        },
        Banana = {
            Id = "Banana",
            DisplayName = "Banana",
            Tags = { "Fruit", "Sweet", "Yellow" },
            BlendColor = Color3.fromRGB(250, 225, 105),
            Rarity = "Common",
        },
        Ice = {
            Id = "Ice",
            DisplayName = "Ice",
            Tags = { "Cold" },
            BlendColor = Color3.fromRGB(190, 235, 255),
            Rarity = "Common",
        },
        Spinach = {
            Id = "Spinach",
            DisplayName = "Spinach",
            Tags = { "Healthy", "Green" },
            BlendColor = Color3.fromRGB(70, 150, 65),
            Rarity = "Common",
        },
        Tire = {
            Id = "Tire",
            DisplayName = "Tire",
            Tags = { "Black", "Gross", "Weird" },
            BlendColor = Color3.fromRGB(45, 45, 50),
            Rarity = "Uncommon",
        },
        Noob = {
            Id = "Noob",
            DisplayName = "Noob",
            Tags = { "Weird", "Character" },
            BlendColor = Color3.fromRGB(245, 210, 55),
            Rarity = "Rare",
        },
        Watermelon = {
            Id = "Watermelon",
            DisplayName = "Watermelon",
            Tags = { "Fruit", "Sweet", "Red" },
            BlendColor = Color3.fromRGB(240, 95, 110),
            Rarity = "Common",
        },
        Blueberry = {
            Id = "Blueberry",
            DisplayName = "Blueberry",
            Tags = { "Fruit", "Sweet", "Blue" },
            BlendColor = Color3.fromRGB(80, 75, 190),
            Rarity = "Common",
        },
        Apple = {
            Id = "Apple",
            DisplayName = "Apple",
            Tags = { "Fruit", "Sweet", "Healthy", "Red" },
            BlendColor = Color3.fromRGB(210, 55, 45),
            Rarity = "Common",
        },
        -- Mystery uses the same deterministic RGB mean as every other unit.
        Mystery = {
            Id = "Mystery",
            DisplayName = "Mystery",
            Tags = { "Weird", "Mystery" },
            BlendColor = Color3.fromRGB(170, 65, 230),
            Rarity = "Rare",
        },
    }
return Ingredients
