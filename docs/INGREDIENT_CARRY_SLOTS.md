# Ingredient carry slots

Inspected and changed the local working tree only; no GitHub/main source was used.

## Ownership and flow

`IngredientService` keeps a server registry for loose world items. `IngredientPickup`
calls `InventoryService.CarryWorldItem`, which validates distance, health, ownership,
and capacity, consumes the world identity, and creates a record in `held[player]`.
That ordered server-owned record list remains authoritative for physical carry.
The separate legacy `carried[player]` ingredient-count API was not redesigned.

Previously, all ingredient records referenced one shared Tool. Its name changed to
the newest ingredient with a `(click to throw)` suffix. Smoothies already had
individual Tools. `equipVisual` connected `Tool.Activated` to `ThrowHeld`; there was
no existing centralized client carry-throw controller.

Each ingredient record now owns one passive, handle-free Tool, named from
`DisplayName` with ingredient ID fallback. `IngredientId` identifies the definition;
`CarryItemId` is a server-session unique number stored in the record and attached
to its Tool and overhead host. The record's direct Tool reference is the stable
mapping. Duplicates have separate records, IDs, Tools, and visuals. Attributes
never authorize contents. Surviving Tools are not rebuilt after another removal.

Each overhead visual lives under its own character Model. Existing placement,
clearance, rotation, welds, and spacing calculations remain. Removing a middle
record reflows higher visuals across their individual hosts. Backpack/Character
selection does not remove inventory, move the stack, or introduce hand geometry.

## Throw and selection behavior

One `CarryInputController` action sends `GameplayRequest("ThrowHeld")`; the existing
rate-limited server adapter calls `InventoryService.ThrowHeld`. Mouse click,
gamepad R2, and a touch Throw button use this path. All per-Tool Activated throw
listeners were removed, including the shared helper's smoothie listener, so a
click cannot trigger two throw paths.

Ingredient throwing remains newest-first while any ingredient slot is equipped.
Selecting an older ingredient does not change throw order. A selected smoothie
still throws that exact smoothie. No selected carry Tool means no throw. Server
health checks, spawn failure retention, launch position/velocity, and collision
grace remain. Input throttling now uses the existing 0.15-second request limit.

Ingredient selection now identifies that individual item for stash deposit.
Previously only the shared ingredient Tool existed, so deposits chose its newest
record. After removing an equipped ingredient, the newest remaining ingredient
is selected when available. Smoothie selection, hand geometry, copied data,
consumption, and stash behavior remain intact.

Unequipping ingredients no longer drops the stack: this is necessary for passive
hotbar selection. Explicit drops, death/reset, and player cleanup still release
and clear carried items. Blender ingestion consumes the released world ingredient;
its matching Tool/visual have already been removed during throw/drop. Stash
withdrawal creates a fresh carry identity and slot; stash stacks remain unchanged.
Current configured capacity tiers remain 3/5/7, including shared smoothie capacity.

## Changed files

Runtime:
- `src/server/Services/InventoryService.luau`
- `src/server/Services/IngredientCarryPresentation.luau`
- `src/server/Services/GameplayService.luau`
- `src/client/Controllers/CarryInputController.luau` (new)
- `src/client/init.client.luau`

Validation:
- `tests/ingredient_slots.spec.luau` and `tests/carry_input.spec.luau` (new)
- `tests/ingredient_carry.spec.luau`, `tests/ingredient_throw.spec.luau`
- `tests/carry_presentation.spec.luau`, `tests/fixtures/carry.luau`
- `tests/stash_interaction.spec.luau` (definition/equip doubles)
- `tests/smoothie_survivors.spec.luau`, `tests/smoothie_world.spec.luau` (central throw calls)
- `tests/run_state_tests.py` (added suites and controller source; preserved existing local edits)
- This document.

## Validation

- `--carry-only`: PASS, including carry state, throw state, individual slot/stash/
  blender/smoothie integration, centralized input integration, and overhead presentation.
- `--throw-only`: PASS, including multipart blender ingestion during collision grace.
- Runner contract tests: 4/4 PASS.
- `--stash-only`: presentation PASS; state stops at the pre-existing
  `H: carry capacity remains three` expectation.
- `--smoothie-only`: survivors and geometry PASS; pre-existing failures remain in
  smoothie-world (`capacity failure retains world item`), smoothie
  (`capacity rejects extra smoothie`), and smoothie-roundtrip (`take stored smoothie`).
- All four remaining failures reproduce on a saved copy of the original local
  working tree. Capacity assumptions and a one-second wait against a 1.2-second
  stash burst timeout are stale. No unrelated production behavior was changed.
- New passing integration coverage separately verifies smoothie selection,
  consumption, stash/withdraw identity, hand Tool shape, and configured capacity.
- Roblox-aware Luau LSP typecheck, StyLua, Rojo build, and whitespace checks PASS.
  Typecheck retains the existing `LoadCharacterAppearance` deprecation warning.

## Studio smoke checks

No manual Studio session was run. No authored asset or Studio setup changes are
required; sync with Rojo. Verify actual hotbar ordering/equip replication, two
same-ID slots, selecting/unequipping without dropping, vertical stack clearance
and middle-item reflow, single mouse/gamepad/touch throws (including UI clicks),
stash/withdraw, blender ingestion, smoothie selection/serving, and death/respawn.
CLI doubles do not simulate Roblox input priority, networking, weld physics, or
rendered hotbar behavior.
