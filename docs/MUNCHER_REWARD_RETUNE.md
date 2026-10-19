# Muncher non-blocking hint and reward retune - review

2026-10-19. Provisional inputs to Pass 3 telemetry. **Implemented and automated checks pass; Studio/device acceptance and Collin review remain pending. No merge performed.** This supersedes the rates in the casino pass.

## Policy and constraint conflicts

The final guardrail is **EV <= 110% of input** at tier floor/midpoint/ceiling. The approved **sub-$1,053 Cheap lottery exemption is explicitly retained**, with 99% return-your-Rock at $1,000. All eleven non-exempt requested sample points and every non-exempt current catalog input pass. This is an offline balance assertion, not a runtime payout limiter.

The requested $1,053 cutoff is mathematically insufficient: even the theoretical minimum EV is `0.998 * 1000 + 0.002 * 165000 = $1,328`, which needs input >= $1,207.2727 to meet 110%, before any upgrade shift or other outputs. Tests explicitly record the failure at $1,053; they do not broaden the approved exemption or claim arbitrary positive-valued inputs pass.

Strictly higher win rates at every sample are also impossible with the unchanged output lists/jackpots: Cheap floor fixes 99% Rock/push and 1% wins; Cheap ceiling has only the 0.2% jackpot above input; High Roller midpoint has only the 2% jackpot above input; at its $165K ceiling the jackpot is a push and no output can win. These four samples retain their prior win rates. All eight other samples improve by more than one percentage point. High Roller remains loss-heavy for expensive inputs despite better EV; changing that would require a separate output-list/jackpot decision.

## Weights

Base weights are basis points (10,000 = 100%). For `t = clamp((inputValue - tierMin) / (tierMax - tierMin), 0, 1)`, transfer **t * 70%** of the first two entries' mass proportionally to the next two. Dragon Fruit is excluded from transfer. Selection retains fractional basis points; rounding below is display only. Tier thresholds, saturation ceiling, ordered outputs, server selection and PlayerHead $5K fallback/exclusion are unchanged. Cheap base weights stay unchanged to preserve its 99% Rock floor.

| Tier | Output | Value | Floor bp | Midpoint bp | Ceiling bp |
|---|---|---:|---:|---:|---:|
| Cheap | Rock | $1,000 | 9,900 | 6,435.0000 | 2,970.0000 |
| Cheap | Apple | $1,500 | 50 | 32.5000 | 15.0000 |
| Cheap | Banana | $2,000 | 20 | 2,341.6667 | 4,663.3333 |
| Cheap | Mushrooms | $3,000 | 10 | 1,170.8333 | 2,331.6667 |
| Cheap | Dragon_Fruit | $165,000 | 20 | 20.0000 | 20.0000 |
| Standard | Mushrooms | $3,000 | 7,800 | 5,070.0000 | 2,340.0000 |
| Standard | Protein | $5,000 | 600 | 390.0000 | 180.0000 |
| Standard | Pear | $10,000 | 1,200 | 3,476.1290 | 5,752.2581 |
| Standard | Honey | $22,000 | 350 | 1,013.8710 | 1,677.7419 |
| Standard | Dragon_Fruit | $165,000 | 50 | 50.0000 | 50.0000 |
| Premium | Pear | $10,000 | 5,400 | 3,510.0000 | 1,620.0000 |
| Premium | Honey | $22,000 | 2,000 | 1,300.0000 | 600.0000 |
| Premium | Crab | $35,000 | 2,000 | 4,072.0000 | 6,144.0000 |
| Premium | Golden_Potato | $60,000 | 500 | 1,018.0000 | 1,536.0000 |
| Premium | Dragon_Fruit | $165,000 | 100 | 100.0000 | 100.0000 |
| High Roller | Coconut | $25,000 | 2,500 | 1,625.0000 | 750.0000 |
| High Roller | Crab | $35,000 | 1,700 | 1,105.0000 | 510.0000 |
| High Roller | Golden_Potato | $60,000 | 3,400 | 4,292.5000 | 5,185.0000 |
| High Roller | Pizza | $75,000 | 2,200 | 2,777.5000 | 3,355.0000 |
| High Roller | Dragon_Fruit | $165,000 | 200 | 200.0000 | 200.0000 |

Jackpot odds are exactly **0.2% / 0.5% / 1% / 2%** at every input. Non-Cheap outputs are all at least 50% of their tier floor; Cheap Rock weight falls from 99% to 29.7% across its tier.

## EV and win/push/loss

Win means output catalog value > input; equal value is a push. Midpoints are arithmetic tier midpoints, including half dollars. Prior win rates use the incoming working-tree casino pools and their 50% shift. Percentages are rounded to four decimals.

| Tier | Sample | Input | EV | EV/input | Win % | Push % | Loss % | Prior win % | 110% check |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| Cheap | Floor | $1,000.00 | $1,334.50 | 133.45% | 1.0000 | 99.0000 | 0.0000 | 1.0000 | Exempt Cheap floor |
| Cheap | Midpoint | $2,999.50 | $1,797.96 | 59.94% | 11.9083 | 0.0000 | 88.0917 | 8.5917 | PASS |
| Cheap | Ceiling | $4,999.00 | $2,261.42 | 45.24% | 0.2000 | 0.0000 | 99.8000 | 0.2000 | PASS |
| Standard | Floor | $5,000.00 | $5,435.00 | 108.70% | 16.0000 | 6.0000 | 78.0000 | 6.0000 | PASS |
| Standard | Midpoint | $12,499.50 | $8,247.65 | 65.98% | 10.6387 | 0.0000 | 89.3613 | 3.1364 | PASS |
| Standard | Ceiling | $19,999.00 | $11,060.29 | 55.30% | 17.2774 | 0.0000 | 82.7226 | 5.2727 | PASS |
| Premium | Floor | $20,000.00 | $21,450.00 | 107.25% | 46.0000 | 0.0000 | 54.0000 | 40.0000 | PASS |
| Premium | Midpoint | $34,999.50 | $28,380.00 | 81.09% | 51.9000 | 0.0000 | 48.1000 | 36.2500 | PASS |
| Premium | Ceiling | $49,999.00 | $35,310.00 | 70.62% | 16.3600 | 0.0000 | 83.6400 | 9.0714 | PASS |
| High Roller | Floor | $50,000.00 | $52,400.00 | 104.80% | 58.0000 | 0.0000 | 42.0000 | 29.0000 | PASS |
| High Roller | Midpoint | $107,500.00 | $57,816.25 | 53.78% | 2.0000 | 0.0000 | 98.0000 | 2.0000 | PASS |
| High Roller | Ceiling | $165,000.00 | $63,232.50 | 38.32% | 0.0000 | 2.0000 | 98.0000 | 0.0000 | PASS |

With these actual Cheap weights and the 70% shift, EV at $1,053 is **$1,346.78**; the continuous Cheap EV/input ratio falls to 110% only at approximately **$1,270.0950**. The interval from $1,053 to that crossover remains an unresolved constraint conflict, outside the approved exemption. No current catalog ingredient occupies that interval. Eligibility is unchanged.

## Worst-case individual degrade

Degrade = `(input - lowest possible output) / input`. Minimum outputs retain positive probability even at the ceiling. These are worst single outcomes, not average returns; inputs beyond High Roller's saturation ceiling can degrade further.

| Tier | Lowest output | At floor | At midpoint | At ceiling | Max loss in tier range |
|---|---:|---:|---:|---:|---:|
| Cheap | $1,000 | 0.00% | 66.66% | 80.00% | $3,999 (80.00%) |
| Standard | $3,000 | 40.00% | 76.00% | 85.00% | $16,999 (85.00%) |
| Premium | $10,000 | 50.00% | 71.43% | 80.00% | $39,999 (80.00%) |
| High Roller | $25,000 | 50.00% | 76.74% | 84.85% | $140,000 (84.85%) |

## Decorative input behavior

`MuncherHint` already set its BillboardGui `Active = false`; its sole TextLabel now explicitly does too. The whole input-capable subtree is inactive. UIStroke and UIPadding are UIComponents without an Active property; assigning it would raise an engine error. The existing outline remains unchanged. Audit found no `Active = true` in Muncher presentation modules. No visibility, text, colors, timings, result labeling, or throw-input code changed. The separate prompt rule `Active = not paddedTouch` is unchanged.

The incoming controller displays FEED ME/BUSY through this hint; result accents live in MuncherEffects. This pass adds no result-banner behavior. Any text displayed through the hint label inherits the same inactivity.

## Validation and Studio handoff

- `muncher-rewards`: normalization, exact 70% transfer, 110% cap with explicit Cheap floor exemption, $1,053 conflict, catalog inputs, win/push/loss reporting versus prior pools, fixed jackpots and fractional selection boundaries.
- `muncher-presentation`: real controller hint creation, root/label/subtree inactivity, FEED ME and busy-banner expiry; existing reel/result/timing/lifecycle contracts retained.
- `muncher`, `muncher-vacuum`, `gameplay-audio`, and the unchanged native ThrowHeld route in `carry-input`: PASS.
- Roblox-aware luau-lsp on all three changed production modules with fresh Rojo sourcemap/Roblox definitions: PASS. StyLua on all five changed Luau files and Rojo 7.7 full place build: PASS.

**Studio and real-device verification: PENDING, not claimed.** The available tool surface exposes no node_repl/Windows automation or Studio execution connector; physical device input cannot be verified by CLI fixtures. No Studio setup changes are required by this pass. Keep the existing authored DisplayScreen BasePart with outward Front face.

On desktop and mobile, feed each tier in a real session. Repeatedly throw while FEED ME overlaps the world/Throw button; repeat with any result banner and BUSY flash visible. Verify eligible hint show/hide, visitor restrictions, unchanged expiry/chew/spit/reel timing, output labels and actual session feel. Record device/viewport and observations. Native GUI hit-testing must be checked in Studio/device, independently of passing policy tests.

Collin reviews this table and the two constraint conflicts before merge. The $1,053 conflict and four unchanged win samples are reported limitations, not accepted changes to the requested requirements.

Changed production files: `src/client/Controllers/MuncherPresentationController.luau`, `src/shared/Constants/Muncher.luau`, `src/server/Services/MuncherRewards.luau`. Tests: `tests/muncher_rewards.spec.luau`, `tests/muncher_presentation.spec.luau`. Docs: this review and the superseding link in `docs/MUNCHER_CASINO_POLISH.md`. Pre-existing working-tree edits were preserved.
