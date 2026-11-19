# Smart tutorial: state-aware onboarding and recovery

## Goal
A first-time player can explore out of order, carry unrelated items, fail a smoothie, buy upgrades early, die, or cooperate with a teammate without the tutorial skipping essential lessons, looping obsolete prompts, or getting stuck.

## Current code audit (main, 2026-11-18)
- `TutorialService.currentTarget` only evaluates the first tutorial order (`index > 1` breaks), then transitions to upgrades, next customer, market and jump.
- `FirstServeRewarded` is currently treated as an alternative to `order.Served`; verify this flag never conflates payout with a valid completed lesson.
- Carrying **any** ingredient can return `Blender` once the initial ladder branch is bypassed; carrying unrelated market items should not imply completion of stash/ingredient selection.
- `BatchOrders` maps a batch to an order at first observation; a partial or incorrect batch can be attached to the current order before the actual ingredient set is evaluated.
- Wrong full batches have FinishBatch/DrainBatch recovery, but wrong partially loaded batches need a reachable recovery path too.
- `ReachedCounter`, `TookStashItem`, `UsedLadder`, and `LoadedBlender` milestones should be distinguished from current inventory state and evaluated independently.

## Required behavior
1. Separate **durable learning milestones** (counter/order taken, own ladder used, first accepted ingredient, first successful serve) from **transient state** (held items, in-flight throws, batch progress, cup ownership, active order).
2. Compute a single authoritative next actionable instruction on the server, with explicit priority: unblocking full/partial incompatible blender > usable matching cup > required learning step > ingredient acquisition > throw > spin > dispense > serve. Do not treat merely holding a Tool as completion.
3. For the Red first order, evaluate ingredients against the actual customer request. Do not count unrelated items as Red ingredients. If carrying wrong items, provide a concrete stash/drop/swap recovery prompt; if partially loaded with incompatible ingredients, offer a clear way to finish/drain/reset using existing game mechanics. Never claim an invalid batch fulfills the order.
4. After failed service, inspect whether the request is still active and what the player actually has. Do not blindly repeat “make a Red smoothie”; direct them to the missing action and give specific corrective feedback. Keep first-success payout guarded exactly once.
5. If a player visits market, purchases upgrades, or gets unrelated tools before onboarding, preserve the required blender mechanics. Preowned Jump/Bat should satisfy purchase guidance, without skipping blender teaching.
6. Reconcile out-of-order **valid** cups, batch ingestion, dispensing, and teammate serves from server snapshots. Shared order completion must not fabricate personal ladder/throw learning. No client-authoritative milestone claims.
7. Preserve existing plot-session isolation, respawn handling, starter stash behavior, RichText, gleams/beams, platform-specific hints, and tutorial protection semantics. Reset session-only state only on actual session reassignment; don't overwrite persisted completion.
8. Avoid stage oscillation: recompute on meaningful events, debounce transient throw/physics transitions, and don't display a new hint until the authoritative state confirms it.

## Player-perspective acceptance scenarios
- Failed Red smoothie, customer still waiting: clear actionable recovery; no incorrect reward or infinite loop.
- One/two/three random market ingredients carried: no accidental ladder/throw/serve advancement.
- Correct Red ingredients carried without ever using ladder: teaches ladder, then throwing.
- Mixed correct/wrong inventory: instructs the missing ingredients without pretending all three are correct.
- One or two wrong ingredients in blender: recovery is possible, no deadlock.
- Three wrong ingredients in blender, before/after spin: finish/drain as necessary, then correct order.
- Valid Red cup acquired early: direct to order/serve, not remake.
- Valid serve by teammate: shared queue advances but player's personal mechanics guidance remains truthful.
- Bat/Jump purchased early: no duplicate purchase prompt.
- Death during carry, plot reassignment, dropped ingredient, stolen ingredient, delayed queue setup, and late UI mount: coherent recovery without false completion.
- Fast repeated state changes: stable stage; no stale target/beam or contradictory instructions.
- Existing first serve reward paid at most once, even across retries.

## Implementation handoff
Refactor `src/server/Services/TutorialService.luau` around a pure, testable objective resolver that accepts authoritative snapshots. Extend `src/client/UI/TutorialHintText.luau` only for necessary recovery messages; keep existing visual contract. Add focused table-driven tests in `tests/` for every scenario above and document the stage precedence in `docs/TUTORIAL.md`.

## Definition of done
Actual implementation plus tests in this PR before marking ready for review. Run focused tutorial specs, typecheck, StyLua, Rojo build and report pass/fail counts and pre-existing failures separately. Two-client Studio smoke test for wrong batch, out-of-order market, teammate serve, and respawn.

**Current PR status:** design/handoff only. No runtime behavior is changed by this commit.
