# Approved economy rebalance

Implemented all 53 canonical ingredient prices, the listed upgrade/farm costs,
and serve rates 3,000 / 4,000 / 6,000 / 8,000 by Jump tier. Only configuration
changes affect production behavior. Ingredient IDs, aliases, tags, rarity,
JumpLocation, upgrade effects, spawn cadence, announcements, order evaluation,
ripeness, origin multipliers, filler rules, tutorial floors, and task reward-lock
logic are unchanged. Rainbow_Trout and Mystery now explicitly reject farming;
the three previous premium opt-outs remain.

## Purchase and payout acceptance

Paid steps use array index step + 1. Speed/Stamina steps 1?11 remain unchanged;
their step 12 prices are 40,000 / 34,000. Full-track totals are now 344,000 /
236,500. Farm rows cost 20,000 / 55,000 / 110,000. The server/UI integration
checks every next displayed upgrade price against the authoritative next charge;
the farm presentation suite checks all three row labels.

The actual first Red serve still awards its 30,000 floor, and a cross-system
tutorial test buys Jump 1 (10,000) and Bat 1 (20,000) with that cash. Carry 5
remains 30,000. Serve task blocks remain 3, then 7, then recurring 10; replay
checks cover the first, tenth, and recurring crossings. Tier changes apply only
at the existing activation/lock boundary. Tutorial and steal rewards are unchanged.

With request base 250, grade A, fresh matching Market ingredients, no boosts:

| Jump | Regular median per unit | Rounded three-unit payout |
|---|---:|---:|
| 0 | 2,500 | 9,688 |
| 1 | 4,500 | 18,906 |
| 2 | 6,000 | 28,516 |
| 3 | 8,000 | 45,469 |

Two matching ground units at 2,500 plus one matching tier-3 Market unit at 8,000
pay 24,844. These are formula tests, outside tutorial and task grants. Existing
checks retain full effective matching value, discounted/capped filler, and no
tower multiplier from a higher-floor filler. Catalog cards and effective-value
lookups are checked against all 53 approved shared values.

## Muncher tuning

Final bounds use the proposed bands:

| Tier | Minimum | Interpolation maximum | Ordinary floor example | Non-pity Dragon Fruit odds |
|---|---:|---:|---|---:|
| Cheap | 1,500 | 3,499 | Rock / Worm | 0.2% |
| Standard | 3,500 | 5,499 | Mushrooms / Tire / Cactus | 0.5% |
| Premium | 5,500 | 7,999 | Milk / French Fries | 1% |
| High Roller | 8,000 | 45,000 | Golden Potato / Golden Tomato | 2% |

Pool changes (weights in basis points):

- Cheap: Rock 8,000; Worm 1,000; Apple 200; Ice 150; Banana 150;
  Strawberry 125; Shit 75; Mushrooms 100; Orange 75; Watermelon 75;
  Protein 30; Dragon Fruit 20. This reduces fresh floor EV from 1,816 to 1,698.50.
- Standard: replace 4,000 of Mushrooms' original 6,000 weight with Rock.
  All other weights remain unchanged. Fresh floor EV falls from 4,052.50 to 3,252.50.
- Premium: no weight or membership changes.
- Standard and High Roller are reordered by the new catalog values, retaining
  ascending order for interpolation. Rainbow Trout remains a High Roller reward
  at 400 base basis points, immediately before Dragon Fruit.

Each pool still totals 10,000. Purchase price remains 100,000. Five-loss pity,
70% interpolation, 500 bp per-generation chain shift capped at five stacks, and
jackpot mass are unchanged. Pity continues to condition on strictly higher-value
outputs and ignores generation; its conditional jackpot odds can therefore
exceed the non-pity odds above, exactly as before.

Expected **catalog output value**, before serving and without assigning value to
matching tags, travel, machine time, or purchase amortization:

| Input | Tier | Fresh non-pity EV | Repeated fresh input, including pity | Generation 5 non-pity EV |
|---|---|---:|---:|---:|
| 1,500 | Cheap | 1,698.50 | 1,698.50 | 1,587.00 |
| 2,000 | Cheap | 1,966.57 | 2,071.96 | 1,601.44 |
| 2,500 | Cheap | 2,234.63 | 2,294.23 | 1,766.73 |
| 3,500 | Standard | 3,252.50 | 3,265.02 | 2,469.71 |
| 4,500 | Standard | 3,850.17 | 3,880.42 | 3,343.07 |
| 5,000 | Standard | 4,149.00 | 4,486.34 | 3,745.11 |
| 5,500 | Premium | 5,855.00 | 5,904.58 | 5,278.61 |
| 6,000 | Premium | 6,023.52 | 6,078.37 | 5,369.68 |
| 7,000 | Premium | 6,360.57 | 6,577.18 | 6,133.80 |
| 8,000 | High Roller | 8,750.00 | 8,926.67 | 7,665.00 |
| 9,000 | High Roller | 8,770.14 | 11,208.34 | 8,040.34 |
| 13,000 | High Roller | 8,850.70 | 11,928.42 | 8,081.71 |
| 24,000 | High Roller | 9,072.25 | 14,047.18 | 9,072.25 |
| 30,000 | High Roller | 9,193.09 | 14,863.60 | 9,193.09 |
| 45,000 | High Roller | 9,495.19 | 15,117.86 | 9,495.19 |

The repeat column is the exact stationary mean for continually supplying the
same fresh input to one machine. With loss probability L, pity frequency is
L^5 / (1 + L + ... + L^5); pushes reset the streak. It is distinct from reinserting
outputs, which changes input value, tier, and generation on every roll.

Cheap's floor has no lower-valued catalog outcome: positive jackpot odds make a
positive catalog return unavoidable. Its remaining fresh-input premium is 13.23%;
generation 5 reduces it to 5.8%. Floor pushes never build pity. Standard's repeated
floor return is 93.29%; at generation 5, including pity, it is 2,593.25 (74.09%).

Exact output-reinsertion distributions (including loss streaks and generation):

| Starting item | After 1 roll | After 6 rolls | After 25 rolls |
|---|---:|---:|---:|
| Rock (1,500) | 1,698.50 | 1,644.98 | 1,639.77 |
| Mushrooms (3,500) | 3,252.50 | 1,779.63 | 1,639.78 |

Remaining tuning findings: Premium/High Roller floor inputs retain positive
fresh EV; pity also makes repeated fresh 2,000 and 9,000 inputs positive EV.
This pass reduces the specified Cheap/Standard floor premiums without changing
pity or jackpot policy. These catalog expectations do not establish cash/minute.

## Premium supply and Studio follow-up

Studio is running, but there is no connected document session and both native
computer-use entry points fail with ?native pipe is unavailable ... os error 2.?
No authored Workspace spawn inventory or live route timing could be verified.
The checked-in model assets contain no Rainbow Trout/Mystery spawn definitions.

Code-visible supply paths retained for this pass:

- An ordinary IngredientSpawn or MarketService marker for Rainbow_Trout would
  refill in 3 seconds (JumpLocation 0); Mystery would refill in 90 seconds
  (JumpLocation 3). Neither has a special refill override. Their existence in the
  live scene is unverified. This is the main repeatable-premium authoring risk.
- AnnouncedIngredientSpawn retains authored RespawnSeconds or min/max bounds;
  absent valid timing it defaults to 5 seconds. Inspect the live markers' actual
  attributes and ensure they have only one spawn tag.
- Muncher can repeatedly supply Rainbow Trout through High Roller. Mystery is
  excluded from Muncher reward pools. Muncher output origin cannot activate the
  Market/Event bonus.
- Lucky Block catalog rolls can include both premiums in eligible tier-based
  or MysteryBox rewards, but LuckyBlockConfig.Enabled is currently false.
- Farming now rejects both premiums without consuming the selected held item.

No new Studio objects are required. Sync with Rojo, inspect the actual two spawn
sources/tags/timing, and sample comparable ground-only and mixed-floor routes.
Record elapsed travel/refill time, order quality, boosts, served cash, and task
cash separately. Neither route has an observed cash/minute result in this pass.

## Validation

- State: **5/5 suites pass**: economy-config, customer-payout, tutorial, tasks,
  muncher-rewards.
- Integration: **11/11 suites pass**: customer-payout-serve, tutorial-gameplay,
  tutorial-payout-serve, upgrade-sync, farm, farm-boost, tasks-serve, tasks-steal,
  muncher, economy-origin, economy-supply. No baseline failures in these suites.
- Presentation: upgrade UI runner passes with UI initially absent and present;
  farm presentation runner passes (23 assertions). Presentation runs separately.
- All five changed runtime constants pass Roblox-aware luau-lsp typechecking.
- Full-source typecheck fails with **212 TypeError headers**, exactly matching
  an isolated HEAD snapshot after normalizing source paths; zero added/removed.
- Changed-file StyLua passes. Repository-wide `stylua --check src tests` fails on
  **148 existing files**; every failing file also fails on isolated HEAD using
  the same local configuration. Unrelated formatting was not changed.
- Default-project Rojo 7.7 build passes. `git diff --check` passes.

Focused runners use `.validation-tools/luau.exe` via `--luau`; gameplay suites
are selected with `python tests/run_state_tests.py --suite <name>`.
Presentation uses `tests/run_upgrade_ui_tests.py` and
`tests/run_farm_presentation_tests.py`. Muncher EV/distribution calculations are
printed by the muncher-rewards suite and require no Monte Carlo sampling.

Changed production files: `src/shared/Constants/{Ingredients,Upgrades,FarmConfig,
TasksConfig,Muncher}.luau`. Updated test homes: customer payout/serve, economy
origin, farm/presentation, Muncher rewards, tasks, tutorial gameplay, upgrade
sync/UI. Added economy_config.spec.luau and registered it in run_state_tests.py.
