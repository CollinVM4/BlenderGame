# Framewisp binding pass ? November 5, 2026

Implemented Changes 1?6 against the local B3TZAA export. Hotbar binds the shipped backgrounds with optional Selected; Settings binds through its wrappers and maps Locked to Closed; all five Upgrades rows bind through their verified wrappers. UpgradesController is unchanged and its tests pass in both initial-UI states. No UI element was created in production code, no Figma/export operation was performed, and nothing was committed, pushed, or published.

## Step 0 evidence

Inspected both local files and UIRegistry before editing. At inspection:

| File | Bytes | Modified (America/New_York) |
| --- | ---: | --- |
| newestExport11426.rbxmx | 1,616,553 | 2026-11-05 17:02:39.103054 -05:00 |
| Framewisp_Hotbar.prepared.rbxmx | 1,617,804 | 2026-11-05 17:03:14.771401 -05:00 |

The raw and prepared files had identical classes, names, referents, and parent-child relationships across 645 instances. All required Step 0 path checks matched; no stop condition occurred. All five card wrappers use the verified card-name-plus-Content spelling. The duplicate PLOT Titles have different text but remain ambiguous by the exact-name contract; neither is selected by text or order.

The prepared file was explicitly regenerated from this raw export before testing:

```powershell
python tools/prepare_framewisp_ui.py --input newestExport11426.rbxmx --output Framewisp_Hotbar.prepared.rbxmx
```

The complete inspected subtrees follow. Repeated Slot1 entries are distinct authored instances, in XML order.

Hotbar (direct child of Be a Blender! Desktop):

```text
Frame Hotbar
  TextButton Slot1
    ImageLabel Slot1Background
    ImageLabel SlotIcon
    TextLabel Label
      UIScale FW_Scale
        NumberValue k_text
    TextLabel Number
      UIStroke UIStroke
      UIScale FW_Scale
        NumberValue k_text
  TextButton Slot1
    ImageLabel Slot1Background
    ImageLabel SlotIcon
    TextLabel Label
      UIScale FW_Scale
        NumberValue k_text
    TextLabel Number
      UIStroke UIStroke
      UIScale FW_Scale
        NumberValue k_text
  TextButton Slot1
    ImageLabel Slot1Background
    ImageLabel SlotIcon
    TextLabel Label
      UIScale FW_Scale
        NumberValue k_text
    TextLabel Number
      UIStroke UIStroke
      UIScale FW_Scale
        NumberValue k_text
  TextButton Slot1
    ImageLabel Slot1Background
    ImageLabel SlotIcon
    TextLabel Label
      UIScale FW_Scale
        NumberValue k_text
    TextLabel Number
      UIStroke UIStroke
      UIScale FW_Scale
        NumberValue k_text
  TextButton Slot1
    ImageLabel Slot1Background
    ImageLabel SlotIcon
    TextLabel Label
      UIScale FW_Scale
        NumberValue k_text
    TextLabel Number
      UIStroke UIStroke
      UIScale FW_Scale
        NumberValue k_text
  TextButton Slot1
    ImageLabel Slot1Background
    ImageLabel SlotIcon
    TextLabel Label
      UIScale FW_Scale
        NumberValue k_text
    TextLabel Number
      UIStroke UIStroke
      UIScale FW_Scale
        NumberValue k_text
  TextButton Slot1
    ImageLabel Slot1Background
    ImageLabel SlotIcon
    TextLabel Label
      UIScale FW_Scale
        NumberValue k_text
    TextLabel Number
      UIStroke UIStroke
      UIScale FW_Scale
        NumberValue k_text
  TextButton Slot1
    ImageLabel Slot1Background
    ImageLabel SlotIcon
    TextLabel Label
      UIScale FW_Scale
        NumberValue k_text
    TextLabel Number
      UIStroke UIStroke
      UIScale FW_Scale
        NumberValue k_text
  TextButton Slot1
    ImageLabel Slot1Background
    ImageLabel SlotIcon
    TextLabel Label
      UIScale FW_Scale
        NumberValue k_text
    TextLabel Number
      UIStroke UIStroke
      UIScale FW_Scale
        NumberValue k_text
```

Settings (direct child of Be a Blender! Desktop):

```text
Frame Settings
  Frame UpgradesPanelArtwork
    ImageLabel Background
      UIStroke UIStroke
    Frame Background
      UIGradient UIGradient
      UIStroke UIStroke
  Frame MUSIC
    ImageLabel MUSICBackground
    Frame MUSICContent
      TextButton MusicOff
        ImageLabel MusicOffBackground
        ImageLabel Music OFF
      TextButton MusicOn
        ImageLabel MusicOnBackground
        ImageLabel Music ON White
      TextLabel Title Text='MUSIC'
        UIStroke UIStroke
        UIScale FW_Scale
          NumberValue k_text
      TextLabel Title Text='ON / OFF'
        UIStroke UIStroke
        UIScale FW_Scale
          NumberValue k_text
      Frame Slider
        ImageLabel SliderBackground
      TextLabel Title Text='MASTER VOLUME'
        UIStroke UIStroke
        UIScale FW_Scale
          NumberValue k_text
  Frame PLOT
    ImageLabel PLOTBackground
    CanvasGroup PLOTContent
      TextButton Kick
        ImageLabel KickBackground
        TextLabel BuyLabel
          UIStroke UIStroke
          UIScale FW_Scale
            NumberValue k_text
      TextButton Rename
        ImageLabel RenameBackground
        TextLabel BuyLabel
          UIStroke UIStroke
          UIScale FW_Scale
            NumberValue k_text
        Frame RenameIcon
          Frame layer-MC0
            Frame Clip path group
              Frame Clip path groupMask
        ImageLabel Golden edit pencil UI icon 1
      TextButton Open
        ImageLabel OpenBackground
        TextLabel BuyLabel
          UIStroke UIStroke
          UIScale FW_Scale
            NumberValue k_text
      TextButton Locked
        ImageLabel LockedBackground
        TextLabel BuyLabel
          UIStroke UIStroke
          UIScale FW_Scale
            NumberValue k_text
      TextButton Friends
        ImageLabel FriendsBackground
        TextLabel BuyLabel
          UIStroke UIStroke
          UIScale FW_Scale
            NumberValue k_text
      TextLabel Title Text='TEAM & PLOT'
        UIStroke UIStroke
        UIScale FW_Scale
          NumberValue k_text
      TextLabel Title Text='Who can join..?'
        UIStroke UIStroke
        UIScale FW_Scale
          NumberValue k_text
  Frame Header
    ImageLabel HeaderBackground
    Frame HeaderContent
      TextLabel SETTINGS
        UIStroke UIStroke
        UIScale FW_Scale
          NumberValue k_text
      ImageButton Close
        UICorner UICorner
        UIStroke UIStroke
```

Upgrades (direct child of Be a Blender! Desktop):

```text
Frame Upgrades
  Frame UpgradesPanelArtwork
    ImageLabel Background
      UIStroke UIStroke
    ImageLabel Background
  Frame Header
    ImageLabel HeaderBackground
    Frame HeaderContent
      TextLabel UPGRADES
        UIStroke UIStroke
        UIScale FW_Scale
          NumberValue k_text
      ImageButton Close
        UICorner UICorner
        UIStroke UIStroke
  ScrollingFrame UpgradeScroll
    Frame UpgradeList
      Frame SprintStaminaCard
        ImageLabel SprintStaminaCardBackground
        Frame SprintStaminaCardContent
          TextButton Buy
            ImageLabel BuyBackground
            Frame BuyBackground
              UICorner UICorner
              UIStroke UIStroke
            TextLabel BuyLabel
              UIStroke UIStroke
              UIScale FW_Scale
                NumberValue k_text
          TextLabel PurchasePrice
            UIStroke UIStroke
            UIScale FW_Scale
              NumberValue k_text
          Frame LevelContainer
            ImageLabel LevelContainerBackground
            ImageLabel Arrow
            TextLabel NextValue
              UIStroke UIStroke
              UIScale FW_Scale
                NumberValue k_text
            TextLabel CurrentValue
              UIStroke UIStroke
              UIScale FW_Scale
                NumberValue k_text
          TextLabel UpgradeTitle
            UIStroke UIStroke
            UIScale FW_Scale
              NumberValue k_text
          ImageLabel Glossy Block Runner in Motion 1
      Frame CarryCapacityCard
        ImageLabel CarryCapacityCardBackground
        CanvasGroup CarryCapacityCardContent
          TextButton Buy
            ImageLabel BuyBackground
            Frame BuyBackground
              UICorner UICorner
              UIStroke UIStroke
            TextLabel BuyLabel
              UIStroke UIStroke
              UIScale FW_Scale
                NumberValue k_text
          TextLabel PurchasePrice
            UIStroke UIStroke
            UIScale FW_Scale
              NumberValue k_text
          Frame LevelContainer
            ImageLabel LevelContainerBackground
            ImageLabel Arrow
            TextLabel NextValue
              UIStroke UIStroke
              UIScale FW_Scale
                NumberValue k_text
            TextLabel CurrentValue
              UIStroke UIStroke
              UIScale FW_Scale
                NumberValue k_text
          TextLabel UpgradeTitle
            UIStroke UIStroke
            UIScale FW_Scale
              NumberValue k_text
          TextLabel +
            UIStroke UIStroke
            UIScale FW_Scale
              NumberValue k_text
          ImageLabel Glossy Fruit Trio Sticker 1
      Frame MovementSpeedCard
        ImageLabel MovementSpeedCardBackground
        Frame MovementSpeedCardContent
          TextButton Buy
            ImageLabel BuyBackground
            Frame BuyBackground
              UICorner UICorner
              UIStroke UIStroke
            TextLabel BuyLabel
              UIStroke UIStroke
              UIScale FW_Scale
                NumberValue k_text
          TextLabel PurchasePrice
            UIStroke UIStroke
            UIScale FW_Scale
              NumberValue k_text
          Frame LevelContainer
            ImageLabel LevelContainerBackground
            ImageLabel Arrow
            TextLabel NextValue
              UIStroke UIStroke
              UIScale FW_Scale
                NumberValue k_text
            TextLabel CurrentValue
              UIStroke UIStroke
              UIScale FW_Scale
                NumberValue k_text
          TextLabel UpgradeTitle
            UIStroke UIStroke
            UIScale FW_Scale
              NumberValue k_text
          ImageLabel Electric Blue Speed Sneaker 1
      Frame BatCard
        ImageLabel BatCardBackground
        CanvasGroup BatCardContent
          TextButton Buy
            ImageLabel BuyBackground
            Frame BuyBackground
              UICorner UICorner
              UIStroke UIStroke
            TextLabel BuyLabel
              UIStroke UIStroke
              UIScale FW_Scale
                NumberValue k_text
          TextLabel PurchasePrice
            UIStroke UIStroke
            UIScale FW_Scale
              NumberValue k_text
          Frame LevelContainer
            ImageLabel LevelContainerBackground
            ImageLabel Arrow
            TextLabel NextValue
              UIStroke UIStroke
              UIScale FW_Scale
                NumberValue k_text
            TextLabel CurrentValue
              UIStroke UIStroke
              UIScale FW_Scale
                NumberValue k_text
          TextLabel UpgradeTitle
            UIStroke UIStroke
            UIScale FW_Scale
              NumberValue k_text
          ImageLabel Isolated Wooden Baseball Bat 1
          ImageLabel BatAlert
      Frame JumpCard
        ImageLabel JumpCardBackground
        CanvasGroup JumpCardContent
          TextButton Buy
            ImageLabel BuyBackground
            Frame BuyBackground
              UICorner UICorner
              UIStroke UIStroke
            TextLabel BuyLabel
              UIStroke UIStroke
              UIScale FW_Scale
                NumberValue k_text
          TextLabel PurchasePrice
            UIStroke UIStroke
            UIScale FW_Scale
              NumberValue k_text
          Frame LevelContainer
            ImageLabel LevelContainerBackground
            ImageLabel Arrow
            TextLabel NextValue
              UIStroke UIStroke
              UIScale FW_Scale
                NumberValue k_text
            TextLabel CurrentValue
              UIStroke UIStroke
              UIScale FW_Scale
                NumberValue k_text
          TextLabel UpgradeTitle
            UIStroke UIStroke
            UIScale FW_Scale
              NumberValue k_text
          ImageLabel Jump1Alert
          ImageLabel Glossy Cyan Power-Up Arrow 4
          ImageLabel Glossy Cyan Power-Up Arrow 3
```

Counts in the raw export:

| Scope | Name | Count |
| --- | --- | ---: |
| Hotbar | SlotSelected | 0 |
| Hotbar | Slot1Selected | 0 |
| Hotbar | SlotBackground | 0 |
| Hotbar | Slot1Background | 9 |
| MUSIC | Knob | 0 |
| MUSIC | ProgressBar | 0 |
| PLOTContent | Title (TextLabel) | 2 |

PLOTContent Title text: `TEAM & PLOT` and `Who can join..?`.

Verified fallback paths relative to Desktop:

```text
Upgrades/UpgradeScroll/UpgradeList/CarryCapacityCard/CarryCapacityCardContent/Glossy Fruit Trio Sticker 1
Upgrades/UpgradeScroll/UpgradeList/BatCard/BatCardContent/Isolated Wooden Baseball Bat 1
Shop/ShopScroll/ShopList/Ice Gun/Ice GunContent/IceGunImage
```

All three images have nonempty Image values. Bat and Ice also needed their verified content wrapper in the Hotbar fallback helper; no Shop adapter was changed.

## SlotSelected history

Searched all reachable Git histories for checked-in .rbxmx files, parsing 24 distinct export blobs and checking named instances under Hotbar. Commit `90b0de40a4ddf4438089ffb0fe49da4cd4ff4469`, committed **2026-11-02 18:35:07 -05:00**, contains nine `SlotSelected` instances under Hotbar in each of:

- `newestExport.rbxmx`
- `Framewisp_Hotbar.prepared.rbxmx`

No `Slot1Selected` instance was found under Hotbar in that search. This establishes that a checked-in export contained Selected; it does not establish why the current export omits it or attribute the removal to a wiring pass.

## Files changed by this pass

| File | Change | Result |
| --- | --- | --- |
| src/client/UI/HotbarGui.luau | 1 | Required Label/Icon/Background; shipped background aliases; optional Selected with per-instance warning; direct/Items/HotbarScroll candidates; wrapped fallback images. |
| src/client/Controllers/HotbarController.luau | 2 | Guard Selected reads/writes; retain nil-to-nil revalidation and GuiService selection fallback. |
| src/client/UI/SettingsGui.luau | 3 | Resolve one level through PLOTContent/MUSICContent; Locked maps to Closed; incomplete slider and ambiguous Status remain optional. |
| src/client/UI/UpgradesGui.luau | 4 | Resolve row controls through card content, retain direct-card compatibility, resolve arrows at card or content depth. |
| tools/prepare_framewisp_ui.py | 5 | Stamp direct/Items/HotbarScroll text labels, deduplicating referents. |
| tests/test_prepare_framewisp_ui.py | 5, 6 | Verify all three slot locations stamp Label and Number bounds. |
| tests/framewisp_export.py (new) | 6 | Shared Rojo-mapped prepared-export loader, explicit missing-file instruction, shipped hierarchy regressions. |
| tests/run_hotbar_tests.py | 6 | Use shared prepared loader and shipped Hotbar contract. |
| tests/run_settings_tests.py | 6 | Replace obsolete filename with mapped prepared file and shipped Settings contract. |
| tests/run_upgrade_ui_tests.py | 6 | Replace obsolete filename with mapped prepared file and shipped Upgrades contract. |
| tests/run_framewisp_menu_tests.py | 6 | Same obsolete filename also blocked the requested menu suite; use mapped prepared loader. |
| tests/hotbar.spec.luau | 6 | Default fixture has Slot1Background/no Selected; test required children, optional highlight, slot locations, equip/cloning/native handoff, real wrapped fallback artwork. Presentation reveal assertions use GuiService focus when Selected is absent. |
| tests/settings.spec.luau | 6 | Shipped Locked/Closed mapping, exact Knob/ProgressBar/Title issues, nil Status controller feedback, inert slider and working music buttons. Retain geometry tests on explicitly synthetic complete controls. |
| tests/upgrade_ui.spec.luau | 6 | Real wrapped export rows, direct-card compatibility, wrapper-aware replacement and semantic fixtures. |
| Framewisp_Hotbar.prepared.rbxmx | preparation | Regenerated from local newestExport11426.rbxmx. This file already had local changes before the pass. |
| docs/FRAMEWISP_BINDING_PASS_2026-11-05.md (new) | report | This evidence and acceptance record. |

The raw export and pre-existing Lucky Block changes were left as received. Generated typecheck/build/cache artifacts are excluded from the pass changes. No production paths differed from the allowed layouts; the menu runner's stale export filename was the additional validation-path fix.

## Validation

Final successful commands (repository root; `-B` prevents tracked Python cache churn):

```powershell
python -B tests/run_hotbar_tests.py --luau .validation-tools/luau.exe
python -B tests/run_settings_tests.py --luau .validation-tools/luau.exe
python -B tests/run_upgrade_ui_tests.py --luau .validation-tools/luau.exe
python -B tests/run_framewisp_menu_tests.py --luau .validation-tools/luau.exe
python -m unittest discover -s tests -p test_prepare_framewisp_ui.py
.validation-tools/stylua.exe --check src/client/UI/HotbarGui.luau src/client/Controllers/HotbarController.luau src/client/UI/SettingsGui.luau src/client/UI/UpgradesGui.luau tests/hotbar.spec.luau tests/settings.spec.luau tests/upgrade_ui.spec.luau
& 'C:/Users/Collin Van Meter/.aftman/tool-storage/rojo-rbx/rojo/7.7.0/rojo.exe' sourcemap default.project.json --output .validation-tools/framewisp-pass.sourcemap.json
& 'C:/Users/Collin Van Meter/.aftman/tool-storage/rojo-rbx/rojo/7.7.0/rojo.exe' build default.project.json --output .validation-tools/framewisp-pass.rbxlx
.validation-tools/luau-lsp.exe analyze --platform roblox --sourcemap .validation-tools/framewisp-pass.sourcemap.json --definitions .validation-tools/globalTypes.d.luau src/client/UI/HotbarGui.luau src/client/UI/SettingsGui.luau src/client/UI/UpgradesGui.luau src/client/Controllers/HotbarController.luau
```

| Check | Result |
| --- | --- |
| Hotbar | PASS; 1,810 checks, including real mounted export and existing docking/reparent coverage. |
| Settings/music | PASS; 195 checks. |
| Upgrade UI | PASS with UI present before Init both false and true; purchase, replacement, semantic binding, badge and tutorial coverage completed. |
| Framewisp menus | PASS; 1,390 checks. |
| Preparation | PASS; 18 unittest tests. |
| StyLua | PASS; formatted changed Luau files and final --check exit 0. |
| Focused typecheck | PASS; exit 0 against freshly generated sourcemap; only a watcher-registration environment warning. |
| Rojo sourcemap/build | PASS using installed 7.7.0 binary. |

Initial failures were resolved within scope: Hotbar tests assumed highlight visibility and counted all warnings; Upgrade fixtures assumed an obsolete desktop wrapper; the menu runner referenced nonexistent Framewisp_CCWMF.rbxmx. Final suites above passed after those fixture/runner corrections. `python -m pytest tests/test_prepare_framewisp_ui.py` was attempted but could not run because pytest is not installed; the equivalent unittest suite passed. The Aftman `rojo` shim failed with ?Home directory could not be found?; the installed binary succeeded. No broad unrelated gameplay or live-purchase suites were run.

## Remaining authored UI items (Figma TODOs; no code fabrication)

- **Selection highlight:** absent because the raw export has no SlotSelected/Slot1Selected. Restore an authored direct slot child named SlotSelected (or supported Slot1Selected), and verify that it survives export. Equipping and GuiService selection are covered without it.
- **Volume slider:** inert because Slider has no direct Knob and ProgressBar. Add authored direct children with those exact names. SliderBackground remains artwork; MusicOn/MusicOff still work.
- **Status:** nil because PLOTContent has two TextLabels named Title. Give the heading and status distinct authored names (for example PLOTTitle and StatusTitle); a subsequent explicit binding-contract update would be needed for StatusTitle. This pass continues to require a unique Title and does not select by text or order.

## Studio acceptance ? PENDING for Collin

No Studio acceptance was run by Codex. Mock viewport tests passed; they are not engine acceptance.

1. Prepare from the saved local raw export, restart Rojo if it predates the prepare write, and sync CCVVMF in place. Remove only the raw B3TZAA import ScreenGui once; retain Framewisp_CCVVMF and save the place.
2. Play Solo with one client: confirm one active desktop, nine Hotbar slots, no unusable-slot warning, and native Backpack disabled after successful handoff. Missing Selected warnings are expected once per slot instance.
3. Confirm Open/Friends/Locked, Rename/Kick and music toggles work; Settings reports only Knob, ProgressBar and Title. Slider remains inert and no Status text is bound.
4. Confirm five Upgrades rows and Buy actions, and Shop binding without regression. No live purchase was tested.
5. Confirm click/1?9 equip and GuiService selection with no nil errors; selection highlight remains absent as expected.
6. Desktop, phone portrait and phone landscape visual/docking acceptance are all PENDING. Check bottom docking, aspect, glyph appearance and touch behavior in Studio.

Prepared output after regeneration: 1617804 bytes; raw SHA-256 `8635c5de9fac34a38806ce6fdda0c0094b594452b9439de7d7a6ab09595a7f09`; prepared SHA-256 `ffc88cc0c96c88e92faaff35098ea032e50599fef2e5c1cd9f299a9798d84017`.
