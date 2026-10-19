-- Real inventory/registry and session authority; presentation never drives settlement.
local roll = 0
local rolls = 0
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
local input = part("InputZone", model)
local pad = part("PurchasePoint1", model)
local function feed(actor, target, context)
    return muncher.TryFeed(actor or p, target or input, nil, context)
end
local function finish()
    now += config.ChewSeconds + config.SpitSeconds
    muncher.Step()
    now += config.SpitSeconds
end
local function unlock()
    authority.SetCash(p, 100100)
    setup(muncher.TryPurchase(p, pad, authority.GetRequestContext(p)), "purchase")
    check(authority.GetCash(p) == 100, "preserves exact purchase cost")
    check(not muncher.TryPurchase(p, pad, nil), "duplicate purchase rejected")
    check(not muncher.CompleteReveal(p, model), "cannot finish reveal early")
    now += config.RevealSeconds
    setup(muncher.CompleteReveal(p, model), "reveal complete")
end
muncher.Reset(p)
carry(p, "Apple")
check(not feed() and inventory.GetCarryCount(p) == 1, "locked machine preserves input")
authority.SetCash(p, 99999)
local ok, reason = muncher.TryPurchase(p, pad, nil)
check(not ok and reason == "InsufficientCash", "insufficient shared cash preserved")
unlock()
local spawnCount, spawned = 0, {}
local originalSpawn = ingredients.Spawn
ingredients.Spawn = function(...)
    local args = { ... }
    local object = originalSpawn(...)
    if object and args[5] and args[5].BeforePublish then
        spawnCount += 1
        table.insert(spawned, object)
    end
    return object
end
check(feed(), "held ingredient accepted")
check(inventory.GetCarryCount(p) == 0 and spawnCount == 0, "consume exactly one and delay output")
check(muncher.GetSnapshot(p).Phase == "Processing", "authoritative busy state")
carry(p, "Banana")
check(not feed() and inventory.GetCarryCount(p) == 1 and rolls == 1, "duplicate cannot consume or reroll")
finish()
check(spawnCount == 1 and ingredients.GetRecord(spawned[1]).Id == "Rock", "predetermined physical collectible")
check(not ingredients.GetRecord(spawned[1]).Item.IsRipe, "output is fresh")
muncher.Step()
check(spawnCount == 1 and muncher.GetSnapshot(p).Phase == "Idle", "settlement replays cannot duplicate")
check(muncher.GetCashMultiplier(p) == 1, "retired buff API leaves unrelated payouts unchanged")
local outsider = player(3)
carry(outsider, "Apple")
check(not feed(outsider) and inventory.GetCarryCount(outsider) == 1, "visitor cannot consume across plots")
local loose = originalSpawn("Apple", frame(), nil, true)
check(not muncher.TryFeed(p, input, loose, nil) and ingredients.GetRecord(loose), "loose output cannot auto-feed")
local weapon = instance("Tool")
weapon.Parent = p.Character
check(not feed() and inventory.GetCarryCount(p) == 1, "non-ingredient tool blocks hidden ingredient feed")
weapon:Destroy()
inventory.ConsumeHeldIngredient(p, "Banana")
grant(p, "muncher-smoothie")
check(not feed() and inventory.GetHeldSmoothie(p) ~= nil, "smoothie rejected intact")
inventory.ConsumeHeldSmoothie(p)
carry(p, "Apple")
local olderTool = tool(p)
carry(p, "Banana")
p.Character:FindFirstChildOfClass("Humanoid"):EquipTool(olderTool)
check(
    feed() and inventory.GetCarryCount(p) == 1 and inventory.GetHeldIngredientId(p) == "Apple",
    "newest ingredient consumed once"
)
-- Already committed reward survives death/disconnect and interrupted presentation.
p.Character:FindFirstChildOfClass("Humanoid").Health = 0
muncher.RemovePlayer(p)
finish()
check(spawnCount == 2, "death and disconnect cannot strand committed reward")
p.Character:FindFirstChildOfClass("Humanoid").Health = 100
-- Presentation delay never selects the result a second time.
roll = 0.99999
check(feed(), "jackpot selected at commit")
roll = 0
finish()
check(ingredients.GetRecord(spawned[3]).Id == "Dragon_Fruit", "delayed reward cannot reroll")
-- Failure before publication, and an error after publication, both recover without duplicates.
for _, mode in { "nil", "published-error", "placement" } do
    carry(p, "Apple")
    local real = ingredients.Spawn
    local failed = false
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
    setup(feed(), "recoverable feed")
    now += config.ChewSeconds
    muncher.Step()
    check(muncher.GetSnapshot(p).Phase == "Spitting", "failed spawn keeps machine busy")
    local countBefore = spawnCount
    output.Placement = function()
        return at, vec(0, 0, 0)
    end
    now += config.RetrySeconds
    muncher.Step()
    check(muncher.GetSnapshot(p).Phase == "Idle" and spawnCount == countBefore + 1, "retry settles same reward")
    ingredients.Spawn = real
    now += config.SpitSeconds
end
local teammate = player(3)
authority.RemovePlayer(teammate)
setup(authority.JoinSession(teammate, p, authority.GetRequestContext(p)), "join owner")
carry(teammate, "Apple")
check(feed(teammate), "authorized teammate feeds same machine")
carry(p, "Apple")
local countBefore = inventory.GetCarryCount(p)
check(not feed() and inventory.GetCarryCount(p) == countBefore, "simultaneous owner attempt preserves input")
local stale = authority.GetRequestContext(teammate)
setup(authority.Kick(p, teammate, authority.GetRequestContext(p)), "kick during processing")
finish()
check(not feed(teammate, input, stale), "kicked actor cannot feed with stale membership")
-- Death before commitment and throw-first ordering preserve authoritative carry ownership.
p.Character:FindFirstChildOfClass("Humanoid").Health = 0
check(not feed() and inventory.GetCarryCount(p) == countBefore, "dead actor cannot feed")
p.Character:FindFirstChildOfClass("Humanoid").Health = 100
inventory.ClearHeld(p)
carry(p, "Banana")
local thrown = inventory.ThrowHeld(p)
check(thrown ~= nil and not feed(), "throw-first cannot also consume same ingredient")
carry(p, "Banana")
check(feed() and inventory.ThrowHeld(p) == nil, "feed-first cannot throw consumed ingredient")
finish()
-- Reset detaches machine state while preserving the committed reward debt.
carry(p, "Apple")
setup(feed(), "feed before reset")
local before = spawnCount
muncher.Reset(p)
finish()
check(
    spawnCount == before + 1 and not muncher.GetSnapshot(p).Purchased,
    "reset settles reward without unlocking new machine"
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

unlock()
-- A dynamic PlayerHead follows the ordinary ownership path; output has no source metadata.
carry(p, "PlayerHead")
check(feed(), "dynamic PlayerHead is a valid input")
finish()
local reward = spawned[#spawned]
check(
    ingredients.GetRecord(reward).Id ~= "PlayerHead"
        and reward:GetAttribute("SourceUserId") == nil
        and reward:GetAttribute("SourceDisplayName") == nil
        and reward:GetAttribute("SourceUsername") == nil,
    "reward never inherits dynamic player identity"
)
-- Session teardown must not lose a reward or retain the old machine's purchase state.
carry(p, "Apple")
setup(feed(), "feed before session teardown")
local teardownCount = spawnCount
muncher.CleanupSession(authority.GetSessionId(p))
finish()
check(
    spawnCount == teardownCount + 1 and muncher.GetSnapshot(p) == nil,
    "session cleanup preserves committed output only"
)
muncher.Reset(p)
unlock()
carry(p, "Apple")
local pool = config.RewardPools[1]
local originalId = pool[1].Id
pool[1].Id = "PlayerHead"
check(not feed() and inventory.GetCarryCount(p) == 1, "invalid reward configuration never consumes input")
pool[1].Id = originalId
check(feed(), "configuration recovery releases lifecycle lock")
finish()
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
-- Exercise the real component-created action through the registered server callback.
muncher.Reset(p)
env.Enum.KeyCode = { E = "E", ButtonX = "ButtonX" }
local cleanup
workspaceFake.GetPartBoundsInRadius = function()
    return {}
end
pad.Touched = signal()
local createPrompt = cache.WorldUtil.Prompt
cache.WorldUtil.Prompt = function(parent, name, text)
    local prompt = createPrompt(parent, name)
    prompt.ActionText = text
    return prompt
end
cache.WorldUtil.BindTag = function(_, attach)
    cleanup = attach(plot)
end
loadModule("MuncherComponent").Init(dependency)
unlock()
heartbeat:Fire(0.1)
local prompt = input:FindFirstChild("FeedMuncher")
check(
    prompt ~= nil and prompt.Enabled and prompt.ActionText == "FEED MUNCHER",
    "purchased component exposes feed interaction"
)
carry(p, "Apple")
prompt.Triggered:Fire(p, authority.GetRequestContext(p))
check(
    inventory.GetCarryCount(p) == 0 and muncher.GetSnapshot(p).Phase == "Processing",
    "registered prompt commits real inventory feed"
)
finish()
cleanup()
