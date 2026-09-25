-- Real session authority, inventory, batch, customers and movement together.
env.Enum.HumanoidDisplayDistanceType = { None = "None" }
env.Enum.HumanoidHealthDisplayType = { AlwaysOff = "AlwaysOff" }
workspaceFake.Gravity = 196.2
local tycoon = dependency.TycoonService
local movement = loadModule("MovementService")
movement.Init(dependency)
local owner = player()
local teammate = player()
local visitor = player()
tycoon.RemovePlayer(teammate)
tycoon.RemovePlayer(visitor)
local cleanupCount, invalidBeforeCleanup = 0, false
tycoon.Init({
    MemberChanged = function(p)
        movement.RefreshPlayer(p)
        blend.BindPlayer(p)
        customer.BindPlayer(p)
    end,
    MemberRemoved = function(p)
        blend.RemovePlayer(p)
        customer.RemovePlayer(p)
        movement.RefreshPlayer(p)
    end,
    SessionEnded = function(id)
        cleanupCount += 1
        invalidBeforeCleanup = tycoon.GetSessionOwner(id) == nil
        blend.CleanupSession(id)
        customer.CleanupSession(id)
    end,
})
local function context(p)
    return tycoon.GetRequestContext(p)
end
local function join(p, manager)
    return tycoon.JoinSession(p, manager, context(manager))
end
setup(join(teammate, owner), "join existing owner")
local id = tycoon.GetSessionId(owner)
local old = context(teammate)
tycoon.AddCash(owner, 20000)
tycoon.AddCash(teammate, 10000)
check(tycoon.GetCash(owner) == 30000 and dataService.GetCash(teammate) == 30000, "both actors earn into one balance")
check(owner:GetAttribute("playerCash") == teammate:GetAttribute("playerCash"), "cash projects to both clients")
local copy = tycoon.GetSession(owner)
copy.SharedCash, copy.SharedUpgrades.Jump = 0, 4
check(tycoon.GetCash(owner) == 30000 and tycoon.GetJumpTier(owner) == 0, "snapshot mutation cannot change authority")
for _, amount in { -1, 0 / 0, math.huge } do
    check(
        not pcall(tycoon.AddCash, owner, amount) and tycoon.GetCash(owner) == 30000,
        "invalid cash award cannot corrupt balance"
    )
    check(not tycoon.PurchasePersonalUpgrade(owner, context(owner), amount, function()
        error("must not commit")
    end), "invalid deduction rejected")
end
check(not tycoon.PurchaseUpgrade(visitor, "Jump", 2, old), "visitor cannot spend")
setup(tycoon.PurchaseUpgrade(teammate, "Jump", 2, old), "teammate buys shared jump")
check(tycoon.GetCash(owner) == 28000 and tycoon.GetUpgrade(owner, "Jump") == 2, "one shared deduction and tier")
check(
    not tycoon.PurchaseUpgrade(owner, "Jump", 2, context(owner)),
    "duplicate next-tier request cannot buy another tier"
)
check(movement.GetJumpPower(owner) == movement.GetJumpPower(teammate), "both receive purchased jump")
for _, track in { "MovementSpeed", "SprintStamina", "Hand", "Payout" } do
    setup(tycoon.PurchaseUpgrade(owner, track, 2, context(owner)), "buy " .. track)
    check(tycoon.GetUpgrade(teammate, track) == 2, "shared tier visible to teammate")
end
check(
    movement.GetBaseWalkSpeed(owner) == movement.GetBaseWalkSpeed(teammate)
        and movement.GetMaxStamina(owner) == movement.GetMaxStamina(teammate),
    "movement derived from common upgrades"
)
check(tycoon.Kick(owner, teammate, context(owner)), "owner can kick")
check(not tycoon.PurchaseUpgrade(teammate, "Jump", 3, old), "kicked member loses spending")
setup(join(teammate, owner), "rejoin developed plot")
check(not tycoon.PurchaseUpgrade(teammate, "Jump", 3, old), "same-session rejoin rejects stale revision")
check(
    movement.GetJumpPower(owner) == movement.GetJumpPower(teammate),
    "joining inherits developed movement immediately"
)
check(
    not tycoon.PurchaseUpgrade(
        owner,
        "Jump",
        3,
        { PlotSessionId = "old", MembershipRevision = context(owner).MembershipRevision }
    ),
    "stale session identity rejected"
)
tycoon.SetCash(owner, 5000)
setup(tycoon.PurchaseUpgrade(owner, "MovementSpeed", 3, context(owner)), "spend available cash")
check(
    not tycoon.PurchaseUpgrade(teammate, "SprintStamina", 3, context(teammate)) and tycoon.GetCash(owner) == 0,
    "concurrent different purchases cannot overspend"
)
-- Separate account inventory; contribution crosses only the world ingestion boundary.
local input, wheel = references[owner].BlenderInput, references[owner].TurbineWheel
local object = ingredients.Spawn("Banana", frame(), owner, true)
input.Overlaps = { object }
check(
    not blend.TryInput(teammate, object, input, context(teammate)) and ingredients.GetRecord(object) ~= nil,
    "membership cannot consume another member's world item"
)
setup(blend.TryInput(owner, object, input, context(owner)), "owner contributes own ingredient")
for _, who in { teammate, owner } do
    local item = ingredients.Spawn("Banana", frame(), who, true)
    input.Overlaps = { item }
    setup(blend.TryInput(who, item, input, context(who)), "actor contributes own ingredient")
end
check(
    #blend.GetSnapshot(teammate).Ingredients == 3
        and owner:GetAttribute("BlendState") == teammate:GetAttribute("BlendState"),
    "one batch and both projections"
)
setup(
    blend.AddProgress(teammate, wheel, loadModule("Economy").RequiredProgress, context(teammate)),
    "teammate completes shared batch"
)
local batchId = blend.GetSnapshot(owner).Result.BlendId
local staleOwner = context(owner)
local staleTeammate = context(teammate)
local configs = loadModule("CustomerRequests")
table.clear(configs.Definitions)
configs.SpecialCustomerChance = 0
configs.Definitions[1] =
    { Id = "Low", RequiredTags = { "Yellow" }, DisplayText = "Yellow", BasePayout = 25, MinJumpTier = 0 }
configs.Definitions[2] =
    { Id = "High", RequiredTags = { "Yellow" }, DisplayText = "High", BasePayout = 25, MinJumpTier = 3 }
dependency.PlayerDataService.HasEntitlement = dataService.HasEntitlement
customer.ActivateForPlayer(owner)
owner:SetAttribute("JumpLevel", 3) -- deliberately personal/debug projection
local npc = customer.SpawnForPlayer(owner)
flush()
check(npc:GetAttribute("RequestId") == "Low", "regular eligibility ignores personal debug Jump")
local beforeCash = tycoon.GetCash(owner)
tycoon.RemovePlayer(owner)
customer.RemovePlayer(owner)
blend.RemovePlayer(owner)
check(
    tycoon.GetSessionId(teammate) == id and tycoon.GetSession(teammate).OwnerUserId == teammate.UserId,
    "promotion keeps session identity"
)
check(
    tycoon.GetCash(teammate) == beforeCash and tycoon.GetUpgrade(teammate, "MovementSpeed") == 3,
    "promotion preserves cash and upgrades"
)
check(
    blend.GetSnapshot(teammate).Result.BlendId == batchId and customer.GetSnapshot(teammate).Model == npc,
    "promotion preserves batch and queue"
)
check(not tycoon.PurchaseUpgrade(teammate, "Jump", 3, staleTeammate), "promotion invalidates prior management revision")
check(
    not blend.Dispense(owner, wheel, staleOwner) and not customer.Serve(owner, npc, staleOwner),
    "departed actor cannot blend or serve"
)
check(
    not blend.Dispense(teammate, wheel, staleTeammate) and not customer.Serve(teammate, npc, staleTeammate),
    "stale promoted actor requests rejected"
)
setup(blend.Dispense(teammate, wheel, context(teammate)), "promoted owner dispenses preserved batch")
check(blend.GetCup(teammate) ~= nil and blend.GetCup(owner) == nil, "only dispenser receives cup")
-- Reentrant other-member serve must not consume a second actor's cup.
setup(join(owner, teammate), "former owner rejoins as teammate")
grant(owner, "other-cup")
local originalConsume = dependency.BlendService.ConsumeCup
local consumes, nested = 0, true
dependency.BlendService.ConsumeCup = function(actor)
    consumes += 1
    nested = customer.Serve(owner, npc, context(owner))
    return originalConsume(actor)
end
dataService.SetEntitlement(teammate, "DoubleCash", true)
dataService.SetEntitlement(owner, "DoubleCash", true)
local expected = customer.CalculateOrderPayout(
    teammate,
    { Ingredients = { "Banana", "Banana", "Banana" } },
    configs.Definitions[1],
    true
)
setup(customer.Serve(teammate, npc, context(teammate)), "serve shared queue")
check(
    not nested and consumes == 1 and completedServes == 1 and blend.GetCup(owner) ~= nil,
    "two member contention consumes/completes once"
)
check(
    tycoon.GetCash(owner) == beforeCash + expected and dataService.GetCash(teammate) == tycoon.GetCash(owner),
    "single actor entitlement pays shared cash once"
)
check(
    owner:GetAttribute("CustomerReaction") == teammate:GetAttribute("CustomerReaction"),
    "result published to both members"
)
dependency.BlendService.ConsumeCup = originalConsume
local currentCash = tycoon.GetCash(owner)
tycoon.RemovePlayer(owner)
check(
    tycoon.GetCash(teammate) == currentCash and cleanupCount == 0,
    "teammate departure preserves progression without cleanup"
)
tycoon.RemovePlayer(teammate)
tycoon.RemovePlayer(teammate)
check(
    cleanupCount == 1 and invalidBeforeCleanup and tycoon.GetOwner(wheel) == nil,
    "final departure invalidates before one cleanup and releases plot"
)
check(
    not customer.Serve(teammate, npc, staleTeammate) and not blend.Dispense(teammate, wheel, staleTeammate),
    "teardown rejects stale operations"
)
flush()
check(
    blend.GetSnapshot(teammate) == nil and #customer.GetQueueSnapshot(teammate) == 0,
    "deferred reset cannot resurrect closed session"
)
