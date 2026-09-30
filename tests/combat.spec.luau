-- Real combat, inventory, movement, shared purchases and request adapter; engine query/timers doubled.
env.OverlapParams = {
    new = function()
        return {}
    end,
}
local combat = loadModule("CombatService")
local movement = loadModule("MovementService")
local tycoon = dependency.TycoonService
local config = loadModule("BatConfig")
local gameplaySfx = loadModule("GameplaySfxService")
gameplaySfx.Init()
local sfxRemote = shared.Events:FindFirstChild("GameplaySfx")
local swingSounds = {}
sfxRemote.FireAllClients = function(_, name, position)
    table.insert(swingSounds, { Name = name, Position = position })
end
dependency.MovementService = movement
dependency.CombatService = combat
dependency.CustomerService = customer
movement.Init(dependency)
combat.Init(dependency)
-- Physical engine boundary; AJU joint restoration is covered in ragdoll.spec.
local physical = {}
local ragdollCalls = {}
local ragdollFailure = nil
local heartbeatCallbacks = {}
services.RunService.Heartbeat.Once = function(_, callback)
    table.insert(heartbeatCallbacks, callback)
end
local function heartbeat()
    local pending = heartbeatCallbacks
    heartbeatCallbacks = {}
    for _, callback in pending do
        callback()
    end
end
dependency.RagdollService = {
    SetRagdolled = function(character, enabled)
        local owner = services.Players:GetPlayerFromCharacter(character)
        table.insert(ragdollCalls, {
            Character = character,
            Enabled = enabled,
            Stunned = owner and movement.IsStunned(owner),
            CarryCount = owner and inventory.GetCarryCount(owner),
        })
        if ragdollFailure == (if enabled then "on-error" else "off-error") then
            error("injected ragdoll failure")
        elseif ragdollFailure == (if enabled then "on-false" else "off-false") then
            return false
        end
        physical[character] = enabled
        character:FindFirstChildOfClass("Humanoid").PlatformStand = enabled
        return true
    end,
    IsRagdolled = function(character)
        return physical[character] == true
    end,
}
local function impulseRoot(root)
    root.AssemblyMass = 12
    function root:ApplyImpulse(impulse)
        self.Impulse = impulse
        self.ImpulseCount = (self.ImpulseCount or 0) + 1
    end
end
workspaceFake.Gravity = 196.2
local timers = {}
env.task.delay = function(seconds, callback)
    table.insert(timers, { At = now + seconds, Callback = callback })
end
local function advance(seconds)
    now += seconds
    local pending = timers
    timers = {}
    for _, timer in pending do
        if timer.At <= now then
            timer.Callback()
        else
            table.insert(timers, timer)
        end
    end
end
local template = instance("Tool")
template.Name, template.Parent = "Bat", storage
template.Grip = frame(0.1, -0.3, 0.2)
local handle = part("Handle", template)
handle.Size = vec(1, 2, 1)
local mesh = part("BatMesh", template)
mesh.Size = vec(1, 4, 1)
local hitbox = part("Hitbox", template)
hitbox.Size = vec(0.867, 0.597, 4.703)
hitbox.CFrame = frame(0.25, 0.1, -2.35)
local roster = {}
services.Players.GetPlayers = function()
    return roster
end
services.Players.GetPlayerFromCharacter = function(_, character)
    for _, p in roster do
        if p.Character == character then
            return p
        end
    end
    return nil
end
local function fighter(z)
    local p, humanoid = player()
    p.Name = "Fighter" .. tostring(#roster + 1)
    p.Character.Name = p.Name
    p.Parent, p.Neutral, p.ChildAdded = services.Players, true, signal()
    humanoid.UseJumpPower = true
    local root = p.Character:FindFirstChild("HumanoidRootPart")
    impulseRoot(root)
    root.Position, root.CFrame = vec(0, 0, z or 0), frame(0, 0, z or 0)
    p.Character.Parent = workspaceFake
    table.insert(roster, p)
    movement.ApplyCharacter(p, p.Character)
    combat.ApplyCharacter(p, p.Character)
    flush()
    return p, humanoid
end
local function bats(p)
    local result = {}
    for _, container in { p.Character, p:FindFirstChildOfClass("Backpack") } do
        for _, object in container:GetChildren() do
            if object:IsA("Tool") and object.Name == "Bat" then
                table.insert(result, object)
            end
        end
    end
    return result
end
tycoon.Init({
    MemberChanged = function(p)
        movement.RefreshPlayer(p)
        combat.RefreshPlayer(p)
    end,
    MemberRemoved = function(p)
        combat.RefreshPlayer(p)
    end,
})
local attacker, attackerHumanoid = fighter(0)
local victim, victimHumanoid = fighter(-3)
local teammate = fighter(-2)
tycoon.RemovePlayer(teammate)
setup(tycoon.JoinSession(teammate, attacker, tycoon.GetRequestContext(attacker)), "join teammate")
check(#bats(attacker) == 0, "level zero grants no bat")
attacker:SetAttribute("BatLevel", 3)
combat.RefreshPlayer(attacker)
check(#bats(attacker) == 0 and not combat.SwingBat(attacker), "replicated level cannot spoof ownership")
tycoon.SetCash(attacker, 20000)
setup(tycoon.PurchaseUpgrade(attacker, "Bat", 2, tycoon.GetRequestContext(attacker)), "purchase bat one")
check(#bats(attacker) == 1 and #bats(teammate) == 1, "shared unlock grants exactly one bat per member immediately")
local bat = bats(attacker)[1]
check(bat.Grip == template.Grip, "grant preserves authored Tool grip")
combat.RefreshPlayer(attacker)
check(#bats(attacker) == 1 and bats(attacker)[1] == bat, "refresh is idempotent")
check(not combat.IsBatEquipped(attacker), "issued Bat in Backpack is not considered equipped")
local issuedHandle = bat:FindFirstChild("Handle")
local issuedHitbox = bat:FindFirstChild("Hitbox")
check(
    issuedHandle ~= nil
        and issuedHandle:IsA("BasePart")
        and issuedHitbox ~= nil
        and issuedHitbox:IsA("BasePart"),
    "issued Bat resolves direct-child Handle and Hitbox BaseParts"
)
local fakeBat = instance("Tool")
fakeBat.Name, fakeBat.Parent = "Bat", attacker.Character
part("Handle", fakeBat)
part("Hitbox", fakeBat)
check(not combat.IsBatEquipped(attacker), "unissued Character Bat is not considered equipped")
check(not combat.SwingBat(attacker), "unissued Character Bat cannot start a swing")
check(#swingSounds == 0, "unissued Character Bat does not emit BatSwing")
fakeBat:Destroy()
local querySize, queryFrame, queryParams, queryCount = nil, nil, nil, 0
local overlaps = {}
workspaceFake.GetPartBoundsInBox = function(_, at, size, params)
    querySize, queryCount = size, queryCount + 1
    queryFrame, queryParams = at, params
    return overlaps
end
local function equip(p)
    p.Character:FindFirstChildOfClass("Humanoid"):EquipTool(bats(p)[1])
end
check(not combat.SwingBat(attacker), "unequipped bat rejects request")
check(#swingSounds == 0, "unequipped bat rejection is silent")
equip(attacker)
check(combat.IsBatEquipped(attacker), "legitimate server-issued Character Bat resolves as equipped")
issuedHandle.Parent = nil
check(not combat.SwingBat(attacker), "missing direct-child Handle rejects safely")
issuedHandle.Parent = bat
issuedHitbox.Parent = nil
check(not combat.SwingBat(attacker), "missing direct-child Hitbox rejects safely")
issuedHitbox.Parent = bat
overlaps =
    { attacker.Character:FindFirstChild("HumanoidRootPart"), teammate.Character:FindFirstChild("HumanoidRootPart") }
check(combat.SwingBat(attacker), "owned equipped bat starts swing")
local swingHitbox = bat:FindFirstChild("Hitbox")
check(
    #swingSounds == 1 and swingSounds[1].Name == "BatSwing" and swingSounds[1].Position == swingHitbox.Position,
    "accepted swing emits once at the bat Hitbox even when no target is hit"
)
check(not combat.SwingBat(attacker), "swing cooldown rejects repeated request")
check(#swingSounds == 1, "cooldown rejection does not emit another swing sound")
advance(config.HitActiveStart + 0.000001)
check(not movement.IsStunned(attacker) and not movement.IsStunned(teammate), "self and shared teammate are rejected")
local levelOneSize = querySize
advance(config.SwingCooldown)
carry(victim, "Banana")
carry(victim, "Strawberry")
grant(victim, "bat-preserved-smoothie")
local health = victimHumanoid.Health
overlaps = { victim.Character:FindFirstChild("HumanoidRootPart"), victim.Character:FindFirstChild("Head") }
local actualSpawn = ingredients.Spawn
local dropped = {}
ingredients.Spawn = function(...)
    local object = actualSpawn(...)
    if object then
        table.insert(dropped, object)
    end
    return object
end
local traceLines = {}
local previousPrint = env.print
env.print = function(message)
    table.insert(traceLines, message)
end
studio = true
attacker:SetAttribute("BatDebugNextSwing", true)
setup(combat.SwingBat(attacker), "enemy swing")
-- The impact pose can differ from the handle/template reconstruction (authored joints).
local liveHitbox = bat:FindFirstChild("Hitbox")
liveHitbox.CFrame = frame(0, 0, -1)
advance(config.HitActiveStart + 0.000001)
studio = false
env.print = previousPrint
check(attacker:GetAttribute("BatDebugNextSwing") == nil, "one-swing diagnostic automatically disarms")
check(
    string.find(table.concat(traceLines, "\n"), "SetStunned result=true", 1, true) ~= nil,
    "one-swing trace observes final authoritative stun"
)
local batTrace = table.concat(traceLines, "\n")
check(
    string.find(batTrace, "runtimeTool=" .. bat:GetFullName(), 1, true) ~= nil
        and string.find(batTrace, "runtimeToolParent=" .. attacker.Character:GetFullName(), 1, true) ~= nil
        and string.find(batTrace, "isUnderCharacter=true", 1, true) ~= nil
        and string.find(batTrace, "handle=" .. issuedHandle:GetFullName(), 1, true) ~= nil
        and string.find(batTrace, "hitbox=" .. issuedHitbox:GetFullName(), 1, true) ~= nil
        and string.find(batTrace, "issuedValidation=true", 1, true) ~= nil,
    "one-shot diagnostic reports runtime Tool hierarchy and issued validation"
)
check(queryFrame == liveHitbox.CFrame, "query samples actual equipped Hitbox at impact")
check(
    queryParams.FilterDescendantsInstances[1] == attacker.Character
        and #queryParams.FilterDescendantsInstances == 1
        and queryParams.RespectCanCollide == false
        and queryParams.MaxParts == 0,
    "query excludes only attacker descendants and includes noncollidable queryable bodies"
)
check(movement.IsStunned(victim) and victimHumanoid.Health == health, "enemy is stunned without damage")
check(victim:GetAttribute("StunnedUntil") == now + 1.5, "level one controls stun duration")
check(victimHumanoid.WalkSpeed == 0 and victimHumanoid.JumpPower == 0, "stun disables movement and jumping")
check(#dropped == 2 and inventory.GetCarryCount(victim) == 1, "successful hit drops every ingredient once")
for _, object in dropped do
    local velocity = cache.WorldUtil.Part(object).AssemblyLinearVelocity
    local horizontal = vec(velocity.X, 0, velocity.Z).Magnitude
    check(
        horizontal >= config.Scatter.HorizontalMin
            and horizontal <= config.Scatter.HorizontalMax
            and velocity.Y >= config.Scatter.UpwardMin
            and velocity.Y <= config.Scatter.UpwardMax
            and velocity.Z < 0,
        "Bat ingredients scatter upward and away within configured speed bounds"
    )
end
check(
    (cache.WorldUtil.Part(dropped[1]).Position - cache.WorldUtil.Part(dropped[2]).Position).Magnitude > 0.5,
    "Bat burst starts at separated world positions"
)
check(victimHumanoid.PlatformStand and physical[victim.Character], "valid Bat hit activates ragdoll")
local activation = ragdollCalls[#ragdollCalls]
check(
    activation.Enabled and activation.Stunned and activation.CarryCount == 1,
    "ragdoll begins after authoritative stun and ingredient drops"
)
local victimRoot = victim.Character:FindFirstChild("HumanoidRootPart")
check(victimRoot.Impulse == nil, "knockback waits for the next Heartbeat")
heartbeat()
check(
    victimRoot.ImpulseCount == 1
        and victimRoot.Impulse.Z == -config.Knockback.HorizontalSpeed * victimRoot.AssemblyMass
        and victimRoot.Impulse.Y == config.Knockback.UpwardSpeed * victimRoot.AssemblyMass,
    "one mass-aware impulse moves victim away with modest lift"
)
heartbeat()
check(victimRoot.ImpulseCount == 1, "knockback is a one-shot impulse")
check(victim:GetAttribute("HasSmoothie") == true, "stun preserves smoothie state")
check(inventory.DropCarriedIngredients(victim, "repeat") == 0, "repeated forced drop cannot duplicate ingredients")
local droppedParent = dropped[1].Parent
local carryBefore = inventory.GetCarryCount(victim)
check(not inventory.CarryWorldItem(victim, dropped[1]), "stunned victim cannot pick up")
check(not inventory.ClaimWorldItem(victim, dropped[1]), "direct ownership grant also rejects stunned pickup")
check(
    dropped[1].Parent == droppedParent
        and ingredients.GetRecord(dropped[1]) ~= nil
        and inventory.GetCarryCount(victim) == carryBefore,
    "rejected pickup preserves world identity and carry inventory"
)
check(
    not movement.CanPerformGameplayAction(victim) and movement.CanPerformGameplayAction(attacker),
    "authoritative gate isolates the stunned player"
)
check(not blend.Dispense(victim), "stunned victim cannot dispense")
check(
    inventory.ThrowHeld(victim) == nil and not inventory.InteractStash(victim, 3),
    "stunned victim cannot throw or stash"
)
check(not blend.AddProgress(victim, references[victim].TurbineWheel, 1), "stunned victim cannot operate blender")
check(inventory.GetHeldSmoothie(victim) == nil, "stunned victim cannot serve smoothie")
check(inventory.CarryWorldItem(attacker, dropped[1]), "attacker can pick up a dropped ingredient")
check(not inventory.CarryWorldItem(attacker, dropped[1]), "world drop can only be claimed once")
check(
    inventory.Deposit(attacker, "Strawberry", 3) or inventory.Deposit(attacker, "Banana", 3),
    "stolen ingredient can be stashed"
)
ingredients.Spawn = actualSpawn
advance(0.65)
check(
    movement.IsStunned(victim) and victimHumanoid.WalkSpeed == 0,
    "authoritative stun remains active throughout its duration"
)
advance(1.5 - 0.65)
check(
    not movement.IsStunned(victim) and victimHumanoid.JumpPower == movement.GetJumpPower(victim),
    "expiry restores upgraded jump state"
)
local recovery = ragdollCalls[#ragdollCalls]
check(
    not recovery.Enabled
        and recovery.Character == victim.Character
        and recovery.Stunned
        and not physical[victim.Character],
    "ragdoll recovery precedes authoritative stun release"
)
equip(attacker)
setup(combat.SwingBat(attacker), "immune swing")
advance(config.HitActiveStart + 0.000001)
check(not movement.IsStunned(victim), "post-stun immunity rejects chain stun")
advance(config.ImmunitySeconds)
-- Studio regression: authored contact can occur beyond gameplay Reach at level one.
local firstSample = config.HitActiveStart
local sampleStep = config.HitSampleInterval
local windowRoot = victim.Character:FindFirstChild("HumanoidRootPart")
local secondVictim = fighter(-4)
local secondRoot = secondVictim.Character:FindFirstChild("HumanoidRootPart")
overlaps = {}
setup(combat.SwingBat(attacker), "contact enters window on second sample")
advance(firstSample)
check(not movement.IsStunned(victim), "empty first sample does not hit")
liveHitbox.CFrame = frame(0, 0, -2)
overlaps = { windowRoot }
advance(sampleStep + 0.000001)
check(
    movement.IsStunned(victim) and queryFrame == liveHitbox.CFrame,
    "second sample uses live pose and hits new contact"
)
local queriesAfterHit = queryCount
overlaps = { secondRoot }
advance(sampleStep)
check(
    not movement.IsStunned(secondVictim) and queryCount == queriesAfterHit,
    "second-sample hit stops remaining queries and victims"
)
advance(config.Levels[1].StunDuration + config.ImmunitySeconds)
overlaps = { windowRoot }
setup(combat.SwingBat(attacker), "first sample contact")
advance(firstSample + 0.000001)
check(movement.IsStunned(victim), "first sample can select a target")
local stunDeadline = victim:GetAttribute("StunnedUntil")
queriesAfterHit = queryCount
overlaps = { secondRoot }
advance(config.HitSampleInterval)
check(
    not movement.IsStunned(secondVictim)
        and victim:GetAttribute("StunnedUntil") == stunDeadline
        and queryCount == queriesAfterHit,
    "first sample hit cannot hit again or select a second victim"
)
advance(config.Levels[1].StunDuration + config.ImmunitySeconds)
overlaps = {}
local queriesBeforeMiss = queryCount
setup(combat.SwingBat(attacker), "entire window misses")
advance(firstSample + 0.000001)
for _ = 1, math.ceil((config.HitActiveEnd - config.HitActiveStart) / sampleStep) do
    advance(sampleStep + 0.000001)
end
check(queryCount > queriesBeforeMiss + 3 and not movement.IsStunned(victim), "miss samples throughout broader window")
local queriesAtExpiry = queryCount
overlaps = { windowRoot }
advance(sampleStep)
check(
    queryCount == queriesAtExpiry and not movement.IsStunned(victim),
    "expired window cannot hit newly overlapping target"
)
check(not combat.SwingBat(attacker), "miss still consumes full cooldown")
advance(config.SwingCooldown)
-- Early and late contacts are active; startup and callbacks after the deadline are not.
overlaps = { windowRoot }
local beforeWindow = queryCount
setup(combat.SwingBat(attacker), "window startup")
advance(config.HitActiveStart / 2)
check(queryCount == beforeWindow and not movement.IsStunned(victim), "startup has no damaging query")
overlaps = {}
advance(config.HitActiveStart / 2 + 0.000001)
for _ = 1, 7 do
    advance(sampleStep + 0.000001)
end
liveHitbox.CFrame = frame(0, 0, -1.7)
overlaps = { windowRoot }
advance(sampleStep + 0.000001)
check(
    movement.IsStunned(victim) and queryFrame == liveHitbox.CFrame,
    "late contact at roughly 0.40 seconds uses live Hitbox and hits"
)
local afterLateHit = queryCount
overlaps = { secondRoot }
advance(config.HitActiveEnd)
check(queryCount == afterLateHit and not movement.IsStunned(secondVictim), "late hit consumes entire swing")
advance(config.Levels[1].StunDuration + config.ImmunitySeconds)
setup(combat.SwingBat(attacker), "scheduler resumes after deadline")
local beforeDelayed = queryCount
overlaps = { windowRoot }
advance(config.HitActiveEnd + 0.01)
check(queryCount == beforeDelayed and not movement.IsStunned(victim), "late callback never replays expired contacts")
advance(config.SwingCooldown)
for _, cancellation in { "unequip", "death", "membership" } do
    overlaps = {}
    setup(combat.SwingBat(attacker), "window cancellation: " .. cancellation)
    advance(firstSample + 0.000001)
    if cancellation == "unequip" then
        bat.Parent = attacker:FindFirstChildOfClass("Backpack")
        bat.Unequipped:Fire()
        equip(attacker) -- re-equipping must not revive the old swing
    elseif cancellation == "death" then
        attackerHumanoid.Health = 0
        attackerHumanoid.Died:Fire()
    else
        tycoon.RemovePlayer(teammate)
    end
    overlaps = { windowRoot }
    advance(config.HitSampleInterval)
    check(not movement.IsStunned(victim), "remaining samples cancelled by " .. cancellation)
    if cancellation == "death" then
        attackerHumanoid.Health = 100
        combat.ApplyCharacter(attacker, attacker.Character)
        flush()
        bat = bats(attacker)[1]
        liveHitbox = bat:FindFirstChild("Hitbox")
        equip(attacker)
    elseif cancellation == "membership" then
        setup(tycoon.JoinSession(teammate, attacker, tycoon.GetRequestContext(attacker)), "restore teammate")
    end
    advance(config.SwingCooldown)
end
local contactRoot = victim.Character:FindFirstChild("HumanoidRootPart")
contactRoot.Position = vec(0, 0, -5.807)
overlaps = { contactRoot }
setup(combat.SwingBat(attacker), "level one authored contact at 5.807 studs")
advance(config.HitActiveStart + 0.000001)
check(movement.IsStunned(victim), "level one overlap at 5.807 stuns across separate plot sessions")
advance(config.Levels[1].StunDuration + config.ImmunitySeconds)
contactRoot.Position = vec(0, 0, -2)
overlaps = {}
setup(combat.SwingBat(attacker), "close target outside authored volume")
advance(config.HitActiveStart + 0.000001)
check(not movement.IsStunned(victim), "close root distance never substitutes for Hitbox overlap")
advance(config.SwingCooldown)
overlaps = { contactRoot }
local validPose = liveHitbox.CFrame
liveHitbox.CFrame = frame(0, 0, -100)
setup(combat.SwingBat(attacker), "spoofed distant observed Tool pose")
advance(config.HitActiveStart + 0.000001)
check(not movement.IsStunned(victim), "excessively distant Hitbox pose rejects even a reported nearby overlap")
liveHitbox.CFrame = validPose
advance(config.SwingCooldown)
-- Each kind of overlapping descendant resolves through nested Models to the real owner.
for _, name in { "HumanoidRootPart", "Torso", "Left Arm", "Accessory" } do
    local contact
    if name == "Accessory" then
        local accessory = instance("Accessory")
        accessory.Parent = victim.Character
        local nested = instance("Model")
        nested.Parent = accessory
        contact = part("Handle", nested)
    else
        contact = victim.Character:FindFirstChild(name) or part(name, victim.Character)
    end
    overlaps = { contact }
    victim.Character:FindFirstChild("HumanoidRootPart").Position = vec(0, 0, -1)
    setup(combat.SwingBat(attacker), "point blank descendant " .. name)
    advance(config.HitActiveStart + 0.000001)
    check(movement.IsStunned(victim), "point blank overlap resolves owner: " .. name)
    advance(config.Levels[1].StunDuration + config.ImmunitySeconds)
end
victim.Character:FindFirstChild("HumanoidRootPart").Position = vec(0, 0, -3)
for level = 2, 3 do
    setup(tycoon.PurchaseUpgrade(attacker, "Bat", level + 1, tycoon.GetRequestContext(attacker)), "upgrade bat")
    check(#bats(attacker) == 1 and bats(attacker)[1] == bat, "upgrade keeps one existing bat")
    check(
        math.abs(bat:FindFirstChild("Handle").Size.Y - 2 * config.Levels[level].Scale) < 0.0001,
        "visible size follows level"
    )
    equip(attacker)
    victim.Character:FindFirstChild("HumanoidRootPart").Position = vec(0, 0, -7.9 * config.Levels[level].Scale)
    setup(combat.SwingBat(attacker), "upgraded swing")
    advance(config.HitActiveStart + 0.000001)
    check(victim:GetAttribute("StunnedUntil") == now + config.Levels[level].StunDuration, "upgraded stun duration")
    check(
        querySize.X > levelOneSize.X and math.abs(querySize.Z - hitbox.Size.Z * config.Levels[level].Scale) < 0.0001,
        "upgraded query grows modestly"
    )
    advance(config.Levels[level].StunDuration)
    advance(config.ImmunitySeconds)
end
victim.Character:FindFirstChild("HumanoidRootPart").Position = vec(0, 0, -3)
check(handle.Size.Y == 2 and hitbox.Size.Z == 4.703, "stored template is unchanged")
check(bat.Grip == template.Grip, "upgrades preserve authored Tool grip")
-- A client-provided target is ignored by the real adapter.
local remoteService = loadModule("GameplayService")
local requestRemote
local originalNew = env.Instance.new
env.Instance.new = function(class)
    local object = originalNew(class)
    if class == "RemoteEvent" then
        object.OnServerEvent = signal()
        requestRemote = object
    end
    return object
end
remoteService.Init(dependency)
local remote = requestRemote
remote.FireClient = function() end
-- Reject a manually submitted throw using the issued Bat, then restore newest-first throwing.
inventory.ClearHeld(attacker)
for _, id in { "Banana", "Ice" } do
    carry(attacker, id)
end
equip(attacker)
advance(0.2)
remote.OnServerEvent:Fire(attacker, "ThrowHeld")
check(inventory.GetCarryCount(attacker) == 2, "server rejects throw while authoritative Bat is equipped")
bat.Parent = attacker:FindFirstChildOfClass("Backpack")
bat.Unequipped:Fire()
-- A lookalike does not count as the authoritative issued Bat.
local lookalike = instance("Tool")
lookalike.Name, lookalike.Parent = "Bat", attacker.Character
lookalike:SetAttribute("BatLevel", 1)
advance(0.2)
remote.OnServerEvent:Fire(attacker, "ThrowHeld")
check(
    inventory.GetCarryCount(attacker) == 1 and inventory.GetHeldIngredientId(attacker) == "Banana",
    "unequipping issued Bat restores newest-first throw even with an unissued lookalike"
)
lookalike:Destroy()
inventory.ClearHeld(attacker)
equip(attacker)
advance(0.2)
local far = fighter(-100)
overlaps = {}
local adapterTrace = {}
env.print = function(message)
    table.insert(adapterTrace, message)
end
local function adapterLogged(message)
    return string.find(table.concat(adapterTrace, "\n"), message, 1, true) ~= nil
end
studio = true
attacker:SetAttribute("BatDebugNextSwing", true)
remote.OnServerEvent:Fire(attacker, "SwingBat", far, 3, { StunDuration = 999 })
check(
    adapterLogged("GameplayRequest received: SwingBat from " .. attacker.Name)
        and adapterLogged("request adapter accepted: SwingBat")
        and adapterLogged("calling CombatService SwingBat")
        and adapterLogged("[Bat] " .. attacker.Name .. " SwingBat accepted"),
    "request trace crosses adapter dispatch into the real combat handler"
)
check(attacker:GetAttribute("BatDebugNextSwing") == nil, "dispatch preserves the flag until combat consumes it")
table.clear(adapterTrace)
attacker:SetAttribute("BatDebugNextSwing", true)
remote.OnServerEvent:Fire(attacker, "SwingBat")
check(
    adapterLogged("GameplayRequest received: SwingBat")
        and adapterLogged("request adapter rejected: gameplay throttle")
        and not adapterLogged("calling CombatService SwingBat")
        and attacker:GetAttribute("BatDebugNextSwing") == nil,
    "throttle rejection is visible before dispatch and consumes the one-shot rejection trace"
)
advance(config.HitActiveStart + 0.000001)
check(not movement.IsStunned(far), "client cannot choose a target outside server query")
advance(0.2) -- Move beyond the request throttle before testing the independent stun gate.
table.clear(adapterTrace)
movement.SetStunned(attacker, true)
attacker:SetAttribute("BatDebugNextSwing", true)
remote.OnServerEvent:Fire(attacker, "SwingBat")
check(
    adapterLogged("GameplayRequest received: SwingBat")
        and adapterLogged("request adapter rejected: MovementService.IsStunned(attacker)")
        and not adapterLogged("calling CombatService SwingBat")
        and attacker:GetAttribute("BatDebugNextSwing") == nil,
    "stun rejection is visible before dispatch and consumes the one-shot rejection trace"
)
movement.SetStunned(attacker, false)
studio = false
env.print = previousPrint
advance(config.SwingCooldown)
local farther = fighter(-4)
overlaps = { farther.Character:FindFirstChild("HumanoidRootPart"), victim.Character:FindFirstChild("HumanoidRootPart") }
setup(combat.SwingBat(attacker), "nearest enemy swing")
advance(config.HitActiveStart + 0.000001)
check(movement.IsStunned(victim) and not movement.IsStunned(farther), "one swing hits closest valid enemy only")
-- Stunned ownership does not permit swinging; stale timers cannot clear a new character's stun.
tycoon.SetCash(victim, 2000)
setup(tycoon.PurchaseUpgrade(victim, "Bat", 2, tycoon.GetRequestContext(victim)), "victim owns bat")
equip(victim)
check(not combat.SwingBat(victim), "stunned bat owner cannot swing")
victimHumanoid.Health = 0
victimHumanoid.Died:Fire()
check(not movement.IsStunned(victim), "death clears stun")
local oldCharacter = victim.Character
local newCharacter = instance("Model")
newCharacter.Name = victim.Name
newCharacter.Parent = workspaceFake
local newRoot = part("HumanoidRootPart", newCharacter)
impulseRoot(newRoot)
newRoot.CFrame, newRoot.Position = frame(0, 0, -3), vec(0, 0, -3)
part("Head", newCharacter)
local newHumanoid = instance("Humanoid")
newHumanoid.Parent, newHumanoid.Health, newHumanoid.UseJumpPower, newHumanoid.Died = newCharacter, 100, true, signal()
newHumanoid.EquipTool = victimHumanoid.EquipTool
victim.Character, victimHumanoid = newCharacter, newHumanoid
combat.ApplyCharacter(victim, newCharacter)
movement.ApplyCharacter(victim, newCharacter)
overlaps = { newRoot }
oldCharacter.Parent = nil
flush()
check(#bats(victim) == 1 and not movement.IsStunned(victim), "respawn restores owned bat and clears stun")
advance(config.SwingCooldown)
setup(combat.SwingBat(attacker), "new stun after lifecycle reset")
advance(config.HitActiveStart + 0.000001)
advance(1.8) -- old timer is due before the newer stun's deadline
check(movement.IsStunned(victim), "old unstun token cannot clear newer stun")
advance(1.2)
check(not movement.IsStunned(victim), "new stun expires normally")
advance(config.ImmunitySeconds)
-- Engine query candidates still require living enemies, reach, and unobstructed sight.
for _, policy in { "wall", "team", "dead", "behind", "reach", "unequipped" } do
    overlaps = { victim.Character:FindFirstChild("HumanoidRootPart") }
    local root = victim.Character:FindFirstChild("HumanoidRootPart")
    if policy == "wall" then
        workspaceFake.Raycast = function()
            return { Instance = instance("Part") }
        end
    end
    if policy == "team" then
        attacker.Neutral, victim.Neutral, attacker.Team, victim.Team = false, false, "same", "same"
    end
    if policy == "dead" then
        victimHumanoid.Health = 0
    end
    if policy == "behind" then
        root.Position = vec(0, 0, 3)
    end
    if policy == "reach" then
        root.Position = vec(0, 0, -100)
    end
    setup(combat.SwingBat(attacker), "policy swing " .. policy)
    if policy == "unequipped" then
        bats(attacker)[1].Parent = attacker:FindFirstChildOfClass("Backpack")
    end
    advance(config.HitActiveStart + 0.000001)
    check(not movement.IsStunned(victim), "reject invalid target/impact: " .. policy)
    workspaceFake.Raycast = function()
        return nil
    end
    attacker.Neutral, victim.Neutral, victimHumanoid.Health, root.Position = true, true, 100, vec(0, 0, -3)
    equip(attacker)
    advance(config.SwingCooldown)
end
-- Death and membership changes invalidate a pending impact.
setup(combat.SwingBat(attacker), "pending swing before death")
attackerHumanoid.Health = 0
attackerHumanoid.Died:Fire()
advance(config.HitActiveStart + 0.000001)
check(not movement.IsStunned(victim), "attacker death cancels pending impact")
attackerHumanoid.Health = 100
combat.ApplyCharacter(attacker, attacker.Character)
flush()
equip(attacker)
setup(combat.SwingBat(attacker), "pending membership swing")
tycoon.RemovePlayer(teammate)
advance(config.HitActiveStart + 0.000001)
check(not movement.IsStunned(victim), "membership revision change cancels pending swing")
advance(config.SwingCooldown)
local lost = bats(attacker)[1]
lost:Destroy()
flush()
check(#bats(attacker) == 1 and bats(attacker)[1] ~= lost, "unexpected destruction restores one authorized bat")
equip(attacker)
setup(combat.SwingBat(attacker), "leave during pending swing")
combat.RemovePlayer(attacker)
advance(config.HitActiveStart + 0.000001)
check(
    not combat.SwingBat(attacker) and not movement.IsStunned(victim),
    "leaving cancels combat state and pending impact"
)
combat.RemovePlayer(victim)
check(not movement.IsStunned(victim), "leaving clears victim stun state")
tycoon.RemovePlayer(attacker)
check(#bats(attacker) == 0, "session removal revokes bat access")

-- A deferred replacement cannot resurrect tools after removal.
local departing = fighter(0)
tycoon.SetCash(departing, 2000)
setup(tycoon.PurchaseUpgrade(departing, "Bat", 2, tycoon.GetRequestContext(departing)), "departing bat")
bats(departing)[1]:Destroy()
combat.RemovePlayer(departing)
flush()
check(#bats(departing) == 0, "leaving cancels deferred weapon recovery")
local utility = cache.WorldUtil
cache.WorldUtil = nil
local realWorldUtil = loadModule("WorldUtil")
local nearby = part("Interaction", workspaceFake)
movement.SetStunned(departing, true)
check(not realWorldUtil.Near(departing, nearby, 10), "real proximity gate blocks stunned interactions")
movement.SetStunned(departing, false)
check(realWorldUtil.Near(departing, nearby, 10), "proximity gate works again after unstun")
cache.WorldUtil = utility

-- A fresh grant reads widened Studio geometry as its baseline at every level.
local originalSize = hitbox.Size
hitbox.Size = vec(originalSize.X * 2, originalSize.Y, originalSize.Z)
local widened = fighter(0)
tycoon.SetCash(widened, 20000)
overlaps = {}
for level = 1, 3 do
    setup(tycoon.PurchaseUpgrade(widened, "Bat", level + 1, tycoon.GetRequestContext(widened)), "widened bat upgrade")
    equip(widened)
    setup(combat.SwingBat(widened), "widened bat swing")
    advance(config.HitActiveStart + 0.000001)
    check(
        math.abs(querySize.X - hitbox.Size.X * config.Levels[level].Scale) < 0.0001,
        "authored widened Hitbox remains the scaled query baseline"
    )
    advance(config.SwingCooldown)
end
hitbox.Size = originalSize

-- Integration-specific failure and deferred callback contracts.
local hitter = fighter(0)
tycoon.SetCash(hitter, 2000)
setup(tycoon.PurchaseUpgrade(hitter, "Bat", 2, tycoon.GetRequestContext(hitter)), "integration hitter owns bat")
equip(hitter)
local function hitTarget(target)
    overlaps = { target.Character:FindFirstChild("HumanoidRootPart") }
    setup(combat.SwingBat(hitter), "integration hit")
    advance(config.HitActiveStart + 0.000001)
    setup(movement.IsStunned(target), "integration target stunned")
end
for _, failure in { "on-false", "on-error", "off-false", "off-error" } do
    local target = fighter(-3)
    carry(target, "Banana")
    ragdollFailure = failure
    hitTarget(target)
    check(inventory.GetCarryCount(target) == 0, failure .. " preserves ingredient drop")
    heartbeat()
    local root = target.Character:FindFirstChild("HumanoidRootPart")
    if string.sub(failure, 1, 2) == "on" then
        check(root.Impulse == nil, failure .. " skips knockback")
    end
    advance(config.Levels[1].StunDuration)
    check(
        not movement.IsStunned(target) and target:GetAttribute("StunnedUntil") == 0,
        failure .. " cannot strand authoritative stun"
    )
    ragdollFailure = nil
    combat.RemovePlayer(target)
end
for _, invalidation in
    { "death", "removed", "character-removed", "replacement", "unstunned", "unragdolled", "expired", "new-token" }
do
    local target, humanoid = fighter(-3)
    hitTarget(target)
    local original = target.Character
    local originalRoot = original:FindFirstChild("HumanoidRootPart")
    if invalidation == "death" then
        humanoid.Health = 0
        humanoid.Died:Fire()
    elseif invalidation == "removed" then
        target.Parent = nil
        combat.RemovePlayer(target)
    elseif invalidation == "character-removed" then
        original.Parent = nil
    elseif invalidation == "expired" then
        advance(config.Levels[1].StunDuration)
    elseif invalidation == "replacement" then
        local replacement = fighter(-3)
        target.Character = replacement.Character
    elseif invalidation == "unstunned" then
        movement.SetStunned(target, false)
    elseif invalidation == "unragdolled" then
        physical[original] = false
    else
        -- Same character, new stun token before the old recovery deadline.
        combat.ApplyCharacter(target, original)
        flush()
        advance(config.SwingCooldown)
        hitTarget(target)
    end
    heartbeat()
    if invalidation == "new-token" then
        check(originalRoot.ImpulseCount == 1, "old token cannot add an impulse to a newer stun on the same character")
        advance(0.4) -- First stun expires; newer one remains active.
        check(
            movement.IsStunned(target) and physical[original],
            "old recovery cannot clear a newer same-character stun"
        )
    else
        check(originalRoot.Impulse == nil, invalidation .. " cancels deferred knockback")
    end
    local callsBeforeRecovery = #ragdollCalls
    advance(config.Levels[1].StunDuration)
    if invalidation == "replacement" then
        check(
            #ragdollCalls == callsBeforeRecovery and target.Character:FindFirstChild("HumanoidRootPart").Impulse == nil,
            "old callbacks cannot impulse or unragdoll a replaced character"
        )
    end
    combat.RemovePlayer(target)
end
-- Coincident roots use attacker forward, including a safe fallback for vertical forward.
for _, forward in { vec(1, 0, 0), vec(0, 1, 0) } do
    local target = fighter(0)
    local root = target.Character:FindFirstChild("HumanoidRootPart")
    root.AssemblyMass = 25
    hitter.Character:FindFirstChild("HumanoidRootPart").CFrame.LookVector = forward
    hitTarget(target)
    heartbeat()
    local expected = if forward.X == 1 then vec(7, 4, 0) else vec(0, 4, -7)
    check(
        (root.Impulse / root.AssemblyMass - expected).Magnitude < 0.0001,
        "coincident roots normalize safely and mass preserves configured velocity change"
    )
    advance(config.Levels[1].StunDuration)
    combat.RemovePlayer(target)
end

-- Classification uses the customer authority; both kinds share the same geometry/token gate.
local registeredCustomer = instance("Model")
registeredCustomer.Name, registeredCustomer.Parent = "Customer", workspaceFake
local customerRoot = part("HumanoidRootPart", registeredCustomer)
local customerHits = 0
local receivedContext
local realCustomerService = dependency.CustomerService
local customerEligible = true
dependency.CustomerService = {
    CanHitCustomer = function(actor, model)
        return actor == hitter and model == registeredCustomer and customerEligible
    end,
    HitCustomer = function(actor, model, context)
        setup(actor == hitter and model == registeredCustomer, "dispatch registered customer")
        customerHits += 1
        receivedContext = context
        return true
    end,
}
hitter.Character:FindFirstChild("HumanoidRootPart").CFrame.LookVector = vec(0, 0, -1)
local competingPlayer = fighter(-3)
local savedRaycast = workspaceFake.Raycast
for _, rejection in { "authority", "distance", "behind", "wall", "none" } do
    advance(config.SwingCooldown)
    customerEligible = rejection ~= "authority"
    customerRoot.Position = if rejection == "distance"
        then vec(0, 0, -100)
        elseif rejection == "behind" then vec(0, 0, 2)
        else vec(0, 0, -2)
    workspaceFake.Raycast = function()
        return if rejection == "wall" then { Instance = instance("Part") } else nil
    end
    overlaps = { customerRoot, customerRoot }
    if rejection == "none" then
        table.insert(overlaps, competingPlayer.Character:FindFirstChild("HumanoidRootPart"))
    end
    setup(combat.SwingBat(hitter), "customer candidate swing")
    advance(config.HitActiveStart + 0.000001)
    check(customerHits == (if rejection == "none" then 1 else 0), rejection .. " shares customer validation")
    advance(config.HitSampleInterval)
end
check(
    not movement.IsStunned(competingPlayer) and customerHits == 1,
    "nearest customer wins over player and duplicate parts/later samples cannot accept another target"
)
check(
    receivedContext.Duration == config.Levels[1].StunDuration and receivedContext.Direction.Z == -1,
    "customer receives server-owned duration and shared knockback direction"
)
advance(config.SwingCooldown)
customerRoot.Position = vec(0, 0, -4)
overlaps = { customerRoot, competingPlayer.Character:FindFirstChild("HumanoidRootPart") }
setup(combat.SwingBat(hitter), "closer player competes with customer")
advance(config.HitActiveStart + 0.000001)
check(
    movement.IsStunned(competingPlayer) and customerHits == 1,
    "nearest player keeps existing player stun handling without hitting customer"
)
workspaceFake.Raycast = savedRaycast
dependency.CustomerService = realCustomerService
