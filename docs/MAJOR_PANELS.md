> See [FRAMEWISP_REIMPORT.md](FRAMEWISP_REIMPORT.md) for the current four-panel export, semantic attributes and recovery validation.

# Major menu exclusivity

`src/client/UI/PanelManager.luau` coordinates major menus across imported and
script-generated UI. It closes the active panel before opening another. Requests
received during a yielding transition coalesce to the latest requested panel.
Opening the same panel remains idempotent; Framewisp navigation retains its toggle
behavior, while Scrapbook retains its open behavior and selected tab. X buttons
close only their own panel, so an old close callback cannot cancel another menu.

## Registered panels

- **Upgrades, Settings, Shop, Index, Cosmetics**: registered by FramewispMenus
  when a corresponding authored panel exists. Only **Upgrades** exists in the
  previous export. The current export contains Upgrades, Settings, Shop and Index;
  no Cosmetics panel was found. No placeholders are added.
- **Scrapbook**: registered by ScrapbookController after its presentation is ready.
- **PlotManagement**: the generated MANAGE PLOT menu in PlotIdentityController.

The coordinator acts only on registered views. Cash, stamina, customer dialogue,
orders, notifications, world prompts and temporary feedback remain outside it.
The compact stand-naming claim sequence is also outside the large-menu scope.

## Adding a menu

Register a stable logical name and the existing presentation callbacks. Route its
opening and dismissal actions through the returned handle; use GuiButton.Activated
for pointer, touch and controller activation. Destroy the handle when the view is
removed. A replacement registration for the same logical name retires the previous
view and makes its old opening handle inert.

```luau
local menu = PanelManager.Register("MyMenu", {
    Open = showExistingView,
    Close = hideExistingView,
})
openButton.Activated:Connect(menu.Open) -- or menu.Toggle for toggle navigation
closeButton.Activated:Connect(menu.Close)
gui.Destroying:Connect(menu.Destroy)
```

Open/Close callbacks must finish their visibility transition before returning. If
an animation leaves the panel visible until completion, wait for that animation
inside Close; do not schedule an untracked delayed hide. The manager serializes
these callbacks. The current imported major panels and generated menus already
hide immediately; existing button effects and plot-selection animations continue.

## Framewisp imports and Studio setup

After replacing `Framewisp_CCWMF.rbxmx`, run:

```text
python tools/prepare_framewisp_ui.py
```

Then sync through Rojo and restart Play. The preparation step now installs a small
FramewispActions hook requiring the canonical client FramewispMenus module, which
shares PanelManager with controllers. It no longer embeds a separate policy copy.
All other generated scripts, action handlers, attributes, artwork and hierarchy
are preserved. The hook waits for PlayerScripts.Client.UI, the stable Rojo source
mapping, rather than any import-specific ScreenGui name or referent.

Processed and retained-tag panel names (e.g. Upgrades and Upgrades_panel) work with
or without DesktopContent. Replacement panels re-register and replacement buttons
rebind through the existing descendant lifecycle. Absent/ambiguous panel targets
retain the existing no-op behavior. Authored major panels are saved hidden to
prevent a startup flash. No additional Studio objects or hierarchy edits are needed.

## Validation

Presentation-only CLI suites:

```text
python tests/run_panel_manager_tests.py --luau <luau.exe>
python tests/run_framewisp_menu_tests.py --luau <luau.exe>
python tests/run_scrapbook_ui_tests.py --luau <luau.exe>
python tests/run_state_tests.py --luau <luau.exe> --suite plot-identity
```

These pass exclusivity, rapid activation, X/reopen, yielding close/open transitions,
queued cancellation, replacement/removal, imported-to-generated switching,
Scrapbook tab preservation and management actions. Touch activation is exercised
at the mocked Activated boundary. StyLua and Rojo build pass. Roblox-aware
typecheck reports no diagnostics in the changed modules. Full-source Roblox-aware typecheck
retains the same baseline diagnostics.
The existing upgrade UI runner fails its insufficient-cash feedback assertion on
both the pre-change sources and current sources; no purchase code was changed.
The Scrapbook runner's baseline omitted BadCustomers, now an existing dependency
of CustomerRequests; its fixture/bundle includes that dependency to run the suite.

Remaining engine smoke check: in Studio Play and the mobile device emulator, open
Upgrades, Scrapbook and Plot Management rapidly in both directions, tap X, reopen,
and respawn. Exercise Index/Settings/Shop/Cosmetics when their authored panels are
available. Confirm cash/stamina, customer orders and world prompts persist, and
button effects and purchases still work. CLI fixtures do not verify engine
rendering or actual touch hardware; no live Studio playtest is claimed.
