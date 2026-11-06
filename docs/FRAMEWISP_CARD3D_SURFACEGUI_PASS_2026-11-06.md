# Framewisp Card3D SurfaceGui correction - November 6, 2026

Card3D roots now accept SurfaceGui alongside ScreenGui, with the exact FramewispCard3D_ prefix still required. This corrects the prior pass's missed constructor and inaccurate ScreenGui-only fixture. No prepare run, re-export, Figma edit, commit, stage, push, or publish was performed.

## Step 0 evidence

Read local FramewispMenus, the complete menu spec, its runner, and docs/FRAMEWISP_CARD3D_INDEX_PASS_2026-11-06.md before editing. HEAD is 291dd5a. Initial `git status --short` produced no output: the tree was clean. The prior Lucky Block work is now included in HEAD; there were no uncommitted Lucky Block changes in this session. Its four previously identified files remain equal to HEAD.

Initial local sizes:

| File | Bytes |
| --- | ---: |
| src/client/UI/FramewispMenus.luau | 9633 |
| tests/framewisp_menus.spec.luau | 19620 |
| tests/run_framewisp_menu_tests.py | 2273 |
| docs/FRAMEWISP_CARD3D_INDEX_PASS_2026-11-06.md | 12328 |

Both `export116.rbxmx` and `Framewisp_Hotbar.prepared.rbxmx` contain this generated FramewispCard3D constructor:

```luau
local sg = Instance.new("SurfaceGui")
sg.Name = "FramewispCard3D_" .. card.Name
sg.ResetOnSpawn = false
sg.AlwaysOnTop = true
```

No third GUI root class was found in that script's GUI constructors. The same constructor creates the per-card root using card.Name. ScreenGui compatibility is retained as requested; the verified generated constructor is SurfaceGui.

Collin's supplied Play Solo evidence, November 6, 13:24 ET, is:

```text
Index button -> LeftMenu -> FramewispCard3D_LeftMenu (SurfaceGui)
             -> PlayerGui -> player -> Players -> DataModel
Content(desktop) = Desktop; no Content wrapper
ContentOf(button) = nil
Matches(LeftMenu, LeftMenu) = true
PanelId(button ancestors) = nil
PanelId(Index panel) = Index
```

At 13:20 ET, Wire returned false for Index and Upgrades despite one active desktop and the new mainContent implementation. This is supplied runtime evidence, not a Studio session operated by Codex. The local implementation matches its cause: isCard3DRoot checked ScreenGui only, wire's fallback ancestor walk stopped only on ScreenGui, and observeCard3D delegated to the same ScreenGui-only helper. The fixture constructed a ScreenGui at the Card3D root. The mock's `IsA` starts with `want == class`, so it already models SurfaceGui accurately without a helper rewrite. No stop condition occurred.

## Changes

Only these three files changed:

| File | Change |
| --- | --- |
| src/client/UI/FramewispMenus.luau | Change 1: accept ScreenGui or SurfaceGui in isCard3DRoot and the fallback ancestor walk. Prefix, mainContent, observer, activation guard, initialization, lookup and cleanup are unchanged. StyLua wraps the longer helper expression. |
| tests/framewisp_menus.spec.luau | Change 2: parameterize all existing/late/moved Card3D cases across SurfaceGui and ScreenGui; construct unrelated and wrong-prefix roots using each class. Preserve all existing panel toggling, RightMenu, descendant, removal, respawn, detach and stop checks. |
| docs/FRAMEWISP_CARD3D_SURFACEGUI_PASS_2026-11-06.md | This report. |

There is no BillboardGui or GuiBase2d catch-all. No generated script or authored UI was changed. Both raw and prepared exports were checked against HEAD and are unchanged. PanelManager, UIRegistry, ScrapbookPresentation, Hotbar, Settings, Upgrades, Shop adapters, and the prepare tool were left untouched.

## Fail-first reproduction

Added SurfaceGui fixtures while production still had the ScreenGui-only checks. Ran:

```powershell
python -B tests/run_framewisp_menu_tests.py --luau .validation-tools/luau.exe
```

Result: **expected FAIL**, exit 1, at:

```text
SurfaceGui existing navigation claimed: Upgrades
```

The failing assertion was `check(binding.Wire(buttons[id]), ...)`: Wire returned false on the first SurfaceGui Upgrades button, reproducing the observed runtime failure. Only after this run were the two production checks changed.

## Passing validation

Ran these commands from the repository root after the fix:

```powershell
.validation-tools/stylua.exe src/client/UI/FramewispMenus.luau tests/framewisp_menus.spec.luau
python -B tests/run_framewisp_menu_tests.py --luau .validation-tools/luau.exe
python -B tests/run_scrapbook_ui_tests.py --luau .validation-tools/luau.exe
python -B tests/run_hotbar_tests.py --luau .validation-tools/luau.exe
python -B tests/run_settings_tests.py --luau .validation-tools/luau.exe
python -B tests/run_upgrade_ui_tests.py --luau .validation-tools/luau.exe
python -B -m unittest discover -s tests -p test_prepare_framewisp_ui.py
.validation-tools/stylua.exe --check src/client/UI/FramewispMenus.luau tests/framewisp_menus.spec.luau
& 'C:/Users/Collin Van Meter/.aftman/tool-storage/rojo-rbx/rojo/7.7.0/rojo.exe' sourcemap default.project.json --output .validation-tools/card3d-pass.sourcemap.json
& 'C:/Users/Collin Van Meter/.aftman/tool-storage/rojo-rbx/rojo/7.7.0/rojo.exe' build default.project.json --output .validation-tools/card3d-pass.rbxlx
.validation-tools/luau-lsp.exe analyze --platform roblox --sourcemap .validation-tools/card3d-pass.sourcemap.json --definitions .validation-tools/globalTypes.d.luau src/client/UI/FramewispMenus.luau
git diff --check
```

| Check | Result |
| --- | --- |
| Menu gate | PASS, 1,534 checks (previously 1,462). Both root classes run all three orders; Index/Upgrades/Shop/Settings toggle; unrelated and wrong-prefix roots are rejected. |
| Scrapbook | PASS: races, rendering, grid, replacement, lifecycle and exclusive navigation. Runner emits no numeric count. |
| Hotbar | PASS, 1,810 contracts, plus docking/reparent regressions. |
| Settings/music | PASS, 195 checks. |
| Upgrades | PASS for initial UI absent and present. Each run reports 382 base, 400 export/lifecycle, 404 behavior, 443 reimport/duplicate and 453 purchase-feedback assertions, then semantic, badge and tutorial contracts. These are cumulative milestones, not additive totals. |
| Preparation | PASS, all 18 unittest tests. Temporary test outputs only; repository exports unchanged. |
| StyLua | PASS, both changed Luau files. |
| Rojo sourcemap/build | PASS. |
| Changed-file typecheck | PASS, exit 0; only environment warning about unsupported watcher registration. |
| Diff whitespace | PASS. |

No requested automated check was skipped. Broad unrelated gameplay suites and Studio acceptance were not run. The generated build and sourcemap artifacts were removed after validation.

## Studio handoff - pending for Collin

No prepare run is needed and no export changed. Restart Rojo if it predates the code change, sync, and Play Solo with one client.

1. Re-run the Wire snippet: Index and Upgrades must now return true.
2. Click LeftMenu Upgrades twice and Index twice; each panel must open then close. Verify Index cards and discovered/total title.
3. Click RightMenu Shop and Settings twice and a panel X Close; each must work.
4. Confirm LeftMenu still has its visible 3D tilt and no missing-panel-target or ambiguous-panel warning appears. Tilt implementation is unchanged; visual acceptance has not been performed by Codex.
5. Confirm Hotbar has nine slots, Settings only has Knob/ProgressBar/Title outstanding, and Upgrades has all five rows.
6. Respawn: all menus must close.

Nothing was staged or pushed. Collin handles pushing after reviewing git status.
