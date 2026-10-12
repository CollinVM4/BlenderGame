# LockBase

Security is manual only. Claiming a plot leaves walls inactive, lasers hidden and
retracted, and the Fredoka world display showing **LOCK BASE**. There is no READY
subtitle or automatic claim protection. An unclaimed plot has no visible display.

The current owner or teammate activates security by stepping onto the existing
LockButton.Button. Each accepted activation locks for exactly 60 seconds. The
countdown shows LOCKED and m:ss. Active locks cannot be extended. Expiration disables
walls immediately and allows another activation without cooldown, after stepping
off and back on. InitialClaimLock has been removed from configuration.

## Activation and claim placement

LockBase continues using RejectFloorButton's unchanged server standing check: a
living, nonascending character must have verified short downward button support.
The LockBase-only fallback handles overlapping LockButton/BlackBase support only
when a second downward ray also hits Button itself. Touch events only diagnose;
they never authorize activation. Current TycoonService membership remains the
permission authority, and no client activation remote is added.

StartSession retains its existing bootstrap API but only binds/refreshes the
unlocked state. On claim or ownership handoff, members start latched until the
server observes them off the plate. New character placement also starts latched.
This prevents claim/spawn overlap or an old standing contact from automatically
locking a base. An ordinary fresh entry after stepping off activates immediately.

## Visuals, timer and gameplay

The authored `LockBase.LockButton.Visual` placement is the exact fully raised pivot.
Binding captures it and every original part transparency before applying inactive
changes. The entire model retracts vertically by its world-space height plus one
stud. Its existing Laser/LaserBase geometry, relative transforms, colors, materials
and authored active transparencies remain intact; laser parts are physically inert.

On actual manual activation, original transparencies are restored at the current
retracted position and a NumberValue tween drives Model:PivotTo upward for **0.35
seconds**, using Quart/Out for a smooth finish. Activation does not snap to the raised
pivot first. Walls activate immediately. Expiration disables walls immediately and
tweens the model downward over **0.25 seconds**, hiding parts at completion. Previous
tweens are canceled and stale completions cannot hide a new lock. Absolute authored
metadata prevents accumulated offsets, including after asset rebinding.

Private lock state is keyed by plot and records owner, session ID and server-time
deadline. `LockBaseSessionId`, `LockBaseLockedUntil` and `LockBaseLocked` are replicated
projections. Gameplay permissions read server state, not those attributes. Deadlines
are checked directly for stash protection and on Heartbeat for expiration. Cleanup
matches session IDs, so stale cleanup cannot unlock a reused plot. Owner handoff or
release resets security; teammates joining/removing do not extend the timer.

The server-owned world GUI and model movement replicate to every player, including
late joiners. Text is written only when the displayed second or state changes. The
single-line idle text is centered horizontally and vertically; Fredoka, outline,
color and 65-stud camera culling are retained. The UI uses the exact authored
attachment with zero offsets and independent 6/7-stud character proximity.

Collision and theft behavior are unchanged: existing PlayerOnlyCollision walls
block outsiders while locked, server-created NoCollisionConstraints exempt owner/
teammate character parts, and members still collide with other plots' locked walls.
NPCs and loose items retain nonplayer collision behavior. Locked-base outsider TAKE
is denied and checked again before slot reservation; permanent stash protection
remains independent. Reject, plot ownership and team systems are unchanged.

## Studio setup and inspection

Keep the authored hierarchy:

```text
LockBase
  LockButton (BasePart or container)
    BlackBase
    Button (BasePart)
      LockAttachment (Attachment)
    Visual (Model)
      LaserBase (multiple)
      Laser (multiple)
```

The exact UI anchor is `LockBase.LockButton.Button.LockAttachment`. Runtime leaves
its authored Position/CFrame and parent untouched. Move this attachment in Studio
to place the text; both BillboardGui offsets are zero. No floating anchor is made.
Attachments elsewhere are not repaired or used as fallback anchors. Runtime
anchors/enables collision/query/touch on Button as before.

The server publishes occupancy and continues updating Fredoka countdown text.
Each client checks HumanoidRootPart distance to the attachment's WorldPosition
every 0.2 seconds: show within 6 studs, retain visibility through 7 studs, hide
beyond 7. Missing/removed characters and unclaimed plots hide the UI. Camera
culling remains at 65 studs to accommodate normal third-person camera offsets.
`Enabled` is locally controlled, so its server value stays false even when a
nearby player sees the text. The existing color/outline are retained at size 24.

Retain PlayerOnlyCollision on the authored security walls. Discovery accepts tagged
parts beneath LockBase, in any Wall/Walls hierarchy within the plot, or explicitly
marked `LockBaseWall=true`. Only unnamed sibling walls outside those hierarchies
need that boolean attribute. Button, LockButton, BlackBase and Visual descendants
are excluded; unrelated helpers keep their existing behavior. Runtime makes the
security walls invisible/anchored and controls CanCollide.

Run [InspectLockBase](studio/InspectLockBase.luau) in the Server Command Bar during
Play. It reports actual paths/classes, Button properties, attachment host, visual
pivot, Laser/LaserBase counts, wall count, owner, deadline, and GUI presence/enabled
state. It also runs without the published service bridge and reports orphan
LockBase models outside known plots. Workspace.LockBaseInitialized and each plot's
LockBaseAssetsReady help distinguish startup and authored-instance problems.

Scoped event diagnostics are opt-in:

```lua
workspace:SetAttribute("LockBaseDiagnostics", true)
```

Set this in Edit mode before Play or in the Server Command Bar. Set false to stop.
Binding, contact entry, changed nearby support, lock/unlock and activation results
include plot/player identity, membership, remaining time and rejection reason.
Steady Heartbeat results and duplicate limb touches do not print every frame.
Missing required assets always warn.

## Studio acceptance

1. Press Play with no claim: lasers hidden/retracted, walls inactive, no UI.
2. Claim, including while overlapping Button: remain unlocked and show only LOCK BASE.
   Step off before activating; confirm no automatic 30-second lock occurs.
3. Step onto Button as owner: quick button press, visible 0.35-second upward movement,
   immediate security walls, exact authored final position, LOCKED / 1:00 countdown.
4. Stay on Button through expiration: walls deactivate, lasers lower in 0.25 seconds,
   display returns to LOCK BASE, and standing still does not relock.
5. Step off and back on: another full 60-second lock starts immediately. Repeat and
   check no accumulated visual offsets or altered authored appearance.
6. Check outsider activation/theft denial and wall blocking; owner/teammate can cross
   and access their stash. Teammate can activate; removal revokes wall exemptions.
7. Repeat across multiple plots and respawns. Join a client midway through a lock and
   verify its geometry/countdown. Release/reclaim and verify the inactive reset.

The actual authored model is not in repository exports. No live Studio validation
was performed; geometry/contact physics/rendering/replication need these checks.

## Files changed in the manual-only polish pass

- `src/shared/Constants/LockBaseConfig.luau`: remove InitialClaimLock; rise duration 0.35.
- `src/server/Services/LockBaseService.luau`: manual-only claim lifecycle and placement latch.
- `src/server/Services/LockBasePresentation.luau`: centered single-line idle lettering.
- `tests/lock_base.spec.luau`: manual-only state, independent plots, teammate activation and stale-session contracts.
- `tests/lock_base_runtime.spec.luau`: real lifecycle/presentation, claim overlap, rise movement/endpoints and repeated entry.
- `tests/lock_base_presentation.spec.luau`: centered idle text and revised rise duration.
- `docs/LOCK_BASE.md`: current behavior, setup and acceptance.

## Validation

```text
python tests/run_lock_base_tests.py --luau <luau.exe>
```

The runner isolates gameplay/integration, real service/presentation integration and
presentation in separate processes. `--group integration` runs the two integration
suites; `--group presentation` runs presentation alone. Focused results: 58 gameplay
checks, 30 runtime-integration checks and 16 presentation checks passed. Changed
production modules pass Roblox-aware Luau LSP analysis with a fresh Rojo sourcemap.
StyLua formatting checks and the Rojo 7.7 build also pass. These CLI tests
prove authority, exception relationships and model tween transitions against engine
doubles; they do not substitute for the Studio acceptance above.

### Billboard proximity smoke checks

In Studio Start Server with two players, check the UI is centered exactly on the
authored Button.LockAttachment, with no 3-stud offset or duplicate display. Move
the attachment in Studio and verify the origin follows it. Independently move
each character within 6 studs and beyond 7; one player's visibility must not
affect the other. Zoom the normal third-person camera out while remaining near.
Leave range during a lock, wait, then return and verify the current timer. Release
and reclaim the plot, respawn nearby and far away, and remove/restore the plot to
check hidden/removed displays and late replication. Confirm two-line LOCKED/time
and plain LOCK BASE render without clipping. CLI boundary tests do not prove
Roblox rendering, physical attachment transforms, or live network timing.
