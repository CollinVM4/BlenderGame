# Mobile carry investigation and ingredient hold pose

## Status

A (prompt/Throw routing) and B (missing mobile slots) remain pending device evidence,
as requested after code inspection. No input, prompt, hotbar, server inventory,
selection, capacity, throw remote, or economy implementation changed in this pass.
No Studio or physical-device/emulator acceptance was performed. CLI results below
do not establish native input routing, visible slots, or animation blending.

## Code diagnosis: A

`InteractionPromptPresentation.Create` sets the full BillboardGui `Active = true`.
For padded mobile prompts the visual label is inactive and a separate active
`TouchTarget` forwards input through `MobilePromptTouchTargets.Register` to
`InputHoldBegin`. The registration rejects events when `gui.Active` is false.
Consequently, changing only the billboard's Active flag would break pickup.

This supports the reported billboard-overlap hypothesis but does not prove the
engine's routing behavior. The CAS Throw action binds ButtonR2 and its own touch
button; world touch deliberately does not throw, and processed mouse clicks are
ignored. `MobileControlLayout` positions action buttons around Jump and avoids
other known controls, but does not reserve space against world billboards.
No competing Throw CAS binding was found in the inspected path. Prompt-service
capture, actual GUI stacking, and layout overlap still need device comparison.

Before a fix, enable the existing ThrowDebug player attribute and mobile prompt
logging described in `INGREDIENT_PICKUP_PROMPTS.md`. On a real mobile client or
Android/iOS emulator, compare Throw taps with no prompt, a nearby prompt, and a
billboard overlapping Throw outside the intended prompt target. Record whether
the CAS handler is invoked and whether the prompt logs TOUCH RECEIVED / TARGET
SELECTED. Also test actual touch-target overlap separately: an active target can
still compete with Throw even if the billboard background becomes inactive.
Compare a diagnostic build with only the billboard/background capture removed
and the registration's Active guard adjusted. Preserve finger claiming,
InputHoldBegin/End, hold duration, mouse clicks and gamepad prompt activation.
Only then choose the smallest verified input-layer fix.

## Code diagnosis: B

Inventory creates a separate handle-free Tool per ingredient, marks it with
ItemType, IngredientId and CarryItemId, and parents it to Backpack. Equipped Tools
move to Character. The client has no custom native-backpack slot model and no
SetCoreGuiEnabled call disabling its backpack. The native rendered hotbar is
outside these test doubles. Existing ingredient-slots tests establish Tool
identity/lifecycle, not whether Roblox draws each slot.

On the same device record CarryCount, configured capacity, every ingredient Tool's
CarryItemId and parent (Backpack or Character), smoothie Tools, other Tools, and
the number of visible/selectable slots. CarryCount includes smoothies; unrelated
weapon slots must be counted separately. At each 3/5/7 tier, use duplicates and
mixed smoothie inventory, and check both the collapsed hotbar and expanded native
backpack. Compare immediately after pickup and after replication settles. Select
each slot and correlate the resulting Character Tool's CarryItemId.

This distinguishes absent/late Tools from an overflow or collapsed native UI and
from missing rendering despite a live Tool. A root cause has not been established;
no custom hotbar or speculative reparenting workaround was added. Extend the
authoritative slot suite only for a diagnosed Tool-mapping defect. Native rendered
slot coverage must remain a device acceptance check while using native CoreGui.

## Ingredient hold implementation and setup

`src/shared/Constants/CarryPresentation.luau` exposes
`IngredientHoldAnimationId`, default `""`. Set it to Collin's published
`rbxassetid://...` after authoring an arms-up looping pose with only the arm joints
keyframed. Do not keyframe legs/root; Action priority overrides idle on animated
joints, so full-body keys would override locomotion. Publish under the appropriate
experience owner or grant the experience asset permission. Verify the actual rig
used by the game, walking, idle, and weapon transitions in Studio before enabling
it for players. No placeholder asset ships.

`IngredientHoldController` is initialized beside BatController. When unset it
creates no Animation and installs no listeners. Otherwise it watches character
Tool equips and the authoritative ItemType marker, plays one looped Action track
only for Ingredient, and reuses the existing replicated Humanoid Animator. Late
Animator/marker replication is handled through events. It never creates an
Animator, sends gameplay requests, or stops another controller's tracks.
Unequip, reparent/throw, marker removal, Tool destruction, death, character removal,
player departure and explicit Destroy stop and release its own pose.

Changed files for this pass:

- `src/client/Controllers/IngredientHoldController.luau` (new)
- `src/shared/Constants/CarryPresentation.luau` (new)
- `src/client/init.client.luau` (one added initialization; prior edits preserved)
- `tests/ingredient_hold.spec.luau` (new)
- `tests/run_state_tests.py` (suite/source registration; prior edits preserved)
- This document.

## Validation

- PASS: ingredient-hold, carry-input, ingredient-slots focused suites.
- Hold coverage includes unset asset, marker-only classification, smoothie and
  weapon exclusion, existing equip, late Animator/marker replication, teardown,
  and actual BatController co-execution for bat → ingredient → smoothie handoff.
  Ingredient teardown leaves the bat's track playing. Ice gun controllers in the
  inspected path do not load animation tracks; live weapon visuals still require
  acceptance testing.
- PASS: Roblox-aware Luau LSP analysis of the new controller and config using a
  fresh Rojo sourcemap; StyLua checks of touched Luau; Rojo 7.7 build; diff whitespace.
- Existing failures reproduced in a temporary copy of the pre-change working
  tree (including prior local edits): bat-controller and mobile_prompt fail at
  CarryInputController InputBegan:Connect because their UIS double lacks that
  signal; interaction_prompt fails at `stash store retains key and action`;
  ingredient_prompt fails at `registered Strawberry definition`.
- An expanded typecheck through init.client follows unrelated dependencies and
  reports CustomerRequests missing DisplayText type errors; the same errors
  reproduce with the new controller/config/registration removed. No unrelated
  production code or fixtures were changed to hide those failures.

## Studio and device acceptance (all pending)

1. Real mobile client/emulator: Throw with a nearby prompt, including billboard
   overlap outside its intended target. Confirm one request and correct throw.
2. Prompt target: tap/hold pickup still forwards once and releases correctly.
3. All configured capacities: count live ingredients and visible native slots,
   including mixed smoothies, duplicates, overflow and collapsed UI; select each.
4. After publishing/configuring the asset: ingredient pose loops while walking.
5. Unequip/throw, rapid bat ↔ ingredient ↔ smoothie and ice gun transitions,
   Tool destruction, death/respawn and departure: no stuck/fighting tracks.
6. Smoothie equip: no ingredient pose; existing smoothie hand visuals preserved.
7. Desktop unprocessed mouse throw, processed UI clicks, mouse prompt pickup,
   and gamepad throw/prompt paths retain their current behavior.

Device results and the published animation ID are the remaining inputs needed to
finish acceptance and diagnose A/B before implementing their fixes.
