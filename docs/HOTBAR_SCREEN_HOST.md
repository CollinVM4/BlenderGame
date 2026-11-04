# Hotbar screen host (2026-11-04)

The hotbar now docks to a full-size Frame directly under its existing ScreenGui. Desktop and DesktopContent retain their authored geometry, aspect constraint and clipping. This is a code-only working-tree diff; no export, Figma, gameplay, Muncher, wings, TaskList, or other panel change is included.

## Changed files

| File | Change |
|---|---|
| `src/client/UI/HotbarGui.luau` | Find the marked hosted bar with ambiguity/active-desktop checks; resolve panel images independently from the bar parent; recognize existing slots inside HotbarScroll. |
| `src/client/Controllers/HotbarController.luau` | Create/recover the screen host, preserve authored geometry, roll back failed reparenting, observe host size, and restore the bar before destroying its owned host. |
| `tests/hotbar.spec.luau` | Extend the existing event-driven doubles with separate screen and letterboxed content geometry, host failures, rotation, discovery, stacking and release survival. Existing viewport tests now set Root pixels, the coordinate space actually used after this change. |
| `tests/run_hotbar_tests.py` | Add the independent `--case reparent` selector. |
| `docs/HOTBAR_SCREEN_HOST.md` | Local audit, results, exact validation commands and pending Studio acceptance. |

The pre-existing `MuncherEffects.luau`, `muncher_presentation.spec.luau` and `docs/muncher-roll-performance.md` workspace edits were left untouched.

## Step-0 audit of the local tree

Before this change, Find selected at most one active Registry desktop/root, then used Registry.Content and Registry.Child to find Hotbar. Resolve used bar.Parent for Upgrades, Shop and the CarryCapacity generic image. Setup cached Gui.Metrics for every authored slot, captured savedBar, created/reused its internal scrolling host, and bound the same slot buttons into that host. Render compared Find's Root/Bar identity and checked each button remained a descendant of Bar. Resize already used Bar.Parent.AbsoluteSize/AbsolutePosition. Release restored original slot parents and authored bar geometry, hid the bar and removed owned scrolling UI. These APIs and the render identity/descendant checks remain in place.

Actual values read from the mounted `Framewisp_Hotbar.prepared.rbxmx`:

| Property | Actual local value |
|---|---|
| ScreenGui | Framewisp_WYHWBJ, mounted as StarterGui.Framewisp_CCVVMF |
| ScreenGui ScreenInsets | token 1, DeviceSafeInsets |
| ScreenGui ClipToDeviceSafeArea | true |
| ScreenGui ZIndexBehavior | token 1, Sibling |
| Desktop Size / Position / AnchorPoint | (1,0,1,0) / (0.5,0,0.5,0) / (0.5,0.5) |
| Desktop aspect / AspectType / DominantAxis | 1.77777779 / token 0 FitWithinMaxSize / token 0 Width |
| Desktop ZIndex / ClipsDescendants | 1 / false |
| DesktopContent Size / Position / AnchorPoint | (1,0,1,0) / (0.5,0,0.5,0) / (0.5,0.5) |
| DesktopContent ZIndex / ClipsDescendants | 6 / true |
| Bar Size | (0.483333319,0,0.088888891,0) |
| Bar Position / AnchorPoint | (0.509895861,0,0.949999988,0) / (0.5,0.5) |
| Bar ZIndex / ClipsDescendants | 538 / false |

The local aspect is 1.77777779 rather than the request's rounded 1.777. No authored property changed. Since the local root uses Sibling stacking, HotbarHost takes the original content's ZIndex, 6; Bar retains 538. For a Global root the host retains its default ZIndex. The root already uses device safe insets, so the new host inherits the root's safe coordinate area. Bottom-inset calculations are unchanged, with no added inset subtraction. The 390x844 automated host is an explicit simulated coordinate area, not a measurement of a live physical phone's safe rectangle.

The tutorial remains owned by TutorialHintController/AnnouncementBanner and was not moved. Framewisp TextScaler remains under the same ScreenGui and scans its descendants, so the moved bar remains in its scan. Existing FW_TextOwn/FW_Scale handling is unchanged. Live text-size verification is pending Studio.

## Lifecycle and compatibility

`screenHost`, `ownedScreenHost`, and `originalBarParent` are distinct from the pre-existing `host` and `ownedHost` locals, which refer to the ScrollingFrame inside the bar. The new Frame has name HotbarHost, Size (1,1), Position (0,0), AnchorPoint zero, BackgroundTransparency 1, BorderSizePixel 0, Active false, ClipsDescendants false and Visible true. Its only UI child is the original bar; slot instances and Bar.ZIndex are preserved.

Setup order: compute/cache every slot's Metrics; retain the existing pristine template capture; capture savedBar and originalBarParent; create/configure the screen host; parent it to Root; move the original Bar; set HotbarReparented true; continue the existing scroll/layout/slot setup; connect both scroll AbsoluteSize and screenHost AbsoluteSize to schedule(). There is no metric cache clearing or post-move recomputation. Ordinary rotation changes neither instance identity nor cached design metrics.

Authored anchor/position/size are also retained as HotbarAuthoredAnchor/HotbarAuthoredPosition/HotbarAuthoredSize attributes on the owned host. A setup encountering an already hosted bar recovers its original content through Registry.Content, reads these authored values when available, and does not create a nested host. A host still owned by this controller can be reused with its existing saved state. A host supplied by another instance is not claimed or destroyed; placement continues against it, its size is watched, and a warning explains the skipped reparent. The scripted already-hosted test exercises content/geometry recovery and the no-duplicate-host guard.

Creation, configuration, parenting and marker assignment are protected. Failure restores the original parent before removing a partially created host, clears a partially assigned marker, warns once with the reason, and continues ordinary scroll setup/resize. The tests force creation, host parenting, bar parenting and marker failures independently. Reparent failure alone does not restore the native Backpack.

Release order: restore original slot buttons and clean existing layout/scroll resources; move Bar to its valid original parent; clear HotbarReparented; restore saved AnchorPoint/Position/Size; set Visible false; destroy the owned screen host only after the bar is outside it; clear screen-host state. Native Backpack restoration, unbinding, disconnections, pool and pristine cleanup retain their existing behavior. If the original UI parent has been removed, the safety guard does not destroy a host that still contains the bar; ordinary valid-parent teardown is covered by the bar-survival test.

Find retains the original active-desktop visibility/root gates. It recognizes only a marked Hotbar directly inside a direct HotbarHost child of that root. Content plus hosted copies, multiple hosted copies, and multiple content copies alongside a hosted copy fail rather than selecting an arbitrary bar. Existing ambiguous-active-desktop behavior is retained.

Resolve gets its panel content independently through the active desktop matching Root. To satisfy the requested Resolve-after-setup contract, slot collection also accepts children of the existing HotbarScroll (in addition to direct bar children). Slot validation, fallback requirements and image lookup rules are unchanged. This small extension is necessary because setup already reparents authored buttons into that scroll.

Resize itself is unchanged: target height round/clamp(11%,64,96), width cap 960, touch max(16, engine bottom inset), desktop 12, gamepad ceil(5% of parent height), existing shrink/lift logic, 35% lift cap and 48px hit floor. At 1080px height the gamepad bottom margin is **54px**, not the 96px stated in one Studio example in the request. Bar height is 96px.

## Automated results

All checks use the existing scripted Roblox doubles and the real resolver/controller modules; no new harness was introduced. They verify runtime contracts, not live engine layout or input rendering.

| Requested case | Result |
|---|---|
| Same bar/slot identity, unchanged ZIndex, cached Metrics, slot descendants | PASS |
| Find returns original Root/Bar after setup; next render retains custom UI | PASS |
| Hidden original Desktop / disabled Root | PASS independently; native Backpack restored |
| Content and hosted bar ambiguity; warning deduplication | PASS; additional multiple-content ambiguity guard passes |
| Resolve after setup retains Bat, Ice, generic images and slot instances | PASS |
| Release restores parent/geometry/visibility/marker, removes host, preserves bar and original buttons | PASS |
| 390x844 touch, content 390x219.375 | PASS: height 93, bottom 16, width 188.500 |
| 844x390 touch, content 693.333x390 | PASS: height 64, bottom 16, width 407.933 |
| 1920x1080 desktop | PASS: height 96, bottom 12, width 928.000 |
| 1920x1080 gamepad | PASS: height 96, bottom 54, width 928.000 |
| Rotation portrait to landscape and back, firing only host size notification | PASS: height/width/bottom recomputed, original host retained, no native fallback |
| Host creation failure / warning once / old resize continues | PASS |
| Host parent / bar parent / marker failure rollback | PASS independently; bar survives, no partial host or marker remains |
| Sibling / Global stacking rules | PASS independently |
| Release and subsequent setup / already-hosted recovery | PASS independently |
| Existing hotbar suite including viewport, controls, labels, selection and mounted-export coverage | PASS |

The width-cap check retains authored width as well as the 960px maximum; this export's 1920px-wide screen yields 928px. Existing broader viewport/cap cases remain in the hotbar suite. Touch overlap and engine inset doubles remain covered by that suite.

Exact final commands from repository root (PowerShell):

```powershell
$hotbarValidation = Join-Path $env:TEMP 'blender-hotbar-screen-host'
New-Item -ItemType Directory -Path $hotbarValidation -Force | Out-Null
$hotbarRojo = 'C:\Users\Collin Van Meter\.aftman\tool-storage\rojo-rbx\rojo\7.7.0\rojo.exe'
.validation-tools/stylua.exe --check src/client/UI/HotbarGui.luau src/client/Controllers/HotbarController.luau tests/hotbar.spec.luau
python tests/run_hotbar_tests.py --luau .validation-tools/luau.exe --case reparent
python tests/run_hotbar_tests.py --luau .validation-tools/luau.exe
& $hotbarRojo sourcemap default.project.json --output "$hotbarValidation/sourcemap.json"
.validation-tools/luau-lsp.exe analyze --platform roblox --sourcemap "$hotbarValidation/sourcemap.json" --definitions .validation-tools/globalTypes.d.luau src/client/UI/HotbarGui.luau src/client/Controllers/HotbarController.luau
& $hotbarRojo build default.project.json --output "$hotbarValidation/hotbar-screen-host.rbxlx"
git diff --check -- src/client/UI/HotbarGui.luau src/client/Controllers/HotbarController.luau tests/hotbar.spec.luau tests/run_hotbar_tests.py docs/HOTBAR_SCREEN_HOST.md
```

Results: focused reparent and complete hotbar suite pass; changed-module Roblox typecheck, StyLua, Rojo build and diff whitespace checks pass (exit 0). Luau LSP emits only its tool-level watched-files registration warning. No unrelated suites were run, per AGENTS.md's focused-validation rule. A fresh Rojo sourcemap is required; the committed validation sourcemap is stale and produces unknown-require errors. The generated source map and build are retained outside the delivered diff under the directory above. The build includes the existing concurrent workspace edits.

## Studio acceptance: pending, not completed

Computer use discovered the existing `Be a Blender! [ALPHA] - Roblox Studio` window. Initial capture failed with `FrameArrived timed out: timed out waiting on channel`; after refreshing window selection and activating Studio, capture failed again with `window capture timed out: timed out waiting on channel`. UI automation stopped after that recovery attempt. No build was opened in Studio and no live viewport was tested. No Studio acceptance result is claimed. Build prepared for acceptance: `%TEMP%/blender-hotbar-screen-host/hotbar-screen-host.rbxlx`, generated with Rojo 7.7 from this working tree. No authored Studio setup or export replacement is required. Populate the bar with at least one Tool before testing; an empty bar is intentionally hidden.

| Required Studio item | Result / check still required |
|---|---|
| 390x844 portrait touch | PENDING: device/safe-coordinate bottom, host-space target height, taps and selection |
| 844x390 landscape touch | PENDING: bottom dock, 64px height, touch-control clearance and taps |
| 1920x1080 tablet/desktop | PENDING: 12px bottom margin, 96px height, centered width at most 960px |
| 1920x1080 console/gamepad | PENDING: 54px bottom margin, 96px height, real selection/input |
| Portrait to landscape and back without respawn | PENDING: redocking and width/height changes, no native Backpack fallback |
| Settings, Shop and Upgrades | PENDING: unchanged panel behavior, stacking and label text size |
| Failure, character respawn and re-equip | PENDING: original bar survival, native Backpack during release, subsequent docking, no owned orphan host or duplicate bar |

Live acceptance remains outstanding. If docking fails, record the viewport and both HotbarHost and DesktopContent AbsoluteSize/AbsolutePosition, plus actual ScreenGui safe-coordinate dimensions, before judging the result. Automated double results do not establish real safe-area margins, CanvasGroup compositing, rendered stacking, font size, touch hit routing or respawn behavior.
