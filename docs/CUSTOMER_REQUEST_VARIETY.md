# Customer request variety

## Eligibility and selection

The previous selector gave each eligible specific request the same chance.
Categories with more definitions appeared more often, and template recency
only changed which NPC model arrived. At Jump 0, Combo and Trait accounted for
13 of 26 eligible orders. At Jump 3, Recipe accounted for 11 of 44 and Color
for 3 of 44.

The regular pool uses the plot's purchased Jump tier, ingredient reachability
and whether the required tags and ingredient slots can fit in one blend after
applying restrictions. NPC-only definitions and wildcards are outside this
pool. The authored `MinJumpTier` gates fixed special requests. Ordinary requests
use the eligibility validator, which admits ten Jump 0 orders with higher
authored tier labels.

After the scripted tutorial orders, each regular arrival independently rolls
an 11% wildcard chance, up from 5% on main. The outcome stays with that encounter
through a refresh. Wildcards still pay a $250 base with applicable multipliers.
Fixed special and tutorial orders keep their own rules, and the special
wildcard probability is zero.

### Relative weights for specific requests

| Condition | Weight multiplier |
| --- | ---: |
| Any eligible request, before repeat adjustments | 1.00 |
| Same request ID or equivalent authored requirements as any of the last three specific orders | 0.20 |
| Same type as the last specific order | 0.55 |
| Shares a named required ingredient with the last specific order | 0.65 |

The server multiplies applicable factors and picks one order with probability
equal to its weight divided by the total. All weights are positive, including
when every available order repeats something. Tag case and the order of tags,
ingredient slots, or alternatives do not affect requirement matching. Slot
multiplicity and the distinction between exact and flexible recipes are
preserved. Named-ingredient overlap uses required slots and their alternatives.
`SimilarityKeys` are catalog metadata and carry no selection weight.

Teammates share the plot session's last three specific regular orders. Wildcards,
specials and tutorial orders leave that history alone. Flow restarts keep
history. Session cleanup clears it. An explicit request refresh adds to history
when it changes a specific regular order.

## Seeded simulation

Run `python tests/run_state_tests.py --suite customer-order-simulation --luau /path/to/luau`.
The simulation runs 10,000 regular arrivals per Jump tier per mode, for 80,000
arrivals total. Both modes use the production validator, selector and 11%
wildcard rate. The uniform comparison supplies empty history with the same
random draws. These results measure generated orders at a fixed Jump tier.

### Weighted frequency across all regular arrivals

| Jump tier | Eligible specific orders | Color | Trait | Combo | Restriction | Ingredient | Recipe | Wildcard |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 26 | 10.67% | 20.27% | 22.89% | 17.51% | 7.15% | 10.78% | 10.73% |
| 1 | 33 | 8.09% | 21.45% | 23.57% | 13.55% | 7.99% | 13.87% | 11.48% |
| 2 | 41 | 7.03% | 19.23% | 19.57% | 11.56% | 12.44% | 19.23% | 10.94% |
| 3 | 44 | 5.85% | 17.94% | 18.29% | 10.64% | 14.30% | 21.53% | 11.45% |

### Repeat and streak rates, uniform → weighted

Percentages use adjacent arrivals where both orders were specific. A wildcard
breaks the measured streak and leaves the selector's specific history intact.

| Jump tier | Exact requirements | Same type | Named ingredient overlap | Longest specific type streak | Specific type streaks of 3+ |
| --- | ---: | ---: | ---: | ---: | ---: |
| 0 | 4.11% → 0.50% | 18.72% → 9.77% | 1.49% → 0.58% | 7 → 4 | 239 → 64 |
| 1 | 2.91% → 0.33% | 18.96% → 10.49% | 1.77% → 0.64% | 7 → 4 | 231 → 68 |
| 2 | 2.43% → 0.28% | 18.04% → 9.87% | 2.98% → 1.14% | 6 → 5 | 199 → 52 |
| 3 | 1.95% → 0.22% | 17.91% → 9.82% | 2.91% → 1.22% | 6 → 5 | 198 → 52 |

Wildcard runs peaked at three or four consecutive orders, with 4–14 runs of
three or more per 10,000 arrivals. The first five regular arrivals on 1,000
simulated fresh Jump 0 plots averaged 3.39 different specific types with weights,
up from 3.16 with uniform draws.

## Follow-up improvements

- Measure request type, purchased Jump tier, time to serve and payout when
  players reveal and serve orders. Use those results to decide whether the
  first few regular orders need additional variety or the frequency of any
  specific type needs tuning. The simulation already shows broader early
  exposure without prescribing an order sequence.
- All five restriction orders pass the validator at Jump 0 and have base
  payouts of $250–$1,000. Playtest the time and contention involved in
  fulfilling them with fresh plots and regular market traffic. Compare cash per
  minute with unrestricted orders to see whether the more demanding
  combinations need a reward adjustment. The validator assumes accessible
  catalog ingredients can be obtained over time.
