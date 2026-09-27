# Customer request variety

Regular requests have optional `RequestGroup` and `SimilarityKeys` fields.
The authored groups are Color, Trait, Combo, Restriction, Ingredient, and Recipe.
Restrictions take precedence over positive combinations; exact recipes use Recipe.
Apple + Sour and Mushrooms + Fruit use Combo; non-exact ingredient pairs use
Ingredient. Missing group metadata uses a shared Ungrouped compatibility bucket.
Similarity keys are explicit, case-sensitive concepts, not inferred smoothie tags.
Use the same spelling across definitions (for example Red, Fruit, NoFruit).

CustomerService keeps recent IDs, groups, and arrays of similarity keys by plot
session ID, alongside existing template history. Regular assignments (including
explicit RefreshOrder replacements) advance this history. Day/flow restarts keep
it; CleanupSession clears all of it. Team members share the session's history.
Fixed special requests bypass selection and do not advance any regular history.

Selection preserves normal eligibility and MinJumpTier, then applies the existing
three-ID recency preference and its all-recent fallback. It groups that pool,
uniformly chooses a group absent from the last two regular assignments when
possible, then uniformly chooses a request with no keys shared with the last two
regular assignments. Similarity filtering falls back inside the chosen group;
if every available group is recent, group selection uses all remaining groups.
Neither fallback restores locked/NPCOnly requests or IDs excluded by exact recency.
There are no progression weights. The three window settings are independent in
CustomerRequests: RegularRequestRecencyWindow (3),
RegularRequestGroupRecencyWindow (2), RegularRequestSimilarityRecencyWindow (2).

`DisplayTexts` optionally supplies alternate lines. Assignment chooses one entry
from a nonempty list, otherwise uses DisplayText. The customer record caches the
line per RequestId for its lifetime; even revisiting an ID through RefreshOrder
keeps that line. TakeOrder and refreshed bubbles use the cached text with existing
highlighting. Definitions and validation inputs remain unchanged. No authored
request was converted to alternate dialogue yet; focused tests provide examples.

The only duplicate ID found was RedNoFruit. Its Apple-only exclusion is now
RedNoApple; RedNoFruit retains the separate all-Fruit exclusion. Their requirements,
payouts, dialogue, and tiers remain intact, and no special mapping referenced the
renamed ID. The selection suite checks uniqueness across the complete catalog.

No Studio setup changes are required; sync through Rojo as usual. No Studio play
session was performed. Focused CLI coverage uses the mocked Roblox boundary:

- request-selection: group alternation, two-order window, group fallback, exact
  recency, similarity avoidance/fallback, tiers, recipes, special mappings and
  history isolation, cleanup, catalog uniqueness, and serving contracts.
- customer-order-text: allowed variants, stable refreshes, gameplay ID preservation,
  empty variant fallback, and existing DisplayText formatting.
- customer-queue: existing customer lifecycle and queue integration.

The legacy requests suite still has a baseline nameplate-style assertion failure;
customer-validation still has a baseline Sweet/Banana metadata expectation failure.
These failures were reproduced separately without the selection changes.
