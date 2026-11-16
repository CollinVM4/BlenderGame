# Standalone hotbar startup rebuild

Implemented from current GitHub `main`, verified by `git ls-remote` at
`9ec68c295c65d00a522aa9a724d94e766920c1e1` on November 16, 2026. The working tree
included the checkpoints documented in HOTBAR_STARTUP_TRACE.md. The seven
already-deleted `hotbar-*.patch` files were left as found. Sprint Pass 2 stays paused.
The live phone failure's cause remains unconfirmed; this rebuild does not claim
that a text API or any other particular operation caused it.

## Runtime behavior

The existing early `HotbarController.Init()` creates one
`PlayerGui.BlenderHotbar` ScreenGui with `ResetOnSpawn = false` and
`ScreenInsets = CoreUISafeInsets`. The same root survives rotation, empty
inventory and Character/Backpack replacement. Teardown disconnects subscriptions,
releases custom input and restores native access with a bounded CoreGui retry.

`HotbarGui` creates one reusable ImageButton template from the known Framewisp
backing, selected, Bat, Ice Gun and generic assets. Fredoka labels and number
badges occupy fixed regions. Icons fit proportionally. Square targets are normally
56–72 pixels, with a 48-pixel floor on unusually narrow safe areas. Long names
truncate without growing slots. Ingredient/Smoothie previews are optional deferred
work; missing, failing or suspended preview work cannot block the usable fallback.
Late preview assets can populate the existing slot.

Layout reads the mounted safe-area Frame, once. It uses live movement/action
bounds and the shared MobileControlLayout placement policy, including conservative
reserves before TouchGui or CAS mounts. The row docks at bottom center in the
first clear lane. Occupied slots use an explicit horizontal canvas; the canvas
is computed from count, slot size, gap and padding. There is no text measurement,
slot growth or measured-scroll equality gate. Routine renders preserve swipe
position. Bounds/count changes clamp it; actual equip or gamepad-focus changes
reveal the affected slot. Brief zero bounds preserve an established layout.

Only HotbarController writes the native Backpack CoreGui setting. Native remains
available until a supported Tool, selectable Humanoid, mounted view and usable
slot area exist. Slots/input are prepared before disabling. A successful disable
commits custom visibility in the same non-yielding update. A failed disable with
native still enabled leaves custom input and visibility inactive. Successful
ownership is not reasserted for rotation, respawn, empty inventory, late controls
or later Tools. Only failed CoreGui operations retry: at most eight attempts per
ownership transition, 0.25 seconds apart. Genuine view loss releases input and
restores native; re-enabling/reattaching the same view permits takeover again.

Tool classification, Backpack/Character discovery, identity deduplication,
Bat → Ice Gun → Ingredients by CarryItemId → Smoothie ordering, 1–9/0 shortcuts,
controller links, menu/pause/chat/stale/dead-character guards and Humanoid
EquipTool/UnequipTools calls remain. Gameplay services and remote contracts did
not change. The existing admin-only `;hotbardebug` reports place version,
orientation, owner, transition reason, safe width, occupied slots, visibility and
CoreGui errors. Its remote can arrive late. The old `hide` argument is accepted
as a diagnostic read; it does not bypass readiness or force another CoreGui write.
No command is required for startup.

Removed startup dependencies: Framewisp registry discovery, authored slot
validation/reparenting, text-scaler takeover, per-slot TextService measurement,
slot growth loops, scroll-size equality checks, render-flight recovery timers,
initial layout retries and delayed touch reassertions. Optional previews and the
QA remote are also outside the handoff path. The historical HotbarDiagnostic
module is no longer started by the controller.

## Changed files

| File | Purpose |
| --- | --- |
| `src/client/Controllers/HotbarController.luau` | Standalone lifecycle, Tool observation/input, ownership and concise QA report. |
| `src/client/UI/HotbarGui.luau` | Dedicated view, reusable template, deterministic layout and scroll/reveal. |
| `src/client/UI/MobileControlLayout.luau` | Exposes actual/predicted control obstacles using its existing placement policy. |
| `Framewisp_Hotbar.prepared.rbxmx` | Removes the legacy hotbar subtree. All 542 remaining instances retain their properties and scripts. |
| `tools/prepare_framewisp_ui.py` | Removes the legacy subtree on future imports, preserving other export bytes. |
| `tests/hotbar.spec.luau` | Focused observable startup, input, lifecycle, overflow and fallback contracts. |
| `tests/run_hotbar_tests.py` | Loads the real standalone modules and shipped-export names. |
| `tests/framewisp_export.py` | Requires the shipped export to have no legacy bar. |
| `tests/test_prepare_framewisp_ui.py` | Verifies removal/preservation/idempotence; uses present `export1162.rbxmx` fixture. |
| `docs/HOTBAR_STARTUP_TRACE.md` | Links the historical investigation to this replacement. |
| `docs/HOTBAR_STARTUP_REBUILD.md` | Validation and Studio/published-phone handoff. |

`src/client/init.client.luau` and `default.project.json` were inspected and retain
the existing early initialization and Rojo mappings. The prepared export is still
required by menus, upgrades, settings, shops, scrapbook and other registry users.
It must remain mapped at `StarterGui.Framewisp_CCVVMF`.

## Validation

| Check | Result |
| --- | --- |
| Baseline hotbar runner before editing | PASS, 2,068 checks. |
| Standalone hotbar runner | PASS, 31 cases, 0 failed; 285 checks in Roblox UI/input doubles. |
| Mobile control layout runner | PASS, 282 checks. |
| Framewisp menu runner | PASS, 1,534 checks. |
| Export preparation unittest suite | PASS, 17 tests, 0 failed. |
| Roblox-aware typecheck, all three changed runtime modules | PASS, 0 errors with fresh Rojo sourcemap and Roblox definitions. |
| Broader analysis through unchanged client initializer | FAIL, 22 CustomerRequests.DisplayText type errors; identical on an isolated HEAD snapshot. No hotbar type errors or new diagnostics. |
| StyLua, all changed Luau files | PASS. |
| `git diff --check` | PASS. |
| Rojo 7.7 build and XML inspection | PASS; one mapped Framewisp ScreenGui in StarterGui, no legacy Hotbar subtree. Runtime ScreenGui is created by the controller. |
| Studio sync/publish and physical phone acceptance | PENDING — Collin. |

The old preparation suite initially failed because it referenced absent
`export116.rbxmx` (baseline: 18 errors before any test body). Its fixture reference
was corrected to the repository's `export1162.rbxmx` while updating the removal
contracts. No unrelated production code was changed.

Commands (use the already installed Rojo 7.7 binary if the Aftman shim cannot
resolve its home):

```powershell
python -B tests/run_hotbar_tests.py --luau .validation-tools/luau.exe
python -B tests/run_mobile_control_layout_tests.py --luau .validation-tools/luau.exe
python -B tests/run_framewisp_menu_tests.py --luau .validation-tools/luau.exe
python -B -m unittest discover -s tests -p test_prepare_framewisp_ui.py
.validation-tools/stylua.exe --check src/client/Controllers/HotbarController.luau src/client/UI/HotbarGui.luau src/client/UI/MobileControlLayout.luau tests/hotbar.spec.luau
rojo sourcemap default.project.json --output <temporary-sourcemap.json>
.validation-tools/luau-lsp.exe analyze --platform roblox --sourcemap <temporary-sourcemap.json> --definitions .validation-tools/globalTypes.d.luau src/client/Controllers/HotbarController.luau src/client/UI/HotbarGui.luau src/client/UI/MobileControlLayout.luau
rojo build default.project.json --output <temporary-build.rbxlx>
git diff --check
```

Build, sourcemap and baseline/current initializer diagnostics are retained outside
the diff at
`C:\Users\COLLIN~1\AppData\Local\Temp\blender-hotbar-rebuild-c7da4d347e7b48e5bb49ea14146f9488`.
These engine doubles do not establish native Backpack pixels, glyph rendering,
phone touch routing or real replication timing.

## Studio sync and cleanup — Collin

1. Stop any active Play/Test session. Use this checkout's `default.project.json`
   for the Rojo server; sync both the client modules and mapped prepared export.
   Record the exact `git rev-parse HEAD` and whether local changes were present
   at sync. This handoff itself is an uncommitted change on the base above.
2. Confirm the destination place before publishing. The current Studio log
   `0.747.0.7471481_20261116T161958Z_Studio_A1068_last.log` records place
   **135773467290280**, universe **10764667433**, and a version check of **1542**
   at 11:22 a.m. America/New_York on November 16. This is log evidence of the
   opened target; it is not evidence that this source was synced or that a phone
   joined that version. The computer-use connection was unavailable, so the live
   Studio Explorer/session could not be independently inspected.
3. In Explorer, confirm `StarterGui > Framewisp_CCVVMF > Be a Blender! Desktop`
   has **no Hotbar child**. Rojo normally removes the previously managed subtree.
   If an old imported copy remains, delete only its legacy `Hotbar` subtree.
   Older imports may put it under `DesktopContent` / `Be a Blender! DesktopContent`.
   The raw XML screen is named `Framewisp_RMMRUE`; Rojo renames the mapped root
   to `Framewisp_CCVVMF`. Check separately imported copies under either name.
   Keep the parent export, menus and all other screens. Remove an old
   `HotbarHost` under that Framewisp ScreenGui only if a saved/runtime copy persists.
   Do not put `BlenderHotbar` in StarterGui: the controller creates it under PlayerGui.
4. Start a fresh Play session. Under the local player's PlayerGui, verify exactly
   one `BlenderHotbar` with `ResetOnSpawn=false`, `ScreenInsets=CoreUISafeInsets`
   and no other visible legacy hotbar. No new Studio attributes/instances are
   required. Old running LocalScripts/module caches require a fresh session.
5. Publish once. Record the actual joined `game.PlaceVersion` from that published
   build (the admin report includes it) separately from the source commit.
   Run every acceptance scenario on that same published version.

For a controlled local-client fallback check, disable `PlayerGui.BlenderHotbar.Enabled`
(or temporarily set its Parent to nil while retaining a reference). Confirm native
Tool equip works. Re-enable/reattach that same root and confirm takeover. If you
permanently Destroy the root, native remains available; restart the client or
Destroy/Init HotbarController to create a fresh view.

The LF-normalized runtime source digest for this handoff is
`8b42dca171dbec11cefce17dcb923b12acfd7095c42dea2a306430a39cef40c0`.
It hashes, in order, path + NUL + contents + NUL for HotbarController, HotbarGui,
MobileControlLayout, init.client, default.project.json and the prepared export.
It identifies this working-tree implementation, not a Roblox place version.

| Release acceptance, same published build | Status |
| --- | --- |
| Repeated fresh portrait and fresh landscape as Eatandpoop with pre-plot Ice Gun: custom visible/tappable without rotation or commands; native pixels gone | PENDING |
| Fresh empty join, then late Ice Gun using test account/existing QA grant: custom takeover and tap equip | PENDING |
| Portrait → landscape → portrait while equipped, then respawn: one usable bar, control clearance, actual replacement Tools | PENDING |
| Nine slots on narrow phone: equip 1, swipe to 9 without snapping, tap fully visible slot 9 | PENDING |
| Disable/remove and restore custom view: native equip, then clean custom recovery | PENDING |
| Keyboard and physical controller smoke checks | PENDING |

Source revision actually synced: **PENDING, Collin to record**.
Published place version actually joined: **PENDING, Collin to record**.
Published-phone release acceptance: **PENDING**. CoreGui readback and green tests
support the investigation; actual visible bars and tap response decide acceptance.
