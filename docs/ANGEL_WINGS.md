# Angel Wings Game Pass

Implementation: Rev3 brief, 2026-11-02, with the [in-progress feel correction](ANGEL_WINGS_FEEL_FIX.md). Studio acceptance is **PENDING**, not a release sign-off. The reported missing-WingMotor failure is repaired through native accessory joint posing; post-fix Studio visual and two-client acceptance remain PENDING.

## Audited assets and UI revision

- Pass ID: `2021642550`. Price is queried on each client via Marketplace, never hardcoded as a purchase price. The actual localized/Dashboard price has **not been observed** in Studio.
- Supplied local asset: `angelWings.rbxmx`, mapped to `ServerStorage.AngelWingsTemplate` in `default.project.json`. One `Accessory` named `Angel wings`, one `Part` named `Handle`, one `SpecialMesh` (`rbxassetid://7236038907`), and `Handle.BodyBackAttachment`. There are **no independent left/right wing parts or joints**. The authored attachment position is approximately (-0.000242, 0.135629, 0.813240), rotated 180 degrees around Y. The service aligns it with the rig's BodyBackAttachment (torso-back fallback for R6).
- The single supplied mesh is posed as a pair through the native accessory RigidConstraint (legacy AccessoryWeld and prior WingMotor grants are supported); resting poses narrow its mesh silhouette and tilt it, Powered pulses width with a small bank/bob, Gliding holds it spread with a small bob. Native BodyBackAttachment and scaling metadata remain intact; posing uses a separate client attachment. Independent feather/left-right articulation would require different art. Visual quality, camera clearance and R6/R15 fit require Studio inspection.
- Initial audit found `uiExport_103026.rbxmx` / `Framewisp_Hotbar.prepared.rbxmx`. During implementation Collin replaced the source with `newestExport.rbxmx` and explicitly approved using it. Current revision is **newestExport.rbxmx**, root `Framewisp_WYHWBJ`. The preparation tool now defaults to that source; its output remains `Framewisp_Hotbar.prepared.rbxmx`. Removed old source exports were not restored.
- Shop binding: `FramewispMenus` opens the registered Shop panel and publishes `MenuNotifications.OnOpened("Shop")`. `WingsShopAdapter` subscribes to that existing path and resolves `Shop/ShopScroll/ShopList/Angel Wings`, `Buy/BuyLabel`, and `Robux/RobuxCost` with `UIRegistry.Child`. No authored element is rebuilt/repositioned. The existing IceGunShopAdapter has no consumer in FramewispMenus; wings binds independently through the same registry/open notification path.

## Mechanics and authority

The server verifies live entitlement, grants a sanitized registered accessory, owns input interpretation and the 1.75-second per-airborne-episode budget, and publishes WingState. Releasing Jump preserves remaining energy. Only 0.2 seconds of consecutive humanoid-state AND FloorMaterial evidence refills it. Swimming, climbing, seated/Physics, PlatformStand, stun/freeze and anchored roots cancel lift without refilling. Confirmed revocation is deferred until sustained landing or respawn. Ownership lookup failure does not remove an already granted airborne accessory; new grants fail closed.

Lift channel: **local client RenderStepped, gated by server WingState**. WingsService no longer writes root velocity or borrows network ownership. The client preserves X/Z and faster rising momentum, approaches 45 studs/s at 300 studs/s?, floors each Powered entry at 30 studs/s, and caps glide descent at -20. The server retains entitlement, energy, movement eligibility, recharge and landing protection. The glide overspeed latch is removed. BatKnockback itself is unchanged by this correction. No new movement detector is included; modified clients ignoring WingState remain outside this pass.

FallDamageService retains its existing curve, thresholds, compensation and landing/void rules. Its optional wings callbacks delimit each fall episode, observe genuine landing candidates, and atomically consume glide protection before damage. Wings also captures provisional pre-touchdown glide evidence so reverse Heartbeat order / different ground-confirmation windows cannot erase it. Graze, release, lock, reset, teleport and subsequent episodes invalidate evidence. There is no timed immunity flag.

No jump catalog, JumpPower/tier, WalkSpeed/stamina, payout, gameplay action gate, DataStore, tutorial, hotbar or 2x Cash production logic was changed by this wings pass. Separate concurrent hotbar/UI-source edits in the workspace belong to the other ongoing work.

## Hold sensor investigation

The preferred Enum.PlayerActions.CharacterJump binding was investigated rather than assumed: the available current Roblox-aware CAS signature accepts KeyCode/UserInputType, not PlayerActions. The supported fallback observes Space and ButtonA with a high-priority CAS callback that always returns Pass and never creates a touch button. Native mobile JumpButton input is observed separately, with matching touch identity and global InputEnded handling for release outside the button. The sensor clears on Cancel, focus loss, text focus, menu open, character removal, hidden/recreated button and teardown. Input sends only changed booleans.

API/source references:
- https://create.roblox.com/docs/reference/engine/classes/ContextActionService
- https://github.com/Roblox/Core-Scripts/blob/master/PlayerScripts/StarterPlayerScripts/ControlScript/MasterControl/TouchJump.lua

The archived TouchJump source explains why mobile is handled separately; it does not prove current engine/device behavior. Mocked press/release, cancellation, touch, first-airborne hold and duplicate suppression passed. **PC, mobile and console physical/device-simulator verification is still pending. A missing release signal remains a release blocker.** No press-only or toggle fallback is used.

## Changed files

- `src/shared/Constants/WingsConfig.luau`: exact pass ID and specified initial balance values; no tuning from unobserved Studio measurements.
- `src/server/Services/WingsService.luau`: entitlement/purchase, sanitized accessory lifecycle, flight budget, server lift, glide validation, episode-scoped landing evidence.
- `src/server/Services/FallDamageService.luau`: optional wings dependency and narrow episode/landing/reset callbacks plus glide-protected diagnostic branch; unchanged damage math/tracker rules.
- `src/server/Services/BatKnockback.luau`: overlapping network-ownership leases for wing/bat coexistence; existing API preserved.
- `src/server/init.server.luau`: WingsService initialization and existing player/character/removal chains; no new CharacterAdded connection.
- `src/client/Controllers/WingsController.luau`: all-player poses and once-per-session verbatim onboarding via existing AnnouncementBanner.
- `src/client/Controllers/WingsHoldSensor.luau`: isolated passive cross-platform hold/release sensor.
- `src/client/Controllers/WingsShopAdapter.luau`: authored-card binding, client-local live pricing, ownership display and purchase intent; no Equip.
- `src/client/init.client.luau`: independent spawned input/display/shop startup.
- `default.project.json`: supplied wings asset mapping.
- `tools/prepare_framewisp_ui.py` / `Framewisp_Hotbar.prepared.rbxmx`: approved newestExport source selection and regenerated output. The larger artwork diff is from Collin's replacement export, not runtime wings styling.
- `tests/fixtures/wings.luau`, `tests/wings_flight.spec.luau`, `tests/wings_ownership.spec.luau`: authoritative/integration contracts at the mocked Marketplace/physics boundary.
- `tests/wings_input.spec.luau`: independent input/onboarding presentation tests.
- `tests/wings_shop.spec.luau` / `tests/run_wings_shop_tests.py`: real resolver against both source/prepared XML, all bound-name rename failures, localized-price/Owned/refresh behavior.
- `tests/bat_knockback.spec.luau`: overlapping borrower release orders.
- `tests/run_state_tests.py`: explicit wings suites and controller source bundling.
- This document and `tests/README.md`: validation and pending manual checks.

## Automated validation

Passing suites: wings-flight, wings-ownership, wings-input, fall-damage, bat-knockback, combat-launch, combat, freeze-bat, unstuck, unstuck-placement, unstuck-fallback, initial-spawn, icegun-entitlement, icegun-initial-owner, icegun-combat, icegun-simulated-combat, icegun-input, upgrade-sync and client-presentation. Shop resolution passes on both XML exports. Presentation runs independently from state/integration tests.

Four existing suite failures reproduced in an isolated `git archive HEAD`:
- sprint: StandIdentity receives a missing fixture name during AssignPlot.
- legacy-movement: retired "comfortable movement baseline applies" expectation.
- bat-controller: missing CarryInputController input signal fixture.
- tutorial-claim: missing module in UnstuckService's bootstrap test bundle.

StyLua checks all wings-touched Luau files. Default-project Rojo build passes, including the supplied accessory and regenerated UI. Full-source Roblox-aware typecheck is not globally clean: the wings-only snapshot matched HEAD's 212 existing TypeError headers exactly, with no errors in new/touched wings modules. The final captured shared-workspace check reported 243 TypeError headers; the 31 additional headers are in concurrently edited hotbar modules, outside this pass. Those files continued changing during validation and should be reviewed with that work. Do not describe full-source typecheck as passing.

Run:

```text
python tools/prepare_framewisp_ui.py
python tests/run_state_tests.py --luau <luau.exe> --suite wings-flight --suite wings-ownership
python tests/run_state_tests.py --luau <luau.exe> --suite wings-input
python tests/run_wings_shop_tests.py --luau <luau.exe>
rojo sourcemap default.project.json --output <sourcemap.json>
luau-lsp analyze --platform roblox --sourcemap <sourcemap.json> --definitions <roblox.d.luau> src
rojo build default.project.json --output <place.rbxlx>
```

## Manual Studio acceptance — all pending

1. Sync/build the default project and confirm `ServerStorage.AngelWingsTemplate` contains the supplied accessory. Use the actual pass owner/non-owner accounts; no Studio ownership bypass or saved flag was added. Confirm asset/mesh permissions in the published experience.
2. **PC Space, mobile native Jump, console standard Jump:** hold from ground, first airborne engagement, 1.5–2 seconds Powered, Glide, release/re-hold at both stages, focus/menu cancellation and no second visible button. Record device/platform and observed timing. Missing release blocks acceptance.
3. **Two-client session, required:** host and client verify actual lift/replication, all four distinct poses on both avatars, R6/R15 fit and camera/carry/weapon clearance. Record any network-ownership stutter and bat-hit overlap. Solo Studio cannot establish this.
4. **Purchase/UI:** record the actual localized live price and compare with Dashboard (initial target 299; report any difference without overriding Dashboard). Verify cancel/failure, verified purchase without rejoin, disabled Owned, join-owned grant, respawn restoration and exact onboarding shown once per session. No live price was measured by this pass.
5. **Progression measurement:** record unaided and wing-assisted maximum Y/reach for Jump tiers 0–3 and the actual Jump-tier-gated/Cloud Garden destination heights. Jump 0 + wings must not reach a gated destination. No reach or gate-height values were measured. Measure at the new 45 target / 300 acceleration / 30 entry floor and 1.75-second duration. If Jump 0 + wings reaches a tier gate, report the measurements, trim duration first, and re-measure. Do not add a wings entry gate or silently restore the weak 22 target.
6. **Fall/interaction regression:** high-peak glide landing safe; release immediately before landing and one second earlier damages normally; no stale protection next fall; graze/bunny hop under 0.2s does not refill; walk-offs engage. Verify stun/freeze/knockback, sprint drain, bat, ice gun, carry/throw/store/serve and existing 2x Cash display.

All physical, device-specific, live Marketplace, progression-height and multiplayer results remain **Pending manual Studio verification**. Balance values remain exactly those supplied in Rev3.
