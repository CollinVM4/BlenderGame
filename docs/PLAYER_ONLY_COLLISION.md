# Blender player collision helpers

Create a Part around the spinning blender/turbine where a player guard or floor
is needed. In Studio's Properties tag editor, add `PlayerOnlyCollision` to each
physical Part/MeshPart (tagging a Model does not configure its children).
Author `Transparency = 1` and usually `Anchored = true` for a fixed invisible guard.
The server sets only `CollisionGroup = "PlayerOnly"` and `CanCollide = true`.
Appearance, transform, anchoring, touch and query properties remain authored values.

`PlayerOnlyCollisionService.Init()` registers missing `Players` / `PlayerOnly`
groups and configures existing tagged parts plus later tag additions. `PlayerOnly`
collides only with `Players`; it ignores `Default`, itself, and every other group
registered at startup, including any Studio-authored ingredient/world-item groups.
Groups added by future code after initialization must explicitly disable their
collision with `PlayerOnly` when registered.

The codebase previously had no player collision group setup. Ingredients use
`Default`. Existing `CharacterPhysicsService` scans assign avatar body/root and
cosmetic parts to `Players`, including late additions and respawns. Gameplay Tools
and accessories marked `PreserveGameplayPhysics` keep their existing physics.
Character scaling, collidability, and normalization behavior are unchanged.
Existing collision relationships between other groups are preserved.

## Validation

Run `python tests/run_character_physics_tests.py --luau <luau.exe>` for the
helper/matrix contracts and existing character lifecycle tests at a fake Roblox
boundary. These validate configuration, not physical simulation.

Implementation validation: focused tests, StyLua, Rojo build, and typecheck of the
two collision services pass. Full-project typecheck reports the same 201 type
errors on baseline and this change; no new type errors were introduced. The
existing `LoadCharacterAppearance` deprecation warning remains.

In Studio Play mode:

1. Walk and jump against/on a tagged invisible helper near the spinning turbine.
   Check that it closes the intended gaps without trapping players or obstructing
   entry. Verify walking, pushing the turbine, and respawning.
2. Drop and throw ingredients through the helper; repeat with a loose world
   ingredient and an ordinary ungrouped physics Part. They should pass through
   the helper while still colliding with the normal world.
3. Add the tag to another Part during play on the server. Confirm it immediately
   receives `PlayerOnly` and `CanCollide = true`, and repeat player/object contact.
4. Confirm normal world floors/walls and any authored ingredient collision groups
   retain their previous behavior. Inspect the Collision Groups matrix to confirm
   `Players`–`PlayerOnly` is enabled and other `PlayerOnly` pairs are disabled.

Helper placement and geometry determine which gaps are covered. No helper parts
are generated automatically, and no Studio playtest is implied by CLI checks.
