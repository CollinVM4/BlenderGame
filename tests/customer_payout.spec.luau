local customer = loadModule("CustomerService")
local data = loadModule("PlayerDataService")
bindTestData(data)
local upgrades = loadModule("Upgrades")
local ingredients = loadModule("Ingredients")
local economy = loadModule("Economy")
local owner = instance("Player")
data.AddPlayer(owner)
assignTestSession(owner)
customer.Init({ PlayerDataService = data, TycoonService = sessionTestAuthority }, function() end)
local blue = { Id = "Blue", RequiredTags = { "Blue" }, BasePayout = 25 }
local function award(ids, request, expected, expectedValue, expectedSuccess)
    local cup = { Ingredients = ids, Tags = { "Blue" }, IngredientValue = 999999 }
    local success = customer.ValidateRequest(cup, request)
    local amount, ingredientValue = customer.CalculateOrderPayout(owner, cup, request, success)
    check(success == expectedSuccess and amount == expected, "payout for " .. table.concat(ids, ","))
    check(ingredientValue == expectedValue, "subtotal derived from every ingredient ID, including duplicates")
end
award({ "Blueberry", "Banana", "Banana" }, blue, 2288, 1500, true)
award({ "Fish", "Banana", "Banana" }, blue, 6038, 4000, true)
award({ "Noob", "Banana", "Banana" }, blue, 906, 4000, false)
-- Unrelated extras still contribute wealth, without a rarity multiplier.
award({ "Blueberry", "Noob", "Mystery" }, blue, 15038, 10000, true)
award({ "Mystery", "Noob", "Tire" }, {
    RequiredTags = {},
    RequiredIngredients = { "Mystery", "Noob", "Tire" },
    ExactIngredients = true,
    BasePayout = 200,
}, 16050, 10500, true)
award({ "Mystery", "Noob", "Tire" }, { RequiredTags = { "*" }, BasePayout = 25 }, 15788, 10500, true)
-- Values, not rarity labels or a cached subtotal, determine money.
local oldValue, oldRarity = ingredients.Banana.Value, ingredients.Banana.Rarity
ingredients.Banana.Value = 750
ingredients.Banana.Rarity = "Mystery"
award({ "Blueberry", "Banana", "Banana" }, blue, 3038, 2000, true)
ingredients.Banana.Value = oldValue
award({ "Blueberry", "Banana", "Banana" }, blue, 2288, 1500, true)
ingredients.Banana.Rarity = oldRarity
blue.BasePayout = 125
award({ "Blueberry", "Banana", "Banana" }, blue, 2438, 1500, true)
blue.BasePayout = 25
local oldGrade = economy.GradeMultiplier.A
economy.GradeMultiplier.A = 1
award({ "Blueberry", "Banana", "Banana" }, blue, 1525, 1500, true)
award({ "Noob", "Banana", "Banana" }, blue, 604, 4000, false)
economy.GradeMultiplier.A = oldGrade

data.SetEntitlement(owner, "DoubleCash", true)
award({ "Fish", "Banana", "Banana" }, blue, 12075, 4000, true)
award({ "Noob", "Banana", "Banana" }, blue, 1811, 4000, false)
data.SetEntitlement(owner, "DoubleCash", false)
data.SetCash(owner, 12000)
setup(buyTestUpgrade(data, owner, "Payout"), "purchase second payout tier")
check(data.GetCash(owner) == 9000 and upgrades.Payout[2].Value == 1.3, "second tier costs 3000 for x1.3")
award({ "Fish", "Banana", "Banana" }, blue, 7849, 4000, true)
award({ "Noob", "Banana", "Banana" }, blue, 1177, 4000, false)
setup(buyTestUpgrade(data, owner, "Payout"), "purchase final payout tier")
check(data.GetCash(owner) == 0 and upgrades.Payout[3].Value == 1.7, "final tier costs 9000 for x1.7")
data.SetEntitlement(owner, "DoubleCash", true)
award({ "Fish", "Banana", "Banana" }, blue, 20528, 4000, true)
award({ "Noob", "Banana", "Banana" }, blue, 3079, 4000, false)
for track, expected in
    {
        MovementSpeed = { 0, 1000, 5000, 10000 },
        Jump = { 0, 2000, 5000, 8000 },
        SprintStamina = { 0, 1000, 5000, 8000 },
        Hand = { 0, 3000, 8000 },
        CarryCapacity = { 0, 3000, 11000 },
        StackSize = { 0, 5000 },
        BlendSpeed = { 0, 2000, 6000 },
    }
do
    for index, cost in expected do
        check(upgrades[track][index].Cost == cost, track .. " preserves scaled relative prices")
    end
end
