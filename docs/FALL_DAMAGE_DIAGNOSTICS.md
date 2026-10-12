# Fall damage diagnostic investigation

## Pass 8: reliability fixes implemented

The three confirmed diagnostic defects are now fixed in FallDamageService.
The investigation below is retained as the **pre-fix record**; its descriptions
of known failures and the proposed patch refer to the diagnostic pass.

Exact changes in this follow-up:

- **Upright contact:** root-to-foot ray length uses current root height and
  HipHeight, with existing padding, character exclusion, collision group,
  collidable filtering, water exclusion, and minimum normal-Y requirements.
  R6 includes its current left-leg height to retain existing rig compatibility,
  following the [Humanoid HipHeight formulas](https://create.roblox.com/docs/reference/engine/classes/Humanoid#HipHeight).
  Physics/PlatformStand keeps torso-based support. FloorMaterial is retained for
  quiet standing detection and diagnostics but cannot alone confirm an impact.
  The standing shortcut no longer ignores large downward velocity when a
  locomotion state or FloorMaterial is stale.
- **Brief touchdown:** StateChanged observes valid world contact and captures
  the previous episode's peak, including downward velocity observed at that
  contact. It never applies damage from the event callback. Heartbeat runs the
  existing reset/reposition checks before evaluating the captured contact. A
  captured intermediate position must also fit that unchanged travel budget.
  Contact evidence expires within the existing 0.25-second settling interval,
  using both wall time and simulation age. A fresh event at the end of a long
  Heartbeat is not aged by the entire preceding frame.
- **Distinct jumps:** recent validated contact plus server-observed Jumping and
  upward motion rearms a distinct episode immediately. Upward evidence may be
  observed in the event or subsequent Heartbeat. Jumping without contact never
  confirms a landing; expired contact never corroborates a takeoff. The old
  impact is consumed before rearming and tracking a later fall. Ragdoll entry
  invalidates saved jump signals, preserving quiet-support rearm and suppression
  of repeated ragdoll contacts/recovery bounces.
- **Appearance replacements:** torso probes resolve the three current named
  parts at query time. Refreshing references preserves the active peak. Reset,
  removal, respawn, and death clear pending contact and takeoff evidence.
- **Regression selection:** the three previously failing contracts are ordinary
  assertions in `--suite fall-damage`. `--fall-damage-fix-contracts` remains a
  compatibility selector for the same now-passing suite. No assertions retain
  the three defects as correct behavior. The discontinuous-position test now
  describes the intentional, unchanged reposition guard.

Changed files in Pass 8: `src/server/Services/FallDamageService.luau`,
`tests/fall_damage.spec.luau`, `tests/run_state_tests.py`, `tests/README.md`, and
this report. The diagnostics helper and client observer are unchanged.

Damage curve, thresholds, JumpPower compensation, jump upgrades, regeneration,
ForceField behavior, character normalization, ragdoll physics, and network
ownership are unchanged. Source comparison also verifies the existing damage
calculation/application and reposition/reset guard blocks are unchanged.

Validation: both focused selectors pass.
Changed-module Roblox-aware Luau LSP typecheck, StyLua, and Rojo build pass.
Coverage includes all twelve requested cases plus brief between-Heartbeat
touchdown, stale jump velocity, expired support, fresh event contact after a
long frame, latched-contact reset/death/respawn, R6 clearance, player-only
collision groups, and recovery-bounce suppression. Unrelated gameplay and
presentation suites were not run. The full-project type errors documented in
the original investigation were not re-audited in this focused pass.

**Remaining timing hypotheses:** a client-owned character's pre-impact downward
peak or brief contact/state/upward impulse may never reach the server observer.
Position replication bursts may still trip the unchanged reposition guard.
Neither hypothesis has been established by a multiplayer engine capture; no
ownership, guard-tolerance, or client-reported-damage workaround is added.

### Studio multiplayer validation checklist

No new place assets or settings are required. Studio engine/multiplayer checks
have not been executed in this pass. Use the existing opt-in server/client
observers described below in a two-client session, including latency simulation:

1. At every jump tier, repeat released and held normal jumps at equal elevation;
   verify zero unintended damage and no standing pause between jumps.
2. Step/jump from high platforms, hold Jump through touchdown, and repeat
   immediate bunny hops over a ledge. Verify one damage attempt per distinct
   fall using the unchanged `ComputeDamage(max(0, peak - compensation))` curve.
3. Try standard, short, wide, and unusual R15 body packages after appearance
   loading. Compare actual HipHeight/root dimensions and refreshed torso
   references. Include R6 if supported by the place.
4. Land centrally and near edges on flat, thin, moving, and player-only
   platforms, ramps, and terrain. Verify valid support normals are accepted,
   walls/unsupported surfaces are rejected, and collision groups agree.
5. Ragdoll in midair, land in multiple orientations, bounce, and recover. Verify
   one damage attempt for the original impact and no recovery-contact replay.
6. Compare protected spawn falls with unprotected falls. Verify positive
   calculated damage can have zero applied health loss under a ForceField,
   with no replay when protection expires.
7. Teleport, anchor, swim/climb/sit, die, and respawn around a pending landing.
   Verify reset rules prevent inherited or deferred old-life damage.
8. Compare synchronized server/client traces: `state-contact:foot-ray`/
   `state-contact:torso-ray:*`, `supported-jump-takeoff`, damage peak/application,
   contact age, position displacement, and `reposition-budget` resets. Record
   any server-missing peak/contact/jump impulse for a separate timing follow-up.

## Original diagnostic investigation (before Pass 8)

Investigated 2026-10-11. This pass adds observation and tests only. The damage
curve, detection thresholds, jump tiers, regeneration, network ownership, and
ragdoll mechanics are unchanged. Corrective gameplay changes below are proposed
for a separate implementation pass.

## Findings and confidence

Three defects reproduce against both the original FallDamageService and the
instrumented service using controlled engine signals. These are code-level
reproductions, not a claim that an engine playtest has been performed.

| Finding | Mechanism and consequence | Confidence |
|---|---|---|
| Safe landings suppress later real falls | Every confirmed landing enters `Settling`, even when computed damage is zero. The settling branch ignores all downward speed until 0.25 seconds of continuous support with vertical speed at most 4. Immediate jumping resets `SupportedFor`; repeated bunny hops can suppress distinct high falls indefinitely. | Reproduced with a safe jump followed by four damaging falls. |
| Jumping touchdown can miss confirmation | `Jumping` is absent from `GROUNDED_STATES`. Non-Air FloorMaterial cannot confirm that state; only collidable torso rays can. An upright character's feet can contact a floor while torso-center rays ending just 0.3 studs below each torso do not reach it. Holding Jump can return the humanoid to Jumping before a server Heartbeat samples Running/Landed. | Missed support and retained peak reproduced; the real engine timing of held input remains a Studio check. |
| Appearance replacement leaves stale support parts | `Supports` captures UpperTorso/LowerTorso/Torso once at attachment. Removed references are ignored and replacements are never discovered. CharacterPhysicsService asynchronously applies a description that can replace body parts after FallDamageService has attached. | Replacement failure reproduced. Frequency of description-driven replacement requires Studio observation. |
| Batched replication can resemble teleportation | The reposition guard compares position displacement with one Heartbeat's `dt`, previous/current velocity, gravity, and 12 extra studs. A 20-stud delayed position update following a tracked speed of 201 exceeds the roughly 15.4-stud frame budget and discards the peak. | Guard behavior reproduced; network replication as the cause of real failures is a hypothesis. |
| Damage may be attempted but blocked | Landing is consumed before `TakeDamage`; a ForceField can block health loss. Removing protection later does not replay the consumed landing. | Reproduced using the documented ForceField behavior in the engine double. Intended protection is preserved. |

The approximately one-second delay is **not** a timer in this service. An
unconfirmed peak has no landing timeout. A controlled test retains it for sixty
1/60-second steps and applies it when Running plus non-Air FloorMaterial finally
appears. Settling is a different path: it suppresses tracking and cannot later
apply the ignored fall's peak. Logs distinguish these two symptoms.

## Answers to the ten investigation questions

1. **Freefall directly to Jumping/Running/Landed/Physics:** there is no
   transition-driven reset and no requirement to see Freefall or Landed. Any
   downward velocity starts a fall. Tests cover all four direct transitions and
   preserve the previous peak when valid support exists. Running/Landed may use
   FloorMaterial; Jumping/Physics depend on torso rays. StateChanged is now
   observed without making it a damage trigger.
2. **Holding Jump:** the service never reads Jump to decide damage. The indirect
   failure is the Jumping support exclusion and immediate takeoff during
   settling, not an explicit immunity for held input.
3. **Premature peak reset:** ordinary state changes do not reset the peak.
   Resets occur on death, anchoring, Swimming/Climbing/Seated, excessive
   repositioning, and completed settling. A consumed landing clears the peak.
   Character replacement/removal drops its state. The reposition guard can
   therefore erase a valid peak before landing evaluation.
4. **Avatar geometry:** torso probe lengths use actual size and orientation,
   including horizontal rotation. They cover only each torso's center line, not
   its entire footprint or feet. Width alone adds no upright ray length. Small,
   wide, short, and off-center rigs can produce different contact coverage.
   CharacterPhysicsService normalizes six R15 scale values after appearance
   loading and gives the root a fixed 2x2x1 size. It retains body assets and
   collision behavior; this does not guarantee identical torso geometry. R6 has
   no R15 scale conversion. Failed/delayed normalization also needs observation.
5. **Floor/state/ray disagreement:** grounded locomotion with non-Air floor
   bypasses rays. Physics/PlatformStand deliberately ignores FloorMaterial.
   Jumping can report floor contact while the service reports no support. The
   new shadow probes report ray evidence independently even when floor wins.
6. **Physics timing:** Heartbeat reads the server's current root velocity after
   simulation. It is not necessarily the client's pre-impact velocity or
   contemporaneous with the latest replicated position/state. Neither character
   physics nor ragdoll code explicitly changes player character ownership;
   default ownership may be client-side. A peak absent from server samples
   cannot be reconstructed by this service. Server `dt`, previous velocity,
   displacement, ownership, and synchronized timestamps are logged. The client
   observer below supplies comparison evidence without feeding damage inputs.
7. **Bounce suppression:** confirmed defect. The consumed-fall latch has no
   independent deliberate-takeoff rearm path. It suppresses every later fall,
   including falls after zero-damage landings, until quiet support completes.
8. **Ragdoll/collision:** ragdoll sets Physics/PlatformStand and enables torso
   collision, retaining a kinematic Root joint and articulated body constraints.
   The fall peak survives this change. Tests cover Physics impacts, recovery,
   slope support, wall rejection, and duplicate bounce contacts. Head/limb-first
   impact may not be a torso-center-ray impact. Root and torso velocities can
   differ during articulation. Player-only helper platforms must match the torso
   collision group; queries already respect collision groups, CanCollide,
   character exclusion, and IgnoreWater. No collision/ownership fix is applied.
9. **Immediate repeated jumps:** both an unconfirmed touchdown and the settling
   latch can evade the check. The first retains a peak for later recognition;
   the second does not track subsequent downward velocity at all.
10. **Calculated but unapplied damage:** dead humanoids are skipped; ForceFields
    protect TakeDamage. Bat/freeze immunity tables are not consulted by
    FallDamageService. HealthRegenService observes health decreases and delays
    regeneration; it does not cancel damage. Compensation uses the resolved
    MovementService tier at evaluation time, even when a movement lock sets the
    humanoid's actual jump power to zero. An uninitialized movement service uses
    compensation zero. These behaviors are logged and preserved.

Roblox documentation supports the engine boundaries here:
[Humanoid FloorMaterial, StateChanged and TakeDamage](https://create.roblox.com/docs/reference/engine/classes/Humanoid),
[Humanoid state meanings](https://create.roblox.com/docs/reference/engine/enums/HumanoidStateType),
[network ownership](https://create.roblox.com/docs/scripting/security/network-ownership),
and [ForceField protection](https://create.roblox.com/docs/reference/engine/classes/ForceField).
FloorMaterial is not replicated; local and server observations should not be
assumed identical. Actual live timing is an inference to test, not a measured
root cause from this pass.

## Enabling and reading the instrumentation

In Studio Play mode, after the server initialized message and character spawn,
use the **Server Command Bar**:

```lua
local player = game:GetService("Players"):GetPlayers()[1]
local service = require(game.ServerScriptService.Server.Services.FallDamageService)
assert(service.EnableDiagnostics(player, 30, 240), "Character has not attached")
```

This existing StudioServices bridge targets the running service instance.
Call `service.DisableDiagnostics(player)` to stop early. Enable again for a new
capture or respawn. No remotes, replicated debug attributes, or automatic
all-player logging are added. Only server code can enable tracing.

Each character capture defaults to 30 seconds and 240 total records. Arguments
are capped at 60 seconds and 600 records. Periodic samples are at most 10 Hz;
state changes, resets, landing and damage records share the same total budget.
`lastRecord=true` marks budget exhaustion. Wall-clock and accumulated simulation
time both bound the session; respawn/removal/explicit disable disconnect the
observer, and Heartbeat cleans up expired sessions. Nothing logs by default.
Optional extra raycasts are observation only and never confirm gameplay damage.

Every record includes humanoid state, FloorMaterial, Jump, root velocity and
tracked peak, falling/settling flags, supported duration, health/protection,
network owner, root size, rig type, HipHeight, six live scale values, humanoid
jump settings, resolved compensation, and synchronized `serverTime`.
Samples add contact transitions, confirmation candidate source, independent ray
contact, each cached torso's size/ray length/group/velocity/hit/normal, previous
velocity, displacement and `dt`. Removed or noncollidable cached supports are
identified explicitly.

Interpret the decisive events:

- `landing-confirmed`: `source=floor-material` or `source=torso-ray:<part>`.
- `damage`: `impactPeak`, compensation, effective speed, calculated damage,
  health before/after, actual health decrease, and applied/safe/protected reason.
  `impactPeak` survives a synchronous death/reset; health loss may be smaller
  than the damage request when remaining health is low.
- `reset reason=reposition-budget`: compare travel with travelBudget before the
  discarded peak is zeroed. Other reset reasons identify deliberate exclusions.
- Samples with `reason=bounce-suppression`: later falling speeds are being
  ignored. `rearmed` records completed quiet support.
- `reason=awaiting-support`: an existing fall has not found support. Non-Air
  `floor` alongside `contact=false` and Jumping points to the support gap.

For owner/client timing, paste [TraceFallDamageClient.luau](studio/TraceFallDamageClient.luau)
into that player's **Client Command Bar** after spawning. It is a Studio-only,
read-only observer with the same 30-second/240-record bounds, state events and
10 Hz samples. Match records by synchronized `serverTime`, not by the local
elapsed counter. Its samples can also miss very short impulses; use state events
and repeated trials. Client observations are evidence only and never authoritative
damage inputs.

## Studio reproduction matrix

Use a disposable test place/session with flat anchored platforms at several
heights, a broad catch floor, a ramp, terrain, a narrow platform, and an existing
player-only helper. Test each trial after respawn or at least 0.25 seconds of
quiet confirmed support, except the deliberate bunny-hop trials. Let spawn
ForceFields expire for unprotected tests. Do not confuse visually high falls
with effective impact speed: at JumpPower 116, damage begins only above tracked
speed 170. Compare results with `ComputeDamage(max(0, peak - compensation))`.

| Case | Reproduction steps | Evidence / expected contract |
|---|---|---|
| Ordinary jumps | Jump and land at the same elevation using tiers 60, 85, 95, 116. Release Jump; then repeat held. | No damage; resolved compensation and measured peak explain safety. |
| High falls | Step from increasing platform heights without jumping. Repeat with a jump before stepping off. | Once effective speed exceeds 54, exactly one damage attempt matching the unchanged curve. |
| Held Jump | Start a high fall from a freshly rearmed state. Hold Jump before touching the broad catch floor. Compare released-input runs. | Look for Freefall -> Jumping, old peak retained, non-Air floor with no torso hit, and damage delayed until Running. |
| Bunny hopping | Perform a safe jump first, then touch down and immediately jump away over a ledge into a damaging drop. Repeat without resting. Finally release and stand still before another drop. | `settling=true`, `bounce-suppression`, no new tracked peak; final quiet-support trial damages again. |
| Small/wide avatars | Use real differing body packages and scales; inspect CharacterPhysics FINAL readback and diagnostic live scales after loading. Repeat held/released high falls. | Compare actual torso dimensions and HipHeight, not requested description alone. Look for removed supports after async appearance changes. Normalization stays enabled. |
| Slopes/terrain | Land upright and ragdolled on broad ramps and terrain on either side of the normal-Y 0.5 cutoff; also try wall contact. | Upward-facing support at/above cutoff can confirm torso rays; steeper/wall contact cannot. Floor and ray paths may differ. |
| Platforms | Try anchored, thin, edge, moving, and player-only platforms, approaching center and edge. | Log hit/group/normal and source. Center rays may miss edge contacts. Moving platform tests retain the existing absolute downward-speed model. |
| Ragdoll | In the Server Command Bar call the running RagdollService `SetRagdolled(character, true)` during a high fall, then restore false after touchdown. Try torso/head/limb-first orientations and recovery. | Peak survives Physics/GettingUp; floor alone cannot confirm PlatformStand. Torso contact should apply once; bounces should not repeat damage. Check velocities and cached collider status. |
| Network timing | Repeat held/released and ragdoll trials in a two-client Studio session with latency simulation, collecting owner-client and server output. | Determine whether pre-impact velocity or brief grounded state is absent on the server; correlate reposition resets with position bursts. Do not change ownership in the diagnostic pass. |
| Protection | Repeat high falls while a spawn ForceField is present and after it expires. | Positive calculated damage with applied zero/protected reason; no delayed replay on protection expiry. |

No place assets or Studio settings are changed by this patch. Real terrain,
contact geometry, replication, avatar-description replacement, and physical
ragdoll acceptance remain manual Studio checks; CLI doubles cannot validate them.

## Proposed minimal corrective patch (not applied)

Limit the follow-up to FallDamageService's contact and rearm state, with tests in
the existing fall-damage home. Keep ComputeDamage, all constants, MovementService,
regeneration, and ragdoll/collision ownership unchanged.

1. Resolve current named torso parts at probe time, or refresh the three cached
   entries when character children are replaced. Do not clear a valid peak just
   because a torso reference changes. A removed root/humanoid should use the
   normal character lifecycle handling, not inherit old-life damage.
2. Add an upright foot-level support probe using `HipHeight + root.Size.Y / 2`
   and the existing padding/normal/filter/group rules. Keep torso support for
   PlatformStand/Physics ragdolls. Permit Jumping touchdown to consume the old
   fall only with corroborating world contact. Do not simply trust Jump or
   accept FloorMaterial unconditionally in Physics.
3. Capture brief server-observed landing candidates at state/contact transitions
   and consume the saved peak before a confirmed new takeoff can replace it.
   If latency tests show contact already gone by the sampled Jumping frame,
   use a bounded previous/current foot contact sweep or recent validated contact
   latch; never interpret Freefall -> Jumping alone as a landing. The upright
   probe alone may not cover an entire skipped simulation interval.
4. In Settling, distinguish the consumed fall's physical bounce from a new
   server-observed Jumping takeoff corroborated by recent ground support.
   Rearm for that deliberate takeoff without requiring 0.25 seconds of rest.
   Keep the existing quiet-support rearm for ragdoll bounce suppression.

Proposed state-machine shape:

```lua
-- Conceptual follow-up only; support/takeoff helpers must verify world contact.
if state.Falling and confirmedLandingCandidate then
    local impactPeak = state.PeakDownSpeed
    consumeAndEvaluate(impactPeak) -- existing compensation and curve, once
end
if state.Settling and confirmedDistinctJumpTakeoff then
    rearmForNewAirborneEpisode() -- no damage replay and no client-supplied peak
end
-- Continue current quiet-support rearm for ordinary bounces/recovery.
```

Do not loosen the reposition tolerance yet. If paired traces confirm ordinary
replication is tripping it, propose a separate small change that uses the elapsed
observation interval for plausibility while preserving explicit teleport/reset
exclusions. Do not bypass ForceFields or snapshot/change tier compensation in
this fix. A server never observing the peak is a separate evidence problem, not
permission to accept client-reported damage.

## Automated validation

```text
python tests/run_state_tests.py --luau <luau.exe> --suite fall-damage
python tests/run_state_tests.py --luau <luau.exe> --fall-damage-fix-contracts
```

The normal suite covers original damage/jump/ragdoll/reset contracts, all four
direct state transitions, delayed confirmation, small/wide ray geometry,
terrain-normal cutoff, known defect reproductions, protected health loss, and
diagnostic enable/disable/budgets/expiry. The opt-in correction mode runs the
desired gameplay contracts and currently fails with three named defects:
distinct bunny-hop falls, held-Jump touchdown, and replaced-torso Physics
landing. It is deliberately excluded from normal/default selection until the
follow-up fixes land. Then convert the known-defect assertions to corrected
contracts in the normal suite; do not preserve failing behavior as intended.

Validation results: normal focused suite passes; all gameplay reproductions
also pass against the original service (with logging-only tests omitted).
Both production modules pass Roblox-aware Luau LSP analysis. StyLua and Rojo
build pass. Full-src typecheck remains blocked by existing errors: a stable
snapshot of the current workspace and the same snapshot with the original
FallDamageService both report the same 216 TypeErrors and no new errors from
this pass. Existing unrelated working-tree changes were preserved.
