-- Real Blend/Inventory/Customer services; only engine/plot boundaries are faked.
local p = player()
local requests = loadModule("CustomerRequests").Definitions
table.clear(requests)
requests[1] = { Id = "RoundTripRed", DisplayText = "Red", RequiredTags = { "Red" }, BasePayout = 25, MinJumpTier = 0 }

local id = complete(p)
setup(blend.Dispense(p, references[p].TurbineWheel), "dispense completed batch")
flush()
setup(press(p), "store dispensed smoothie")
check(inventory.GetCarryCount(p) == 0 and slot(p).Smoothie.BlendId == id, "stash owns the dispensed identity")
now += 1 -- End STORE burst before establishing TAKE.
setup(press(p), "take stored smoothie")
local held = inventory.GetHeldSmoothie(p)
check(
    held.BlendId == id and table.concat(held.Ingredients, ",") == "Strawberry,Banana,Strawberry" and slot(p).Count == 0,
    "round-trip preserves identity, ingredient order and duplicates without a stored copy"
)
setup(customer.SpawnForPlayer(p) ~= nil, "spawn round-trip customer")
flush()
flush()
local cash = dataService.GetCash(p)
check(customer.Serve(p), "round-tripped smoothie serves successfully")
check(
    inventory.GetCarryCount(p) == 0 and dataService.GetCash(p) == cash + 25 and completedServes == 1,
    "serve consumes the returned reservation and pays/completes once"
)
check(not customer.Serve(p) and dataService.GetCash(p) == cash + 25, "round-trip cannot replay payout")
