--!strict
export type Request = {
    Id: string,
    DisplayText: string,
    GoodResponse: string?,
    BadResponse: string?,
    RequiredTags: { string }, -- All must be present across the smoothie's ingredient tags.
    ForbiddenTags: { string }?, -- None may be present; omitted means empty.
    RequiredIngredients: { string }?, -- All IDs must be present; duplicates require matching quantities.
    ForbiddenIngredients: { string }?, -- None of these IDs may be present.
    ExactIngredients: boolean?, -- Require exactly the RequiredIngredients multiset.
    BasePayout: number,
    MinJumpTier: number,
    NPCOnly: boolean?,
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
        GoodResponse = "Gotta love yellow!",
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
    DisplayText = "Bazalright.. need MILK to sleep before bed!",
    GoodResponse = "wait, it's clocking sisters..!",
    BadResponse = "HIIIIVISEEEE GET ME OUTT OF HERE!",
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
    DisplayText = "You know the business, and I know the chemistry.. get me a BLUE smoothie!",
    GoodResponse = "Ha! You're hired kid. meet a los pollos 4 o'clock",
    BadResponse = "you've got more work to do.. Not Impressed!",
    RequiredTags = { "Blue" },
    BasePayout = 105,
    MinJumpTier = 1,
    NPCOnly = true,
})

local CustomerRequests = {
    Definitions = requests,

    SpecialCustomerChance = 0.32,
    MaxSpecialCustomersPerDay = 1,
    RegularCustomerRecencyWindow = 3,
    RegularRequestRecencyWindow = 3,

    NPCs = {
        steak = {
            Type = "Special",
            DisplayName = "Steak",
            RequestId = "Steak",
            Weight = 1,
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
            Weight = 1,
        },

        pirate = {
            Type = "Special",
            DisplayName = "Pirate",
            RequestId = "Pirate",
            Weight = 1,
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
            Weight = 1,
        },
        jynxzi = {
            Type = "Special",
            DisplayName = "Junko",
            RequestId = "Jynxzi",
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
