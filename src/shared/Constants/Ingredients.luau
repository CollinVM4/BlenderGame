--!strict

export type IngredientDefinition = {
	Id: string,
	DisplayName: string?,
	Tags: { string },
	BlendColor: Color3,
	Rarity: ("Common" | "Uncommon" | "Rare" | "Mystery")?,
	JumpLocation: number
}

local Ingredients: { [string]: IngredientDefinition } = {
	Apple = {
		Id = "Apple",
		DisplayName = "Apple",
		Tags = { "Fruit", "Sweet", "Healthy", "Red" },
		BlendColor = Color3.fromRGB(210, 55, 45),
		Rarity = "Common",
		JumpLocation = 0
	},

	Banana = {
		Id = "Banana",
		DisplayName = "Banana",
		Tags = { "Fruit", "Sweet", "Yellow" },
		BlendColor = Color3.fromRGB(250, 225, 105),
		Rarity = "Common",
		JumpLocation = 0,
	},

	Blueberry = {
		Id = "Blueberry",
		DisplayName = "Blueberry",
		Tags = { "Fruit", "Sweet", "Blue" },
		BlendColor = Color3.fromRGB(80, 75, 190),
		Rarity = "Common",
		JumpLocation = 0,
	},


	Cabbage = {
		Id = "Cabbage",
		DisplayName = "Cabbage",
		Tags = { "Veggie", "Healthy", "Green" },
		BlendColor = Color3.fromRGB(125, 180, 95),
		Rarity = "Common",
		JumpLocation = 0,
	},

	Carrot = {
		Id = "Carrot",
		DisplayName = "Carrot",
		Tags = { "Veggie", "Healthy", "Orange" },
		BlendColor = Color3.fromRGB(240, 125, 45),
		Rarity = "Common",
		JumpLocation = 0,
	},

	Crab = {
		Id = "Crab",
		DisplayName = "Crab",
		Tags = { "Seafood", "Red", "Weird" },
		BlendColor = Color3.fromRGB(200, 50, 50),
		Rarity = "Rare",
		JumpLocation = 2
	},

	Cherries = {
		Id = "Cherries",
		DisplayName = "Cherries",
		Tags = { "Fruit", "Sweet", "Red" },
		BlendColor = Color3.fromRGB(190, 35, 55),
		Rarity = "Common",
		JumpLocation = 0,
	},

	Chili_Pepper = {
		Id = "Chili_Pepper",
		DisplayName = "Chili Pepper",
		Tags = { "Veggie", "Spicy", "Red" },
		BlendColor = Color3.fromRGB(215, 45, 35),
		Rarity = "Common",
		JumpLocation = 1
	},

	Coconut = {
		Id = "Coconut",
		DisplayName = "Coconut",
		Tags = { "Fruit", "Sweet", "Tropical" },
		BlendColor = Color3.fromRGB(225, 220, 195),
		Rarity = "Uncommon",
		JumpLocation = 2
	},


	Dragon_Fruit = {
		Id = "Dragon_Fruit",
		DisplayName = "Dragon Fruit",
		Tags = { "Fruit", "Sweet", "Pink" },
		BlendColor = Color3.fromRGB(235, 90, 155),
		Rarity = "Mystery",
		JumpLocation = 3,
	},


	Mushrooms = {
		Id = "Mushrooms",
		DisplayName = "Mushrooms",
		Tags = { "Mushroom", "White" },
		BlendColor = Color3.fromRGB(225, 215, 180),
		Rarity = "Uncommon",
		JumpLocation = 0
	},


	Grapes = {
		Id = "Grapes",
		DisplayName = "Grapes",
		Tags = { "Fruit", "Sweet", "Purple" },
		BlendColor = Color3.fromRGB(125, 65, 170),
		Rarity = "Common",
		JumpLocation = 0,
	},

	Green_Apple = {
		Id = "Green_Apple",
		DisplayName = "Green Apple",
		Tags = { "Fruit", "Sweet", "Healthy", "Green" },
		BlendColor = Color3.fromRGB(130, 190, 65),
		Rarity = "Common",
		JumpLocation = 0,
	},


	Kiwi = {
		Id = "Kiwi",
		DisplayName = "Kiwi",
		Tags = { "Fruit", "Sweet", "Green" },
		BlendColor = Color3.fromRGB(115, 170, 65),
		Rarity = "Common",
		JumpLocation = 0,
	},

	Lemon = {
		Id = "Lemon",
		DisplayName = "Lemon",
		Tags = { "Fruit", "Sour", "Yellow" },
		BlendColor = Color3.fromRGB(245, 225, 65),
		Rarity = "Common",
		JumpLocation = 0,
	},

	Cinnamon = {
		Id = "Cinnamon",
		DisplayName = "Cinnamon",
		Tags = { "Cinnamon", "Brown", "Spice" },
		BlendColor = Color3.fromRGB(150, 100, 50),
		Rarity = "Rare",
		JumpLocation = 3
	},

	Melon = {
		Id = "Melon",
		DisplayName = "Melon",
		Tags = { "Fruit", "Sweet", "Green", "Cloud Garden" },
		BlendColor = Color3.fromRGB(160, 205, 105),
		Rarity = "Rare",
		JumpLocation = 3
	},




	Onion = {
		Id = "Onion",
		DisplayName = "Onion",
		Tags = { "Veggie", "White", "Weird", "Healthy" },
		BlendColor = Color3.fromRGB(220, 205, 170),
		Rarity = "Common",
		JumpLocation = 0,
	},

	Gummy_Bear = {
		Id = "Gummy_Bear",
		DisplayName = "Gummy Bear",
		Tags = { "Candy", "Sweet", "Red" },
		BlendColor = Color3.fromRGB(255, 100, 100),
		Rarity = "Rare",
		JumpLocation = 0,
	},

	Orange = {
		Id = "Orange",
		DisplayName = "Orange",
		Tags = { "Fruit", "Sweet", "Citrus", "Orange" },
		BlendColor = Color3.fromRGB(245, 145, 45),
		Rarity = "Common",
		JumpLocation = 0,
	},

	Peach = {
		Id = "Peach",
		DisplayName = "Peach",
		Tags = { "Fruit", "Sweet", "Pink", "Cloud Garden" },
		BlendColor = Color3.fromRGB(245, 150, 125),
		Rarity = "Rare",
		JumpLocation = 3,
	},

	Pineapple = {
		Id = "Pineapple",
		DisplayName = "Pineapple",
		Tags = { "Fruit", "Sweet", "Yellow" },
		BlendColor = Color3.fromRGB(235, 190, 65),
		Rarity = "Common",
		JumpLocation = 1,
	},

	Squid = {
		Id = "Squid",
		DisplayName = "Squid",
		Tags = { "Seafood", "White", "Weird", "Protein" },
		BlendColor = Color3.fromRGB(200, 200, 200),
		Rarity = "Uncommon",
		JumpLocation = 2,
	},

	Fish = {
		Id = "Fish",
		DisplayName = "Fish",
		Tags = { "Seafood", "Blue", "Weird", "Protein" },
		BlendColor = Color3.fromRGB(25, 164, 223),
		Rarity = "Rare",
		JumpLocation = 2,
	},

	Pomegranate = {
		Id = "Pomegranate",
		DisplayName = "Pomegranate",
		Tags = { "Fruit", "Sweet", "Red" },
		BlendColor = Color3.fromRGB(185, 45, 65),
		Rarity = "Uncommon",
		JumpLocation = 2,
	},

	Potato = {
		Id = "Potato",
		DisplayName = "Potato",
		Tags = { "Vegetable", "Golden", "Cloud Garden" },
		BlendColor = Color3.fromRGB(247, 250, 61),
		Rarity = "Mystery",
		JumpLocation = 3,
	},


	Starfruit = {
		Id = "Starfruit",
		DisplayName = "Starfruit",
		Tags = { "Fruit", "Sweet", "Yellow" },
		BlendColor = Color3.fromRGB(235, 205, 75),
		Rarity = "Uncommon",
		JumpLocation = 1,
	},

	Strawberry = {
		Id = "Strawberry",
		DisplayName = "Strawberry",
		Tags = { "Fruit", "Sweet", "Red" },
		BlendColor = Color3.fromRGB(235, 65, 80),
		Rarity = "Common",
		JumpLocation = 0,
	},

	Tomato = {
		Id = "Tomato",
		DisplayName = "Tomato",
		Tags = { "Fruit", "Golden", "Cloud Garden" },
		BlendColor = Color3.fromRGB(236, 227, 59),
		Rarity = "Mystery",
		JumpLocation = 3,
	},


	Watermelon = {
		Id = "Watermelon",
		DisplayName = "Watermelon",
		Tags = { "Fruit", "Sweet", "Red", "Watermelon" },
		BlendColor = Color3.fromRGB(240, 95, 110),
		Rarity = "Common",
		JumpLocation = 0,
	},

	-- Existing non-pack ingredients

	Ice = {
		Id = "Ice",
		DisplayName = "Ice",
		Tags = { "Cold", "White", "Blue" },
		BlendColor = Color3.fromRGB(190, 235, 255),
		Rarity = "Common",
		JumpLocation = 0,
	},

	Milk = {
		Id = "Milk",
		DisplayName = "Milk",
		Tags = { "Milk", "White" },
		BlendColor = Color3.fromRGB(245, 245, 245),
		Rarity = "Uncommon",
		JumpLocation = 2,
	},


	Tire = {
		Id = "Tire",
		DisplayName = "Tire",
		Tags = { "Black", "Gross", "Weird" },
		BlendColor = Color3.fromRGB(45, 45, 50),
		Rarity = "Uncommon",
		JumpLocation = 1,
	},

	Sushi = {
		Id = "Sushi",
		DisplayName = "Sushi",
		Tags = { "Seafood", "Weird", "Protein", "Black" },
		BlendColor = Color3.fromRGB(200, 200, 200),
		Rarity = "Rare",
		JumpLocation = 2,
	},

	Steak = {
		Id = "Steak",
		DisplayName = "Steak",
		Tags = { "Protein", "Steak" },
		BlendColor = Color3.fromRGB(150, 50, 50),
		Rarity = "Rare",
		JumpLocation = 1,
	},

	Hamburger = {
		Id = "Hamburger",
		DisplayName = "Hamburger",
		Tags = { "Protein", "Weird", "Fast Food" },
		BlendColor = Color3.fromRGB(180, 100, 60),
		Rarity = "Uncommon",
		JumpLocation = 1,
	},

	Noob = {
		Id = "Noob",
		DisplayName = "Noob",
		Tags = { "Weird", "Yellow", "Noob" },
		BlendColor = Color3.fromRGB(245, 210, 55),
		Rarity = "Rare",
		JumpLocation = 3,
	},

	GoldenTomato = {
		Id = "GoldenTomato",
		DisplayName = "Golden Tomato",
		Tags = { "Fruit", "Sweet", "Healthy", "Yellow" },
		BlendColor = Color3.fromRGB(255, 205, 55),
		Rarity = "Rare",
		JumpLocation = 3,
	},

	-- Mystery uses the same deterministic RGB mean as every other unit.
	Mystery = {
		Id = "Mystery",
		DisplayName = "Mystery",
		Tags = { "Weird", "Mystery" },
		BlendColor = Color3.fromRGB(170, 65, 230),
		Rarity = "Mystery",
		JumpLocation = 3,
	},
}

return Ingredients
