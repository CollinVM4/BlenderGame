-- Authoritative customer outcomes and cross-system claims; physics is an engine boundary.
local config = loadModule("BadCustomers")
local bat = loadModule("BatConfig")
for _, tuning in bat.Levels do
    check(
        config.Reject.LaunchVertical > tuning.VerticalKnockback * 5,
        "dedicated rejection height greatly exceeds ordinary Bat knockback"
    )
end
for _, definition in authoredCustomerDefinitions do
    if definition.Id == "Thief" or definition.Id == "Freeloader" then
        table.insert(requests.Definitions, definition)
    end
end
local sfx = {}
cache.AudioService.PlayBadCustomerCue = function(_, cue)
    sfx[cue] = (sfx[cue] or 0) + 1
end
local thefts, stolen = 0, nil
local drops = {}
local ingredientService = loadModule("IngredientService")
deps.IngredientService = ingredientService
deps.InventoryService = {
    RemoveThiefIngredient = function(actor, sessionId, committed)
        setup(actor == owner and sessionId == tycoon.GetSessionId(owner), "theft uses authoritative owner/session")
        thefts += 1
        stolen = { IngredientId = "Banana", ItemId = "stolen-unit", IsRipe = true, RipenessStoredSeconds = 120 }
        committed(stolen)
        return stolen
    end,
    ReleaseThiefIngredient = function(item, at)
        local object = ingredientService.Spawn(item.IngredientId, at, nil, true, { Item = item })
        table.insert(drops, object)
        return object
    end,
}
deps.BlendService.GetCup = function()
    return cup
end
local physical, pending = {}, {}
deps.RagdollService = {
    PrepareCharacter = function()
        return true
    end,
    SetRagdolled = function(model, enabled)
        physical[model] = enabled
        return true
    end,
    IsRagdolled = function(model)
        return physical[model] == true
    end,
    CleanupCharacter = function(model)
        physical[model] = nil
    end,
}
services.RunService.Heartbeat.Once = function(_, fn)
    table.insert(pending, fn)
end
local function heartbeat()
    local batch = pending
    pending = {}
    for _, fn in batch do
        fn()
    end
    flush()
end
workspaceFake.FallenPartsDestroyHeight = -500
local assembly = instance("Model")
assembly.Name, assembly.Parent = "RejectButton", plot
local button = instance("Part")
button.Name, button.Parent, button.CFrame = "Button", assembly, frame(3, 4, 5)
local base = instance("Part")
base.Name, base.Parent = "BlackBase", assembly
local origin = instance("Attachment")
origin.Name, origin.Parent = "Attachment", assembly
local thiefPoint = instance("Part")
thiefPoint.Name, thiefPoint.Parent, thiefPoint.CFrame = "CustomerThiefPoint", plot, frame(75, 0, 0)
refs.CustomerThiefPoint = thiefPoint
local folder, special = instance("Folder"), instance("Folder")
folder.Name, folder.Parent = "CustomerNPCs", storage
special.Name, special.Parent = "Special", folder
local template = instance("Model")
template.Name, template.Parent = "Suspicious", special
local templateRoot = instance("Part")
templateRoot.Name, templateRoot.Parent = "HumanoidRootPart", template
local templateHumanoid = instance("Humanoid")
templateHumanoid.RigType, templateHumanoid.Parent = { Name = "Test" }, template
template.PrimaryPart = templateRoot
local clone = template.Clone
function template:Clone()
    local model = clone(self)
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    humanoid.Health, humanoid.Died = 100, signal()
    local root = model.PrimaryPart
    root.AssemblyMass = 12
    root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = vec(0, 0, 0), vec(0, 0, 0)
    root.ApplyImpulse = function(self, impulse)
        self.Impulse = impulse
    end
    return model
end
local function reset()
    customer.DeactivateForPlayer(owner)
    table.clear(timers)
    table.clear(pending)
    requests.SpecialCustomerChance = 0
    setup(customer.ActivateForPlayer(owner), "activate clean queue")
    table.clear(timers) -- This suite explicitly spawns encounters; cadence has its own test home.
end
local function spawn(kind)
    if kind then
        template:SetAttribute("CustomerId", kind)
        requests.SpecialCustomerChance = 1
        -- Selection cooldown still operates: advance server clock, not scheduler.
        now += economy.SpecialCustomerCooldownSeconds + 1
    else
        requests.SpecialCustomerChance = 0
    end
    local model = customer.SpawnForPlayer(owner)
    setup(model ~= nil, "spawn encounter")
    flush()
    return model
end
tycoon.Init({
    SessionStarted = customer.ActivateForPlayer,
    SessionEnded = customer.CleanupSession,
    MemberChanged = customer.BindPlayer,
    MemberRemoved = customer.RemovePlayer,
})
tycoon.AutoTagLegacyPlot(plot)
setup(tycoon.AssignPlot(owner, plot) == plot, "claim authoritative owner")
reset()
local normal, thief, free = spawn(), spawn("thief"), spawn("freeloader")
check(customer.ResolveRejectTarget(owner) == normal, "counter wins without inspecting thief/freeloader waiting")
check(not customer.RejectFront(foreign, plot) and #customer.GetQueueSnapshot(owner) == 3, "outsider cannot dismiss")
setup(tycoon.JoinSession(foreign, owner, tycoon.GetRequestContext(owner)), "join teammate")
check(
    not customer.RejectFront(foreign, plot) and not customer.RejectCustomer(foreign, thief, "Bat"),
    "teammate is not plot owner"
)
local cashBefore, consumedBefore = tycoon.GetCash(owner), consumed
cup = { Ingredients = { "Strawberry", "Banana", "Ice" }, BlendId = "keep-me" }
local held = cup
setup(customer.TakeOrder(owner, normal), "take legitimate order before dismissal")
check(customer.RejectFront(owner, plot), "owner dismisses legitimate front")
check(
    customer.ResolveRejectTarget(owner) == thief and thief:GetAttribute("QueuePosition") == 1,
    "Wait1 immediately advances after dismissal"
)
check(
    normal:GetAttribute("Reaction") == "Disgust" and normal:GetAttribute("Grade") == nil,
    "false rejection gives angry reaction without grade"
)
check(
    not customer.Serve(owner, normal) and not customer.TakeOrder(owner, normal),
    "dismissed order cannot be restarted/served"
)
check(
    cup == held and consumed == consumedBefore and tycoon.GetCash(owner) == cashBefore,
    "dismissal preserves smoothie/cash"
)
check(not customer.DismissCustomer(owner, normal, "RejectedByOwner"), "duplicate dismissal is inert")
advance(config.DismissalResponseHold)
check(
    normal.Destroyed and normal:GetPivot().Position.X == refs.CustomerExit.CFrame.Position.X,
    "dismissed order retains correct plot exit context"
)
check(customer.RejectFront(owner, plot) and sfx.Reject == 1, "front thief enters shared rejection")
check(
    not customer.HitCustomer(owner, thief, { Direction = vec(1, 0, 0), Duration = 1 }),
    "Button then Bat cannot double reject"
)
check(
    customer.ResolveRejectTarget(owner) == free and free:GetAttribute("QueuePosition") == 1,
    "Wait2 advances before launch completes"
)
heartbeat()
check(thief.PrimaryPart.Impulse.Y == 12 * config.Reject.LaunchVertical, "rejection is mass-scaled physical sky impulse")
check(button.CFrame.Position.X == 3 and button.CFrame.Position.Y == 4, "authored red button stays fixed")
check(customer.HitCustomer(owner, free, { Direction = vec(1, 0, 0), Duration = 1 }), "owner Bat rejects freeloader")
check(
    not customer.RejectCustomer(owner, free, "RejectButton") and sfx.Reject == 2,
    "Bat then Button commits/audio once"
)
check(
    #customer.GetQueueSnapshot(owner) == 0 and not customer.RejectFront(owner, plot),
    "empty queue and no active thief is safe no-op"
)
check(not customer.Serve(owner, free) and cup == held, "rejected freeloader causes no consumption/debit")
-- Negative result bypasses every payout modifier, validates minimum cup and consumes once.
reset()
free = spawn("freeloader")
setup(customer.TakeOrder(owner, free), "take freeloader request")
check(free:GetAttribute("RequestId") == "Freeloader", "bad fixed request never becomes random wildcard dialogue")
cup = { Ingredients = { "Ice" }, BlendId = "invalid-minimum" }
check(
    not customer.Serve(owner, free) and consumed == consumedBefore,
    "freeloader refuses undersized cup without consuming"
)
cup = { Ingredients = { "Strawberry", "Banana", "Ice" }, BlendId = "freeloader-cup" }
tycoon.SetCash(owner, 100)
local normalPayout = customer.CalculateOrderPayout
customer.CalculateOrderPayout = function()
    error("freeloader entered normal payout formula")
end
check(
    customer.Serve(owner, free) and tycoon.GetCash(owner) == 50 and consumed == consumedBefore + 1,
    "freeloader costs exactly fifty and consumes once"
)
customer.CalculateOrderPayout = normalPayout
check(
    free:GetAttribute("Grade") == nil and not customer.RejectCustomer(owner, free, "Bat"),
    "served freeloader needs no grade and cannot be rejected"
)
local resultGui = free:FindFirstChild("CustomerResult", true)
check(
    string.find(resultGui:FindFirstChild("Result").Text, "-$50", 1, true) ~= nil
        and not resultGui:FindFirstChild("Ingredients"),
    "result shows only negative cash"
)
check(not customer.Serve(owner, free) and tycoon.GetCash(owner) == 50, "freeloader service replay cannot debit twice")
reset()
free = spawn("freeloader")
tycoon.SetCash(owner, 20)
cup = { Ingredients = { "Strawberry", "Banana", "Ice" }, BlendId = "floor" }
setup(customer.Serve(owner, free), "serve under cash floor")
check(tycoon.GetCash(owner) == 0, "cash follows centralized nonnegative policy")
-- Service owns the exclusive claim BEFORE consuming visual callbacks.
reset()
normal = spawn()
cup = { Ingredients = { "Strawberry", "Banana", "Ice" }, BlendId = "serve-wins" }
local consume = deps.BlendService.ConsumeCup
local dismissalWon
deps.BlendService.ConsumeCup = function(...)
    dismissalWon = customer.DismissCustomer(owner, normal, "RejectedByOwner")
    return consume(...)
end
local beforeConsume = consumed
check(
    customer.Serve(owner, normal) and dismissalWon == false and consumed == beforeConsume + 1,
    "serve wins against reentrant reject during consumption"
)
deps.BlendService.ConsumeCup = consume
check(not customer.DismissCustomer(owner, normal, "RejectedByOwner"), "served legitimate customer cannot dismiss later")
reset()
normal = spawn()
cup = { Ingredients = { "Strawberry", "Banana", "Ice" }, BlendId = "dismiss-wins" }
local serveWon
local oldSet = normal.SetAttribute
function normal:SetAttribute(name, value)
    if name == "RequestId" and value == nil then
        serveWon = customer.Serve(owner, normal)
    end
    oldSet(self, name, value)
end
beforeConsume, cashBefore, held = consumed, tycoon.GetCash(owner), cup
check(
    customer.DismissCustomer(owner, normal, "RejectedByOwner") and serveWon == false,
    "dismiss wins against reentrant service"
)
check(
    consumed == beforeConsume and tycoon.GetCash(owner) == cashBefore and cup == held,
    "dismiss winner changes no smoothie/economy state"
)
-- Revealed thief overrides the advancing line, including both waiting slots.
reset()
thief, normal = spawn("thief"), spawn()
local wait1, wait2 = spawn(), nil
local unconsumed = consumed
check(not customer.Serve(owner, thief) and consumed == unconsumed, "queued thief never takes normal service/payout")
check(customer.TakeOrder(owner, thief), "owner order initiation starts theft")
check(
    #customer.GetQueueSnapshot(owner) == 2 and customer.ResolveRejectTarget(owner) == thief,
    "stealing thief frees line and overrides legitimate front and Wait1"
)
wait2 = spawn()
check(customer.ResolveRejectTarget(owner) == thief, "active thief also overrides Wait2")
flush()
check(thief:GetPivot().Position.X == 75 and sfx.Thief == 1, "thief uses own authored stash waypoint/audio")
local priorThefts = thefts
local priorDrops = #drops
check(customer.RejectFront(owner, plot), "button catches thief in theft windup")
advance(config.TheftWindup)
check(thefts == priorThefts and #drops == priorDrops, "rejection before theft removes/drops nothing")
check(
    customer.ResolveRejectTarget(owner) == normal and normal:GetAttribute("Reaction") == nil,
    "innocent counter is retained and normal targeting resumes after rejection"
)
-- Steal once, escape via Wait2, catch after commit and release the persistent unit.
reset()
thief = spawn("thief")
setup(customer.TakeOrder(owner, thief), "start late catch")
flush()
local thiefHumanoid = thief:FindFirstChildOfClass("Humanoid")
local routes = {}
thiefHumanoid.MoveTo = function(humanoid, at)
    table.insert(routes, at.X)
    humanoid.WalkTarget = at
end
advance(config.TheftWindup)
check(thefts == priorThefts + 1 and stolen.ItemId == "stolen-unit", "one theft mutation commits")
local carriedVisual = thief:FindFirstChild("StolenIngredientVisual")
check(
    carriedVisual ~= nil and ingredientService.GetRecord(carriedVisual) == nil and #drops == priorDrops,
    "held loot travels with thief without a claimable world duplicate"
)
normal = spawn()
check(customer.ResolveRejectTarget(owner) == thief, "escaping thief overrides new counter")
thiefHumanoid.MoveToFinished:Fire(true)
check(
    table.find(routes, 30) ~= nil and thief:GetAttribute("QueuePosition") == nil,
    "escape traverses Wait2 without claiming a slot"
)
thiefHumanoid.MoveToFinished:Fire(true) -- complete Wait2
flush() -- start final Exit route
thiefHumanoid.MoveToFinished:Fire(true) -- advance from path start to Exit
check(
    table.find(routes, refs.CustomerExit.CFrame.Position.X) ~= nil and customer.ResolveRejectTarget(owner) == thief,
    "thief stays rejectable through final escape leg"
)
check(
    customer.ResolveRejectTarget(owner) == thief
        and customer.HitCustomer(owner, thief, { Direction = vec(1, 0, 0), Duration = 1 }),
    "escaping thief still accepts owner Bat"
)
advance(2 * config.TheftWindup)
check(thefts == priorThefts + 1 and stolen.ItemId == "stolen-unit", "late Bat cannot repeat theft")
local drop = drops[#drops]
local recovered = ingredientService.GetRecord(drop)
check(
    #drops == priorDrops + 1 and recovered.Item.ItemId == stolen.ItemId and recovered.Item.IsRipe,
    "owner Bat publishes exactly one ripe persistent world ingredient"
)
check(
    carriedVisual.Destroyed and not thief.PrimaryPart.Impulse,
    "stolen visual is removed and world drop published before sky impulse"
)
check((drop:GetPivot().Position - thief.PrimaryPart.Position).Magnitude < 8, "loot drops near caught thief")
check(
    not customer.RejectCustomer(owner, thief, "RejectButton")
        and not customer.HitCustomer(owner, thief, { Direction = vec(1, 0, 0), Duration = 1 })
        and #drops == priorDrops + 1,
    "repeated Button/Bat cannot duplicate release"
)
heartbeat()
check(
    ingredientService.GetRecord(drop) ~= nil and drop.Parent == workspaceFake,
    "loot stays in world when thief launches"
)
thief:Destroy()
check(
    #drops == priorDrops + 1 and ingredientService.GetRecord(drop) ~= nil,
    "NPC cleanup never duplicates or removes released world loot"
)
check(customer.ResolveRejectTarget(owner) == normal, "front queue resumes after late catch cleanup")
-- Button wins after commit too, including a simultaneous Bat attempt at publication.
reset()
thief = spawn("thief")
setup(customer.TakeOrder(owner, thief), "start Button recovery")
flush()
local escapeHumanoid = thief:FindFirstChildOfClass("Humanoid")
escapeHumanoid.MoveTo = function(h, at)
    h.WalkTarget = at
end
advance(config.TheftWindup)
priorDrops = #drops
local release = deps.InventoryService.ReleaseThiefIngredient
local batWon
deps.InventoryService.ReleaseThiefIngredient = function(...)
    batWon = customer.HitCustomer(owner, thief, { Direction = vec(1, 0, 0), Duration = 1 })
    return release(...)
end
check(
    customer.RejectFront(owner, plot) and batWon == false and #drops == priorDrops + 1,
    "Button after theft and reentrant Bat publish exactly one drop"
)
deps.InventoryService.ReleaseThiefIngredient = release
heartbeat()
check(
    not customer.RejectCustomer(owner, thief, "RejectButton") and #drops == priorDrops + 1,
    "launch/repeated reject cannot release thief loot again"
)
-- A successful escape or unexpected destruction consumes custody, never drops it.
for _, destroyUnexpectedly in { false, true } do
    reset()
    thief = spawn("thief")
    setup(customer.TakeOrder(owner, thief), "start uncaught thief")
    flush()
    normal = spawn()
    priorDrops = #drops
    if destroyUnexpectedly then
        local h = thief:FindFirstChildOfClass("Humanoid")
        h.MoveTo = function(self, at)
            self.WalkTarget = at
        end
    end
    advance(config.TheftWindup)
    if destroyUnexpectedly then
        thief:Destroy()
    end
    check(
        thief.Destroyed and #drops == priorDrops and customer.ResolveRejectTarget(owner) == normal,
        "escape/generic cleanup loses stolen loot and resumes front targeting"
    )
end
-- The plot transaction guards reentrant rejection; the next owner input recovers.
reset()
thief = spawn("thief")
setup(customer.TakeOrder(owner, thief), "start commit race")
flush()
local commitHumanoid = thief:FindFirstChildOfClass("Humanoid")
commitHumanoid.MoveTo = function(h, at)
    h.WalkTarget = at
end
local remove = deps.InventoryService.RemoveThiefIngredient
local commitReject
deps.InventoryService.RemoveThiefIngredient = function(...)
    local result = remove(...)
    commitReject = customer.RejectFront(owner, plot)
    return result
end
priorDrops = #drops
advance(config.TheftWindup)
deps.InventoryService.RemoveThiefIngredient = remove
check(
    commitReject == false and #drops == priorDrops and customer.RejectFront(owner, plot) and #drops == priorDrops + 1,
    "theft transaction blocks reentrant rejection then exact loot remains recoverable"
)
-- Deterministic plot-scoped association when more than one thief is revealed.
reset()
local firstThief = spawn("thief")
setup(customer.TakeOrder(owner, firstThief), "reveal first thief")
flush()
local firstHumanoid = firstThief:FindFirstChildOfClass("Humanoid")
firstHumanoid.MoveTo = function(h, at)
    h.WalkTarget = at
end
advance(config.TheftWindup) -- First thief is now Escaping, with its route held open.
local secondThief = spawn("thief")
setup(customer.TakeOrder(owner, secondThief), "reveal second thief")
flush()
check(customer.ResolveRejectTarget(owner) == firstThief, "escaping thief wins over stealing thief")
setup(customer.RejectFront(owner, plot), "catch more progressed thief")
check(customer.ResolveRejectTarget(owner) == secondThief, "next revealed thief becomes priority after rejection")
local thirdThief = spawn("thief")
setup(customer.TakeOrder(owner, thirdThief), "reveal third thief")
flush()
check(customer.ResolveRejectTarget(owner) == secondThief, "oldest stealing encounter breaks priority ties")
for _, cleanup in { "Death", "Reset" } do
    reset()
    thief = spawn("thief")
    setup(customer.TakeOrder(owner, thief), "start post-theft cleanup case")
    flush()
    local h = thief:FindFirstChildOfClass("Humanoid")
    h.MoveTo = function(self, at)
        self.WalkTarget = at
    end
    advance(config.TheftWindup)
    priorDrops = #drops
    if cleanup == "Death" then
        h.Died:Fire()
    else
        customer.DeactivateForPlayer(owner)
    end
    check(
        thief.Destroyed and #drops == priorDrops and customer.ResolveRejectTarget(owner) == nil,
        "post-theft death/reset consumes loot and clears active association"
    )
end
-- A Bat hit during the stash route cancels old movement before the impulse step.
reset()
thief = spawn("thief")
local walkingHumanoid = thief:FindFirstChildOfClass("Humanoid")
walkingHumanoid.MoveTo = function(humanoid, at)
    humanoid.WalkTarget = at
end
setup(customer.TakeOrder(owner, thief), "start pending thief walk")
flush()
priorThefts = thefts
priorDrops = #drops
check(
    customer.HitCustomer(owner, thief, { Direction = vec(1, 0, 0), Duration = 1 }),
    "owner Bat interrupts active thief walk"
)
walkingHumanoid.MoveToFinished:Fire(true)
advance(config.TheftWindup)
check(
    thefts == priorThefts and #customer.GetQueueSnapshot(owner) == 0 and #drops == priorDrops,
    "cancelled walk completion cannot restart theft/queue"
)

-- Another plot/session is isolated, including spoofed customer attributes.
local otherPlot = instance("Model")
otherPlot.Name, otherPlot.Parent = "OtherPlot", workspaceFake
for name, marker in refs do
    local copy = instance("Part")
    copy.Name, copy.Parent, copy.CFrame = name, otherPlot, marker.CFrame
end
tycoon.RemovePlayer(foreign)
tycoon.AutoTagLegacyPlot(otherPlot)
setup(tycoon.AssignPlot(foreign, otherPlot) == otherPlot, "claim other business")
check(
    not customer.RejectFront(owner, otherPlot) and not customer.RejectCustomer(foreign, thief, "Bat"),
    "wrong plot requests cannot control victim"
)
-- Two active bad encounters remain isolated through simultaneous plot operations.
template:SetAttribute("CustomerId", "thief")
requests.SpecialCustomerChance = 1
local secondBusiness = customer.SpawnForPlayer(foreign)
setup(secondBusiness, "spawn second plot thief")
flush()
setup(customer.TakeOrder(foreign, secondBusiness), "reveal other plot thief")
check(
    customer.ResolveRejectTarget(foreign) == secondBusiness and customer.ResolveRejectTarget(owner) == nil,
    "Plot1 never selects Plot2 active thief"
)
local otherBefore = #customer.GetQueueSnapshot(foreign)
check(customer.RejectCustomer(foreign, secondBusiness, "Bat"), "other plot owner can reject their own bad customer")
check(
    #customer.GetQueueSnapshot(foreign) == otherBefore and #customer.GetQueueSnapshot(owner) == 0,
    "each rejection affects only its own queue"
)

-- Non-owner ordinary hit behavior remains temporary within the allowed same session.
tycoon.RemovePlayer(foreign)
setup(tycoon.JoinSession(foreign, owner, tycoon.GetRequestContext(owner)), "rejoin teammate")
reset()
thief = spawn("thief")
check(
    customer.HitCustomer(foreign, thief, { Direction = vec(1, 0, 0), Duration = 1 }),
    "teammate follows ordinary hit path"
)
check(
    #customer.GetQueueSnapshot(owner) == 1 and customer.ResolveRejectTarget(owner) == thief,
    "teammate hit preserves active lifecycle/queue"
)
check(
    customer.HitCustomer(owner, thief, { Direction = vec(1, 0, 0), Duration = 1 }),
    "owner can reject already ragdolled bad customer"
)
check(#customer.GetQueueSnapshot(owner) == 0, "owner rejection during ragdoll releases queue")
-- Legitimate customers (including specials) retain the ordinary Bat contract.
requests.NPCs.legitimateTest =
    { Type = "Special", DisplayName = "Legitimate Special", RequestId = "QueueRed", Weight = 1 }
for _, kind in { "regularTest", "legitimateTest" } do
    reset()
    local legitimate = spawn(if kind == "legitimateTest" then kind else nil)
    if kind == "regularTest" then
        local humanoid = instance("Humanoid")
        humanoid.Health, humanoid.Parent = 100, legitimate
        local root = legitimate.PrimaryPart
        root.Name, root.AssemblyMass = "HumanoidRootPart", 12
        root.ApplyImpulse = function(self, value)
            self.Impulse = value
        end
    end
    local requestId, rejectionCues = legitimate:GetAttribute("RequestId"), sfx.Reject
    setup(customer.TakeOrder(owner, legitimate), "take legitimate order for Bat")
    check(
        customer.HitCustomer(owner, legitimate, { Direction = vec(1, 0, 0), Duration = 1 }),
        "legitimate Bat hit uses temporary ragdoll"
    )
    check(
        #customer.GetQueueSnapshot(owner) == 1 and legitimate:GetAttribute("RequestId") == requestId,
        "legitimate Bat preserves queue/order"
    )
    heartbeat()
    advance(1)
    heartbeat()
    check(
        customer.GetSnapshot(owner).Ready and sfx.Reject == rejectionCues,
        "ordinary Bat recovers without successful rejection audio"
    )
    check(
        customer.DismissCustomer(owner, legitimate, "RejectedByOwner") and #customer.GetQueueSnapshot(owner) == 0,
        "button dismisses recovered legitimate special/regular"
    )
end
-- Owner-only physical interaction validates button range and immutable plot association.
reset()
normal = spawn()
local prompt = button:FindFirstChild("RejectPrompt")
prompt.MaxActivationDistance = 10
prompt.Triggered:Fire(foreign)
owner.Near = false
prompt.Triggered:Fire(owner)
check(customer.ResolveRejectTarget(owner) == normal, "foreign and distant physical presses are inert")
owner.Near = true
prompt.Triggered:Fire(owner)
check(customer.ResolveRejectTarget(owner) == nil, "valid physical press resolves authoritative front")
-- Missing escape markers are additive failures; they never prevent logical removal.
reset()
thief = spawn("thief")
refs.CustomerWait2.Parent = nil
setup(customer.TakeOrder(owner, thief), "start escape without Wait2")
flush()
advance(config.TheftWindup)
check(thief.Destroyed, "missing Wait2 goes directly to Exit")
refs.CustomerWait2.Parent = plot
reset()
normal = spawn()
refs.CustomerExit.Parent = nil
check(
    customer.DismissCustomer(owner, normal, "RejectedByOwner") and normal.Destroyed,
    "missing exit cleans dismissed NPC immediately"
)
refs.CustomerExit.Parent = plot
-- Walking failure and out-of-bounds launch have bounded cleanup.
reset()
thief = spawn("thief")
local pathFactory = services.PathfindingService.CreatePath
services.PathfindingService.CreatePath = function(...)
    local path = pathFactory(...)
    path.Status = "NoPath"
    return path
end
setup(customer.TakeOrder(owner, thief), "start unreachable thief route")
flush()
check(thief.Destroyed, "exhausted thief path retries remove NPC")
services.PathfindingService.CreatePath = pathFactory
reset()
thief = spawn("thief")
setup(customer.RejectCustomer(owner, thief, "Bat"), "launch out of bounds")
thief.PrimaryPart.Position = vec(0, -600, 0)
heartbeat()
check(thief.Destroyed, "out-of-bounds rejected rig cleans")

-- Missing markers and bounded physics recovery/cleanup.
reset()
thiefPoint.Parent = nil
thief = spawn("thief")
priorThefts = thefts
setup(customer.TakeOrder(owner, thief), "missing point starts safe escape")
flush()
flush()
check(thefts == priorThefts and thief.Destroyed, "missing thief point prevents theft and exits safely")
thiefPoint.Parent = plot
reset()
thief = spawn("thief")
setup(customer.RejectCustomer(owner, thief, "RejectButton"), "launch for recovery")
workspaceFake.Raycast = function()
    return { Instance = base }
end
heartbeat()
advance(config.Reject.MinimumFlight + config.Reject.LandingPoll + config.Reject.RecoveryDelay)
heartbeat()
check(thief.Destroyed and not physical[thief], "landed bad customer recovers then exits/cleans")
workspaceFake.Raycast = function()
    return nil
end
reset()
thief = spawn("thief")
setup(customer.RejectCustomer(owner, thief, "Bat"), "launch with no floor")
heartbeat()
advance(config.Reject.LandingTimeout + 0.1)
check(thief.Destroyed, "landing timeout cleans rig")
reset()
thief = spawn("thief")
setup(customer.TakeOrder(owner, thief), "start runtime for cleanup")
flush()
priorThefts = thefts
thief:FindFirstChildOfClass("Humanoid").Died:Fire()
advance(config.TheftWindup)
check(
    thief.Destroyed and thefts == priorThefts and #customer.GetQueueSnapshot(owner) == 0,
    "death cancels special runtime"
)
reset()
thief = spawn("thief")
setup(customer.TakeOrder(owner, thief), "start runtime for plot reset")
flush()
customer.DeactivateForPlayer(owner)
advance(config.TheftWindup)
check(thief.Destroyed and thefts == priorThefts, "plot reset cancels theft")
reset()
local studioCheck = services.RunService.IsStudio
services.RunService.IsStudio = function()
    return true
end
services.RunService.IsServer = function()
    return true
end
template:SetAttribute("CustomerId", "thief")
local injected = customer.SpawnForPlayer(owner, "thief")
check(
    injected ~= nil and injected:GetAttribute("CustomerId") == "thief",
    "injection selects ID with random special chance zero"
)
local repeated = customer.SpawnForPlayer(owner, "thief")
check(repeated ~= nil and #customer.GetQueueSnapshot(owner) == 2, "injection appends despite special cooldown")
check(
    customer.SpawnForPlayer(owner, "missing") == nil and #customer.GetQueueSnapshot(owner) == 2,
    "missing injection never spawns fallback"
)
check(customer.SpawnForPlayer(owner, "thief") ~= nil, "injection fills final queue slot")
check(customer.SpawnForPlayer(owner, "thief") == nil, "injection preserves queue capacity")
services.RunService.IsStudio = function()
    return false
end
check(customer.SpawnForPlayer(owner, "thief") == nil, "injection unavailable outside Studio")
services.RunService.IsStudio = studioCheck
reset()
thief = spawn("thief")
setup(customer.TakeOrder(owner, thief), "start runtime for owner leave")
flush()
tycoon.RemovePlayer(owner)
advance(config.TheftWindup)
check(thief.Destroyed and thefts == priorThefts, "owner leaving cancels theft/runtime")
tycoon.RemovePlayer(foreign) -- Last teammate releases the surviving promoted session.
setup(tycoon.AssignPlot(owner, plot) == plot, "reclaim plot for post-theft owner leave")
reset()
thief = spawn("thief")
setup(customer.TakeOrder(owner, thief), "start committed theft before owner leave")
flush()
local leavingHumanoid = thief:FindFirstChildOfClass("Humanoid")
leavingHumanoid.MoveTo = function(h, at)
    h.WalkTarget = at
end
advance(config.TheftWindup)
priorDrops = #drops
tycoon.RemovePlayer(owner)
check(
    thief.Destroyed and #drops == priorDrops and customer.ResolveRejectTarget(owner) == nil,
    "owner departure after theft consumes loot without recovery and clears targeting"
)
print(
    "PASS bad customers outcomes, targeting, authority, races, theft, and cleanup",
    count,
    "assertions;",
    setupCount,
    "setup"
)
