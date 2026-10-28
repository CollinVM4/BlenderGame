# Ice Ray presentation

The radial pulse, frost, shards, sound and hit feedback are rendered locally
by `IceShotgunPresentationController`. `IceShotgunPresentationService`
broadcasts `Shared.Events.IceShotgunResult` only after an accepted server shot.
It contains the authoritative caster root, blast radius, shooter, server
timestamp and successful hits, including whether each hit actually froze. There
is no direction or angle in the payload anymore. The remote has no server
receive handler. Rejected fire requests produce no blast; accepted misses
produce a pulse with no hit marker or impact effects.

Damage, radial eligibility and server cooldown are unchanged from Pass 1,
except that eligibility is now radius-only (see
[ICE_SHOTGUN.md](ICE_SHOTGUN.md)). Original server impact cosmetics have moved
to the client result handler to avoid duplicate bursts and sound. The existing
server ice-block freeze, formation/shatter and gameplay locks remain in use.

## Visuals and budgets

A transparent bluish sphere expands outward around the caster, in the style
of an outward burst, with no movement mechanic attached. It grows to exactly
the server blast radius over 0.11 seconds and fades by 0.35 seconds, so the
visible edge is the hit edge. Frost uses brief one-shot particle emission
from the pulse center; shards use tweens with no physical simulation. All
effect geometry has collision, touch, query and shadows disabled. No client
effects participate in hit detection or alter character properties.

| Budget | Desktop | Touch |
|---|---:|---:|
| Concurrent blasts | 4 | 2 |
| View distance | 100 studs | 70 studs |
| Pulse spheres per blast | 1 | 1 |
| Center frost particles | 24 | 12 |
| Rendered impacts per shot | 4 | 2 |
| Frost particles per rendered impact | 10 | 6 |
| Shards per rendered impact | 4 | 2 |

One blast creates at most 21 native parts on desktop or 7 on touch (pulse
plus one impact part and its shards per rendered impact). Particle
lifetimes stop at 0.35 seconds; the shared cleanup removes blast models by 0.65
seconds. Nearby simultaneous shots have a fixed concurrent budget; additional
world bursts are dropped while confirmed local HUD feedback still updates. There
are no per-shard Heartbeat connections or per-shot polling loops. The client drops
stale result events older than 0.75 seconds and malformed payloads.

Confirmed shooter hits briefly show a blue marker for an actual new freeze, or
white for damage without a new freeze. Confirmed local victims get a subtle blue
flash. Feedback does not capture input, expires in 0.22 seconds, and is cleared
on character removal. No client activation predicts a hit.

`IceShotgunPresentationConfig` supplies sound hooks for original Launch
`11900833` and Shatter `4508963254`, plus original snow texture `276120078`.
Preload runs asynchronously. Until an asset successfully loads, the controller
uses builtin water-impact sound and sparkle texture fallbacks; fetch failure,
exception or slow loading cannot prevent visuals. Sound and particle settings
can be changed here without changing gameplay tuning in `IceGunConfig`.

## Central character outlines

`CharacterStatusOutlineController` owns one `CharacterStatusOutline` Highlight per
visible living player character. It uses server character attributes, rather than
the aggregate Player `Stunned` flag that also includes freeze. The priority is:

1. Active freeze: blue, based on the existing `FrozenUntil` attribute remaining
   present until authoritative thaw, including delayed server frames.
2. Active bat stun: white, from `BatStunned`.
3. Freeze recovery immunity: flashing blue until `FreezeImmuneUntil`.
4. Bat recovery immunity: flashing white until `BatImmuneUntil`.

Both immunity deadlines use `GetServerTimeNow`. Freeze publishes its actual thaw
deadline plus the existing immunity duration. Bat publishes its existing nominal
stun-plus-immunity deadline; this does not extend bat immunity when recovery is
late. Active statuses always outrank immunity; overlapping immunity uses the
fixed priority above. Flash phase follows the server clock at 0.22-second periods.

Outlines have transparent fill and occluded depth mode. Polling runs at 10 Hz for
expiry, flashing and distance culling. The budget is 20 within 100 studs, with
local player first, then nearest distance, then UserId for ties. Idle/distant
outlines are destroyed to release Roblox's Highlight budget. Existing tutorial
and stash Highlight owners are left alone. Initialization and status transitions
reuse one owned outline; death, character removal, replacement and departure
retire it and its character subscriptions. Old-character events cannot remove
the replacement's outline.

## Validation

```powershell
# Presentation tests run independently of authoritative gameplay.
python tests/run_state_tests.py --luau <luau.exe> --suite ice-shotgun-vfx --suite character-status-outlines --suite icegun-input
# Output contract plus the relevant Pass 1 gameplay/recovery contracts.
python tests/run_state_tests.py --luau <luau.exe> --suite ice-shotgun-results --suite icegun-combat --suite icegun-aim --suite freeze-status --suite freeze-bat --suite combat-launch --suite icegun-initial-owner
```

All ten focused suites pass. Presentation modules pass Roblox-aware typecheck;
full-source typecheck retains the same baseline 216 TypeError lines, with no new
diagnostics after normalizing line numbers. StyLua and Rojo build pass. CLI
doubles verify observable budgets, lifetime, priority, lifecycle and asset
fallbacks; they cannot establish rendered appearance or real device frame time.

## Studio-only acceptance

No additional Studio instances or purchases are needed: Rojo syncs the controllers
and server creates the output-only remote. Use existing entitlement and R15
ragdoll setup from [the shotgun gameplay guide](ICE_SHOTGUN.md).

1. Run four clients and compare shooter, two enemies and a teammate. Confirm one
   expanding blue blast from the actual muzzle on all nearby clients. Check
   muzzle flash, frost, shards and original sound at desktop/touch graphics
   levels. An accepted miss has no impact/marker; a rejected shot has no blast.
2. Cover one enemy with a wall. Only the exposed enemy receives confirmed impact
   feedback. Decorative cone rendering never changes who is hit. Use another
   shooter during immunity and confirm damage-only white feedback. Check real
   third-person, shift-lock and touch camera views and simulated latency.
3. Observe freeze-first and bat-first overlap with short/long bat stuns. Verify
   blue freeze overrides white stun, then remaining active status overrides
   flashing immunity. Simultaneous immunity chooses blue until freeze immunity
   expires, then white if bat immunity remains. Check one combat Highlight in
   Explorer, transparent fill, wall occlusion and no leftovers after expiry.
4. Die/reset/disconnect during each status and immunity phase. Respawn and quickly
   apply a new status: no old outline or HUD flash survives, and old callbacks
   do not remove the replacement outline. Repeat joins while other players are
   already frozen/stunned, and camera movement across the culling distance.
5. Use the Device Emulator and a physical low-end mobile device. Stress nearby
   simultaneous shots and crowd outlines; use MicroProfiler/Stats to inspect
   frame time, translucent overdraw, particles and instance recovery after bursts.
   Confirm the touch budgets above and no continuous particle emitters, lights,
   physics debris or growing memory after repeated combat.
6. Test unavailable imported audio/texture IDs in an isolated session, then
   restore the configuration. Verify immediate builtin fallbacks, no blocked
   visuals and no duplicated original server launch/impact audio.

No live Studio or physical-device rendering/performance session was run.
