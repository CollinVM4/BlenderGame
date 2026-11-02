# Hotbar proportions, icons and number keys — 2026-11-02

Implementation diff is ready for review. Stage A automated checks pass; Stage B
Studio acceptance is **PENDING**. This builds on `HOTBAR_INTEGRATION.md`; its
description of the former incompatible export is historical.

## Local inspection before behavior changes

The local modules are `src/client/UI/HotbarGui.luau` and
`src/client/Controllers/HotbarController.luau`. Collin supplied
`newestExport.rbxmx` after inspection found the older exports incomplete. The new
source is unchanged by this pass (SHA-256 matches the incoming snapshot).
Preparation writes `Framewisp_Hotbar.prepared.rbxmx`, already mapped at
`StarterGui.Framewisp_CCVVMF` in `default.project.json`. Its internal ScreenGui
name is `Framewisp_WYHWBJ`; its design canvas attributes are 1920 × 1080.

The actual direct hierarchy is
`Be a Blender! Desktop/Be a Blender! DesktopContent/Hotbar/Slot1` (nine sibling
slots). Bindings use the existing tagged-child resolver and stripped/suffixed
name alternatives, including `Slot1_button_smooth`.

| Element | Actual class | Exported size, scale X/Y (offsets zero) | Position, scale X/Y | Other authored settings |
| --- | --- | --- | --- | --- |
| Hotbar | Frame | 0.483333319 / 0.088888891 | 0.509895861 / 0.949999988 | Anchor 0.5 / 0.5; about 928 × 96 design px |
| Slot1 | TextButton | 0.103448279 / 1 | X varies; Y 0.5 | Anchor 0.5 / 0.5; about 96 × 96 design px; real button, exported Sink enabled |
| SlotIcon | ImageLabel | 0.625 / 0.625 | 0.5 / 0.364583343 | About 60 × 60 design px; ScaleType 0 (Stretch) |
| SlotSelected | ImageLabel | 1 / 1 | 0.5 / 0.5 | ScaleType 0; authored artwork retained |
| SlotBackground | ImageLabel | 1 / 1 | 0.5 / 0.5 | ScaleType 0; each slot's authored artwork retained |
| Label | TextLabel | 1.5 / 0.0729166642 | 0.5 / 0.801281333 | About 144 × 7 design px; TextSize 8, FigmaFontSize 15, TextScaled false; FW_Scale 1 |
| Number | TextLabel | 0.114583336 / 0.135416672 | Varies per numeral | TextSize 12–14, FigmaFontSize 24; FW_Scale 1 |

No aspect constraints are exported under the slots. This is a Figma-fidelity
gap: runtime adds constraints to the slot root, icon host, and its viewport
render only. The measured slot and icon ratios are 0.9999999769 (1:1 within
export rounding). Label design ratio is about 20.5714; it is **not locked**.

All nine SlotIcon images contain the template **rbxassetid://99205963165985**.
Actual artwork observations from this source:

- BatCard/Isolated Wooden Baseball Bat 1: `rbxassetid://73374069906161`.
- Shop/ShopScroll/ShopList/Ice Gun/IceGunImage: `rbxassetid://114860674836321`.
- Intentional generic item fallback: Upgrades/UpgradeScroll/UpgradeList/
  CarryCapacityCard/Glossy Fruit Trio Sticker 1: `rbxassetid://136789729873472`.

These IDs are resolved from mounted instances, not hardcoded in runtime modules.

## Diagnosis and automated reproduction gate

Before changing runtime behavior, two independent harness probes failed:

- `--case aspect`: widths 320, 768, 1280, 1920 produced slot ratios
  0.636364, 0.636364, 0.700337, 1.090909. The expected authored ratio was 1:1.
- `--case template`: a full rebuild containing ingredient previews, a missing
  ingredient preview, smoothie, bat and ice ray retained **four** template images.

The relevant write/assignment paths were inspected:

| Element/path | Cause before this pass | Correction |
| --- | --- | --- |
| Controller.resize slot Size | Pixel width varied independently of height `1, -8` in a fixed 96 px band; no aspect constraint | Compute uniform size from measured authored ratio; write scale dimensions; apply a 48 × 48 UISizeConstraint floor |
| Controller.resize bar Size/Position | Existing 96 px docking band and viewport-dependent width; fixed minimum width widened phone bar | Retain docking/control avoidance; remove floor-driven widening; floor growth goes into horizontal canvas |
| Controller.setup list Padding | Added fixed 8 px gaps | Scale gap 8/928, matching authored design spacing; existing layout padding converted to scale |
| Icon host | Exported Stretch and no aspect constraint | Fit with authored aspect constraint; authored icon Size/Position retained |
| IngredientViewport.Create | Shared renderer made a sibling ViewportFrame; template remained below it | Clear host first, then move the single preview into the host, size to host, inherit its ratio |
| Tool-clone visual | Also made a sibling render over the template | Single child render in cleared host, same sanitized Geometry.Clone/Distance/FOV/camera pipeline |
| Ingredient preview failure | Did not try Tool geometry; returned to template | Try Tool geometry before card artwork or intentional fallback |
| Bat/ice artwork assignment | Existing card fallback assigned Image, but initial template could still appear | Every pooled host cleared synchronously before deferred first render; every rebind clears its prior source |
| Smoothie/missing preview or card | Unassigned Image path silently retained template | Deliberate fruit-trio fallback plus warning once per missing ID/kind |
| clearBinding | Restored OriginalImage, resurrecting template | Leave host empty and button hidden; dispose/remove previous render sources |
| Label | Bind only wrote Text; 150% width and short fixed proportional height could spill/shrink; generated Framewisp scaler could overwrite text sizing | Flexible scaled bounds inside slot, wrapping, TextScaled, authored min/max constraints, FW_TextOwn handoff; no label aspect constraint |
| Number | Authored numeral survived slot reorder/cloning | Update current 1–9/0 labels and hide later numbers; flexible bounds and authored text limits |
| Controller.setup CAS binding | Registered before render/native handoff, despite callback enabled guard | Register only after completed render and successful native Backpack hide; one action carrying all ten keyboard keys |

Preparation stamps only `HotbarTextMin`/`HotbarTextMax` metadata onto authored
Label/Number instances, preserving all original attributes. This retains the
exported text bounds even if Framewisp's responsive script runs before controller
startup. It does not rewrite slot artwork, sizes, positions, classes or scripts
beyond the existing menu delegation hook.

## Resulting behavior and limits

Both dimensions of the interactive slot button stay at least 48 px. For example,
a synthetic 2:1 authored slot uniformly grows to 96 × 48, rather than stretching
to 48 × 48. Slot sizes use scale; the pixel minimum exists on the button's
UISizeConstraint. The button itself remains the hit area. Icon artwork may be
smaller. Text layout can grow a button uniformly within the existing docking
band to fit its authored minimum; the scrolling canvas absorbs its width.

The bar keeps its authored width fraction (capped to existing safe bounds and
960 px), independent of slot count/floor. Horizontal canvas width includes each
occupied button's hit area and scaled gaps. Selection/focus still scrolls into
view. The existing 96 px docking band, bottom placement, touch-control avoidance,
and inherited ScreenGui safe-inset settings remain in use. Scrollbar space is
reserved vertically. A layout that cannot fit safely retains native inventory.

Labels wrap inside the slot without aspect constraints. Main label limits are
8–15 px from this export; number limits are each authored 12–14 px minimum up to
24 px. Their measured minimum text must fit before custom handoff proceeds.
Authored measurements are cached per button so teardown/reactivation does not
derive new ratios from an already adapted layout.

One icon host has one source at a time: allowlisted IngredientViewport preview,
then sanitized Tool-clone preview, then bat/ice card art, then the intentional
fruit-trio artwork. Before each rebind the prior source is removed. Successful
previews leave Image empty. The mounted-export mixed-bar test observes **zero
visible template images** and exactly one source per occupied slot. Missing
fallback artwork or an attempted template-as-fallback fails resolution.
Live asset loading/permissions still require Studio confirmation.

The source audit found no other client 1–9/0 bindings. CAS uses
createTouchButton=false. Keys map to current visible view order and call the
same selectTool function as Activated. TextBox focus, MenuIsOpen, GameplayPaused,
missing index, dead humanoid and removed/stale Tool guards apply. Rebuilds reuse
one action. Resolution/handoff failure, character removal, root loss and
controller teardown unbind it; respawn activates it once after rendering.

Preserved contracts: CarryItemId ingredient ordering, smoothie first-seen order,
then bat and ice ray; selection by equipped Tool identity; equip/unequip-only
clicks and keys with no gameplay remotes; pickup capacity never limits displayed
items; nine authored slots are a preview, with clones beyond nine; empty slots
hidden; persistent HUD outside UIRegistry.Panels. Throw, fire and swing handlers,
server inventory/rewards, panel management and native-backpack restoration paths
are unchanged. No input-sinking listeners or Active=false subtree workarounds
were added. Engine click-through routing is a pending Studio smoke check.

## Stage B acceptance

Studio process 30216 had MainWindowHandle=0 and no accessible emulator window.
No Studio viewport or live key/chat check was performed.

| Viewport | Automated layout/input model | Studio acceptance |
| --- | --- | --- |
| Phone portrait, 320 × 568 | Passed | **PENDING** |
| Tablet, 768 × 1024 | Passed | **PENDING** |
| Narrow desktop, 800 × 600 | Passed | **PENDING** |
| 16:9 desktop, 1920 × 1080 | Passed | **PENDING** |
| Console, 1080p | Passed (1920 × 1080 layout model) | **PENDING** |

For each viewport, verify actual slot/icon proportions, readable unclipped text,
both hit-area dimensions at floor, safe bounds, scrolling and selected-slot
reveal. Verify 1–9/0 with native Backpack hidden, empty index, chat/menu/pause
guards, click-equipped-to-unequip, no throw/fire/swing on slot activation, and
rebuild/respawn cleanup. The fake font metrics test complete text layout at
authored minimums, including a long player-head name; they do not rasterize
Roblox glyphs or establish live text readability.

Collin handoff: swap the slot template's default image in Figma to blank/transparent so future Framewisp exports do not reintroduce it; runtime clearing does not depend on this step.

## Files in this pass

- `src/client/UI/HotbarGui.luau`: measured authored ratios/text bounds, flexible
  text setup, template capture/clearing and intentional fallback resolution.
- `src/client/Controllers/HotbarController.luau`: ratio/floor/scroll layout,
  single-source icon lifecycle and activation-gated keyboard lifecycle.
- `tools/prepare_framewisp_ui.py`: authored text-bound metadata; retains the
  already selected newestExport input and existing preparation policy.
- `Framewisp_Hotbar.prepared.rbxmx`: generated mounted export from newestExport.
- `tests/run_hotbar_tests.py`: mounted project asset/properties/metadata and
  independent reproduction probes.
- `tests/hotbar.spec.luau`: reproduction, mounted-export, layout, source,
  fallback, key mapping and lifecycle contracts, retaining prior gameplay cases.
- `tests/test_prepare_framewisp_ui.py`: current source fixture and preserved
  authored text-bound contracts.
- `docs/HOTBAR_ASPECT_IMAGES_KEYS.md`: this report.

Other incoming workspace changes, including wings/server work, are outside this
pass. No commit, merge or publication was made. Existing main working-tree diff
is used; no unrelated changes were staged or reverted.

## Commands and results

Validation artifacts/snapshot/logs:
`C:/Users/COLLIN~1/AppData/Local/Temp/blender-hotbar-rev3-9qdm88h0`.
Tool versions come from the repository's previously used local tool cache.

```powershell
$tools = "$env:TEMP/BlenderGame-lucky-block-validation-20261030-1541a6c"
$out = "$env:TEMP/blender-hotbar-rev3-9qdm88h0"
$luau = "$tools/luau/luau.exe"
$rojo = 'C:/Users/Collin Van Meter/.aftman/tool-storage/rojo-rbx/rojo/7.7.0/rojo.exe'

python -B tools/prepare_framewisp_ui.py --input newestExport.rbxmx --output Framewisp_Hotbar.prepared.rbxmx
python -B tests/run_hotbar_tests.py --luau $luau --case aspect
python -B tests/run_hotbar_tests.py --luau $luau --case template
python -B tests/run_hotbar_tests.py --luau $luau
python -B -m unittest discover -s tests -p test_prepare_framewisp_ui.py
& "$tools/stylua/stylua.exe" --check src/client/UI/HotbarGui.luau src/client/Controllers/HotbarController.luau tests/hotbar.spec.luau
& $rojo sourcemap -o "$out/sourcemap.json"
& "$tools/lsp/luau-lsp.exe" analyze --platform roblox --sourcemap "$out/sourcemap.json" --definitions "$tools/roblox.d.luau" src/client/UI/HotbarGui.luau src/client/Controllers/HotbarController.luau
& $rojo build -o "$out/hotbar.rbxlx"
python -B tests/run_state_tests.py --luau $luau
python -B "$out/baseline/tests/run_state_tests.py" --luau $luau
git diff --check -- src/client/UI/HotbarGui.luau src/client/Controllers/HotbarController.luau tools/prepare_framewisp_ui.py Framewisp_Hotbar.prepared.rbxmx tests/run_hotbar_tests.py tests/hotbar.spec.luau tests/test_prepare_framewisp_ui.py docs/HOTBAR_ASPECT_IMAGES_KEYS.md
```

Preparation, both post-fix probes, hotbar spec, all 17 preparation tests, focused
typecheck, StyLua, Rojo build and scoped whitespace checks pass. Post-fix ratio
sweep is 0.9999999769 at every width; template rebuild count is zero. Hotbar
checks cover the mounted export, non-square ratios, all ten keyboard mappings,
guards, stale items, intentional fallback warning deduplication, geometry
fallback, rebind cleanup, overflow, initial failure, teardown and respawn.

The requested full suite fails identically on the incoming snapshot and current
tree: state 20/26, integration 53/69, presentation 35/45. All 140 result entries
match; the same 32 pre-existing failures were left untouched:

- State: ripeness, smoothie-world, smoothie, customer-validation,
  customer-compatibility, sprint.
- Integration: tutorial-claim, muncher-vacuum, ingredient-cleanup,
  ripeness-lifecycle, discovery-customers, plot-session-races,
  plot-session-progression, plot-session-requests, plot-session, customer-queue,
  customer-serve-anywhere, legacy-state, legacy-movement, requests, world,
  smoothie-roundtrip.
- Presentation: tutorial-hints, ripeness-presentation, jacked-noob-hit-presentation,
  bat-controller, ingredient-hold, vfx, customer-order-text, customer-orders,
  blend-presentation, icegun-presentation.

The suite categories remain separated; presentation failures do not block the
authoritative focused hotbar checks. No unrelated production fixes were made.
