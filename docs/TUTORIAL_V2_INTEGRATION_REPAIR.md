# Tutorial V2 / Starter Stash post-merge repair

Validated November 9, 2026 on `fix/tutorial-v2-integration`, branched from fetched
`origin/main` at `21e8f54`. No merge, push, or publication is part of this pass.

## Integration repair

`TycoonService.AssignPlot` publishes membership before `SessionStarted`. The latter
opens the persisted starter stash and may yield before activating the customer
queue. An already-started TutorialService runtime previously treated a missing
queue as completed onboarding. On reclaim this prematurely set `Tutorial.Complete`,
which suppressed the first successful serve's reward floor; a delayed first claim
could also bypass onboarding entirely.

`CustomerService.IsActiveForPlayer` now exposes server-owned queue readiness.
TutorialService waits at ClaimPlot while no current queue exists. An active normal
queue still completes introductory guidance, and existing completed profiles keep
their completion. No gameplay payouts, ownership rules, customer selection weights,
or upgrade requirements were changed. Both real-bootstrap delayed-load and real
reassignment regressions fail against the original merged production modules and
pass with this repair.

InventoryService, PlayerDataService, and bootstrap initialization were inspected.
Their existing stash restore, shared-session binding, cleanup, initialization guards,
and copied tutorial snapshots needed no production changes in this pass.

## Registry and restored coverage

- One registration each for tutorial-claim and tutorial-gameplay. Both retain
  smoothie + stash_persistence; gameplay also loads intro_customers for authored
  CaseOh selection. Claim only exercises Red and needs no special-avatar fixture.
- The runner rejects duplicate SUITES keys before Python can overwrite them,
  including for `--list`, and reads all registered fixtures/specs before selection.
  Python regressions inject duplicates and a missing unselected manifest file.
- No additional stash fixture is necessary: smoothie supplies the real inventory,
  stash geometry, `press`/InteractStash, blender and customer services;
  stash_persistence supplies the detached store boundary. Gameplay now withdraws
  via the actual TAKE interaction rather than bypassing it through Withdraw.
- Starter-stash independently pins all five ingredient recipes and slot indices,
  verifies all fifteen original unit identities survive repeated initialization,
  and checks every depleted slot stays empty. Existing protection, theft, raid,
  promotion, persistence, stale-load/write, and failure recovery tests remain.
- Gameplay restores partial withdrawal/ladder guidance, canonical thrown unit
  identity, missed throws, duplicate ingestion rejection, partial blend readiness,
  cup consumption, duplicate first-serve protection, and cumulative serve-task
  progression. It exercises actual replacement characters, reclaim, disappearance
  and stale customer calls, teammate queue/stash reuse, shared cash/reward guards,
  and serving while optional upgrade guidance remains visible.
- The customer queue boundary now supplies IsDoubleCashActive. Its stale hardcoded
  economy totals were replaced by the live payout formula; independent payout
  suites remain responsible for formula correctness.
- Python runner tests retain group isolation, continuation after failure, focused
  selectors and both VFX harness callers without assuming an obsolete manifest
  size or first presentation suite.

## Verified intended behavior

1. Customer one is Red, fulfilled with the real Apple, Cherries and Strawberry
   from protected Slot 1 through TAKE, throw, blender, dispense and Serve.
2. The first valid fulfilled delivery receives at least $30,000 once per shared
   session; higher computed payouts remain intact. Invalid/unfulfilled deliveries,
   replays, queue reconstruction and completed profiles cannot mint another floor.
3. Jump 1 and Bat 1 are both recommended and optional. No-purchase and Bat-first
   shared-session paths reach Market, MarketJump and Complete while customers two
   and three remain unserved. Serving continues through recommendations.
4. Customer two is standard Cold; customer three is the canonical `caseoh` avatar
   and `Caseoh` request. Both use normal computed payouts. The separate third-serve
   task milestone remains additive. Normal customer selection resumes afterward.
5. Slots 1-5 contain Red (Apple/Cherries/Strawberry), Yellow (Banana/Lemon/Pear),
   Cold (Ice/Ice/Ice), Veggie (Cabbage/Carrot/Mushrooms), and Milk (Milk/Milk/Milk).
   Slots 1-2 retain authored protection; slots 3-5 use ordinary theft/raid rules.
   Reinitialization, respawn, joining and reclaim never reseed depleted contents.

No assertions requiring three mandatory tutorial customers were restored.
TutorialOrders' legacy extra recipe entries do not govern the introductory queue:
IntroCustomers owns queue positions/payout floors; StarterStash owns all five slots.

## Validation

Core gameplay selection: **15/15 PASS, 0 failures**. Expanded gameplay selection:
**20/21 PASS, 1 baseline failure** (state 5/5; integration 15/16). Presentation:
**6/6 PASS, 0 failures**, independently reported. Combined selection: **26/27 PASS**.

| Suite | Behavioral assertions | Setup validations | Result |
|---|---:|---:|---|
| tutorial | 48 | 0 | PASS |
| tutorial-claim | 10 | 5 | PASS |
| tutorial-gameplay | 74 | 41 | PASS |
| starter-stash | 238 | 33 | PASS |
| tutorial-payout-serve | 22 | 18 | PASS |
| customer-queue | 69 | 7 | PASS |
| customer-payout | 83 | 3 | PASS |
| customer-payout-serve | 57 | 6 | PASS |
| tasks | 46 | 66 | PASS |
| tasks-serve | 21 | 15 | PASS |
| protection | 18 | 0 | PASS |
| protection-gameplay | 43 | 16 | PASS |
| protection-ice | 6 | 3 | PASS |
| stash | 490 | 185 | PASS |
| stash-integration | 16 | 16 | PASS |
| customer-serve-anywhere | not reported | not reported | FAIL (baseline) |
| request-selection | 556 | 158 | PASS |
| customer-wildcard | 51 | 20 | PASS |
| upgrade-sync | 230 | 38 | PASS |
| initial-spawn | 38 | 13 | PASS |
| stash-expansion | 67 | 15 | PASS |
| tutorial-hints | 121 | 0 | PASS |
| tutorial-targets | 83 | 1 | PASS |
| tutorial-beam-stability | 18 | 0 | PASS |
| stash-presentation | 79 | 0 | PASS |
| stash-capacity-indicators | 394 | 0 | PASS |
| stash-prompts | 45 | 0 | PASS |

Counts are executed assertions, not unique behaviors; the failed suite stops
before a count report. No unrelated movement, combat presentation or legacy
regression suites were run.

| Check | Result |
|---|---|
| Python runner validation | 8/8 tests PASS; baseline 1/5 (4 stale failures) |
| Registered fixture loads | 21/21 distinct ordered combinations PASS; all 20 fixture files (18 optional plus roblox/session) exist and load |
| Generated suite syntax | 145/145 bundles compile with luau-compile; these are syntax checks, not 145 executed gameplay suites |
| StyLua | PASS on all 8 touched Luau files |
| Roblox-aware whole-src typecheck | FAIL: 212 existing TypeError headers; 0 added, 0 removed versus all three snapshots below, preserving multiplicity and normalizing file roots/line numbers |
| Rojo build | PASS with default.project.json |
| git diff --check | PASS |

Tools: installed Luau 0.745, StyLua 2.6.0, luau-lsp 1.70.1 with installed
`globalTypes.d.luau` and freshly generated per-snapshot Rojo sourcemaps, Rojo 7.7.0.
The Aftman shim could not resolve its home under the subprocess environment, so
validation used the installed Rojo 7.7.0 executable directly.

### Baselines and remaining failures

Each baseline was extracted with git archive into its own temporary directory and
ran its original registry/tests with the same Luau executable. The selected 21
state/integration suites above were used (Tutorial V2 has no starter-stash suite).

| Snapshot | Gameplay suites | Python runner | Whole-src type errors |
|---|---:|---:|---:|
| Merged main `21e8f54` | 18/21 PASS, 3 FAIL | 1/5 PASS, 4 FAIL | 212 |
| Pre-merge main / Starter Stash `16b74b5` | 19/21 PASS, 2 FAIL | 1/5 PASS, 4 FAIL | 212 |
| Original Tutorial V2 `d77d13d` | 17/20 PASS, 3 FAIL | 1/5 PASS, 4 FAIL | 212 |
| Repair | 20/21 PASS, 1 FAIL | 8/8 PASS | 212 |

The remaining customer-serve-anywhere failure is `SETUP: spawn customer at each
marker`, reproduced at exactly that setup assertion on all three snapshots.
It is outside tutorial/stash repair; neither its production behavior nor its
position-selection test was changed. Existing type errors remain in
CustomerRequests, CombatService, JackedNoobService and CustomerService. There are
no new normalized diagnostic headers from this repair. The merged main's other
failures were the lost intro_customers fixture and missing cash-boost fixture API.
The original Tutorial V2's claim suite also lacked unrelated bootstrap doubles;
Starter Stash already supplied those fixes in the merged code.

Reproduce core selection:

```powershell
python tests/run_state_tests.py --luau .validation-tools/luau.exe --suite tutorial --suite tutorial-claim --suite tutorial-gameplay --suite starter-stash --suite tutorial-payout-serve --suite customer-queue --suite customer-payout --suite customer-payout-serve --suite tasks --suite tasks-serve --suite protection --suite protection-gameplay --suite protection-ice --suite stash --suite stash-integration
python -B tests/test_state_runner.py
```

Expanded selection adds customer-serve-anywhere, request-selection,
customer-wildcard, upgrade-sync, initial-spawn and stash-expansion. Presentation
selection is tutorial-hints, tutorial-targets, tutorial-beam-stability,
stash-presentation, stash-capacity-indicators and stash-prompts.

## Release dependency: DataStore V1

No DataStore V1 work was implemented. The existing dedicated stash persistence
system remains unchanged. `Tutorial.FirstServeRewarded` and `Tutorial.Complete`
are still memory-only PlayerDataService fields and are released on player removal.
Cross-reconnect/server-restart reward and completion protection remains a release
blocker until DataStore V1 hydrates these fields before claims and saves them with
its authoritative progression transaction/migration. Runtime shared-session guards
and persisted stash contents do not supply persistent tutorial/cash progression.

## Required Studio acceptance

No new assets, tags, remotes or configuration are required. Retain unique SlotIndex
surfaces 1-5, existing protection designations, and the imported canonical CaseOh
model under ServerStorage.CustomerNPCs.Special with CustomerId `caseoh`. Stash
claims require the existing API-enabled published test experience; test with
separate test records. Missing CaseOh art intentionally diagnoses the missing
asset rather than substituting another customer.

CLI engine doubles do not replace these unexecuted Studio/network checks:

1. Two-client initial claim and reclaim with delayed stash loading: guidance must
   wait, then reveal Red, with no premature completion or lost $30,000 floor.
2. Take all three Slot 1 fruits using actual prompts; throw into/miss the blender,
   recover, blend, dispense and serve. Check tool activation, rendered stash counts,
   progression beams and server-replicated cash on both clients.
3. Let a teammate serve first; retry/stale prompts cannot duplicate payout. Reset
   characters, release/reclaim and promote the teammate; verify shared items,
   protection, customer identity and progress remain consistent.
4. Decline both upgrades, or buy Bat first. Verify both optional prompts, Market
   and jump guidance complete before serving Cold or CaseOh; verify CaseOh's real
   artwork/name/request and ordinary payouts, then normal random arrivals.
5. Destroy a customer during travel/serving and verify replacement without free
   rewards. Drain/steal all slots, respawn/reclaim/rejoin/restart, and verify no
   starter reseed; exercise API denial and competing stash leases fail-closed.

Do not interpret the final reconnect/restart stash check as tutorial persistence:
that separate guarantee depends on DataStore V1 above.
