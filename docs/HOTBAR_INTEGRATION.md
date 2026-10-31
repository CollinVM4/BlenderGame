# Authored hotbar integration — 2026-10-30

Local branch: `feature/framewisp-hotbar`. No commit, merge, or publication was made.
The focused patch excludes the pre-existing Lucky Block and other local changes.

## Export and current runtime status

The source is the existing, unchanged `uiExport_103026.rbxmx`. Preparation writes
`Framewisp_Hotbar.prepared.rbxmx`, mounted at `StarterGui.Framewisp_CCVVMF` by
`default.project.json`. The export's internal ScreenGui name is `Framewisp_3WK7AK`.
Only this prepared file is mapped; the locally modified `Framewisp_CCWMF.rbxmx`
is preserved and no longer mounted by this project. No raw export is mounted.

Preparation uses the existing FramewispActions menu delegation and defaults the
four existing main panels to hidden. TOP, navigation and panel artwork are
preserved. The current export resolves all five upgrade rows and Cash through
the existing UpgradesGui resolver. Hotbar is not registered as a panel.

Actual direct hierarchy:

| Instance | Exported class | Result |
| --- | --- | --- |
| Be a Blender! Desktop | Frame | Active desktop discovery |
| Be a Blender! DesktopContent | CanvasGroup | Desktop content |
| Hotbar | Frame | Persistent HUD container |
| Slot1 (nine siblings) | Frame | **Incompatible: must be GuiButton** |
| Each Slot1/Label | TextLabel | Compatible text child |
| SlotIcon | Absent | Required ImageLabel for IngredientViewport |
| SlotSelected | Absent | Required GuiObject |
| SlotBackground | Absent | Required GuiObject |

**The native Backpack remains enabled. Custom selection is inactive, and the
unbound authored preview bar is hidden.** Required authoring correction: export
the actual slot roots as ImageButtons/TextButtons with all four compatible
children under each slot. Repeated sibling Slot1 names are supported. No
invisible button wrappers, replacement art, or placeholder ScreenGui were added.

The exported Hotbar size is `(0.483333319, 0, 0.088888891, 0)`, with position
`(0.509895861, 0, 0.949999988, 0)` and anchor `(0.5, 0.5)`. These are relative
values, not verified 928×96 runtime pixels. Its root retains the exported safe
inset/device-safe-area settings.

## Controller behavior behind validation

The controller initializes after CarryInputController. It observes Backpack,
current Character, Tool lifecycle/name/classification signals, and root changes;
events are deferred/coalesced rather than polled. Tool identity owns selection.
Ingredients use numeric CarryItemId order; smoothies retain per-instance first
observation sequence, followed by bat and ice ray. Invalid ingredient ordering
metadata pauses the custom UI and retains native inventory.

There is no capacity lookup or slot cap. Bindings and previews are reused for
unchanged Tools; excess bindings are hidden and cleaned, and a pristine complete
slot template supplies additional slots. Character removal clears old Tool
references and previews. Controller/PlayerGui teardown restores native inventory.

GuiButton.Activated only calls Humanoid EquipTool/UnequipTools after current
ownership checks. CAS 1–9/0 selects indices 1–10, with no CAS touch buttons;
textbox/menu/GameplayPaused guards apply. Horizontal SelectedObject relationships
support the same button activation path without assigning focus from other UI.
Native Backpack handoff occurs only after wiring and rendering, including an
empty first render. Failed handoff releases custom handlers and retries with a
bounded initialization delay; restoration also retries CoreGui initialization.

Layout uses `MIN_SLOT_WIDTH = 56` pixels and rejects measured targets below 48px.
It follows the authored width proportion, permits a wider phone band, caps width
at 960, uses a 96px fixed layout band, and anchors `(0.5, 1)` at bottom-center.
These are controller layout choices, not measured runtime export dimensions.
An ordinary authored container gains only a transparent horizontal ScrollingFrame
layout host; actual authored buttons/art move into it. Canvas sizing includes
spacing/padding. Selected/focused items scroll into view. On touch, the band sits
above the observed Jump and CAS controls used by MobileControlLayout; insufficient
space retains native inventory. This adaptation is dormant for the current export.

AnnouncementBanner currently rests at top scale Y=0.065. It has no bottom-dock
BOTTOM_OFFSET/132 constant in this checkout, so no hint-offset change was made.

IngredientViewport has 53 allowlisted IDs and consumes sanitized assets published
from ServerStorage.Ingredients into Shared.ScrapbookPreviewAssets. Actual asset
availability depends on the running place. Missing previews retain authored art
and warn once per ID. Live weapon/smoothie copies use Geometry.Clone's inert
geometry allowlist, FOV 35, Geometry.Distance, and direction `(1, 0.65, 1)`.
Fallbacks resolve image content from the current prepared hierarchy:

* Upgrades/UpgradeScroll/UpgradeList/BatCard/Isolated Wooden Baseball Bat 1 —
  ImageLabel, currently `rbxassetid://123758203701050`.
* Shop/ShopScroll/ShopList/Ice Gun/IceGunImage — ImageLabel, currently
  `rbxassetid://114860674836321`.

Those asset IDs are observations, not hardcoded controller constants. Smoothies
have no card fallback or blend metadata; their label stays `Smoothie`.

## Changed files

* `src/client/UI/HotbarGui.luau` — authored resolver/validation only.
* `src/client/Controllers/HotbarController.luau` — observation, rendering, selection and cleanup.
* `src/client/init.client.luau` — one Hotbar initialization line; existing local initialization preserved.
* `default.project.json` — single prepared-root mapping.
* `tools/prepare_framewisp_ui.py` — current source/output defaults; persistent Hotbar exclusion.
* `Framewisp_Hotbar.prepared.rbxmx` — generated prepared export.
* `tests/hotbar.spec.luau` and `tests/run_hotbar_tests.py` — real-module fake-boundary contracts.
* `tests/test_prepare_framewisp_ui.py` — current export/default CLI preparation contracts.
* `docs/HOTBAR_INTEGRATION.md` — this report.

The existing untracked raw export is an unchanged input dependency. All pre-existing
server code, inventory authority, pickup/capacity rules, throw/swing/fire handlers,
and PanelManager implementation remain unchanged.

## Validation

Tools reused from `$env:TEMP/BlenderGame-lucky-block-validation-20261030-1541a6c`:
Luau, StyLua, Luau LSP with Roblox definitions, and installed Rojo 7.7.0.
Logs, baseline snapshot and focused patch live in the temporary validation
directory recorded in `$env:TEMP/blender-hotbar-validation-path.txt`.

```powershell
$tools = "$env:TEMP/BlenderGame-lucky-block-validation-20261030-1541a6c"
$out = Get-Content "$env:TEMP/blender-hotbar-validation-path.txt"
$rojo = 'C:/Users/Collin Van Meter/.aftman/tool-storage/rojo-rbx/rojo/7.7.0/rojo.exe'
python -B tools/prepare_framewisp_ui.py --input uiExport_103026.rbxmx --output Framewisp_Hotbar.prepared.rbxmx
python -B tests/run_hotbar_tests.py --luau "$tools/luau/luau.exe"
python -B -m unittest discover -s tests -p test_prepare_framewisp_ui.py
python tests/run_state_tests.py --luau "$tools/luau/luau.exe" --suite carry-input --suite bat-controller --suite icegun-input --suite icegun-presentation
python tests/run_state_tests.py --luau "$tools/luau/luau.exe"
python "$out/baseline/tests/run_state_tests.py" --luau "$tools/luau/luau.exe"
& "$tools/stylua/stylua.exe" --check src/client/UI/HotbarGui.luau src/client/Controllers/HotbarController.luau src/client/init.client.luau tests/hotbar.spec.luau
& $rojo sourcemap -o "$out/sourcemap.json"
& "$tools/lsp/luau-lsp.exe" analyze --platform roblox --sourcemap "$out/sourcemap.json" --definitions "$tools/roblox.d.luau" src/client/UI/HotbarGui.luau src/client/Controllers/HotbarController.luau
$sourceFiles = Get-ChildItem src -Recurse -Filter '*.luau' | ForEach-Object { Resolve-Path -Relative $_.FullName }
& "$tools/lsp/luau-lsp.exe" analyze --platform roblox --sourcemap "$out/sourcemap.json" --definitions "$tools/roblox.d.luau" $sourceFiles
& $rojo build -o "$out/hotbar.rbxlx"
git diff --check
```

Results: 70 hotbar checks and all 16 preparation tests pass. Carry-input (36
behavioral checks) and icegun-input (147) pass. Bat-controller fails because its
fixture lacks CarryInputController's InputBegan signal; icegun-presentation fails
its live-renderer visibility assertion. Both reproduce on the incoming snapshot.
Full suite: 17/23 state, 48/64 integration, 33/43 presentation pass, identical to
baseline (98/130 pass, same 32 failures). No unrelated production fixes were made.
Focused typecheck, StyLua, Rojo build, and diff whitespace checks pass. Full-src
typecheck exits 1 with 39 unique diagnostics, identical by module/location/message
to baseline, in CombatService, CustomerService, JackedNoobService and CustomerRequests.

The incoming baseline includes the user's existing local changes, rather than
only HEAD. Raw export and old prepared asset bytes were verified unchanged.
Fake tests exercise the controller/resolver and IngredientViewport cleanup API,
not real engine viewport pixels, Tool.Activated routing, safe insets, or gamepad
hardware. Carry respects processed mouse input; ice checks GUI targets; bat
uses Tool.Activated. Engine click/touch fallthrough cannot be certified here,
and there is no usable authored custom button to test in the current export.
No protected gameplay input path or broad input suppression was changed.
