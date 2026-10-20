# Fall damage tracking and diagnostics

FallDamageService is server-authoritative and samples the character on Heartbeat.
The public API remains Init(dependencies), ApplyCharacter, RemovePlayer,
NotifyRecoveryTeleport, EnableDiagnostics/DisableDiagnostics, and ComputeDamage.
No client position, speed, state event, or damage claim enters the calculation.

## Two-state tracker

Each character tracks Airborne, Peak downward speed, SoftTime, LastPosition, and
LastVelocity. There is no StateChanged listener, contact capture, pending landing,
intentional-takeoff latch, or settling/rearm state.

After lifecycle and reposition checks, each Heartbeat reads downward speed and
support. Upright rigs use the existing foot probe (HipHeight plus root half-height,
and leg height for R6), then torso probes. Physics/PlatformStand rigs use the live
collidable torso probes. Torso rays account for orientation and replacement during
appearance loading. Running, Landed, RunningNoPhysics, and GettingUp are also
sampled support evidence. FloorMaterial is diagnostic metadata only. Probes retain
character exclusion, RespectCanCollide, IgnoreWater, collision groups, padding
0.3, and minimum normal Y 0.5.

- Supported and not airborne: remain idle.
- First unsupported sample: start an episode with the current downward speed.
- Airborne: retain the maximum downward speed across every sample.
- Support plus a speed drop of at least 8 from the peak: evaluate once as impact.
- Otherwise, support with downward speed at most 4 continuously for 0.1 seconds:
  evaluate once as soft. Any interruption resets that confirmation time.
- Support while still near peak speed is a graze. It never consumes the episode.

Evaluation immediately clears the episode before TakeDamage. The next support
loss starts a fresh episode, including shelf drops and small landing bounces.
There is no quiet-ground delay or immunity window. GroundConfirmSeconds replaces
the old unused SettleSeconds; SettleVerticalSpeed remains 4. A severe fall slowing
to a gentle supported touchdown meets the impact rule first; the soft rule handles
small peaks without a sufficient impact-speed drop.

Dead, anchored, Swimming, Climbing, and Seated characters void the episode without
evaluation. Physics/ragdoll is not a void condition. The existing reposition budget
is unchanged: max(previous speed, current speed) * dt + Gravity * dt^2 / 2 + 12.
Travel beyond it discards the peak. NotifyRecoveryTeleport explicitly discards it
for an authorized small reposition too; later falls receive no immunity. Character
replacement/removal cannot transfer a peak to the next life.

## Compensation and damage

At evaluation, compensation is min(MovementService.GetJumpPower(player), 85), or
zero if movement has not initialized. CompensationCap is configurable in
src/shared/Constants/FallDamage.luau; math.huge restores uncapped compensation.
Tier 0 remains at 60; tier 3 now subtracts 85 instead of 116. Flat-ground jumps
remain safe at all current tiers. Jumping from the same ledge produces at least
as much damage as walking off it under the sampled episode model.

ComputeDamage and its smooth interpolation are unchanged:

| Effective peak speed | Damage |
| --- | --- |
| 54 or less | 0 |
| 69 | 16 |
| 85 | 72 |
| 96 or more | 200 |

Effective speed is max(0, peak - compensation). ForceFields still protect
TakeDamage; a protected landing is consumed and never replayed when protection
expires. Health regeneration, movement tuning, ragdoll, and ownership are unchanged.

## Capturing a trace

In Studio Play, after character attachment, run in the Server Command Bar:

```lua
local player = game:GetService("Players"):GetPlayers()[1]
local service = require(game.ServerScriptService.Server.Services.FallDamageService)
assert(service.EnableDiagnostics(player, 30, 240), "Character has not attached")
```

DisableDiagnostics(player) stops early. Re-enable after respawn for a new capture.
Tracing is silent by default and stays server-only. FallDamageDiagnostics retains
its default 30-second/240-record bounds, capped at 60 seconds/600 records, with
both simulation time and wall time expiry. No per-sample or StateChanged output
is emitted. Enabling/removing/resetting a trace produces lifecycle records;
each completed episode produces one episode-start and one damage evaluation.

The damage record includes peak (also impactPeak for compatibility), effective,
compensation, calculated, applied, and cause=impact or cause=soft. It retains health
before/after and safe/applied/ForceField reasons. Capturing peak before TakeDamage
preserves it even when death resets the live tracker synchronously. Snapshot fields
include sampled mode/floor, velocity, airborne/softTime, health, root dimensions,
HipHeight, rig/scales, jump settings, network owner, and synchronized serverTime.

The optional [client observer](studio/TraceFallDamageClient.luau) remains a separate
Studio-only comparison tool. Its samples/state events never drive server damage.
The server cannot reconstruct a peak or landing completely absent from Heartbeat
samples; real replication and physics timing still need playtests.

## Validation

The authoritative fall-damage suite owns the unchanged curve checks and scripted
Heartbeat episodes: repeated same-ledge walk/jump comparisons at all tiers, safe
flat-ground jumps, high-speed grazes/state flicker, shelves, bounces, sustained soft
support, rig probes, ragdoll/recovery, resets, capped/uncapped compensation,
ForceFields, and diagnostic silence/budgets/expiry.

```text
python tests/run_state_tests.py --luau <luau.exe> --suite fall-damage
```

The --fall-damage-fix-contracts alias selects this same suite. Recovery and bat
integration remain in their existing unstuck and combat suites.

No Studio setup changes are required. With tracing enabled, manually verify:

- Same ledge: walk off and jump off five times each; jump damage is never lower.
- Graze ledge matching the Landed/Running flicker: one full-peak evaluation at
  the true landing.
- Roof hops and stairs: no damage or per-sample log spam.
- Shelf landing followed by an immediate drop: separate peak evaluations.
- Bat knockback off a plot roof: normal fall evaluation through Physics/recovery.
- Tier-3 capture: compensation=85, with calculation and actual health loss visible.

CLI tests use velocity/support boundary doubles, not a Roblox physics simulation.
