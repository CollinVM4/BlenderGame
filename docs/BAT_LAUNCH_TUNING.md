# Bat launch tuning

Player hits now use these initial horizontal/upward velocity changes in studs/second:

| Bat | Horizontal | Upward | Stun (unchanged) | Damage (unchanged) |
|---|---:|---:|---:|---:|
| Level 0 / no bat | unchanged | unchanged | none | none |
| Level 1 / Normal | 28 | 10 | 1.5 seconds | 25% MaxHealth |
| Level 2 / Big Bat | 48 | 20 | 2.25 seconds | 34% MaxHealth |
| Level 3 / Giant | 75 | 32 | 3 seconds | 50% MaxHealth |

These are impulse tuning targets, not promised travel distances. Existing motion,
contacts, friction, gravity, articulated body mass, and replication affect the result.
BatConfig owns the targets and the new 110 horizontal / 80 upward resultant-speed
limits. Limits apply once at player impact, not continuously. Downward speed is not
clamped; the upward impulse still changes existing descent by the configured amount.
The existing legacy 7/4 NPC impulse remains unchanged to preserve queue recovery.
Cross-plot customer eligibility, queue/order preservation, and Jacked Noob behavior
are unchanged; the NPC suites cover their existing valid targets.

## Hit and recovery path

CombatService retains all server-issued Tool, overlap-window, team/session, forward,
line-of-sight, alive, immunity, and target checks. The swing consumes its token before
dispatch, so multiple parts or later samples cannot apply another impulse.

After stun and ingredient drops, combat snapshots the root's ownership mode/owner
and borrows server ownership before RagdollService requests Physics. On the next
Heartbeat it checks the same character/root/stun token, living membership, active
ragdoll, deadline, and anchoring before applying one centered ApplyImpulse using
current AssemblyMass times the bounded velocity change. It adds no angular impulse,
continuous force, camera effect, particles, or audio. Existing hit feedback remains.

Ownership returns to the saved automatic/manual policy 0.2 seconds after impulse.
Death, character reset/removal, failed ragdoll activation, failed impulse, and stun
recovery also release it. Release is idempotent, does not mutate a fresh character,
and preserves a later explicit owner handoff. A departed prior owner falls back to
automatic ownership. Destroyed/removed roots and assemblies that cannot accept an
ownership change are skipped. If initial acquisition is unavailable/fails, physical
launch is skipped while ordinary damage, drop, stun, and recovery still run.

The implementation follows Roblox's [network ownership API](https://create.roblox.com/docs/physics/network-ownership)
and [BasePart impulse API](https://create.roblox.com/docs/reference/engine/classes/BasePart#ApplyImpulse).
The short ownership interval is initial tuning and still needs latency testing.

Cooldown remains 1.1 seconds; hit windows, stun lengths, and 2.5-second post-recovery
immunity remain unchanged. RagdollService's joint/collision snapshots, native R15
AJU constraints, Physics/GettingUp transitions, and UNSTUCK recovery/placement are
unchanged. CharacterPhysicsService's avatar normalization remains unchanged.

FallDamageService is unchanged: genuine falls retain jump compensation, one landing
consumption, and bounce suppression. Combat does not reset fall history or grant
fall immunity. UNSTUCK still resets old fall history only after authorized recovery
teleports. The new fall test uses the actual knockback helper for each launch target
and confirms safe modeled flat-ground arcs, recovery, and later genuine-fall damage.
Ragdoll restoration tests confirm that recovery itself does not assign launch velocity.
CLI tests cannot prove that engine joint restoration will never create contact spikes.

## Files changed in this pass

- src/shared/Constants/BatConfig.luau: player targets, ownership interval, speed bounds.
- src/server/Services/BatKnockback.luau: ownership snapshot/release and bounded mass-scaled player impulse; legacy NPC Apply API preserved.
- src/server/Services/CombatService.luau: brief ownership lifecycle around existing ragdoll/Heartbeat launch.
- tests/bat_knockback.spec.luau: exact targets, multiple masses, direction/fallback, caps, invalid assemblies, ownership policies.
- tests/fixtures/bat_combat.luau: shared existing combat setup extracted, with ownership/active-ragdoll impulse boundary.
- tests/combat_launch.spec.luau: existing launch callback/failure/NPC dispatch contracts moved out of the mixed combat suite, plus upgrade/recovery/immunity and death/reset/respawn-after-launch checks.
- tests/combat.spec.luau: consumes shared setup and checks brief ownership return and immunity without blocking the independent launch suite.
- tests/ragdoll.spec.luau: Giant-launch velocity retained through native joint/collision restoration.
- tests/fall_damage.spec.luau: modeled bat arcs/recovery and later real-fall damage.
- tests/run_state_tests.py: bat-knockback and combat-launch selectors, shared fixture.
- tests/README.md and this guide: test boundaries and Studio acceptance.

Pre-existing workspace edits were retained. No production changes were made to
RagdollService, CharacterPhysicsService, FallDamageService, UNSTUCK, or customer services.

## Validation results

Run with the installed Luau executable:

```
python tests/run_state_tests.py --luau <luau.exe> --suite bat-knockback --suite combat-launch --suite npc-combat --suite customer-bat --suite fall-damage --suite unstuck --suite unstuck-placement --suite unstuck-fallback --suite ragdoll
python tests/run_character_physics_tests.py --luau <luau.exe>
```

All nine focused suites pass independently, as do character-physics/player-only
collision checks. The separate mixed combat suite still fails at `unequipping issued
Bat restores newest-first throw even with an unissued lookalike`; the customer-queue
suite fails at `front consumes and pays once`. Both reproduce in an isolated copy
of the pre-pass workspace. Their production systems were not changed to hide failures.
Customer-bat's queue/order recovery coverage passes. The independent launch suite
executes lifecycle/failure contracts even when the mixed combat suite stops early.

StyLua checks and Rojo build pass. Roblox-aware Luau LSP full-src analysis still
reports the same 41 unique diagnostics (216 repeated reports) as the pre-pass copy,
with zero new source-matched diagnostics. These existing errors include optional
EquippedBat narrowing in CombatService, CustomerRequests DisplayText definitions,
and CustomerService/JackedNoobService diagnostics. BatKnockback and BatConfig have
no diagnostics. Full-src typecheck therefore remains failing, with no added errors.

## Live Studio acceptance (not yet run)

No new Studio instances or collision groups are required. Keep the existing R15
Avatar Joint Upgrade/native constraint setup. R6 ragdoll support is unchanged.
Use Start Server with two clients on separate plot sessions, and swap attacker/victim.
Purchase upgrades through the normal authoritative upgrade flow, rather than setting
BatLevel attributes. Reset victim health between independent hits, because Giant
still deals 50% MaxHealth damage. Do not repeatedly hit an already immune victim.

Test each level with a normal block R15, a small package, and a wide/unusually
proportioned package, with and without large accessories. Let production appearance
normalization complete first. If testing experimental scales, apply them afterward
only in the test session and record them separately from supported normalization.

| Level | Required physical comparison |
|---|---|
| 0 | No bat granted and no attack; unchanged normal movement. |
| 1 | Readable immediate shove away from attacker, small upward hop, useful separation, normal recovery after 1.5 seconds. |
| 2 | Substantial shove with some airtime, clearly stronger than Normal, recovery after 2.25 seconds. |
| 3 | Visible ragdoll launch away from attacker and clearly strongest separation/airtime, recovery after 3 seconds. |

For every package/level record observed root velocity before/after impact, actual
separation, airtime, recovery/control, and ownership in both client and server views.
Use a clear flat area first. Repeat while the victim runs toward/away from attacker,
and while jumping. Verify mass changes do not dominate upgrade strength. The velocity
caps must prevent compounded upward/horizontal acceleration without stopping a real
fast downward fall. Compare both viewing clients, including simulated network latency;
verify ownership returns shortly after launch and control remains normal afterward.

1. Hold swing input and overlap several target parts through the complete hit window.
   Confirm one damage/drop/impulse, 1.1-second attack cooldown, and no relaunch during
   stun or the 2.5-second recovery immunity. Test same session, same non-neutral team,
   ForceField, obstruction, out-of-range pose, self, and dead targets for rejection.
2. Bat cross-plot queued and served/exiting customers and supported Jacked Noob rigs.
   Confirm unchanged NPC response, queue slot/order/payout preservation, recovery to
   the target's own destination, and recovery after the attacker leaves.
3. Test flat grass, Terrain, slopes, walls, low ceilings, plot barriers, and platform
   edges. Confirm torso core collisions, noncolliding ragdoll limbs, normal restored
   collisions, and no persistent Physics/Freefall/ragdoll lock after recovery.
4. Enable existing FallDamageService diagnostics in Studio (see
   [fall diagnostics](FALL_DAMAGE_DIAGNOSTICS.md)). Compare flat-ground launches to
   actual falls off elevated platforms. Confirm one damage event per genuine landing,
   no artificial lethal peak on GettingUp, and no extra damage from ragdoll bounces.
5. After legitimate stun, induce floor entrapment and exercise both ten-stud UNSTUCK
   lift and own-plot fallback. Active stun must still forbid UNSTUCK. Confirm clearance,
   carried-instance preservation, restored controls, and reset of old teleport impact
   history while a subsequent genuine descent still receives normal fall damage.
6. Reset/die/disconnect before the launch Heartbeat, during its 0.2-second ownership
   interval, while airborne, and near recovery. Confirm no stale launch/recovery reaches
   the new character, no permanent server ownership, and normal respawn movement,
   jumping, bat access, and subsequent combat.

CLI doubles cannot simulate native articulated contacts, real airtime, latency,
ownership migration, or client replication. Studio acceptance remains required before
calling these initial targets final. In particular, observe package-dependent damping,
wall/ceiling contacts, airborne joint restoration, and the short ownership handoff.
