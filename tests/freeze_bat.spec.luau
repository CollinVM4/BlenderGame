-- Real bat combat + freeze + movement; native R15 recovery remains a Studio check.
services.RunService.IsServer = function()
    return true
end
local iceConfig = loadModule("IceGunConfig")
local freeze = loadModule("FreezeStatusService")
local ice = {}
dependency.IceGunEffects = {
    Freeze = function(character)
        ice[character] = true
    end,
    ClearFreeze = function(character)
        ice[character] = nil
    end,
}
freeze.Init(dependency)
for _, scenario in
    {
        { Level = 1, FreezeFirst = true },
        { Level = 3, FreezeFirst = true },
        { Level = 1, FreezeFirst = false },
        { Level = 3, FreezeFirst = false },
    }
do
    local hitter = fighter(0)
    tycoon.SetCash(hitter, 1000000)
    for level = 1, scenario.Level do
        setup(tycoon.PurchaseUpgrade(hitter, "Bat", level + 1, tycoon.GetRequestContext(hitter)), "overlap bat upgrade")
    end
    equip(hitter)
    local target, h = fighter(-3)
    local character = target.Character
    local root = character:FindFirstChild("HumanoidRootPart")
    freeze.ApplyCharacter(target, character)
    flush()
    local frozenAt = now
    if scenario.FreezeFirst then
        setup(freeze.Apply(target), "freeze before bat")
    end
    overlaps = { root }
    setup(combat.SwingBat(hitter), "overlap bat swing")
    advance(config.HitActiveStart + 0.000001)
    heartbeat()
    local stunnedAt = now
    check(
        character:GetAttribute("BatStunned") == true
            and character:GetAttribute("BatImmuneUntil") > workspaceFake:GetServerTimeNow(),
        "bat publishes separate active/immunity status for presentation"
    )
    if not scenario.FreezeFirst then
        setup(freeze.Apply(target), "freeze during bat stun")
        frozenAt = now
    end
    check(
        movement.IsFrozen(target) and movement.IsStunned(target) and h.PlatformStand,
        "both independent statuses coexist"
    )
    local thawAt = frozenAt + iceConfig.FreezeSeconds
    local recoverAt = stunnedAt + config.Levels[scenario.Level].StunDuration
    advance(math.min(thawAt, recoverAt) - now + 0.000001)
    if recoverAt < thawAt then
        check(
            not movement.IsStunned(target)
                and movement.IsFrozen(target)
                and not h.PlatformStand
                and h.WalkSpeed == 0
                and h.JumpPower == 0
                and ice[character],
            "bat recovery restores ragdoll while preserving freeze and movement lock"
        )
    else
        check(
            movement.IsStunned(target)
                and not movement.IsFrozen(target)
                and h.PlatformStand
                and h.WalkSpeed == 0
                and h.JumpPower == 0
                and not ice[character],
            "thaw removes only ice while preserving bat ragdoll and movement lock"
        )
    end
    advance(math.max(thawAt, recoverAt) - now + 0.000001)
    check(character:GetAttribute("BatStunned") == nil, "bat recovery clears only its active presentation status")
    check(
        not movement.IsMovementLocked(target)
            and not h.PlatformStand
            and root.OwnershipAuto
            and h.WalkSpeed == movement.GetBaseWalkSpeed(target)
            and h.JumpPower == movement.GetJumpPower(target),
        "last status expiry restores current movement and network ownership"
    )
    freeze.RemovePlayer(target)
    combat.RemovePlayer(target)
    combat.RemovePlayer(hitter)
end

-- Invalidate both outstanding callbacks together, then freeze the replacement.
local hitter = fighter(0)
tycoon.SetCash(hitter, 1000000)
setup(tycoon.PurchaseUpgrade(hitter, "Bat", 2, tycoon.GetRequestContext(hitter)), "lifecycle bat")
equip(hitter)
for _, reason in { "death", "character-removing", "departure" } do
    local target, h = fighter(-3)
    local old = target.Character
    freeze.ApplyCharacter(target, old)
    flush()
    setup(freeze.Apply(target), "lifecycle freeze")
    overlaps = { old:FindFirstChild("HumanoidRootPart") }
    setup(combat.SwingBat(hitter), "lifecycle bat swing")
    advance(config.HitActiveStart + 0.000001)
    if reason == "death" then
        h.Health = 0
        h.Died:Fire()
    elseif reason == "character-removing" then
        target.CharacterRemoving:Fire(old)
    else
        combat.RemovePlayer(target)
        freeze.RemovePlayer(target)
    end
    check(not movement.IsMovementLocked(target) and not ice[old], reason .. " cancels both locks and ice")
    check(
        old:GetAttribute("BatStunned") == nil and old:GetAttribute("BatImmuneUntil") == nil,
        reason .. " cancels replicated bat outline status"
    )
    advance(1)
    local replacement = fighter(-3)
    target.Character = replacement.Character
    replacement.Character = nil
    movement.ApplyCharacter(target, target.Character)
    combat.ApplyCharacter(target, target.Character)
    freeze.ApplyCharacter(target, target.Character)
    flush()
    setup(freeze.Apply(target), "replacement freeze")
    advance(1.5)
    check(
        movement.IsFrozen(target) and ice[target.Character],
        "old bat/thaw callbacks cannot unlock replacement freeze"
    )
    advance(1.01)
    check(not movement.IsMovementLocked(target), "replacement recovers on its own deadline")
    combat.RemovePlayer(target)
    freeze.RemovePlayer(target)
end
print("PASS: Freeze/bat independent recovery integration")
