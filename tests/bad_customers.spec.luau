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
    services.RunService.Heartbeat:Fire()
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
local equipped = {}
deps.CombatService = {
    IsBatEquipped = function(p)
        return equipped[p] == true
    end,
}
local function hit(p, model)
    return customer.HitCustomer(p, model, { Direction = vec(1, 0, 0), Duration = 1 })
end
local function buyBat(p, tier)
    tycoon.SetCash(p, 1000000)
    setup(tycoon.PurchaseUpgrade(p, "Bat", tier or 2, tycoon.GetRequestContext(p)), "purchase authoritative Bat")
end
local function holdRoute(model)
    model:FindFirstChildOfClass("Humanoid").MoveTo = function(h, at)
        h.WalkTarget = at
    end
end
local function startTheft()
    local model = spawn("thief")
    setup(customer.TakeOrder(owner, model), "reveal thief")
    flush()
    holdRoute(model)
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
check(not tycoon.HasBat(owner) and plot:GetAttribute("BadNPCEnabled") == false, "level zero disables plot eligibility")
for _, kind in { "thief", "freeloader" } do
    local model = spawn(kind)
    check(model:GetAttribute("CustomerId") ~= kind, "level zero filters bad candidates even at full special chance")
end
reset()
local studio = services.RunService.IsStudio
services.RunService.IsStudio = function()
    return true
end
services.RunService.IsServer = function()
    return true
end
template:SetAttribute("CustomerId", "thief")
check(customer.SpawnForPlayer(owner, "thief") == nil, "Studio injection cannot bypass Level 0 eligibility")
services.RunService.IsStudio = studio
reset()
local normal = spawn()
local beforeQueue = #customer.GetQueueSnapshot(owner)
buyBat(owner)
check(
    tycoon.HasBat(owner) and plot:GetAttribute("HasBat") and plot:GetAttribute("BadNPCEnabled"),
    "purchase enables derived eligibility"
)
check(#customer.GetQueueSnapshot(owner) == beforeQueue, "purchase does not force an arrival")
check(assembly.Destroyed, "legacy floor action removed from active plot")
setup(tycoon.JoinSession(foreign, owner, tycoon.GetRequestContext(owner)), "join defender teammate")
equipped[owner], equipped[foreign] = true, true
check(tycoon.HasBat(foreign), "teammate reads existing shared purchased tier")
for _, tier in { 2, 3, 4 } do
    if tier > 2 then
        buyBat(foreign, tier)
    end
    reset()
    for _, kind in { "thief", "freeloader" } do
        local model = spawn(kind)
        check(
            model:GetAttribute("CustomerId") == kind,
            "level one and higher retain existing bad candidate probability"
        )
    end
end
reset()
template:SetAttribute("CustomerId", "thief")
requests.SpecialCustomerChance = 0
check(
    customer.SpawnForPlayer(owner):GetAttribute("CustomerId") ~= "thief",
    "purchased eligibility preserves zero special probability"
)
requests.SpecialCustomerChance = 1
now += economy.SpecialCustomerCooldownSeconds + 1
check(
    customer.SpawnForPlayer(owner):GetAttribute("CustomerId") == "thief",
    "existing full special probability works when eligible"
)
check(
    customer.SpawnForPlayer(owner):GetAttribute("CustomerId") ~= "thief",
    "existing special cooldown remains enforced"
)
reset()
normal = spawn()
check(
    not customer.RejectFront(owner, plot) and not customer.DismissCustomer(owner, normal, "RejectedByOwner"),
    "legacy actions cannot dismiss legitimate queue"
)
check(
    not customer.RejectCustomer(owner, normal, "Bat") and customer.ResolveRejectTarget(owner) == nil,
    "legacy exact/front reject APIs are inert"
)
check(#customer.GetQueueSnapshot(owner) == 1, "legacy requests preserve queue")
-- Bad rejection never consumes a cup or cash; serving a freeloader keeps its existing penalty.
reset()
local free = spawn("freeloader")
cup = { Ingredients = { "Strawberry", "Banana", "Ice" }, BlendId = "preserved-on-hit" }
local cashBefore, consumedBefore, held = tycoon.GetCash(owner), consumed, cup
check(
    hit(foreign, free) and cup == held and consumed == consumedBefore and tycoon.GetCash(owner) == cashBefore,
    "Bat rejection preserves smoothie and economy"
)
reset()
free = spawn("freeloader")
setup(customer.TakeOrder(owner, free), "reveal freeloader")
cup = { Ingredients = { "Strawberry", "Banana", "Ice" }, BlendId = "served-once" }
cashBefore, consumedBefore = tycoon.GetCash(owner), consumed
check(
    customer.Serve(owner, free) and tycoon.GetCash(owner) == cashBefore + config.FreeloaderPayout,
    "freeloader retains existing serve penalty"
)
check(
    not hit(foreign, free) and not customer.Serve(owner, free) and consumed == consumedBefore + 1,
    "serve claim prevents duplicate Bat rejection or payout"
)
reset()
normal, thief = spawn(), spawn("thief")
-- Equipped-tool state affects combat authorization, never spawn entitlement.
local thief = spawn("thief")
equipped[owner], equipped[foreign] = false, false
check(
    tycoon.HasBat(owner) and plot:GetAttribute("BadNPCEnabled") and not hit(owner, thief),
    "unequip preserves eligibility but blocks rejection"
)
owner.Character = nil
customer.BindPlayer(owner)
check(not thief.Destroyed and tycoon.HasBat(owner), "temporary death/respawn cannot cancel encounter")
equipped[owner], equipped[foreign] = true, true
-- Both defenders use the exact physical victim; a waiting bad NPC need not be the front.
for _, defender in { owner, foreign } do
    reset()
    normal, thief = spawn(), spawn("thief")
    local cues = sfx.Reject or 0
    check(hit(defender, thief), "assigned equipped defender rejects waiting bad NPC")
    check(
        #customer.GetQueueSnapshot(owner) == 1 and customer.GetQueueSnapshot(owner)[1].Model == normal,
        "exact hit preserves legitimate front"
    )
    check(
        not hit(defender, thief) and not hit(owner, thief) and sfx.Reject == cues + 1,
        "duplicate defender hits claim rejection once"
    )
    heartbeat()
    check(thief.PrimaryPart.Impulse.Y == 12 * config.Reject.LaunchVertical, "existing dramatic launch retained")
end
-- Normal customers stay in queue and retain their request through hit/recovery.
reset()
normal = spawn()
local h = instance("Humanoid")
h.Health, h.Parent = 100, normal
normal.PrimaryPart.Name, normal.PrimaryPart.AssemblyMass = "HumanoidRootPart", 12
normal.PrimaryPart.ApplyImpulse = function(self, value)
    self.Impulse = value
end
setup(customer.TakeOrder(owner, normal), "take legitimate order")
local requestId = normal:GetAttribute("RequestId")
check(hit(foreign, normal), "normal customer uses ordinary temporary combat")
check(
    #customer.GetQueueSnapshot(owner) == 1 and normal:GetAttribute("RequestId") == requestId,
    "normal combat cannot permanently reject order"
)
heartbeat()
advance(1)
heartbeat()
check(customer.GetSnapshot(owner).Ready and not normal.Destroyed, "normal customer recovers and returns to service")
requests.NPCs.legitimateTest =
    { Type = "Special", DisplayName = "Legitimate Special", RequestId = "QueueRed", Weight = 1 }
reset()
local legitimateSpecial = spawn("legitimateTest")
local specialRequest = legitimateSpecial:GetAttribute("RequestId")
check(
    hit(owner, legitimateSpecial) and #customer.GetQueueSnapshot(owner) == 1,
    "legitimate special uses temporary Bat path"
)
heartbeat()
advance(1)
heartbeat()
check(
    not legitimateSpecial.Destroyed and legitimateSpecial:GetAttribute("RequestId") == specialRequest,
    "legitimate special recovers without permanent rejection"
)
-- Interrupt both pending movement and the theft windup.
for _, phase in { "Walking", "Windup" } do
    reset()
    thief = spawn("thief")
    if phase == "Walking" then
        holdRoute(thief)
    end
    setup(customer.TakeOrder(owner, thief), "start pre-commit encounter")
    flush()
    local priorThefts, priorDrops = thefts, #drops
    check(hit(foreign, thief), "teammate interrupts pre-commit thief")
    thief:FindFirstChildOfClass("Humanoid").MoveToFinished:Fire(true)
    advance(config.TheftWindup)
    check(
        thefts == priorThefts and #drops == priorDrops and #customer.GetQueueSnapshot(owner) == 0,
        "stale route/timer cannot commit theft after rejection"
    )
end
reset()
thief = startTheft()
normal = spawn()
local priorDrops = #drops
advance(config.TheftWindup)
check(customer.CanHitCustomer(foreign, thief), "escaping thief remains associated and hittable after queue release")
local reentrant
local release = deps.InventoryService.ReleaseThiefIngredient
deps.InventoryService.ReleaseThiefIngredient = function(...)
    reentrant = hit(owner, thief)
    return release(...)
end
check(hit(foreign, thief), "post-commit teammate hit rejects exact escaping thief")
deps.InventoryService.ReleaseThiefIngredient = release
local recovered = ingredientService.GetRecord(drops[#drops])
check(
    reentrant == false and #drops == priorDrops + 1 and recovered.Item.ItemId == stolen.ItemId,
    "reentrant hit drops exact stolen unit once"
)
check(
    recovered.Item.IsRipe and recovered.Item.RipenessStoredSeconds == 120,
    "recovery preserves stolen ingredient state"
)
check(
    customer.GetQueueSnapshot(owner)[1].Model == normal and not hit(owner, thief),
    "old thief cannot reject replacement customer"
)
-- A successful final exit consumes the unit; a timeout/failed route preserves it.
reset()
thief = spawn("thief")
setup(customer.TakeOrder(owner, thief), "start successful escape")
flush()
priorDrops = #drops
advance(config.TheftWindup)
check(
    thief.Destroyed and #drops == priorDrops and not hit(owner, thief),
    "successful escape permanently consumes ingredient"
)
-- Reentrant hit during commit cannot bypass the plot transaction.
reset()
thief = startTheft()
local remove = deps.InventoryService.RemoveThiefIngredient
local duringCommit
deps.InventoryService.RemoveThiefIngredient = function(...)
    local result = remove(...)
    duringCommit = hit(foreign, thief)
    return result
end
priorDrops = #drops
advance(config.TheftWindup)
deps.InventoryService.RemoveThiefIngredient = remove
check(
    duringCommit == false and #drops == priorDrops and hit(owner, thief) and #drops == priorDrops + 1,
    "commit lock prevents duplicate theft/rejection and next hit recovers"
)
-- Reset restores unescaped custody and invalidates callbacks.
for _, postCommit in { false, true } do
    reset()
    thief = startTheft()
    if postCommit then
        advance(config.TheftWindup)
    end
    local priorThefts = thefts
    priorDrops = #drops
    customer.DeactivateForPlayer(owner)
    advance(config.TheftWindup + 1)
    check(
        thief.Destroyed and thefts == priorThefts and #drops == priorDrops + (if postCommit then 1 else 0),
        "reset cancels encounter and preserves unescaped custody"
    )
end
-- Teammate departure revokes their authority without erasing the shared purchase.
reset()
thief = startTheft()
tycoon.RemovePlayer(foreign)
check(
    not thief.Destroyed and tycoon.HasBat(owner) and not hit(foreign, thief),
    "departing teammate cannot defend but surviving purchased plot stays eligible"
)
setup(tycoon.JoinSession(foreign, owner, tycoon.GetRequestContext(owner)), "return teammate")
check(hit(foreign, thief), "newly assigned teammate can defend the existing encounter")
-- Current ownership survives promotion because Bat upgrades belong to the session.
reset()
thief = startTheft()
advance(config.TheftWindup)
priorDrops = #drops
tycoon.RemovePlayer(owner)
check(
    not thief.Destroyed and tycoon.HasBat(foreign) and plot:GetAttribute("BadNPCEnabled"),
    "owner departure promotes eligible teammate without cancelling encounter"
)
check(hit(foreign, thief) and #drops == priorDrops + 1, "promoted teammate defends existing escaping thief")
-- Last member closes session, preserving loot; new session starts at level zero.
local oldOwner = owner
owner = foreign
reset()
-- theft fixture checks its dynamically bound owner.
thief = startTheft()
advance(config.TheftWindup)
priorDrops = #drops
tycoon.RemovePlayer(owner)
check(
    thief.Destroyed and #drops == priorDrops + 1 and not plot:GetAttribute("BadNPCEnabled"),
    "last Bat member departure clears eligibility and restores custody"
)
owner = oldOwner
setup(tycoon.AssignPlot(owner, plot) == plot, "new owner starts new session")
check(not tycoon.HasBat(owner), "new ownership cannot inherit departed session purchase")
-- Exercise eligibility loss independently of equip, using the authoritative read boundary.
-- Current shared upgrades cannot be downgraded in gameplay, but cancellation must handle it.
buyBat(owner)
reset()
thief = startTheft()
advance(config.TheftWindup)
normal = spawn()
priorDrops = #drops
local getUpgrade = tycoon.GetUpgrade
tycoon.GetUpgrade = function(p, id)
    return if id == "Bat" then 1 else getUpgrade(p, id)
end
customer.BindPlayer(owner)
check(
    thief.Destroyed and #drops == priorDrops + 1 and customer.GetQueueSnapshot(owner)[1].Model == normal,
    "loss of last purchased eligibility cancels only bad encounter with exact recovery"
)
tycoon.GetUpgrade = getUpgrade
-- Separate plots cannot reject a victim, even with a purchased equipped Bat.
local otherPlot = instance("Model")
otherPlot.Name, otherPlot.Parent = "OtherPlot", workspaceFake
for name, marker in refs do
    local copy = instance("Part")
    copy.Name, copy.Parent, copy.CFrame = name, otherPlot, marker.CFrame
end
tycoon.AutoTagLegacyPlot(otherPlot)
setup(tycoon.AssignPlot(foreign, otherPlot) == otherPlot, "claim foreign business")
buyBat(foreign)
reset()
thief = spawn("thief")
thief:SetAttribute("OwnerUserId", foreign.UserId)
check(
    not hit(foreign, thief) and not customer.CanHitCustomer(foreign, thief),
    "foreign plot Bat and spoofed attributes cannot reject"
)
-- Missing theft point remains safe; launch cleanup remains bounded.
reset()
thiefPoint.Parent = nil
thief = spawn("thief")
local priorThefts = thefts
setup(customer.TakeOrder(owner, thief), "missing theft point")
flush()
flush()
check(thefts == priorThefts and thief.Destroyed, "missing theft point prevents loss")
thiefPoint.Parent = plot
reset()
thief = spawn("thief")
setup(hit(owner, thief), "launch without floor")
heartbeat()
advance(config.Reject.LandingTimeout + 0.1)
check(thief.Destroyed, "launch timeout cleans rig")
-- Real adapter discards legacy REJECT requests regardless of submitted victim/context.
reset()
normal, thief = spawn(), spawn("thief")
local remote
local originalNew = env.Instance.new
env.Instance.new = function(class)
    local object = originalNew(class)
    if class == "RemoteEvent" then
        object.OnServerEvent = signal()
        remote = object
    end
    return object
end
loadModule("GameplayService").Init(deps)
env.Instance.new = originalNew
for _, action in { "Reject", "RejectCustomer" } do
    remote.OnServerEvent:Fire(owner, action, thief, 1, tycoon.GetRequestContext(owner))
    remote.OnServerEvent:Fire(foreign, action, normal, 1, tycoon.GetRequestContext(foreign))
end
check(
    #customer.GetQueueSnapshot(owner) == 2 and not thief.Destroyed and not normal.Destroyed,
    "real legacy remote requests leave all NPCs intact"
)
-- Real CombatService validates issued/equipped identity and dispatches the exact overlap victim.
local combat = loadModule("CombatService")
deps.CombatService = combat
deps.MovementService = {
    CanPerformGameplayAction = function()
        return true
    end,
}
combat.Init(deps)
owner.Character = instance("Model")
owner.Character.Parent = workspaceFake
owner.Parent = services.Players
local humanoid = instance("Humanoid")
humanoid.Health, humanoid.Parent = 100, owner.Character
local attackerRoot = instance("Part")
attackerRoot.Name, attackerRoot.Parent = "HumanoidRootPart", owner.Character
local backpack = instance("Backpack")
backpack.Parent = owner
local batTemplate = instance("Tool")
batTemplate.Name, batTemplate.Parent = "Bat", storage
for _, name in { "Handle", "Hitbox" } do
    local part = instance("Part")
    part.Name, part.Parent = name, batTemplate
end
combat.RefreshPlayer(owner)
local issued = backpack:FindFirstChild("Bat")
setup(issued, "real combat issues purchased Bat")
services.Players.GetPlayerFromCharacter = function(_, model)
    return if model == owner.Character then owner else nil
end
thief.PrimaryPart.Position = vec(0, 0, -2)
workspaceFake.GetPartBoundsInBox = function()
    return { thief.PrimaryPart, thief.PrimaryPart }
end
workspaceFake.Raycast = function()
    return nil
end
check(not combat.SwingBat(owner), "unequipped real issued Bat cannot start rejection")
local forged = batTemplate:Clone()
forged.Parent = owner.Character
check(not combat.SwingBat(owner) and not hit(owner, thief), "forged equipped Bat cannot reject")
forged:Destroy()
issued.Parent = owner.Character
check(combat.SwingBat(owner), "real equipped issued Bat starts validated swing")
advance(bat.HitActiveStart + 0.000001)
check(
    #customer.GetQueueSnapshot(owner) == 1 and customer.GetQueueSnapshot(owner)[1].Model == normal,
    "real overlap hit rejects waiting bad victim without touching front"
)
check(not hit(owner, thief), "real combat cannot replay rejected victim")
print(
    "PASS bat-only bad customer eligibility, authority, exact targets, theft, and lifecycle",
    count,
    "assertions;",
    setupCount,
    "setup"
)
