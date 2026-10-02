# Player Head death drops

`PlayerHeadDropService` observes `Humanoid.Died` through bootstrap's existing
character lifecycle. It binds immediately, or when a late Humanoid is added,
without delaying other character setup. It validates the player/character pair,
reserves one drop per character before spawning, and disconnects on character or
player removal. Teardown does not create ingredients; a fresh respawn can drop
its own head. Death position prefers Head, UpperTorso, HumanoidRootPart, then
the character pivot, with a small world-space offset.

Drops use `IngredientService.Spawn` with the victim's current `character.Head`
as a `VisualTemplate`. `IngredientGeometry.CapturePlayerHead` clones it without
mutating the source, keeps head geometry/mesh textures, face decals, SurfaceAppearance,
bones, FaceControls and wrap rendering data, and removes all other children.
This removes scripts, joints, constraints, sounds/effects and character references.
Tags and attributes are cleared before publication. The clone uses unanchored,
collidable, touchable/queryable physics with normal mass/material defaults,
Default collision group, and server network ownership through the usual spawn API.
No avatar fetching, accessories, gore, or new Studio asset is required.

Missing, non-part, unarchivable, or failed head clones use the existing
`ServerStorage.Ingredients.PlayerHead` prefab, then the normal geometry fallback.
There is no special inventory, ownership, cleanup, or blender acceptance path.
Heads remain loose claimable items and participate in normal world cleanup.

The item carries an opaque frozen `VisualKey` table, containing no Instance.
Geometry privately maps this key to a sanitized detached template in a weak-key
registry. Existing shallow item copies keep the same key through pickup, overhead
carry, stash, theft, and throw/drop. `IngredientService.CreateVisual(id, item)`
centrally resolves this appearance; normal IDs use their original template path.
Templates are released when their final item/snapshot references are collected,
without a permanent cache indexed by player or item ID. Appearance is in-memory
for the current server, matching the existing ingredient lifecycle.

Blender snapshots now include copies of the existing per-unit `IngredientItems`
for cosmetic rendering. Arrival and restored jar proxies use the same resolver,
including dynamic-head rendering children. Acceptance, batch state, values,
colors, tags, and grading are unchanged. No visual keys or templates are attached
as replicated attributes or accepted from client requests.

Optional `SourceUserId`, `SourceDisplayName`, and `SourceUsername` fields live on
the normal authoritative `IngredientItem` and are published as world attributes
before the ingredient tag. Existing copies preserve them through pickup, carry,
stash, theft, throw/drop, and blending. Replicated attributes do not authorize
inventory or supply authoritative source identity.

The shared PlayerHead definition remains generic: Player Head, Weird, Uncommon,
$15K, pink blend color (the existing working-copy definition). `IngredientName.Resolve` overrides only PlayerHead with a
positive source user ID and nonblank display name to `<DisplayName>'s Head`.
Missing metadata falls back to Player Head. World pickup labels refresh for late
metadata replication, and carry Tools use the same resolver. Stash presentation
currently has value-only labels; cosmetic head proxies retain their source
attributes and resolved name. Existing rarity, ripeness, and value formatting
is unchanged.

## Validation

- `python tests/run_state_tests.py --luau <luau.exe> --suite player-head`
  covers death, duplicate/teardown/respawn guards, late Humanoids, simultaneous
  identities, pickup, stash, theft, throw, blender input, and normal loose cleanup.
- `--suite player-head-visual` covers MeshPart appearance, sanitization, unchanged
  source heads, independent death-time snapshots, copy preservation and fallbacks.
- `--suite player-head-stash` and `--suite player-head-blender-visual` provide
  separate presentation coverage for distinct stash heads and live/restored jar heads.
- `python tests/run_ingredient_prompt_tests.py --luau <luau.exe> --player-head-only`
  covers world names, fallback, late metadata, and unchanged rarity/value display.
- Existing focused carry, stash-integration, throw-blender, and ingredient-cleanup
  suites pass. Full source typecheck still reports baseline errors in combat,
  customer, and JackedNoob code; changed/new head implementation has no errors.
- Existing stash-presentation and ingredient-prompt suites have baseline failures
  on stale ingredient value/ripeness expectations, reproduced without this feature.
  The legacy world suite's second-item capacity assertion and VFX suite's outdated
  session fixture also fail on the starting snapshot; head-specific replacements
  run independently and pass.
  Runner manifest checks also retain two baseline failures from stale suite lists/order.

## Studio smoke check

No new Studio setup is required. The authored `ServerStorage.Ingredients.PlayerHead`
Model/BasePart is now only a fallback. Check both a classic Part/SpecialMesh/face
avatar and a modern MeshPart/dynamic-head avatar. The dropped ingredient should
match the victim's appearance, with no remaining character connections/effects.
After Rojo sync, test lethal fall damage and Reset Character: one head should
appear near the body for each death, with the correct name and standard value.
With two clients, pick up, throw, store in an unprotected slot, steal, and blend
heads from different players. Verify each head retains its own face/mesh through
ordinary drops, throws, overhead carry, stash proxies, takes/theft and jar display.
Also check missing/unarchivable Head fallbacks, replicated names, normal
cleanup, and another single drop after respawn. Real engine death timing,
physics, replication, and visuals still require this Studio smoke check.
