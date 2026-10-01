local customer = loadModule("CustomerService")
local data = loadModule("PlayerDataService")
bindTestData(data)
local upgrades = loadModule("Upgrades")
local ingredients = loadModule("Ingredients")
local requests = loadModule("CustomerRequests")
local economy = loadModule("Economy")
local owner = instance("Player")
data.AddPlayer(owner)
assignTestSession(owner)
customer.Init({ PlayerDataService = data, TycoonService = sessionTestAuthority }, function() end)

local expectedValues = {
    Rock = 1000, Strawberry = 3000, Gummy_Bear = 18000, Steak = 25000,
    Crab = 35000, Cinnamon = 50000, Potato = 60000, Tomato = 60000,
    GoldenTomato = 100000, Dragon_Fruit = 165000,
}
for id, value in expectedValues do
    check(ingredients[id].Value == value, id .. " has its authored monetary value")
end
for _, id in { "Potato", "Tomato", "GoldenTomato", "Pizza", "Mystery" } do
    check(ingredients[id].Rarity == "Rare", id .. " remains Rare")
end
local mysteryCount = 0
for id, definition in ingredients do
    if definition.Rarity == "Mystery" then
        mysteryCount += 1
        check(id == "Dragon_Fruit", "Dragon Fruit is the only Mystery ingredient")
    end
end
check(mysteryCount == 1 and ingredients.Dragon_Fruit.Farmable == false, "only Dragon Fruit is Mystery and cannot be farmed")
for _, id in { "Apple", "Potato", "Tomato", "GoldenTomato" } do
    check(ingredients[id].Farmable ~= false, id .. " remains farmable")
end
local requestById = {}
for _, request in requests.Definitions do requestById[request.Id] = request end
check(requestById.Red.BasePayout == 250, "25-dollar request scales to 250")
check(requestById.Seafood.BasePayout == 750, "75-dollar request scales to 750")
check(requests.WildcardRequest.BasePayout == 250, "wildcard uses the small 250-dollar base")
local has1050, has2000 = false, false
for _, request in requests.Definitions do
    has1050 = has1050 or request.BasePayout == 1050
    has2000 = has2000 or request.BasePayout == 2000
end
check(has1050 and has2000, "105 and 200-dollar requests scale to 1050 and 2000")
check(economy.GradeMultiplier.A == 1.25 and economy.GradeMultiplier.B == 1.1
    and economy.GradeMultiplier.C == 0.9 and economy.GradeMultiplier.D == 0.15,
    "specific fulfillment keeps the established grade multipliers")

local function award(ids, request, expected, expectedValue, expectedGrade)
    local cup = { Ingredients = ids, Tags = { "Blue" }, IngredientValue = 999999 }
    local evaluation = customer.EvaluateOrder(cup, request)
    local amount, ingredientValue = customer.CalculateOrderPayout(owner, cup, request, evaluation)
    check(evaluation.Grade == expectedGrade and amount == expected, "payout for " .. table.concat(ids, ","))
    check(ingredientValue == expectedValue, "subtotal comes from physical ingredient IDs")
end
local blue = { Id = "Blue", RequiredTags = { "Blue" }, BasePayout = requests.WildcardRequest.BasePayout }
award({ "Blueberry", "Blueberry", "Blueberry" }, blue, 9688, 7500, "A")
award({ "Fish", "Banana", "Banana" }, blue, 30825, 34000, "C")
award({ "Noob", "Banana", "Banana" }, blue, 9638, 64000, "D")
award({ "Blueberry", "Noob", "Mystery" }, blue, 110475, 122500, "C")
local function exact(ids, base, expected, raw)
    award(ids, { RequiredTags = {}, RequiredIngredients = ids, ExactIngredients = true, BasePayout = base }, expected, raw, "A")
end
exact({ "Strawberry", "Cherries", "Blueberry" }, 250, 10313, 8000)
exact({ "Crab", "Sushi", "Fish" }, 750, 125938, 100000)
exact({ "GoldenTomato", "Potato", "Tomato" }, 2000, 277500, 220000)
exact({ "Dragon_Fruit", "Dragon_Fruit", "Dragon_Fruit" }, 2000, 621250, 495000)
local wildcardCup = { Ingredients = { "Blueberry", "Banana", "Banana" } }
local wildcardEvaluation = customer.EvaluateOrder(wildcardCup, requests.WildcardRequest)
local wildcardPayout = customer.CalculateOrderPayout(owner, wildcardCup, requests.WildcardRequest, wildcardEvaluation)
check(wildcardEvaluation.Grade == nil and wildcardPayout == 6750, "wildcard liquidates at neutral 1.0")

local originalValue, originalRarity = ingredients.Banana.Value, ingredients.Banana.Rarity
ingredients.Banana.Rarity = "Mystery"
award({ "Fish", "Banana", "Banana" }, blue, 30825, 34000, "C")
ingredients.Banana.Value = 750
award({ "Blueberry", "Banana", "Banana" }, blue, 3825, 4000, "C")
ingredients.Banana.Value, ingredients.Banana.Rarity = originalValue, originalRarity

data.SetCash(owner, 750000)
setup(buyTestUpgrade(data, owner, "Payout"), "purchase first payout tier")
check(data.GetCash(owner) == 600000 and upgrades.Payout[2].Value == 1.3, "first payout tier costs 150000")
setup(buyTestUpgrade(data, owner, "Payout"), "purchase max payout tier")
check(data.GetCash(owner) == 0 and upgrades.Payout[3].Value == 1.7, "max payout tier costs 600000")
exact({ "GoldenTomato", "Potato", "Tomato" }, 2000, 471750, 220000)
exact({ "Dragon_Fruit", "Dragon_Fruit", "Dragon_Fruit" }, 2000, 1056125, 495000)
data.SetEntitlement(owner, "DoubleCash", true)
exact({ "Dragon_Fruit", "Dragon_Fruit", "Dragon_Fruit" }, 2000, 2112250, 495000)

local prices = {
    MovementSpeed = { 0, 20000, 125000, 400000 },
    SprintStamina = { 0, 15000, 100000, 300000 },
    Jump = { 0, 50000, 375000, 800000 },
    CarryCapacity = { 0, 40000, 350000 },
    StackSize = { 0, 250000 },
    Bat = { 0, 50000, 175000, 450000 },
    Payout = { 0, 150000, 600000 },
    SecondStorage = { 0, 400000 },
    BlendSpeed = { 0, 75000, 250000 },
}
local playableTotal = 0
for track, expected in prices do
    for index, cost in expected do
        check(upgrades[track][index].Cost == cost, track .. " has its authored marginal price")
        if track ~= "BlendSpeed" then playableTotal += cost end
    end
end
local farmConfig = loadModule("FarmConfig")
check(farmConfig.RowPrices[1] == 20000 and farmConfig.RowPrices[2] == 100000
    and farmConfig.RowPrices[3] == 350000, "farm rows use authored prices")
for _, price in farmConfig.RowPrices do playableTotal += price end
check(playableTotal == 5120000, "functional progression totals 5.12 million without legacy tracks")
