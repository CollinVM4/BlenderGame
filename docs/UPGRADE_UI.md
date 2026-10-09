> Current export/recovery contract: [FRAMEWISP_REIMPORT.md](FRAMEWISP_REIMPORT.md). The historical audits below describe older exports. The current asset has four panels and CanvasGroup cards.

# Framewisp upgrades and cash

The inspected `Framewisp_CCWMF.rbxmx` export is mapped into StarterGui by
`default.project.json`. Its actual ScreenGui name is **Framewisp_CCVVMF** (two V's).
Runtime bindings resolve its clone in PlayerGui. Restart a running Studio playtest
when adopting the new controller so any GUI left by the previous controller is removed.
The main-menu visibility pass below now prepares the export's panel defaults and
FramewispActions wiring; earlier statements about unchanged generated sources
describe the upgrade binding pass before that visibility change.

## Verified import and reference strategy

```text
PlayerGui
  Framewisp_CCVVMF (ScreenGui, ResetOnSpawn=false)
    FramewispActions / FramewispButtonFX / FramewispSpin / FramewispTextScaler (LocalScripts)
    Be a Blender! Desktop (Frame)
      Be a Blender! DesktopContent (CanvasGroup)
        TOP (Frame)
          CashDisplay (Frame)
            {Coins} (TextLabel)
        LeftMenu (Frame)
          Upgrades (TextButton, open action targeting Upgrades)
        Upgrades (Frame, panel action)
          Header (Frame)
            Close (ImageButton, close action)
          UpgradeScroll (ScrollingFrame)
            UpgradeList (Frame)
              JumpCard / BatCard / MovementSpeedCard / CarryCapacityCard / SprintStaminaCard (Frames)
```

Every card has the same verified direct children: `UpgradeTitle` (TextLabel),
`PurchasePrice` (TextLabel), `LevelContainer` (Frame), `Buy` (TextButton),
`UpgradeIcon` (ImageLabel), and `CardBackground` (Frame). `LevelContainer` contains
`CurrentValue` and `NextValue` (TextLabels), `Arrow` (ImageLabel), and
`LevelBackground` (Frame). `Buy` contains `BuyLabel` (TextLabel), `BuyBackground`,
and `BuyShadow` (Frames).

`UpgradesGui.luau` is a presentation adapter. It discovers the named desktop under
LocalPlayer.PlayerGui without requiring the generated ScreenGui name. It accepts
the processed path above and the retained-tag contract below, using direct-child
paths and class checks within the selected desktop. It observes GUI insertion/removal. It
binds `Buy.Activated`, disconnects purchase handlers immediately when a bound
instance or ancestor is removed, and rebinds when the hierarchy is complete again.
Unrelated decorative FX removal does not invalidate purchases. Player attribute
and remote subscriptions remain in the guarded controller, independent of panel
opening or GUI replacement. No cards are cloned or UI instances created.

## Generated behavior preserved

Figma tags are already translated by the exporter:

- `_smooth`: the instance is named `Buy`, with `FigmaSmooth=1`.
  `FramewispButtonFX` retains the authored hover/press scale compositor and effects.
- `_open:Upgrades`: `LeftMenu.Upgrades` has `FigmaAction=open` and
  `FigmaActionParam=Upgrades`; the panel has `FigmaAction=panel`.
  `Header.Close` has `FigmaAction=close`. `FramewispActions` owns their Activated
  handlers and panel tweens. The adapter never toggles the panel.
- `_scroll`: `UpgradeScroll` is a native vertical ScrollingFrame, with scrolling
  enabled and authored CanvasSize. `_list`: `UpgradeList` is a Frame; its child
  layout is baked into positions/sizes, rather than a UIListLayout or runtime list
  script. These properties are unchanged.
- `{Coins}` is a literal TextLabel name. None of the four generated scripts binds
  its text to cash. The controller supplies that binding.
- `FramewispTextScaler` owns responsive text sizing and stroke scaling. It supports
  changed text by using the font-size fallback when text differs from FW_Text0.
  The adapter writes Text only, leaving sizing, fonts, artwork, strokes, shadows,
  selection/navigation, and all Framewisp attributes unchanged.
- `FramewispSpin` retains attribute-driven spin behavior.

Buy, open, and close buttons are interactive GuiButtons. All value/price/title/cash
labels, backgrounds, shadows, icons, and arrows are presentation-only. The adapter
only changes purchase Interactable for loading, pending, or MAX. It adds no
unaffordable-card styling and never changes generated scripts.

## Authoritative data and presentation

| Card | Backend ID | Purchased progression | Presentation |
|---|---|---|---|
| JumpCard | Jump | JumpPurchasedLevel | JUMP 0 through JUMP 3 |
| BatCard | Bat | BatPurchasedLevel | NO BAT, NORMAL, BIG BAT, GIANT |
| MovementSpeedCard | MovementSpeed | MovementSpeedPurchasedLevel | SPEED 0 through SPEED 3 |
| CarryCapacityCard | CarryCapacity | CarryCapacityLevel | Config Value followed by ITEMS |
| SprintStaminaCard | SprintStamina | SprintStaminaPurchasedLevel | STAMINA 0 through STAMINA 3 |

Titles are JUMP LEVEL, STUN-BAT, MOVEMENT SPEED, CARRY CAPACITY, and SPRINT STAMINA.
Carry's configured quantities are currently 3, 5, and 7; they are read from
Constants.Upgrades rather than presentation constants. Effective values such as
BaseWalkSpeed, StaminaMax, JumpLevel, CarryCapacity, and BatLevel retain their
existing subscriptions but never determine purchased progression or displayed
quantities. A purchased tier renders even if an effective projection arrives later.
No other upgrade categories are exposed.

Next price comes from the next shared definition's Cost via MoneyFormat.Compact.
MAX keeps the current value, shows MAX as the next value and BuyLabel, clears price
text, and disables purchases. Cash is bound solely to playerCash using the new
shared MoneyFormat.Full, producing $0, $1,000, $125,000, $10,000,000, and
$10,000,000,000 without abbreviation. Cash changes refresh the cards and HUD.

The existing request is unchanged:
`GameplayRequest:FireServer("PurchaseUpgrade", id, purchasedLevel + 2, context)`.
The tier argument is the backend definition index; context carries PlotSessionId
and PlotMembershipRevision. No new remote, balance change, local cash subtraction,
or optimistic upgrade grant was added. Pending guards, MAX protection, timeout,
session/revision checks, membership cleanup, and success/failure feedback remain
in UpgradesController. Feedback now renders in BuyLabel and then restores BUY/MAX.

The old UpgradesGui CashHud, Toggle, Panel, Close, and generated Rows creation has
been retired by replacing that module with the adapter. There is one menu, and its
opening/closing remains owned by Framewisp.

## Validation

- `python tests/run_upgrade_ui_tests.py --luau <luau.exe>`: passes 144 behavioral
  assertions. The fixture builds the GUI boundary from the actual exported XML,
  covering exact paths/classes, all tier mappings and config prices, five request
  IDs, rapid clicking, authoritative rendering, feedback, MAX, stale responses,
  timeout recovery, missing import, root replacement, and nested label replacement.
- `luau tests/money_format_full.spec.luau`: passes the five required full-cash
  examples and negative formatting.
- Roblox-aware Luau LSP typecheck of the four changed runtime modules: passes.
- Focused StyLua check, Rojo build, and scoped whitespace check: passes.
- Existing `upgrade-sync` integration suite fails at `jump value and next price`;
  it expects 375000 whereas the existing shared config has 125000. Reproduces with
  the original UpgradeDisplay module. The suite also contains other stale economy
  expectations. No backend or economy definitions were changed to satisfy it.
- Existing `money_format.spec.luau` fails on its $500 compact expectation;
  baseline MoneyFormat returns $500 while the test expects $0.5K. Reproduces on
  baseline. Compact/Announcement behavior and this existing test remain unchanged.

The export and all four generated script sources/attributes are preserved in the
Rojo build. Tests mock the engine; they do not execute generated UI scripts or
verify engine rendering/network ordering.

## Studio validation remaining

Sync with Rojo, restart Play, and check:

- Exactly one imported GUI/menu and no old CashHud/Toggle; Upgrades open and Close
  still work normally, and all five cards scroll correctly.
- Each Buy activates the correct backend category. Bat starts at NO BAT, then
  purchases NORMAL, BIG BAT, and GIANT; remaining tier transitions match the table.
- Cash updates immediately for payouts, purchases, farm/storage spending, admin
  grants, joining/leaving sessions, and teammate spending in a two-client session.
- MAX cannot purchase; insufficient cash does not change cash/tier; rapid clicks
  cannot double-purchase; feedback restores BUY/MAX and dropped requests recover.
- Respawn and GUI replacement preserve one purchase handler per button.
- Desktop, touch Activated, narrow/mobile sizing, gamepad selection/open/close,
  and long cash/feedback strings remain readable with authored text scaling.

No Framewisp/Figma changes are required for these bindings. Future Live Sync
hierarchy changes must be re-exported to Framewisp_CCWMF.rbxmx and reviewed against
the supported contracts; Rojo syncs this exported snapshot. Any text overflow or
navigation issue found in Studio should be resolved deliberately in the authored
layout rather than silently replacing generated behavior.

Changed files: default.project.json, src/client/Controllers/UpgradesController.luau,
src/client/UI/UpgradesGui.luau, src/client/UI/UpgradeDisplay.luau,
src/shared/MoneyFormat.luau, tests/run_upgrade_ui_tests.py,
tests/upgrade_ui.spec.luau, tests/money_format_full.spec.luau, and this document.
Framewisp_CCWMF.rbxmx is the supplied, unchanged import asset referenced by Rojo.

## Reimport binding repair (2026-10-07)

The pre-repair resolver required `PlayerGui.Framewisp_CCVVMF` and its exact
`Be a Blender! Desktop.Be a Blender! DesktopContent` wrapper, then the processed
names `Upgrades.UpgradeScroll.UpgradeList` and each card's `Buy`. The reported
reimport instead retains `Upgrades_panel.UpgradeScroll_scroll.UpgradeList_list`
and `Buy_button_smooth`, directly below the desktop. That contract cannot resolve
with the previous adapter. Resolution is all-or-nothing for cash and the five
cards, so a missing upgrade path also leaves cash unbound. The supplied XML still
contains the processed contract; it is not a snapshot of the reported new import.
The name/wrapper mismatch is established in source, but the exact live failing
node requires the Studio diagnostic below; no live session was available here.

The previous adapter already observed DescendantAdded/DescendantRemoving,
compared current instance identity, disconnected stale Activated handlers, and
immediately called the controller's refresh on replacement. It did not use
Framewisp reference IDs, permanently cache an original root, resolve StarterGui,
or give up after a startup timeout. Its weakness was that every later scan still
required the obsolete hierarchy and generated ScreenGui name. It also used
FindFirstChild for the root without duplicate selection protection.

The repaired resolver supports both the XML contract and the reported retained-tag
contract. `Be a Blender! Desktop` may be a Frame inside a ScreenGui whose generated
name changes, or the ScreenGui itself. The known DesktopContent CanvasGroup is
optional; TOP and the upgrade panel remain direct children of the selected content.
Purchase buttons are checked as GuiButton so TextButton and ImageButton both use
Activated. Stable desktop/card/label names form the binding contract; XML
referents and generated wrapper IDs are never used. Reimport-created instance
identity changes are covered in tests, but live identity/ID changes were not observed.

Selection requires one active desktop with an enabled ScreenGui and visible desktop
ancestors. Disabled/hidden obsolete copies do not win selection. Multiple active
desktops produce a warning and pause all binding rather than choosing an arbitrary
copy. Enabled/Visible changes trigger discovery again. No selection relies on
insertion order or presumed newest ownership. The checked-in export and Rojo
mapping contain one desktop/root; `$ignoreUnknownInstances=true` means extra
Studio copies may still exist. Actual StarterGui/PlayerGui duplicate counts remain
unverified until the Studio diagnostic runs.

Runtime path is `Players.LocalPlayer.PlayerGui -> current ScreenGui -> Be a Blender!
Desktop -> optional Be a Blender! DesktopContent -> TOP.CashDisplay.{Coins}`.
Upgrade resolution uses the corresponding panel/scroll/list path. Discovery is
event-driven, deferred to coalesce import events, and has no polling or timeout.
Removal immediately disconnects old purchase handlers; a complete replacement
binds fresh handlers and renders current cash and every purchased tier, without
waiting for a new attribute mutation. ScreenGui recreation on respawn follows the
same lifecycle. The persistent PlayerGui container remains owned by Roblox;
attribute/remote listeners stay once in the guarded, unchanged controller.
MoneyFormat.Full, tier text, MAX, pending state, feedback, requests, and all
Framewisp scripts/layout/artwork/attributes remain unchanged.

Backend changes: **none**. Source inspection confirms TycoonService publishes
`playerCash` and shared `*PurchasedLevel` attributes, and PlayerDataService publishes
`CarryCapacityLevel`/`CarryCapacity` on personal purchases. Mocked replication tests
confirm presentation reads these attributes independently of GUI lifetime. This
is not a claim that network replication was observed in a live Studio session.

Files changed for this repair only:

- `src/client/UI/UpgradesGui.luau`: named-contract discovery and active duplicate protection.
- `tests/upgrade_ui.spec.luau`: reimport and duplicate selection scenarios.
- `tests/run_upgrade_ui_tests.py`: runs with UI present before Init and with delayed arrival.
- `tests/studio_framewisp_diagnostics.luau`: opt-in Studio-only diagnostic, not mapped by Rojo.
- `docs/UPGRADE_UI.md`: cause, contracts, results, and remaining validation.

Validation: the focused runner passes 183 assertions in each of the two startup
scenarios. Coverage includes delayed arrival, processed and retained-tag contracts,
changed wrapper names, fresh roots/labels/buttons, repeated replacement, immediate
rendering of all five tiers, disconnected old buttons, single new requests, one
cash render per subsequent attribute mutation, subsequent upgrade replication,
duplicate ambiguity/recovery, and hidden desktop recovery. Full cash-format tests,
Roblox-aware typecheck of adapter and unchanged controller, focused StyLua check,
and Rojo build pass. These tests simulate the engine; they do not run Framewisp
LocalScripts or establish the live imported classes.

Remaining Studio validation: sync/restart Play, then paste
`tests/studio_framewisp_diagnostics.luau` into the **client** Command Bar. It prints
PlayerGui's actual path/class, every required named instance's actual path/class
(or MISSING with processed aliases shown), all matching desktop copies in both
StarterGui and PlayerGui, enabled/visible candidate state, and the adapter's chosen
runtime root/cash path. It prints initial values and watches the seven cash/upgrade
attributes for 60 seconds, then disconnects its own observers. Exercise a payout
and purchases during that window to verify backend attributes change independently.
Repeat the snapshot after reimport/replacement and respawn; confirm the new UI
renders existing state immediately, old buttons cannot request, new buttons request
once, and generated open/close, smooth effects, scrolling, and responsive sizing
still work. Do not install the diagnostic as a production LocalScript. No temporary
diagnostic logging was added to production; the duplicate warning is intentional
ongoing error reporting. If two roots are active, disable/remove the obsolete copy
rather than leaving the adapter to guess which visible import owns the UI.

## Main menus closed by default (2026-10-07)

`src/client/UI/FramewispMenus.luau` supplies the focused menu policy, loaded
through a hook in the existing FramewispActions LocalScript by
`python tools/prepare_framewisp_ui.py`. Its existing `wire` function delegates
main navigation and X buttons to that policy and returns before connecting the
generated open/close handler. Buy buttons, upgrade bindings, cash subscriptions,
other Framewisp actions, ButtonFX, text scaling, spin, artwork, names, attributes,
and hierarchy are preserved. Main-panel visibility changes are immediate; they
do not use the generated hide tween, avoiding delayed callbacks and overlapping
visible menus during rapid switching.

Run the preparation command **after replacing the export and before Rojo sync or
build**. It writes `Visible=false` into the existing Settings, Upgrades, Shop, and
Index panel properties so clones are hidden before any LocalScript runs. It also
loads the canonical policy module from FramewispActions, preserving unrelated
generated source. The command is idempotent and fails if the expected generated wiring
contract changes. A raw new export that bypasses this step does not carry the
startup guarantee. Figma artwork does not need edits.

The supplied snapshot contains only Upgrades; Settings, Shop, and Index have
navigation buttons but no panels. No placeholder content was created. Their
panels are supported when supplied by a later import. Both processed names
(`Settings`, etc.) and retained tags (`Settings_panel`, etc.) work under the
desktop, with or without DesktopContent. Tagged navigation buttons are supported
even when the importer has not translated their action attributes.

Every newly inserted main panel is hidden synchronously, including a complete
subtree replacement. Existing open panels are not reset by decorative insertion
or repeated wiring. Navigation toggles the selected panel and closes its siblings;
Header.Close closes just its panel. CharacterAdded closes existing panels even
when ResetOnSpawn is false, and reconstructed GUIs initialize closed. Removed
button handlers are disconnected and GUI destruction releases the respawn listener.
The surrounding HUD is never hidden.

Validation: `python tests/run_framewisp_menu_tests.py --luau <luau.exe>` executes
the prepared export's actual FramewispActions source against an engine double.
It covers all four menus, tagged/processed paths, toggling, exclusive opening,
X, preserved Buy activation and HUD, decorative insertion, replacement, respawn,
and reconstruction. The existing upgrade UI suite passes in both startup
scenarios, including purchase requests, feedback, cash/upgrade replication, and
replacement; full cash-format checks pass. Roblox-aware policy typecheck,
focused StyLua, and Rojo build pass.

Studio smoke check remains: prepare, sync, restart Play, confirm HUD-only joining
without a flash; open Settings/Upgrades in both directions once all four authored
panels are present; toggle each menu, use X, purchase an upgrade, watch cash, and
respawn with a menu open. Engine rendering and real network replication were not
observed by the CLI tests.
