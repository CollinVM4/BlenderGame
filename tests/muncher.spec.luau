-- Conversion settlement owns these contracts; physical eligibility lives in muncher-vacuum.
local roll, rolls = 0, 0
env.Random = {
    new = function()
        return {
            NextNumber = function()
                rolls += 1
                return roll
            end,
        }
    end,
}
local muncher = loadModule("MuncherService")
local config = loadModule("Muncher")
local output = loadModule("MuncherOutput")
local outputPlacement = output.Placement
local at = frame()
output.Placement = function()
    return at, vec(0, 0, 0)
end
dependency.MuncherService = muncher
muncher.Init(dependency)
local p = player(3)
local authority = dependency.TycoonService
local plot = authority.GetPlot(p)
local model = instance("Model")
model.Name, model.Parent = "Muncher", plot
local input, pad = part("InputZone", model), part("PurchasePoint1", model)
input.Position = vec(0, 0, 0)
local function thrown(id)
    carry(p, id or "Apple")
    local object = inventory.ThrowHeld(p)
    local root = cache.WorldUtil.Part(object)
    root.Position, root.CFrame = input.Position, frame(input.Position)
    root.GetConnectedParts = function()
        return {}
    end
    return object
end
local function feed(object)
    return muncher.TryStartConversion(p, input, object, "WorldVacuum", nil)
end
local function finish()
    now += config.ChewSeconds
    muncher.Step()
    now += config.SpitSeconds
end
local function unlock()
    authority.SetCash(p, 100100)
    setup(muncher.TryPurchase(p, pad, nil), "purchase")
    check(authority.GetCash(p) == 100, "exact purchase cost")
    check(not muncher.TryPurchase(p, pad, nil), "duplicate purchase rejected")
    check(not muncher.CompleteReveal(p, model), "reveal cannot complete early")
    now += config.RevealSeconds
    setup(muncher.CompleteReveal(p, model), "reveal complete")
end
muncher.Reset(p)
local apple = thrown()
check(not feed(apple) and ingredients.GetRecord(apple) ~= nil, "locked machine preserves world input")
authority.SetCash(p, 99999)
local ok, reason = muncher.TryPurchase(p, pad, nil)
check(not ok and reason == "InsufficientCash", "insufficient shared cash preserved")
unlock()
carry(p, "Banana")
check(muncher.TryFeed == nil, "carried feed API retired")
check(
    not muncher.TryStartConversion(p, input, nil, "CarriedPrompt", nil) and inventory.GetCarryCount(p) == 1,
    "no hidden carried feed fallback"
)
inventory.ClearHeld(p)
local spawnCount, spawned = 0, {}
local originalSpawn = ingredients.Spawn
ingredients.Spawn = function(...)
    local args = { ... }
    local object = originalSpawn(...)
    if object and args[5] and args[5].MuncherImmune then
        spawnCount += 1
        table.insert(spawned, object)
    end
    return object
end
check(feed(apple), "physical ingredient accepted")
check(ingredients.GetRecord(apple) == nil and spawnCount == 0, "consume once and delay output")
check(muncher.GetSnapshot(p).Phase == "Processing", "authoritative busy state")
check(
    muncher.GetSnapshot(p).OutputId == "Rock" and muncher.GetSnapshot(p).ResultKind == "Lose",
    "committed snapshot publishes actual output and catalog loss before settlement"
)
local extra = thrown("Banana")
check(not feed(extra) and ingredients.GetRecord(extra) ~= nil and rolls == 1, "busy attempt cannot consume or reroll")
check(model:GetAttribute("BusyUntil") == now + config.BusySeconds, "busy rejection projects brief feedback")
local sequence = muncher.GetSnapshot(p).Sequence
finish()
check(spawnCount == 1 and ingredients.GetRecord(spawned[1]).Id == "Rock", "predetermined collectible")
check(not ingredients.GetRecord(spawned[1]).Item.IsRipe, "output is fresh")
muncher.Step()
check(
    spawnCount == 1 and muncher.GetSnapshot(p).Phase == "Idle" and muncher.GetSnapshot(p).Sequence == sequence,
    "rejection and replay cannot change settlement"
)
check(muncher.GetCashMultiplier(p) == 1, "unrelated payouts unchanged")
check(feed(extra), "rejected world item remains usable")
p.Character:FindFirstChildOfClass("Humanoid").Health = 0
muncher.RemovePlayer(p)
finish()
check(spawnCount == 2, "death and disconnect cannot strand committed reward")
p.Character:FindFirstChildOfClass("Humanoid").Health = 100
roll = 0.99999
check(feed(thrown()), "jackpot selected at commit")
roll = 0
finish()
check(ingredients.GetRecord(spawned[3]).Id == "Dragon_Fruit", "delayed reward cannot reroll")
for _, mode in { "nil", "published-error", "placement" } do
    local object = thrown()
    local real, failed = ingredients.Spawn, false
    ingredients.Spawn = function(...)
        if not failed then
            failed = true
            if mode == "nil" then
                return nil
            end
            if mode == "published-error" then
                real(...)
                error("transient after publication")
            end
        end
        return real(...)
    end
    if mode == "placement" then
        output.Placement = function()
            error("blocked landing")
        end
    end
    setup(feed(object), "recoverable feed")
    now += config.ChewSeconds
    muncher.Step()
    check(muncher.GetSnapshot(p).Phase == "Spitting", "failed spawn keeps machine busy")
    local before = spawnCount
    local rejected = thrown()
    local beforeRolls = rolls
    check(
        not feed(rejected) and ingredients.GetRecord(rejected) ~= nil and rolls == beforeRolls,
        "spitting rejects without consuming or rerolling"
    )
    output.Placement = function()
        return at, vec(0, 0, 0)
    end
    now += config.RetrySeconds
    muncher.Step()
    check(muncher.GetSnapshot(p).Phase == "Idle" and spawnCount == before + 1, "retry settles same reward")
    ingredients.Spawn = real
    now += config.SpitSeconds
end
setup(feed(thrown()), "feed before reset")
local before = spawnCount
muncher.Reset(p)
finish()
check(
    spawnCount == before + 1 and not muncher.GetSnapshot(p).Purchased,
    "reset preserves committed reward debt without unlocking replacement"
)
-- Actual placement resolver: a clear arc spits; an obstruction uses a grounded local position.
output.Placement = outputPlacement
local casts = 0
workspaceFake.Gravity = 196.2
workspaceFake.Raycast = function()
    return { Position = vec(2, 0, 2) }
end
workspaceFake.Spherecast = function()
    casts += 1
    return nil
end
local clearAt, speed = output.Placement(model, frame())
check(clearAt ~= nil and speed.Y > 0 and casts == 6, "clear arc has bounded upward impulse")
workspaceFake.Spherecast = function()
    casts += 1
    return if casts == 1 then {} else nil
end
workspaceFake.Raycast = function()
    return { Position = vec(2, 0, 2) }
end
casts = 0
local fallbackAt, fallbackSpeed = output.Placement(model, frame())
check(fallbackAt.Position.Y == 1.5 and fallbackSpeed.Y == 0, "obstructed arc drops above nearby floor")

workspaceFake.Raycast = function()
    return nil
end
workspaceFake.Spherecast = function()
    return nil
end
output.Placement = function()
    return at, vec(0, 0, 0)
end
unlock()
check(feed(thrown("PlayerHead")), "dynamic head follows physical path")
finish()
local reward = spawned[#spawned]
check(
    ingredients.GetRecord(reward).Id ~= "PlayerHead"
        and reward:GetAttribute("SourceUserId") == nil
        and reward:GetAttribute("SourceDisplayName") == nil
        and reward:GetAttribute("SourceUsername") == nil,
    "reward never inherits player identity"
)
setup(feed(thrown()), "feed before teardown")
local teardownCount = spawnCount
muncher.CleanupSession(authority.GetSessionId(p))
finish()
check(spawnCount == teardownCount + 1 and muncher.GetSnapshot(p) == nil, "teardown preserves committed output")
muncher.Reset(p)
unlock()
local retry = thrown()
local pool, originalId = config.RewardPools[1], config.RewardPools[1][1].Id
pool[1].Id = "PlayerHead"
check(not feed(retry) and ingredients.GetRecord(retry) ~= nil, "invalid configuration preserves world input")
pool[1].Id = originalId
check(feed(retry), "configuration recovery releases lifecycle lock")
finish()
output.Placement = outputPlacement
workspaceFake.Raycast = function()
    return { Position = vec(2, 0, 2) }
end
-- Native floor contact preserves the normal spit path; fully blocked fallback retains debt.
workspaceFake.Spherecast = function()
    return { Normal = vec(0, 1, 0) }
end
local floorAt, floorSpeed = output.Placement(model, frame())
check(floorAt ~= nil and floorSpeed.Y > 0, "descending floor contact remains a normal spit")
workspaceFake.Spherecast = function()
    return { Normal = vec(1, 0, 0) }
end
workspaceFake.GetPartBoundsInBox = function()
    return { input }
end
check(not pcall(output.Placement, model, frame()), "blocked fallback never publishes inaccessible output")
workspaceFake.GetPartBoundsInBox = function()
    return {}
end
output.Placement = function()
    return at, vec(0, 0, 0)
end
-- Actual component retires authored prompts and never creates a replacement.
muncher.Reset(p)
local cleanup
workspaceFake.GetPartBoundsInRadius = function()
    return {}
end
pad.Touched = signal()
cache.WorldUtil.BindTag = function(_, attach)
    cleanup = attach(plot)
end
local legacy = instance("ProximityPrompt")
legacy.Name, legacy.Parent = "FeedMuncher", input
legacy:SetAttribute("MuncherPrompt", true)
loadModule("MuncherComponent").Init(dependency)
unlock()
heartbeat:Fire(0.1)
check(input:FindFirstChild("FeedMuncher") == nil, "no E/gamepad/touch feed prompt remains")
for _, child in model:GetDescendants() do
    check(child:GetAttribute("MuncherPrompt") == nil, "component never creates marked feed prompt")
end
cleanup()
