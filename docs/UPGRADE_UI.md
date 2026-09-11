# Cash HUD and movement upgrades

The client bootstrap starts the idempotent `UpgradesController`. `UpgradesGui` creates ordinary Roblox UI instances; `UpgradeDisplay` handles shared definition lookups and feedback text. No backend, tuning, prices, or persistence changes are required.

## Hierarchy

```text
PlayerGui
└── UpgradesGui (ScreenGui, ResetOnSpawn=false)
    ├── CashHud (rounded Frame, padding, vertical list)
    │   ├── Cash (TextLabel)
    │   └── Toggle (TextButton)
    └── Panel (rounded Frame, stroke, size constraint, padding)
        ├── Title
        ├── Close (TextButton)
        └── Rows (ScrollingFrame, automatic canvas, vertical list)
            ├── MovementSpeed
            ├── SprintStamina
            └── Jump
                ├── Name
                ├── Level
                ├── Stat
                └── Purchase (TextButton)
```

Each row has the same four children. The top-right HUD stays visible while the panel toggles. The panel width is capped at 352 pixels and its height at 490 pixels; smaller viewports reduce the panel and scroll its rows. Standard button color feedback supports mouse presses. ScreenGui uses the default GUI inset.

## Data and requests

Cash reads only the server-owned `playerCash` attribute and listens for changes. Missing replication displays a loading placeholder. There is no optimistic cash deduction or local level increment.

Rows read `MovementSpeedLevel`, `SprintStaminaLevel`, and `JumpLevel`. Current speed uses `BaseWalkSpeed`; current sprint duration uses `StaminaMax / SprintConfig.STAMINA_DRAIN_RATE`, formatted as whole seconds. Jump power has no separate replicated attribute, so current power comes from the shared Jump tier indexed by the replicated effective `JumpLevel`. Next values and prices come from `Constants/Upgrades`, at displayed level + 2. Sprint speed is not displayed.

Clicking Purchase sends exactly `GameplayRequest:FireServer("PurchaseUpgrade", track.Id)`. The server-created remote also carries `PurchaseUpgradeResult`; it is separate from `GameplayPresentation`. A global pending guard disables all purchase buttons until a result or five-second timeout. No automatic retries occur. Max rows send no request.

Success briefly displays `UPGRADED!`, while attributes drive cash/stat/level refreshes regardless of response ordering. Insufficient cash displays `NOT ENOUGH CASH`. MaxLevel disables the row with `MAX`; a subsequent replicated level change clears that response flag. InvalidUpgrade warns in client output and displays `UNAVAILABLE`. A missing result or other failure displays `PLEASE TRY AGAIN`. Response levels are never copied into player attributes. At max, `MAX` takes precedence over temporary feedback.

Effective Studio overrides can differ from purchased levels. The UI intentionally displays the effective attributes, while the server continues purchasing against its owned levels; reset overrides before testing ordinary purchases.

## Validation and Studio checks

- `python tests/run_upgrade_ui_tests.py --luau <executable>`: 74 assertions passed, covering all tier lookups, seconds, loading/max states, exact request arguments, pending guards, feedback, attribute updates, and stale timeout recovery.
- `python tests/run_state_tests.py --luau <executable> --vfx-only`: 115 assertions passed.
- Full state suite and `--customer-only`: blocked by existing movement assertion `base stamina full at 110`, which conflicts with the configured baseline 60. Customer checks are not reached.
- Roblox-aware Luau LSP analysis of the three new runtime modules: passed. Including the bootstrap reports existing type errors in `StashPromptController.luau` at lines 36 and 39.
- StyLua, source compilation, Rojo build, and whitespace checks: passed.

No manually placed GUI, remotes, assets, or other Studio setup is needed; sync via the existing Rojo project. Live Studio validation remains necessary: inspect desktop and narrow/short viewport layouts, chat/player-list overlap, scrolling and clicks; purchase each tier with sufficient/insufficient cash; verify cash and stat replication, sprint duration and jump display, max buttons, two clients, respawn without duplicate HUDs, and latency/throttle recovery. CLI tests mock the engine and do not verify rendering or actual network ordering.

Files added: `src/client/UI/UpgradesGui.luau`, `src/client/UI/UpgradeDisplay.luau`, `src/client/Controllers/UpgradesController.luau`, `tests/run_upgrade_ui_tests.py`, `tests/upgrade_ui.spec.luau`, and this document. File modified: `src/client/init.client.luau`.
