--!strict

local Ingredients: {
	[string]: {
		Id: string,
		DisplayName: string,
		Tags: { string },
		BlendColor: Color3,
		Rarity: string,
	},
} = {
	Apple = {
		Id = "Apple",
		DisplayName = "Apple",
		Tags = { "Fruit", "Sweet", "Healthy", "Red" },
		BlendColor = Color3.fromRGB(210, 55, 45),
		Rarity = "Common",
	},

	Avocado = {
		Id = "Avocado",
		DisplayName = "Avocado",
		Tags = { "Fruit", "Healthy", "Green" },
		BlendColor = Color3.fromRGB(115, 160, 70),
		Rarity = "Common",
	},

	Banana = {
		Id = "Banana",
		DisplayName = "Banana",
		Tags = { "Fruit", "Sweet", "Yellow" },
		BlendColor = Color3.fromRGB(250, 225, 105),
		Rarity = "Common",
	},

	Blueberry = {
		Id = "Blueberry",
		DisplayName = "Blueberry",
		Tags = { "Fruit", "Sweet", "Blue" },
		BlendColor = Color3.fromRGB(80, 75, 190),
		Rarity = "Common",
	},

	Broccoli = {
		Id = "Broccoli",
		DisplayName = "Broccoli",
		Tags = { "Vegetable", "Healthy", "Green" },
		BlendColor = Color3.fromRGB(65, 135, 55),
		Rarity = "Common",
	},

	Cabbage = {
		Id = "Cabbage",
		DisplayName = "Cabbage",
		Tags = { "Vegetable", "Healthy", "Green" },
		BlendColor = Color3.fromRGB(125, 180, 95),
		Rarity = "Common",
	},

	Carrot = {
		Id = "Carrot",
		DisplayName = "Carrot",
		Tags = { "Vegetable", "Healthy", "Orange" },
		BlendColor = Color3.fromRGB(240, 125, 45),
		Rarity = "Common",
	},

	Cauliflower = {
		Id = "Cauliflower",
		DisplayName = "Cauliflower",
		Tags = { "Vegetable", "Healthy", "White" },
		BlendColor = Color3.fromRGB(225, 220, 190),
		Rarity = "Common",
	},

	Cherries = {
		Id = "Cherries",
		DisplayName = "Cherries",
		Tags = { "Fruit", "Sweet", "Red" },
		BlendColor = Color3.fromRGB(190, 35, 55),
		Rarity = "Common",
	},

	Chili_Pepper = {
		Id = "Chili_Pepper",
		DisplayName = "Chili Pepper",
		Tags = { "Vegetable", "Spicy", "Red" },
		BlendColor = Color3.fromRGB(215, 45, 35),
		Rarity = "Common",
	},

	Coconut = {
		Id = "Coconut",
		DisplayName = "Coconut",
		Tags = { "Fruit", "Sweet", "White" },
		BlendColor = Color3.fromRGB(225, 220, 195),
		Rarity = "Common",
	},

	Corn = {
		Id = "Corn",
		DisplayName = "Corn",
		Tags = { "Vegetable", "Sweet", "Yellow" },
		BlendColor = Color3.fromRGB(245, 210, 65),
		Rarity = "Common",
	},

	Cucumber = {
		Id = "Cucumber",
		DisplayName = "Cucumber",
		Tags = { "Vegetable", "Healthy", "Green" },
		BlendColor = Color3.fromRGB(80, 160, 75),
		Rarity = "Common",
	},

	Dragon_Fruit = {
		Id = "Dragon_Fruit",
		DisplayName = "Dragon Fruit",
		Tags = { "Fruit", "Sweet", "Pink" },
		BlendColor = Color3.fromRGB(235, 90, 155),
		Rarity = "Rare",
	},

	Eggplant = {
		Id = "Eggplant",
		DisplayName = "Eggplant",
		Tags = { "Vegetable", "Purple" },
		BlendColor = Color3.fromRGB(100, 55, 135),
		Rarity = "Common",
	},

	Enoki_Mushrooms = {
		Id = "Enoki_Mushrooms",
		DisplayName = "Enoki Mushrooms",
		Tags = { "Mushroom", "Healthy", "White" },
		BlendColor = Color3.fromRGB(225, 215, 180),
		Rarity = "Uncommon",
	},

	Fig = {
		Id = "Fig",
		DisplayName = "Fig",
		Tags = { "Fruit", "Sweet", "Purple" },
		BlendColor = Color3.fromRGB(125, 65, 115),
		Rarity = "Uncommon",
	},

	Garlic = {
		Id = "Garlic",
		DisplayName = "Garlic",
		Tags = { "Vegetable", "White" },
		BlendColor = Color3.fromRGB(225, 215, 185),
		Rarity = "Common",
	},

	Grapefruit = {
		Id = "Grapefruit",
		DisplayName = "Grapefruit",
		Tags = { "Fruit", "Citrus", "Pink" },
		BlendColor = Color3.fromRGB(235, 120, 115),
		Rarity = "Common",
	},

	Grapes = {
		Id = "Grapes",
		DisplayName = "Grapes",
		Tags = { "Fruit", "Sweet", "Purple" },
		BlendColor = Color3.fromRGB(125, 65, 170),
		Rarity = "Common",
	},

	Green_Apple = {
		Id = "Green_Apple",
		DisplayName = "Green Apple",
		Tags = { "Fruit", "Sweet", "Healthy", "Green" },
		BlendColor = Color3.fromRGB(130, 190, 65),
		Rarity = "Common",
	},

	Green_Pepper = {
		Id = "Green_Pepper",
		DisplayName = "Green Pepper",
		Tags = { "Vegetable", "Healthy", "Green" },
		BlendColor = Color3.fromRGB(75, 150, 65),
		Rarity = "Common",
	},

	King_Oyster_Mushroom = {
		Id = "King_Oyster_Mushroom",
		DisplayName = "King Oyster Mushroom",
		Tags = { "Mushroom", "Healthy", "White" },
		BlendColor = Color3.fromRGB(195, 180, 145),
		Rarity = "Uncommon",
	},

	Kiwi = {
		Id = "Kiwi",
		DisplayName = "Kiwi",
		Tags = { "Fruit", "Sweet", "Green" },
		BlendColor = Color3.fromRGB(115, 170, 65),
		Rarity = "Common",
	},

	Lemon = {
		Id = "Lemon",
		DisplayName = "Lemon",
		Tags = { "Fruit", "Citrus", "Yellow" },
		BlendColor = Color3.fromRGB(245, 225, 65),
		Rarity = "Common",
	},

	Lime = {
		Id = "Lime",
		DisplayName = "Lime",
		Tags = { "Fruit", "Citrus", "Green" },
		BlendColor = Color3.fromRGB(110, 190, 65),
		Rarity = "Common",
	},

	Mango = {
		Id = "Mango",
		DisplayName = "Mango",
		Tags = { "Fruit", "Sweet", "Orange" },
		BlendColor = Color3.fromRGB(245, 155, 55),
		Rarity = "Common",
	},

	Melon = {
		Id = "Melon",
		DisplayName = "Melon",
		Tags = { "Fruit", "Sweet", "Green" },
		BlendColor = Color3.fromRGB(160, 205, 105),
		Rarity = "Common",
	},

	Muscat_Grapes = {
		Id = "Muscat_Grapes",
		DisplayName = "Muscat Grapes",
		Tags = { "Fruit", "Sweet", "Green" },
		BlendColor = Color3.fromRGB(165, 205, 90),
		Rarity = "Uncommon",
	},

	Napa_Cabbage = {
		Id = "Napa_Cabbage",
		DisplayName = "Napa Cabbage",
		Tags = { "Vegetable", "Healthy", "Green" },
		BlendColor = Color3.fromRGB(160, 195, 105),
		Rarity = "Common",
	},

	Onion = {
		Id = "Onion",
		DisplayName = "Onion",
		Tags = { "Vegetable", "White" },
		BlendColor = Color3.fromRGB(220, 205, 170),
		Rarity = "Common",
	},

	Orange = {
		Id = "Orange",
		DisplayName = "Orange",
		Tags = { "Fruit", "Sweet", "Citrus", "Orange" },
		BlendColor = Color3.fromRGB(245, 145, 45),
		Rarity = "Common",
	},

	Papaya = {
		Id = "Papaya",
		DisplayName = "Papaya",
		Tags = { "Fruit", "Sweet", "Orange" },
		BlendColor = Color3.fromRGB(245, 145, 75),
		Rarity = "Common",
	},

	Peach = {
		Id = "Peach",
		DisplayName = "Peach",
		Tags = { "Fruit", "Sweet", "Pink" },
		BlendColor = Color3.fromRGB(245, 150, 125),
		Rarity = "Common",
	},

	Pear = {
		Id = "Pear",
		DisplayName = "Pear",
		Tags = { "Fruit", "Sweet", "Green" },
		BlendColor = Color3.fromRGB(170, 195, 85),
		Rarity = "Common",
	},

	Persimmon = {
		Id = "Persimmon",
		DisplayName = "Persimmon",
		Tags = { "Fruit", "Sweet", "Orange" },
		BlendColor = Color3.fromRGB(235, 105, 45),
		Rarity = "Uncommon",
	},

	Pineapple = {
		Id = "Pineapple",
		DisplayName = "Pineapple",
		Tags = { "Fruit", "Sweet", "Yellow" },
		BlendColor = Color3.fromRGB(235, 190, 65),
		Rarity = "Common",
	},

	Plum = {
		Id = "Plum",
		DisplayName = "Plum",
		Tags = { "Fruit", "Sweet", "Purple" },
		BlendColor = Color3.fromRGB(110, 55, 135),
		Rarity = "Common",
	},

	Pomegranate = {
		Id = "Pomegranate",
		DisplayName = "Pomegranate",
		Tags = { "Fruit", "Sweet", "Red" },
		BlendColor = Color3.fromRGB(185, 45, 65),
		Rarity = "Uncommon",
	},

	Potato = {
		Id = "Potato",
		DisplayName = "Potato",
		Tags = { "Vegetable", "Brown" },
		BlendColor = Color3.fromRGB(170, 135, 90),
		Rarity = "Common",
	},

	Raspberry = {
		Id = "Raspberry",
		DisplayName = "Raspberry",
		Tags = { "Fruit", "Sweet", "Red" },
		BlendColor = Color3.fromRGB(205, 45, 85),
		Rarity = "Common",
	},

	Red_Bell_Pepper = {
		Id = "Red_Bell_Pepper",
		DisplayName = "Red Bell Pepper",
		Tags = { "Vegetable", "Healthy", "Red" },
		BlendColor = Color3.fromRGB(220, 55, 45),
		Rarity = "Common",
	},

	Red_Onion = {
		Id = "Red_Onion",
		DisplayName = "Red Onion",
		Tags = { "Vegetable", "Purple" },
		BlendColor = Color3.fromRGB(145, 70, 125),
		Rarity = "Common",
	},

	Starfruit = {
		Id = "Starfruit",
		DisplayName = "Starfruit",
		Tags = { "Fruit", "Sweet", "Yellow" },
		BlendColor = Color3.fromRGB(235, 205, 75),
		Rarity = "Uncommon",
	},

	Strawberry = {
		Id = "Strawberry",
		DisplayName = "Strawberry",
		Tags = { "Fruit", "Sweet", "Red" },
		BlendColor = Color3.fromRGB(235, 65, 80),
		Rarity = "Common",
	},

	Sweet_Potato = {
		Id = "Sweet_Potato",
		DisplayName = "Sweet Potato",
		Tags = { "Vegetable", "Sweet", "Orange" },
		BlendColor = Color3.fromRGB(205, 105, 60),
		Rarity = "Common",
	},

	Tomato = {
		Id = "Tomato",
		DisplayName = "Tomato",
		Tags = { "Fruit", "Red" },
		BlendColor = Color3.fromRGB(220, 60, 45),
		Rarity = "Common",
	},

	Turnip = {
		Id = "Turnip",
		DisplayName = "Turnip",
		Tags = { "Vegetable", "White" },
		BlendColor = Color3.fromRGB(210, 195, 185),
		Rarity = "Common",
	},

	Watermelon = {
		Id = "Watermelon",
		DisplayName = "Watermelon",
		Tags = { "Fruit", "Sweet", "Red" },
		BlendColor = Color3.fromRGB(240, 95, 110),
		Rarity = "Common",
	},

	Yellow_Bell_Pepper = {
		Id = "Yellow_Bell_Pepper",
		DisplayName = "Yellow Bell Pepper",
		Tags = { "Vegetable", "Healthy", "Yellow" },
		BlendColor = Color3.fromRGB(240, 205, 55),
		Rarity = "Common",
	},

	-- Existing non-pack ingredients

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

    Steak = {
        Id = "Steak",
        DisplayName = "Steak",
        Tags = { "Protein", "Weird" },
        BlendColor = Color3.fromRGB(150, 50, 50),
        Rarity = "Uncommon",
    },

    Hamburger = {
        Id = "Hamburger",
        DisplayName = "Hamburger",
        Tags = { "Protein", "Weird" },
        BlendColor = Color3.fromRGB(180, 100, 60),
        Rarity = "Uncommon",
    },

	Noob = {
		Id = "Noob",
		DisplayName = "Noob",
		Tags = { "Weird", "Character" },
		BlendColor = Color3.fromRGB(245, 210, 55),
		Rarity = "Rare",
	},

	GoldenApple = {
		Id = "GoldenApple",
		DisplayName = "Golden Apple",
		Tags = { "Fruit", "Sweet", "Healthy", "Yellow" },
		BlendColor = Color3.fromRGB(255, 205, 55),
		Rarity = "Rare",
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