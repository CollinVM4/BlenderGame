# Ice Ray radial blast

The imported `IcicleGun` now fires a large radial AoE blast centered on the
player who activates it. Its mesh, texture, grip, pedestal, pass entitlement,
hotbar and purchase flow are unchanged, and its tooltip text
("winter best season") has been removed. No new purchase, weapon asset or
freeze system is required, and no movement mechanic was added. Client
presentation uses a server-output-only result remote; see
[presentation and outline validation](ICE_SHOTGUN_PRESENTATION.md). Legacy
imported scripts remain sanitized out of the runtime Tool.

## Behavior and authority

`src/shared/Constants/IceGunConfig.luau` owns these defaults:

| Setting | Default |
|---|---|
| `BlastRadius` | 22 studs, in 3D, from the server caster root to each target root |
| `FreezeSeconds` | 4 seconds total, including 0.2-second block formation |
| `CustomerRagdollSeconds` | 2.5 seconds, independent of players |
| `ShotCooldown` | 4.5 seconds per shooter |
| `DirectDamage` | 5 HP per eligible player, once per shot |
| `TeamDamage` | false |
| `ImmunitySeconds` | existing 4 seconds after actual thaw |

`IceGunProjectileService` keeps its name and public methods for existing wiring,
but no longer simulates a traveling damage projectile. Launch smoke/sound and
target impact/ice effects reuse imported assets. `ClearPlayer` preserves cooldown
when putting the Tool away; character reset/removal keeps the existing reset path.

The server verifies cached ownership and the exact issued equipped Tool, living
current character, gameplay lock, PlatformStand, request throttle and cooldown.
Aim and camera data are still sanity-checked when supplied (finite vectors,
unit camera direction, bounded camera position), but they no longer derive a
direction, an aim distance, or occlusion: the crosshair is activation intent
only. The client never specifies targets, damage, radius or status duration.
The cooldown (4.5 seconds) and crosshair logic are unchanged.

Every current player root is tested against the blast radius only, in 3D,
from the caster root. There is no cone angle, no muzzle origin, no
line-of-sight raycast and no projectile travel: a target inside the sphere is
hit in every direction, including behind the caster and behind a wall, and a
target 0.01 studs outside it is untouched. Targets are snapshotted before any
damage or freeze callback runs, the caster is explicitly excluded, and each
player is inserted into that snapshot at most once, so one activation deals
exactly 5 HP and at most one freeze per target. Existing cosmetic ice retains
`CanQuery=false`.

`CombatService` retains living plot-session, current-character and ForceField
checks, plus the explicit caster exclusion. Shared-plot and non-neutral Roblox
teammates are protected by default. Only explicit server `TeamDamage=true`
bypasses those two teammate protections for ice blasts; bat calls retain the
existing defaults. Unclaimed owners can fire but cannot damage players;
unclaimed targets remain ineligible.

NPC customers are handled only when the customer system is wired in, through
the existing bat reaction: a customer model whose root is inside the sphere
gets `CustomerService.HitCustomer` (ragdoll, then return to its queue marker),
with no change to its order, payout or queue membership. Bad
(thief/freeloader) customers stay ineligible, because that reaction path
requires a bat. NPC reactions are server-side only and are not part of the
player hit list sent to clients.

Successful damage calls the existing `FreezeStatusService.Apply` and original
`IceGunEffects.Freeze` ice block. Active freeze does not stack or extend; immunity
prevents another freeze while damage remains allowed. Lethal hits cannot freeze
the dead character.

## Independent recovery

`MovementService` already tracks freeze and bat stun separately and derives the
aggregate speed/jump/input lock. Freeze touches only its flag and ice visual. It
does not save/restore PlatformStand, AutoRotate, joints, collisions, velocity or
network ownership. `CombatService`/`RagdollService` continue owning bat recovery.

Bat recovery can restore the rig while ice still blocks controls; thaw can remove
ice while bat stun still ragdolls the player. Current movement upgrades return
after the final lock clears. Existing character tokens invalidate old callbacks.

## Focused validation

```powershell
python tests/run_state_tests.py --luau <luau.exe> --suite icegun-combat --suite ice-ray-radial --suite icegun-aim --suite freeze-status --suite freeze-bat --suite icegun-simulated-combat --suite icegun-initial-owner --suite icegun-entitlement --suite combat-launch
python tests/run_state_tests.py --luau <luau.exe> --suite icegun-input
python tests/test_icegun_assets.py
stylua --check <changed Luau files>
rojo sourcemap default.project.json --output sourcemap.json
luau-lsp analyze --platform roblox --sourcemap sourcemap.json --definitions <globalTypes.d.luau> src
rojo build default.project.json --output <temporary place.rbxlx>
```

`icegun-combat` owns radial geometry, multiplayer hits, eligibility, friendly
fire defaults/opt-in, authorization and cooldown. `ice-ray-radial` owns the
boundary (21.9/22/22.01 studs), moving targets, caster exclusion, exactly-once
per blast and NPC customer reaction. `icegun-aim` owns aim/camera intent
validation: malformed payloads are rejected, but aim, walls and muzzle pose
no longer gate a blast. `freeze-status` retains freeze/immunity/movement
lifecycle tests. `freeze-bat` runs real combat, freeze and movement with
engine doubles for both hit orders, both recovery orders, death/removal and
old callbacks against a replacement. `combat-launch` retains bat launch
contracts. Input/presentation runs separately.

Radial validation: all focused gameplay/integration suites and the separate
input suite pass; the imported-asset preservation check, StyLua and Rojo
build pass. Ice Ray/config modules pass Roblox-aware typecheck. Full-source
typecheck should be re-baselined against the pre-change count (previously
216 TypeError lines, including the existing nine optional Bat typing errors
in CombatService); unrelated production code was not changed to silence them.

## Required Studio acceptance

Use the existing mappings and sanitized assets in [ICE_GUN.md](ICE_GUN.md); no
additional setup is needed. Use existing verified entitlement or the existing
opt-in negative-UserId [Studio simulation](ICE_GUN_STUDIO_TESTING.md). Native bat
checks require the existing R15 Avatar Joint Upgrade [setup](RAGDOLL.md).

1. Start four clients: owner shooter, two enemies in separate plot sessions and
   one shared-plot teammate. Wait out ForceFields. Place enemies in every
   direction around the shooter (front, back, left, right, above, below): one
   click deals 5 HP and forms one original block on each. Test 21.9/22/22.01
   studs from the caster root in several directions, and confirm the visible
   pulse edge lines up with the hit edge at 22 studs.
2. Cover one enemy with a queryable wall while the other stays exposed. Test
   Terrain, corners, and standing with the gun against a wall. Under the new
   radius-only rule the walled target is hit; if that is not the intended
   balance, say so before release, because it is a deliberate change, not an
   accident. Repeat with moving players (walking into and out of the radius
   between clicks) and simulated latency, and confirm the caster is never hit.
3. Verify shared-plot/Roblox-team protection, Neutral behavior, ForceFields,
   dead/unassigned players, NPC customers and team changes before the next shot.
   NPC customers inside the radius should ragdoll and then return to their
   queue marker without losing their order. Leave `TeamDamage=false` for
   production; test true only in an isolated session and restore false afterward.
4. Spam and put away/re-equip during the 4.5-second cooldown: no extra damage.
   Death/reset grants the normal single hotbar Tool. Check desktop pointer,
   shift-lock, touch and gamepad aiming. Compare gun/pedestal appearance to the
   imported asset; verify the radial pulse, original launch sound and ice
   formation/shatter, and confirm the tooltip is now empty.
5. Time the 4-second player freeze and 4-second immunity after thaw. Use another shooter
   during immunity to verify damage without another block. Check upgraded
   jump/sprint, carried ingredients, airborne targets, lethal hits and health regen.
6. Test bat-first and freeze-first against Normal (1.5-second) and strongest
   (3-second) bat stuns. Verify both expiry orders: no premature controls or
   permanent PlatformStand/AutoRotate/joint/collision changes, no anchored body,
   normal getting up and ownership after both expire. Repeat airborne, by walls,
   with death/reset/disconnect during overlap, and after respawn. Check current
   upgraded speed/jump after recovery.

CLI doubles cannot establish native physics, rendered assets/audio, latency or
real Marketplace ownership. Studio acceptance remains required; no live Studio
session was run for this conversion.

## Ice Ray audio and longer freeze (2026-10-28)

Changes remain on `ice-ray-radial-blast`, unmerged. Player movement, FrozenUntil,
ice visual removal and thaw audio use the same four-second FreezeStatusService
callback. Immunity remains four seconds from actual thaw (including delayed frames).
The ice block no longer has a competing Debris deadline that could remove it before
a delayed thaw. Customer reaction uses its own 2.5-second setting. Shot cooldown,
radial radius/damage, pulse and crosshair behavior are unchanged.

The imported Handle.Launch is `11900833`, volume 1. The previous client already
configured that ID, but initialized to water and only replaced it on successful
ContentProvider preload: both pending and failed fetches could select water. The
fallback is now the imported icy IceCrack, and uses normal playback speed. Asset
permissions and the sound actually heard in Studio remain unverified; the CLI
cannot establish them. If neither imported asset is permitted, grant audio access
to the experience or replace the fallback with an owned icy clip.

| Phase | Sound asset | Base volume |
|---|---|---|
| Cast | `rbxassetid://11900833` (original Launch) | 0.30 |
| Cast fallback | `rbxassetid://32788850` (original IceCrack) | 0.30 |
| Freeze | `rbxassetid://32788850` (original IceCrack) | 0.16 |
| Thaw | `http://www.roblox.com/Asset?ID=87015121` (original freeze Shatter) | 0.12 |

All three use InverseTapered rolloff, minimum 6 / maximum 60 studs, normal pitch,
and a four-second maximum clip lifetime independent of the 0.65-second pulse.
Cast uses an Attachment on the caster root (confirmed origin if unavailable).
Freeze uses the victim torso; thaw uses their root, so both follow the character.
Per-target client impact audio (`4508963254`, imported volume 5) was removed to
avoid doubling the authoritative freeze sound. Nearby overlapping freeze/thaw
voices, across all casters, divide their base volumes by the nearby active voice
count; total unattenuated gain stays at most 0.16, or 0.12 for thaws alone.
Ended/destroyed/expired clips release the budget. This is a gain ceiling, not a
measured loudness guarantee; final listening still requires Studio.

Focused validation includes `freeze-status`, `freeze-bat`, `ice-ray-radial`,
`icegun-combat`, `ice-shotgun-results`, plus separate presentation suites
`ice-shotgun-vfx`, `ice-ray-audio` and `icegun-input`. Audio doubles verify six
simultaneous freezes/thaws share their budget and follow victim parts. They do
not measure perceived loudness, native attenuation or replication.

### Two-client Studio verification still required

No connected Studio session was available for this update. No new Studio asset
setup is required beyond the existing Rojo mappings and entitlement simulation.

1. Start Server & Clients with two enemies in separate plot sessions; wait for
   ForceFields. Run `tests/studio_ice_ray_audio.luau` in each CLIENT Command Bar
   before firing. It observes for 90 seconds and reports preload statuses plus
   actual sound ID, IsLoaded, Playing, TimePosition, volume, source and distance.
   Correlate failed Launch fetch with IceCrack fallback; inspect Output for asset
   permission errors. Successful preload alone is not proof of audible playback.
2. Fire A at B: verify controls/jump/sprint and ice remain locked through 3.99s,
   thaw together at 4s, and movement/upgrades recover. Retry at the 4.5s shot
   cooldown: damage may apply but freeze must remain immune through 8s after
   the first shot. Freeze becomes eligible four seconds after actual thaw.
   Repeat with B as caster and A as victim, then reset/death during freeze.
3. Listen on both clients at 3, 6, 22, 40, 60 and 80 studs. Cast should track
   the caster; freeze/thaw should track the victim, including movement after
   recovery. Nearby audio should be clear, freeze/thaw softer than cast, and
   audio silent beyond 60 studs. Move the camera too: native Sound listening
   uses the client's listener/camera, not a server-assumed player position.
4. To hear multi-target stacking, add more enemy clients: actual freeze targets
   must be players, not customer NPCs. Test one then several frozen players, and
   overlapping casters; compare caster and victim listening. Two clients alone
   verify positional audio and timing but cannot establish multi-victim loudness.
   Confirm customers still ragdoll for 2.5 seconds and retain their orders.

Validation result: all eight focused suites and the imported-asset preservation
check pass. Changed Luau files pass StyLua; Rojo build passes. Changed production
modules have no type errors. Full-source analysis reports the same 216 existing
TypeError diagnostics as HEAD, with zero added/removed diagnostics after path and
line normalization. Live two-client verification remains outstanding as above.
