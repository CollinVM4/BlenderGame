--!strict
local Ingredients = require(script.Parent.Ingredients)

export type IngredientRequirement = string | { string }

export type Request = {
    Id: string,
    DisplayText: string,
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
        DisplayText = "can you make a RED smoothie!",
        GoodResponse = "Splendid! It's red!",
        BadResponse = "This isn't red enough!",
        RequiredTags = { "Red" },
        BasePayout = 25,
        MinJumpTier = 0,
    },
    {
        Id = "Sweet",
        DisplayText = "need to tame my SWEET tooth!",
        GoodResponse = "Perfectly sweet!",
        BadResponse = "Too bland!",
        RequiredTags = { "Sweet" },
        BasePayout = 25,
        MinJumpTier = 0,
    },
    {
        Id = "Mushroom",
        DisplayText = "I want something with MUSHROOMS!",
        GoodResponse = "Thank you!",
        BadResponse = "Where are the mushrooms?",
        RequiredTags = { "Mushroom" },
        BasePayout = 25,
        MinJumpTier = 0,
    },
    {
        Id = "Seafood",
        DisplayText = "I need something from the OCEAN!",
        GoodResponse = "MM.. Seafood delight!",
        BadResponse = "This isn't from the ocean!",
        RequiredTags = { "Seafood" },
        BasePayout = 75,
        MinJumpTier = 2,
    },
    {
        Id = "Veggie",
        DisplayText = "my new years resolution is to eat VEGGIES!",
        GoodResponse = "I LOVE VEGGIES!",
        BadResponse = "Not enough veggies!",
        RequiredTags = { "Veggie" },
        BasePayout = 25,
        MinJumpTier = 0,
    },
    {
        Id = "Yellow",
        DisplayText = "I'll have you know my favorite color is YELLOW!",
        GoodResponse = "Thanks a lot, smoothie master!",
        BadResponse = "This isn't yellow enough!",
        RequiredTags = { "Yellow" },
        BasePayout = 25,
        MinJumpTier = 0,
    },
    {
        Id = "Purple",
        DisplayText = "can't get enough PURPLE in my life!",
        GoodResponse = "YESS PURPLE!",
        BadResponse = "This isn't purple enough!",
        RequiredTags = { "Purple" },
        BasePayout = 25,
        MinJumpTier = 0,
    },
    {
        Id = "Green",
        DisplayText = "I LOVE GREEN!",
        GoodResponse = "YAY I LOOOOVEE GREEN!",
        BadResponse = "This isn't green enough!",
        RequiredTags = { "Green" },
        BasePayout = 25,
        MinJumpTier = 0,
    },
    {
        Id = "Cold",
        DisplayText = "make it ice COLD!",
        GoodResponse = "Yipee cold!",
        BadResponse = "This isn't cold enough!",
        RequiredTags = { "Cold" },
        BasePayout = 25,
        MinJumpTier = 0,
    },
    {
        Id = "Spicy",
        DisplayText = "gimmie something with some HEAT!",
        GoodResponse = "Just the right spice!",
        BadResponse = "Not spicy enough!",
        RequiredTags = { "Spicy" },
        BasePayout = 50,
        MinJumpTier = 1,
    },
    {
        Id = "Protein",
        DisplayText = ".. PROTEIN!",
        GoodResponse = "Oh yea, this will get me swole!",
        BadResponse = "Where's the protein at bro?",
        RequiredTags = { "Protein" },
        BasePayout = 50,
        MinJumpTier = 1,
    },
    {
        Id = "FastFood",
        DisplayText = "Im craving FAST FOOD!",
        GoodResponse = "Thank you good sir!",
        BadResponse = "I said I wanted FAST FOOD!",
        RequiredTags = { "Fast Food" },
        BasePayout = 25,
        MinJumpTier = 1,
    },
    {
        Id = "Milk",
        DisplayText = "got MILK!?",
        GoodResponse = "Milk is the BEST!",
        BadResponse = "This isn't milky enough!",
        RequiredTags = { "Milk" },
        BasePayout = 50,
        MinJumpTier = 2,
    },
    {
        Id = "Pomegranate",
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
        DisplayText = "hey boss, its gotta be super SOUR",
        GoodResponse = "Oooh so sour!",
        BadResponse = "This isn't sour enough!",
        RequiredTags = { "Sour" },
        BasePayout = 25,
        MinJumpTier = 0,
    },
    {
        Id = "Fruit",
        DisplayText = "dr said I need FRUIT, or else I'll get scurvy!",
        GoodResponse = "Totally saved me!",
        BadResponse = "Guess i'll get scurvy..",
        RequiredTags = { "Fruit" },
        BasePayout = 25,
        MinJumpTier = 0,
    },
    {
        Id = "Watermelon",
        DisplayText = "can you fit a whole WATERMELON in there?",
        GoodResponse = "Watermelon wonder!",
        BadResponse = "not enough watermelon!",
        RequiredTags = { "Watermelon" },
        BasePayout = 25,
        MinJumpTier = 0,
    },
    {
        Id = "SweetCold",
        DisplayText = "gimmie something SWEET and ICE COLD!",
        GoodResponse = "Sweet AND refreshing!",
        BadResponse = "You're missing something!",
        RequiredTags = { "Sweet", "Cold" },
        BasePayout = 50,
        MinJumpTier = 1,
    },
    {
        Id = "FruitProtein",
        DisplayText = "FRUIT and PROTEIN. gotta get those gains!",
        GoodResponse = "Thanks my brotha",
        BadResponse = "Where's the good stuff?!",
        RequiredTags = { "Fruit", "Protein" },
        BasePayout = 50,
        MinJumpTier = 1,
    },
    {
        Id = "GreenSpicy",
        DisplayText = "make it GREEN with some HEAT!",
        GoodResponse = "That's got a kick!",
        BadResponse = "I said GREEN and SPICY!",
        RequiredTags = { "Green", "Spicy" },
        BasePayout = 50,
        MinJumpTier = 1,
    },
    {
        Id = "RedNoFruit",
        DisplayText = "something RED... but NO FRUIT!",
        GoodResponse = "Delicious!",
        BadResponse = "WHY IS THERE FRUIT?!",
        RequiredTags = { "Red" },
        ForbiddenTags = { "Fruit" },
        BasePayout = 75,
        MinJumpTier = 2,
    },
    {
        Id = "FruitNoMilk",
        DisplayText = "I want FRUIT but NO MILK!",
        GoodResponse = "Perfect!",
        BadResponse = "I said NO MILK!",
        RequiredTags = { "Fruit" },
        ForbiddenTags = { "Milk" },
        BasePayout = 75,
        MinJumpTier = 2,
    },
    {
        Id = "ColdNoFruit",
        DisplayText = "make it COLD and keep the FRUIT out!",
        GoodResponse = "Now that's refreshing!",
        BadResponse = "Is that FRUIT?!",
        RequiredTags = { "Cold" },
        ForbiddenTags = { "Fruit" },
        BasePayout = 75,
        MinJumpTier = 2,
    },
    {
        Id = "SweetColdNoSpicy",
        DisplayText = "SWEET and COLD... absolutely NO SPICE!",
        GoodResponse = "Exactly what I wanted!",
        BadResponse = "You messed up my order!",
        RequiredTags = { "Sweet", "Cold" },
        ForbiddenTags = { "Spicy" },
        BasePayout = 100,
        MinJumpTier = 3,
    },
    {
        Id = "FruitGreenNoMilk",
        DisplayText = "FRUITY and GREEN, but NO MILK!",
        GoodResponse = "Now THAT'S a green smoothie!",
        BadResponse = "I said NO MILK!",
        RequiredTags = { "Fruit", "Green" },
        ForbiddenTags = { "Milk" },
        BasePayout = 100,
        MinJumpTier = 3,
    },

    -- Exact / scavenger-hunt requests

    {
        Id = "AppleBananaIce",
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
        DisplayText = "STRAWBERRY, BLUEBERRY, CHERRIES! Berry time!",
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
        DisplayText = "CABBAGE, CARROT, and ONION... trust me.",
        GoodResponse = "Tastes healthy enough!",
        BadResponse = "That's not my salad smoothie!",
        RequiredTags = {},
        RequiredIngredients = { "Cabbage", "Carrot", "Onion" },
        ExactIngredients = true,
        BasePayout = 50,
        MinJumpTier = 0,
    },

    {
        Id = "AppleSour",
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
        DisplayText = "MUSHROOMS and ONION! Surprise me with the rest.",
        GoodResponse = "Strangely delicious!",
        BadResponse = "I said MUSHROOMS and ONION!",
        RequiredTags = {},
        RequiredIngredients = { "Mushrooms", "Onion" },
        BasePayout = 75,
        MinJumpTier = 1,
    },

    {
        Id = "JunkFoodDisaster",
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
        Id = "SeafoodPlatter",
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
        DisplayText = "CRAB and COCONUT! You choose the last ingredient.",
        GoodResponse = "Tropical seafood... somehow it works!",
        BadResponse = "Where's my CRAB and COCONUT?!",
        RequiredTags = {},
        RequiredIngredients = { "Crab", "Coconut" },
        BasePayout = 100,
        MinJumpTier = 2,
    },

    {
        Id = "FancyFruitShake",
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
    DisplayText = "Bazalright.. this kitten needs MILK to sleep before bed!",
    GoodResponse = "wait, it's clocking sisters..!",
    BadResponse = "HIIIIVISEEEE GET A DIFFERENT SMOOTHIE!",
    RequiredTags = { "Milk" },
    BasePayout = 105,
    MinJumpTier = 2,
    NPCOnly = true,
})
table.insert(requests, {
    Id = "Caseoh",
    DisplayText = "whats good cuh. you know i'm bout that PROTEIN action",
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
    DisplayText = "Make me the CRAZIEST smoothie possible. I want something WEIRD and SWEET!",
    GoodResponse = "Okay... that's actually insane.",
    BadResponse = "Nahhh, that wasn't crazy enough!",
    RequiredTags = { "Weird", "Sweet" },
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
    MinJumpTier = 1,
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
    DisplayText = "Okay buddy... something YELLOW and SOUR. Easy enough, right?",
    GoodResponse = "Beautiful. Absolutely beautiful.",
    BadResponse = "Yeahhh... that ain't it.",
    RequiredTags = { "Yellow", "Sour" },
    BasePayout = 105,
    MinJumpTier = 0,
    NPCOnly = true,
})
table.insert(requests, {
    Id = "NotFunneh",
    DisplayText = "Can I get something PURPLE and ICE COLD?",
    GoodResponse = "Okayyy, this is actually really good!",
    BadResponse = "Nooo! You forgot something!",
    RequiredTags = { "Purple", "Cold" },
    BasePayout = 105,
    MinJumpTier = 0,
    NPCOnly = true,
})
table.insert(requests, {
    Id = "ProbablyNotRusso",
    DisplayText = "I need something BLUE and expensive-looking. Surprise me.",
    GoodResponse = "Okay definitely worth the Robux.",
    BadResponse = "I spent WHAT on this?!",
    RequiredTags = { "Blue" },
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

local CustomerRequests = {
    Definitions = requests,
    TagGroups = tagGroups,

    SpecialCustomerChance = 1,
    -- Continuous special cooldown is configured in Economy.SpecialCustomerCooldownSeconds.
    RegularCustomerRecencyWindow = 3,
    RegularRequestRecencyWindow = 3,

    NPCs = {
        steak = {
            Type = "Special",
            DisplayName = "Steak",
            RequestId = "Steak",
            Weight = 0,
        },
        blueman = {
            Type = "Special",
            DisplayName = "Bluey",
            RequestId = "Blueman",
            Weight = 0,
        },
        prankster = {
            Type = "Special",
            DisplayName = "Edgar",
            RequestId = "Prankster",
            Weight = 0,
        },
        pirate = {
            Type = "Special",
            DisplayName = "Pirate",
            RequestId = "Pirate",
            Weight = 0,
        },
        caseoh = {
            Type = "Special",
            DisplayName = "dookieman12",
            RequestId = "Caseoh",
            Weight = 0,
        },
        walter = {
            Type = "Special",
            DisplayName = "Walter White",
            RequestId = "Walter",
            Weight = 0,
        },
        jynxzi = {
            Type = "Special",
            DisplayName = "Junko",
            RequestId = "Jynxzi",
            Weight = 0,
        },
        kreek = {
            Type = "Special",
            DisplayName = "TotallyNotKreek",
            RequestId = "TotallyNotKreek",
            Weight = 0,
        },
        caylus = {
            Type = "Special",
            DisplayName = "DefinitelyNotCaylus",
            RequestId = "DefinitelyNotCaylus",
            Weight = 0,
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
            Weight = 0,
        },
        sketch = {
            Type = "Special",
            DisplayName = "TotallyNotSketch",
            RequestId = "TotallyNotSketch",
            Weight = 0,
        },
        funneh = {
            Type = "Special",
            DisplayName = "NotFunneh",
            RequestId = "NotFunneh",
            Weight = 0,
        },
        russo = {
            Type = "Special",
            DisplayName = "ProbablyNotRusso",
            RequestId = "ProbablyNotRusso",
            Weight = 0,
        },
        nathan = {
            Type = "Special",
            DisplayName = "Bigroll",
            RequestId = "Nathan",
            Weight = 1,
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
