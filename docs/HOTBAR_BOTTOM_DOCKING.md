Hotbar bottom docking — 2026-11-04

Local inspection findings, recorded before the behavior description:

- Controller: `src/client/Controllers/HotbarController.luau`; resolver/metrics: `src/client/UI/HotbarGui.luau`. Both exist locally. `default.project.json` mounts `Framewisp_Hotbar.prepared.rbxmx` as `StarterGui.Framewisp_CCVVMF`; the serialized root is named `Framewisp_WYHWBJ`.
- Original `resize()` starts bottom at 12, then on touch takes `max(bottom, parent.AbsolutePosition.Y + parent.AbsoluteSize.Y - button.AbsolutePosition.Y + 8)` for every visible collected button. No horizontal intersection or bottom-zone test exists. Sprint, Throw, Ice Ray, and Jump each contribute their top edge unconditionally; whichever top is highest wins. Height was fixed at 96. The guards were parent width < 48, parent height < 120, or parent height < bottom + 108.
- Actual constants: `MIN_SLOT_WIDTH = 48`, `BAR_HEIGHT = 96`, `MAX_WIDTH = 960`. `BAR_HEIGHT` remains named and valued as before, now serving as the height cap.
- Actual CAS names are `SprintHeld`, `ThrowHeld`, `IceShotgunFire`, confirmed against their respective controllers and `MobileControlLayout`. Jump lookup is direct `playerGui:FindFirstChild("TouchGui")`, then every descendant named `JumpButton` that is a `GuiButton`. The thumbstick is deliberately outside this set.
- Bar parent: `Framewisp_WYHWBJ/Be a Blender! Desktop/Be a Blender! DesktopContent`. Both enclosing frames have size `(1,0,1,0)`, position `(0.5,0,0.5,0)`, anchor `(0.5,0.5)`. There is no authored bottom gap: content fills its ScreenGui coordinate area. The root serializes `ScreenInsets = 1` (DeviceSafeInsets), `SafeAreaCompatibility = 1` (FullscreenExtension), `ClipToDeviceSafeArea = true`, Enabled true, ResetOnSpawn false. `IgnoreGuiInset` is not serialized or assigned by the hotbar modules; its live value has not been measured. The physical-screen gap on an inset device remains PENDING Studio measurement; no numeric gap is fabricated and the parent is unchanged.
- Authored bar size is `(0.483333319,0,0.088888891,0)`, consistent with the HEAD-era dimensions. Saved local width remains the input to placement. Controller writes to bar anchor/position/size occur only in `resize()` and restoration in `release()`; setup saves them. No authored hierarchy or export was changed.
- `playerGui.DescendantAdded -> uiChanged -> schedule` already covers late TouchGui and CAS descendants. Removing descendants defers `uiChanged`. Existing coalescing is retained; tests cover late Jump/CAS additions, removal, and subsequent visibility changes. No new watch or timer was needed.
- The local tutorial uses `TutorialHintController -> AnnouncementBanner.Create`: label anchor `(0.5,0)`, resting position `(0.5,0.065)`, height 104, CoreUISafeInsets. It has no 132px bottom dock. It was inspected and left unchanged.
- The installed Roblox definitions declare two Vector2 returns for `GetGuiInset`. The [official API example](https://create.roblox.com/docs/reference/engine/classes/GuiService#GetGuiInset) names the second return `screenAreaBottomRight`. The implementation reads its Y component. The automated boundary explicitly returns distinct top `(0,36)` and bottom `(0,31)` values and verifies 31, plus a zero-bottom test verifying the 16px floor. Actual engine/device return values remain PENDING Studio; automated doubles are not a live build measurement. ScreenGui inset semantics were checked against [Roblox's ScreenGui documentation](https://create.roblox.com/docs/reference/engine/classes/ScreenGui#IgnoreGuiInset).

Changed files in this pass:

| File | Change |
|---|---|
| `src/client/Controllers/HotbarController.luau` | Docking/clearance, adaptive height, approved short-band label accommodation |
| `tests/hotbar.spec.luau` | Fake inset/control boundaries, two reproductions, viewport and clearance contracts |
| `tests/run_hotbar_tests.py` | Independent `dock-portrait`, `dock-landscape`, and `docking` selectors |
| `docs/HOTBAR_BOTTOM_DOCKING.md` | Inspection, formulas, validation, Studio acceptance |

Other modified Muncher/ingredient files were concurrent workspace work and were not edited by this pass. This is one working-tree diff; no commit or publication was made.

Placement implemented:

- Classification is recomputed every resize: touch first, otherwise gamepad, otherwise desktop. There are no viewport/device branches.
- Safe bottom: touch `max(16, secondInset.Y)` (maximum, not addition); gamepad `ceil(parentHeight * 0.05)`; desktop 12.
- Target height: `clamp(floor(parentHeight * 0.11 + 0.5), 64, BAR_HEIGHT)`. Nearest-pixel rounding gives the requested 93px at 844px. Guard rejects width < 48 or height < target + safe bottom + 12; release/native Backpack behavior is retained.
- Candidate width: `parentWidth * min(0.9, 960 / parentWidth, desiredWidth / parentWidth)`, where desired width uses saved authored X scale and offset. Center and candidate edges use parent AbsolutePosition/AbsoluteSize.
- Touch controls qualify only when Visible, bottom edge >= parent top + 0.6 * height, and their horizontally expanded interval intersects the candidate. Expansion is 8px on each side. Desktop/gamepad skip collection entirely.
- No overlap docks at the safe bottom. Otherwise allowed centered width is twice the distance from parent center to the near expanded control edge, with the minimum taken across overlaps. Left controls use `2 * (center - buttonRight - 8)`; right controls use `2 * (buttonLeft - 8 - center)`.
- Minimum usable width is `2 * 48 + gap`, with gap converted as `layout.Padding.Scale * candidateWidth + layout.Padding.Offset`; the scrolling host fills the bar. If the allowed width meets that minimum, shrink and dock; overflow stays in the canvas.
- Otherwise lift is `max(safeBottom, parentBottom - buttonTop + 8)` across overlapping bottom-zone controls only. If lift exceeds 35% of parent height, dock at minimum usable width and warn once per viewport size, naming the control and viewport. No capped or uncapped excessive lift is applied.
- Final anchor `(0.5,1)`, position `(0.5,0,1,-bottom)`, size `(finalWidth / parentWidth, targetHeight / parentHeight)`.

The original long-label sweep passed with the original 96px code but failed with the required 64px height and unchanged slot loop. Collin explicitly approved a focused label-layout fix during this pass. When text at the authored minimum cannot fit below the icon, the loop reserves label room by uniformly reducing the icon while retaining its top edge and aspect ratio, with at least 24px icon height. Saved authored icon geometry is restored each resize and on release. If it still cannot fit, the existing native fallback remains. No slot hit area or font minimum is reduced. The old tests are unchanged and pass; a new short-band long-label test checks separation, readability, aspect, and restoration. This approved exception is the only change to the slot loop beyond bar placement.

Stage A reproductions: before production editing, both independent commands below exited 1 with `non-overlapping right-edge control must not lift: 208 expected 16`. Landscape's 208px lift places the 96px bar around midscreen. Portrait also lifts 208px unnecessarily. Both now exit 0 with bottom 16. The fake authored width is 0.34 in portrait and 0.4 in landscape to guarantee zero overlap after the 8px expansion in both viewports; using the real 0.483333319 width at 390px slightly intersects a 100px right-edge control's expanded interval and correctly takes the shrink path instead. The fake left thumbstick is 120px wide and remains outside the approved collected control set.

Automated viewport results, no controls present (pixels are parent-space inputs):

| Viewport | Input classification | Bottom | Height | Result |
|---|---|---:|---:|---|
| Phone portrait 390x844 | Touch | 16 | 93 | PASS |
| Phone landscape 844x390 | Touch | 16 | 64 | PASS |
| Small phone landscape 740x360 | Touch | 16 | 64 | PASS |
| Tablet portrait 820x1180 | Touch | 16 | 96 | PASS |
| Tablet landscape 1180x820 | Touch | 16 | 90 | PASS |
| Narrow desktop 1024x768 | Desktop | 12 | 84 | PASS |
| Desktop 1920x1080 | Desktop | 12 | 96 | PASS |
| Console 1920x1080 | Gamepad | 54 | 96 | PASS |
| Console 1280x720 | Gamepad | 36 | 79 | PASS |

Every row also verifies anchor, authored/capped width, all 12 items retained, both 48px hit floors, slot aspect, selection links, and selected overflow scrolling. Additional contracts pass for left/right shrink in nonzero absolute parent coordinates, overlap-only lift, high/invisible controls, excessive-lift warning deduplication, insufficient dimensions/native restoration, late controls, and touch/gamepad/desktop transitions with touch winning hybrid input.

Exact validation commands (PowerShell, repository root):

```powershell
$out = 'C:\Users\COLLIN~1\AppData\Local\Temp\hotbar-docking-validation-f8916a81f0d941baa1d1cad3b3e639c4'
$rojo = 'C:\Users\Collin Van Meter\.aftman\tool-storage\rojo-rbx\rojo\7.7.0\rojo.exe'
python tests/run_hotbar_tests.py --luau .validation-tools/luau.exe --case dock-portrait
python tests/run_hotbar_tests.py --luau .validation-tools/luau.exe --case dock-landscape
python tests/run_hotbar_tests.py --luau .validation-tools/luau.exe --case docking
python tests/run_hotbar_tests.py --luau .validation-tools/luau.exe
.validation-tools/stylua.exe --check src/client/Controllers/HotbarController.luau tests/hotbar.spec.luau
& $rojo sourcemap default.project.json --output "$out/hotbar-sourcemap.json"
.validation-tools/luau-lsp.exe analyze --platform roblox --sourcemap "$out/hotbar-sourcemap.json" --definitions .validation-tools/globalTypes.d.luau src/client/Controllers/HotbarController.luau
& $rojo build default.project.json --output "$out/hotbar.rbxlx"
git diff --check -- src/client/Controllers/HotbarController.luau tests/hotbar.spec.luau tests/run_hotbar_tests.py docs/HOTBAR_BOTTOM_DOCKING.md
python tests/run_state_tests.py --luau .validation-tools/luau.exe
python tests/run_state_tests.py --luau .validation-tools/luau.exe --suite muncher
```

All hotbar commands, formatting, changed-runtime-module Roblox typecheck, fresh sourcemap, build, and whitespace check pass (exit 0). The complete hotbar run reports 1643 executed checks before its existing final weapon-pinning block, which also completes successfully. Tests compile/execute the real modules against doubles; the spec's injected fake environment is not a Roblox runtime module. The Aftman shim initially failed to find its home directory; using its installed Rojo binary directly resolved that. Raw final logs and the generated build are in `$out`, outside the delivered diff.

The full state-runner manifest exited 1: state 20/26, integration 52/69, presentation 36/46. These results are separate from the passing hotbar spec. An isolated source/test snapshot with the original hotbar reproduced these 32 unrelated failures:

| Group | Failing suites reproduced with original hotbar |
|---|---|
| State | ripeness, smoothie-world, smoothie, customer-validation, customer-compatibility, sprint |
| Integration | tutorial-claim, ingredient-cleanup, ripeness-lifecycle, discovery-customers, plot-session-races, plot-session-progression, plot-session-requests, plot-session, customer-queue, customer-serve-anywhere, legacy-state, legacy-movement, requests, world, smoothie-roundtrip, icegun-aim |
| Presentation | tutorial-hints, ripeness-presentation, jacked-noob-hit-presentation, bat-controller, ingredient-hold, vfx, customer-order-text, customer-orders, blend-presentation, icegun-presentation |

`muncher` was the 33rd failure during the first full run; concurrent unrelated work changed it, and it passes both the isolated comparison and a focused current rerun (72 behavioral checks, 68 setup validations). No unrelated production or test repair was made. The baseline comparison command was `python <snapshot>/tests/run_state_tests.py --luau C:/src/BlenderGame/BlenderGame/.validation-tools/luau.exe` with repeated `--suite <name>` for the 33 original failures. Snapshot path: `C:/Users/COLLIN~1/AppData/Local/Temp/hotbar-suite-baseline-rgq5wga3`. This comparison isolates this hotbar diff; it is not a claim that the concurrently modified workspace equals git HEAD. Logs are retained in `$out/hotbar-full-suite.log` and `$out/hotbar-baseline-suite.log`.

Stage B has not been run: no Studio emulator/viewport session was used. Each cell below is explicitly PENDING live verification. For every viewport, verify bottom docking/intended safe margin, authored ratios and unclipped labels, fully tappable uncovered touch controls where applicable, selected-slot scrolling, and tutorial separation. Console additionally needs real D-pad left/right selection verification.

| Studio viewport | Dock/safe margin | Ratios/labels | Touch tappability | Selected overflow | Tutorial overlap | D-pad |
|---|---|---|---|---|---|---|
| Phone portrait | PENDING | PENDING | PENDING | PENDING | PENDING | N/A |
| Phone landscape | PENDING | PENDING | PENDING | PENDING | PENDING | N/A |
| Tablet portrait | PENDING | PENDING | PENDING | PENDING | PENDING | N/A |
| Tablet landscape | PENDING | PENDING | PENDING | PENDING | PENDING | N/A |
| Narrow desktop | PENDING | PENDING | N/A | PENDING | PENDING | N/A |
| 16:9 desktop | PENDING | PENDING | N/A | PENDING | PENDING | N/A |
| Console 1080p | PENDING | PENDING | N/A | PENDING | PENDING | PENDING |

Static hint geometry has no overlap with the new dock at the simulated dimensions; visual overlap remains PENDING, including device insets. No tutorial movement or new Studio setup is required. Pending acceptance does not block review/landing of this diff.

Preserved contracts: Bat then Ice, ingredients by CarryItemId, smoothies first-seen; Tool-identity selection; clicks only equip/unequip with no remote; no new input-sinking listener; capacity only limits pickup; unlimited displayed slot pool with hidden unused slots; slot/icon aspect locks and flexible labels; template clearing, one intentional icon source, once-per-id fallback warning; 48px interactive floor and horizontal overflow; existing keyboard gating/cleanup (including the locally existing 0 binding); native Backpack handoff/restoration; persistent HUD outside UIRegistry.Panels; unchanged Selectable/focus and left/right selection links. Throw, swing, fire, inventory authority, and all excluded gameplay systems are untouched. The approved icon/label accommodation is recorded above rather than claimed as an unchanged slot loop.
