--!strict
-- First-order stash contract shared with feature/starter-stash.
-- Legacy extra stash groups remain here until that branch owns seeding; queue
-- positions and payouts after customer one are defined only in IntroCustomers.
type Order = { RequestId: string, Slot: number, Ingredients: { string }, Arrival: number, PayoutFloor: number? }
local orders: { Order } = {
    {
        RequestId = "Red",
        Slot = 1,
        Ingredients = { "Apple", "Cherries", "Strawberry" },
        Arrival = 0,
        PayoutFloor = 30000,
    },
    { RequestId = "Cold", Slot = 3, Ingredients = { "Ice", "Ice", "Ice" }, Arrival = 8, PayoutFloor = 20000 },
    { RequestId = "Yellow", Slot = 2, Ingredients = { "Banana", "Lemon", "Pear" }, Arrival = 16 },
}

return orders
