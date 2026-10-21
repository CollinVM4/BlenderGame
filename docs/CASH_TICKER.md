# Cash ticker

`CashTicker` counts the displayed number up or down inside the authored `{Coins}`
label. The label stays visible and is the only renderer, preserving its font,
stroke, alignment, position, currency prefix and separators from `MoneyFormat.Full`.
No digit wheels, overlays, text measurement or clipping containers are created.

`CashTickerModel` owns the continuous value, Cubic Out interpolation and duration.
Timing constants remain in `Constants/CashFeedback`. RenderStepped connects only
while counting. Retargets continue from the last rendered sample; same-target
pokes preserve the active easing clock. Completion writes the exact target.
Render failures stop the loop and attempt to snap to the correct balance.

The upgrade controller routes known replicated cash through the ticker, binds
replacement labels through the HUD observer, and snaps on respawn. Unknown cash
clears the ticker and displays `$—`; when cash returns, the label is rebound.
`playerCash` remains authoritative. `CashRewardAnimation` is unchanged: its arrival
poke confirms/retargets the count, and its existing CashDisplay punch still runs.

No Studio setup is required beyond the existing semantic CashDisplay/Cash HUD.

Validation commands:

```text
python tests/run_cash_reward_tests.py --luau <luau>
python tests/run_upgrade_ui_tests.py --luau <luau>
```

The first runner covers production ticker/model and reward contracts; the second
checks controller routing with a ticker boundary stub. Also run Roblox-aware
changed-module typecheck, changed-file StyLua and Rojo build.

Studio acceptance remains manual: serve a customer and check the fast count with
icon arrival/punch; buy an upgrade and check the downward count; make rapid sales
and check continuity/exact settlement; respawn and check immediate balance; verify
the authored label is unchanged at rest. CLI doubles do not verify visual timing
or Roblox rendering.
