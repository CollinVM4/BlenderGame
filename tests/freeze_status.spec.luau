check(
    authoredConfig.FreezeSeconds == 2.75
        and authoredConfig.FreezeGrowthSeconds == 0.2
        and authoredConfig.ImmunitySeconds == 4,
    "central timing includes formation in 2.75 seconds and four-second immunity"
)
local freeze = loadModule("FreezeStatusService")
local remote = { OnServerEvent = signal() }
shared.Events.SprintEvents = "SprintEvents"
cache.SprintEvents = function()
    return remote
end
local sprint = loadModule("SprintService")
freeze.Init(deps)
sprint.Init(deps)
local target, h = fighter("A")
ready(target)
sprint.ResetCharacter(target)
freeze.ApplyCharacter(target, target.Character)
flush()
upgrades.Jump = 3
movement.RefreshPlayer(target)
local jump = movement.GetJumpPower(target)
remote.OnServerEvent:Fire(target, true)
advance(0.1)
local stamina = sprint.GetSnapshot(target).StaminaCurrent
check(freeze.Apply(target), "eligible direct hit always applies freeze")
check(
    movement.IsFrozen(target) and h.WalkSpeed == 0 and h.JumpPower == 0,
    "freeze locks voluntary movement and upgraded jump"
)
check(not movement.CanPerformGameplayAction(target), "existing bat/carry/throw action gate blocks freeze")
remote.OnServerEvent:Fire(target, true)
advance(0.1)
check(
    sprint.GetSnapshot(target).StaminaCurrent >= stamina and not sprint.GetSnapshot(target).IsSprinting,
    "attempted sprint during freeze consumes no stamina"
)
movement.SetStunned(target, true)
movement.SetStunned(target, false)
check(
    h.WalkSpeed == 0 and h.JumpPower == 0 and movement.IsFrozen(target),
    "bat recovery cannot release the freeze lock"
)
check(not freeze.Apply(target), "active freeze cannot stack or extend")
advance(2.64)
check(movement.IsFrozen(target), "freeze remains active before 2.75 seconds")
advance(0.01)
check(
    not movement.IsFrozen(target) and h.JumpPower == jump and h.WalkSpeed == movement.GetBaseWalkSpeed(target),
    "thaw restores current upgrades at 2.75 seconds including formation"
)
check(not freeze.Apply(target), "thaw starts immunity")
advance(3.99)
check(not freeze.Apply(target), "immunity lasts four seconds")
advance(0.01)
check(freeze.Apply(target), "freeze is eligible at immunity boundary")
movement.SetStunned(target, true)
advance(2.75)
check(movement.IsStunned(target) and h.WalkSpeed == 0, "thaw cannot release independent bat stun")
movement.SetStunned(target, false)
advance(4)
check(freeze.Apply(target), "freeze after independent stun recovery")
h.Health = 0
h.Died:Fire()
check(
    not movement.IsFrozen(target) and not freezeVisuals[target.Character],
    "death immediately cancels ice and movement status"
)
local old = target.Character
local other, newHumanoid = fighter("B")
target.Character = other.Character
other.Character = nil
freeze.ApplyCharacter(target, target.Character)
ready(target)
flush()
check(
    not movement.IsFrozen(target) and newHumanoid.JumpPower == jump and freeze.Apply(target),
    "respawn inherits neither freeze nor immunity"
)
advance(2.75)
check(not movement.IsFrozen(target), "old delayed callbacks cannot strand new-character movement")
advance(4)
check(freeze.Apply(target), "freeze before delayed server thaw")
advance(5) -- Timer callback arrives later than the nominal deadline.
check(not movement.IsFrozen(target) and not freeze.Apply(target), "immunity begins at actual delayed thaw")
advance(3.99)
check(not freeze.Apply(target), "delayed thaw retains a full four seconds of immunity")
advance(0.01)
check(freeze.Apply(target), "immunity expires four seconds after delayed thaw")
freeze.RemovePlayer(target)
check(not freezeVisuals[old] and not movement.IsFrozen(target), "departure removes status and visuals")
print("PASS: Freeze/movement lifecycle contracts")
