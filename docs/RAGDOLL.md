# Native Avatar Joint Upgrade ragdoll

## Confirmed runtime and scope

The user's Studio inspection found an R15 player with 15 AnimationConstraints,
14 BallSocketConstraints, 19 NoCollisionConstraints, and zero Motor6Ds. Root is an
AnimationConstraint without a matching BallSocket. Waist is an AnimationConstraint
with a WaistBallSocket. Some shoulder sockets use nested JointRotation attachments.
The inspection supplied in this pass did not include the AvatarJointUpgrade setting
value; the service uses the generated character rather than changing that setting.

RagdollService now exclusively supports this native AJU representation. The legacy
Motor6D preparation and custom skeleton construction have been removed. The user
verified isolated ON/OFF in Studio and authorized Bat integration. CombatService now
owns hit sequencing, stun duration and knockback; this service remains physics-only.
See [BAT_PVP.md](BAT_PVP.md) for the integration flow and tuning.

## Behavior

PrepareCharacter validates a living R15 Humanoid, the kinematic Root connection,
and the 14 named body AnimationConstraints. It checks the built-in named sockets
are enabled with attachments in the character. It does not require socket attachments
to match animation attachments, so nested shoulder JointRotation attachments work.
Preparation saves joint and Humanoid settings and creates no Instances.

ON snapshots the current settings at each inactive-to-active transition and changes:

- The 14 body AnimationConstraints: IsKinematic=false, MaxForce=0, MaxTorque=0.
- UpperTorso and LowerTorso: CanCollide=true, saving their current values first.
- Humanoid: AutoRotate=false, PlatformStand=true; requests Physics state.

Root remains untouched and kinematic. Body strength/damping properties are not
changed on ON. Native BallSockets, NoCollisionConstraints and all attachments are
left intact and unmodified. Other body collision settings remain unchanged, including
root, head and limbs. The service does not change RequiresNeck,
mass, network ownership, state permissions, movement, input or gameplay restrictions.

OFF restores each body's exact saved IsKinematic, MaxForce, MaxTorque,
LinearStrength, LinearDamping, AngularStrength and AngularDamping values. It restores
both saved torso CanCollide values, PlatformStand and AutoRotate, then requests GettingUp when alive and the original
PlatformStand was false. No default torque is assumed. Repeated same-state calls
are no-ops and cannot overwrite the snapshots.

Cleanup restores active settings, removes prepared state and disconnects listeners.
Death, destruction and removal from Workspace trigger cleanup. Existing bootstrap
CharacterRemoving and PlayerRemoving hooks also call CleanupCharacter. A new
character prepares independently. No native instances are destroyed by cleanup.

## API and Server Command Bar

The existing PrepareCharacter, SetRagdolled, IsRagdolled and CleanupCharacter APIs
and StudioServiceCalls bridge are unchanged. The earlier optional InspectCharacter
method remains available for read-only troubleshooting; it no longer runs on every
preparation. No additional diagnostics framework or client code was added.

Sync Rojo, stop the old Play session and start a fresh session. Wait for the server
initialized message, then use the **Server Command Bar**. These commands select
Eatandpoop or Player1 explicitly.

ON:

```lua
local players = game:GetService("Players")
local p = players:FindFirstChild("Eatandpoop") or players:FindFirstChild("Player1")
assert(p and p.Character, "Spawn first")
assert(game.ServerStorage.StudioServiceCalls:Invoke(
    "RagdollService", "SetRagdolled", p.Character, true
))
```

OFF:

```lua
local players = game:GetService("Players")
local p = players:FindFirstChild("Eatandpoop") or players:FindFirstChild("Player1")
assert(p and p.Character, "Spawn first")
assert(game.ServerStorage.StudioServiceCalls:Invoke(
    "RagdollService", "SetRagdolled", p.Character, false
))
```

Expected Studio messages (preparation may happen at spawn):

```text
[Ragdoll] prepared rig=R15 jointSystem=AnimationConstraint bodyJoints=14 root=Root
[Ragdoll] ON changed=14 RootKinematic=true
[Ragdoll] OFF restored=14
```

## Validation and remaining milestone

The focused AJU fixture has the confirmed 15/14/19 constraint layout, no Motor6Ds,
and nested shoulder socket attachments. Contracts cover idempotent preparation,
three ON/OFF cycles, non-default snapshots, exact restoration, unchanged native
structure/root/body properties, cleanup, death/removal/destruction, fresh characters,
and rejection without partial mutations when required joints or sockets are absent.
Legacy-only rigs are explicitly unsupported, with no fallback construction.

The focused ragdoll contracts pass (45 behavioral assertions), along with the updated
Combat integration contracts, Roblox-aware typecheck, StyLua, Rojo build and diff
whitespace validation. Automated tests do not simulate physics.

The user confirmed isolated standing -> ON -> loose collapse -> OFF -> normal
movement. The floor-collision follow-up now supplies torso world collision during ragdoll;
Studio must verify whether this resolves sinking and occasional stuck recovery.
The next Studio check is Bat hit -> stun/drop -> ragdoll/knockback -> recovery,
including repeated hits after immunity and reset during an active stun. The isolated
ON/OFF commands above remain supported.
