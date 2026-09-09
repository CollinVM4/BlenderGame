--!strict
export type Request = {
    Id: string,
    DisplayText: string,
    RequiredTags: { string },
    BasePayout: number,
}

-- Every required tag must occur in at least one ingredient; extra ingredients are allowed.
-- Add { "Red", "Sweet" } to require both, even across different ingredients.
local requests: { Request } = {
    { Id = "Red", DisplayText = "I want something RED!", RequiredTags = { "Red" }, BasePayout = 25 },
    { Id = "Sweet", DisplayText = "I want something SWEET!", RequiredTags = { "Sweet" }, BasePayout = 25 },
    { Id = "Cold", DisplayText = "I want something COLD!", RequiredTags = { "Cold" }, BasePayout = 25 },
}
return requests
