-- Exercise real carry, ingredient registry, plot authority and customer payout.
local goalIndex = 1
env.Random = {
    new = function()
        return {
            NextInteger = function(_, low, high)
                check(low == 1 and high == 3, "buff rolls use the three existing multipliers")
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
local pad = part("PurchasePoint1", model)
muncher.Reset(p)
local tycoonPurchase = dependency.TycoonService
carry(p)
check(
    not muncher.TryFeed(p, input, nil, tycoonPurchase.GetRequestContext(p)) and inventory.GetCarryCount(p) == 1,
    "unbought Muncher preserves carried ingredients"
)
local lockedLoose = ingredients.Spawn("Banana", frame(), nil, true)
input.Overlaps = { lockedLoose }
check(
    not muncher.TryFeed(p, input, lockedLoose, nil) and ingredients.GetRecord(lockedLoose) ~= nil,
    "unbought input preserves overlapping world ingredients"
)
tycoonPurchase.SetCash(p, 99999)
local bought, reason = muncher.TryPurchase(p, pad, tycoonPurchase.GetRequestContext(p))
check(
    not bought and reason == "InsufficientCash" and tycoonPurchase.GetCash(p) == 99999,
    "insufficient shared cash preserves balance"
)
local outsider = player(3)
tycoonPurchase.SetCash(outsider, 100000)
check(
    not muncher.TryPurchase(outsider, pad, tycoonPurchase.GetRequestContext(outsider)),
    "other plot cannot buy Muncher"
)
local function unlock()
    tycoonPurchase.SetCash(p, 100100)
    check(
        muncher.TryPurchase(p, pad, tycoonPurchase.GetRequestContext(p)),
        "purchase succeeds using existing shared cash"
    )
    check(tycoonPurchase.GetCash(p) == 100, "Muncher costs exactly 100000")
    check(
        not muncher.TryPurchase(p, pad, tycoonPurchase.GetRequestContext(p)) and tycoonPurchase.GetCash(p) == 100,
        "purchase commits only once"
    )
    check(
        not muncher.CompleteReveal(p, model) and not muncher.GetSnapshot(p).Active,
        "reveal cannot complete before server deadline"
    )
    check(not muncher.TryFeed(p, input, nil, nil), "intake remains off during reveal")
    now += loadModule("Muncher").RevealSeconds
    check(muncher.CompleteReveal(p, model) and muncher.GetSnapshot(p).Active, "intake activates after completed reveal")
end
unlock()
inventory.ConsumeHeldIngredient(p, "Banana")
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
for index, buff in config.Buffs do
    goalIndex = index
    muncher.Reset(p)
    unlock()
    for n = 1, 25 do
        local object = world(if n % 2 == 0 then "Rock" else "Mystery")
        check(muncher.TryFeed(p, input, object, nil), "each normal ingredient counts equally")
        local snapshot = muncher.GetSnapshot(p)
        if n < 25 then
            check(
                snapshot.Progress == n and snapshot.ActiveBuff == nil and snapshot.Multiplier == 1,
                "no reward before exactly 25"
            )
        end
    end
    local snapshot = muncher.GetSnapshot(p)
    check(
        snapshot.Progress == 0 and snapshot.Target == 25 and snapshot.ActiveBuff == buff.Id,
        "25th ingredient rolls exactly one buff and resets progress"
    )
    check(
        snapshot.Multiplier == buff.CashMultiplier and snapshot.ExpiresAt == now + 300,
        "existing multiplier lasts exactly 300 seconds"
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
        boosted == math.round(base * buff.CashMultiplier) and value == baseValue and evaluation.Grade == nil,
        "wildcard payout uses existing multiplier without changing grade or ingredient subtotal"
    )
    now = snapshot.ExpiresAt
    check(
        muncher.GetCashMultiplier(p) == 1
            and muncher.GetSnapshot(p).ActiveBuff == nil
            and muncher.GetSnapshot(p).ExpiresAt == 0,
        "expiry clears effect and buff state exactly at deadline"
    )
end
-- A full pending batch never replaces/stacks an active effect or destroys excess items.
goalIndex = 3
muncher.Reset(p)
unlock()
for _ = 1, 25 do
    check(muncher.TryFeed(p, input, world(), nil), "complete first batch")
end
local deadline = muncher.GetSnapshot(p).ExpiresAt
goalIndex = 1
now += 20
for _ = 1, 25 do
    check(muncher.TryFeed(p, input, world(), nil), "accumulate pending batch")
end
local full = muncher.GetSnapshot(p)
check(
    full.Progress == 25 and full.Multiplier == 2 and full.ExpiresAt == deadline,
    "FULL batch preserves single active buff and original deadline"
)
local excess = world()
check(
    not muncher.TryFeed(p, input, excess, nil) and ingredients.GetRecord(excess) ~= nil,
    "FULL preserves excess ingredients"
)
now = deadline
local pending = muncher.GetSnapshot(p)
check(
    pending.Progress == 0
        and pending.ActiveBuff == config.Buffs[1].Id
        and pending.Multiplier == 1.25
        and pending.ExpiresAt == now + 300,
    "expiry activates one pending buff and resets progress"
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
check(
    not muncher.TryPurchase(stranger, pad, tycoon.GetRequestContext(stranger)),
    "teammate cannot repurchase unlocked Muncher"
)
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

check(not muncher.GetSnapshot(p).Purchased and not muncher.GetSnapshot(p).Active, "fresh session resets purchase gate")
tycoon.RemovePlayer(stranger)
setup(tycoon.JoinSession(stranger, p, tycoon.GetRequestContext(p)), "join fresh session before purchase")
tycoon.SetCash(stranger, 100001)
check(muncher.TryPurchase(stranger, pad, tycoon.GetRequestContext(stranger)), "correct teammate can buy shared Muncher")
check(tycoon.GetCash(p) == 1 and tycoon.GetCash(stranger) == 1, "teammate purchase debits the same shared cash ledger")
now += config.RevealSeconds
check(
    muncher.CompleteReveal(stranger, model) and muncher.GetSnapshot(p).Active,
    "teammate purchase reveals shared assembly"
)
