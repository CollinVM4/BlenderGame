-- Real CustomerService with the shared fake Roblox boundary.
cache.StudioServices = {
    Wrap = function(_, service)
        return service
    end,
}
env.math = table.clone(math)
local function player(name)
    local owner = instance("Player")
    owner.Name = name
    owner.UserId = #allInstances
    owner.Parent = services.Players
    owner.Near = true
    return owner
end
local data = loadModule("PlayerDataService")
local requests = loadModule("CustomerRequests")
local customer = loadModule("CustomerService")
local refs = {}
for _, name in { "CustomerSpawn", "CustomerCounter", "CustomerExit" } do
    refs[name] = instance("Part")
    refs[name].CFrame = frame()
end
customer.Init({
    PlayerDataService = data,
    TycoonService = {
        GetReference = function(_, name)
            return refs[name]
        end,
    },
}, function() end, function()
    return true
end)
local ids = {}
for _, request in requests do
    check(not ids[request.Id], "request IDs are unique")
    ids[request.Id] = true
    check(
        type(request.MinJumpTier) == "number"
            and request.MinJumpTier >= 0
            and request.MinJumpTier <= 3
            and request.MinJumpTier == math.floor(request.MinJumpTier),
        "every request has a valid minimum jump tier"
    )
end
-- Exercise actual arrival/refresh selection with every random index, not statistical sampling.
do
    local owner = player("RequestTiers")
    data.AddPlayer(owner)
    data.SetCash(owner, 10000)
    local savedRequests = table.clone(requests)
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
            check(data.PurchaseUpgrade(owner, "Jump"), "purchase authoritative jump upgrade")
        end
        check(owner:GetAttribute("JumpLevel") == tier, "existing progression publishes zero-based tier")
        for roll = 1, tier + 1 do
            env.math.random = function(low, high)
                check(low == 1 and high == tier + 1, "random bounds contain exactly eligible requests")
                return roll
            end
            local model = customer.SpawnForPlayer(owner)
            check(model ~= nil, "eligible player can spawn")
            flush()
            flush()
            check(customer.GetSnapshot(owner).RequestId == "Tier" .. (roll - 1), "arrival selects eligible request")
            customer:RefreshOrder(model)
            flush()
            check(customer.GetSnapshot(owner).RequestId == "Tier" .. (roll - 1), "refresh selects eligible request")
            customer.RemovePlayer(owner)
        end
    end
    env.math.random = function()
        error("empty pool must not call random")
    end
    table.clear(requests)
    check(
        customer.SpawnForPlayer(owner) == nil and customer.GetSnapshot(owner) == nil,
        "empty pool creates no customer"
    )
    -- Only locked requests is also an empty eligible pool.
    owner:SetAttribute("JumpLevel", 0)
    requests[1] = savedRequests[1]
    local savedTier = requests[1].MinJumpTier
    requests[1].MinJumpTier = 1
    check(customer.SpawnForPlayer(owner) == nil, "all locked requests fail safely")
    requests[1].MinJumpTier = savedTier
    -- Configuration/progression can change during arrival or before a refresh.
    local arriving = customer.SpawnForPlayer(owner)
    table.clear(requests)
    flush()
    check(arriving.Destroyed and customer.GetSnapshot(owner) == nil, "empty arrival cleans up without an order")
    requests[1] = savedRequests[1]
    env.math.random = savedRandom
    local ready = customer.SpawnForPlayer(owner)
    flush()
    flush()
    table.clear(requests)
    env.math.random = function()
        error("empty refresh must not call random")
    end
    customer:RefreshOrder(ready)
    check(ready.Destroyed and customer.GetSnapshot(owner) == nil, "empty refresh removes stale order")
    check(not customer.Serve(owner), "empty pool cannot be served or paid")
    check(warnings == 4, "all empty pool paths warn")
    for _, request in savedRequests do
        table.insert(requests, request)
    end
    env.math.random, env.warn = savedRandom, savedWarn
    data.RemovePlayer(owner)
end
print(string.format("PASS: %d customer request assertions (mocked Roblox boundary).", count))
