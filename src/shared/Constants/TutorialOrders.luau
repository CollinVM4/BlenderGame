--!strict
-- Canonical request and ingredient IDs; timing is relative to the plot session.
type Order = { RequestId: string, Slot: number, Ingredients: { string }, Arrival: number, PayoutFloor: number? }
local orders: { Order } = {
    {
        RequestId = "Red",
        Slot = 3,
        Ingredients = { "Cherries", "Cherries", "Strawberry" },
        Arrival = 0,
        PayoutFloor = 10000,
    },
    { RequestId = "Cold", Slot = 4, Ingredients = { "Ice", "Ice", "Ice" }, Arrival = 8, PayoutFloor = 20000 },
    { RequestId = "Yellow", Slot = 5, Ingredients = { "Banana", "Banana", "Banana" }, Arrival = 16 },
}

return orders
