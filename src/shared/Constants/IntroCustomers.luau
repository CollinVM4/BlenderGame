--!strict
-- Queue positions are independent of the guided tutorial and starter-stash seeding.
local TutorialOrders = require(script.Parent.TutorialOrders)
type IntroCustomer = { RequestId: string, Arrival: number, PayoutFloor: number?, CustomerId: string? }
local sequence: { IntroCustomer } = {
    { RequestId = TutorialOrders[1].RequestId, Arrival = 0, PayoutFloor = TutorialOrders[1].PayoutFloor },
    { RequestId = "Cold", Arrival = 8 },
    { RequestId = "Caseoh", CustomerId = "caseoh", Arrival = 16 },
}

return sequence
