# Ice Gun equip, accuracy and freeze pass

## Findings and changes

Two lifecycle/input failures are reproducible against the pre-pass code:

- Purchase completion established entitlement and granted a Backpack Tool, but never called EquipTool. Only the pedestal EQUIP path equipped it. Purchases now request one automatic equip after the server confirms ownership, subject to the existing action gate and a living, non-ragdolled Humanoid. If Backpack/Humanoid is unavailable, the existing character/Backpack grant retries preserve the purchase preference. Refreshes and respawn grants do not repeatedly take hotbar selection.
- IceGunController observed only Character children and rejected a Tool whose IceGunWeapon attribute was not visible at ChildAdded. It never retried that child, leaving no Activated listener until a subsequent equip. The controller now binds Tools in both Backpack and Character and checks the attribute when activation occurs. Transfers and late attributes no longer require another pedestal interaction. Authorization still uses the server's exact issued Tool instance.

The new first-selection and simulated-purchase regressions fail with the original runtime sources and pass with the changes. This establishes the code defects; a live multiplayer Studio trace has not been collected to distinguish which occurred in the reported session. No entitlement/security rewrite was needed.

Desktop now uses GetMouseLocation with ViewportPointToRay, avoiding the extra GUI inset introduced by ScreenPointToRay. Touch/gamepad use the viewport center. See [Roblox Camera coordinates](https://create.roblox.com/docs/reference/engine/classes/Camera). The remote keeps its aim Vector3 and adds optional camera-origin/direction intent. The server bounds finite camera data to 128 studs from the character, validates a unit ray and consistent target, and performs its own camera raycast. Legacy Vector3 calls remain bounded and supported.

Previously the trajectory was calculated from GunBarrel but spawned at root + one stud up + four studs along aim. Now both visual spawn and simulation start at the server-owned GunBarrel.WorldPosition, and direction is target minus that muzzle. The original exported projectile used its negative-Z forward axis with a look-at CFrame; that orientation is retained, including during swept travel. Artwork, smoke attachment and launch sound source remain unchanged. Live rendering still needs Studio inspection.

Root-to-muzzle occlusion, muzzle-adjacent obstruction, character-body clearance, ownership, action eligibility, plot session, cooldown and range remain server checks. Camera raycasts never apply damage. Only server swept projectile impacts can damage/freeze; a clear camera view cannot bypass a blocked muzzle or a wall along projectile travel. Speed remains 70 studs/sec, range 110, damage 14 HP and cooldown two seconds.

FreezeSeconds is 2.75, FreezeGrowthSeconds 0.20 (included in that total), and ImmunitySeconds four. Existing actual-thaw scheduling and independent Frozen/Stunned movement locks are retained, along with upgraded jumping, sprint integration, death/respawn cleanup and original freeze effects.

## Diagnostics

Set IceGunConfig.DebugLogging = true temporarily to trace grants, server/client equips, activation-listener binding, activations, fire requests, eligibility/rejection reasons and spawns. Messages are limited to once per second per player/stage; no Heartbeat logging is added. The setting is false by default.

## Validation

Eight focused suites pass: icegun-entitlement, freeze-status, icegun-combat, icegun-simulated-combat, icegun-aim, icegun-input, icegun-display and icegun-presentation. New contracts cover first selection with late attribute replication, one-time purchase equip, deferred Backpack grant, normal hotbar re-equip and respawn fire, camera offset/zoom/height convergence, malformed ray rejection, wall collision, 2.75-second total freeze and full immunity after delayed thaw.

The pre-pass entitlement suite had a stale assertion requiring the authored simulation flag to be false although the developer config explicitly enables it. Its fixture now explicitly disables simulation before testing opt-in; the developer setting and published-server restrictions are preserved. No other baseline failures occurred in the selected gameplay suites.

Roblox-aware luau-lsp analysis of the Ice Gun runtime modules, StyLua check of every changed Luau file and Rojo 7.7 build all pass. CLI engine doubles do not establish real Tool replication timing, physical attachment transforms or rendered mesh/audio behavior. No live Studio session was run.

## Changed files

Runtime: src/client/Controllers/IceGunController.luau; src/server/Services/IceGunService.luau; src/server/Services/IceGunProjectileService.luau; src/shared/Constants/IceGunConfig.luau.

Tests: tests/icegun_entitlement.spec.luau; tests/icegun_combat.spec.luau; tests/icegun_simulated_combat.spec.luau; tests/freeze_status.spec.luau; tests/icegun_presentation.spec.luau (input cases moved into their own suite); tests/icegun_input.spec.luau (new); tests/icegun_aim.spec.luau (new); tests/run_state_tests.py. Documentation: this file.

## Studio multiplayer acceptance

1. Sync the source changes with Rojo. No new model/attachment setup is required. Start Server & Clients with two synthetic players, explicitly enabling the existing StudioGamePassSimulation setting for the configured pass.
2. Claim plots on opposing teams. Purchase at the pedestal; confirm exactly one IcicleGun appears and equips, then fire without another pedestal interaction. Check a canceled purchase grants nothing.
3. Unequip and select the gun from the normal hotbar. Fire immediately. Repeat after death/respawn, then test the owned pedestal EQUIP alternative. Repeated refresh/equip must not duplicate Tools or continually override hotbar selection.
4. Click stationary targets near, medium and near the 110-stud range limit; test off-center clicks, left/right, above/below and camera zoom. Observe muzzle spawn and mesh forward alignment. Repeat with moving targets: travel remains slow/dodgeable, without tracking.
5. Aim through a wall, stand with the muzzle against a wall and use third-person camera peeking. Confirm obstruction prevents launch or stops the swept projectile before the victim. Verify smoke and launch audio remain at the gun.
6. Hit an enemy: confirm 14 HP damage, immediate movement lock, 0.20-second formation within a 2.75-second total freeze and original shattering. Re-hit during four seconds after thaw: damage applies, freeze does not. With upgraded jump/sprint, bat stun and ragdoll, verify each independent lock releases only on its own recovery. Test carrying, falling, death and respawn.
7. In Device Emulator verify touch activation/camera-center aim alongside Throw/Sprint, and gamepad activation/center aim. In a published server with the development flag still enabled, synthetic simulation must remain unavailable; real ownership must still be verified by Roblox.
8. If any first-grant shot fails, temporarily enable DebugLogging and inspect both client and server Output for the last lifecycle stage and explicit rejection reason; disable it afterward.
