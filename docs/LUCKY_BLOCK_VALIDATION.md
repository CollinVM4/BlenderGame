# Lucky Blocks implementation and validation - October 30, 2026

This records the initial implementation pass. The subsequent [presentation update report](LUCKY_BLOCK_PRESENTATION_UPDATE.md) supersedes its collectible-appearance/HUD behavior and current validation results.

Branch: `lucky-block-rewards`. Based on clean local main at `1541a6c12d65cf6f114e4a1a2556188089bd5ac7`. Delivered as a working diff; no merge or publication.

## Result and consumer sites

Seven prizes (100 total weight), four session buffs, delayed public pickups, mandatory ingredient overfill, 3/1/1/0 block slots and the Level0 shared clock are implemented. Existing economy, Muncher, protection and presentation constants remain intact.

- `LuckyBlockService.TryClaim`: retains roll/retire/notifications, then schedules the public pickup from presentation constants. `spawnAt` handles both block and pickup template clones. `TryClaimPickup` validates and atomically commits or recovers the same identity/lifetime. `IsBuffActive`, `GetCashMultiplier`, `RemovePlayer` expose server buff/cleanup APIs.
- `CombatService.playerDamageRejection`: rejects StarPower/Invincibility victims. Existing `enemyRejection -> hit` already calls it before bat stun, drops, ragdoll and final damage; no separate initial-hit bypass exists. The `hit` Heartbeat launch callback additionally rechecks immunity before `Knockback.Apply`, covering buffs acquired after impact but before physics.
- `CombatService.SwingBat`: MegaBat scales only the `attackAt[player]` cooldown assignment. `hit` scales the launch at its application site. `BatKnockback.Apply` adds optional scale (default 1), scaling launch speeds and corresponding accumulation bounds; BatConfig and tiers are unchanged. Other callers retain default behavior.
- `IceGunProjectileService.attack` is unchanged: target eligibility consults CanDamagePlayer, then DamagePlayer must succeed before FreezeStatusService.Apply. Real ice integration specs now cover both Lucky immunities.
- `SprintService.Init` Heartbeat sprint-drain branch skips subtraction for StarPower. Existing regeneration/exhaustion behavior remains.
- `CustomerService.CalculatePayout` and `CalculateOrderPayout` use `max(shopFactor, luckyFactor)` for the serving player, including wildcard payouts. Grade, purchased payout, origin, filler and Muncher factors remain. Integration/spec checks include teammate ownership and shop 2x versus Lucky 1.5x.
- `init.server.luau` injects the existing services table into Lucky initialization and calls RemovePlayer through the existing leave cleanup list. No circular requires or new remotes.

## Overfill and failure audit

`GrantIngredient(player, id, allowOverfill?)` preserves all ordinary checks and Origin Unknown. Audit found a second capacity rejection inside private `equipVisual`; it now accepts the same optional flag. Purchased capacity and all other acquisition gates stay unchanged. Backpack selection, ThrowHeld, complete overhead stack/count, storage and serving already support excess held items; real inventory tests cover them.

The existing synchronous grant can fail after a held reservation is created or on a later pack unit. Prevalidation alone was insufficient. `PrepareIngredientReward` therefore stages all selected authored visuals, then uses a one-shot transaction calling GrantIngredient with true. It rolls back only new held records and restores selection on false/error; discovery is deferred until complete success. No grant-path function yields. Recovery cannot duplicate a partial pack or extend its original lifetime. Lucky requires authored ingredient art to avoid the existing normal IngredientGeometry fallback. Ordinary grants retain that legacy behavior.

## Asset/setup limitations and assumptions

No authored LuckyBlockVisuals or Workspace LuckyBlockSpawns tree is available in the Rojo source mappings or checked-in XML exports. PantryPack, TopShelf and MysteryBox models are absent from inspectable repository assets; their live Studio presence is unverified. They remain Collin asset tasks, with existing-style warnings and safe client text fallback. Marker counts are unavailable; enabled levels require >=3/1/1 markers. No geometry, markers or Studio testing tasks were added.

No announced-only catalog flag/set exists. `TODO(LuckyMysteryAnnouncedOnly)` records the missing source. MysteryBox excludes actual IDs Player_Head and Dragon_Fruit (and the catalog's existing PlayerHead alias defensively). No RainbowRampage compatibility alias was necessary. The other discovered compatibility issue was the private carry-capacity gate noted above. There is no blocking design conflict.

## Commands and outcomes

Tools used: Luau 0.745, StyLua 2.6.0, Luau LSP 1.70.1 with Roblox globalTypes definitions, Rojo 7.7.0. CLI tools absent from PATH were downloaded into `.validation-tools` for this run; raw output/tool artifacts are kept outside the delivered diff. There was no repository typecheck script or .luaurc configuration.

Focused validation (exit 0, 15/15 suites):

```powershell
python tests/run_state_tests.py --luau .validation-tools/luau/luau.exe --suite lucky-block --suite lucky-inventory --suite lucky-combat --suite lucky-sprint --suite lucky-block-roulette --suite lucky-block-view --suite lucky-block-controller --suite customer-payout --suite customer-payout-serve --suite icegun-combat --suite icegun-simulated-combat --suite combat --suite combat-launch --suite bat-knockback --suite carry-selection
```

Full runner (exit 1):

```powershell
python tests/run_state_tests.py --luau .validation-tools/luau/luau.exe
```

Final result: 96/128 pass (state 17/23, integration 48/64, presentation 31/41). Baseline: 93/125 pass. The same 32 suites fail on untouched HEAD; no new failures. A baseline tree was extracted using `git archive --format=zip HEAD` through Python zipfile, then run with:

```powershell
python .validation-tools/baseline/tests/run_state_tests.py --luau C:/src/BlenderGame/BlenderGame/.validation-tools/luau/luau.exe
```

Formatting passed (exit 0) for every changed Luau source/spec, including new files. Actual equivalent commands, with the file arrays expanded below:

```powershell
$sourceFiles = @(
    "src/server/Services/BatKnockback.luau",
    "src/server/Services/CombatService.luau",
    "src/server/Services/CustomerService.luau",
    "src/server/Services/InventoryService.luau",
    "src/server/Services/LuckyBlockService.luau",
    "src/server/Services/SprintService.luau",
    "src/server/init.server.luau",
    "src/shared/Constants/LuckyBlockConfig.luau",
    "src/shared/Constants/LuckyBlockPresentation.luau"
)
$luauFiles = $sourceFiles + @(
    "tests/customer_payout.spec.luau",
    "tests/customer_payout_serve.spec.luau",
    "tests/fixtures/customer_payout.luau",
    "tests/icegun_combat.spec.luau",
    "tests/lucky_block.spec.luau",
    "tests/lucky_block_controller.spec.luau",
    "tests/lucky_block_roulette.spec.luau",
    "tests/lucky_block_view.spec.luau",
    "tests/lucky_combat.spec.luau",
    "tests/lucky_inventory.spec.luau",
    "tests/lucky_sprint.spec.luau"
)
.validation-tools/stylua/stylua.exe $luauFiles
.validation-tools/stylua/stylua.exe --check $luauFiles
& 'C:\Users\Collin Van Meter\.aftman\tool-storage\rojo-rbx\rojo\7.7.0\rojo.exe' sourcemap --output .validation-tools/sourcemap.json
.validation-tools/lsp/luau-lsp.exe analyze --platform roblox --sourcemap .validation-tools/sourcemap.json --definitions .validation-tools/roblox.d.luau $sourceFiles
& 'C:\Users\Collin Van Meter\.aftman\tool-storage\rojo-rbx\rojo\7.7.0\rojo.exe' build -o .validation-tools/lucky.rbxlx
git diff --check
```

Rojo sourcemap/build and diff whitespace check passed. Typecheck exits 1 with 40 baseline-reproduced diagnostics: CombatService 9 optional-value errors; CustomerService 1 Grade union error; CustomerRequests 22 missing DisplayText errors; JackedNoobService 8 Instance/refinement errors. Baseline was analyzed with identical source arguments, tool/definitions, and its own generated sourcemap. Diagnostic headers match after normalizing absolute paths and source locations. LuckyBlockService, both Lucky configs, InventoryService, SprintService and BatKnockback have no type errors. No new type diagnostics were introduced; unrelated code was left alone.

Automated tests use the repository's mocked Roblox boundary. Live engine physics/network behavior and live authored assets remain unverified. No live validation or Studio testing work is claimed.

## Baseline failures

Every failure below reproduced on untouched HEAD. Presentation failures remain independently reported by the runner and do not block authoritative suites.

- `ripeness`
- `smoothie-world`
- `smoothie`
- `customer-validation`
- `customer-compatibility`
- `sprint`
- `tutorial-claim`
- `muncher-vacuum`
- `ingredient-cleanup`
- `ripeness-lifecycle`
- `discovery-customers`
- `plot-session-races`
- `plot-session-progression`
- `plot-session-requests`
- `plot-session`
- `customer-queue`
- `customer-serve-anywhere`
- `legacy-state`
- `legacy-movement`
- `requests`
- `world`
- `smoothie-roundtrip`
- `tutorial-hints`
- `ripeness-presentation`
- `jacked-noob-hit-presentation`
- `bat-controller`
- `ingredient-hold`
- `vfx`
- `customer-order-text`
- `customer-orders`
- `blend-presentation`
- `icegun-presentation`

## Every changed file

- `docs/LUCKY_BLOCKS.md`
- `docs/LUCKY_BLOCK_COLLECTION_FIX.md`
- `docs/LUCKY_BLOCK_LEVEL_SPAWNING.md`
- `docs/LUCKY_BLOCK_ROULETTE.md`
- `docs/LUCKY_BLOCK_VALIDATION.md`
- `docs/STAT_UPGRADES.md`
- `src/server/Services/BatKnockback.luau`
- `src/server/Services/CombatService.luau`
- `src/server/Services/CustomerService.luau`
- `src/server/Services/InventoryService.luau`
- `src/server/Services/LuckyBlockService.luau`
- `src/server/Services/SprintService.luau`
- `src/server/init.server.luau`
- `src/shared/Constants/LuckyBlockConfig.luau`
- `src/shared/Constants/LuckyBlockPresentation.luau`
- `tests/README.md`
- `tests/customer_payout.spec.luau`
- `tests/customer_payout_serve.spec.luau`
- `tests/fixtures/customer_payout.luau`
- `tests/icegun_combat.spec.luau`
- `tests/lucky_block.spec.luau`
- `tests/lucky_block_controller.spec.luau`
- `tests/lucky_block_roulette.spec.luau`
- `tests/lucky_block_view.spec.luau`
- `tests/lucky_combat.spec.luau`
- `tests/lucky_inventory.spec.luau`
- `tests/lucky_sprint.spec.luau`
- `tests/run_state_tests.py`
