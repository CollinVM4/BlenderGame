# Economy redesign ? 2026-10-23

Implemented the revised payout, request access/selection, refill/farm, and CarryCapacity pass. Values are initial Studio tuning constants. The separate movement/stat pass may coexist in this working tree; this economy change does not set those tracks.

## Behavior and tuning

- `Economy.FillerValueFraction = 0.25`, `FillerCapFraction = 0.5`. Relevant ingredients pay full per-unit value, including ripeness. Filler contributes `min(fillerValue * 0.25, onRequestValue * 0.5)`. Zero matching value produces zero filler value. This bounds filler within a drink; it does not establish an ordering across different blends.
- `Economy.OriginMultiplier = { [0] = 1, [1] = 1.1, [2] = 1.25, [3] = 1.5 }`. The highest relevant Market/Event ingredient's JumpLocation multiplies the entire drink, including relevant farm production and the request base. This rewards tower-sourced loot; it does not verify climbing. Stolen loot keeps its provenance.
- Normal payout: `(effectiveValue + BasePayout) * origin * grade * upgrade * entitlement * muncher`, rounded once. The payout API's display subtotal is effectiveValue. Carried/stored catalog-value displays retain their existing meaning.
- Wildcard payout: `BasePayout * upgrade * entitlement * muncher`; returned ingredient subtotal is zero. Regular wildcard chance is 0.05; Special remains zero. With modifiers disabled, a regular post-tutorial wildcard pays $250.
- Tutorial floors remain in Serve, after payout calculation and only for valid successful tutorial records.
- Ordinary requests use physical accessibility and joint satisfiability at the purchased session Jump tier. Tags share the evaluator's tag-group matching. Alternative slots, forbidden ingredients/tags, and exact-size restrictions are considered together within `Economy.MaxIngredients`. Repeated catalog IDs can use distinct world copies; availability is assumed over time. Empty requirements are eligible. NPCOnly and explicit Wildcard definitions are excluded from the regular pool.
- Regular prompt selection uses one uniform index over the entire eligible pool, including immediate repeats. Retired regular request recency/group/similarity state was removed because no other path consumed it. Template recency and special/fixed request gating remain intact.
- `Economy.RefillSeconds`: JL0/JL1/JL2/JL3 = 3/12/40/90 seconds. Both MarketService and the actual IngredientSpawn component use it. Ordinary marker RespawnSeconds attributes no longer control refill. AnnouncedIngredientSpawn keeps its authored RespawnSeconds / MinRespawnSeconds / MaxRespawnSeconds behavior.
- `Economy.SpecialRefillSeconds.Gummy_Bear = 300` overrides JL0. This is an explicit placeholder, not a recovered authored value. Gummy Bear is now unplantable; existing Player Head and Dragon Fruit exclusions remain.
- A row's grow duration is refill time multiplied by its three validated grow markers: 9/36/120/270 seconds. This gives per-unit parity between **one row and one pedestal**. More rows deliberately increase total farm supply. FarmConfig.GrowSeconds and Economy.MarketRespawnSeconds are retired.
- CarryCapacity 3/5/7 costs 0/30,000/150,000. Other upgrade tracks are outside this economy pass.

Capacity evidence: BlendService rejects input once ingredient count reaches Economy.MaxIngredients and switches to READY at that count; progress also requires a full batch. CustomerOrderEvaluation rejects both underfilled and overfilled smoothies. Eligibility uses that same constant, currently three.

## Creation-path provenance audit

Origin is stored in the authoritative ingredient record, never read from client attributes. Item.New assigns it at creation (Unknown unless explicitly supplied). IngredientService.Spawn uses options.Origin only for its fresh-record branch; options.Item is cloned without restamping, including legacy missing origins. Unknown/missing origins never qualify for the premium.

| Producer | Origin |
|---|---|
| MarketService pedestal stock and SpawnDrop | Market |
| Ordinary IngredientSpawn world markers | Market |
| AnnouncedIngredientSpawn output through IngredientSpawn.Bind | Event |
| FarmService grow output | Farm |
| MuncherOutput.Spawn | Muncher |
| PlayerHeadDropService's fresh unit | Unknown |
| InventoryService.GrantIngredient, including JackedNoob protein grants | Unknown |
| InventoryService blend-input record assembly fallbacks | Unknown |
| DevContentService SpawnIngredient / PrepareCombination | Unknown |
| LuckyBlockService | No ingredient producer; powerup rewards only |
| Tutorial | Normal world/carry/stash flow; no separate record minting |

Item.CopyAll, inventory theft/drop/throw/re-pickup, stash, blender and smoothie copies preserve the record's origin. Origin is not reset by spawning an existing record.

Gummy Bear scene limitation: the repository contains the ordinary IngredientSpawn and MarketPedestal code paths, but not the live waterfall pedestal/place authoring or its intended secret timer. Both ordinary paths now apply the Gummy_Bear exemption before the tier rate, so either registration is protected. Confirm the waterfall's actual tag and set the intended constant in Studio; no authored cadence was inferred.

## Current-catalog evaluator results

The request's acceptance example assumes Strawberry costs $500. This checkout's catalog has **Strawberry = $2,000**, the same value as Cherries. Its price was preserved. With the actual Red evaluator, BasePayout $250, fresh ingredients and no paid multipliers:

| Legal blend | Relevant value | Capped filler | Effective value | Grade | Cash |
|---|---:|---:|---:|---|---:|
| Cherries + Cherries + Strawberry | $6,000 | $0 | $6,000 | A | $7,813 |
| Cherries + Strawberry + Melon | $4,000 | $2,000 | $6,000 | B | $6,875 |
| Cherries + Cherries + Melon | $4,000 | $2,000 | $6,000 | B | $6,875 |
| Crab + Cherries + Strawberry, farm Crab | $39,000 | $0 | $39,000 | A | $49,063 |
| Crab + Cherries + Strawberry, market Crab | $39,000 | $0 | $39,000 | A | $61,328 |

The Crab chain uses exactly 1.25 for Market versus 1 for Farm before the final integer rounding. Off-request Market Melon never supplies a premium. A relevant Market Pear can multiply a drink containing relevant Farm Melon, intentionally.

Catalog-priced cap checks use complete legal blends: Cherries plus Melon filler contributes $1,000 at most; Pear plus Crab filler contributes $5,000 at most. Ripeness tests verify that relevant and filler unit subtotals reconstruct GetSmoothieValue before discounting.

## Ground-floor demand audit

At Jump tier 3, **18 of 44 eligible regular requests (40.9%)** require at least one JL0 ingredient under the requested authored-slot/tag-carrier criterion. A concrete ground-floor dependency remains; no new prompts were authored.

| Request | Ground-floor dependency |
|---|---|
| Mushroom | Mushrooms tag |
| Cold | Cold tag |
| Lemon | Sour tag |
| Watermelon | Watermelon tag |
| SweetCold | Cold tag |
| SweetSour | Sour tag |
| ColdNoFruit | Cold tag |
| SweetColdNoSpicy | Cold tag |
| MilkPurple | Purple tag |
| AppleBananaIce | Apple/Green_Apple alternative slot; Banana; Ice |
| BerryTrio | Strawberry; Blueberry; Cherries |
| SaladSmoothie | Cabbage; Carrot; Onion |
| AppleSour | Apple; Sour tag |
| SpicyPineapple | Ice |
| MushroomOnion | Mushrooms; Onion |
| JunkFoodDisaster | Ice |
| BreakfastDisaster | Banana; Worm |
| BeachSmoothie | Ice |

Tag dependencies mean every catalog carrier is JL0. Alternative-slot dependencies mean every alternative is JL0. This measures concrete ingredient demand, not frequency of actual tower visits or player collection behavior. The request-selection suite prints this audit directly from the authored pool.

## Automated validation

Run with the installed Luau executable:

```powershell
python tests/run_state_tests.py --luau <luau.exe> --suite customer-payout --suite request-selection --suite economy-origin --suite economy-supply --suite farm --suite customer-wildcard --suite customer-payout-serve --suite tutorial-payout-serve
```

All eight suites pass. Payout owns value/relevance/grade/modifier contracts; request-selection owns accessibility, joint covers, whole-pool deterministic picks, immediate repeats and the audit; economy-origin owns real inventory/stash/blender release and theft boundaries; economy-supply owns refill and producer provenance; farm owns planting and production; wildcard/serve/tutorial integration retain cash, replay, feedback and floor checks. Presentation assertions are not prerequisites for authoritative payout tests.

StyLua checks all economy-touched Luau files. Rojo build passes. Full-src Roblox-aware typecheck still fails on existing diagnostics; comparison with isolated HEAD shows no added diagnostic headers. The touched payout function's optional-evaluation diagnostics are resolved.

Unrelated baseline failures were isolated: the legacy world suite fails before spawn timing at InventoryService's missing TycoonService fixture boundary, and the Python runner-contract tests have four failures on both HEAD and the working tree. Existing stale payout prices/probabilities and request progression budgets were updated in the focused economy suites; no unrelated production fixes were made for those tests.

## Studio acceptance ? outstanding

No live Studio/Roblox control session is available in this environment. CLI engine doubles establish server contracts, not real session pacing, physical theft, replication, or rendered feedback. These observations remain **not run**:

1. Sync with Rojo. Confirm the waterfall Gummy Bear uses one ordinary spawn tag. Replace the 300-second SpecialRefillSeconds placeholder with Collin's intended cadence in the shared constant; ordinary scene RespawnSeconds no longer overrides it. Verify Gummy Bear seed rejection preserves the carried unit.
2. Serve the five complete blends above through actual customer interactions and record credited cash and feedback. Confirm returned/displayed value follows the effective subtotal (wildcard zero); the current result graphic already shows only credited cash. Carried/stash loot-value displays keep catalog value.
3. Roll a regular **post-tutorial** wildcard with Payout level 0, no DoubleCash and no Muncher modifier. Serve cheap and expensive complete blends; each must pay $250 without a grade or ingredient-value implication.
4. Observe about 20 tier-0 regular customers, checking prompt variety and physical reachability. Repeats are allowed. Verify actual Blueberry/Melon pedestal refills at about 3/90 seconds and farm grows at about 9/270 seconds; verify the secret's separately configured cadence. Announced event cadence must remain authored.
5. Follow the normal fresh-player tutorial purchases and confirm Jump/Bat beats and payout-floor serves remain intact. Buy Carry 5 at $30,000. Record elapsed time and shared cash spent (including any stat purchases).
6. Continue the same fresh-player session. Record first Carry 5 purchase, first surplus brought home, first storage, first completed ripening and first theft interaction, or explicitly record each event's absence. Compare Carry 5 timing with the intended first-session window (not numerically specified in this request). If it misses, report a price-curve finding across both passes; do not redesign automatically.

| Combined session event | Observed elapsed time | Result |
|---|---|---|
| Carry 5 purchase | ? | Not run |
| Surplus returned home | ? | Not run |
| First storage | ? | Not run |
| First completed ripening | ? | Not run |
| First theft interaction | ? | Not run |

## File map

Runtime changes: CustomerOrderEvaluation, CustomerService, IngredientService, MarketService, IngredientSpawn component, FarmService, MuncherOutput, InventoryService creation defaults, PlayerHeadDropService, DevContentService; shared Types, IngredientItem, Economy, CustomerRequests, FarmConfig, Ingredients and the CarryCapacity entries in Upgrades.

Focused test changes: customer_payout, customer_payout_serve, customer_request_selection, customer_wildcard, farm, tutorial_payout_serve and fixtures/customer_requests; new economy_origin_lifecycle and economy_supply suites registered in run_state_tests.py. No color-coherence, prompt authoring, expedition orders or movement/stat redesign is included in this change.
