-- Authoritative order value, grade and provenance contracts (legal three-unit blends).
local customer = loadModule("CustomerService")
local data = loadModule("PlayerDataService")
bindTestData(data)
local items = loadModule("IngredientItem")
local ingredients = loadModule("Ingredients")
local requests = loadModule("CustomerRequests")
local economy = loadModule("Economy")
local upgrades = loadModule("Upgrades")
local owner = instance("Player")
owner.Name, owner.DisplayName, owner.UserId = "Economy", "Economy", 42
data.AddPlayer(owner)
assignTestSession(owner)
local muncher = 1
local luckyFactor = 1
local expectedServer = owner
customer.Init({
    LuckyBlockService = {
        GetCashMultiplier = function(player)
            check(player == expectedServer, "cash multiplier uses serving player")
            return luckyFactor
        end,
    },
    PlayerDataService = data,
    TycoonService = sessionTestAuthority,
    MuncherService = {
        GetCashMultiplier = function()
            return muncher
        end,
    },
}, function() end)
local byId = {}
for _, request in requests.Definitions do
    byId[request.Id] = request
end
local function cup(ids, origins)
    local result = { Ingredients = ids, IngredientItems = {} }
    for index, id in ids do
        result.IngredientItems[index] = items.New(id, tostring(index), origins and origins[index])
    end
    return result
end
local function award(result, request, effective, multiplier, grade)
    local evaluation = customer.EvaluateOrder(result, request)
    local amount, display = customer.CalculateOrderPayout(owner, result, request, evaluation)
    local expected = math.round((effective + request.BasePayout) * multiplier * economy.GradeMultiplier[grade])
    check(evaluation.Grade == grade and amount == expected and display == effective, "real grade/payout/display chain")
    return amount
end
local a = award(cup({ "Cherries", "Cherries", "Strawberry" }), byId.Red, 7500, 1, "A")
local b = award(cup({ "Cherries", "Strawberry", "Melon" }), byId.Red, 6750, 1, "B")
local c = award(cup({ "Cherries", "Cherries", "Melon" }), byId.Red, 6750, 1, "B")
check(b < a and c < a and b == c, "accepted final ordering under the real evaluator")
local invalid = customer.EvaluateOrder({ Ingredients = { "Cherries" } }, byId.Red)
check(
    not invalid.IsValid and #invalid.Relevant == 1 and not invalid.Relevant[1],
    "invalid result still exposes parallel nonqualifying relevance"
)
local flags = customer.EvaluateOrder(cup({ "Cherries", "Strawberry", "Melon" }), byId.Red).Relevant
check(#flags == 3 and flags[1] and flags[2] and not flags[3], "relevance is parallel to physical ingredient order")
local recipe = {
    RequiredTags = {},
    RequiredIngredients = { "Cherries", "Strawberry", "Melon" },
    ExactIngredients = true,
    BasePayout = 250,
}
award(cup({ "Cherries", "Strawberry", "Melon" }), recipe, 12000, 1, "A")
local pair = cup({ "Cherries", "Melon", "Melon" })
award(pair, byId.Red, 3750, 1, "C")
check(3750 - ingredients.Cherries.Value == 1250, "catalog-priced red match caps filler at half matching value")
award(cup({ "Melon", "Melon", "Melon" }), byId.Red, 0, 1, "D")
local pear = { RequiredTags = { "Yellow" }, BasePayout = 250 }
award(cup({ "Pear", "Crab", "Crab" }), pear, 6750, 1, "C")
local ripe = cup({ "Cherries", "Strawberry", "Melon" })
ripe.IngredientItems[1].IsRipe = true
local raw = items.GetSmoothieValue(ripe, now)
check(raw == 12625, "ripeness is included in shared per-unit value source")
local relevantRaw = items.GetSmoothieIngredientValue(ripe, 1, now) + items.GetSmoothieIngredientValue(ripe, 2, now)
check(
    relevantRaw + items.GetSmoothieIngredientValue(ripe, 3, now) == raw,
    "split exactly reconstructs undiscounted sum"
)
award(ripe, byId.Red, 7375, 1, "B")
local allRipe = cup({ "Cherries", "Cherries", "Strawberry" })
allRipe.IngredientItems[1].IsRipe = true
award(allRipe, byId.Red, items.GetSmoothieValue(allRipe, now), 1, "A")
local sweet = { RequiredTags = { "Sweet" }, BasePayout = 250 }
for _, origin in { "Market", "Event", "Farm", "Muncher", "Unknown" } do
    award(
        cup({ "Melon", "Cherries", "Strawberry" }, { origin, "Farm", "Farm" }),
        sweet,
        12000,
        if origin == "Market" or origin == "Event" then 1.5 else 1,
        "A"
    )
end
award(cup({ "Cherries", "Strawberry", "Melon" }, { "Farm", "Farm", "Market" }), byId.Red, 6750, 1, "B")
award(cup({ "Crab", "Strawberry", "Melon" }, { "Market", "Farm", "Farm" }), byId.Red, 11250, 1.25, "B")
award(cup({ "Pear", "Melon", "Cherries" }, { "Market", "Farm", "Farm" }), sweet, 14000, 1.1, "A")
local farm = award(cup({ "Crab", "Cherries", "Strawberry" }, { "Farm", "Farm", "Farm" }), byId.Red, 12000, 1, "A")
local market =
    award(cup({ "Crab", "Cherries", "Strawberry" }, { "Market", "Farm", "Farm" }), byId.Red, 12000, 1.25, "A")
check(
    market == math.round((12000 + 250) * 1.25 * 1.25) and market > farm,
    "pedestal Crab multiplies otherwise identical drink"
)
local legacy = { Ingredients = { "Melon", "Cherries", "Strawberry" } }
award(legacy, sweet, 12000, 1, "A")
local missing = cup({ "Melon", "Cherries", "Strawberry" })
missing.IngredientItems[1].Origin = nil
award(missing, sweet, 12000, 1, "A")
check(items.New("Melon", "new").Origin == "Unknown", "fresh unit opts out of premium")
local original = cup({ "Melon", "Cherries", "Strawberry" }, { "Market", "Farm", "Muncher" })
local copies = items.CopyAll(original.IngredientItems)
check(
    copies[1].Origin == "Market" and copies[2].Origin == "Farm" and copies[3].Origin == "Muncher",
    "CopyAll preserves provenance"
)
copies[1].Origin = "Unknown"
check(original.IngredientItems[1].Origin == "Market", "CopyAll does not alias source records")
for _, ids in { { "Blueberry", "Blueberry", "Blueberry" }, { "Dragon_Fruit", "Dragon_Fruit", "Dragon_Fruit" } } do
    local amount, display =
        customer.CalculateOrderPayout(owner, cup(ids, { "Market", "Market", "Market" }), requests.WildcardRequest)
    check(amount == 250 and display == 0, "wildcard ignores every ingredient and provenance")
end
check(authoredWildcardChances[1] == 0.16 and authoredWildcardChances[2] == 0, "authored wildcard rates")
for index, expected in { { 0, 3 }, { 30000, 5 }, { 75000, 7 } } do
    check(
        upgrades.CarryCapacity[index].Cost == expected[1] and upgrades.CarryCapacity[index].Value == expected[2],
        "carry tuning"
    )
end
-- Approved regular-tier medians and mixed-floor order, outside tutorial/task grants.
for _, sample in
    {
        { "Cherries", 2500, 1, 9688 },
        { "Pear", 4500, 1.1, 18906 },
        { "Coconut", 6000, 1.25, 28516 },
        { "Golden_Potato", 8000, 1.5, 45469 },
    }
do
    local id, value, multiplier, expected = unpack(sample)
    local request = { RequiredIngredients = { id, id, id }, ExactIngredients = true, BasePayout = 250 }
    check(
        award(cup({ id, id, id }, { "Market", "Market", "Market" }), request, value * 3, multiplier, "A") == expected,
        "approved median payout"
    )
end
local mixed =
    { RequiredIngredients = { "Cherries", "Strawberry", "Golden_Potato" }, ExactIngredients = true, BasePayout = 250 }
check(
    award(cup({ "Cherries", "Strawberry", "Golden_Potato" }, { "Market", "Market", "Market" }), mixed, 13000, 1.5, "A")
        == 24844,
    "matching ground ingredients retain full value alongside tower ingredient"
)

data.SetCash(owner, 750000)
setup(buyTestUpgrade(data, owner, "Payout"), "first payout upgrade")
setup(buyTestUpgrade(data, owner, "Payout"), "second payout upgrade")
data.GrantDoubleCash(owner, 600)
muncher = 2
local premium = cup({ "Melon", "Cherries", "Strawberry" }, { "Market", "Farm", "Farm" })
local amount = customer.CalculateOrderPayout(owner, premium, sweet)
check(amount == math.round((12000 + 250) * 1.5 * 1.25 * 1.7 * 2 * 2), "all premium payout multipliers compose")
local flat, display = customer.CalculateOrderPayout(owner, premium, requests.WildcardRequest)
check(
    flat == math.round(250 * 1.7 * 2 * 2) and display == 0,
    "wildcard keeps upgrade entitlement and muncher modifiers"
)
print("PASS: economy payout contracts")

for _, shop in { false, true } do
    now += data.GetDoubleCashRemainingSeconds(owner) + 1
    if shop then
        data.GrantDoubleCash(owner, 600)
    end
    luckyFactor = 1
    local plain = customer.CalculatePayout(owner, "A")
    luckyFactor = 1.5
    local expected = if shop then 1 else 1.5
    check(customer.CalculatePayout(owner, "A") == math.round(plain * expected), "flat payout uses max shop/lucky")
    check(
        customer.CalculateOrderPayout(owner, premium, sweet)
            == math.round((12000 + 250) * 1.5 * 1.25 * 1.7 * (if shop then 2 else 1.5) * muncher),
        "order payout uses max shop/lucky"
    )
end

local teammate = instance("Player")
teammate.Name, teammate.DisplayName, teammate.UserId = "Server", "Server", 43
data.AddPlayer(teammate)
setup(
    sessionTestAuthority.JoinSession(teammate, owner, sessionTestAuthority.GetRequestContext(owner)),
    "join serving teammate"
)
expectedServer = teammate
data.GrantDoubleCash(owner, 600)
data.SetEntitlement(teammate, "DoubleCash", false)
luckyFactor = 1.5
check(
    customer.CalculateOrderPayout(teammate, premium, requests.WildcardRequest) == math.round(250 * 1.7 * 1.5 * muncher),
    "teammate uses own cash factors with shared payout upgrade"
)
local flat = customer.CalculatePayout(teammate, "A")
check(
    flat == math.round(economy.BasePayout * economy.CashScale * economy.GradeMultiplier.A * 1.7 * 1.5 * muncher),
    "flat payout uses serving teammate entitlement"
)

-- Expired timer wins over the retained backward-compatible entitlement flag.
now += data.GetDoubleCashRemainingSeconds(owner) + 1
expectedServer = owner
luckyFactor = 1
check(
    data.HasEntitlement(owner, "DoubleCash") and not data.IsDoubleCashActive(owner),
    "boolean does not keep expired boost alive"
)
check(
    customer.CalculatePayout(owner, "A")
        == math.round(economy.BasePayout * economy.CashScale * economy.GradeMultiplier.A * 1.7 * muncher),
    "expired flat payout returns to unboosted factor"
)
check(
    customer.CalculateOrderPayout(owner, premium, sweet) == math.round((12000 + 250) * 1.5 * 1.25 * 1.7 * muncher),
    "expired order payout returns to unboosted factor"
)
