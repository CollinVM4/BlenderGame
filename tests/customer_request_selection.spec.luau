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
-- Exercise actual arrival/refresh selection with every random index, not statistical sampling.
for id, mapping in requestConfig.NPCs do
    check(ids[mapping.RequestId], "authored NPC RequestId resolves: " .. id)
end
do
    local owner = player("RequestTiers")
    data.AddPlayer(owner)
    assignTestSession(owner)
    data.SetCash(owner, 200000)
    local savedRequests = table.clone(requests)
    local savedWindow = requestConfig.RegularRequestRecencyWindow
    requestConfig.RegularRequestRecencyWindow = 0 -- Exhaust eligibility independently of recency below.
    local savedRandom, savedWarn = env.math.random, env.warn
    local warnings = 0
    env.warn = function(message)
        check(string.find(message, "No eligible requests", 1, true) ~= nil, "empty pool warning explains failure")
        warnings += 1
    end
    table.clear(requests)
    for tier = 0, 3 do
        table.insert(requests, {
            Id = "Tier" .. tier,
            DisplayText = "Tier " .. tier,
            RequiredTags = { "Red" },
            BasePayout = 25,
            MinJumpTier = tier,
        })
    end
    for tier = 0, 3 do
        if tier > 0 then
            check(buyTestUpgrade(data, owner, "Jump"), "purchase authoritative jump upgrade")
        end
        check(owner:GetAttribute("JumpLevel") == tier, "existing progression publishes zero-based tier")
        for roll = 1, tier + 1 do
            env.math.random = function(low, high)
                check(low == 1 and high == tier + 1, "random bounds contain exactly eligible requests")
                return roll
            end
            local model = spawnFor(owner)
            check(model ~= nil, "eligible player can spawn")
            flush()
            flush()
            check(customer.GetSnapshot(owner).RequestId == "Tier" .. (roll - 1), "arrival selects eligible request")
            customer:RefreshOrder(model)
            flush()
            check(customer.GetSnapshot(owner).RequestId == "Tier" .. (roll - 1), "refresh selects eligible request")
            customer.CleanupSession(sessionTestAuthority.GetSessionId(owner))
        end
    end
    env.math.random = function()
        error("empty pool must not call random")
    end
    table.clear(requests)
    check(spawnFor(owner) == nil and customer.GetSnapshot(owner) == nil, "empty pool creates no customer")
    -- Only locked requests is also an empty eligible pool.
    setTestJump(owner, 0)
    requests[1] = savedRequests[1]
    local savedTier = requests[1].MinJumpTier
    requests[1].MinJumpTier = 1
    check(spawnFor(owner) == nil, "all locked requests fail safely")
    requests[1].MinJumpTier = savedTier
    -- Configuration/progression can change during arrival or before a refresh.
    env.math.random = savedRandom
    local arriving = spawnFor(owner)
    table.clear(requests)
    flush()
    check(
        not arriving.Destroyed and customer.GetSnapshot(owner).RequestId ~= nil,
        "queued request survives catalog changes during arrival"
    )
    arriving:Destroy()
    requests[1] = savedRequests[1]
    env.math.random = savedRandom
    local ready = spawnFor(owner)
    flush()
    flush()
    table.clear(requests)
    env.math.random = function()
        error("empty refresh must not call random")
    end
    customer:RefreshOrder(ready)
    check(ready.Destroyed and customer.GetSnapshot(owner) == nil, "empty refresh removes stale order")
    check(not customer.Serve(owner), "empty pool cannot be served or paid")
    check(warnings == 3, "all empty pool paths warn")
    for _, request in savedRequests do
        table.insert(requests, request)
    end
    env.math.random, env.warn = savedRandom, savedWarn
    requestConfig.RegularRequestRecencyWindow = savedWindow
    data.RemovePlayer(owner)
end
-- Exhaust the authored pool at each tier, including all advanced definitions.
do
    local owner = player("AuthoredRequestTiers")
    data.AddPlayer(owner)
    assignTestSession(owner)
    local savedRandom = env.math.random
    for tier = 0, 3 do
        setTestJump(owner, tier)
        local eligible = {}
        for _, request in requests do
            if not request.NPCOnly and request.MinJumpTier <= tier then
                table.insert(eligible, request)
            end
        end
        local groups, names = {}, {}
        for _, request in eligible do
            if not groups[request.RequestGroup] then
                groups[request.RequestGroup] = {}
                table.insert(names, request.RequestGroup)
            end
            table.insert(groups[request.RequestGroup], request)
        end
        for _, expected in eligible do
            local groupDraw = #names > 1
            env.math.random = function(low, high)
                if groupDraw then
                    groupDraw = false
                    check(low == 1 and high == #names, "group draw contains exactly unlocked groups")
                    return table.find(names, expected.RequestGroup)
                end
                check(low == 1 and high == #groups[expected.RequestGroup], "request draw stays inside chosen group")
                return table.find(groups[expected.RequestGroup], expected)
            end
            local model = spawnFor(owner)
            flush()
            flush()
            check(
                customer.GetSnapshot(owner).RequestId == expected.Id,
                "authored request remains selectable: " .. expected.Id
            )
            customer.CleanupSession(sessionTestAuthority.GetSessionId(owner))
        end
    end
    env.math.random = savedRandom
    data.RemovePlayer(owner)
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
        local expected = customer.CalculateOrderPayout(owner, cup, selected, example[2])
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

-- Recency contracts through real spawn/arrival/refresh, with deterministic first-candidate rolls.
do
    local savedRequests = table.clone(requests)
    local savedRandom, savedChance = env.math.random, requestConfig.SpecialCustomerChance
    local savedMapping = requestConfig.NPCs.steak.RequestId
    table.clear(requests)
    for index = 1, 6 do
        table.insert(requests, {
            Id = "Recent" .. index,
            DisplayText = "Same text",
            RequiredTags = { "Red" },
            BasePayout = 25,
            MinJumpTier = if index == 5 then 3 else 0,
            NPCOnly = index == 6,
        })
    end
    env.math.random = function(low)
        return low or 0
    end
    requestConfig.SpecialCustomerChance = 0
    local function child(class, name, parent)
        local item = instance(class)
        item.Name, item.Parent = name, parent
        if class == "Humanoid" then
            item.RigType = { Name = "R15" }
        end
        return item
    end
    local folder = child("Folder", "CustomerNPCs", storage)
    local regular = child("Folder", "Regular", folder)
    local special = child("Folder", "Special", folder)
    local templates = {}
    for index = 1, 5 do
        local model = child("Model", "Template" .. index, if index == 5 then special else regular)
        child("Humanoid", "Humanoid", model)
        child("Part", "HumanoidRootPart", model)
        model:SetAttribute("SourceProbe", index)
        if index == 5 then
            model:SetAttribute("CustomerId", "steak")
        end
        templates[index] = model
    end
    local a, b = player("RecencyA"), player("RecencyB")
    local function spawn(owner)
        local model = spawnFor(owner)
        setup(model ~= nil, "recency customer spawns")
        flush()
        flush()
        return model, customer.GetSnapshot(owner).RequestId
    end
    local function depart(model)
        model:Destroy() -- Preserve player history between selections.
        flush()
    end
    for turn = 1, 9 do
        customer.BeginDay(a) -- Day boundaries do not erase regular history.
        local model, id = spawn(a)
        local expected = (turn - 1) % 4 + 1
        check(model:GetAttribute("SourceProbe") == expected, "template waits for three intervening regular selections")
        check(
            id == "Recent" .. expected,
            "stable request IDs remain independent despite shared tags/text; locked/NPCOnly excluded"
        )
        depart(model)
    end
    local modelB, idB = spawn(b)
    check(
        modelB:GetAttribute("SourceProbe") == 1 and idB == "Recent1",
        "another player starts with independent histories"
    )
    depart(modelB)
    local modelA, idA = spawn(a)
    check(modelA:GetAttribute("SourceProbe") == 2 and idA == "Recent2", "other player cannot advance either history")
    customer:RefreshOrder(modelA)
    check(customer.GetSnapshot(a).RequestId == "Recent3", "refresh advances only request history")
    depart(modelA)
    modelA, idA = spawn(a)
    check(
        modelA:GetAttribute("SourceProbe") == 3 and idA == "Recent4",
        "template and request histories advance independently"
    )
    depart(modelA)
    requestConfig.SpecialCustomerChance = 1
    for _, forcedId in { "Recent4", "Recent6" } do
        requestConfig.NPCs.steak.RequestId = forcedId
        now += 300 -- Continuous cooldown, independent of BeginDay.
        customer.BeginDay(a)
        modelA, idA = spawn(a)
        check(
            modelA:GetAttribute("SourceProbe") == 5 and idA == forcedId,
            "special bypasses recent request and NPCOnly exclusion"
        )
        customer:RefreshOrder(modelA)
        check(customer.GetSnapshot(a).RequestId == forcedId, "special refresh preserves forced request")
        depart(modelA)
        -- Existing special immediate-repeat rule needs a regular between specials.
        requestConfig.SpecialCustomerChance = 0
        modelA, idA = spawn(a)
        check(
            modelA:GetAttribute("SourceProbe") == (if forcedId == "Recent4" then 4 else 1),
            "special does not advance template history"
        )
        check(
            idA == (if forcedId == "Recent4" then "Recent1" else "Recent2"),
            "special does not advance request history"
        )
        depart(modelA)
        requestConfig.SpecialCustomerChance = 1
    end
    requestConfig.SpecialCustomerChance = 0
    customer.CleanupSession(sessionTestAuthority.GetSessionId(a))
    modelA, idA = spawn(a)
    check(modelA:GetAttribute("SourceProbe") == 1 and idA == "Recent1", "player removal clears both histories")
    depart(modelA)
    -- Group and similarity contracts share the real plot-session selection lifecycle.
    local function definition(id, group, keys, tier)
        return {
            Id = id,
            DisplayText = id,
            RequestGroup = group,
            SimilarityKeys = keys,
            RequiredTags = { "Red" },
            BasePayout = 25,
            MinJumpTier = tier or 0,
        }
    end
    local function catalog(definitions)
        customer.CleanupSession(sessionTestAuthority.GetSessionId(a))
        table.clear(requests)
        for _, request in definitions do
            table.insert(requests, request)
        end
    end
    local function expect(id, message)
        local model, selected = spawn(a)
        check(selected == id, message)
        depart(model)
    end
    catalog({
        definition("Red", "Color", { "Red" }),
        definition("Green", "Color", { "Green" }),
        definition("Sweet", "Trait", { "Sweet" }),
        definition("Recipe", "Recipe", { "Apple" }),
        definition("Locked", "Ingredient", {}, 3),
    })
    requests[4].RequiredIngredients = { "Apple", "Banana", "Ice" }
    requests[4].ExactIngredients = true
    expect("Red", "first regular uses available color group")
    expect("Sweet", "next regular prefers a different group despite a fresh color ID")
    expect("Recipe", "both previous groups are avoided and exact recipes select normally")
    expect("Green", "exact ID recency remains stronger than group preference")
    catalog({ definition("Red", "Color", { "Red" }), definition("Green", "Color", { "Green" }) })
    expect("Red", "single group remains selectable")
    expect("Green", "group restriction relaxes while exact ID recency survives")
    expect("Red", "all recent IDs retain existing eligible-pool fallback")
    catalog({
        definition("Red", "Color", { "Red" }),
        definition("RedNoFruit", "Restriction", { "Red", "NoFruit" }),
        definition("MilkNoFruit", "Restriction", { "Milk", "NoFruit" }),
    })
    expect("Red", "seed recent red concept")
    expect("MilkNoFruit", "similarity avoids red across groups when chosen group has an alternative")
    expect("RedNoFruit", "similarity falls back without weakening exact recency")
    catalog({ definition("Red", "Color", { "Red" }), definition("RedNoFruit", "Restriction", { "Red" }) })
    expect("Red", "seed similarity fallback")
    expect("RedNoFruit", "all overlapping similarity keys still allow spawning")
    catalog({
        definition("Red", "Color", { "Red" }),
        definition("Green", "Color", { "Green" }),
        definition("Sweet", "Trait", { "Sweet" }),
        definition("Recipe", "Recipe", { "Apple" }),
    })
    expect("Red", "seed regular history before special")
    requestConfig.NPCs.steak.RequestId = "Sweet"
    requestConfig.SpecialCustomerChance = 1
    now += 300
    local specialModel, specialId = spawn(a)
    check(
        specialModel:GetAttribute("SourceProbe") == 5 and specialId == "Sweet",
        "special still receives mapped request"
    )
    depart(specialModel)
    requestConfig.SpecialCustomerChance = 0
    expect("Sweet", "special does not consume regular group or similarity history")
    expect("Recipe", "special does not evict older regular group history")
    customer.CleanupSession(sessionTestAuthority.GetSessionId(a))
    expect("Red", "session cleanup clears group and similarity history with ID history")
    for index = 2, 4 do
        templates[index]:Destroy()
    end
    table.clear(requests)
    table.insert(
        requests,
        { Id = "Recent1", DisplayText = "Only", RequiredTags = { "Red" }, BasePayout = 25, MinJumpTier = 0 }
    )
    for _ = 1, 5 do
        modelA, idA = spawn(a)
        check(modelA:GetAttribute("SourceProbe") == 1 and idA == "Recent1", "all-recent pools fall back safely")
        depart(modelA)
    end
    customer.CleanupSession(sessionTestAuthority.GetSessionId(a))
    customer.CleanupSession(sessionTestAuthority.GetSessionId(b))
    folder:Destroy()
    table.clear(requests)
    for _, request in savedRequests do
        table.insert(requests, request)
    end
    env.math.random, requestConfig.SpecialCustomerChance = savedRandom, savedChance
    requestConfig.NPCs.steak.RequestId = savedMapping
end

print("PASS: customer request selection and serving contracts")
