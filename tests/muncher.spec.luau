-- Exercise real carry, ingredient registry, plot authority and customer payout.
local goalIndex = 1
env.Random = {
    new = function()
        return {
            NextInteger = function(_, low, high)
                check(low == 1 and high == 3, "appetite rolls use the three configured goals")
                return goalIndex
            end,
        }
    end,
}
local muncher = loadModule("MuncherService")
dependency.MuncherService = muncher
dependency.PlayerDataService.HasEntitlement = function()
    return false
end
muncher.Init(dependency)
customer.Init(dependency, function() end, function()
    return true
end)
local p = player(3)
local plot = dependency.TycoonService.GetPlot(p)
local model = instance("Model")
model.Name, model.Parent = "Muncher", plot
local input = part("InputZone", model)
muncher.Reset(p)
local function feed()
    now += 0.2
    return muncher.TryFeed(p, input, nil, dependency.TycoonService.GetRequestContext(p))
end
carry(p, "Banana")
carry(p, "Rock")
carry(p, "Mystery")
for remaining = 2, 0, -1 do
    check(feed(), "valid selected/fallback carried ingredient accepted")
    check(inventory.GetCarryCount(p) == remaining, "only accepted carry unit removed; survivors stay usable")
    check(muncher.GetSnapshot(p).Progress == 3 - remaining, "one progress per carried unit")
end
check(not feed(), "empty carry does not count")
grant(p, "muncher-smoothie")
check(not feed() and inventory.GetHeldSmoothie(p) ~= nil, "smoothie is rejected and preserved")
inventory.ConsumeHeldSmoothie(p)
local function world(id, owner, claimable)
    local object = ingredients.Spawn(id or "Banana", frame(), owner, claimable)
    input.Overlaps = { object }
    return object
end
local loose = world()
check(muncher.TryFeed(p, input, loose, nil), "registered claimable world ingredient accepted")
check(
    not muncher.TryFeed(p, input, loose, nil) and muncher.GetSnapshot(p).Progress == 4,
    "duplicate contact cannot consume or increment again"
)
local fake = part("FakeIngredient", model)
carry(p)
local thrown = inventory.ThrowHeld(p)
input.Overlaps = { thrown }
check(
    muncher.TryFeed(p, input, thrown, nil) and inventory.GetCarryCount(p) == 0,
    "existing carry throw path feeds registered world item without leaving reservations"
)
local worldSmoothie = dependency.SmoothieWorldItemService.Spawn(smoothie("muncher-world-smoothie"), frame())
input.Overlaps = { worldSmoothie.PrimaryPart }
check(
    not muncher.TryFeed(p, input, worldSmoothie, nil)
        and dependency.SmoothieWorldItemService.GetData(worldSmoothie) ~= nil,
    "world smoothie is rejected and preserved"
)
fake:SetAttribute("IngredientId", "Banana")
input.Overlaps = { fake }
check(not muncher.TryFeed(p, input, fake, nil), "arbitrary parts and fake metadata grant no progress")
local stranger = player(3)
local foreign = world("Banana", stranger)
check(
    not muncher.TryFeed(p, input, foreign, nil) and ingredients.GetRecord(foreign) ~= nil,
    "another player's item is preserved"
)
local reserved = world("Banana", nil, false)
check(not muncher.TryFeed(p, input, reserved, nil), "unclaimable ingredient rejected")
local far = world()
input.Overlaps = {}
check(not muncher.TryFeed(p, input, far, nil), "world feed needs actual server overlap")
local frozen = ingredients.Spawn("Banana", frame(), nil, true, { FreezeUntilPickup = true })
input.Overlaps = { frozen }
check(not muncher.TryFeed(p, input, frozen, nil), "frozen pickup ingredient preserved")
carry(p)
local humanoid = p.Character:FindFirstChildOfClass("Humanoid")
humanoid.Health = 0
check(not feed() and inventory.GetCarryCount(p) == 1, "death blocks carry feeding without removal")
humanoid.Health = 100
local stale = { PlotSessionId = "stale", MembershipRevision = 1 }
check(
    not muncher.TryFeed(p, input, nil, stale) and inventory.GetCarryCount(p) == 1,
    "stale plot request cannot consume carried item"
)
check(feed(), "valid context remains usable after rejection")
local config = loadModule("Muncher")
for index, goal in config.Goals do
    goalIndex = index
    muncher.Reset(p)
    for n = 1, goal.Required do
        local object = world(if n % 2 == 0 then "Rock" else "Mystery")
        check(muncher.TryFeed(p, input, object, nil), "each normal ingredient counts equally")
        local snapshot = muncher.GetSnapshot(p)
        if n < goal.Required then
            check(snapshot.Progress == n and snapshot.Multiplier == 1, "no reward before exact target")
        end
    end
    local snapshot = muncher.GetSnapshot(p)
    check(snapshot.Progress == 0 and snapshot.Target == goal.Required, "completion resets progress and rolls appetite")
    check(
        snapshot.Multiplier == goal.CashMultiplier and snapshot.ExpiresAt == now + goal.Duration,
        "correct cash multiplier and server duration"
    )
    check(muncher.GetCashMultiplier(stranger) == 1, "other plot receives no buff")
    local cup = smoothie("payout", { "Banana", "Banana", "Banana" })
    local request = loadModule("CustomerRequests").WildcardRequest
    local evaluation = customer.EvaluateOrder(cup, request)
    local boosted, value = customer.CalculateOrderPayout(p, cup, request, evaluation)
    dependency.MuncherService = nil
    local base, baseValue = customer.CalculateOrderPayout(p, cup, request, evaluation)
    dependency.MuncherService = muncher
    check(
        boosted == math.round(base * goal.CashMultiplier) and value == baseValue and evaluation.Grade == nil,
        "wildcard payout boosted without changing ingredient subtotal or grade"
    )
    now = snapshot.ExpiresAt
    check(muncher.GetCashMultiplier(p) == 1 and muncher.GetSnapshot(p).ExpiresAt == 0, "expires exactly at deadline")
end
-- A weaker reward replaces a stronger active buff and starts a fresh duration.
goalIndex = 3
muncher.Reset(p)
goalIndex = 1
for _ = 1, 100 do
    check(muncher.TryFeed(p, input, world(), nil), "complete stronger goal")
end
check(muncher.GetCashMultiplier(p) == 2 and muncher.GetSnapshot(p).Target == 25, "new appetite rolls after reward")
now += 20
for _ = 1, 25 do
    check(muncher.TryFeed(p, input, world(), nil), "complete replacement goal")
end
check(
    muncher.GetCashMultiplier(p) == 1.25 and muncher.GetSnapshot(p).ExpiresAt == now + 300,
    "new reward replaces rather than stacks, even when weaker"
)
-- Actual serve consumes the authoritative inventory cup and credits the active bonus.
local upgrade = loadModule("Upgrades").Payout[2]
local authority = dependency.TycoonService
authority.SetCash(p, upgrade.Cost + 100)
setup(authority.PurchaseUpgrade(p, "Payout", 2, authority.GetRequestContext(p)), "payout upgrade during buff")
check(dataService.GetCash(p) == 100, "Muncher never multiplies upgrade costs")
dependency.PlayerDataService.HasEntitlement = function()
    return true
end
local gradedCup = smoothie("graded-payout", { "Banana", "Banana", "Banana" })
local gradedRequest = { Id = "Yellow", RequiredTags = { "Yellow" }, BasePayout = 250 }
local graded = customer.EvaluateOrder(gradedCup, gradedRequest)
local subtotal = loadModule("IngredientItem").GetSmoothieValue(gradedCup, now)
local gradedPayout = customer.CalculateOrderPayout(p, gradedCup, gradedRequest, graded)
check(
    graded.Grade == "A"
        and gradedPayout
            == math.round((subtotal + 250) * loadModule("Economy").GradeMultiplier.A * upgrade.Value * 2 * 1.25),
    "final cash chain combines grade, payout upgrade, entitlement and Muncher once"
)
local legacyPayout = customer.CalculatePayout(p, "A")
local economy = loadModule("Economy")
check(
    legacyPayout
        == math.round(economy.BasePayout * economy.CashScale * economy.GradeMultiplier.A * upgrade.Value * 2 * 1.25),
    "legacy customer payout uses same reward authority"
)
dataService.AddCash(p, 17)
check(dataService.GetCash(p) == 117, "unrelated cash grants remain unmultiplied")
carry(p, "Banana")
setup(inventory.Deposit(p, "Banana", 3), "store ingredient during active Muncher buff")
local stored = inventory.GetSnapshot(p).Stash[3]
check(
    stored.Count == 1 and stored.Value == loadModule("IngredientItem").GetIngredientValue(stored.Ingredients[1], now),
    "stash totals retain ingredient value during cash buff"
)
env.Enum.HumanoidDisplayDistanceType = { None = "None" }
env.Enum.HumanoidHealthDisplayType = { AlwaysOff = "AlwaysOff" }
local requests = loadModule("CustomerRequests")
requests.RegularWildcardChance, requests.SpecialCustomerChance = 1, 0
customer.ActivateForPlayer(p)
local npc = customer.SpawnForPlayer(p)
flush()
setup(npc and customer.GetSnapshot(p).Ready, "customer ready for Muncher payout")
local cup = smoothie("muncher-serve", { "Banana", "Banana", "Banana" })
setup(inventory.GrantSmoothie(p, cup), "authoritative cup for serve")
local expected = customer.CalculateOrderPayout(p, cup, requests.WildcardRequest)
local cashBefore = dataService.GetCash(p)
check(customer.Serve(p, npc), "serve during active reward succeeds")
check(
    dataService.GetCash(p) == cashBefore + expected and inventory.GetHeldSmoothie(p) == nil,
    "actual serve credits boosted cash and consumes cup once"
)
check(
    npc:GetAttribute("Grade") == nil and npc:GetAttribute("IsWildcard") == true,
    "Muncher leaves wildcard grading unchanged"
)
check(
    not customer.Serve(p, npc) and dataService.GetCash(p) == cashBefore + expected,
    "replaying boosted serve cannot pay again"
)
local tycoon = dependency.TycoonService
tycoon.Init({
    SessionEnded = function(id)
        muncher.CleanupSession(id)
        inventory.CleanupSession(id)
        blend.CleanupSession(id)
        customer.CleanupSession(id)
    end,
})
tycoon.RemovePlayer(stranger)
setup(tycoon.JoinSession(stranger, p, tycoon.GetRequestContext(p)), "join Muncher team")
check(muncher.GetCashMultiplier(stranger) == 1.25, "teammate shares plot reward")
carry(stranger)
now += 0.2
check(muncher.TryFeed(stranger, input, nil, tycoon.GetRequestContext(stranger)), "teammate can feed shared Muncher")
check(muncher.GetSnapshot(p).Progress == 1, "team feed advances same plot appetite")
setup(tycoon.LeaveTeam(stranger, tycoon.GetRequestContext(stranger)), "leave Muncher team")
check(muncher.GetCashMultiplier(stranger) == 1, "departing teammate loses access to buff")
local oldSession = tycoon.GetSessionId(p)
tycoon.RemovePlayer(p)
check(muncher.GetSnapshot(p) == nil and muncher.GetCashMultiplier(p) == 1, "cleanup removes progress and reward")
setup(tycoon.AssignPlot(p, plot) == plot, "reassign original plot")
muncher.Reset(p)
check(
    tycoon.GetSessionId(p) ~= oldSession and muncher.GetSnapshot(p).Progress == 0 and muncher.GetCashMultiplier(p) == 1,
    "fresh session state starts empty"
)
