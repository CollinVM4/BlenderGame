# Tutorial starter stash initialization

## Root cause and execution order

The supplied Studio server log identifies an exception at IceGunDisplay.bind's
unguarded ServerStorage.Weapons lookup. The new Ice Gun display component was
inserted before Stash in the bootstrap component list. An existing pedestal with
no imported Weapons folder caused synchronous component initialization to abort
before Stash.Init and StudioServices.Publish.

The claim zone and session hooks had already been installed. A subsequent claim
still created a session and activated the forced RED customer, as the supplied
log confirms. Server inventory could therefore contain the nine starter records
while the stash had no component-created prompts, replicated counts, displays,
or pips. This was an interrupted stash binding, not evidence of ingredient
cleanup deleting the seed. The new bootstrap test reproduces the exception using
the pre-fix display source and succeeds with the guarded lookup.

Normal order: server dependencies initialize -> player inventory setup ->
component binding -> claim zone entry -> TycoonService creates a busy session ->
membership publication -> farm/blend/muncher activation -> authoritative starter
commit -> tutorial queue activation -> tutorial refresh -> transaction release.
RED/COLD/YELLOW queue insertions and live gameplay guidance remain unchanged.
The 4.5-second claim hint delay does not control inventory creation.

## Changes

- IceGunDisplay uses FindFirstChild for the optional Weapons folder. Its existing
  missing-handle warning/return now handles missing imports without aborting bootstrap.
- InventoryService prepares every starter record before committing any slot, and
  records session success after the commit. IDs remain Cherries, Strawberry, Ice,
  and Banana. Normal fresh/ripeness records and valuation are used, without world
  spawns, carried grants, or discovery writes.
- Stash allocation is idempotent and is available during the claim hook. Late or
  repeated AddPlayer calls cannot erase committed inventory.
- Membership publication transfers the existing stash table to a promoted owner
  before departing-player cleanup. It does not reseed it. Session release clears
  that session's stash and seed identity, permitting a fresh tutorial on reclaim.
- Explicit seed failure or a thrown session-start hook releases the claim
  transaction and closes the failed session. A departure queued during the claim
  cannot return a successful live claim. Legacy hooks returning nil still work.
- Protected slots use the one-ingredient capacity specified in this request;
  the current pre-change source/tests had allowed three. Slots 3–5 still stack
  three, and the starting visible layout is still five slots.

## Files changed in this pass

- src/server/Components/IceGunDisplay.luau
- src/server/Services/InventoryService.luau
- src/server/Services/TycoonService.luau
- src/server/init.server.luau
- tests/tutorial_claim.spec.luau
- tests/tutorial_gameplay.spec.luau
- tests/stash_interaction.spec.luau
- tests/stash_integration.spec.luau
- tests/run_state_tests.py
- docs/TUTORIAL_STASH_INITIALIZATION.md

Existing working-tree changes outside these edits were preserved.

## Validation

Run the state runner with repeated --suite selectors and a Luau executable:

    python tests/run_state_tests.py --luau <luau.exe> --suite tutorial-claim --suite tutorial-gameplay --suite tutorial --suite stash --suite stash-integration --suite farm --suite ingredient-cleanup --suite icegun-display

All eight suites pass. The claim suite executes production bootstrap wiring,
real stash prompt/attribute binding, and authoritative inventory; only cosmetic
stash geometry and unrelated services are doubled. It covers exact quantities,
IDs, fresh state and value, normal TAKE, duplicate callbacks/claims, delayed
player setup, respawn, teammate joining, owner departure, release/reclaim,
partial preparation failure, retry, cleanup isolation, and departure during
initialization. Existing tutorial gameplay covers real throwing, blender input,
100% dispensing, and successful guided RED/COLD/YELLOW serving.

Separately: stash-presentation, stash-capacity-indicators, and tutorial-targets
all pass. StyLua checks on changed Luau files, Rojo 7.7 build, and git diff --check
pass. Full-src Roblox-aware typecheck has 216 diagnostics on both the pre-change
snapshot and current source, with no added diagnostics after normalizing paths
and shifted line numbers. These include existing CustomerRequests DisplayText,
CustomerService, JackedNoobService, and CombatService errors. No type errors are
reported in the modified runtime modules.

The plot-session-races suite still fails at "purchase remains committed" on both
baseline and current source. Python test_state_runner.py has the same four stale
manifest/bundle failures on baseline and current source. Unrelated production
code was not changed to satisfy those failures.

## Studio verification

1. Stop Play, sync the changed source through Rojo, and start a fresh Play session.
2. With an EquipmentSpawner present and Weapons absent, verify the missing-handle
   warning appears but the final server initialized message also appears. Stash
   setup must still finish. Import the project's existing mapped Ice Gun assets
   separately if that display is desired; they are not required for stash setup.
3. Walk into a free plot's ClaimZone. Check slots 1–2 are empty, slot 3 shows two
   Cherries and one Strawberry, slot 4 three Ice Cubes, and slot 5 three Bananas.
4. Verify three filled pips per starter slot and normal value/fresh indicators.
   Use TAKE and check exactly one item moves into carried inventory and the stash
   count/value updates. Wait through normal ripeness duration to verify ripe state.
5. Take the RED order, withdraw/load all three red ingredients, complete blending,
   dispense, and serve. Repeat COLD and YELLOW. Glass guidance must persist until
   three accepted ingredients; dispenser guidance must wait for 100% progress.
6. Reset the character and verify withdrawals stay withdrawn. In a two-client
   test, join as teammate, disconnect the owner, and verify the promoted teammate
   can still TAKE the same remaining stash without receiving another starter set.
7. Release the final member and reclaim the plot: verify a new session with nine
   fresh units. Repeat entering an already claimed zone: no extra rewards.

No live Studio session was operated during this pass. Real replication, authored
geometry, rendered pips/values, device input, and two-client behavior still need
these smoke checks. The supplied exception is reproduced with engine doubles;
missing optional display assets intentionally leave that display unavailable.
