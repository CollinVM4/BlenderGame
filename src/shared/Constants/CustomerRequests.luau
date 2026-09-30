--!strict
local Ingredients = require(script.Parent.Ingredients)

export type IngredientRequirement = string | { string }

export type Request = {
    Id: string,
    DisplayText: string,
    DisplayTexts: { string }?,
    RequestGroup: string?,
    SimilarityKeys: { string }?,
    GoodResponse: string?,
    BadResponse: string?,
    RequiredTags: { string }, -- All must match; "*" matches any ingredient tag.
    ForbiddenTags: { string }?, -- None may be present; omitted means empty.
    RequiredIngredients: { IngredientRequirement }?, -- One physical ingredient per slot; tables offer alternatives.
    ForbiddenIngredients: { string }?, -- None of these IDs may be present.
    ExactIngredients: boolean?, -- Require one ingredient per requirement slot, with no extras.
    BasePayout: number,
    MinJumpTier: number,
    NPCOnly: boolean?,
    Wildcard: boolean?, -- Accept any valid smoothie, with neutral successful grading.
}

-- Tag groups match any member and automatically include newly authored ingredient tags.
local allTags: { [string]: boolean } = {}
for _, ingredient in Ingredients do
    for _, tag in ingredient.Tags do
        allTags[string.lower(tag)] = true
    end
end
local tagGroups: { [string]: { [string]: boolean } } = {
    ["*"] = allTags,
}

local requests: { Request } = {
    {
        Id = "Red",
        RequestGroup = "Color",
        SimilarityKeys = { "Red" },

        DisplayTexts = {
            "can you make me a RED smoothie!",
            "I want something super RED!",
            "favorite color's RED. You know what to do!",
            "gimmie a RED smoothie!",
        },

        GoodResponse = "Splendid! It's red!",
        BadResponse = "This isn't red enough!",

        RequiredTags = { "Red" },
        BasePayout = 25,
        MinJumpTier = 0,
    },
    {
        Id = "RedNoApple",
        RequestGroup = "Restriction",
        SimilarityKeys = { "Red", "NoApple" },
        DisplayText = "can you make me a RED smoothie without any APPLE!",
        GoodResponse = "Splendid! It's red!",
        BadResponse = "This isn't red enough!",
        RequiredTags = { "Red" },
        ForbiddenIngredients = { "Apple" },
        BasePayout = 25,
        MinJumpTier = 2,
    },
    {
        Id = "Sweet",
        RequestGroup = "Trait",
        SimilarityKeys = { "Sweet" },
        DisplayTexts = {
            "need to tame my SWEET tooth!",
            "make it SWEET!",
            "I need a sugar rush. Something SWEET!",
            "gimmie something real SWEET!",
        },
        GoodResponse = "Perfectly sweet!",
        BadResponse = "Too bland!",
        RequiredTags = { "Sweet" },
        BasePayout = 25,
        MinJumpTier = 0,
    },
    {
        Id = "Mushroom",
        RequestGroup = "Combo",
        SimilarityKeys = { "Mushrooms", "Fruit" },
        DisplayText = "I want something with MUSHROOMS and FRUIT!",
        GoodResponse = "Thank you!",
        BadResponse = "Where are the mushrooms?",
        RequiredTags = { "Mushroom", "Fruit" },
        BasePayout = 25,
        MinJumpTier = 0,
    },
    {
        Id = "Seafood",
        RequestGroup = "Trait",
        SimilarityKeys = { "Seafood" },
        DisplayTexts = {
            "I need something from the OCEAN!",
            "throw some SEAFOOD in there!",
            "make it taste like the ocean!",
            "gimmie something FISHY!",
        },
        GoodResponse = "MM.. Seafood delight!",
        BadResponse = "This isn't from the ocean!",
        RequiredTags = { "Seafood" },
        BasePayout = 75,
        MinJumpTier = 2,
    },
    {
        Id = "Yellow",
        RequestGroup = "Color",
        SimilarityKeys = { "Yellow" },
        DisplayTexts = {
            "I'll have you know my favorite color is YELLOW!",
            "gimmie the YELLOW stuff!",
            "make it with YELLOW!",
            "YELLOW smoothie. Surprise me!",
        },
        GoodResponse = "Thanks a lot, smoothie master!",
        BadResponse = "This isn't yellow enough!",
        RequiredTags = { "Yellow" },
        BasePayout = 25,
        MinJumpTier = 0,
    },
    {
        Id = "Green",
        RequestGroup = "Color",
        SimilarityKeys = { "Green" },
        DisplayTexts = {
            "I LOVE GREEN!",
            "make it GREEN!",
            "I want something super GREEN.",
            "GREEN. That's all I need.",
            "gimmie the GREEN stuff!",
        },
        GoodResponse = "YAY I LOOOOVEE GREEN!",
        BadResponse = "This isn't green enough!",
        RequiredTags = { "Green" },
        BasePayout = 25,
        MinJumpTier = 0,
    },
    {
        Id = "Cold",
        RequestGroup = "Trait",
        SimilarityKeys = { "Cold" },
        DisplayTexts = {
            "make it ice COLD!",
            "I need something COLD!",
            "freeze my brain. Make it COLD!",
            "gimmie something ICE COLD!",
        },
        GoodResponse = "Yipee cold!",
        BadResponse = "This isn't cold enough!",
        RequiredTags = { "Cold" },
        BasePayout = 25,
        MinJumpTier = 0,
    },
    {
        Id = "Spicy",
        RequestGroup = "Trait",
        SimilarityKeys = { "Spicy" },
        DisplayTexts = {
            "gimmie something with some HEAT!",
            "make it SPICY!",
            "I wanna feel the burn!",
            "make this thing HOT!",
        },
        GoodResponse = "Just the right spice!",
        BadResponse = "Not spicy enough!",
        RequiredTags = { "Spicy" },
        BasePayout = 50,
        MinJumpTier = 1,
    },
    {
        Id = "Protein",
        RequestGroup = "Trait",
        SimilarityKeys = { "Protein" },
        DisplayTexts = {
            ".. PROTEIN!",
            "gains aren't gonna make themselves. PROTEIN!",
            "load it up with PROTEIN!",
            "I need something for the gains!",
        },
        GoodResponse = "Oh yea, this will get me swole!",
        BadResponse = "Where's the protein at bro?",
        RequiredTags = { "Protein" },
        BasePayout = 50,
        MinJumpTier = 1,
    },
    {
        Id = "FastFood",
        RequestGroup = "Trait",
        SimilarityKeys = { "FastFood" },
        DisplayText = "Im craving FAST FOOD!",
        GoodResponse = "Thank you good sir!",
        BadResponse = "I said I wanted FAST FOOD!",
        RequiredTags = { "Fast Food" },
        BasePayout = 25,
        MinJumpTier = 1,
    },
    {
        Id = "Milk",
        RequestGroup = "Trait",
        SimilarityKeys = { "Milk" },
        DisplayTexts = {
            "got MILK!?",
            "I want something MILKY!",
            "pour some MILK in that thing!",
            "make it nice and MILKY!",
        },
        GoodResponse = "Milk is the BEST!",
        BadResponse = "This isn't milky enough!",
        RequiredTags = { "Milk" },
        BasePayout = 50,
        MinJumpTier = 2,
    },
    {
        Id = "Pomegranate",
        RequestGroup = "Ingredient",
        SimilarityKeys = { "Pomegranate" },
        DisplayText = "I'll treat myself to a POMEGRANATE smoothie!",
        GoodResponse = "Ah yes! How delightful",
        BadResponse = "Next time remember the pomegranate!",
        RequiredTags = {},
        RequiredIngredients = { "Pomegranate" },
        BasePayout = 75,
        MinJumpTier = 2,
    },
    {
        Id = "Lemon",
        RequestGroup = "Trait",
        SimilarityKeys = { "Sour" },
        DisplayTexts = {
            "hey boss, its gotta be super SOUR",
            "I want something SOUR enough to hurt!",
            "make my face scrunch up. SOUR!",
            "gimmie the SOUR stuff!",
        },
        GoodResponse = "Oooh so sour!",
        BadResponse = "This isn't sour enough!",
        RequiredTags = { "Sour" },
        BasePayout = 25,
        MinJumpTier = 0,
    },
    {
        Id = "Fruit",
        RequestGroup = "Trait",
        SimilarityKeys = { "Fruit" },
        DisplayTexts = {
            "dr said I need FRUIT, or else I'll get scurvy!",
            "gimmie something FRUITY!",
            "I need some FRUIT in this thing!",
            "make it full of FRUIT!",
        },
        GoodResponse = "Totally saved me!",
        BadResponse = "Guess i'll get scurvy..",
        RequiredTags = { "Fruit" },
        BasePayout = 25,
        MinJumpTier = 0,
    },
    {
        Id = "Watermelon",
        RequestGroup = "Ingredient",
        SimilarityKeys = { "Watermelon" },
        DisplayText = "can you fit a whole WATERMELON in there?",
        GoodResponse = "how'd you do that!",
        BadResponse = "not enough watermelon!",
        RequiredTags = { "Watermelon" },
        BasePayout = 25,
        MinJumpTier = 0,
    },
    {
        Id = "SweetCold",
        RequestGroup = "Combo",
        SimilarityKeys = { "Sweet", "Cold" },
        DisplayText = "gimmie something SWEET and ICE COLD!",
        GoodResponse = "Sweet AND refreshing!",
        BadResponse = "You're missing something!",
        RequiredTags = { "Sweet", "Cold" },
        BasePayout = 50,
        MinJumpTier = 1,
    },
    {
        Id = "RedSpicy",
        GoodResponse = "RED HOT! That's perfect!",
        BadResponse = "I said RED AND SPICY!",
        DisplayTexts = {
            "make it RED with some HEAT!",
            "I want something RED and SPICY!",
            "RED and HOT. Don't disappoint me!",
        },

        RequiredTags = { "Red", "Spicy" },

        BasePayout = 50,
        MinJumpTier = 1,

        RequestGroup = "Combo",
        SimilarityKeys = { "Red", "Spicy" },
    },
    {
        Id = "BlueProtein",
        GoodResponse = "Mmm delicious!",
        BadResponse = "Where's my BLUE PROTEIN smoothie?!",
        DisplayTexts = {
            "make it BLUE and give me some PROTEIN!",
            "BLUE smoothie. Extra Protein.",
        },

        RequiredTags = { "Blue", "Protein" },

        BasePayout = 75,
        MinJumpTier = 1,

        RequestGroup = "Combo",
        SimilarityKeys = { "Blue", "Protein" },
    },
    {
        Id = "WeirdProtein",
        GoodResponse = "Disgusting... but these gains are REAL!",
        BadResponse = "Not weird enough!",
        DisplayTexts = {
            "I need PROTEIN... make it WEIRD.",
            "something WEIRD and packed with PROTEIN!",
            "gimmie the WEIRDEST PROTEIN smoothie you got!",
        },

        RequiredTags = { "Weird", "Protein" },

        BasePayout = 75,
        MinJumpTier = 1,

        RequestGroup = "Combo",
        SimilarityKeys = { "Weird", "Protein" },
    },
    {
        Id = "YellowSweet",
        GoodResponse = "Now THAT'S what I like!",
        BadResponse = "Where's the YELLOW and SWEET stuff?!",
        DisplayTexts = {
            "make it YELLOW and SWEET!",
            "something YELLOW and super SWEET!",
            "I want a SWEET & YELLOW smoothie!",
        },

        RequiredTags = { "Yellow", "Sweet" },

        BasePayout = 50,
        MinJumpTier = 0,

        RequestGroup = "Combo",
        SimilarityKeys = { "Yellow", "Sweet" },
    },
    {
        Id = "SweetSour",
        GoodResponse = "OOH! Sweet AND sour!",
        BadResponse = "This ain't sweet and sour enough!",
        DisplayTexts = {
            "I want it SWEET AND SOUR!",
            "make my taste buds confused. SWEET and SOUR!",
        },

        RequiredTags = { "Sweet", "Sour" },

        BasePayout = 50,
        MinJumpTier = 0,

        RequestGroup = "Combo",
        SimilarityKeys = { "Sweet", "Sour" },
    },
    {
        Id = "GreenSpicy",
        RequestGroup = "Combo",
        SimilarityKeys = { "Green", "Spicy" },
        DisplayText = "make it GREEN with some HEAT!",
        GoodResponse = "That's got a kick!",
        BadResponse = "I said GREEN and SPICY!",
        RequiredTags = { "Green", "Spicy" },
        BasePayout = 50,
        MinJumpTier = 1,
    },
    {
        Id = "SweetNoFruit",
        GoodResponse = "Sweet with NO FRUIT. Nailed it!",
        BadResponse = "I said NO FRUIT!",
        DisplayTexts = {
            "make it SWEET... but NO FRUIT!",
            "I want something SWEET without any FRUIT.",
            "got anything SWEET that isn't FRUIT?",
        },

        RequiredTags = { "Sweet" },
        ForbiddenTags = { "Fruit" },

        BasePayout = 75,
        MinJumpTier = 1,

        RequestGroup = "Restriction",
        SimilarityKeys = { "Sweet", "Fruit" },
    },
    {
        Id = "RedNoFruit",
        RequestGroup = "Restriction",
        SimilarityKeys = { "Red", "NoFruit" },
        DisplayText = "something RED... but NO FRUIT!",
        GoodResponse = "Delicious!",
        BadResponse = "WHY IS THERE FRUIT?!",
        RequiredTags = { "Red" },
        ForbiddenTags = { "Fruit" },
        BasePayout = 75,
        MinJumpTier = 2,
    },
    {
        Id = "ColdNoFruit",
        RequestGroup = "Restriction",
        SimilarityKeys = { "Cold", "NoFruit" },
        DisplayText = "make it COLD and keep the FRUIT out!",
        GoodResponse = "Now that's refreshing!",
        BadResponse = "Is that FRUIT?!",
        RequiredTags = { "Cold" },
        ForbiddenTags = { "Fruit" },
        BasePayout = 75,
        MinJumpTier = 2,
    },
    {
        Id = "WeirdNoSeafood",
        DisplayTexts = {
            "make it WEIRD, but keep the FISH out!",
            "I want something WEIRD with NO SEAFOOD.",
        },

        RequiredTags = { "Weird" },
        ForbiddenTags = { "Seafood" },

        BasePayout = 75,
        MinJumpTier = 2,

        RequestGroup = "Restriction",
        SimilarityKeys = { "Weird", "Seafood" },
    },
    {
        Id = "ProteinNoSeafood",
        GoodResponse = "All gains, no fish. Beautiful.",
        BadResponse = "I said NO SEAFOOD!",
        DisplayTexts = {
            "I need PROTEIN, but NO SEAFOOD!",
            "PROTEIN please just keep the SEAFOOD out of it.",
            "something PROTEIN packed... just nothing from the OCEAN.",
        },

        RequiredTags = { "Protein" },
        ForbiddenTags = { "Seafood" },

        BasePayout = 75,
        MinJumpTier = 1,

        RequestGroup = "Restriction",
        SimilarityKeys = { "Protein", "Seafood" },
    },
    {
        Id = "SweetColdNoSpicy",
        RequestGroup = "Restriction",
        SimilarityKeys = { "Sweet", "Cold", "NoSpicy" },
        DisplayText = "SWEET and COLD... absolutely NO SPICE!",
        GoodResponse = "Exactly what I wanted!",
        BadResponse = "You messed up my order!",
        RequiredTags = { "Sweet", "Cold" },
        ForbiddenTags = { "Spicy" },
        BasePayout = 100,
        MinJumpTier = 3,
    },


    -- Exact / scavenger-hunt requests

    {
        Id = "TireSweet",
        GoodResponse = "Why is this actually kinda good?!",
        BadResponse = "This TIRE isn't sweet enough!",
        DisplayTexts = {
            "throw in a TIRE... make the rest SWEET.",
            "TIRE smoothie. But make it taste SWEET.",
            "I want a TIRE and something SWEET. Don't ask.",
        },

        RequiredTags = { "Sweet" },
        RequiredIngredients = { "Tire" },

        BasePayout = 75,
        MinJumpTier = 1,

        RequestGroup = "Ingredient",
        SimilarityKeys = { "Weird", "Sweet" },
    },
    {
        Id = "MilkPurple",
        DisplayTexts = {
            "MILK and something PURPLE!",
            "throw in MILK and PURPLE!",
        },

        RequiredTags = { "Purple" },
        RequiredIngredients = { "Milk" },

        BasePayout = 100,
        MinJumpTier = 2,

        RequestGroup = "Ingredient",
        SimilarityKeys = { "Milk", "Purple" },
    },
    {
        Id = "AppleBananaIce",
        RequestGroup = "Recipe",
        SimilarityKeys = { "Apple", "Green_Apple", "Banana", "Ice" },
        DisplayText = "APPLE, BANANA, and ICE! Don't mess it up!",
        GoodResponse = "Exactly what I ordered!",
        BadResponse = "That is NOT my recipe!",
        RequiredTags = {},
        RequiredIngredients = { { "Apple", "Green_Apple" }, "Banana", "Ice" } :: { IngredientRequirement },
        ExactIngredients = true,
        BasePayout = 50,
        MinJumpTier = 0,
    },

    {
        Id = "BerryTrio",
        RequestGroup = "Recipe",
        SimilarityKeys = { "Fruit", "Strawberry", "Blueberry", "Cherries" },
        DisplayText = "STRAWBERRY, BLUEBERRY, CHERRIES! it's berry time!",
        GoodResponse = "BERRY good!",
        BadResponse = "You're missing one of my berries!",
        RequiredTags = {},
        RequiredIngredients = { "Strawberry", "Blueberry", "Cherries" },
        ExactIngredients = true,
        BasePayout = 50,
        MinJumpTier = 0,
    },

    {
        Id = "SaladSmoothie",
        RequestGroup = "Recipe",
        SimilarityKeys = { "Cabbage", "Carrot", "Onion" },
        DisplayText = "lemme get CABBAGE, CARROT, and ONION... trust me.",
        GoodResponse = "Tastes healthy enough..",
        BadResponse = "That's not right!",
        RequiredTags = {},
        RequiredIngredients = { "Cabbage", "Carrot", "Onion" },
        ExactIngredients = true,
        BasePayout = 50,
        MinJumpTier = 0,
    },

    {
        Id = "AppleSour",
        RequestGroup = "Combo",
        SimilarityKeys = { "Sour", "Apple" },
        DisplayText = "I need an APPLE and something SOUR!",
        GoodResponse = "Sweet AND sour!",
        BadResponse = "Where's my apple and sour stuff?!",
        RequiredTags = { "Sour" },
        RequiredIngredients = { "Apple" },
        BasePayout = 50,
        MinJumpTier = 0,
    },

    {
        Id = "SpicyPineapple",
        RequestGroup = "Recipe",
        SimilarityKeys = { "Pineapple", "Chili_Pepper", "Ice" },
        DisplayText = "PINEAPPLE, CHILI PEPPER, ICE!",
        GoodResponse = "HOT... COLD... PERFECT!",
        BadResponse = "You ruined it!",
        RequiredTags = {},
        RequiredIngredients = { "Pineapple", "Chili_Pepper", "Ice" },
        ExactIngredients = true,
        BasePayout = 75,
        MinJumpTier = 1,
    },

    {
        Id = "MushroomOnion",
        RequestGroup = "Ingredient",
        SimilarityKeys = { "Mushrooms", "Onion" },
        DisplayText = "MUSHROOMS and ONION! Surprise me with the rest.",
        GoodResponse = "Strangely delicious!",
        BadResponse = "I said MUSHROOMS and ONION!",
        RequiredTags = {},
        RequiredIngredients = { "Mushrooms", "Onion" },
        BasePayout = 75,
        MinJumpTier = 0,
    },

    {
        Id = "JunkFoodDisaster",
        RequestGroup = "Recipe",
        SimilarityKeys = { "Hamburger", "Tire", "Ice" },
        DisplayText = "HAMBURGER, TIRE, and ICE. Don't ask questions.",
        GoodResponse = "That is absolutely horrible. I love it.",
        BadResponse = "Somehow this isn't gross enough!",
        RequiredTags = {},
        RequiredIngredients = { "Hamburger", "Tire", "Ice" },
        ExactIngredients = true,
        BasePayout = 100,
        MinJumpTier = 1,
    },
    {
        Id = "BreakfastDisaster",

        DisplayTexts = {
            "BANANA, MILK, and a WORM. Breakfast of champions!",
            "MILK, BANANA, WORM. Trust the process.",
        },

        RequiredTags = {},
        RequiredIngredients = { "Banana", "Milk", "Worm" },
        ExactIngredients = true,

        GoodResponse = "Breakfast of champions!",
        BadResponse = "I said BANANA, MILK, and a WORM!",

        BasePayout = 100,
        MinJumpTier = 2,

        RequestGroup = "Recipe",
        SimilarityKeys = { "Protein", "Milk" },
    },
    {
        Id = "BeachSmoothie",

        DisplayTexts = {
            "COCONUT, PINEAPPLE, and ICE!",
            "make me something tropical: COCONUT, PINEAPPLE, ICE!",
        },

        RequiredTags = {},
        RequiredIngredients = { "Coconut", "Pineapple", "Ice" },
        ExactIngredients = true,

        GoodResponse = "Tropical and refreshing!",
        BadResponse = "I said COCONUT, PINEAPPLE, and ICE!",

        BasePayout = 100,
        MinJumpTier = 2,

        RequestGroup = "Recipe",
        SimilarityKeys = { "Fruit", "Cold" },
    },

    {
        Id = "SeafoodPlatter",
        RequestGroup = "Recipe",
        SimilarityKeys = { "Seafood", "Fish", "Squid", "Sushi" },
        DisplayText = "FISH, SQUID, and SUSHI! Blend the whole ocean!",
        GoodResponse = "Now THAT'S seafood!",
        BadResponse = "My seafood platter is missing something!",
        RequiredTags = {},
        RequiredIngredients = { "Fish", "Squid", "Sushi" },
        ExactIngredients = true,
        BasePayout = 125,
        MinJumpTier = 2,
    },

    {
        Id = "CrabCoconut",
        RequestGroup = "Ingredient",
        SimilarityKeys = { "Crab", "Coconut" },
        DisplayText = "CRAB and COCONUT! You choose the last ingredient.",
        BadResponse = "Where's my CRAB and COCONUT?!",
        RequiredTags = {},
        RequiredIngredients = { "Crab", "Coconut" },
        BasePayout = 100,
        MinJumpTier = 2,
    },

    {
        Id = "FancyFruitShake",
        RequestGroup = "Recipe",
        SimilarityKeys = { "Pomegranate", "Coconut", "Milk" },
        DisplayText = "POMEGRANATE, COCONUT, and MILK. Make it fancy!",
        GoodResponse = "Ahhh... exquisite!",
        BadResponse = "This is NOT what I ordered!",
        RequiredTags = {},
        RequiredIngredients = { "Pomegranate", "Coconut", "Milk" },
        ExactIngredients = true,
        BasePayout = 125,
        MinJumpTier = 2,
    },

    {
        Id = "CloudFruitSalad",
        RequestGroup = "Recipe",
        SimilarityKeys = { "Fruit", "Peach", "Melon", "Starfruit" },
        DisplayText = "PEACH, MELON, STARFRUIT! Straight from the CLOUDS!",
        GoodResponse = "Heavenly!",
        BadResponse = "Those aren't my cloud fruits!",
        RequiredTags = {},
        RequiredIngredients = { "Peach", "Melon", "Starfruit" },
        ExactIngredients = true,
        BasePayout = 175,
        MinJumpTier = 3,
    },

    {
        Id = "DragonSpice",
        RequestGroup = "Ingredient",
        SimilarityKeys = { "Dragon_Fruit", "Cinnamon" },
        DisplayText = "DRAGON FRUIT and CINNAMON! Pick the last ingredient.",
        GoodResponse = "Now THAT is exotic!",
        BadResponse = "Where's the DRAGON FRUIT and CINNAMON?!",
        RequiredTags = {},
        RequiredIngredients = { "Dragon_Fruit", "Cinnamon" },
        BasePayout = 150,
        MinJumpTier = 3,
    },

    {
        Id = "GoldenCloud",
        RequestGroup = "Recipe",
        SimilarityKeys = { "Potato", "GoldenTomato", "Tomato" },
        DisplayText = "POTATO, GOLDEN TOMATO, and TOMATO! Golden everything!",
        GoodResponse = "It's beautiful... probably.",
        BadResponse = "This isn't golden enough!",
        RequiredTags = {},
        RequiredIngredients = { "Potato", "GoldenTomato", "Tomato" },
        ExactIngredients = true,
        BasePayout = 200,
        MinJumpTier = 3,
    },

    {
        Id = "MysteryDisaster",
        RequestGroup = "Recipe",
        SimilarityKeys = { "Mystery", "Noob", "Tire" },
        DisplayText = "MYSTERY, NOOB, and a TIRE. I know what I'm doing.",
        GoodResponse = "...I have made a terrible decision.",
        BadResponse = "Nope. Needs to be WAY weirder.",
        RequiredTags = {},
        RequiredIngredients = { "Mystery", "Noob", "Tire" },
        ExactIngredients = true,
        BasePayout = 200,
        MinJumpTier = 3,
    },
}
table.insert(requests, {
    Id = "Steak",
    DisplayText = "You know who I am .. Now get on it!",
    GoodResponse = "Oh yea! this will do.",
    BadResponse = "NEVER AGAIN!",
    RequiredTags = { "Steak" },
    BasePayout = 105,
    MinJumpTier = 1,
    NPCOnly = true,
})
table.insert(requests, {
    Id = "Blueman",
    DisplayText = "obviosuly I NEED a BLUE smoothie!",
    GoodResponse = "Beautifully blue!",
    BadResponse = "It isn't blue enough..",
    RequiredTags = { "Blue" },
    BasePayout = 105,
    MinJumpTier = 0,
    NPCOnly = true,
})
table.insert(requests, {
    Id = "Jynxzi",
    DisplayText = "Bazalright.. I always need MILK before bed!",
    GoodResponse = "SCHWEEEET!",
    BadResponse = "HIIIIVISEEEE GET ME A DIFFERENT SMOOTHIE!",
    RequiredTags = { "Milk" },
    BasePayout = 105,
    MinJumpTier = 2,
    NPCOnly = true,
})
table.insert(requests, {
    Id = "Caseoh",
    DisplayText = "whats good cuh. you know I'm bout that PROTEIN action",
    GoodResponse = "You're safe this time buster.",
    BadResponse = "Don't cross me again simpleton",
    RequiredTags = { "Protein" },
    BasePayout = 105,
    MinJumpTier = 1,
    NPCOnly = true,
})
table.insert(requests, {
    Id = "Brooke",
    DisplayText = "LET ME TELL YOU SOMTHING..! I want it RED!",
    GoodResponse = "Thanks, Daffodil!",
    BadResponse = "This isnt what I asked for!",
    RequiredTags = { "Red" },
    BasePayout = 105,
    MinJumpTier = 0,
    NPCOnly = true,
})
table.insert(requests, {
    Id = "Verity",
    DisplayText = "LET ME TELL YOU SOMTHING..! I want it RED!",
    GoodResponse = "Thanks, Daffodil!",
    BadResponse = "This isnt what I asked for!",
    RequiredTags = { "Red" },
    BasePayout = 105,
    MinJumpTier = 0,
    NPCOnly = true,
})
table.insert(requests, {
    Id = "Prankster",
    DisplayText = "giving this to my homie as a prank.. make it WEIRD!!",
    GoodResponse = "hehe, this will do the trick!",
    BadResponse = "what the heck man, this won't work.",
    RequiredTags = { "Weird" },
    BasePayout = 105,
    MinJumpTier = 1,
    NPCOnly = true,
})
table.insert(requests, {
    Id = "Pirate",
    DisplayText = "ARRR! I be wantin' a FISH smoothie!",
    GoodResponse = "ARRR KNEW YOU'D GET IT DONE..!",
    BadResponse = "ARRR! You landlubbers never listen!",
    RequiredTags = { "Seafood" },
    BasePayout = 105,
    MinJumpTier = 2,
    NPCOnly = true,
})
table.insert(requests, {
    Id = "Walter",
    DisplayText = "I am the one who KNOCKS!! Now get me a BLUE smoothie!",
    GoodResponse = "Ha! You're hired kid. meet a los pollos 4 o'clock",
    BadResponse = "you've got more work to do.. Not Impressed!",
    RequiredTags = { "Blue" },
    BasePayout = 105,
    MinJumpTier = 1,
    NPCOnly = true,
})
table.insert(requests, {
    Id = "TotallyNotKreek",
    DisplayText = "Alright... make me something RED, and throw in FAST FOOD!",
    GoodResponse = "Okayyy, you actually cooked!",
    BadResponse = "Bro... I said RED AND FAST FOOD. We gotta lock in!",
    RequiredTags = { "Red", "Fast Food" },
    BasePayout = 105,
    MinJumpTier = 1,
    NPCOnly = true,
})
table.insert(requests, {
    Id = "DefinitelyNotCaylus",
    DisplayText = "Make me the CRAZIEST smoothie possible. I want something WEIRD and SPICY!",
    GoodResponse = "Okay... that's actually insane.",
    BadResponse = "Nahhh, that wasn't crazy enough!",
    RequiredTags = { "Weird", "Spicy" },
    BasePayout = 105,
    MinJumpTier = 1,
    NPCOnly = true,
})
table.insert(requests, {
    Id = "NotFlamingo",
    DisplayText = "I want something with Fish... and absolutely NO FRUIT.",
    GoodResponse = "Excellent. This should not exist.",
    BadResponse = "Too normal. I expected worse.",
    RequiredTags = { "Seafood" },
    ForbiddenTags = { "Fruit" },
    BasePayout = 125,
    MinJumpTier = 2,
    NPCOnly = true,
})
table.insert(requests, {
    Id = "FoltynMaybe",
    DisplayText = "Gimme something SWEET and COLD. Don't sell.",
    GoodResponse = "W smoothie.",
    BadResponse = "Nah bro, we're running that back.",
    RequiredTags = { "Sweet", "Cold" },
    BasePayout = 105,
    MinJumpTier = 0,
    NPCOnly = true,
})
table.insert(requests, {
    Id = "TotallyNotSketch",
    DisplayText = "Okay buddy... something BLUE and SOUR. Easy enough, right?",
    GoodResponse = "Beautiful. Absolutely beautiful.",
    BadResponse = "Yeahhh... that ain't it.",
    RequiredTags = { "Blue", "Sour" },
    BasePayout = 105,
    MinJumpTier = 0,
    NPCOnly = true,
})
table.insert(requests, {
    Id = "NotFunneh",
    DisplayText = "Can I get something Red and ICE COLD?",
    GoodResponse = "Okayyy, this is actually really good!",
    BadResponse = "Nooo! You forgot something!",
    RequiredTags = { "Red", "Cold" },
    BasePayout = 105,
    MinJumpTier = 0,
    NPCOnly = true,
})
table.insert(requests, {
    Id = "ProbablyNotRusso",
    DisplayText = "I need something expensive-looking. Surprise me.",
    GoodResponse = "Okay definitely worth the Robux.",
    BadResponse = "I spent WHAT on this?!",
    RequiredTags = { "*" },
    BasePayout = 105,
    MinJumpTier = 0,
    NPCOnly = true,
})
table.insert(requests, {
    Id = "Nathan",
    DisplayText = "Fill me up! Anything will do.",
    GoodResponse = "This will definitely fill me up! ",
    BadResponse = "I can't do nathan with this..",
    RequiredTags = { "*" },
    BasePayout = 105,
    MinJumpTier = 0,
    NPCOnly = true,
})
table.insert(requests, {
    Id = "Capybara",
    DisplayText = "HEY! I want CARROT, MANGO, and SPICY",
    GoodResponse = "tasty!",
    BadResponse = "Not quite what I had in mind.",
    RequiredIngredients = { "Carrot", "Mango" },
    RequiredTags = { "Spicy" },
    BasePayout = 110,
    MinJumpTier = 2,
    NPCOnly = true,
})

local CustomerRequests = {
    Definitions = requests,
    TagGroups = tagGroups,

    RegularWildcardChance = 0.70,
    SpecialWildcardChance = 0.30,
    -- Assigned separately so wildcard never enters the specific-request variety pool.
    WildcardRequest = {
        Id = "Wildcard",
        Wildcard = true,
        DisplayText = "Surprise me!",
        DisplayTexts = {
            "Surprise me!",
            "make me whatever!",
            "I'll try anything!",
            "Your choice!",
            "just blend me something!",
            "you pick. I trust the smoothie master!",
            "Throw whatever you want in there!",
        },
        GoodResponse = "Now THAT'S a smoothie! Thanks!",
        BadResponse = "I still wanted a smoothie!",
        RequiredTags = {},
        BasePayout = 25,
        MinJumpTier = 0,
    } :: Request,

    SpecialCustomerChance = 0.55,
    -- Continuous special cooldown is configured in Economy.SpecialCustomerCooldownSeconds.
    RegularCustomerRecencyWindow = 3,
    RegularRequestRecencyWindow = 3,
    RegularRequestGroupRecencyWindow = 2,
    RegularRequestSimilarityRecencyWindow = 2,

    NPCs = {
        steak = {
            Type = "Special",
            DisplayName = "Steak",
            RequestId = "Steak",
            Weight = 0.8,
        },
        blueman = {
            Type = "Special",
            DisplayName = "Bluey",
            RequestId = "Blueman",
            Weight = 1,
        },
        prankster = {
            Type = "Special",
            DisplayName = "Edgar",
            RequestId = "Prankster",
            Weight = 0.9,
        },
        pirate = {
            Type = "Special",
            DisplayName = "Pirate",
            RequestId = "Pirate",
            Weight = 0.9,
        },
        caseoh = {
            Type = "Special",
            DisplayName = "dookieman12",
            RequestId = "Caseoh",
            Weight = 1,
        },
        walter = {
            Type = "Special",
            DisplayName = "Walter White",
            RequestId = "Walter",
            Weight = 0.8,
        },
        jynxzi = {
            Type = "Special",
            DisplayName = "Junko",
            RequestId = "Jynxzi",
            Weight = 1,
        },
        kreek = {
            Type = "Special",
            DisplayName = "TotallyNotKreek",
            RequestId = "TotallyNotKreek",
            Weight = 0.7,
        },
        caylus = {
            Type = "Special",
            DisplayName = "DefinitelyNotCaylus",
            RequestId = "DefinitelyNotCaylus",
            Weight = 0.7,
        },
        flamingo = {
            Type = "Special",
            DisplayName = "NotFlamingo",
            RequestId = "NotFlamingo",
            Weight = 0,
        },
        foltyn = {
            Type = "Special",
            DisplayName = "FoltynMaybe",
            RequestId = "FoltynMaybe",
            Weight = 0.7,
        },
        sketch = {
            Type = "Special",
            DisplayName = "TotallyNotSketch",
            RequestId = "TotallyNotSketch",
            Weight = 0.7,
        },
        funneh = {
            Type = "Special",
            DisplayName = "NotFunneh",
            RequestId = "NotFunneh",
            Weight = 0.7,
        },
        russo = {
            Type = "Special",
            DisplayName = "ProbablyNotRusso",
            RequestId = "ProbablyNotRusso",
            Weight = 0.7,
        },
        nathan = {
            Type = "Special",
            DisplayName = "Bigroll",
            RequestId = "Nathan",
            Weight = 1,
        },
        jeremy = {
            Type = "Special",
            DisplayName = "Capybara",
            RequestId = "Capybara",
            Weight = 0.9,
        },
    } :: {
        [string]: {
            Type: string?,
            DisplayName: string?,
            RequestId: string?,
            Weight: number?,
        },
    },
}

-- IDs are case-sensitive. Model names and usernames never act as gameplay IDs.
function CustomerRequests.NormalizeCustomerId(value: any): string?
    if type(value) ~= "string" then
        return nil
    end
    local trimmed = string.match(value, "^%s*(.-)%s*$")
    return if trimmed == "" then nil else trimmed
end

-- Selection must check the returned definition's MinJumpTier before spawning.
function CustomerRequests.GetForNPC(customerId: string?): (Request?, string?)
    local id = CustomerRequests.NormalizeCustomerId(customerId)
    local mapping = if id then CustomerRequests.NPCs[id] else nil
    if not mapping or not mapping.RequestId then
        return nil, nil
    end
    for _, request in CustomerRequests.Definitions do
        if request.Id == mapping.RequestId then
            return request, nil
        end
    end
    return nil, "Unknown NPC RequestId: " .. tostring(mapping.RequestId)
end

return CustomerRequests
