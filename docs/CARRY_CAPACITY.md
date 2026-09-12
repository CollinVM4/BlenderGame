# Ingredient carry capacity

## Behavior and ownership

InventoryService holds the authoritative ordered `held[player]` array. Each reservation retains its physical visual through cleanup, its shared equipped Tool, original character root, ingredient ID, and throw offset. This extends the existing consume/clone/reserve/spawn representation; it does not create another inventory service. IngredientService world identity and ownership validation remain unchanged.

One Tool activation calls ThrowHeld once. It selects the last array entry and removes only that entry after a successful world spawn. Stash deposit also removes only the top entry, and withdrawal obeys physical carry capacity. HeldIngredientId identifies the top item; CarryCount reports the array length. Capacity is read from private PlayerDataService upgrade state, never from client attributes.

IngredientCarryPresentation places every visual directly above the head. Each item's lower edge clears the previous item's upper edge by IngredientCarry.StackGap (0.5 studs). HeightAboveHead remains 0.35 studs. Multipart and rotated extents are included. Remaining items do not move when the top item is removed. Carried parts have collision and touch disabled and are massless. No arm joints or animation assets are changed by carrying.

DropHeld releases the entire stack with small horizontal offsets in front of the player, preserving its existing first-object return value. Combat's existing DropOne delegates to DropHeld when physical items are held. Death, character removal, unequip, Tool destruction, and player removal use the same pathway. ClearHeld destroys all reserved visuals for existing development cleanup callers. Purchased capacity survives character respawn for the session; persistence across reconnects is not added.

## Upgrades

Constants/Upgrades.luau defines CarryCapacity tiers: 1 free, 2 for $100, 3 for $250. PlayerDataService validates the exact next requested tier before deducting cash. Repeated requests for an already purchased tier fail without another charge. CarryCapacity and the menu's zero-based CarryCapacityLevel attributes update immediately.

UpgradeDisplay adds a fourth track to the existing scrolling UpgradesGui. The controller sends the requested definition index alongside the track ID. The carry row displays levels 1-3, transitions 1 to 2 and 2 to 3, and 3 / 3 with MAX. Other upgrade purchase callers retain the optional-argument API.

## Files changed

- src/server/Services/InventoryService.luau
- src/server/Services/IngredientCarryPresentation.luau
- src/server/Services/PlayerDataService.luau
- src/server/Services/GameplayService.luau
- src/shared/Constants/IngredientCarry.luau
- src/shared/Constants/Upgrades.luau
- src/shared/Types.luau
- src/client/UI/UpgradeDisplay.luau
- src/client/Controllers/UpgradesController.luau
- tests/ingredient_carry.spec.luau
- tests/upgrade_ui.spec.luau
- docs/CARRY_CAPACITY.md

Existing unrelated workspace changes were preserved. The upgrade UI test's stale movement expectation was corrected from 28 to the configured 30.

## Validation

- Carry suite: 221 assertions passed, including geometry, unchanged arm motors, capacity limits, rejected-item preservation, LIFO throws, single Tool activation, forced release, purchase validation, duplicate requests, and a new character carrying three after respawn.
- Upgrade UI suite: 89 existing/expanded assertions plus 4 carry controller integration assertions passed.
- StyLua check passed on all changed Luau files.
- Roblox-aware Luau LSP typecheck passed on changed runtime files using the installed Roblox definitions and fresh Rojo sourcemap.
- Rojo build and git diff --check passed.
- Full state suite stops at the existing BlendVFX assertion `start clears copies and cancels arrival`.
- World suite stops at the existing assertion `rare spawn announces exactly once`.
- Both failures were reproduced using committed HEAD runtime sources, separately from this feature.

## Studio setup and playtest

No new instances, tags, animation assets, or manual UI setup are required. Sync with Rojo. Physics and live rendering were not playtested in Studio.

Test capacity one, then grant session cash through existing server tooling and buy Carry II and III in the upgrades menu. Pick up Strawberry, Banana, Tire and confirm Tire is highest. Click once per throw and confirm Tire, Banana, Strawberry order. Check differently sized ingredient models for clear vertical gaps. At full capacity, verify another world ingredient remains available. Slap, reset, die, and unequip with three items; verify all three are claimable world ingredients again and purchased capacity remains after respawn. Check stash deposits remove only the top ingredient, withdrawal respects capacity, and thrown ingredients still enter the blender through its existing rules.
