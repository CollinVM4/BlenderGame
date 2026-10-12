# Ingredient throw input investigation

## Confirmed findings

- **Ingredient activation was observed by IceGunController.** Its previous `watch` subscribed `Tool.Activated` for every Tool, including ingredients, before checking `IceGunWeapon` inside `requestFire`. This directly explains `issue=nil weapon=nil` and the rejected weapon activation logs. It does **not** prove IceGun consumed the click: an event listener does not itself sink input, and the previous attribute check already prevented an ingredient from sending a shot. Discovery still observes Tools for late attribute replication, but an activation listener now exists only while `IceGunWeapon == true`. Removing the marker disconnects it; transfers, destruction and respawn retain existing cleanup. The combined-controller regression checks ingredients never enter the firing handler, not merely that the server rejects them.
- **Server weapon ownership had a gap.** GameplayService rejected issued Bats but did not consult the issued IceGun before dispatching ThrowHeld. It now uses IceGunService.IsEquipped, which validates the server-issued instance and entitlement rather than trusting client attributes. A gun in the Backpack does not block throwing. This prevents stale or forged throw intent from throwing while the issued gun is equipped. Cooldowns and inventory checks are unchanged.
- **Hybrid hardware and geometry fixes already exist in this checkout.** CarryInputController uses unprocessed UIS MouseButton1 when MouseEnabled, regardless of TouchEnabled or PreferredInput. It does not bind MouseButton1 through CAS. IngredientThrow projects actual body/accessory geometry, excludes the thrower's full character from world queries, checks initial volume/sweep/destination and installs temporary self-collision exclusions. Regression tests pass for short/wide/tall geometry and obstructed throws retain inventory. No new geometry defect was confirmed, so physics were preserved.
- **Remaining affected-PC failure is unconfirmed.** There is no runtime trace from that PC, its body package, or a physical hybrid device. Do not attribute its failure to the weapon log alone. A processed click is still deliberately ignored; bypassing that flag could throw through UI. Inspect the runtime CAS snapshot to identify the consuming action if the failure produces processed=true.

## Resulting input paths

| Input | Owner and behavior |
| --- | --- |
| MouseButton1, MouseEnabled | UIS carry path accepts unprocessed clicks even with TouchEnabled or PreferredInput=Touch; equipped weapons take priority. |
| Touch world/UI gesture | No carry request. Touch alone is not a throw gesture. |
| CAS Throw button | Existing placement and Begin-only shared throw path remain. |
| Gamepad R2 | Carry uses normal CAS priority; equipped IceGun uses existing priority 2100. No priority change or mouse CAS binding was added. |
| IceGun Tool.Activated | Genuine marked weapon only; existing keyboard/mouse native activation and dedicated touch/gamepad fire paths remain. |
| UI | Processed mouse, focused text, Roblox menu, and GameplayPaused are ignored. |

PreferredInput is diagnostic context, not a carry capability gate. Touch-only synthesized mouse remains ignored when MouseEnabled=false. Real hybrid touch-to-mouse synthesis and Studio emulation need engine validation; CLI doubles cannot prove how Roblox marks these events.

## Reproduce on the affected PC

1. Sync with Rojo and restart Play to retire old controller listeners. No new assets, attachments, or collision groups are required.
2. In the **server** Command Bar enable the affected player: `game:GetService("Players"):FindFirstChild("PLAYER_NAME"):SetAttribute("ThrowDebug", true)`. This also enables client traces after replication. On a live server, use an authorized server-side diagnostic mechanism to set that attribute. Logs default off and are limited to 40 lines per player per five seconds independently on client/server.
3. Pick up three ingredients. Select an older one and click clear world space once. Capture Client and Server Output. Match `player` and `attempt`: capability/preferred input + equipped classifications, processed flag, handler/owner, request sent, receipt, authoritative selected/thrown IDs, placement, and publication or rejection. A selected/thrown mismatch with newestFirst=true is expected for an older selected ingredient.
4. Repeat with IceGun in Backpack, equipped, and during rapid switching. On the physical hybrid PC alternate mouse and touch, then try the dedicated Throw button. Also click menus/hotbar/text inputs. Wait at least 0.2 seconds between ordinary throws to distinguish the unchanged gameplay throttle.
5. Run `tests/studio_throw_diagnostics.luau` in Server and Client Command Bars. Capture runtime CAS priorities/input bindings, named GameplayRequest remote count, current rig parts/root and input capabilities. If client says processed=true, identify the runtime consumer before changing priorities. If sent has no matching receipt, compare remote count and deployed controller versions. If server rejects placement, capture the named obstruction and avatar snapshot; move away from walls/ceilings/other players and retry.
6. Repeat with normal R15, scaled R15, and the exact affected body/accessories. Test two clients, respawn, then pick up/equip/throw again. Disable with `player:SetAttribute("ThrowDebug", false)` on server. IceGun's separate Config.DebugLogging now defaults false and remains Studio-only.

Attempt metadata is an optional bounded integer in the fourth ThrowHeld argument. It is only a log label, never a selection, position, authorization, cooldown input, or result. Old clients and direct server inventory callers remain compatible.

## Validation and changed files

Runtime: `src/client/Controllers/CarryInputController.luau` (bounded diagnostics and menu/pause gate); `IceGunController.luau` (authorized activation ownership); `src/server/Services/GameplayService.luau` (receipt correlation and issued gun gate); `IngredientThrow.luau` (bounded server logging); `InventoryService.luau` (authoritative selection diagnostics); `src/shared/Constants/IceGunConfig.luau` (default-off diagnostics).

Tests: `tests/carry_input.spec.luau` (correlation, bounds, server weapon/UI gates); `icegun_input.spec.luau` (combined controllers and marker revocation); `fixtures/icegun_input.luau` (UIS/CAS boundaries); `fixtures/carry.luau` (required TycoonService dependency); `studio_throw_diagnostics.luau` (keyboard/preferred snapshot). Documentation: this file.

The carry fixture initially failed before any throw assertion because InventoryService.AddPlayer requires TycoonService. Substituting unchanged HEAD InventoryService reproduced both failures. Only the fixture dependency was repaired; production initialization was preserved.

Automated suites: throw, carry-input, throw-multiplayer, throw-blender, carry-selection, ingredient-slots, icegun-input. All seven passed after the changes. Focused Roblox-aware typecheck of all six changed runtime modules, StyLua checks of changed Luau files, and Rojo build passed. These suites use engine doubles, not real contact simulation or network/device input.

| Requested case | Automated coverage | Studio/device acceptance still required |
| --- | --- | --- |
| Desktop ingredient click | carry-input, combined icegun-input | Actual UI/input event delivery |
| Gun in Backpack | combined icegun-input, server gate | Hotbar switching |
| Equipped gun fires without throw | combined icegun-input | Live server shots |
| Rapid gun/ingredient switches | combined icegun-input | Replication delays |
| Hybrid physical mouse | carry-input with touch/mouse true | Physical Windows touchscreen PC |
| Hybrid touch does not duplicate | combined input rejects world Touch and processed clicks | Native synthesized input behavior |
| Mobile Throw button | shared CAS callback | Phone/tablet and emulator placement |
| Normal R15 | throw geometry | Live animated R15 |
| Widebody/scaled R15 | throw geometry dimensions/accessories | Exact body package and collision mesh |
| Rapid pickup/equip/throw | carry-input, carry-selection, newest-first contracts | Network timing |
| Respawn | throw-multiplayer, icegun-input | Multiplayer engine lifecycle |
| UI clicks | carry-input processed/text/menu/pause gates | Actual GUI processed flags |

No Studio multiplayer/device validation was performed in this change.
