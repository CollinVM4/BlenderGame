# Isolated standard R15 ragdoll

This is an unverified physical prototype with structural tests. Bat integration is
explicitly deferred until normal -> loose ragdoll on floor -> normal succeeds in
Studio. No balance, scatter, hit sampling, cooldown, immunity, VFX or animation
changes are part of this pass.

## Server Command Bar

Sync with Rojo, STOP the old play session, then start a fresh two-client R15 Play
session. Wait for the server initialized message. Run in the SERVER Command Bar;
replace Player1 with the exact player name. Restarting removes the old client's
cached StunController locks and the old server's prepared BatReaction rig.

ON:

```lua
local p = game:GetService("Players"):WaitForChild("Player1")
assert(p.Character, "Spawn the player first")
assert(game:GetService("ServerStorage"):WaitForChild("StudioServiceCalls"):Invoke("RagdollService", "SetRagdolled", p.Character, true), "R15 preparation or activation failed; inspect Output")
```

OFF:

```lua
local p = game:GetService("Players"):WaitForChild("Player1")
assert(p.Character, "Spawn the player first")
assert(game:GetService("ServerStorage"):WaitForChild("StudioServiceCalls"):Invoke("RagdollService", "SetRagdolled", p.Character, false))
```

This uses the existing StudioServices BindableFunction bridge. It only exists in
Studio and validates server Play mode on each invocation. There is no new remote,
client debug hook or production player-name toggle. Direct module access also works
in server runtime with the project's dot-call convention:

```lua
local ragdoll = require(game.ServerScriptService.Server.Services.RagdollService)
ragdoll.PrepareCharacter(character) -- boolean; incomplete or non-R15 rigs fail
ragdoll.SetRagdolled(character, true) -- boolean; prepares if needed
ragdoll.SetRagdolled(character, false) -- safe even before preparation
ragdoll.IsRagdolled(character) -- boolean
ragdoll.CleanupCharacter(character) -- restore, disconnect, destroy prepared objects
```

## Physical ownership and lifecycle

RagdollService owns only server character physics. It does not require Combat,
Movement, Inventory or client modules. Initialization prepares after the existing
CharacterPhysicsService finishes its one-time avatar normalization, so sockets
are not built against body parts about to be replaced. An optional onReady callback
is the only change to that normalization service. No arbitrary avatar mutation
watcher or R6 support is included.

The service validates all 14 standard Motor6Ds and their Part0/Part1 body names:
Neck, Waist, LeftShoulder, RightShoulder, LeftElbow, RightElbow, LeftWrist,
RightWrist, LeftHip, RightHip, LeftKnee, RightKnee, LeftAnkle, RightAnkle.
The enabled motor connecting HumanoidRootPart to LowerTorso stays enabled.
Tool grips and accessory joints are untouched. A missing joint rejects preparation
before allocating a partial rig, with a Studio warning.

Preparation creates identifiable Ragdoll_* attachments and disabled ball sockets
using C0/C1 (never the animation Transform). Sockets have simple swing limits:
45 degrees at the neck, 90 elsewhere. Prepared NoCollisionConstraints prevent body
self-collision while allowing floor contact. Repeated PrepareCharacter calls reuse
the setup. Preparation never changes the motors' current Enabled values.

ON snapshots original values, sets RequiresNeck=false, AutoRotate=false,
PlatformStand=true, enables sockets and disables the 14 motors. The body parts
become collidable and non-massless; the root stays noncollidable. Server network
ownership permits a server Physics state request. There are no impulses, forced
poses, anchored parts, recurring velocity writes, PlayerModule calls or state
permission changes. In particular, GettingUp and Jumping are never disabled.
Server ownership for server ChangeState follows the
[Roblox Humanoid API](https://create.roblox.com/docs/reference/engine/classes/Humanoid).

OFF disables sockets and self-collision exclusions, restores motor Enabled flags,
body collision/mass settings, RequiresNeck, AutoRotate and PlatformStand. For a
living character that was not already PlatformStanding, it requests GettingUp
while the server still owns physics, then restores automatic/manual network
ownership. It does not depend on any client callback. Death, destruction, removal
from Workspace, CharacterRemoving and leaving clean up the prepared rig. New lives
have separate state. Same-state ON/OFF calls are harmless and preserve snapshots.

## Diagnostics

Studio prints compact [Ragdoll] records at preparation, before/after ON/OFF, and
one 0.25-second observation after each changed state. The observation only reads;
it never restores motors or expires ragdoll. It is invalidated by another toggle
or cleanup. Records show actual disabled-motor/enabled-socket counts,
PlatformStand and Humanoid state.

Expected ON: motorsOff=14/14, socketsOn=14/14, PlatformStand=true.
Expected OFF: motorsOff=0/14, socketsOn=0/14, PlatformStand=false for a normal rig.
If immediate counts are correct but the later counts differ, another system may
be modifying the rig. If counts remain correct but the body is rigid, inspect
extra physical connections and the reported Humanoid state in Studio. Logs are
disabled in production; there is no permanent monitoring loop.

## Preserved gameplay and removed layers

BatReaction is deleted, including dynamic preparation watchers, impulse logic,
reaction cleanup and state-disabling code. All CombatService references to it are
removed. StunController is deleted entirely: no global action sink, PlayerModule
disable/enable, per-render movement zeroing/Physics forcing, or client state masks
remain. Its bootstrap call is removed. Dead BatConfig.Reaction values are removed.

CombatService still owns the stun deadline/token and post-stun immunity;
MovementService still owns authoritative Stunned and CanPerformGameplayAction.
Pickup, throw, stash, blender, dispense and customer gates are preserved. Existing
sprint and carry local request checks and Bat swing/animation behavior are kept.
Bat temporarily has no physical collapse. Manually ragdolling a character does not
set Stunned or block inventory/gameplay actions; test it independently of Bat.

## Files changed in this pass

- Added src/server/Services/RagdollService.luau.
- Removed src/server/Services/BatReaction.luau and src/client/Controllers/StunController.luau.
- Updated CombatService, CharacterPhysicsService, server and client bootstrap, BatConfig.
- Added tests/ragdoll.spec.luau; replaced fixtures/bat_physics.luau with fixtures/ragdoll_physics.luau.
- Updated tests/combat.spec.luau and tests/run_state_tests.py; removed bat_reaction.spec.luau and stun_controller.spec.luau.
- Updated tests/README.md and docs/BAT_PVP.md; added this document.

## Automated verification

Passing: ragdoll (46 contract assertions), combat (92), sprint (34), carry-input
(11), bat-controller (50), and five Python runner tests. The ragdoll fixture includes
all 14 joints and the preserved root, repeated ON/OFF and same-state calls,
cleanup snapshots, death/removal/destruction, fresh-life state and malformed/R6
rejection. These tests do not simulate physical collapse, floor contact or get-up.

Changed-module Roblox-aware typecheck, StyLua, Rojo build and git diff whitespace
checks passed. CharacterPhysicsService retains its existing deprecated
LoadCharacterAppearance warning.

The standalone legacy character-physics runner fails in its fixture with nil
CFrame before exercising the service. The identical failure reproduces using the
pre-change CharacterPhysicsService in an isolated temporary copy. Full-src analysis
retains the existing CustomerRequests missing-DisplayText errors. Neither unrelated
issue was repaired as part of this task.

## Required Studio acceptance (not yet performed)

Start standing still: ON must release visible limbs and let gravity collapse and
settle the body. OFF must return animation control, get up and restore movement.
Repeat ON/OFF three or more times and verify no duplicate constraints, detached
limbs, disabled motors, persistent PlatformStand or worsening behavior.

Repeat for Player1 and Player2 while walking, jumping, falling, against a wall and
on a slope. Test death and Reset Character while ragdolled, then verify the new
life is clean. Capture before/after/settled logs if rigidity or failed recovery
persists. Do not reconnect CombatService until these manual checks pass.
