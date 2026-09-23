# Customer request validation

`CustomerService.ValidateRequest` evaluates server-owned ingredient IDs against
`Ingredients.luau` and ignores supplied smoothie `Tags`. Every required tag and
ingredient ID must exist; forbidden tags and ingredient IDs must be absent. One
ingredient can supply several tags, while duplicate required ingredient IDs require
the same quantity in the smoothie. Extras are allowed unless forbidden or
`ExactIngredients` is enabled. Tag comparisons use `string.lower`; ingredient and
Customer IDs are case-sensitive stable IDs.

```luau
export type IngredientRequirement = string | { string }

export type Request = {
    Id: string,
    DisplayText: string,
    GoodResponse: string?,
    BadResponse: string?,
    RequiredTags: { string },
    ForbiddenTags: { string }?,
    RequiredIngredients: { IngredientRequirement }?,
    ForbiddenIngredients: { string }?,
    ExactIngredients: boolean?,
    BasePayout: number,
    MinJumpTier: number,
    NPCOnly: boolean?,
}
```

Omitted and empty forbidden lists are equivalent. Empty smoothies and requests
without either required tags or required ingredient IDs fail. `ExactIngredients`
requires a non-empty `RequiredIngredients` list and exactly one physical ingredient
per slot, without regard to order or any extras. A string slot requires that exact
ID; a table slot accepts any one listed ID. Each physical ingredient can satisfy
only one slot, including overlapping alternatives and duplicate requirements.
For example, `{{"Apple", "Green_Apple"}, "Banana", "Ice"}` accepts either apple
with Banana and Ice; it rejects both apples together when exact matching is enabled. Validation reports required-tag failures, then
forbidden tags, missing required ingredients, forbidden ingredients, and exact
mismatches. The existing Studio-only serve diagnostic prints the reason; players
still receive the authored GoodResponse/BadResponse. Special NPCs use this same
validator, including existing lowercase `protein` and `weird` requests.

At `CustomerService.Init`, Studio warns without changing definitions when a
required or forbidden ingredient ID is unknown, an exact request has no required
ingredients, or a required ingredient's `JumpLocation` exceeds `MinJumpTier`.
Alternative groups warn for unknown IDs and empty groups. A group gets a tier
warning only when it has valid alternatives but none are accessible at the
request's `MinJumpTier`.

## Initial orders and catalog witnesses

These are example valid three-ingredient smoothies, not enforced recipes.
The map author confirmed Hamburger and Chili_Pepper are reachable at Jump 1,
and Strawberry, Ice, Banana, and Green_Apple at Jump 0. Thus all examples are
obtainable at their order's minimum tier. No ingredient tags or spawn setup changed.

| Request | Tier | Payout | Example ingredients |
| --- | --- | --- | --- |
| SweetCold | 1 | 50 | Strawberry, Ice, Banana |
| FruitProtein | 1 | 50 | Strawberry, Hamburger, Banana |
| GreenSpicy | 1 | 50 | Green_Apple, Chili_Pepper, Banana |
| SweetNoSpicy | 2 | 75 | Strawberry, Ice, Banana |
| FruitNoMilk | 2 | 75 | Strawberry, Ice, Banana |
| ColdNoFastFood | 2 | 75 | Strawberry, Ice, Banana |
| SweetColdNoSpicy | 3 | 100 | Strawberry, Ice, Banana |
| FruitGreenNoMilk | 3 | 100 | Green_Apple, Strawberry, Banana |

All eight suggested definitions retain their supplied dialogue. Selection still
includes every normal request whose MinJumpTier is at most JumpLevel, so simple
orders remain available at higher tiers. NPCOnly filtering, mappings, special
chance/cap, prior payouts, grading, and serving mechanics are unchanged.

## Validation and Studio check

Run `python tests/run_state_tests.py --request-validation-only --luau <luau-path>`.
This runs authoritative validation, legacy compatibility, and request/serving
integration separately. Tag contracts moved from the legacy state monolith to
`customer_validation.spec.luau`; the new suite is their authoritative test home.
Tests exhaust the actual eligible request pool at tiers 0–3 and check real Serve
payment, authored feedback, forged-tag rejection, and duplicate-serve protection.

No new Studio instances, attributes, or remotes are required. With existing
spawns, exercise an advanced order with a valid smoothie, one missing a required
tag, and one containing a forbidden tag. Check the authored response and the
existing Studio diagnostic. Automated tests use a mocked Roblox boundary;
physical map traversal and Studio playtesting are not automated here.

## Ingredient name highlighting

Authored `DisplayText` stays plain. `CustomerService.FormatRequestText` resolves
required ingredient IDs (including all alternatives), uses
`definition.DisplayName or definition.Id`, and colors whole names case-insensitively
with that ingredient's `BlendColor`. Longer names take precedence over contained
names, authored capitalization is retained, and original markup characters are
escaped. Required and forbidden tag words use the centralized presentation-only
`CustomerPresentation.TagHighlights` palette, including authored aliases such as
Spicy ? SPICE/HEAT. Only tags present in that request activate their phrases;
`*` and unknown tags have no highlight. Concrete required ingredient names win
when the same phrase is also a tag, preserving `Ingredients.BlendColor` as their
source of truth. Tag colors never affect request validation.

The order label enables RichText, types escaped plain text at the existing cadence,
and replaces the completed order with its colored version. Restored orders use
the same formatting; success/failure responses retain their existing coloring.
Presentation coverage lives separately in `customer_order_queue.spec.luau` and
`customer_order_text.spec.luau`. Run `--customer-order-text-only` for the spawned
NPC label/typewriter integration checks, including the Yellow request.
No Studio setup is required; visually check the typewriter and final ingredient
colors on AppleBananaIce in Studio.
