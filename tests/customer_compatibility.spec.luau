-- Compatibility helpers, NOT the current CustomerService.Serve payout/reaction path.
local data = loadModule("PlayerDataService")
local customer = loadModule("CustomerService")
local p = instance("Player")
data.AddPlayer(p)
customer.Init(
    { PlayerDataService = data, IngredientService = loadModule("IngredientService") },
    function() end,
    function()
        return true
    end
)
local bad = { Ingredients = { "Tire", "Tire", "Tire" } }
local result = { Result = { Ingredients = { "Strawberry", "Banana", "Ice" } } }
check(customer.CalculateGrade(bad, "Sweet") == "D", "bad match receives D")
check(customer.CalculateGrade(bad, "Weird") == "A", "same smoothie matches Weird")
check(customer.CalculateGrade(result.Result, "Surprise Me") == "A", "Surprise Me rewards variety")
local normalPay = customer.CalculatePayout(p, "D")
data.SetEntitlement(p, "DoubleCash", true)
check(customer.CalculatePayout(p, "D") == normalPay * 2, "cash entitlement affects reward")
local oldRandom = math.random
-- Reaction function accepts no grade; forcing the extreme roll leaves grade unchanged.
env.math = table.clone(math)
env.math.random = function()
    return 0.99999
end
check(
    customer.SelectReaction() == "Launch" and customer.CalculateGrade(bad, "Sweet") == "D",
    "rare reaction independent of D grade"
)
env.math.random = oldRandom
