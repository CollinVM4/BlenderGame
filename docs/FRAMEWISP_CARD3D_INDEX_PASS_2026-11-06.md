# Card3D menu and Index title binding pass - November 6, 2026

Implemented Changes 1-3 against the local tree and saved `export116.rbxmx`. No commit, push, publish, Figma edit, re-export, Studio Play Solo, or live purchase was performed.

## Step 0 evidence

Read the local FramewispMenus, UIRegistry, ScrapbookPresentation, PanelManager, menu and Scrapbook specs, shared prepared-export loader, and November 5 binding report before editing. The prior binding pass remains in place. GitHub HEAD was not used as the implementation source.

Initial inspected source sizes (bytes; LF-normalized for clean tracked source files):

| File | Bytes |
| --- | ---: |
| src/client/UI/FramewispMenus.luau | 7810 |
| src/client/UI/UIRegistry.luau | 3259 (3362 on disk with CRLF) |
| src/client/UI/ScrapbookPresentation.luau | 16290 |
| src/client/UI/PanelManager.luau | 2770 |
| tests/framewisp_menus.spec.luau | 15643 |
| tests/scrapbook_ui.spec.luau | 21187 |
| tests/framewisp_export.py | 2861 on disk |
| docs/FRAMEWISP_BINDING_PASS_2026-11-05.md | 21950 on disk |

The supplied Studio observation (Collin, November 6, 12:52 ET) establishes the runtime path `PlayerGui.FramewispCard3D_LeftMenu.LeftMenu`, LeftMenu class CanvasGroup, Desktop's `LeftMenu_3DSlot`, RightMenu and direct panels, and absent DesktopContent. This pass did not independently operate Studio.

Local raw-export inspection corroborates the runtime mechanism:

```text
CanvasGroup Be a Blender! Desktop
  Frame TaskList
  CanvasGroup LeftMenu
  CanvasGroup RightMenu
  Frame TOP
  Frame Index
  Frame Upgrades
  Frame Settings
  Frame Shop
  Frame Hotbar
  UIAspectRatioConstraint UIAspectRatioConstraint
```

DesktopContent is absent. LeftMenu is authored under Desktop before the generated script moves it; the runtime slot is not an authored export child. The main export contains the FramewispCard3D LocalScript. Its exact root-name assignment is `sg.Name = "FramewispCard3D_" .. card.Name`, confirming the prefix in the supplied Studio path. Prepared FramewispActions has `local gui = script.Parent` and `local blenderMenus = menus.Attach(gui, player)`, under the main ScreenGui. No stop-condition mismatch was found.

Decoded raw-export attributes (nil means absent):

| Menu | Name | ClassName | FigmaAction | FigmaActionParam | BlenderUI |
| --- | --- | --- | --- | --- | --- |
| LeftMenu | Index | TextButton | open | Index | nil |
| LeftMenu | Upgrades | TextButton | open | Upgrades | nil |
| RightMenu | Shop | TextButton | open | Shop | nil |
| RightMenu | Settings | TextButton | open | Settings | nil |

Printed Index contract:

```text
Index/Header children:
  ImageLabel HeaderBackground
  Frame HeaderContent
Index/Header/HeaderContent children:
  TextLabel INDEX
  ImageButton Close
CardsViewport contains Frame IndexCardTemplate; its direct children:
  ImageLabel IndexCardTemplateBackground
  TextLabel IngredientValue
  TextLabel IngredientLabel
  TextLabel RarityLabel
  ImageLabel FruitImage
```

The saved raw export is now `export116.rbxmx` (1,638,205 bytes), and `newestExport11426.rbxmx` was already deleted on entry. Preparation used the current saved file explicitly; the prepare tool was not modified by this pass.

Initial git status, before this pass:

```text
 M Framewisp_Hotbar.prepared.rbxmx
 M docs/LUCKY_BLOCKS.md
 D newestExport11426.rbxmx
 M src/client/Controllers/HotbarController.luau
 M src/client/UI/HotbarGui.luau
 M src/client/UI/SettingsGui.luau
 M src/client/UI/UpgradesGui.luau
 M src/server/Services/LuckyBlockService.luau
 M src/shared/Constants/LuckyBlockConfig.luau
 M tests/hotbar.spec.luau
 M tests/lucky_block.spec.luau
 M tests/run_framewisp_menu_tests.py
 M tests/run_hotbar_tests.py
 M tests/run_settings_tests.py
 M tests/run_upgrade_ui_tests.py
 M tests/settings.spec.luau
 M tests/test_prepare_framewisp_ui.py
 M tests/upgrade_ui.spec.luau
 M tools/prepare_framewisp_ui.py
-- docs/FRAMEWISP_BINDING_PASS_2026-11-05.md
-- export116.rbxmx
-- tests/framewisp_export.py
```

Pre-existing Lucky Block changes are `docs/LUCKY_BLOCKS.md`, `src/server/Services/LuckyBlockService.luau`, `src/shared/Constants/LuckyBlockConfig.luau`, and `tests/lucky_block.spec.luau`. They were left as received, as were the prior binding changes. Nothing was staged or pushed.

## Files changed by this pass

| File | Change | Behavior |
| --- | --- | --- |
| src/client/UI/FramewispMenus.luau | 1 | Resolve unique active main content only for Card3D-hosted buttons; observe existing and newly created Card3D roots and their descendant additions/removals; retain guarded activation after reparenting and existing cleanup. Initialize panels only inside the main GUI. |
| src/client/UI/ScrapbookPresentation.luau | 2 | Resolve Header - HeaderContent - INDEX, falling back to Header - INDEX even when an empty wrapper exists. |
| tests/framewisp_menus.spec.luau | 3 | Existing/late/moved Card3D fixtures, real panel toggles and RightMenu compatibility, unrelated roots, ancestor-walk termination, late descendants, removal, reattachment, respawn and stop behavior. Mock ScreenGuis now default Enabled=true and expose ChildAdded. |
| tests/scrapbook_ui.spec.luau | 3 | Resolve the prepared wrapped title plus direct and empty-wrapper fallbacks; verify all counters use the authored label. Supply PlayerGui.ChildAdded at the test boundary. |
| tests/run_scrapbook_ui_tests.py | 3 | Replace nonexistent legacy export with shared Rojo-mapped prepared-export loader. |
| tests/framewisp_export.py | 3 | Missing-prepared-file message now instructs preparation from the actual saved export116.rbxmx. |
| tests/test_prepare_framewisp_ui.py | 3 | Read current export116.rbxmx for fixtures; retain isolated legacy default-input filename to test the unchanged tool's default behavior. Preserve prior binding-pass additions. |
| Framewisp_Hotbar.prepared.rbxmx | preparation | Regenerated from the current saved raw export with the unchanged prepare tool. |
| docs/FRAMEWISP_CARD3D_INDEX_PASS_2026-11-06.md | report | This evidence, validation and Studio handoff. |

The only deviations from the named files in the request were the necessary Scrapbook runner migration and preparation-fixture/missing-file-hint updates for the already-replaced raw export. No production hierarchy was guessed. Missing PlayerGui at Attach retains the old GUI-only guard and installs no sibling watchers; the real supplied runtime has PlayerGui. Existing Scrapbook lifecycle mocks also exercise the nil-PlayerGui path.

No changes were made to PanelManager, UIRegistry, the generated Card3D script, the prepare tool, HotbarGui/Controller, SettingsGui, UpgradesGui, or Shop adapters in this pass. No runtime UI elements were added. LeftMenu remains owned and tilted by the generated script.

## Validation

All commands below ran from the repository root after preparation. Each suite ran against the regenerated prepared file, not the missing legacy export.

```powershell
python -B tools/prepare_framewisp_ui.py --input export116.rbxmx --output Framewisp_Hotbar.prepared.rbxmx
python -B tests/run_framewisp_menu_tests.py --luau .validation-tools/luau.exe
python -B tests/run_scrapbook_ui_tests.py --luau .validation-tools/luau.exe
python -B tests/run_hotbar_tests.py --luau .validation-tools/luau.exe
python -B tests/run_settings_tests.py --luau .validation-tools/luau.exe
python -B tests/run_upgrade_ui_tests.py --luau .validation-tools/luau.exe
python -B -m unittest discover -s tests -p test_prepare_framewisp_ui.py
.validation-tools/stylua.exe src/client/UI/FramewispMenus.luau src/client/UI/ScrapbookPresentation.luau tests/framewisp_menus.spec.luau tests/scrapbook_ui.spec.luau
.validation-tools/stylua.exe --check src/client/UI/FramewispMenus.luau src/client/UI/ScrapbookPresentation.luau tests/framewisp_menus.spec.luau tests/scrapbook_ui.spec.luau
& 'C:/Users/Collin Van Meter/.aftman/tool-storage/rojo-rbx/rojo/7.7.0/rojo.exe' sourcemap default.project.json --output .validation-tools/card3d-pass.sourcemap.json
& 'C:/Users/Collin Van Meter/.aftman/tool-storage/rojo-rbx/rojo/7.7.0/rojo.exe' build default.project.json --output .validation-tools/card3d-pass.rbxlx
.validation-tools/luau-lsp.exe analyze --platform roblox --sourcemap .validation-tools/card3d-pass.sourcemap.json --definitions .validation-tools/globalTypes.d.luau src/client/UI/FramewispMenus.luau src/client/UI/ScrapbookPresentation.luau
.validation-tools/luau-lsp.exe analyze --platform roblox --sourcemap .validation-tools/card3d-pass.sourcemap.json --definitions .validation-tools/globalTypes.d.luau src/shared/Constants/CustomerRequests.luau
.validation-tools/luau-lsp.exe analyze --platform roblox --sourcemap .validation-tools/card3d-pass.sourcemap.json --definitions .validation-tools/globalTypes.d.luau src/client/UI/FramewispMenus.luau
git diff --exit-code -- src/shared/Constants/CustomerRequests.luau src/shared/Types.luau
git diff --check -- src/client/UI/FramewispMenus.luau src/client/UI/ScrapbookPresentation.luau tests/framewisp_menus.spec.luau tests/scrapbook_ui.spec.luau tests/run_scrapbook_ui_tests.py tests/test_prepare_framewisp_ui.py
```

| Check | Result |
| --- | --- |
| Framewisp menus | PASS, 1,462 checks. Card3D buttons open/close Upgrades and Index, moved buttons work, unrelated ScreenGuis cannot open panels, RightMenu remains functional. |
| Scrapbook UI | PASS: races, rendering, grid, replacement, lifecycle and exclusive navigation, plus wrapped/direct/empty-wrapper title counters. |
| Hotbar | PASS, 1,810 checks. |
| Settings/music | PASS, 195 checks. |
| Upgrades | PASS with UI present before Init both false and true, including purchase, wrapped export, semantic, badge and tutorial contracts. |
| Preparation | PASS, 18 unittest tests. |
| StyLua | PASS for all four changed Luau files. |
| Rojo sourcemap/build | PASS. |
| FramewispMenus typecheck | PASS, exit 0. |
| Combined changed-production typecheck | FAILED, exit 1: 22 existing CustomerRequests errors requiring DisplayText in Request. No diagnostics in either changed file. |
| Baseline error isolation | Analyzing unchanged CustomerRequests alone returns the exact same 22 TypeError diagnostic lines; CustomerRequests and Types have no git diff. No unrelated production code was changed. |
| Diff whitespace | PASS. |

Initial failures were resolved inside this pass: the mock lacked PlayerGui.ChildAdded; a synthetic title move needed to update the mock's child list; preparation fixtures referenced the deleted export. An exploratory StyLua check of the existing Scrapbook fixture showed pre-existing formatting differences; the temporary fixture edit was removed completely, the boundary signal moved to the spec, and all finally changed Luau files pass formatting. No broad gameplay suites were run. Pytest was not run; the repository's documented unittest fallback was used.

Prepared output: 1,639,440 bytes. Raw SHA-256: `8d8bdc8c9fca1d03de1e243cd657798d0422c5c97ef206276341d752a6da2504`. Prepared SHA-256: `c09b73a26a82f2c8e840c4e128f1615535d63e5da4414408fe7a832323ba04b2`.

The generated FramewispCard3D source has identical SHA-256 in raw and prepared exports: `bfe2b75dab23602bac2895793cf21e067816a59c4f3601910d18781f89763828`. The code change preserves the tilt implementation; visual tilt preservation is pending Studio acceptance. Generated build/sourcemap/baseline-log outputs were removed after validation.

## Studio acceptance - pending for Collin

1. Sync the newly prepared asset; restart Rojo if it predates the prepare write. Let Framewisp_CCVVMF update in place. Do not delete it.
2. Play Solo with one client. Toggle LeftMenu Upgrades and Index twice each. Index must show cards and INDEX discovered/total.
3. Toggle RightMenu Shop and Settings; verify X Close and menu exclusivity.
4. Confirm nine Hotbar slots, Settings issues limited to Knob/ProgressBar/Title, and all five Upgrades rows. Confirm no missing-target or ambiguous-panel warning.
5. Confirm LeftMenu retains its visible 3D tilt. This has not been visually verified by Codex.
6. Respawn: all menus must close.

Studio acceptance, visual tilt, and real input behavior are NOT RUN, not passed. No Figma changes were made.
