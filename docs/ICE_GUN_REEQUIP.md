# Ice Gun hotbar re-equip fix

## Finding and status

The supplied live trace confirms the first failing stage: the client sends IceGunFire for issue 1 in Character; the server receives it but sees that exact registered issue 1 in Backpack and rejects authorization. This is an equip-state divergence, not a disconnected activation listener, lost entitlement, plot gate, or projectile failure. The underlying Roblox-native replication cause has not been established.

Pedestal EQUIP works by using server Humanoid:EquipTool on the registered instance. It establishes the server Character parent required by firing. The fix extends that server-controlled selection operation to normal hotbar intent. No Tool is recreated per equip, and Backpack Tools are still forbidden from firing.

Implementation and CLI regression checks are complete. Live hotbar acceptance remains pending: no Studio interaction was performed by this agent. Do not declare the live bug resolved until the acceptance steps below pass.

## Implementation

IceGunController retains one activation binding across Character/Backpack transfers. Equipped, Unequipped, container discovery and ancestry reconciliation send the current selection state rather than trusting a possibly delayed event's meaning. Transient nil parents do not revoke the binding; deferred cleanup reads current ownership and guards against an obsolete connection list. Identical lifecycle notifications are deduplicated. Activation reasserts current selection immediately before sending one shot, covering delayed equip notifications and selections previously rejected while stunned.

Selection and fire now use the existing reliable IceGunFire RemoteEvent and a single nonyielding handler. Selection is a tagged `Select` request containing Tool, desired equipped boolean and current Character. A shot retains the existing aim/ray arguments plus current Character. Using one stream applies selection before an immediate shot; no delay, pending-shot timer, cross-remote ordering assumption or fire-time authorization exemption is used. The intermediate separate IceGunSelection remote was removed. [Roblox remote documentation](https://create.roblox.com/docs/scripting/events/remote) describes reliable ordered RemoteEvent delivery.

IceGunService.RequestSelection validates the exact issued instance, cached server entitlement, player membership, current living Humanoid, legitimate Backpack/Character ownership and boolean intent. Equipping additionally requires the existing MovementService gameplay-action gate and no PlatformStand. Putting away moves only the issued Ice Gun, so it cannot unequip a newly selected Bat or carried Tool. The remote handler rejects a different Character (including pre-respawn messages) before any mutation. Exact registered-instance-in-Character firing checks remain intact. Pedestal RequestEquip reuses the same operation after its existing grant reconciliation.

Reticle visibility no longer authorizes firing. Gameplay/UI eligibility, cooldown, death and stun checks remain. Unequipped visual reconciliation reads current state so obsolete unequip notifications cannot hide a newly equipped reticle.

Projectile simulation, speed/range/cooldown, damage/freeze/immunity, aiming, collisions, PvP/team restrictions, monetization, simulation safeguards and pedestal assets are unchanged. The projectile module changes only its remote dispatch and diagnostic revision.

## Tests and validation

The existing icegun-initial-owner suite now exercises real controller -> remote dispatch -> ownership -> projectile modules at a fake engine boundary. A split-parent model reproduces the supplied observable failure: client Character, server Backpack, request sent, launch rejected. Its corrected-hotbar assertion fails with the three pre-fix runtime modules from commit b2f756a38319060eac5643ae07a4391df5f25ffe and passes with the fix. This approximates the logged condition; it does not reproduce native Roblox replication.

Coverage includes twenty same-instance cycles with Bat switching, twenty split-parent cycles with one client fire request and one server projectile per activation, immediate activation before equip notifications, queued equip/fire/put-away ending with empty hands, late Equipped/Unequipped notifications, recovery from a blocked selection, wrong Character requests, dead/PlatformStand/stunned gates, malformed intent, foreign/unowned/retired Tools, pedestal reuse and newly issued respawn Tools.

The entitlement suite additionally covers twenty simulated-owner selection cycles and rejection of an unowned simulated player. The separate input suite covers twenty reticle/firing cycles with transient nil parents, delayed removal/unequip signals and deferred cleanup; it also verifies a disabled visual reticle cannot block otherwise eligible firing. Late authorization, desktop/touch/gamepad aiming, cursor restoration, destruction and death coverage remains.

Focused suites: icegun-initial-owner, icegun-input, icegun-entitlement, icegun-combat, icegun-simulated-combat, icegun-aim, freeze-status and carry-input. All eight suites pass: state 2/2, integration 5/5, presentation 1/1. Changed-module Roblox-aware typechecking, StyLua and Rojo 7.7 build pass, as does git diff --check. The LSP prints only its existing CLI watch-registration warning; no changed-module type errors or unrelated focused-suite failures remain.

Counts are executed checks, not distinct behaviors: initial-owner 143 behavioral/67 setup; input 101/35; entitlement 95/25. The expected baseline run fails specifically at `hotbar intent establishes server equip before fire without pedestal`. Validation artifacts and the baseline runner are in the system temporary BlenderGame-luau-tools directory; the runner substitutes baseline source in memory without changing the working tree.

Re-run focused validation with `python tests/run_state_tests.py --luau <luau.exe> --suite icegun-initial-owner --suite icegun-input --suite icegun-entitlement --suite icegun-combat --suite icegun-simulated-combat --suite icegun-aim --suite freeze-status --suite carry-input`. Marketplace, native physics and replication remain doubles. No unrelated broad regression suites are required by this change.

## Exact Studio acceptance steps

1. Stop Play and sync the working tree with Rojo. Retain the existing prepared ServerStorage.Weapons.IcicleGun and world EquipmentSpawner. No new Studio instances, game passes or setup scripts are needed. Temporarily enable IceGunConfig.DebugLogging (the existing working-tree setting is already true), then restart Play. Expect revision `icegun-reequip-2026-10-11` in client, ownership and projectile initialization logs. Confirm exactly one ReplicatedStorage.IceGunFire; IceGunSelection should not exist in a fresh session.
2. Use an existing verified pass owner. Without visiting the pedestal, select Ice Gun in the standard hotbar and immediately fire toward clear space. Expect client selection intent, server hotbar selection equipped, fire receipt, exact equipped issue, fire eligible and projectile spawned. Run tests/studio_icegun_diagnostics.luau on Client and Server to confirm the same issue ID and Character parent; keep both Output streams.
3. Put the gun away into Backpack, then reselect the SAME hotbar Tool and immediately fire. Wait more than two seconds between successful shots. Repeat twenty times. Expect the same issue ID, one weapon, one fire request/projectile per activation and no authorization rejection. Never visit EquipmentSpawner during these twenty cycles.
4. Rapidly alternate Ice Gun -> Bat -> empty hands -> Ice Gun, including switching away immediately after a shot. Repeat with simulated network latency. Once messages settle, server and client must agree with the final hotbar selection; no gun may re-equip itself after Bat or empty hands is selected. Bat/carry hotbar controls must work normally. Repeat put-away -> wait -> select -> fire. Test selection while stunned/frozen, then the first eligible activation after recovery.
5. Verify one reticle appears only for the selected living gun, disappears on put-away/Bat/death and reappears on re-equip. Confirm cursor restoration, menus/text focus/navigation and no duplicate requests from desktop clicks, mobile Tool activation or console trigger.
6. After normal-hotbar acceptance, optionally put away and press E at EquipmentSpawner. Confirm it reuses the same issue ID and remains functional; its rotation and purchase UI must be unchanged.
7. Die/respawn. Confirm one newly issued gun, a new issue ID, and immediate first selection/fire without the pedestal. Old Tool/Character requests must not equip or fire the new weapon. Repeat with Studio-simulated ownership (server, Studio, negative UserId, explicit opt-in only) and an unowned player; nonowners must not receive/equip/fire an issued weapon.
8. Repeat steps 2-7 on desktop, mobile Device Emulator plus a physical device, and console/controller. With two clients, check existing team/PvP restrictions and unchanged 14 HP damage, 2.75s freeze and 4s immunity. Disable DebugLogging after capturing results.

## Changed files and preserved edit

- src/client/Controllers/IceGunController.luau: selection reconciliation, ordered selection/fire, visual independence and diagnostic marker.
- src/server/Services/IceGunService.luau: exact-instance selection validation and shared pedestal selection operation.
- src/server/Services/IceGunProjectileService.luau: ordered remote dispatch and stale Character rejection; no projectile balance/physics changes.
- tests/fixtures/icegun.luau: isolate CLI diagnostics from the developer's live logging flag.
- tests/icegun_initial_owner.spec.luau: split-parent, immediate/queued selection, security and lifecycle regression coverage.
- tests/icegun_entitlement.spec.luau: simulated-owner selection coverage.
- tests/icegun_input.spec.luau: selection-aware input boundary and repeated delayed-notification/reticle coverage.
- tests/studio_icegun_diagnostics.luau: current diagnostic revision marker.
- docs/ICE_GUN_REEQUIP.md: this report and live acceptance checklist.

The unrelated src/shared/Constants/IceGunConfig.luau DebugLogging=true edit was preserved, not authored or reverted by this fix. No Game Pass ID or tuning constants changed.
