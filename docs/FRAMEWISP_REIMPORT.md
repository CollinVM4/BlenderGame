# Framewisp reimport recovery

This is the current contract for the 2026-10-08 export. Earlier audit snapshots in UPGRADE_UI.md describe older assets.

## Confirmed cause and before/after

The supplied XML now has a Framewisp_JTRKKV ScreenGui, all four authored panels (Index, Settings, Shop, Upgrades), five CanvasGroup upgrade cards, and TOP.CashDisplay.{Coins}. The existing adapter already ignored the generated ScreenGui name and observed replacement instances. Its card lookup required Frame, so every new CanvasGroup card failed validation. Resolution required every card and the cash label together; a card failure returned no view, stopping both cash and upgrades. The focused upgrade runner reproduced this at “actual exported hierarchy resolves” before the repair.

The adapter now accepts Frame/CanvasGroup containers, binds valid cards independently, and binds cash independently of the upgrade tree. Missing or ambiguous controls produce a scoped warning. A replacement renders current state immediately and disconnects detached purchase buttons. Duplicate active desktops still pause binding instead of selecting an arbitrary import. Keep only one active desktop in PlayerGui; disable/remove old Studio copies. Rojo's ignoreUnknownInstances setting does not remove them automatically.

Source flow is TycoonService.SharedCash -> each session member's playerCash attribute -> UpgradesController.refresh -> active TextLabel via MoneyFormat.Full. PurchasedLevel attributes and personal CarryCapacityLevel follow the existing server projections. GameplayRequest remains the only purchase remote, with existing session/revision checks, pending guard, timeout, MAX and feedback. No economy, server upgrade validation or definitions changed. {Coins} is an instance name with static $0 text in the export; generated scripts do not supply an economy binding. TextScaler, ButtonFX and Juice create text/effect copies; they do not own the authoritative cash text.

The workspace already contained PanelManager, FramewispMenus and a prepared FramewispActions delegation hook. The supplied export already stored the four major panels hidden. The prepared action path was already exclusive; overlap in the live game cannot be attributed to this snapshot without a Studio inspection. A raw reimport that omits preparation restores generated independent show/hide handlers and can overlap panels. Preserve the hook by rerunning preparation. The updated shared registry removes duplicate desktop/panel lookup rules; Attach is idempotent, CanvasGroup panels work, and missing/ambiguous navigation targets warn. Detaching or destroying a root retires its UI handlers and respawn listener. PanelManager now closes registrations on startup and exposes CloseAll/GetActive alongside its existing handles. Immediate major-menu visibility avoids delayed generated action tweens; other effects remain authored.

TOP is the persistent cash HUD, not a closable panel. LeftMenu, RightMenu, desktop/background and HUD remain visible. Cosmetic panels remain supported if authored. Other existing callers of PanelManager keep their APIs.

## Supported import process

1. Replace Framewisp_CCWMF.rbxmx with the exported design.
2. Run python tools/prepare_framewisp_ui.py (or supply another export path as its positional argument).
3. Keep default.project.json pointing to the intended asset, sync Rojo, and restart Play.
4. Ensure only one imported desktop is enabled/visible. Do not leave old active StarterGui clones alongside it.

Preparation saves named Frame/CanvasGroup menu panels hidden before cloning and installs the existing action delegation hook. It is idempotent and rejects an unfamiliar generated wiring contract. It changes only FramewispActions and major-panel Visible properties; Fredoka, artwork, gradients, button styling, FX, Juice, Spin and TextScaler remain intact.

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

The expected parent relationships still apply. Changing names needs no controller edits. For completely different layouts, change only the declarative lookup paths in UpgradesGui/UIRegistry. Keep standard panel/content names for export preparation to save startup visibility automatically; if renaming those using semantic attributes, save their Visible=false in the export to prevent a preview flash before FramewispActions initializes. Runtime always hides newly registered panels regardless of authored visibility. Attribute-only or name-only edits to a live bound tree are not a rebinding API: replace the completed subtree, or restart Play after preparation.

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
