# Cash ticker

`CashTicker` overlays clipped digit strips on the authored cash label. The upgrade
controller continues writing formatted cash text for fallback, binds replacement
labels through its existing HUD observer, retargets replicated balance changes,
and snaps on respawn. `CashRewardAnimation` pokes the same target on icon arrival;
the existing CashDisplay scale punch also scales the wheels.

`CashTickerModel` owns the continuous value, Cubic Out interpolation, duration,
and digit count. Timing constants live in `Constants/CashFeedback`. RenderStepped
is connected only during a roll. Retargeting preserves the last rendered value;
leading wheels remain until settlement when spending reduces the digit count.

The requested continuous formula is `(displayValue / 10^place) % 10`. At 999.5,
the thousands offset is 0.9995 digit cells, approximately one tenth of a wheel
turn (not 0.95 turns). During rolling the view uses that formula; at rest it seats
each wheel on its whole digit, since otherwise 95 would leave the tens wheel
halfway between 9 and 0. Digits contain no currency prefix or commas; authored
icon siblings remain untouched. Construction/render failures restore the label.

No Studio setup is required beyond the existing semantic CashDisplay/Cash HUD.
The ticker creates passive Frames and TextLabels only.

Validation commands:

```text
python tests/run_cash_reward_tests.py --luau <luau>
python tests/run_upgrade_ui_tests.py --luau <luau>
```

The first runner includes the production ticker/model contracts; the second
checks controller routing at the presentation boundary. Also run Roblox-aware
typecheck, changed-file StyLua, and Rojo build.

Studio acceptance remains manual: serve a customer and check flight/arrival
timing and punch; spend on an upgrade; make three rapid sales; respawn; resize
to mobile and tap top-bar controls; replace the imported HUD. CLI doubles do not
verify engine text metrics, actual clipping, touch routing, or perceived timing.

This pass: cash reward/ticker contracts and both upgrade UI startup variants pass.
Changed runtime modules pass Roblox-aware typecheck; changed Luau files pass
StyLua; Rojo build and whitespace checks pass. The existing `customer-payout`
suite fails in `StandIdentity.Truncate` on a missing fixture name, and
`customer-payout-serve` fails its cash/grade assertion. Both failures reproduce
unchanged in a clean archive of HEAD; no server payout code was changed.
