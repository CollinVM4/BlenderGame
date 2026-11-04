# Muncher rev2 ? variety, pity and output chains

2026-11-04. Working-tree implementation of the supplied rev2 request. The old 110% EV guardrail and Cheap-floor exception in earlier retune notes are superseded. Rev1 is not implemented.

## Local step-0 findings

All five requested modules exist at their specified paths; none moved. `Muncher.luau` contains the pools and tier bounds, `MuncherRewards` the reward policy, `MuncherService` the session state and commit, `MuncherOutput` the spawn callback, and `Ingredients.luau` the existing catalog.

- Fresh outputs: `MuncherOutput.Spawn` supplies `MuncherImmune = true`. `IngredientService` stores it on the world registry record. `MuncherWorldInput.Eligible` rejects that record with `OutputImmune`. Immunity has no time expiry and remains unchanged.
- Refeeding: `InventoryService.CarryWorldItem` consumes the old world record and keeps its ingredient item. `releaseHeld` calls `IngredientService.Spawn` with that item and server feeding attribution, without the immunity flag. The new record is intentionally feedable.
- Attribute survival: pickup clones the world object for its carry visual, but throw creates new catalog geometry. Arbitrary original attributes do **not** survive the entire cycle. The explicit fallback is a `MuncherGeneration` field on the server-owned `IngredientItem`: `IngredientService.Spawn` copies it into the new record and restores the attribute before publication. Existing throw/drop paths already pass `options.Item`, so they preserve generation without changing `InventoryService`. Stash item copies retain it too.

## Behavior

`PityLosses = 5`, `ChainNerfBasisPoints = 500`, `ChainNerfMaxStacks = 5` are the three new config constants.

The exact supplied four pools contain 12/11/18/16 existing catalog IDs, ordered by nondecreasing catalog value with Dragon Fruit last, totaling 10,000bp each. No catalog, art or request changes. Player_Head (including its legacy alias), Gummy_Bear and Mystery are absent from every pool.

At commit, generation is read attribute-first, then from the world record, otherwise zero. Natural/pre-pass items start at zero. Outputs publish input generation + 1 in the spawn options, registry, ingredient item and `BeforePublish` attribute alongside `MuncherReward`.

Normal rolls retain the existing 70% interpolation. Each input generation adds 500bp of proportional transfer from strictly winning non-jackpot outputs to the first/lowest output, capped at five stacks. The transfer also clamps to available winning mass: some pools/inputs have less than the requested shift, and exhausted entries must become zero rather than negative. Zero available mass is a no-op. Gen-0 weights are unchanged. Generation follows the item across players.

After five committed losses, the next feed selects only strictly winning entries from the interpolated pool, ignoring the chain nerf. If there are no winning entries, it returns the highest output (Dragon Fruit at the ceiling). A pity resolution always resets the loss counter; normal wins and pushes reset it too. Failed consumption does not advance or spend pity. The counter is session-only and is not exposed in player-facing snapshots/UI.

The existing DebugLogging-gated transaction log adds InputGeneration, OutputGeneration, ChainStacks, PityApplied and the post-commit ConsecutiveLosses. Generation still increments on pity feeds. No changes to ownership/entry rules, timing, machine busy behavior, fees, cash, stealing or serving.

Normal-roll jackpot odds remain exactly 0.2%/0.5%/1%/2%, including under the chain nerf. Neither transformation moves Dragon Fruit's weight. The requested pity filter conditions selection on winning entries, so its conditional jackpot probability is naturally renormalized; at the pity ceiling the fallback is deterministically Dragon Fruit.

## Base EV report

Generation zero, no pity, no chain nerf. Fractional basis points remain unrounded during selection. EV is reported, **not gated**.

| Tier | Sample | Input | Expected output value | EV / input |
|---|---|---:|---:|---:|
| Cheap | Floor | $1,000.00 | $1,572.50 | 157.25% |
| Cheap | Midpoint | $2,999.50 | $2,126.71 | 70.90% |
| Cheap | Ceiling | $4,999.00 | $2,680.93 | 53.63% |
| Standard | Floor | $5,000.00 | $5,880.00 | 117.60% |
| Standard | Midpoint | $12,499.50 | $8,372.67 | 66.98% |
| Standard | Ceiling | $19,999.00 | $10,865.33 | 54.33% |
| Premium | Floor | $20,000.00 | $21,960.00 | 109.80% |
| Premium | Midpoint | $34,999.50 | $26,849.06 | 76.71% |
| Premium | Ceiling | $49,999.00 | $31,738.12 | 63.48% |
| High Roller | Floor | $50,000.00 | $47,900.00 | 95.80% |
| High Roller | Midpoint | $107,500.00 | $51,967.37 | 48.34% |
| High Roller | Ceiling | $165,000.00 | $56,034.74 | 33.96% |

## Changed files

- `src/shared/Constants/Muncher.luau`: supplied pools and three tunables; removes obsolete EV-cap comments.
- `src/shared/Types.luau`: optional item generation metadata.
- `src/server/Services/IngredientService.luau`: generation spawn option, item retention, record field and attribute restoration.
- `src/server/Services/MuncherRewards.luau`: generation normalization, proportional chain shift, shared cumulative selection, pity filter/fallback.
- `src/server/Services/MuncherService.luau`: session loss counter, commit decisions, transaction fields and diagnostics.
- `src/server/Services/MuncherOutput.luau`: incremented generation in spawn options and BeforePublish.
- `tests/muncher_rewards.spec.luau`: extends catalog/tier/result/selection coverage with variable-length pool checks, chain and pity contracts; removes obsolete EV-cap assertions and fixed-five-entry assumptions.
- `tests/muncher.spec.luau`: commit-level pity/reset/failure coverage, generation precedence and transfer across players.
- `tests/muncher_vacuum.spec.luau`: fresh-immunity regression plus real pickup/throw generation chain; corrects stale radius expectation from 10 to the existing production value 15 without changing vacuum tuning.
- `docs/MUNCHER_REV2.md`: this diff summary, EV report and acceptance status.

Concurrent Hotbar changes and other validation files are outside this pass and were left intact.

## Validation and Studio acceptance

Automated checks pass: muncher-rewards (authoritative state), muncher and muncher-vacuum (integration), muncher-presentation (presentation), throw and throw-multiplayer. Roblox-aware luau-lsp typecheck of all six changed production modules passes with a fresh Rojo sourcemap and Roblox definitions. StyLua checks of all nine changed Luau files and Rojo place build pass.

The original vacuum suite failed on baseline because it asserted radius 10 against config radius 15; the corrected test now passes, including radius-edge capture. An additional ingredient-cleanup integration run fails at the marker component's missing fixture definition lookup (`Dragon_Fruit`); an isolated HEAD baseline reproduces the same error. That unrelated suite and its production code were left unchanged.

Live Studio results: **not run; acceptance remains pending**. No Studio process or connected Studio execution tool was available. CLI doubles verify the listed contracts but cannot establish real replication, rendered variety, audio, physical feel or live machine timing.

No new Studio assets, catalog IDs, request wiring or machine setup are required. To complete acceptance, use the existing revealed Muncher in Studio and temporarily enable `Muncher.DebugLogging` (increase LogLimit if necessary):

1. Leave a fresh output at the mouth: expect `OutputImmune` and no automatic suck-back.
2. Pick it up and throw it back repeatedly: expect successful feeds, increasing generation and ChainStacks capped at 5. A new player acquiring the item should retain its chain.
3. Observe varied existing rewards over a session. Check loss counters reset on win/push and PityApplied on the feed after five losses; unit tests provide the statistical proof.
4. Confirm unchanged 1.65s chew, 0.15s spit interval, entry authorization and busy rejection, with no new UI.

Restore normal diagnostic settings after the smoke check. No live acceptance item is claimed passed by this document.
