--!strict
export type Request = {
    Id: string,
    DisplayText: string,
    RequiredTags: { string },
    BasePayout: number,
    MinJumpTier: number,
}

-- Every required tag must occur in at least one ingredient; extra ingredients are allowed.
-- Add { "Red", "Sweet" } to require both, even across different ingredients.
-- MinJumpTier is the earliest area tier supplying all required tags (0 = starting area).
-- TODO: Set Seafood/Cold to their authored area tiers; 3 is a conservative placeholder.
local requests: { Request } = {
    {
        Id = "Red", 
        DisplayText = "I want a RED smoothie!",
        RequiredTags = { "Red" },
        BasePayout = 25,
        MinJumpTier = 0,
    },
    {
        Id = "Sweet",
        DisplayText = "I want something SWEET!",
        RequiredTags = { "Sweet" },
        BasePayout = 25,
        MinJumpTier = 0,
    },
    {
        Id = "Mushroom",
        DisplayText = "I want something with MUSHROOMS!",
        RequiredTags = { "Mushroom" },
        BasePayout = 25,
        MinJumpTier = 0,
    },
    {
        Id = "Seafood",
        DisplayText = "need something from the OCEAN!",
        RequiredTags = { "Seafood" },
        BasePayout = 75,
        MinJumpTier = 2,
    },
    {
        Id = "Veggie",
        DisplayText = "I want something with VEGGIES!",
        RequiredTags = { "Veggie" },
        BasePayout = 25,
        MinJumpTier = 0,
    },
    {
        Id = "Weird",
        DisplayText = "giving this to my homie as a prank.. make it WEIRD!",
        RequiredTags = { "Weird" },
        BasePayout = 25,
        MinJumpTier = 1,
    },
    {
        Id = "Yellow",
        DisplayText = "my favorite color is YELLOW!",
        RequiredTags = { "Yellow" },
        BasePayout = 25,
        MinJumpTier = 0,
    },
    {
        Id = "White",
        DisplayText = "can I get a WHITE smoothie!",
        RequiredTags = { "White" },
        BasePayout = 25,
        MinJumpTier = 2,
    },
    {
        Id = "Blue",
        DisplayText = "my favorite color is BLUE!",
        RequiredTags = { "Blue" },
        BasePayout = 25,
        MinJumpTier = 0,
    },
    {
        Id = "Purple",
        DisplayText = "my favorite color is PURPLE!",
        RequiredTags = { "Purple" },
        BasePayout = 25,
        MinJumpTier = 0,
    },
    {
        Id = "Green",
        DisplayText = "my favorite color is GREEN!",
        RequiredTags = { "Green" },
        BasePayout = 25,
        MinJumpTier = 0,
    },
    {
        Id = "Cold",
        DisplayText = "make it COLD!",
        RequiredTags = { "Cold" },
        BasePayout = 25,
        MinJumpTier = 0,
    },
    {
        Id = "Spicy",
        DisplayText = "gimmie something with some HEAT!",
        RequiredTags = { "Spicy" },
        BasePayout = 25,
        MinJumpTier = 1,
    },
    {
        Id = "Protein",
        DisplayText = ".. PROTEIN!",
        RequiredTags = { "Protein" },
        BasePayout = 25,
        MinJumpTier = 1,
    },
    {
        Id = "FastFood",
        DisplayText = "Im craving FAST FOOD!",
        RequiredTags = { "Fast Food" },
        BasePayout = 25,
        MinJumpTier = 1,
    },
    {
        Id = "Milk",
        DisplayText = "got MILK!?",
        RequiredTags = { "Milk" },
        BasePayout = 50,
        MinJumpTier = 2,
    }
}
return requests
