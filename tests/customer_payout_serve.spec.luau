-- Real server serve transaction, with a one-use authoritative cup boundary.
env.Enum.HumanoidDisplayDistanceType = { None = "None" }
env.Enum.HumanoidHealthDisplayType = { AlwaysOff = "AlwaysOff" }
local customer = loadModule("CustomerService")
local data = loadModule("PlayerDataService")
bindTestData(data)
local owner = instance("Player")
owner.Name, owner.UserId, owner.Near = "PayoutOwner", 42, true
data.AddPlayer(owner)
assignTestSession(owner)
local plot = instance("Model")
local refs = {}
for _, name in { "CustomerSpawn", "CustomerCounter", "CustomerWait1", "CustomerWait2", "CustomerExit" } do
    refs[name] = instance("Part")
    refs[name].CFrame = frame()
end
local config = loadModule("CustomerRequests")
table.clear(config.Definitions)
config.SpecialCustomerChance = 0
config.Definitions[1] = {
    Id = "Blue",
    DisplayText = "Blue please!",
    RequiredTags = { "Blue" },
    BasePayout = 25,
    MinJumpTier = 0,
    GoodResponse = "Thanks!",
    BadResponse = "Not blue!",
}
local cup, completed, consumed = nil, 0, 0
local nestedServe = false
customer.Init({
    GameplayService = {
        RegisterPlotInteraction = function(prompt, callback)
            prompt.Triggered:Connect(callback)
        end,
    },
    PlayerDataService = data,
    TycoonService = setmetatable({
        GetReference = function(_, name)
            return refs[name]
        end,
    }, { __index = sessionTestAuthority }),
    BlendService = {
        ConsumeCup = function()
            local result = cup
            if result then
                cup = nil
                consumed += 1
                nestedServe = customer.Serve(owner)
            end
            return result
        end,
    },
}, function()
    completed += 1
end)
for index, case in
    {
        { "Blueberry", 750, "A", "Thanks!", "+$750" },
        { "Fish", 1313, "A", "Thanks!", "+$1,313" },
        { "Noob", 197, "D", "Not blue!", "+$197" },
    }
do
    customer.ActivateForPlayer(owner)
    local model = customer.SpawnForPlayer(owner)
    flush()
    setup(model and customer.GetSnapshot(owner).Ready, "customer at counter")
    if index == 1 then
        setup(customer.SetForcedReaction(owner, "Disgust"), "force independent reaction")
    end
    local before = data.GetCash(owner)
    check(not customer.Serve(owner) and data.GetCash(owner) == before, "no cup cannot pay")
    cup = { Ingredients = { case[1], "Banana", "Banana" }, Tags = { "Blue" }, BlendId = "cup-" .. index }
    check(customer.Serve(owner, model), "serve consumes assigned cup")
    check(
        not nestedServe and consumed == index and completed == index,
        "reentrant serve cannot double-consume or complete"
    )
    check(
        data.GetCash(owner) == before + case[2] and model:GetAttribute("Grade") == case[3],
        "server awards correct cash and grade"
    )
    if index == 1 then
        check(model:GetAttribute("Reaction") == "Disgust", "cosmetic reaction does not change payout or grade")
    end
    local graphic = model:FindFirstChild("CustomerResult", true)
    check(
        graphic and string.find(graphic:FindFirstChild("Result").Text, case[5], 1, true) ~= nil,
        "serve graphic shows actual award"
    )
    flush()
    check(
        model:FindFirstChild("OrderBubble", true):FindFirstChildOfClass("TextLabel").Text == case[4],
        "assigned dialogue remains separate"
    )
    check(not customer.Serve(owner, model) and data.GetCash(owner) == before + case[2], "replayed serve cannot pay")
    customer.DeactivateForPlayer(owner)
end
