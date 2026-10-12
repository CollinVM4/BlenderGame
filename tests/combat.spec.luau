local attacker, attackerHumanoid = fighter(0)
local victim, victimHumanoid = fighter(-3)
local teammate = fighter(-2)
tycoon.RemovePlayer(teammate)
setup(tycoon.JoinSession(teammate, attacker, tycoon.GetRequestContext(attacker)), "join teammate")
check(#bats(attacker) == 0, "level zero grants no bat")
attacker:SetAttribute("BatLevel", 3)
combat.RefreshPlayer(attacker)
check(#bats(attacker) == 0 and not combat.SwingBat(attacker), "replicated level cannot spoof ownership")
tycoon.SetCash(attacker, 1000000)
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
    issuedHandle ~= nil and issuedHandle:IsA("BasePart") and issuedHitbox ~= nil and issuedHitbox:IsA("BasePart"),
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
check(
    movement.IsStunned(victim) and victimHumanoid.Health == health - 25,
    "enemy is stunned and takes level-one damage once"
)
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
        and victimRoot.Impulse.Z == -config.Levels[1].HorizontalKnockback * victimRoot.AssemblyMass
        and victimRoot.Impulse.Y == config.Levels[1].VerticalKnockback * victimRoot.AssemblyMass,
    "one mass-aware impulse moves victim away with modest lift"
)
heartbeat()
check(victimRoot.ImpulseCount == 1, "knockback is a one-shot impulse")
advance(config.Knockback.ServerOwnershipSeconds)
check(victimRoot.OwnershipAuto and movement.IsStunned(victim), "ownership returns before stun ends")
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
    inventory.ThrowHeld(victim) == nil and not inventory.InteractStash(victim, 3, victim, nil, "STORE"),
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
advance(1.5 - 0.65 - config.Knockback.ServerOwnershipSeconds)
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
heartbeat()
check(victimRoot.ImpulseCount == 1, "post-recovery immunity prevents another launch")
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
victimHumanoid.Health = 100 -- Reset between independent geometry cases.
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
victimHumanoid.Health = 100 -- Reset between independent geometry cases.
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
victimHumanoid.Health = 100 -- Reset between independent geometry cases.
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
victimHumanoid.Health = 100 -- Reset between independent geometry cases.
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
    victimHumanoid.Health = 100 -- Independent geometry cases, not a continuous duel.
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
    victimHumanoid.Health = 100 -- Reset between independent geometry cases.
end
victim.Character:FindFirstChild("HumanoidRootPart").Position = vec(0, 0, -3)
for level = 2, 3 do
    victimHumanoid.Health = 100
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
    heartbeat()
    check(
        (victimRoot.Impulse / victimRoot.AssemblyMass - vec(
            0,
            config.Levels[level].VerticalKnockback,
            -config.Levels[level].HorizontalKnockback
        )).Magnitude < 0.0001,
        "purchased bat level controls independent horizontal and vertical launch speeds"
    )
    check(
        victimHumanoid.Health == 100 - 100 * config.Levels[level].DamageFraction,
        "upgraded bat applies authoritative damage"
    )
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
-- Damage balance: real combat + regeneration + death ingredient lifecycle.
-- Health/queries/physics are engine doubles; all gameplay decisions are real services.
services.RunService.Heartbeat = signal()
services.RunService.Heartbeat.Once = function(_, callback)
    table.insert(heartbeatCallbacks, callback)
end
local regen = loadModule("HealthRegenService")
regen.Init()
local headDrops = loadModule("PlayerHeadDropService")
headDrops.Init(dependency)
local function stepCombat(seconds)
    advance(seconds)
    services.RunService.Heartbeat:Fire(seconds)
    heartbeat()
end
local function headCount(p)
    local count = 0
    for _, object in services.CollectionService:GetTagged("IngredientWorldItem") do
        if ingredients.GetRecord(object) and object:GetAttribute("SourceUserId") == p.UserId then
            count += 1
        end
    end
    return count
end
for level, expected in { { 75, 50, 25, 0 }, { 66, 32, 0 }, { 50, 0 } } do
    local actor = fighter(0)
    local target, h = fighter(-3)
    target.DisplayName = target.Name
    target.Character.ChildAdded = signal()
    tycoon.SetCash(actor, 1000000)
    for purchased = 1, level do
        setup(
            tycoon.PurchaseUpgrade(actor, "Bat", purchased + 1, tycoon.GetRequestContext(actor)),
            "damage bat upgrade"
        )
    end
    equip(actor)
    -- Replicated attributes must not affect the authoritative damage tier.
    actor:SetAttribute("BatLevel", 3)
    bats(actor)[1]:SetAttribute("BatLevel", 3)
    regen.ApplyCharacter(target, target.Character)
    headDrops.ApplyCharacter(target, target.Character)
    local function swing()
        overlaps = {
            target.Character:FindFirstChild("Head"),
            target.Character:FindFirstChild("HumanoidRootPart"),
            target.Character:FindFirstChild("Head"),
        }
        setup(combat.SwingBat(actor), "damage swing")
        stepCombat(config.HitActiveStart + 0.000001)
    end
    local shield = instance("ForceField")
    shield.Parent = target.Character
    swing()
    check(h.Health == 100 and not movement.IsStunned(target), "spawn shield blocks damage and stun")
    stepCombat(config.SwingCooldown)
    shield:Destroy()
    -- Shared plot membership and Roblox teams retain their existing restrictions.
    actor.Neutral, target.Neutral, actor.Team, target.Team = false, false, "damage-team", "damage-team"
    swing()
    check(h.Health == 100 and not movement.IsStunned(target), "Roblox teammates take no damage")
    actor.Neutral, target.Neutral = true, true
    stepCombat(config.SwingCooldown)
    local friend, friendHumanoid = fighter(-2)
    tycoon.RemovePlayer(friend)
    setup(tycoon.JoinSession(friend, actor, tycoon.GetRequestContext(actor)), "damage teammate joins plot")
    overlaps = { friend.Character:FindFirstChild("HumanoidRootPart") }
    setup(combat.SwingBat(actor), "shared plot swing")
    stepCombat(config.HitActiveStart + 0.000001)
    check(friendHumanoid.Health == 100 and not movement.IsStunned(friend), "shared plot teammates take no damage")
    stepCombat(config.SwingCooldown)
    for hitIndex, remaining in expected do
        swing()
        check(
            h.Health == remaining,
            "100 HP level " .. level .. " hit " .. hitIndex .. " leaves " .. remaining .. " HP"
        )
        check(not combat.SwingBat(actor), "successful damage still enforces swing cooldown")
        stepCombat(config.HitSampleInterval)
        check(h.Health == remaining, "duplicate body parts and later samples cannot repeat damage")
        if remaining > 0 then
            -- A ready attacker still cannot damage a ragdolled target.
            stepCombat(config.SwingCooldown)
            swing()
            check(h.Health == remaining, "ragdoll blocks repeat damage")
            stepCombat(config.Levels[level].StunDuration)
            check(
                not movement.IsStunned(target) and not physical[target.Character],
                "surviving damage recovers movement and ragdoll"
            )
            swing()
            check(
                h.Health == remaining and not movement.IsStunned(target),
                "post-ragdoll immunity blocks damage and stun"
            )
            stepCombat(config.ImmunitySeconds)
            check(h.Health == remaining, "regen stays delayed between consecutive valid hits")
        end
    end
    check(h.Health == 0 and not movement.IsStunned(target), "lethal hit follows normal death stun cleanup")
    check(headCount(target) == 1, "Bat death drops exactly one PlayerHead ingredient")
    h.Died:Fire()
    check(headCount(target) == 1, "repeated death cannot duplicate PlayerHead")
    -- Fresh character reuses the player, with no old stun/immunity or damage token.
    local oldCharacter = target.Character
    target.CharacterRemoving:Fire(oldCharacter)
    local character = instance("Model")
    character.Name, character.Parent, character.ChildAdded = target.Name, workspaceFake, signal()
    local root = part("HumanoidRootPart", character)
    root.Position, root.CFrame = vec(0, 0, -3), frame(0, 0, -3)
    impulseRoot(root)
    part("Head", character)
    local fresh = instance("Humanoid")
    fresh.Parent, fresh.Health, fresh.Died, fresh.UseJumpPower = character, 100, signal(), true
    prepareHumanoid(fresh)
    target.Character = character
    movement.ApplyCharacter(target, character)
    combat.ApplyCharacter(target, character)
    regen.ApplyCharacter(target, character)
    headDrops.ApplyCharacter(target, character)
    flush()
    stepCombat(config.SwingCooldown)
    swing()
    check(
        fresh.Health == expected[1] and h.Health == 0,
        "respawn takes fresh authoritative damage without changing old health"
    )
    stepCombat(config.Levels[level].StunDuration + config.ImmunitySeconds)
    check(
        not movement.IsStunned(target) and fresh.Health == expected[1],
        "old death/recovery callbacks cannot damage or strand respawn"
    )
    combat.RemovePlayer(actor)
    combat.RemovePlayer(target)
    regen.RemovePlayer(target)
    headDrops.RemovePlayer(target)
end

-- Upgrade changes during startup are resolved again by the server at impact.
do
    local actor = fighter(0)
    local target, h = fighter(-3)
    h.MaxHealth, h.Health = 200, 200
    tycoon.SetCash(actor, 1000000)
    setup(tycoon.PurchaseUpgrade(actor, "Bat", 2, tycoon.GetRequestContext(actor)), "impact-level bat unlock")
    equip(actor)
    overlaps = { target.Character:FindFirstChild("HumanoidRootPart") }
    setup(combat.SwingBat(actor), "impact-level swing")
    setup(tycoon.PurchaseUpgrade(actor, "Bat", 3, tycoon.GetRequestContext(actor)), "upgrade during startup")
    stepCombat(config.HitActiveStart + 0.000001)
    check(h.Health == 132, "impact uses current server upgrade and target MaxHealth")
    combat.RemovePlayer(actor)
    combat.RemovePlayer(target)
end

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
victimHumanoid.Health = 100
local farther = fighter(-4)
overlaps = { farther.Character:FindFirstChild("HumanoidRootPart"), victim.Character:FindFirstChild("HumanoidRootPart") }
setup(combat.SwingBat(attacker), "nearest enemy swing")
advance(config.HitActiveStart + 0.000001)
check(movement.IsStunned(victim) and not movement.IsStunned(farther), "one swing hits closest valid enemy only")
-- Stunned ownership does not permit swinging; stale timers cannot clear a new character's stun.
tycoon.SetCash(victim, 1000000)
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
prepareHumanoid(newHumanoid)
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
tycoon.SetCash(departing, 1000000)
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
tycoon.SetCash(widened, 1000000)
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
