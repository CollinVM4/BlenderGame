# Framewisp reimport recovery

This is the current contract for the 2026-10-08 export. Earlier audit snapshots in UPGRADE_UI.md describe older assets.

## Confirmed cause and before/after

The supplied XML now has a Framewisp_JTRKKV ScreenGui, all four authored panels (Index, Settings, Shop, Upgrades), five CanvasGroup upgrade cards, and TOP.CashDisplay.{Coins}. The existing adapter already ignored the generated ScreenGui name and observed replacement instances. Its card lookup required Frame, so every new CanvasGroup card failed validation. Resolution required every card and the cash label together; a card failure returned no view, stopping both cash and upgrades. The focused upgrade runner reproduced this at “actual exported hierarchy resolves” before the repair.

The adapter now accepts Frame/CanvasGroup containers, binds valid cards independently, and binds cash independently of the upgrade tree. Missing or ambiguous controls produce a scoped warning. A replacement renders current state immediately and disconnects detached purchase buttons. Duplicate active desktops still pause binding instead of selecting an arbitrary import. Keep only one active desktop in PlayerGui; disable/remove old Studio copies. Rojo's ignoreUnknownInstances setting does not remove them automatically.

Source flow is TycoonService.SharedCash -> each session member's playerCash attribute -> UpgradesController.refresh -> active TextLabel via MoneyFormat.Full. PurchasedLevel attributes and personal CarryCapacityLevel follow the existing server projections. GameplayRequest remains the only purchase remote, with existing session/revision checks, pending guard, timeout, MAX and feedback. No economy, server upgrade validation or definitions changed. {Coins} is an instance name with static $0 text in the export; generated scripts do not supply an economy binding. TextScaler, ButtonFX and Juice create text/effect copies; they do not own the authoritative cash text.

The workspace already contained PanelManager, FramewispMenus and a prepared FramewispActions delegation hook. The supplied export already stored the four major panels hidden. The prepared action path was already exclusive; overlap in the live game cannot be attributed to this snapshot without a Studio inspection. A raw reimport that omits preparation restores generated independent show/hide handlers and can overlap panels. Preserve the hook by rerunning preparation. The updated shared registry removes duplicate desktop/panel lookup rules; Attach is idempotent, CanvasGroup panels work, and missing/ambiguous navigation targets warn. Detaching or destroying a root retires its UI handlers and respawn listener. PanelManager now closes registrations on startup and exposes CloseAll/GetActive alongside its existing handles. Immediate major-menu visibility avoids delayed generated action tweens; other effects remain authored.

TOP is the persistent cash HUD, not a closable panel. LeftMenu, RightMenu, desktop/background and HUD remain visible. Cosmetic panels remain supported if authored. Other existing callers of PanelManager keep their APIs.

## Supported import process

1. Edit the design in Figma.
2. Export through Framewisp as an .rbxmx file (for example, new_export.rbxmx).
3. From the repository root, run:

   ```powershell
   python tools/prepare_framewisp_ui.py --input new_export.rbxmx
   ```

4. Sync Rojo with default.project.json.
5. Restart Studio Play. Keep only one imported desktop active in PlayerGui; remove/disable older Studio copies.

The command preserves new_export.rbxmx and writes **Framewisp_CCWMF.rbxmx in the repository root**, the asset already mapped by Rojo. In this checkout the exact output is C:\src\BlenderGame\BlenderGame\Framewisp_CCWMF.rbxmx. It prints the absolute destination after preparation. Input/output paths may be filenames or relative/absolute paths; relative paths are resolved from your current working directory.

To choose a different output:

```powershell
python tools/prepare_framewisp_ui.py --input new_export.rbxmx --output prepared_export.rbxmx
```

This writes prepared_export.rbxmx in the current directory. Point Rojo at that file if you want to use it instead of the default asset. --input refuses a destination equal to the source to prevent accidental replacement. Only XML .rbxmx exports are supported; missing files, invalid XML and unfamiliar action wiring produce CLI errors without writing output.

The existing `python tools/prepare_framewisp_ui.py` command remains supported and intentionally prepares the repository-root Framewisp_CCWMF.rbxmx **in place**. The legacy positional command (`python tools/prepare_framewisp_ui.py another_export.rbxmx`) also remains in place. An explicit --output can be used with either legacy command to save elsewhere.

Preparation hides unambiguous registered Frame/CanvasGroup panels (Index, Settings, Shop, Upgrades, plus optional Cosmetics) before cloning and installs the existing action delegation hook. It recognizes both default names and serialized string BlenderUI attributes, including renamed desktop/content wrappers. No manual visibility setup is needed for recognized panels. Missing/ambiguous identifiers warn and leave the affected visibility unchanged; ambiguous desktop/content identifiers skip all panel visibility changes. Review these warnings before syncing.

**TOP is permanently excluded from the exclusive menu group.** Preparation never hides TOP, the cash HUD, LeftMenu, RightMenu or persistent navigation. Do not tag persistent UI as a menu panel. Runtime menu switching, active-button toggling and detach/reattach behavior remain owned by the existing FramewispMenus/PanelManager.

Preparation is idempotent and changes only FramewispActions and recognized panels' Visible properties. Fredoka, artwork, gradients, layout, button styling, FX, Juice, Spin and TextScaler remain intact.

Default direct-child contracts (the desktop itself may be a Frame or ScreenGui):

- Be a Blender! Desktop -> optional Be a Blender! DesktopContent or DesktopContent.
- Content -> Index, Settings, Shop, Upgrades (also accepts _panel suffix); TOP, LeftMenu, RightMenu.
- TOP -> CashDisplay -> {Coins} or Cash TextLabel.
- Upgrades -> UpgradeScroll (ScrollingFrame) -> UpgradeList -> JumpCard, BatCard, MovementSpeedCard, CarryCapacityCard, SprintStaminaCard. Scroll/list accept _scroll/_list suffixes.
- Each card -> UpgradeTitle and PurchasePrice TextLabels; LevelContainer -> CurrentValue and NextValue TextLabels; Buy (GuiButton, also Buy_button_smooth) -> BuyLabel TextLabel.
- Navigation buttons under LeftMenu/RightMenu use the panel name or existing FigmaActionParam; close buttons inside panels use Close or FigmaAction=close. Purchases stay separate.

Containers accept GuiObject classes where layout differs; menu panels specifically accept Frame or CanvasGroup. Leaves retain their required TextLabel, ScrollingFrame or GuiButton class. No arbitrary descendant search chooses a button or label.

For renamed designs, assign string attributes named BlenderUI before inserting the completed tree. These attributes override default names and must be unique within the expected parent:

| Instance | BlenderUI value |
| --- | --- |
| Desktop / content wrapper | Desktop / Content |
| Major panel | Panel:Index, Panel:Settings, Panel:Shop, Panel:Upgrades |
| Navigation / close button | Toggle:Index etc. / Close |
| Navigation container | LeftMenu / RightMenu |
| Cash ancestors / label | TOP / CashDisplay / Cash |
| Upgrade scroll / list | UpgradeScroll / UpgradeList |
| Upgrade card | Upgrade:Jump, Upgrade:Bat etc. |
| Card controls | UpgradeTitle, PurchasePrice, LevelContainer, CurrentValue, NextValue, Buy, BuyLabel |

The expected parent relationships still apply. Changing names needs no controller edits. For completely different layouts, change only the declarative lookup paths in UpgradesGui/UIRegistry. Keep the default semantic names or their BlenderUI attribute values stable in the exported XML; preparation uses the same direct-parent relationships and string-attribute overrides as UIRegistry to save startup visibility automatically, including renamed wrappers. TOP is never a Panel:TOP or Toggle:TOP target. Runtime always hides newly registered panels regardless of authored visibility. Attribute-only or name-only edits to a live bound tree are not a rebinding API: replace the completed subtree, or restart Play after preparation.

Affordability uses replicated playerCash and shared tier costs to dim price/BUY text. Authored text opacity returns when affordable. Buttons still allow server-validated attempts so existing insufficient-cash feedback remains available; the client never calculates a new balance or grants a tier.

## Verification

Focused upgrade, Framewisp action/menu, PanelManager, existing Scrapbook and Plot Identity suites pass. Upgrade tests build their hierarchy from the actual XML, exercising UI present/delayed at initialization, state changes, affordability, MAX, single requests, stale responses, replacement, partial cash/card failure, semantic designs and duplicate roots. Existing stale insufficient-cash expectations were corrected to the unchanged UpgradeDisplay.Feedback contract (NOT ENOUGH). Menu tests execute the prepared asset's actual FramewispActions, including semantic CanvasGroup panels and repeated Attach.

Roblox-aware typecheck, focused StyLua and Rojo build pass. Full cash-format tests pass. Import preparation was checked for idempotence, CanvasGroup panel visibility and preservation of generated effects/artwork. CLI fixtures simulate the engine; live Studio PlayerGui inspection and network/rendering validation have not been performed in this session. Use tests/studio_framewisp_diagnostics.luau in the client Command Bar during Play to print actual roots, classes, selected cash path and replicated attributes. It is not mapped into production.

Remaining Studio smoke check: join with HUD/navigation visible and all four panels hidden; rapidly switch/toggle/X menus; purchase every category; verify teammate earnings/spending in two clients; respawn and replace an import; inspect latest state and exactly one request per new button. Confirm Fredoka text, FX and scrolling retain their appearance.

## Files changed in this recovery

- src/client/UI/UIRegistry.luau (new shared semantic resolver)
- src/client/UI/UpgradesGui.luau
- src/client/Controllers/UpgradesController.luau
- src/client/UI/FramewispMenus.luau
- src/client/UI/PanelManager.luau
- tools/prepare_framewisp_ui.py
- tests/upgrade_ui.spec.luau and tests/run_upgrade_ui_tests.py
- tests/framewisp_menus.spec.luau and tests/run_framewisp_menu_tests.py
- tests/panel_manager.spec.luau
- tests/studio_framewisp_diagnostics.luau
- docs/FRAMEWISP_REIMPORT.md, docs/UPGRADE_UI.md, docs/MAJOR_PANELS.md

Existing unrelated workspace changes were preserved.

## Lifecycle follow-up (2026-10-09)

The earlier integration is committed in c9aa42e; the working tree was clean when this follow-up began. The user reports that cash and upgrades worked in Studio after that integration. This follow-up leaves UpgradesController, UpgradesGui, UIRegistry, PanelManager, the export, generated scripts and economy unchanged.

The remaining menu cleanup gap was ownership detection: checking only AncestryChanged's parent == nil missed moving a root (or its ancestor) into another non-nil container outside the player's PlayerGui. FramewispMenus now also checks whether the root remains under its original PlayerGui. Moving inside that PlayerGui preserves the current menu. Leaving it invokes the existing cleanup, retiring panel handles, purchase-independent menu activations, descendant observers, the respawn subscription and its own destruction/ancestry observers. Retired initialization callbacks cannot register new panels.

A second gap affected explicitly reusing a detached root: its retained FramewispActions hook still referenced the retired binding. Attach now wires existing controls itself, and retired hooks forward to the current binding after an explicit reattachment. Repeated Attach remains idempotent. Fresh exports still bind through the existing preparation hook automatically. Runtime code that intentionally restores the same parked root should call FramewispMenus.Attach(root, player) after parenting it back under PlayerGui; no manual Studio script is needed for the normal export/sync workflow.

Focused tests exercise an open panel detached to nil, roots/ancestors moved to non-nil containers, an ancestor detached to nil, harmless moves inside PlayerGui, inert old controls, respawn and descendant insertion after detachment, replacement ownership, explicit same-root reattachment and the retained generated hook. They assert menu behavior without relying on connection counts. The existing upgrade/cash suite still passes with early and delayed UI, including immediate disconnection of removed purchase controls and restoration of current state on replacement. Menu, PanelManager, Scrapbook and Plot Identity suites pass. Roblox-aware focused typecheck, StyLua and Rojo build pass.

Exactly three files are modified by this follow-up:

- src/client/UI/FramewispMenus.luau
- tests/framewisp_menus.spec.luau
- docs/FRAMEWISP_REIMPORT.md

Implementation and CLI verification are complete. Engine validation of these new detach/reattach cases remains a Studio smoke check; the user's successful cash/upgrade playtest is recorded separately from agent-run verification.

## Reimport automation verification

The focused Python suite tests default/legacy CLI commands, relative and absolute custom inputs, custom output, source preservation, CLI errors, named/semantic CanvasGroup panels, missing/ambiguous identifiers, HUD/navigation and artwork preservation, and byte-for-byte idempotency. The existing Luau suites verify exclusive switching, active-button toggle, initial hiding and detach/reattach behavior; Framewisp coverage now explicitly includes Shop -> Index -> Upgrades, RightMenu visibility and permanent TOP exclusion even with a Panel:TOP tag.

Run `python -m unittest discover -s tests -p test_prepare_framewisp_ui.py`, `python tests/run_framewisp_menu_tests.py` and `python tests/run_panel_manager_tests.py` (the Luau runners accept `--luau <executable>`). Live rendering/animation remains a Studio smoke check.

Validation for this automation change: all 15 Python tests pass; Framewisp menu, PanelManager and existing cash/upgrade UI suites pass. Focused Roblox-aware typecheck of FramewispMenus, UIRegistry and PanelManager, StyLua, Rojo build and git diff --check pass. No production Luau module or Rojo mapping changed for this task. Studio Play/rendering was not run.
