local customer = loadModule("CustomerService")
local data = loadModule("PlayerDataService")
bindTestData(data)
local upgrades = loadModule("Upgrades")
local owner = instance("Player")
data.AddPlayer(owner)
assignTestSession(owner)
customer.Init({ PlayerDataService = data, TycoonService = sessionTestAuthority }, function() end)
local blue = { Id = "Blue", RequiredTags = { "Blue" }, BasePayout = 25 }
local function award(ids, request, expected, expectedRarity, expectedSuccess)
    local cup = { Ingredients = ids, Tags = { "Blue" } }
    local success = customer.ValidateRequest(cup, request)
    local amount, rarity = customer.CalculateOrderPayout(owner, cup, request, success)
    check(
        success == expectedSuccess and amount == expected and rarity == expectedRarity,
        "payout for " .. table.concat(ids, ",")
    )
end
award({ "Blueberry", "Banana", "Banana" }, blue, 750, 1, true)
award({ "Fish", "Banana", "Banana" }, blue, 1313, 1.75, true)
award({ "Noob", "Banana", "Banana" }, blue, 197, 1.75, false)
award({ "Blueberry", "Noob", "Mystery" }, blue, 750, 1, true)
award({ "Mystery", "Noob", "Tire" }, {
    RequiredTags = {},
    RequiredIngredients = { "Mystery", "Noob", "Tire" },
    ExactIngredients = true,
    BasePayout = 200,
}, 15000, 2.5, true)
award({ "Milk", "Noob", "Banana" }, { RequiredTags = { "milk" }, BasePayout = 25 }, 938, 1.25, true)
award(
    { "Fish", "Blueberry", "Noob" },
    { RequiredTags = {}, RequiredIngredients = { { "Fish", "Blueberry" }, "Blueberry" }, BasePayout = 25 },
    1313,
    1.75,
    true
)
award({ "Mystery", "Noob", "Tire" }, { RequiredTags = { "*" }, BasePayout = 25 }, 1875, 2.5, true)
award(
    { "Blueberry", "Mystery", "Banana" },
    { RequiredTags = { "Blue" }, ForbiddenIngredients = { "Mystery" }, BasePayout = 25 },
    281,
    2.5,
    false
)
data.SetEntitlement(owner, "DoubleCash", true)
award({ "Fish", "Banana", "Banana" }, blue, 2625, 1.75, true)
award({ "Noob", "Banana", "Banana" }, blue, 394, 1.75, false)
data.SetEntitlement(owner, "DoubleCash", false)
data.SetCash(owner, 12000)
setup(buyTestUpgrade(data, owner, "Payout"), "purchase second payout tier")
check(data.GetCash(owner) == 9000 and upgrades.Payout[2].Value == 1.3, "second tier costs 3000 for x1.3")
award({ "Fish", "Banana", "Banana" }, blue, 1706, 1.75, true)
award({ "Noob", "Banana", "Banana" }, blue, 256, 1.75, false)
setup(buyTestUpgrade(data, owner, "Payout"), "purchase final payout tier")
check(data.GetCash(owner) == 0 and upgrades.Payout[3].Value == 1.7, "final tier costs 9000 for x1.7")
data.SetEntitlement(owner, "DoubleCash", true)
award({ "Fish", "Banana", "Banana" }, blue, 4463, 1.75, true)
award({ "Noob", "Banana", "Banana" }, blue, 669, 1.75, false)
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
