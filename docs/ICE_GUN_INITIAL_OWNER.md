# Ice Gun initial owner and platform aiming follow-up

## Proven defect and limits of the diagnosis

The pre-change working tree already registers the initial grant in IceGunService. Both GrantIfOwned and RequestEquip reach the same server-issued Tool registry; RequestEquip reconciles the Tool and calls Humanoid:EquipTool. It does not establish an additional firing authorization flag. The sanitized Tool has Enabled=true and ManualActivationOnly=false. CarryInputController already passes primary input through for IceGunWeapon Tools.

A reproducible remaining **server-side** defect was IceGunProjectileService.Fire rejecting an otherwise entitled, living, equipped owner when TycoonService.GetSessionId returned nil. A new integration case traces Tool.Activated through the client FireServer call to the real server projectile service. Against the pre-change projectile source, its first hotbar shot fails; with the change, it creates a physical-travel server projectile. This is the first meaningful difference in the automated before/after comparison: launch eligibility, not missing ownership or an unregistered Tool.

The plot-session launch gate is removed. Paid account entitlement now permits firing before claiming a plot. CombatService's existing impact eligibility remains unchanged: unassigned attackers/victims cannot take part in PvP, current teammates remain immune, and damage/freeze still require an eligible direct swept impact. No spawn or inventory behavior was changed.

**The exact Eatandpoop Studio failure has not been captured.** Visiting a pedestal after acquiring a plot session would make the old launch gate pass, but pressing E itself does not create a plot session. If the reported player already had a session during the failed shot, the proven gate does not explain that incident. Claiming that E repaired the registry or connected a missing listener in that live session would be unsupported. The added diagnostics distinguish those cases without assuming a client cause.

The bootstrap also initialized IceGunController after numerous unrelated controllers that can yield. Input initialization now starts independently at the top of the bootstrap. This removes a startup delay risk; it is not claimed as a reproduced cause of the reported live failure.

## Usable Tool lifecycle

- Existing owners and respawned owners receive one authorized gun in Backpack and select it normally; these grants never force equip.
- Production verified purchase completion and the existing Studio simulator retain their one-time automatic equip behavior and production restrictions.
- The server assigns its issued reference before exposing the Tool in Backpack. A diagnostic IceGunIssueId correlates the instance across server/client Output; the ID and weapon attribute never authorize firing.
- Pedestal EQUIP reuses the registered instance when still valid. Tracing reports reuse/replacement and the result of EquipTool explicitly.
- Server retirement waits until a transient Backpack/Character reparent finishes before revoking an issued Tool. Foreign copies still fail exact server-instance authorization.
- Client discovery connects listeners before scans, works without an initial Character or Backpack, reconciles existing contents on startup/respawn, and checks the current Character at activation.
- Weapon-attribute arrival updates presentation. Activation listeners are installed before that attribute arrives and check it at fire time, so no equip event must be repeated to finish binding.
- Per-Tool listeners are deduplicated and retired on destruction/removal. Character listeners and old Tool bindings are retired during character teardown. Transfers and switching Tools remain usable.

## Platform aiming and reticle

Desktop retains GetMouseLocation plus ViewportPointToRay and the normal cursor. Touch and gamepad **already used the corrected camera-center ray and the same server camera-to-muzzle convergence**. They did not require a trajectory rewrite. Each activation reads the current camera, so right-stick camera motion is not cached at equip time.

A small white crosshair with dark outline now appears only for an equipped Ice Gun using touch/gamepad input. It uses a ScreenGui with DeviceSafeInsets and a centered scale position, matching ViewportSize/ViewportPointToRay coordinates, including the top bar but excluding device cutouts. Roblox documents these coordinates in [Camera](https://create.roblox.com/docs/reference/engine/classes/Camera) and [ScreenInsets](https://create.roblox.com/docs/reference/engine/enums/ScreenInsets). Scale positioning adapts to aspect ratio without a per-frame update. Frames are noninteractive and nonselectable; no touch buttons, CAS bindings, Framewisp dependency or mouse dependency was added. Unequip, death, Character removal and Tool destruction remove the reticle immediately. Input changes and late PlayerGui/weapon attributes reconcile visibility.

Server GunBarrel origin, camera-ray bounds/validation and server occlusion resolution, root-to-muzzle/muzzle obstruction, swept collision, physical travel, range, cooldown and entitlement checks remain. Speed 70 studs/sec, cooldown 2 seconds, direct damage 14 HP, freeze 2.75 seconds, post-thaw immunity 4 seconds, no splash and team immunity remain covered in their existing authoritative test homes.

## Diagnostics and comparison

Temporarily set IceGunConfig.DebugLogging=true in Studio; logging is disabled by default and gated by IsStudio. Each player/stage is limited to once per second, with no frame logging.

Before visiting the pedestal, capture entitlement verification, Tool issue/registration and Backpack grant, controller initialization, Backpack/Character observation, weapon attribute receipt, Activated connection, Activated firing, Fire RemoteEvent sent, server request receipt, issued-instance authorization, and the exact server rejection or eligible/projectile-spawn stage.

Then press E and compare IceGunIssueId, parent and weapon attribute. Server logs report the instance before reconciliation, reuse/replacement, and EquipTool's equipped result. Client observation/connection logs show whether a new binding was needed. Fire requests include the server's equipped issue ID. Missing entitlement, missing registry entry and a registered Tool outside the current Character have separate authorization diagnostics; every remaining projectile rejection has its own reason.

If no client controller initialization appears, inspect bootstrap errors. If Activated appears without FireServer, inspect the local rejection. If FireServer appears, compare the server authorization and exact geometry/action/cooldown rejection before and after E. Record the **first** changed stage and the plot-session state when reproducing the old build.

## Validation

Seven focused suites pass independently: icegun-initial-owner, icegun-entitlement, freeze-status, icegun-combat, icegun-simulated-combat, icegun-aim, icegun-input.

The new integration home covers ownership and grant before/after controller startup, late Character/Backpack in both orders, first hotbar selection without pedestal or plot session, preservation of unassigned-player PvP immunity, same-instance pedestal equip, transient reparenting, repeated re-equip producing one fire request/projectile, and respawn first-selection firing without forced equip. The input presentation suite covers late attributes, touch/controller camera-center rays, moving camera rays, portrait/landscape/wide aspect ratios, reticle safe-area coordinates, desktop cursor preservation, unequip/removal/death cleanup and dead input rejection. Existing aim/combat/entitlement/freeze suites retain zoom, above/below targets, muzzle offsets/obstruction, orientation/travel, purchase/simulator/security and balance contracts.

The new first-owner integration test fails against the original projectile service at the first unclaimed-owner shot and passes with the change. StyLua check and Rojo 7.7 build pass. Roblox-aware analysis of the three changed Ice Gun modules passes. Full-src typechecking remains nonzero with exactly the same 216 TypeError lines reproduced before editing; there are no added errors. Including the client bootstrap also exposes existing CustomerRequests dependency errors. Unrelated production code was left unchanged.

Run:

~~~text
python tests/run_state_tests.py --luau <luau.exe> --suite icegun-initial-owner --suite icegun-entitlement --suite freeze-status --suite icegun-combat --suite icegun-simulated-combat --suite icegun-aim --suite icegun-input
stylua --check <changed Luau files>
rojo sourcemap default.project.json --output <temporary sourcemap.json>
luau-lsp analyze --platform roblox --sourcemap <sourcemap.json> --definitions <globalTypes.d.luau> src
rojo build default.project.json --output <temporary game.rbxlx>
~~~

## Changed files in this follow-up

Runtime: src/client/Controllers/IceGunController.luau; src/client/init.client.luau; src/server/Services/IceGunService.luau; src/server/Services/IceGunProjectileService.luau.

Tests: tests/fixtures/icegun_input.luau (new); tests/icegun_initial_owner.spec.luau (new); tests/icegun_input.spec.luau; tests/run_state_tests.py. Documentation: this file. Existing working-tree changes were preserved.

## Remaining Studio acceptance

No new model, attachment, StarterPack, GUI asset or plugin setup is needed; sync with Rojo.

1. Join as Eatandpoop with real Roblox verification of pass 2022020489. Before claiming a plot or touching EquipmentSpawner, select the granted hotbar gun and fire. Confirm projectile launch, then repeat after claiming a plot. Capture development client/server Output and issue IDs if either fails.
2. Die/respawn, select from hotbar and fire without the pedestal. Switch to another Tool and back repeatedly. Check one gun, one shot per activation, and no forced equip on spawn.
3. With two clients on opposing plot sessions, verify direct damage/freeze and team/unassigned-player immunity. Confirm new purchase and Studio simulation still auto-equip once and canceled/unverified purchases grant nothing.
4. Use Device Emulator plus physical mobile and controller clients: portrait/landscape/notched screens, near/far zoom, above/below targets and right-stick camera movement. Verify the visible reticle's aim point matches muzzle convergence, Tool touch/controller activation works, and Throw/Sprint/Jump and controller navigation remain unchanged.
5. Confirm reticle removal on unequip, death and removal, desktop cursor behavior, actual mesh forward orientation, visible 70-stud/sec travel, blocked-muzzle/world collision, cooldown, range and post-thaw immunity. Engine doubles cannot establish real replication timing, device input routing or rendered geometry.
6. Disable DebugLogging after capturing the initial/pedestal comparison. A live trace is still required to identify the exact cause and first changed stage of the originally reported session.
