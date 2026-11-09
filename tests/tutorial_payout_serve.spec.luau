-- Floors belong to tutorial records, and all payout consumers share the award.
loadModule("FilmingUtil").Init()
table.clear(config.Definitions)
for index, definition in originalDefinitions do
    config.Definitions[index] = definition
end
config.RegularWildcardChance = 0
local tutorialOrders = loadModule("IntroCustomers")
local calculatePayout = customer.CalculateOrderPayout
customer.CalculateOrderPayout = function()
    return 250, 100
end
for _, case in
    {
        { Index = 1, Ingredients = { "Cherries", "Cherries", "Strawberry" }, Expected = 30000 },
        { Index = 2, Ingredients = { "Ice", "Ice", "Ice" }, Expected = 250 },
        { Index = 3, Ingredients = { "Hamburger", "Chili_Pepper", "Hamburger" }, Expected = 250 },
        { Index = 1, Ingredients = { "Banana", "Banana", "Banana" }, Expected = 250 },
        { Index = 1, Ingredients = { "Cherries" }, Expected = 250 },
        { Index = 1, Ingredients = { "Cherries", "Cherries", "Strawberry" }, Expected = 250, Normal = true },
    }
do
    data.GetTutorialState(owner).FirstServeRewarded = false
    customer.ActivateForPlayer(owner, not case.Normal)
    local model
    for index = 1, case.Index do
        now += tutorialOrders[index].Arrival
        model = customer.SpawnForPlayer(owner)
        flush()
    end
    setup(model and customer.GetSnapshot(owner).Ready, "floor customer ready")
    if case.Normal then
        -- Only Red is eligible, so normal request selection is deterministic.
        table.clear(config.Definitions)
        for _, definition in originalDefinitions do
            if definition.Id == "Red" then
                config.Definitions[1] = definition
            end
        end
        customer.DeactivateForPlayer(owner)
        customer.ActivateForPlayer(owner)
        model = customer.SpawnForPlayer(owner)
        flush()
        setup(model:GetAttribute("RequestId") == "Red", "normal customer orders Red")
    end
    local before = data.GetCash(owner)
    table.clear(presentation)
    cup = { Ingredients = table.clone(case.Ingredients), BlendId = "floor-cup" }
    setup(customer.Serve(owner, model), "serve floor case")
    check(data.GetCash(owner) == before + case.Expected, "only valid fulfilled tutorial records receive payout floor")
    local reaction
    for _, event in presentation do
        if event.Moment == "CustomerReaction" then
            reaction = event.Payload
        end
    end
    check(reaction and reaction.Payout == case.Expected, "cash-pop payload matches credited tutorial payout")
    local graphic = model:FindFirstChild("CustomerResult", true)
    check(
        string.find(graphic:FindFirstChild("Result").Text, loadModule("MoneyFormat").Full(case.Expected), 1, true)
            ~= nil,
        "result GUI matches credited payout"
    )
    customer.DeactivateForPlayer(owner)
end
customer.CalculateOrderPayout = calculatePayout

data.GetTutorialState(owner).FirstServeRewarded = false
customer.ActivateForPlayer(owner, true)
now += tutorialOrders[1].Arrival
local model = customer.SpawnForPlayer(owner)
flush()
setup(model and customer.GetSnapshot(owner).Ready, "real-formula tutorial customer ready")
cup = { Ingredients = table.clone({ "Cherries", "Cherries", "Strawberry" }), BlendId = "real-floor" }
local before = data.GetCash(owner)
setup(customer.Serve(owner, model), "real-formula tutorial serve")
check(
    data.GetCash(owner) - before == tutorialOrders[1].PayoutFloor,
    "new economy retains tutorial floor after calculation"
)

-- Reconstructing a queue cannot mint a second first-serve floor in this profile.
customer.DeactivateForPlayer(owner)
customer.ActivateForPlayer(owner, true)
model = customer.SpawnForPlayer(owner)
flush()
customer.CalculateOrderPayout = function()
    return 250, 100
end
cup = { Ingredients = { "Cherries", "Cherries", "Strawberry" }, BlendId = "reconstructed" }
before = data.GetCash(owner)
setup(customer.Serve(owner, model), "serve after queue reconstruction")
check(data.GetCash(owner) - before == 250, "profile guard survives queue reconstruction")
customer.DeactivateForPlayer(owner)
data.GetTutorialState(owner).FirstServeRewarded = false
data.GetTutorialState(owner).Complete = true
customer.ActivateForPlayer(owner, true)
model = customer.SpawnForPlayer(owner)
flush()
cup = { Ingredients = { "Cherries", "Cherries", "Strawberry" }, BlendId = "completed" }
before = data.GetCash(owner)
setup(customer.Serve(owner, model), "serve with completed profile")
check(data.GetCash(owner) - before == 250, "completed profiles never receive tutorial floor")
customer.DeactivateForPlayer(owner)
data.GetTutorialState(owner).Complete = false
customer.ActivateForPlayer(owner, true)
model = customer.SpawnForPlayer(owner)
flush()
customer.CalculateOrderPayout = function()
    return 45000, 100
end
cup = { Ingredients = { "Cherries", "Cherries", "Strawberry" }, BlendId = "above-floor" }
before = data.GetCash(owner)
setup(customer.Serve(owner, model), "serve above floor")
check(data.GetCash(owner) - before == 45000, "floor never adds an unconditional extra 30000")
customer.CalculateOrderPayout = calculatePayout
