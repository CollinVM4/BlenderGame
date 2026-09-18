# Smoothie world items

`SmoothieWorldItemService` privately registers data copied from inventory. Drop/throw rebuilds the ServerStorage asset and removes the carried reservation only after spawn succeeds. Pickup locks the record while InventoryService grants the same BlendId and ordered three IDs. Failed grants unlock the same world object; successful grants retire it. Replicated attributes are display-only. IngredientService never registers these models, so blender ingestion ignores them.

Studio requires the existing archivable `ServerStorage.Smoothie` Tool with a BasePart `Handle`. No manual world tags are needed: the server creates the `SmoothieWorldItem` tag and smoothie prompt. Manually tagging a model does not register contents. Loose smoothies have no automatic expiry. Validate real physics, two-client interaction and panel layout in Studio; CLI tests use engine doubles.

Focused validation:
- `python tests/run_state_tests.py --smoothie-only --luau <luau.exe>`
- `python tests/run_state_tests.py --world-only --luau <luau.exe>`
- `python tests/run_smoothie_prompt_tests.py --luau <luau.exe>`

New contracts live in `smoothie_world.spec.luau` and `smoothie_prompt.spec.luau`. Existing lifecycle expectations now release smoothies. Removed the obsolete geometry case that used DropHeld to remove only the bottom ingredient while retaining smoothies; DropHeld now releases the entire stack. Existing serve/stash contracts remain in their original suites.

## Hand carry correction

Each smoothie now keeps a cloned authored Tool/Handle and Grip. CreateTool sanitizes scripts/prompts/tags and rebuilds assembly welds while enabling normal click activation. Only world/stash visuals are converted to Models. Equipped Tool identity selects the authoritative reservation for throw, serve and stash. Ingredients still share their overhead Tool; during smoothie selection, their visuals temporarily live in an IngredientCarryVisuals model under the character. Unequipping a smoothie retains it in the Backpack. Removing one Tool transfers handlers only among reservations using that same Tool, leaving other carried items usable. Capacity remains shared.

Studio smoke checks: authored Grip placement on supported avatar rigs, normal hotbar switching, visible overhead ingredients while holding a smoothie, one world object per click, thrown assembly physics, and two-client pickup contention. Engine doubles cannot validate RightGrip creation or rendered physics.
