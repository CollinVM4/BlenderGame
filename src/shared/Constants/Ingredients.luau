--!strict

export type IngredientDefinition = {
    Farmable: boolean?,
    Id: string,
    Value: number,
    DisplayName: string?,
    Tags: { string },
    BlendColor: Color3,
    Rarity: ("Common" | "Uncommon" | "Rare" | "Mystery")?,
    JumpLocation: number,
}

local Ingredients: { [string]: IngredientDefinition } = {
    Apple = {
        Id = "Apple",
        DisplayName = "Apple",
        Tags = { "Fruit", "Sweet", "Red" },
        BlendColor = Color3.fromRGB(210, 55, 45),
        Rarity = "Common",
        Value = 1500,
        JumpLocation = 0,
    },

    Banana = {
        Id = "Banana",
        DisplayName = "Banana",
        Tags = { "Fruit", "Sweet", "Yellow" },
        BlendColor = Color3.fromRGB(250, 225, 105),
        Rarity = "Common",
        Value = 2000,
        JumpLocation = 0,
    },

    Blueberry = {
        Id = "Blueberry",
        DisplayName = "Blueberry",
        Tags = { "Fruit", "Sweet", "Blue" },
        BlendColor = Color3.fromRGB(80, 75, 190),
        Rarity = "Common",
        Value = 2000,
        JumpLocation = 0,
    },

    Cabbage = {
        Id = "Cabbage",
        DisplayName = "Cabbage",
        Tags = { "Veggie", "Green" },
        BlendColor = Color3.fromRGB(125, 180, 95),
        Rarity = "Common",
        Value = 2000,
        JumpLocation = 0,
    },

    Carrot = {
        Id = "Carrot",
        DisplayName = "Carrot",
        Tags = { "Veggie", "Orange" },
        BlendColor = Color3.fromRGB(240, 125, 45),
        Rarity = "Common",
        Value = 2000,
        JumpLocation = 0,
    },

    Crab = {
        Id = "Crab",
        DisplayName = "Crab",
        Tags = { "Seafood", "Red", "Weird", "Protein" },
        BlendColor = Color3.fromRGB(200, 50, 50),
        Rarity = "Rare",
        Value = 35000,
        JumpLocation = 2,
    },

    Rainbow_Trout = {
        Id = "Rainbow_Trout",
        DisplayName = "Rainbow Trout",
        Tags = { "Seafood", "Rainbow", "Protein" },
        BlendColor = Color3.fromRGB(180, 200, 220),
        Rarity = "Rare",
        Value = 30000,
        JumpLocation = 0,
    },

    Cherries = {
        Id = "Cherries",
        DisplayName = "Cherries",
        Tags = { "Fruit", "Sweet", "Red" },
        BlendColor = Color3.fromRGB(190, 35, 55),
        Rarity = "Common",
        Value = 2000,
        JumpLocation = 0,
    },

    Chili_Pepper = {
        Id = "Chili_Pepper",
        DisplayName = "Chili Pepper",
        Tags = { "Veggie", "Spicy", "Red" },
        BlendColor = Color3.fromRGB(215, 45, 35),
        Rarity = "Common",
        Value = 10000,
        JumpLocation = 1,
    },

    Coconut = {
        Id = "Coconut",
        DisplayName = "Coconut",
        Tags = { "Fruit", "Sweet", "Tropical" },
        BlendColor = Color3.fromRGB(126, 76, 2),
        Rarity = "Rare",
        Value = 25000,
        JumpLocation = 2,
    },

    Dragon_Fruit = {
        Id = "Dragon_Fruit",
        DisplayName = "Dragon Fruit",
        Tags = { "Fruit", "Sweet", "Pink" },
        BlendColor = Color3.fromRGB(235, 90, 155),
        Rarity = "Mystery",
        Farmable = false,
        Value = 165000,
        JumpLocation = 3,
    },

    Mushrooms = {
        Id = "Mushrooms",
        DisplayName = "Mushrooms",
        Tags = { "Mushrooms", "White", "Veggie" },
        BlendColor = Color3.fromRGB(225, 215, 180),
        Rarity = "Uncommon",
        Value = 3000,
        JumpLocation = 0,
    },

    PlayerHead = { 
        Id = "PlayerHead",
        DisplayName = "Player Head", -- This will need to be dynamic
        Tags = { "Weird",},
        BlendColor = Color3.fromRGB(255, 105, 180),
        Rarity = "Uncommon",
        Value = 15000,
        JumpLocation = 0,
    },

    Grapes = {
        Id = "Grapes",
        DisplayName = "Grapes",
        Tags = { "Fruit", "Sweet", "Purple" },
        BlendColor = Color3.fromRGB(125, 65, 170),
        Rarity = "Common",
        Value = 2000,
        JumpLocation = 0,
    },

    Green_Apple = {
        Id = "Green_Apple",
        DisplayName = "Green Apple",
        Tags = { "Fruit", "Sweet", "Healthy", "Green" },
        BlendColor = Color3.fromRGB(130, 190, 65),
        Rarity = "Common",
        Value = 1500,
        JumpLocation = 0,
    },

    Pizza = {
        Id = "Pizza",
        DisplayName = "Pizza",
        Tags = { "Fast Food", "Mystery",},
        BlendColor = Color3.fromRGB(255, 200, 100),
        Rarity = "Rare",
        Value = 75000,
        JumpLocation = 3,
    },

    Kiwi = {
        Id = "Kiwi",
        DisplayName = "Kiwi",
        Tags = { "Fruit", "Sweet", "Green" },
        BlendColor = Color3.fromRGB(115, 170, 65),
        Rarity = "Common",
        Value = 2000,
        JumpLocation = 0,
    },

    Lemon = {
        Id = "Lemon",
        DisplayName = "Lemon",
        Tags = { "Fruit", "Sour", "Yellow" },
        BlendColor = Color3.fromRGB(245, 225, 65),
        Rarity = "Common",
        Value = 2000,
        JumpLocation = 0,
    },

    Rock = {
        Id = "Rock",
        DisplayName = "Rock",
        Tags = { "Rock", "Gray", "Weird" },
        BlendColor = Color3.fromRGB(150, 150, 150),
        Rarity = "Common",
        Value = 1000,
        JumpLocation = 0,
    },

    Shit = {
        Id = "Shit",
        DisplayName = "Bunoid Droppings",
        Tags = { "Weird", "Brown" },
        BlendColor = Color3.fromRGB(120, 85, 60),
        Rarity = "Common",
        Value = 2500,
        JumpLocation = 0,
    },

    Worm = {
        Id = "Worm",
        DisplayName = "Worm",
        Tags = { "Weird", "Protein", "Purple" },
        BlendColor = Color3.fromRGB(160, 50, 160),
        Rarity = "Common",
        Value = 1000,
        JumpLocation = 0,
    },

    Cinnamon = {
        Id = "Cinnamon",
        DisplayName = "Cinnamon",
        Tags = { "Cinnamon", "Brown", "Spice" },
        BlendColor = Color3.fromRGB(150, 100, 50),
        Rarity = "Rare",
        Value = 50000,
        JumpLocation = 3,
    },

    Melon = {
        Id = "Melon",
        DisplayName = "Melon",
        Tags = { "Fruit", "Sweet", "Green", "Cloud Garden" },
        BlendColor = Color3.fromRGB(160, 205, 105),
        Rarity = "Rare",
        Value = 45000,
        JumpLocation = 3,
    },

    Onion = {
        Id = "Onion",
        DisplayName = "Onion",
        Tags = { "Veggie", "White", "Weird",},
        BlendColor = Color3.fromRGB(220, 205, 170),
        Rarity = "Common",
        Value = 2000,
        JumpLocation = 0,
    },

    Gummy_Bear = {
        Id = "Gummy_Bear",
        DisplayName = "Gummy Bear",
        Tags = { "Candy", "Sweet", "Red" },
        BlendColor = Color3.fromRGB(255, 100, 100),
        Rarity = "Rare",
        Value = 25000,
        JumpLocation = 0,
    },

    Orange = {
        Id = "Orange",
        DisplayName = "Orange",
        Tags = { "Fruit", "Sweet", "Citrus", "Orange" },
        BlendColor = Color3.fromRGB(245, 145, 45),
        Rarity = "Common",
        Value = 3000,
        JumpLocation = 0,
    },

    Mango = {
        Id = "Mango",
        DisplayName = "Mango",
        Tags = { "Fruit", "Sweet", "Orange" },
        BlendColor = Color3.fromRGB(255, 165, 65),
        Rarity = "Rare",
        Value = 25000,
        JumpLocation = 2,
    },

    Chili_Sauce = {
        Id = "Chili_Sauce",
        DisplayName = "Chili Sauce",
        Tags = { "Spicy", "Red", "Weird" },
        BlendColor = Color3.fromRGB(255, 50, 50),
        Rarity = "Rare",
        Value = 35000,
        JumpLocation = 2,
    },

    Peach = {
        Id = "Peach",
        DisplayName = "Peach",
        Tags = { "Fruit", "Sweet", "Pink", "Cloud Garden" },
        BlendColor = Color3.fromRGB(245, 150, 125),
        Rarity = "Rare",
        Value = 45000,
        JumpLocation = 3,
    },

    Pear = {
        Id = "Pear",
        DisplayName = "Pear",
        Tags = { "Fruit", "Sweet", "Yellow" },
        BlendColor = Color3.fromRGB(200, 230, 150),
        Rarity = "Uncommon",
        Value = 10000,
        JumpLocation = 1,
    },

    Honey = {
        Id = "Honey",
        DisplayName = "Honey",
        Tags = { "Sweet", "Yellow" },
        BlendColor = Color3.fromRGB(255, 200, 100),
        Rarity = "Rare",
        Value = 22000,
        JumpLocation = 1,
    },

    Shell = {
        Id = "Shell",
        DisplayName = "Shell",
        Tags = { "Weird", "Red", "Protein", "Seafood" },
        BlendColor = Color3.fromRGB(150, 36, 36),
        Rarity = "Uncommon",
        Value = 15000,
        JumpLocation = 2,
    },

    Pineapple = {
        Id = "Pineapple",
        DisplayName = "Pineapple",
        Tags = { "Fruit", "Sweet", "Yellow" },
        BlendColor = Color3.fromRGB(235, 190, 65),
        Rarity = "Uncommon",
        Value = 10000,
        JumpLocation = 1,
    },

    Squid = {
        Id = "Squid",
        DisplayName = "Squid",
        Tags = { "Seafood", "White", "Weird", "Protein" },
        BlendColor = Color3.fromRGB(200, 200, 200),
        Rarity = "Uncommon",
        Value = 15000,
        JumpLocation = 2,
    },

    Fish = {
        Id = "Fish",
        DisplayName = "Fish",
        Tags = { "Seafood", "Blue", "Weird", "Protein" },
        BlendColor = Color3.fromRGB(25, 164, 223),
        Rarity = "Rare",
        Value = 30000,
        JumpLocation = 2,
    },

    Pomegranate = {
        Id = "Pomegranate",
        DisplayName = "Pomegranate",
        Tags = { "Fruit", "Sweet", "Red" },
        BlendColor = Color3.fromRGB(185, 45, 65),
        Rarity = "Rare",
        Value = 25000,
        JumpLocation = 2,
    },

    Golden_Potato = {
        Id = "Golden_Potato",
        DisplayName = "Golden Potato",
        Tags = { "Vegetable", "Golden", "Cloud Garden" },
        BlendColor = Color3.fromRGB(247, 250, 61),
        Rarity = "Rare",
        Value = 60000,
        JumpLocation = 3,
    },

    Protein = {
        Id = "Protein",
        DisplayName = "Protein",
        Tags = { "Protein", },
        BlendColor = Color3.fromRGB(119, 95, 13),
        Rarity = "Uncommon",
        Value = 5000,
        JumpLocation = 0,
    },

    Starfruit = {
        Id = "Starfruit",
        DisplayName = "Starfruit",
        Tags = { "Fruit", "Sweet", "Yellow" },
        BlendColor = Color3.fromRGB(235, 205, 75),
        Rarity = "Uncommon",
        Value = 10000,
        JumpLocation = 1,
    },

    Strawberry = {
        Id = "Strawberry",
        DisplayName = "Strawberry",
        Tags = { "Fruit", "Sweet", "Red" },
        BlendColor = Color3.fromRGB(235, 65, 80),
        Rarity = "Common",
        Value = 2000,
        JumpLocation = 0,
    },

    Golden_Tomato = {
        Id = "Golden_Tomato",
        DisplayName = "Golden Tomato",
        Tags = { "Fruit", "Golden", "Cloud Garden" },
        BlendColor = Color3.fromRGB(236, 227, 59),
        Rarity = "Rare",
        Value = 60000,
        JumpLocation = 3,
    },

    Cotton_Candy = {
        Id = "Cotton_Candy",
        DisplayName = "Cotton Candy",
        Tags = { "Sweet", "Pink", "Candy"},
        BlendColor = Color3.fromRGB(255, 182, 193),
        Rarity = "Rare",
        Value = 65000,
        JumpLocation = 3,
    },

    Watermelon = {
        Id = "Watermelon",
        DisplayName = "Watermelon",
        Tags = { "Fruit", "Sweet", "Red", "Watermelon" },
        BlendColor = Color3.fromRGB(240, 95, 110),
        Rarity = "Common",
        Value = 3000,
        JumpLocation = 0,
    },

    -- Existing non-pack ingredients

    Ice = {
        Id = "Ice",
        DisplayName = "Ice",
        Tags = { "Cold", "White", "Blue" },
        BlendColor = Color3.fromRGB(190, 235, 255),
        Rarity = "Common",
        Value = 1500,
        JumpLocation = 0,
    },

    Milk = {
        Id = "Milk",
        DisplayName = "Milk",
        Tags = { "Milk", "White" },
        BlendColor = Color3.fromRGB(245, 245, 245),
        Rarity = "Rare",
        Value = 20000,
        JumpLocation = 2,
    },

    Tire = {
        Id = "Tire",
        DisplayName = "Tire",
        Tags = { "Black", "Gross", "Weird" },
        BlendColor = Color3.fromRGB(45, 45, 50),
        Rarity = "Uncommon",
        Value = 8000,
        JumpLocation = 1,
    },

    Cactus = {
        Id = "Cactus",
        DisplayName = "Cactus",
        Tags = { "Weird", "Green", "Plant"},
        BlendColor = Color3.fromRGB(100, 200, 100),
        Rarity = "Uncommon",
        Value = 8000,
        JumpLocation = 1,
    },


    French_Fries = {
        Id = "French_Fries",
        DisplayName = "French Fries",
        Tags = { "Weird", "Fast Food", "Potato" },
        BlendColor = Color3.fromRGB(240, 200, 100),
        Rarity = "Uncommon",
        Value = 15000,
        JumpLocation = 1,
    },

    Sushi = {
        Id = "Sushi",
        DisplayName = "Sushi",
        Tags = { "Seafood", "Weird", "Protein", "Black" },
        BlendColor = Color3.fromRGB(200, 200, 200),
        Rarity = "Rare",
        Value = 35000,
        JumpLocation = 2,
    },

    Steak = {
        Id = "Steak",
        DisplayName = "Steak",
        Tags = { "Protein", "Steak" },
        BlendColor = Color3.fromRGB(150, 50, 50),
        Rarity = "Rare",
        Value = 25000,
        JumpLocation = 1,
    },

    Hamburger = {
        Id = "Hamburger",
        DisplayName = "Hamburger",
        Tags = { "Protein", "Weird", "Fast Food" },
        BlendColor = Color3.fromRGB(180, 100, 60),
        Rarity = "Uncommon",
        Value = 10000,
        JumpLocation = 1,
    },

    Noob = {
        Id = "Noob",
        DisplayName = "Noob's Head",
        Tags = { "Weird", "Yellow", "Noob" },
        BlendColor = Color3.fromRGB(245, 210, 55),
        Rarity = "Uncommon",
        Value = 12000,
        JumpLocation = 1,
    },

    -- Mystery uses the same deterministic RGB mean as every other unit.
    Mystery = {
        Id = "Mystery",
        DisplayName = "Mystery",
        Tags = { "Weird", "Mystery" },
        BlendColor = Color3.fromRGB(170, 65, 230),
        Rarity = "Rare",
        Value = 60000,
        JumpLocation = 3,
    },
}

return Ingredients
