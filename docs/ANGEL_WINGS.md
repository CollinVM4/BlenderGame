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

FallDamageService retains its existing curve, thresholds, compensation and landing/void rules. Its optional wings callbacks delimit each fall episode, observe genuine landing candidates, and atomically consume engaged-wing protection (Powered or Gliding, server JumpHeld and eligible) before damage. Wings also captures provisional pre-touchdown engaged-wing evidence so reverse Heartbeat order / different ground-confirmation windows cannot erase it. Graze, release, lock, reset, teleport and subsequent episodes invalidate evidence. There is no timed immunity flag.

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


## Engaged landing follow-up - 2026-11-02

Code implemented against HEAD `3389a9d`; **Studio acceptance PENDING**.

The requested functions remain at their original paths. `IsGliding` is renamed to `IsWingControlled` in `src/server/Services/WingsService.luau`; the predicate now accepts Powered OR Gliding while retaining the server-observed JumpHeld and eligible checks. Both captures use the new predicate: ObserveFallLanding and the grounded branch of step. All references in wings_flight, wings_input and wings_ownership specs use the new name; there are no stale executable references.

The nil-only capture, forced-false cancellation, SetJumpHeld release behavior, one-shot ConsumeGlideLandingProtection and 0.2-second grounded confirmation are unchanged. Falling, Airborne, Grounded and ungranted players do not satisfy the predicate. The existing provisional landing capture still survives a subsequent Grounded publication if wings updates before fall evaluation. Server-observed input arriving after evaluation has no retroactive effect. No release grace window or persistent immunity was added.

In the initial engaged-landing follow-up, FallDamageService was unchanged. The upward-recovery amendment below now adds a narrow Heartbeat peak reset. evaluateLanding, jump compensation, thresholds/curve, and the diagnostic reason `glide-protected` remain unchanged. ConsumeGlideLandingProtection keeps its existing name/API.

Changed files in this follow-up:

- `src/server/Services/WingsService.luau`: predicate rename/broadening and the two capture call sites; the only production change.
- `tests/wings_flight.spec.luau`: renamed references and lethal-peak integration coverage for Powered/Gliding protection, unchanged diagnostic reason, release damage, unowned damage, captured protection invalidated by release, next-fall freshness, one-shot consumption, and wings-first landing capture.
- `tests/wings_input.spec.luau`: cancellation assertion renamed to IsWingControlled.
- `tests/wings_ownership.spec.luau`: death/cleanup assertion renamed to IsWingControlled.
- `docs/ANGEL_WINGS.md`: this summary and current protection description.

The Powered regression failed on the pre-pass implementation at `Powered held through lethal-peak landing prevents all damage`, then passed after the predicate change. The server atomically publishes Falling on release, so a private Powered/JumpHeld=false combination cannot be produced through its API; the release regression also verifies that a Powered display attribute cannot restore a captured exemption after server JumpHeld becomes false.

Validation: wings-flight, wings-ownership, wings-input, wings-shop (both authored and prepared exports), and the fall-damage suite PASS. StyLua on all changed Luau files and the default-project Rojo build PASS. Full-source Roblox-aware typecheck reports 212 existing TypeError headers; a fresh isolated archive of HEAD reports the same 212 normalized diagnostics, with no new diagnostic introduced. Tests use the real fall tracker with mocked engine boundaries; they do not establish Studio physics/input timing.

Required Studio acceptance from a height known lethal without wings:

| Scenario | Result |
| --- | --- |
| Build lethal speed, engage late with energy remaining (Powered), hold through touchdown; zero fall damage | PENDING |
| Build lethal speed, engage with energy exhausted (Gliding), hold through touchdown; zero fall damage | PENDING |
| Same fall, release Jump before touchdown; normal peak-based damage | PENDING |

No connected Roblox Studio tool is available to run these scenarios in this session. Sync the default Rojo project and start a new Play session with an entitled account; no new Studio objects or configuration are required. This follow-up is not a Studio acceptance sign-off.


## Upward wing recovery amendment - 2026-11-02

An airborne upward wing burst now cancels the downward peak accumulated before that recovery. After the server observes positive vertical velocity while IsWingControlled is true, the fall tracker clears the old peak and soft-landing timer and resets the wings landing candidate for the continuing airborne episode. Releasing Jump after this recovery does not restore the old peak. Any subsequent descent builds a new peak and can still cause normal fall damage.

This amendment supersedes the earlier rule only for a completed upward recovery. Slowing the descent or reaching zero vertical velocity does not clear the peak. Releasing without an upward recovery still cancels engaged-landing protection immediately. An upward impulse without eligible engaged wings does not trigger this reset. No timer, release grace, blanket airborne immunity, client-sent velocity/state payload or damage refund was added. evaluateLanding and the damage curve remain unchanged; the optional diagnostic reset reason is `wing-ascent`.

Files changed by this amendment:

- `src/server/Services/FallDamageService.luau`: narrow airborne wing-ascent reset in the existing Heartbeat episode loop.
- `tests/wings_flight.spec.luau`: real fall-tracker regressions for upward recovery followed by release and immediate/low/moderate/lethal subsequent descent, plus non-upward and inactive-wing controls. The new recovery regression failed before the change and passes afterward.
- `docs/ANGEL_WINGS.md`: this behavior and acceptance record.

Validation: wings-flight, fall-damage and wings-ownership PASS; changed-file StyLua and default-project Rojo build PASS. Full-source Roblox-aware typecheck matches a fresh archive of HEAD `84a8f76`: 212 existing normalized TypeError headers in both, no new diagnostics. Concurrent ice-ray changes in the shared workspace were not modified by this amendment.

Studio acceptance remains **PENDING**: build lethal downward speed, engage wings until visibly rising, release, then land from a short remaining drop without damage from the original fall. Repeat with a subsequent long drop and confirm that the new descent still damages normally. Merely slow the fall without rising, release and confirm the original peak still applies. No new Studio setup is required.
