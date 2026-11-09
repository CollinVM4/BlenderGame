# Tutorial V2

Implemented only on `feature/tutorial-v2`; no merge or publication.

## Behavior and ownership

- `IntroCustomers` defines the existing queue's opening positions: Red immediately,
  Cold at eight seconds (regular customer), canonical CaseOh at sixteen seconds.
  Normal selection resumes after the three positions have been inserted. Lost or
  unfulfilled introductory orders retain the existing replacement behavior.
- Only Red receives a payout floor: `max(computed payout, 30000)`. It is credited
  once through the existing shared-session transaction. The customer record,
  queue guard and owner profile guard prevent repeat serves and queue reconstruction
  from awarding another floor. Both present teammates record the reward state;
  either may serve, and the cash belongs to their shared stand.
- Cold and CaseOh retain computed payouts. Existing independent task rewards remain
  unchanged. Jump 1 costs $10,000 and Bat 1 costs $20,000: exactly $30,000 combined.
- The guide preserves counter/order, stash, ladder, throw/blender, turbine,
  dispensing and serving for customer one. It then recommends both upgrades for
  up to eight seconds, introduces MARKET for seven seconds and higher ingredients
  for seven seconds, and completes. Purchases and travel are optional. Buying one
  upgrade updates the remaining recommendation; owning both skips that hint.
  Customers two and three never gate completion. Existing follow-up farm guidance
  remains independent.
- Hints highlight RED, UPGRADES, JUMP, BAT and MARKET. Dynamic input labels retain
  escaping. The existing safe-inset announcement surface gets a tutorial-only
  compact upper-center layout, narrower on landscape touch screens. Other banner
  callers and Framewisp panels keep their existing layout.

## Starter-stash branch contract

Read-only coordination was performed against `feature/starter-stash` at `e8f55ba`.
Locked Slot 1 contains **Apple, Cherries, Strawberry**, all Red. This branch matches
that exact first-order contract in `TutorialOrders`; guidance evaluates the Red
request rather than requiring those exact IDs, so three other red ingredients
also work. No starter-stash seeding implementation was changed here.

The starter-stash branch owns authored locked-slot resolution, protected capacity,
seeding, persisted stash records and the other starter groups. Its TutorialOrders
first payout floor must retain this branch's $30,000 value when integrated; its
old second-customer floor is retired. `IntroCustomers` owns customer queue identity
independently of the legacy starter groups in TutorialOrders. Do not replace the
third queue request with the old Yellow starter group.

## Canonical CaseOh artwork/data

Existing mapping: `CustomerRequests.NPCs.caseoh`, request `Caseoh`, configured
presentation name `dookieman12`. The existing authored model is selected from
`ServerStorage.CustomerNPCs.Special` by normalized `CustomerId = "caseoh"`.
Its authored template, artwork and display-name rules are retained; no ID, avatar, cheese request or display
name was invented. CustomerNPCs is preserved by Rojo's existing
`$ignoreUnknownInstances` mapping; authored avatar geometry is not stored in this
repository. A missing/malformed CaseOh template is diagnosed rather than silently
substituting a different third customer. Only the introductory encounter bypasses
CaseOh's normal Jump-tier eligibility, so declining Jump cannot prevent arrival.
Normal special selection retains its existing eligibility and cooldown rules.

## DataStore V1 integration boundary

As explicitly requested, **no tutorial DataStore or second persistence system was
added**. `PlayerDataService.GetTutorialState` exposes server-owned memory profile
fields `Tutorial.FirstServeRewarded` and `Tutorial.Complete`; GetSnapshot copies
these fields. Both default false for older memory profiles. Duplicate data/runtime
initialization preserves completion, as do respawns and plot changes. A completed
owner starts the normal customer pool and completed personal profiles never
receive another first-serve floor.

**Cross-session reward protection and tutorial completion persistence require
DataStore V1 integration.** Player removal still releases the memory profile.
DataStore V1 must hydrate these flags before tutorial initialization/plot claims,
retain known completion during migration, and persist the reward/completion state
with its authoritative profile transaction. The queue and presentation timers are
runtime state, not another save schema. This pass makes no reconnect/server-crash
persistence guarantee before that integration.

## Validation

Commands use the installed `.validation-tools/luau.exe` and StyLua 2.6.0,
luau-lsp 1.70.1 with Roblox definitions and a fresh Rojo sourcemap, and Rojo 7.7.0.

```powershell
python tests/run_state_tests.py --luau .validation-tools/luau.exe --suite tutorial --suite tutorial-gameplay --suite tutorial-payout-serve --suite tutorial-hints --suite customer-payout --suite customer-payout-serve --suite request-selection --suite tutorial-targets --suite tutorial-beam-stability --suite upgrade-sync --suite tasks --suite customer-wildcard --suite protection-gameplay --suite tasks-serve
python tests/run_tutorial_alert_tests.py --luau .validation-tools/luau.exe
```

- Focused suites: 14/14 pass; separate alert model: 21 contracts pass.
- Changed/new Luau files: StyLua check passes. Rojo build passes.
- Whole-source typecheck: FAIL, **212 existing TypeError headers**, matching the
  pre-edit baseline including multiplicity after normalizing line numbers. No
  added or removed normalized error headers.
- `tutorial-claim`: FAIL on baseline and current at missing UnstuckService fixture
  dependency (`loadstring` receives nil), before tutorial behavior executes.
- `customer-queue`: FAIL on baseline and current because its PlayerDataService
  double lacks `IsDoubleCashActive`. New queue/serve behavior is covered separately
  by tutorial-gameplay and tutorial-payout-serve using real services.
- Python test_state_runner: 1/5 pass, same four failures in an isolated archive of
  HEAD. Its stale manifest/bundle expectations are unrelated to this change.
- Baseline tutorial-gameplay and tutorial-hints also failed: the former lacked a
  current payout dependency in its fixture, and the latter expected old wording.
  Those focused fixtures/expectations were repaired here. No unrelated production
  code was changed to address baseline failures.

Tests exercise real services at simulated engine boundaries, including solo and
shared-stand first delivery, rejected/lost customer recovery, duplicate serves,
queue reconstruction, completed memory profiles, computed payouts, optional
purchases, safe-inset layout dimensions and input wording. No live device, native
rendering or multiplayer networking session was run; CLI geometry checks cannot
establish rendered legibility on every device.
