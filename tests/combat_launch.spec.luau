-- Launch lifecycle integration runs independently of unrelated inventory/adapter checks.
local launcher = fighter(0)
tycoon.SetCash(launcher, 1000000)
for level = 1, 3 do
    setup(tycoon.PurchaseUpgrade(launcher, "Bat", level + 1, tycoon.GetRequestContext(launcher)), "launch upgrade")
    equip(launcher)
    local target, humanoid = fighter(-3)
    local character = target.Character
    local root = character:FindFirstChild("HumanoidRootPart")
    overlaps = { root, character:FindFirstChild("Head") }
    setup(combat.SwingBat(launcher), "launch swing")
    advance(config.HitActiveStart + 0.000001)
    heartbeat()
    local launchVelocity = root.Impulse / root.AssemblyMass
    check(
        launchVelocity.Z == -config.Levels[level].HorizontalKnockback
            and launchVelocity.Y == config.Levels[level].VerticalKnockback,
        "valid player receives upgraded launch"
    )
    advance(config.HitSampleInterval)
    heartbeat()
    check(root.ImpulseCount == 1, "duplicate parts and later swing samples cannot relaunch")
    advance(config.Levels[level].StunDuration)
    check(
        not movement.IsStunned(target)
            and not physical[character]
            and root.OwnershipAuto
            and humanoid.JumpPower == movement.GetJumpPower(target),
        "strong launch expires into restored movement and ownership"
    )
    setup(combat.SwingBat(launcher), "immune target swing")
    advance(config.HitActiveStart + 0.000001)
    heartbeat()
    check(root.ImpulseCount == 1 and not movement.IsStunned(target), "recovery immunity refuses further launches")
    advance(config.SwingCooldown + config.ImmunitySeconds)
    combat.RemovePlayer(target)
end
combat.RemovePlayer(launcher)

-- Integration-specific failure and deferred callback contracts.
local hitter = fighter(0)
tycoon.SetCash(hitter, 1000000)
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
    check(root.OwnershipAuto, failure .. " releases temporary ownership")
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
    local tuning = config.Levels[1]
    local expected = if forward.X == 1
        then vec(tuning.HorizontalKnockback, tuning.VerticalKnockback, 0)
        else vec(0, tuning.VerticalKnockback, -tuning.HorizontalKnockback)
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

-- Death/reset after the impulse must release ownership without touching a fresh spawn.
do
    local actor = fighter(0)
    tycoon.SetCash(actor, 1000000)
    for level = 1, 3 do
        setup(tycoon.PurchaseUpgrade(actor, "Bat", level + 1, tycoon.GetRequestContext(actor)), "lifecycle Giant bat")
    end
    equip(actor)
    for _, ending in { "death", "reset", "leave" } do
        local target, humanoid = fighter(-3)
        local character = target.Character
        local root = character:FindFirstChild("HumanoidRootPart")
        root:SetNetworkOwner(target)
        overlaps = { root }
        setup(combat.SwingBat(actor), "Giant lifecycle swing")
        advance(config.HitActiveStart + 0.000001)
        heartbeat()
        check(root.ImpulseCount == 1 and root.NetworkOwner == nil, "Giant launches before lifecycle interruption")
        if ending == "death" then
            humanoid.Health = 0
            humanoid.Died:Fire()
        elseif ending == "reset" then
            target.CharacterRemoving:Fire(character)
        else
            combat.RemovePlayer(target)
        end
        check(
            not movement.IsStunned(target) and not physical[character] and root.NetworkOwner == target,
            ending .. " clears ragdoll/stun and restores manual ownership"
        )
        local replacement, replacementHumanoid = fighter(-3)
        target.Character = replacement.Character
        movement.ApplyCharacter(target, target.Character)
        combat.ApplyCharacter(target, target.Character)
        flush()
        advance(config.Levels[3].StunDuration + config.ImmunitySeconds)
        heartbeat()
        check(
            not movement.IsStunned(target)
                and replacementHumanoid.JumpPower > 0
                and target.Character:FindFirstChild("HumanoidRootPart").Impulse == nil,
            ending .. " leaves respawn free of stale launch and recovery callbacks"
        )
        combat.RemovePlayer(target)
        combat.RemovePlayer(replacement)
    end
    combat.RemovePlayer(actor)
end
for _, failure in { "unavailable", "error" } do
    local actor = fighter(0)
    tycoon.SetCash(actor, 1000000)
    setup(tycoon.PurchaseUpgrade(actor, "Bat", 2, tycoon.GetRequestContext(actor)), "ownership failure bat")
    equip(actor)
    local target = fighter(-3)
    local root = target.Character:FindFirstChild("HumanoidRootPart")
    if failure == "unavailable" then
        root.CanSetNetworkOwnership = function()
            return false
        end
    else
        root.SetNetworkOwner = function()
            error("ownership unavailable")
        end
    end
    overlaps = { root }
    setup(combat.SwingBat(actor), "ownership failure swing")
    advance(config.HitActiveStart + 0.000001)
    heartbeat()
    check(
        root.Impulse == nil and movement.IsStunned(target),
        "ownership failure skips unreliable launch but preserves hit stun"
    )
    advance(config.Levels[1].StunDuration)
    check(not movement.IsStunned(target) and not physical[target.Character], "ownership failure cannot strand recovery")
    combat.RemovePlayer(actor)
    combat.RemovePlayer(target)
end
