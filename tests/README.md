# Test suite boundaries

Run `python tests/run_state_tests.py --luau <luau.exe>`. The default manifest runs
every suite below, in a fresh Luau process, continues after failures, reports each
group separately, and exits nonzero if any suite failed. `--list` shows selection
without executing. No presentation suite is a prerequisite for gameplay tests.

| Group | Suites | Intended responsibility |
|---|---|---|
| `--group state` | carry, stash, smoothie, customer-compatibility, sprint | Authoritative service contracts: capacity, ownership, order, cleanup, transfer rollback, explicit STORE/TAKE, dispense/serve replay. Compatibility helpers are explicitly separate from current serving. |
| `--group integration` | legacy-state, legacy-movement, requests, world, smoothie-roundtrip, smoothie-survivors | Service/component wiring, request selection, physical-ingredient registry and station lifecycle, cross-system flows. |
| `--group presentation` | vfx, carry-presentation, smoothie-geometry, customer-placement, client-presentation, blend-presentation, stash-presentation | Cosmetic lifecycle, geometry, placement, client startup and progress notification throttling. |

`--throw-only` runs ingredient throw contracts and multipart blender acceptance during collision grace.

Focused flags remain: `--carry-only` includes carry presentation; `--stash-only`
includes stash session/smoothie integration, geometry, and prompts; `--requests-only` includes customer placement;
`--smoothie-only` includes foundation state, round-trip, mixed survivors and
geometry. These sub-suites still report in separate groups. `--vfx-only`,
`--world-only`, and `--sprint-only` select one suite. `--customer-only` retains the
legacy customer/state prefix, now without extracted movement/presentation tests;
use the full integration group to include their remaining integration coverage.
Selectors are mutually exclusive, preventing silently ignored combinations.

The existing standalone UI/prompt/physics runners are unchanged and remain
outside this manifest. This is the state-runner manifest, not all repository tests.

## Fixtures and counting

`fixtures/roblox.luau` is the former shared prefix of `server_state.spec.luau`,
extracted without redesigning its engine doubles. Runners load the explicit file;
they never split a test's source to locate its fixture. `fixtures/carry.luau` and
`fixtures/smoothie.luau` contain the existing feature setup shared by their state,
flow and presentation cases. They are concatenated lexical fixtures, not a new
test framework or standalone Roblox modules.

Use `setup(condition, message)` for fixture preparation and `check` for the
contract under test. Both fail immediately; their counts are reported separately.
Counts mean executed assertions, **not distinct behaviors**. Loops still expand
them, and the older monolith still counts some setup as assertions.

`python -B tests/test_state_runner.py` verifies default coverage, group isolation,
focused selection, and continuation/nonzero exit after a failed suite without
requiring Luau.

## First cleanup pass: retained coverage

| Consolidation/rewrite | Retained authoritative or observable replacement |
|---|---|
| Repeated smoothie connection counts and shared Tool identity assertions removed | `smoothie-survivors`: selected removal preserves usable survivors; stale old Tool activation/unequip cannot affect a new stack. Mixed lifecycle matrix stays in smoothie state. |
| Single-ingredient death/reset/destroy repetitions removed from carry setup | Full-stack lifecycle matrix in carry state, plus missing-character/repeated-event/disconnect cases in legacy-state. |
| Motor/handle checks removed from every gameplay setup | Representative attach/throw/drop/clear checks in carry-presentation, including initially disabled motor state. |
| Duplicate all-smoothie mixed-capacity row removed | Smoothie capacity loop already exercises capacities 1–3; mixed ingredient/smoothie rows remain. |
| Generic stash foreign/protected/dead checks and ingredient slot capacity repeated in smoothie removed | Stash interaction and legacy-state retain access, capacity and failure preservation. Smoothie-specific nonstacking, metadata isolation and visual/equip rollback remain. |
| Second frozen-origin stash flow removed | One frozen-origin round-trip remains; earlier multipart reconstruction and generic stash tests retain the other contracts. |
| Frozen-item destruction-order callback removed | Successful pickup must transfer registry ownership; carried visuals and subsequent throw/drop must be unfrozen. No assertion requires unanchoring a retiring object before `Destroy`. |
| Duplicate request schema block removed from legacy-state | Request integration validates all IDs and tier values. Arbitrary ingredient arrays are explicitly labeled unit-level tag validation. |
| Nameplate style repeated for every special customer reduced to one representative | Every NPC still exercises configured name/request mapping, tier gating, refresh and fallback. Shared styling is checked for steak. |
| Legacy payout/grade/random-reaction block moved | `customer_compatibility` retains all original checks. Current `Serve` payout/replay remains in state and integration tests. |

No entire spec was deleted and no unique gameplay contract was intentionally
removed. Most line changes are fixture/test moves. Approximately 8–10 duplicate
assertion/scenario clusters were consolidated; this is not a reduction in intended
behavioral coverage. Comparing the original five focused suites with their moved
coverage (excluding the new round-trip and newly selected stash geometry), roughly
190 repeated/structural assertion evaluations were retired. Setup accounting is
separate from that estimate and is not treated as a coverage reduction.

## Repaired drift and new flow

- VFX now supplies three ingredients wherever it expects a blend to start.
  The start case captures live arrival effects by their visual objects, requires
  a successful start, and verifies their cancellation/destruction without assuming
  which tween was created first. Authored Fruit/Leaf appearance is distinguished
  from generated assembly parts; every physical proxy part must remain inert.
- VFX uses an inventory boundary double for dispense presentation; real capacity,
  grants and ownership remain covered in state and round-trip tests.
- Legacy-state fixtures use an Instance for world ingredients, complete character
  transforms, and retain the shared `CFrame.lookAt` when customizing transforms.
- The old serving flow selects a deterministic Red request, so catalog expansion
  cannot randomly turn its success case into failure. Customer request serving
  doubles now contain three ingredients.
- Rotated stash geometry checks usable surface sizing and clearance instead of
  the stale exact 4.4-stud tuning value. Client presentation startup ignores
  unrelated controller internals rather than requiring fixture edits per controller.
- `smoothie-roundtrip` exercises real blend → dispense → stash → take → serve,
  preserving BlendId and ordered duplicate ingredients, removing the stored copy,
  and consuming/paying/completing once. `smoothie-survivors` retains the mixed-stack
  removal/activation flow independently of its visual reflow assertions.

## Validation for this pass

| Suite | Behavioral assertions | Setup validations | Result |
|---|---:|---:|---|
| carry | 53 | 22 | PASS |
| stash | 49 | 63 | PASS |
| smoothie | 65 | 44 | PASS |
| customer-compatibility | 5 | 0 | PASS |
| sprint | 32 | 0 | PASS |
| legacy-state | 707 | 0 | PASS |
| legacy-movement | — | — | FAIL; pre-existing stale baseline |
| requests | 247 | 31 | PASS |
| world | 167 | 3 | PASS |
| smoothie-roundtrip | 5 | 8 | PASS |
| smoothie-survivors | 7 | 5 | PASS |
| vfx | 135 | 0 | PASS |
| carry-presentation | 44 | 3 | PASS |
| smoothie-geometry | 11 | 3 | PASS |
| customer-placement | 17 | 0 | PASS |
| client-presentation | 11 | 0 | PASS |
| blend-presentation | 19 | 0 | PASS |
| stash-presentation | 110 | 0 | PASS |

All requested focused commands pass. Groups: state 5/5, integration 5/6,
presentation 7/7. The aggregate deliberately remains red: the unchanged extracted
movement scenario expects speed 22/stamina 110, while current upgrade definitions
use 25/60. It was previously hidden behind the VFX failure and remains out of this
inventory/customer cleanup's scope.

Runner tests: 4/4. Roblox-aware Luau LSP analysis of `src`, using installed Roblox
definitions and a fresh Rojo sourcemap: PASS, with an existing deprecated
`LoadCharacterAppearance` warning. StyLua on changed/new Luau tests: PASS.
Rojo 7.7 build: PASS. Build/sourcemap/check logs were written to the temporary
directory. No production edits or Studio setup are required for this cleanup.

## Remaining boundaries and limitations

- Legacy-state is still a sequential integration monolith. Display inertness,
  order bubbles, presentation event totals and Studio adapters remain interleaved
  with transactions. A failure can stop that spec, but cannot stop other suites.
- Request integration still includes nameplate/template checks. They are explicitly
  mixed integration coverage; only standalone placement moved in this pass.
- Carry fixtures still construct motors for both slices, and smoothie geometry
  uses the existing feature fixture. Further fixture slimming is deferred.
- Fake transforms, bounding boxes, cloning, task queues and manually fired signals
  are approximations. No engine redesign or comprehensive fixture typecheck was
  introduced; CLI execution validates the generated bundles.
- Studio smoke coverage must still validate real multipart welds, Tool activation
  and respawn, two-client contention, replication and rendered NPC/stash geometry.
  No Studio session was run. No SmoothieWorldItem behavior was added.

## Customer queue migration

`--customer-queue-only` runs the new plot/queue lifecycle integration suite.
`--customer-presentation-only` includes simultaneous owner visibility for three
orders, separately from gameplay. Existing request tests now activate owned
plots and assert continuous cooldown/serving instead of day completion. See
[customer queue validation](../docs/CUSTOMER_QUEUE.md#validation) for the
current results, baseline failures, and required Studio checks.

## Blender ready floor cue

The standalone presentation suite is `python tests/run_blender_ready_tests.py --luau <luau.exe>`.
See [setup and validation](../docs/BLENDER_READY_INDICATOR.md) for readiness, lifecycle coverage, and Studio checks.

## Shared plot-session foundation

Use repeated `--suite` selectors for `plot-session`, `plot-session-races`,
`plot-session-progression`, and `plot-session-requests`. The separate
`plot-session-feedback` suite covers shared warning deadlines and stale timers.
See [architecture, validation, baseline failures, and Studio smoke steps](../docs/PLOT_SESSIONS.md).

## Request variety

`--suite request-selection` owns request catalog uniqueness, tier eligibility,
exact ID recency, group/similarity preferences and fallbacks, special history
isolation, and advanced serving contracts. It shares setup in
`fixtures/customer_requests.luau` with the older `requests` template/serving suite,
but runs independently so legacy presentation assertions cannot block selection.
`--suite customer-order-text` covers stable alternate dialogue, empty/legacy
fallback, and formatted label refreshes. Both are included in the default manifest.


## Bat combat

`--suite combat` runs the Bat PvP integration contracts with real CombatService,
InventoryService, MovementService, shared upgrade transactions and request adapter.
It covers ownership, target authority, cooldown, stun/immunity, theft and lifecycle
cleanup. Engine overlap/physics remain Studio smoke checks; see
[`docs/BAT_PVP.md`](../docs/BAT_PVP.md). Sprint stun contracts use the server
MovementService API. Retired damage-slap assertions were removed from legacy-state.

`--suite upgrade-sync` verifies initial shared-upgrade attribute publication for
unclaimed players, real Sprint/Jump/Bat purchase receipts, and nonblocking Bat
asset failures. The upgrade UI runner also tests independently delayed BatLevel
replication. Sprint covers callbacks delivered after movement state removal.

`--suite bat-controller` is a separate presentation suite for local swing playback,
shared cooldown, intent-only requests, missing assets and track cleanup. It is
not a prerequisite for authoritative combat tests.


Isolated R15 ragdoll: `--suite ragdoll` validates preparation, all fourteen joint
toggles, property restoration, repeated calls, and death/removal cleanup using
engine doubles. It is a separate presentation suite and cannot prove physical
collapse or getting up. The obsolete bat-reaction/stun-controller suites were
removed with those modules. `combat` verifies authoritative stun/drop/immunity
without physical ragdoll. See `docs/RAGDOLL.md` for manual Studio acceptance.

## Scrapbook GUI

Run `python tests/run_scrapbook_ui_tests.py --luau <luau.exe>` for the standalone
presentation/controller suite. It uses real modules at a fake Roblox boundary and
remains separate from authoritative discovery suites. Studio setup and manual
layout checks are documented in `docs/SCRAPBOOK_GUI.md`.

## Player Head death drops

`--suite player-head` covers the character death and identity round-trip through
normal inventory, stash, theft, throw, blender input, and loose cleanup.
`--suite player-head-visual` covers avatar cloning, sanitization and fallback.
`--suite player-head-stash`, `--suite player-head-blender-visual`, and the ingredient prompt runner's `--player-head-only`
flag keep head presentation checks separate. See [setup and validation](../docs/PLAYER_HEAD_DROPS.md).

## Bad customer first pass

`--suite bad-customers --suite bad-customer-stash` runs the new customer lifecycle,
queue-front/owner authority, Serve/Dismiss/Reject races, Thief/Freeloader outcomes,
real stash isolation and real blender/smoothie preservation integration.
`--suite bad-customer-presentation` separately verifies only new REJECT lettering
and inert stolen geometry. Presentation is not a prerequisite for gameplay.
Existing normal request/payout, queue, walk and ragdoll tests keep their original
homes. See [BAD_CUSTOMERS.md](../docs/BAD_CUSTOMERS.md) for Studio smoke checks and
baseline validation limitations.


## Walk-in claiming and stand identity

`--suite stand-identity --suite plot-player-flow` checks zone entry, existing
session membership and filtered rename authority. Presentation remains separate:
`--suite stand-sign --suite stand-editor --suite plot-identity`. The turbine camera
runner verifies the editor handoff preserves its existing contracts. See
[STAND_IDENTITY.md](../docs/STAND_IDENTITY.md) for Studio setup, validation and
pre-existing session/typecheck/runner blockers.

Naming-specific coverage now includes the shared 27-grapheme contract, conservative
token/separator masking, both Roblox filter failure stages, safe star publication,
duplicate SAVE/on-screen Return/FocusLost events, controller navigation and keyboard
placement calculations. `fixtures/stand_graphemes.luau` is a limited CLI Unicode
double; engine segmentation, native keyboards and rendered readability require the
Device Simulator checks documented in that guide.

## Mobile action layout

`python tests/run_mobile_control_layout_tests.py --luau <luau.exe>` runs the
separate mobile presentation/input suite with the real layout helper and both
controllers. It owns screen geometry, safe bounds, native/CAS recreation,
initialization and layout teardown; gameplay authority remains in the existing
carry-input and sprint suites. It is not a prerequisite for gameplay suites.
Manual Device Emulator checks and the baseline fixture blockers are recorded in
`docs/MOBILE_CONTROLS.md`.

## Explicit stash interactions

Stash state covers explicit STORE/TAKE across pauses and rapid taps, immediate
action switching, protected/exposed capacity three, permissions, ripest ordering,
rollback, replay/throttle rejection, and unchanged raid deadlines. Stash integration
covers real teammates and smoothie exclusivity/identity; expansion covers the
authored expanded prompt and unlock. Stash-prompts executes the real controller
for touch, keyboard, and controller dispatch, focus/navigation, availability and
server feedback. Presentation checks run independently of state checks.

See [Player stash](../docs/PLAYER_STASH.md) for Studio/device smoke checks.

## Mobile pickup and dispensing

Use `run_mobile_prompt_tests.py` for touch geometry, overlap routing and input
isolation, plus `--suite smoothie-dispense` for the independent authoritative
dispense contracts. See [mobile pickup validation](../docs/MOBILE_PICKUP.md)
for commands, baseline failures and physical-device checks.
