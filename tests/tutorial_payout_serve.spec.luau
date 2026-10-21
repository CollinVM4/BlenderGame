-- Floors belong to tutorial records, and all payout consumers share the award.
loadModule("FilmingUtil").Init()
table.clear(config.Definitions)
for index, definition in originalDefinitions do
    config.Definitions[index] = definition
end
config.RegularWildcardChance = 0
local tutorialOrders = loadModule("TutorialOrders")
local calculatePayout = customer.CalculateOrderPayout
customer.CalculateOrderPayout = function()
    return 250, 100
end
for _, case in
    {
        { Index = 1, Ingredients = tutorialOrders[1].Ingredients, Expected = 10000 },
        { Index = 2, Ingredients = tutorialOrders[2].Ingredients, Expected = 20000 },
        { Index = 3, Ingredients = tutorialOrders[3].Ingredients, Expected = 250 },
        { Index = 1, Ingredients = { "Banana", "Banana", "Banana" }, Expected = 250 },
        { Index = 1, Ingredients = { "Cherries" }, Expected = 250 },
        { Index = 1, Ingredients = tutorialOrders[1].Ingredients, Expected = 250, Normal = true },
    }
do
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
