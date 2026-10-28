local ids = {}
for _, request in requests do
    check(not ids[request.Id], "request IDs are unique")
    ids[request.Id] = true
    if not request.NPCOnly then
        check(
            table.find({ "Color", "Trait", "Combo", "Restriction", "Ingredient", "Recipe" }, request.RequestGroup)
                ~= nil,
            "regular request has a supported group: " .. request.Id
        )
        check(request.SimilarityKeys and #request.SimilarityKeys > 0, "regular request has similarity concepts")
    end
    check(
        type(request.MinJumpTier) == "number"
            and request.MinJumpTier >= 0
            and request.MinJumpTier <= 3
            and request.MinJumpTier == math.floor(request.MinJumpTier),
        "every request has a valid minimum jump tier"
    )
end
-- Joint accessibility uses the same validator as production selection.
local function definition(tags, slots)
    return {
        Id = "Joint",
        DisplayText = "Joint",
        RequiredTags = tags,
        RequiredIngredients = slots,
        BasePayout = 250,
        MinJumpTier = 3,
    }
end
local function eligible(request, tier)
    return #customer.ValidateRequestDefinition(request, tier) == 0
end
for tier = 0, 3 do
    check(
        not eligible(definition({}, { "Apple", "Apple", "Apple", "Apple" }), tier),
        "four slots exceed blender capacity at every tier"
    )
    check(
        not eligible(definition({ "Milk", "Spicy" }, { "Apple", "Banana" }), tier),
        "two slots plus two distinct carriers cannot fit"
    )
end
check(
    eligible(definition({ "Red", "Milk" }, { "Apple", "Banana" }), 2),
    "slot covers red while one remaining unit covers milk"
)
check(
    not eligible(definition({ "Milk" }, nil), 0) and eligible(definition({ "Milk" }, nil), 2),
    "JL2-only tag requires actual access"
)
check(eligible(definition({}, { "Apple", "Apple", "Apple" }), 0), "repeated IDs can use three physical copies")
check(eligible(definition({}, nil), 0), "requirement-free request remains eligible")
check(eligible(definition({ "*" }, nil), 0), "tag groups expand through evaluator matching")
local alternatives = definition({ "Milk" }, { { "Crab", "Apple" }, "Banana" })
check(eligible(alternatives, 2), "alternative slots choose a jointly satisfiable cover")
local blocked = definition({ "Red" }, { "Apple" })
blocked.ForbiddenIngredients = { "Apple" }
check(not eligible(blocked, 3), "prohibited ingredients cannot fulfill a required slot")

-- Exhaust the authored reachable pool with an injected request-index sequence.
-- Repeated picks remain available across arrivals and refresh; group metadata has no weighting.
do
    local owner = player("UniformOrders")
    data.AddPlayer(owner)
    assignTestSession(owner)
    local savedRandom = env.math.random
    for tier = 0, 3 do
        setTestJump(owner, tier)
        local pool = {}
        for _, request in requests do
            if not request.NPCOnly and not request.Wildcard and eligible(request, tier) then
                table.insert(pool, request)
            end
        end
        setup(#pool > 0, "authored accessible pool exists")
        if tier == 0 then
            local complex = false
            for _, request in pool do
                complex = complex or request.MinJumpTier > 0
            end
            check(complex, "tier zero can draw authored complex requests despite their labels")
        end
        for index, expected in pool do
            env.math.random = function(low, high)
                if low == 1 and high == #pool then
                    return index
                end
                return low or 0.99
            end
            local model = spawnFor(owner)
            flush()
            flush()
            setup(model ~= nil, "accessible regular spawns")
            check(
                customer.GetSnapshot(owner).RequestId == expected.Id,
                "uniform whole-pool index selects " .. expected.Id
            )
            customer:RefreshOrder(model)
            check(customer.GetSnapshot(owner).RequestId == expected.Id, "recency permits immediate repeat")
            model:Destroy()
            flush()
        end
        customer.CleanupSession(sessionTestAuthority.GetSessionId(owner))
    end
    env.math.random = savedRandom
end
-- NPCOnly, explicit wildcard and unreachable definitions cannot enter a regular pool.
do
    local saved = table.clone(requests)
    local owner = player("ExcludedOrders")
    data.AddPlayer(owner)
    local only = { Id = "Only", DisplayText = "Only", RequiredTags = { "Red" }, BasePayout = 250, MinJumpTier = 3 }
    table.clear(requests)
    table.insert(requests, only)
    local npc = table.clone(only)
    npc.Id, npc.NPCOnly = "NPC", true
    table.insert(requests, npc)
    local wild = table.clone(only)
    wild.Id, wild.Wildcard = "ExplicitWildcard", true
    table.insert(requests, wild)
    local locked = definition({ "Milk" }, nil)
    locked.Id = "Locked"
    table.insert(requests, locked)
    local oversized = definition({}, { "Apple", "Apple", "Apple", "Apple" })
    table.insert(requests, oversized)
    local savedRandom = env.math.random
    env.math.random = function(low, high)
        return high or 0.99
    end
    local model = spawnFor(owner)
    flush()
    flush()
    check(
        model and customer.GetSnapshot(owner).RequestId == "Only",
        "regular pool excludes NPC/wildcard/unreachable/unblendable"
    )
    customer.CleanupSession(sessionTestAuthority.GetSessionId(owner))
    table.clear(requests)
    for _, request in saved do
        table.insert(requests, request)
    end
    env.math.random = savedRandom
end

-- An empty accessible pool fails safely on spawn and refresh.
do
    local saved = table.clone(requests)
    local owner = player("EmptyPool")
    data.AddPlayer(owner)
    table.clear(requests)
    local savedWarn = env.warn
    env.warn = function() end
    check(spawnFor(owner) == nil, "empty pool does not spawn a customer")
    requests[1] =
        { Id = "Temporary", DisplayText = "Temporary", RequiredTags = { "Red" }, BasePayout = 250, MinJumpTier = 0 }
    local model = spawnFor(owner)
    flush()
    flush()
    setup(model ~= nil, "refresh fixture has a valid order")
    table.clear(requests)
    customer:RefreshOrder(model)
    check(model.Destroyed and customer.GetSnapshot(owner) == nil, "empty refresh removes stale order")
    check(not customer.Serve(owner), "empty refresh cannot be served or paid")
    env.warn = savedWarn
    table.clear(requests)
    for _, request in saved do
        table.insert(requests, request)
    end
    customer.CleanupSession(sessionTestAuthority.GetSessionId(owner))
end

-- The real serve path uses forbidden metadata, authored feedback, and one payment.
do
    local owner = player("AdvancedServing")
    data.AddPlayer(owner)
    assignTestSession(owner)
    setTestJump(owner, 3)
    local savedRequests = table.clone(requests)
    local selected
    for _, request in requests do
        if request.Id == "SweetColdNoSpicy" then
            selected = request
        end
    end
    table.clear(requests)
    table.insert(requests, selected)
    local savedRandom = env.math.random
    env.math.random = function(low)
        return low or 0
    end
    local cup
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
    }, function() end, function()
        return true
    end)
    for _, example in
        {
            { { "Strawberry", "Ice", "Banana" }, true },
            { { "Strawberry", "Ice", "Chili_Pepper" }, false },
            { { "Strawberry", "Banana", "Banana" }, false },
        }
    do
        local model = spawnFor(owner)
        flush()
        flush()
        cup = { Ingredients = example[1], Tags = { "Sweet", "Cold" }, BlendId = "advanced" }
        local evaluation = customer.EvaluateOrder(cup, selected)
        local expected = customer.CalculateOrderPayout(owner, cup, selected, evaluation)
        local cash = data.GetCash(owner)
        check(customer.Serve(owner), "advanced serving completes")
        flush()
        check(data.GetCash(owner) == cash + expected, "advanced validation controls payment")
        check(
            model:FindFirstChild("OrderBubble", true):FindFirstChildOfClass("TextLabel").Text
                == (if example[2] then selected.GoodResponse else selected.BadResponse),
            "advanced result uses authored response"
        )
        check(cup == nil and not customer.Serve(owner), "advanced cup consumed once and cannot be served twice")
        customer.CleanupSession(sessionTestAuthority.GetSessionId(owner))
    end
    table.clear(requests)
    for _, request in savedRequests do
        table.insert(requests, request)
    end
    env.math.random = savedRandom
    data.RemovePlayer(owner)
end

-- Template recency remains independent of uniform prompt selection.
do
    local saved = table.clone(requests)
    table.clear(requests)
    requests[1] = { Id = "Repeat", DisplayText = "Repeat", RequiredTags = { "Red" }, BasePayout = 250, MinJumpTier = 0 }
    local savedRandom, savedChance = env.math.random, requestConfig.SpecialCustomerChance
    env.math.random = function(low)
        return low or 0
    end
    requestConfig.SpecialCustomerChance = 0
    local folder = instance("Folder")
    folder.Name, folder.Parent = "CustomerNPCs", storage
    local regular = instance("Folder")
    regular.Name, regular.Parent = "Regular", folder
    for index = 1, 4 do
        local model = instance("Model")
        model.Name, model.Parent = "Template" .. index, regular
        model:SetAttribute("SourceProbe", index)
        local clone = model.Clone
        function model:Clone()
            local copy = clone(self)
            copy:FindFirstChildOfClass("Humanoid").Died = signal()
            return copy
        end

        local root = instance("Part")
        root.Name, root.Parent = "HumanoidRootPart", model
        local humanoid = instance("Humanoid")
        humanoid.Parent, humanoid.RigType = model, { Name = "R15" }
    end
    local owner = player("TemplateHistory")
    data.AddPlayer(owner)
    for turn = 1, 8 do
        local model = spawnFor(owner)
        flush()
        flush()
        check(model:GetAttribute("SourceProbe") == (turn - 1) % 4 + 1, "template recency remains unchanged")
        check(customer.GetSnapshot(owner).RequestId == "Repeat", "repeated regular prompt remains eligible")
        model:Destroy()
        flush()
    end
    customer.CleanupSession(sessionTestAuthority.GetSessionId(owner))
    folder:Destroy()
    table.clear(requests)
    for _, request in saved do
        table.insert(requests, request)
    end
    env.math.random, requestConfig.SpecialCustomerChance = savedRandom, savedChance
end
print("PASS: reachable uniform request selection")

-- Reporting only: max-tier ground-floor demand from authored slots and tag carriers.
do
    local catalog = loadModule("Ingredients")
    local evaluation = loadModule("CustomerOrderEvaluation")
    local count, eligibleCount = 0, 0
    for _, request in requests do
        if request.NPCOnly or request.Wildcard or not eligible(request, 3) then
            continue
        end
        eligibleCount += 1
        local reasons = {}
        for _, requirement in request.RequiredIngredients or {} do
            local alternatives = if type(requirement) == "string" then { requirement } else requirement
            local groundOnly = #alternatives > 0
            for _, id in alternatives do
                groundOnly = groundOnly and catalog[id].JumpLocation == 0
            end
            if groundOnly then
                table.insert(reasons, table.concat(alternatives, "/"))
            end
        end
        for _, tag in request.RequiredTags do
            local found, onlyGround = false, true
            for _, ingredient in catalog do
                local tags = {}
                for _, member in ingredient.Tags do
                    tags[string.lower(member)] = true
                end
                if evaluation.MatchesTag(tags, tag) then
                    found = true
                    onlyGround = onlyGround and ingredient.JumpLocation == 0
                end
            end
            if found and onlyGround then
                table.insert(reasons, "tag:" .. tag)
            end
        end
        if #reasons > 0 then
            count += 1
            print("GROUND-DEMAND " .. request.Id .. ": " .. table.concat(reasons, ", "))
        end
    end
    print(string.format("GROUND-DEMAND TOTAL %d / %d eligible regular requests", count, eligibleCount))
end
