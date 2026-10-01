local wildcard = requestConfig.WildcardRequest
check(authoredWildcardChances[1] == 0.60 and authoredWildcardChances[2] == 0.30, "authored wildcard probabilities")
requestConfig.RegularWildcardChance, requestConfig.SpecialWildcardChance = unpack(authoredWildcardChances)
check(wildcard.Wildcard and #wildcard.DisplayTexts >= 5, "explicit wildcard has varied dialogue")
check(#customer.ValidateRequestDefinition(wildcard) == 0, "wildcard definition is valid")
for _, ids in { { "Apple", "Apple", "Apple" }, { "Tire", "Fish", "Ice" } } do
    check(customer.ValidateRequest({ Ingredients = ids }, wildcard), "wildcard accepts player-chosen ingredients")
end
for _, ids in { {}, { "Apple" }, { "Apple", "Ice" }, { "Apple", "Ice", "MadeUp" } } do
    check(not customer.ValidateRequest({ Ingredients = ids }, wildcard), "wildcard rejects invalid smoothie")
end
local constrained = table.clone(wildcard)
constrained.RequiredTags = { "Nonexistent" }
constrained.RequiredIngredients = { "Lemon" }
constrained.ForbiddenTags = { "Fruit" }
constrained.ForbiddenIngredients = { "Apple" }
constrained.ExactIngredients = true
check(
    customer.ValidateRequest({ Ingredients = { "Apple", "Apple", "Apple" } }, constrained),
    "wildcard bypasses all request constraints"
)

local owner = player("WildcardOwner")
data.AddPlayer(owner)
assignTestSession(owner)
setTestJump(owner, 3)
local roll = 0
env.math.random = function(low)
    return low or roll
end
requestConfig.SpecialCustomerChance = 0
local cup, servedGrade
customer.Init({
    GameplayService = {
        RegisterPlotInteraction = function(prompt, callback)
            prompt.Triggered:Connect(callback)
        end,
    },
    PlayerDataService = data,
    TycoonService = requestAuthority(function(_, name)
        return refs[name]
    end),
    BlendService = {
        ConsumeCup = function()
            local result = cup
            cup = nil
            return result
        end,
    },
}, function(_, grade)
    servedGrade = grade
end)
local function spawn()
    local model = spawnFor(owner)
    setup(model ~= nil, "wildcard test customer spawns")
    flush()
    flush()
    return model, customer.GetSnapshot(owner)
end
local function depart(model)
    model:Destroy()
    flush()
end
for _, sample in { { 0, true }, { 0.5999, true }, { 0.60, false }, { 0.9999, false } } do
    roll = sample[1]
    local model, snapshot = spawn()
    check((snapshot.RequestId == wildcard.Id) == sample[2], "regular probability boundary")
    depart(model)
end

-- History must survive more wildcard arrivals than every recency window.
table.clear(requests)
for _, entry in
    {
        { "Red", "Color", "Red" },
        { "Green", "Color", "Green" },
        { "RedNoFruit", "Restriction", "Red" },
        { "MilkNoFruit", "Restriction", "Milk" },
    }
do
    table.insert(requests, {
        Id = entry[1],
        DisplayText = entry[1],
        RequestGroup = entry[2],
        SimilarityKeys = { entry[3] },
        RequiredTags = { "Red" },
        BasePayout = 25,
        MinJumpTier = 0,
    })
end
customer.CleanupSession(sessionTestAuthority.GetSessionId(owner))
roll = 0.9
local model, snapshot = spawn()
check(snapshot.RequestId == "Red", "specific fallback seeds history")
depart(model)
roll = 0
for _ = 1, 5 do
    model, snapshot = spawn()
    check(snapshot.RequestId == wildcard.Id, "wildcard stays outside specific selection")
    depart(model)
end
roll = 0.9
model, snapshot = spawn()
check(snapshot.RequestId == "MilkNoFruit", "wildcards preserve ID, group and similarity history")
depart(model)

local function child(class, name, parent)
    local item = instance(class)
    item.Name, item.Parent = name, parent
    if class == "Humanoid" then
        item.RigType = { Name = "R15" }
    end
    return item
end
local folder = child("Folder", "CustomerNPCs", storage)
local special = child("Folder", "Special", folder)
local template = child("Model", "SpecialSource", special)
template:SetAttribute("CustomerId", "steak")
template:SetAttribute("SourceProbe", "special")
child("Humanoid", "Humanoid", template)
child("Part", "HumanoidRootPart", template)
requestConfig.NPCs.steak.RequestId = "Red"
requestConfig.SpecialCustomerChance = 1
for _, sample in { { 0, true }, { 0.2999, true }, { 0.30, false }, { 0.9999, false } } do
    customer.CleanupSession(sessionTestAuthority.GetSessionId(owner))
    roll = sample[1]
    model, snapshot = spawn()
    check(
        snapshot.CustomerId == "steak" and model:GetAttribute("SourceProbe") == "special",
        "special model and CustomerId survive wildcard assignment"
    )
    check(model:FindFirstChild("CustomerName", true).Text == "Steak", "special display identity survives")
    check(
        snapshot.RequestId == (if sample[2] then wildcard.Id else "Red"),
        "special probability boundary and mapped fallback"
    )
    customer:RefreshOrder(model)
    check(customer.GetSnapshot(owner).RequestId == snapshot.RequestId, "refresh keeps encounter wildcard decision")
    if sample[2] then
        setup(customer.SetForcedReaction(owner, "Disgust"), "force independent special reaction")
        check(not customer.Serve(owner, model), "wildcard cannot serve without a completed server cup")
        cup = { Ingredients = { "Apple", "Apple", "Apple" }, BlendId = "wildcard" }
        local ingredients = loadModule("Ingredients")
        local expected = math.round(3 * ingredients.Apple.Value + wildcard.BasePayout)
        local before = data.GetCash(owner)
        check(customer.Serve(owner, model), "special wildcard consumes a valid cup")
        check(model:GetAttribute("Grade") == nil and servedGrade == nil, "wildcard publishes no letter grade")
        check(data.GetCash(owner) == before + expected, "wildcard pays 1.0x ingredient value plus base")
        check(model:GetAttribute("Reaction") == "Disgust", "special forced reaction remains independent")
        flush()
        check(
            model:FindFirstChild("OrderBubble", true):FindFirstChildOfClass("TextLabel").Text == wildcard.GoodResponse,
            "neutral grade uses success dialogue"
        )
        check(not customer.Serve(owner, model) and data.GetCash(owner) == before + expected, "wildcard pays only once")
    end
    depart(model)
end
print("PASS: wildcard customer contracts")
