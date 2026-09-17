# Customer request validation

`CustomerService.ValidateRequest` evaluates server-owned ingredient IDs against
`Ingredients.luau` and ignores supplied smoothie `Tags`. Every required tag and
ingredient ID must exist; forbidden tags and ingredient IDs must be absent. One
ingredient can supply several tags, while duplicate required ingredient IDs require
the same quantity in the smoothie. Extras are allowed unless forbidden or
`ExactIngredients` is enabled. Tag comparisons use `string.lower`; ingredient and
Customer IDs are case-sensitive stable IDs.

```luau
export type Request = {
    Id: string,
    DisplayText: string,
    GoodResponse: string?,
    BadResponse: string?,
    RequiredTags: { string },
    ForbiddenTags: { string }?,
    RequiredIngredients: { string }?,
    ForbiddenIngredients: { string }?,
    ExactIngredients: boolean?,
    BasePayout: number,
    MinJumpTier: number,
    NPCOnly: boolean?,
}
```

Omitted and empty forbidden lists are equivalent. Empty smoothies and requests
without either required tags or required ingredient IDs fail. `ExactIngredients`
requires a non-empty `RequiredIngredients` list and compares the complete ID
multiset without regard to order. Validation reports required-tag failures, then
forbidden tags, missing required ingredients, forbidden ingredients, and exact
mismatches. The existing Studio-only serve diagnostic prints the reason; players
still receive the authored GoodResponse/BadResponse. Special NPCs use this same
validator, including existing lowercase `protein` and `weird` requests.

At `CustomerService.Init`, Studio warns without changing definitions when a
required or forbidden ingredient ID is unknown, an exact request has no required
ingredients, or a required ingredient's `JumpLocation` exceeds `MinJumpTier`.

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
