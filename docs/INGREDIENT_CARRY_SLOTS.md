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

One `CarryInputController` action sends `GameplayRequest("ThrowHeld", selectedCarryItemId)`; the existing
rate-limited server adapter calls `InventoryService.ThrowHeld`. Mouse click,
gamepad R2, and a touch Throw button use this path. All per-Tool Activated throw
listeners were removed, including the shared helper's smoothie listener, so a
click cannot trigger two throw paths.

The controller reads the equipped Tool under Character and sends its numeric
`CarryItemId` when it also has `IngredientId`. It never uses a hotbar index, name,
or ingredient ID as the item identity. Unequipping sends no selected ID; input
remains enabled while CarryCount is positive.

Throw and stash share `resolveActionItem` on the server. An equipped smoothie
keeps exact selection precedence. Otherwise a supplied ingredient carry ID (or
the server-equipped ingredient Tool's ID when no hint is supplied) must match a
live ingredient record in that player's held list. The record must not be
releasing or destroying. Numeric IDs must be positive integers. Invalid, stale,
malformed, or foreign IDs fall back only to that player's newest live ingredient.
Nothing selected also uses that fallback. Unselected smoothies never become
fallback items. Health and existing action-specific access checks still apply.

Duplicates resolve by CarryItemId, so selecting the first Apple removes that
record and its exact Tool/visual. Selection never reorders the held array.
Server HeldIngredientId/HeldItemType presentation attributes report the effective
action target, including fallback, so stash prompts describe the ingredient that
will be stored. Stash burst direction, capacity, stacking, protections, and
transfer checks remain unchanged. A fresh stash interaction with unequipped
ingredients now starts STORE using the newest ingredient; an existing TAKE burst
still continues TAKE. Removing an equipped item retains the existing automatic
selection of a surviving Tool. Ingredient selection does not affect smoothie
hand geometry, serving, or copied data.

Launch position/velocity, spawn failure retention, collision grace, and the
existing 0.15-second request limit are unchanged.

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

## Selected-slot follow-up

This follow-up changes only `CarryInputController.luau`, `GameplayService.luau`,
`InventoryService.luau`, `carry_input.spec.luau`, `ingredient_slots.spec.luau`,
`run_state_tests.py`, this document, and new `carry_selection.spec.luau`.
No presentation implementation or authored assets changed.

Validation: `--carry-only` passes all six suites, covering exact middle/first
selection, duplicate throw/stash, nil fallback, malformed/foreign IDs, selection
lifecycle, client ID forwarding, overhead preservation, and selected smoothies.
The stash/smoothie focused runs retain the same four failures listed above,
reproduced again on a copy of the local tree taken before this follow-up.
Runner tests, Roblox-aware typecheck, StyLua, Rojo build, and whitespace checks
pass. The existing deprecated API warning remains. Studio input/equip replication
still needs manual verification; no Studio session was run.
