# Ice Shotgun

The imported `IcicleGun` now fires an immediate server cone. Its mesh, texture,
grip, pedestal, pass entitlement, hotbar and purchase flow are unchanged. No new
purchase, weapon asset or freeze system is required. Client presentation uses a
server-output-only result remote; see [presentation and outline validation](ICE_SHOTGUN_PRESENTATION.md). Legacy imported scripts
remain sanitized out of the runtime Tool.

## Behavior and authority

`src/shared/Constants/IceGunConfig.luau` owns these defaults:

| Setting | Default |
|---|---|
| `MaximumRange` | 22 studs from server muzzle to target HumanoidRootPart |
| `ConeAngleDegrees` | 50-degree full angle (25 degrees either side), in 3D |
| `FreezeSeconds` | 2.5 seconds total, including 0.2-second block formation |
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
It validates finite aim, bounded camera position, unit camera direction and
aim/camera-ray consistency, then resolves camera occlusion and derives the cone
direction from the actual validated muzzle. Free camera aiming stays supported.
The client never specifies targets, damage, range, angle or status duration.

Every current player root is tested against range and angle. A separate server
raycast from muzzle to each root checks visibility. Queryable walls, Terrain and
intervening bodies can occlude targets; the target's own descendants count as
visible. Visibility is collected before damage/drop/effect callbacks. Cover must
have `CanQuery=true`; existing cosmetic ice retains `CanQuery=false`.

`CombatService` retains living plot-session, self, current-character and ForceField
checks. Shared-plot and non-neutral Roblox teammates are protected by default.
Only explicit server `TeamDamage=true` bypasses those two teammate protections for
ice shots; bat calls retain the existing defaults. Unclaimed owners can fire but
cannot damage players; unclaimed targets and NPC customers remain ineligible.

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
python tests/run_state_tests.py --luau <luau.exe> --suite icegun-combat --suite icegun-aim --suite freeze-status --suite freeze-bat --suite icegun-simulated-combat --suite icegun-initial-owner --suite icegun-entitlement --suite combat-launch
python tests/run_state_tests.py --luau <luau.exe> --suite icegun-input
python tests/test_icegun_assets.py
stylua --check <changed Luau files>
rojo sourcemap default.project.json --output sourcemap.json
luau-lsp analyze --platform roblox --sourcemap sourcemap.json --definitions <globalTypes.d.luau> src
rojo build default.project.json --output <temporary place.rbxlx>
```

`icegun-combat` owns cone geometry, multiplayer/wall hits, eligibility, friendly
fire defaults/opt-in, authorization and cooldown. `icegun-aim` owns aim validation
and convergence. `freeze-status` retains freeze/immunity/movement lifecycle tests.
`freeze-bat` runs real combat, freeze and movement with engine doubles for both hit
orders, both recovery orders, death/removal and old callbacks against a replacement.
`combat-launch` retains bat launch contracts. Input/presentation runs separately.

Conversion validation: all eight focused gameplay/integration suites and the
separate input suite pass; the imported-asset preservation check, StyLua and Rojo
build pass. Shotgun/config modules pass Roblox-aware typecheck. Full-source
typecheck retains exactly the baseline's 216 TypeError lines, with zero added or
removed diagnostics after normalizing line numbers, including the existing nine
optional Bat typing errors in CombatService. Unrelated production code was not
changed to silence them.

## Required Studio acceptance

Use the existing mappings and sanitized assets in [ICE_GUN.md](ICE_GUN.md); no
additional setup is needed. Use existing verified entitlement or the existing
opt-in negative-UserId [Studio simulation](ICE_GUN_STUDIO_TESTING.md). Native bat
checks require the existing R15 Avatar Joint Upgrade [setup](RAGDOLL.md).

1. Start four clients: owner shooter, two enemies in separate plot sessions and
   one shared-plot teammate. Wait out ForceFields. Place both enemies in the cone
   with clear sightlines: one click deals 5 HP and forms one original block on each.
   Test 21.9/22.1 studs from GunBarrel, 24.9/25.1 degrees left/right and above/below,
   and targets behind the shooter.
2. Cover one enemy with a queryable wall while the other stays exposed. Test
   Terrain, corners, muzzle-against/in-wall and a camera seeing around cover.
   Covered targets stay untouched. Repeat with moving players and simulated latency.
3. Verify shared-plot/Roblox-team protection, Neutral behavior, ForceFields,
   dead/unassigned players, NPC customers and team changes before the next shot.
   Leave `TeamDamage=false` for production; test true only in an isolated session
   and restore false afterward.
4. Spam and put away/re-equip during the 4.5-second cooldown: no extra damage.
   Death/reset grants the normal single hotbar Tool. Check desktop pointer,
   shift-lock, touch and gamepad aiming. Compare gun/pedestal appearance to the
   imported asset; verify original smoke, launch sound and ice formation/shatter.
5. Time the 2.5-second freeze and 4-second immunity after thaw. Use another shooter
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
