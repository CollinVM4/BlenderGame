# Ice Gun pre-plot diagnosis and circular cursor

## Status and confirmed findings

The desktop visibility failure is confirmed in the starting source: IceGunController.updateReticle explicitly hid its ScreenGui whenever pointerAim() was true. This pass replaces that platform-specific behavior with one 14-pixel circle and center dot on all inputs.

The remaining live pre-plot firing failure is **not yet confirmed or fixed**. No live Studio interaction tool is available in this session. Four recent installed Studio logs were inspected; none contained the needed Ice Gun activation/request/rejection trace. They do not establish the running module revision. Do not infer a registry, movement, geometry, or stale-build cause from claim/pedestal success. The first changed condition in that live reproduction remains unknown.

Repository inspection confirms:
- Rojo maps server bootstrap to ServerScriptService.Server, its Services beneath it, and client bootstrap to StarterPlayer.StarterPlayerScripts.Client (copied to Players.<player>.PlayerScripts.Client in Play).
- Server bootstrap requires the Services in that mapped tree and initializes projectile/ownership services. Character handling invokes IceGunService.ApplyCharacter before CombatService and MovementService.ApplyCharacter. InitialSpawnService schedules spawn routing independently.
- Client bootstrap starts IceGunController independently before other controller initialization can yield. It watches existing and arriving Backpack/Character Tools, including late weapon attributes.
- The exact issued reference is registered before grant; GetEquipped requires cached server entitlement and that instance in the current Character. Pedestal equip reconciles/reuses the issued reference and calls EquipTool; it supplies no extra plot-based authorization.
- Fire already has no plot/session launch gate. Its gameplay action gate tests freeze/stun; it does not require resolved movement stats or a plot. Humanoid.PlatformStand is a separate rejection. Muzzle pose/obstruction, camera-ray validation, cooldown and active-projectile limits remain gates.
- CombatService.DamagePlayer still requires eligible current sessions/teams at impact. Pre-plot launches cannot damage/freeze players. Inventory and spawn routing do not establish Ice Gun firing authorization.

No further launch-eligibility change was made without evidence. Existing automated first-owner tests pass using current client, ownership, movement, projectile and combat modules; that is not proof of actual Roblox replication/input/geometry behavior.

## Rendering and aim

The installed Roblox client CrossMouseIcon.png was visually inspected: it is a small outlined plus, not a circular cursor. This pass uses the requested local UI alternative: a small white circle, black outline and white center dot. No asset upload, model or additional controller is needed.

The existing IceGunController owns the ScreenGui. PreferredInput selects mouse versus camera-center behavior; LockCenter explicitly selects camera center even on desktop. LockCurrentPosition retains the actual pointer location. Free desktop input and circle placement share aimPoint(), which removes device-safe offsets from fullscreen GetMouseLocation coordinates. It computes the offset from the difference between GetInsetArea(DeviceSafeInsets).Min and GetInsetArea(None).Min; it does not subtract the top bar. Touch/gamepad and locked desktop use ViewportSize/2, matching the DeviceSafeInsets ScreenGui's scaled center.

The desktop UI replaces the cursor visually, using MouseIconEnabled only while the circle owns active desktop aiming. MouseIcon artwork is never changed. The previous visibility is saved/restored, including an initially hidden cursor. Menus, interactive PlayerGui button/TextBox hover, text focus, controller UI selection, window focus loss, GameplayPaused, unequip, death, character removal, destroyed Tool and removed PlayerGui release the cursor/reticle. Disabling the reticle ScreenGui restores the native cursor and blocks its fire input until re-enabled.

Mouse movement, PreferredInput/MouseBehavior changes, viewport/current-camera changes and inset changes update layout. There is no RenderStepped loop. Input-mode reconciliation does not disconnect Tool.Activated. The UI has no action binding and is noninteractive/nonselectable, preserving Tool/controller firing and Throw/Sprint/Jump controls.

The server still resolves the untrusted camera ray against world geometry and converges from its own GunBarrel muzzle. Physical travel remains 70 studs/second, range 110 studs, cooldown 2 seconds, damage 14 HP, freeze 2.75 seconds, immunity 4 seconds, direct impacts only. Near obstruction or moving targets can legitimately produce impacts different from the original camera target; no reticle offset, homing or aim assist was added.

API references: [UserInputService](https://create.roblox.com/docs/reference/engine/classes/UserInputService), [Camera](https://create.roblox.com/docs/reference/engine/classes/Camera), [GuiService](https://create.roblox.com/docs/reference/engine/classes/GuiService).

## Live reproduction and build verification still required

1. Stop Play. Sync current Rojo sources and temporarily set IceGunConfig.DebugLogging=true. Restart Play; updating source during Play does not invalidate previously required ModuleScripts.
2. Expect revision icegun-circle-2026-10-09 in the ownership, projectile and controller initialization logs, with the mapped module paths. Server paths should be ServerScriptService.Server.Services.IceGunService / IceGunProjectileService; client path should be Players.<player>.PlayerScripts.Client.Controllers.IceGunController. Missing/wrong markers require fixing sync/bootstrap first, not adjusting gameplay gates.
3. Paste tests/studio_icegun_diagnostics.luau into the Studio Play Command Bar on Server, then Client. It prints module revision presence, remote count (one), Tool issue/activation properties, cached ownership, exact registered equipped Tool, plot session, action acceptance, PlatformStand and muzzle-to-root distance. Run the same probe at each following phase.
4. Join as the real existing pass owner. Without claiming a plot, select the initial gun through the hotbar and click at an unobstructed wall. Capture both Output streams. Record Tool.Activated, Fire RemoteEvent sent, server receipt, server issue authorization, action state, geometry, fire eligible/projectile spawned, and any rejection or immediate impact/expiry.
5. Claim a plot without touching EquipmentSpawner. Equip the same gun if necessary, wait out cooldown and shoot again from comparable geometry. Compare issue ID and the first differing stage/condition. Only then interact with the pedestal and repeat. Registry replacement, changed action locks and changed muzzle geometry must be supported by the logs, not assumed.
6. Repeat first hotbar fire after respawn and with Studio simulated ownership; check an unentitled player cannot launch. With two clients, verify unassigned/team immunity and eligible enemy damage/freeze after claim.
7. Desktop: move mouse over walls at different screen positions, test shift-lock/first-person and right-click lock-current camera drag, near/far/elevated/lower targets and camera offsets. Circle and camera aim must align; watch physical flight and muzzle obstruction separately. Test hover on menus/TextBoxes, escape menu, focus loss, equip another Tool, death/reset and restoration of custom/hidden native cursor states.
8. Device Emulator and real device/controller: portrait/landscape/wide/notched safe areas, center aiming during camera rotation, Throw/Sprint/Jump and controller fire/navigation, repeated preferred-input switches and respawn. Confirm a single circle, no overlap with action buttons, one shot per activation and immediate lifecycle cleanup.
9. Disable DebugLogging after capturing the comparison. No Studio desktop/mobile/console acceptance test has been executed by this pass.

Diagnostics are Studio-only, optional and rate-limited. New logs identify revision/module locations, Tool Enabled/ManualActivationOnly/RequiresHandle, session and ownership snapshots (diagnostic only), movement/PlatformStand state, muzzle/root/camera geometry and projectile collision/termination. They preserve all existing authorization gates.

## Automated validation

Seven focused suites pass: icegun-initial-owner, icegun-entitlement, freeze-status, icegun-combat, icegun-simulated-combat, icegun-aim and icegun-input. Authoritative/state and cross-system suites report independently from presentation. New coverage verifies claim alone preserves the original issued gun's launchability without pedestal, circular desktop presentation, pointer/device-safe coordinates, locked-center aim, menus/text/UI hover/navigation/focus, disabled GUI behavior and previous visible/hidden cursor restoration. Existing suites retain ownership/security, respawn, simulated/Marketplace boundary, PvP immunity, convergence, obstruction, swept collision and balance contracts. Marketplace checks in CLI are doubles, not live real-account verification.

Changed runtime modules pass Roblox-aware luau-lsp analysis. Full-src analysis has exactly the same 216 TypeError lines as the pre-edit snapshot. StyLua check passes for all changed Luau files and the Studio probe. Rojo 7.7 build passes. Unrelated working-tree changes were preserved.

Changed files:
- src/client/Controllers/IceGunController.luau — circle, aim coordinates and cursor/input lifecycle.
- src/server/Services/IceGunService.luau — diagnostic revision/path and Tool activation properties only.
- src/server/Services/IceGunProjectileService.luau — diagnostic revision/path, action/geometry and termination only.
- tests/fixtures/icegun_input.luau — preferred input, UI/inset/focus boundary.
- tests/icegun_input.spec.luau — cursor/reticle/input contracts.
- tests/icegun_initial_owner.spec.luau — claim-only, original-instance firing contract.
- tests/studio_icegun_diagnostics.luau — read-only Studio Command Bar snapshot, not Rojo-mapped.
- docs/ICE_GUN_PREPLOT_CROSSHAIR.md — this report and outstanding live acceptance procedure.
