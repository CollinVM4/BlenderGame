# Customer request variety

## How orders are drawn

- After the tutorial, a regular customer has a 16% chance to ask for a wildcard
  order, up from 5%. These are independent rolls, so two consecutive regular
  customers both ask for a wildcard 2.56% of the time. The roll is saved on the
  customer when its order is assigned. Wildcards pay a $250 base with applicable
  multipliers, and ingredient value contributes $0.
- On the other 84% of regular arrivals, the server draws one uniform random
  index from the full pool of eligible specific requests. Eligibility uses the
  purchased Jump tier, ingredient reachability and whether the requirements can
  fit together in one blend. `MinJumpTier` on a regular definition does not gate
  this draw. Ten JL0-eligible requests have higher authored tier labels.
- The last three regular **NPC templates** are avoided where alternatives exist.
  Specific requests have no history filter. The October economy rework removed
  order recency, and `RegularRequestRecencyWindow`,
  `RegularRequestGroupRecencyWindow` and `RegularRequestSimilarityRecencyWindow`
  are unused. `RequestGroup` and `SimilarityKeys` describe the catalog and carry
  no selection weight. A different NPC or dialogue line can carry the same order.
- Scripted tutorial orders and fixed special requests follow their own
  definitions. The special wildcard roll is disabled. The special arrival check
  can replace a regular arrival when a valid special template is available and
  the plot's 300-second special cooldown permits it.

## Request frequency by purchased Jump tier

The table counts catalog entries that pass the production request validator at
each tier, excluding NPC-only and wildcard definitions. Percentages are
conditional on a regular customer drawing a specific request. Multiply by
0.84 for the share of **all regular arrivals** at the new wildcard rate.
For example, JL0 Combo is 7 of 26 specific requests, or 22.6% of regular arrivals.

| Jump tier | Eligible | Color | Trait | Combo | Restriction | Ingredient | Recipe |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 26 | 11.5% | 23.1% | 26.9% | 19.2% | 7.7% | 11.5% |
| 1 | 33 | 9.1% | 24.2% | 27.3% | 15.2% | 9.1% | 15.2% |
| 2 | 41 | 7.3% | 22.0% | 22.0% | 12.2% | 14.6% | 22.0% |
| 3 | 44 | 6.8% | 20.5% | 20.5% | 11.4% | 15.9% | 25.0% |

For two specific draws at the same Jump tier, the following chances come from
enumerating all ordered pairs of eligible requests. The same-ID column also
counts toward the same-group column.

| Jump tier | Same request ID | Same request group | Different IDs sharing a similarity key |
| --- | ---: | ---: | ---: |
| 0 | 3.85% | 19.53% | 11.54% |
| 1 | 3.03% | 19.56% | 10.28% |
| 2 | 2.44% | 18.62% | 9.16% |
| 3 | 2.27% | 18.90% | 8.57% |

These are catalog probabilities. The orders players reveal and serve can have a
different mix once queue behavior, special arrivals and ingredient availability
are factored in.

## Follow-up improvements

1. Start with a per-plot-session preference against the last two or three
   specific request IDs. Keep draws random among eligible IDs outside the
   window, and use the full eligible pool when the window would leave it empty.
   Keep wildcard rolls independent and have them leave specific-order history
   intact. This also lets teammates share repeat protection at their counter.
2. Track the group and request ID on order reveal and serve, with purchased
   Jump tier and serve time. If near-repeats still feel common, prefer fewer
   overlaps with the last specific order's similarity keys. Use the observed
   group mix and serve times to tune explicit weights if needed, especially for
   early Combo orders and late Recipes.
3. Review above-label JL0 orders against a real starter plot and market inventory.
   The validator checks whether the recipe is possible with the catalog at that
   tier. Playtesting can identify orders that are valid but bottlenecked by
   shared spawns or requiring multiple copies of one ingredient.
