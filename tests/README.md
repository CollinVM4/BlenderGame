# Test suite boundaries

World billboard sizing: `python tests/run_billboard_tests.py --luau <luau.exe>`
owns the shared stud-size/culling/text contracts and repository-wide direct-size
lint. This is an independent presentation check, not a prerequisite for gameplay
state suites. See [the convention, sizing table and Studio acceptance](../docs/BILLBOARD_CONVENTION.md).

Lucky Blocks: `--suite lucky-block` owns spawn clocks, roll/claim lifecycle, buff clocks,
item selection and recovery. `lucky-inventory` owns actual overfill and batch rollback;
`lucky-combat` owns buff combat integration; `lucky-sprint` owns stamina effects.
Cash contracts remain in customer-payout/customer-payout-serve; ice immunity stays
in icegun-combat (also reused by icegun-simulated-combat). Presentation remains
separate in lucky-block-roulette, lucky-block-view and lucky-block-controller.
`lucky-handoff` covers partial/terminal replication and stationary public rewards;
`lucky-hud` covers server-expiry messages, keyed refresh, styling and UI recreation.
See [current behavior](../docs/LUCKY_BLOCKS.md) and [validation](../docs/LUCKY_BLOCK_VALIDATION.md).

Fall damage: `--suite fall-damage` owns the unchanged damage curve and scripted
Heartbeat episode contracts: same-ledge walk/jump comparisons, high-speed grazes,
immediate shelf drops, safe jumps/bounces, soft confirmation, capped compensation,
rig/ragdoll support, resets, and bounded episode diagnostics.
`--fall-damage-fix-contracts` remains a compatibility selector for the same suite.
See [the two-state tracker and Studio checks](../docs/FALL_DAMAGE_DIAGNOSTICS.md).

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
| Duplicate all-smoothie mixed-capacity row removed | Smoothie capacity loop already exercises capacities 1â€“3; mixed ingredient/smoothie rows remain. |
| Generic stash foreign/protected/dead checks and ingredient slot capacity repeated in smoothie removed | Stash interaction and legacy-state retain access, capacity and failure preservation. Smoothie-specific nonstacking, metadata isolation and visual/equip rollback remain. |
| Second frozen-origin stash flow removed | One frozen-origin round-trip remains; earlier multipart reconstruction and generic stash tests retain the other contracts. |
| Frozen-item destruction-order callback removed | Successful pickup must transfer registry ownership; carried visuals and subsequent throw/drop must be unfrozen. No assertion requires unanchoring a retiring object before `Destroy`. |
| Duplicate request schema block removed from legacy-state | Request integration validates all IDs and tier values. Arbitrary ingredient arrays are explicitly labeled unit-level tag validation. |
| Nameplate style repeated for every special customer reduced to one representative | Every NPC still exercises configured name/request mapping, tier gating, refresh and fallback. Shared styling is checked for steak. |
| Legacy payout/grade/random-reaction block moved | `customer_compatibility` retains all original checks. Current `Serve` payout/replay remains in state and integration tests. |

No entire spec was deleted and no unique gameplay contract was intentionally
removed. Most line changes are fixture/test moves. Approximately 8â€“10 duplicate
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
- `smoothie-roundtrip` exercises real blend â†’ dispense â†’ stash â†’ take â†’ serve,
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
| legacy-movement | â€” | â€” | FAIL; pre-existing stale baseline |
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

## Bat-only bad customers

`--suite bad-customers --suite bad-customer-stash` covers derived purchased Bat
eligibility, exact NPC hit authority for either teammate, retired actions/remotes,
normal customer recovery, theft commit/escape/recovery, replay, reset and ownership
changes. `bad-customers` includes real CombatService issuance and overlap dispatch.
`--suite bad-customer-presentation` independently checks inert stolen geometry.
Existing `customer-bat` and `npc-combat` retain normal recovery and geometry authority.
See [BAD_CUSTOMERS.md](../docs/BAD_CUSTOMERS.md) for validation and Studio checks.

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

## Ragdoll unstuck recovery

Use `--suite unstuck --suite unstuck-placement --suite unstuck-fallback --suite unstuck-ui`
for authorization, destination clearance, assigned-plot fallback integration, and
presentation/input. The shared resolver is covered by `--suite initial-spawn`;
authorized teleport history and subsequent natural falls by `--suite fall-damage`.
Native joint/collision restoration remains in the independent `--suite ragdoll` home.
See [UNSTUCK setup and Studio acceptance](../docs/UNSTUCK.md) for the ten-stud lift,
current-plot fallback, device/multiplayer checks, and validation limitations.


## Bat launch tuning

`--suite bat-knockback` owns target values, mass-normalized impulse math, direction,
speed bounds, and ownership-policy restoration. `--suite combat-launch` uses the shared
bat combat fixture to run upgrade launch, one-hit, immunity, deferred callback,
ragdoll failure, cross-target dispatch, death/reset/respawn, and ownership interruption
contracts independently of the mixed `combat` inventory/adapter suite. Existing native
joint/collision restoration stays in `ragdoll`; actual landing/recovery history stays in
`fall-damage`. See [tuning, baseline blockers, and per-level multiplayer Studio checks](../docs/BAT_LAUNCH_TUNING.md).

## Ice Shotgun

Use `--suite icegun-combat --suite icegun-aim --suite freeze-status --suite freeze-bat`
for cone geometry, multiplayer/occlusion, authorization, aim, freeze immunity and
real bat/freeze overlap recovery. Existing entitlement, initial-owner and simulated
combat suites retain acquisition coverage. Input/presentation remains separate.
See [current configuration and Studio acceptance](../docs/ICE_SHOTGUN.md).

`--suite ice-shotgun-vfx --suite character-status-outlines` independently tests
local effect budgets/fallbacks, confirmed feedback and central outline priority,
flashing and lifecycle. `--suite ice-shotgun-results` verifies the server-only
notification contract and replicated immunity clocks without duplicating cone
authority tests. See [presentation Studio checks](../docs/ICE_SHOTGUN_PRESENTATION.md).

## Muncher ingredient conversion (Pass 1)

`--suite muncher-rewards` owns catalog base values, exact thresholds, head fallback,
normalized configurable pools and deterministic mystery selection. `--suite muncher`
covers real inventory/registry/session transactions, purchase/reveal gating, registered
prompt feeding, authorization, contention, throw/feed ordering, head input, retry,
landing fallback and reset/removal settlement. `--suite muncher-presentation` independently
checks disabled feedback, preserved reveal, local hearts/chew/actual-rarity glow and
interrupted-effect cleanup. Existing carry-selection, carry-input, and player-head
suites retain the shared contracts. See [Muncher setup and validation](../docs/MUNCHER.md)
for provisional EV limitations, required mouth orientation, and Studio acceptance.


## Muncher physical-ingestion correction

`--suite muncher-vacuum` owns physical ingestion, server attribution, eligibility,
per-spawn output immunity, common world-item claims, protected crop/carry/stash
exclusions, overlapping plots, release behavior and deliberate pickup/rethrow.
`--suite blender-vacuum` runs the existing unchanged blender vacuum spec through
the current fixture/bundler. Keep `muncher`, `muncher-rewards` and
`muncher-presentation` for their existing transaction/reward/presentation contracts.
See [Muncher correction and baseline failures](../docs/MUNCHER.md) for the focused
regression command, legacy world/blender harness failures and Studio smoke checklist.


## FilmCam

`python tests/run_filmcam_tests.py --luau <luau.exe>` is an independent client
presentation/math suite. It owns camera-track filtering, spline/slerp known
answers, delta-filtered timestamp continuity, easing, take validation, the JSON
adapter, gate logic, preset geometry, and record/play/seek/HUD/camera restoration.
`run_turbine_camera_tests.py` owns the turbine suspension/resume behavior alongside
its existing camera contracts. Native CFrame/JSON and a real filmed take require
the separate [Studio checks](../docs/FILMCAM.md); CLI doubles do not establish
visual smoothness. These suites do not gate authoritative gameplay tests.


## Economy redesign (2026-10-23)

The focused economy command, provenance producer audit, tier-3 ground-floor demand
report, baseline failures and outstanding Studio session log are in
[ECONOMY_REDESIGN.md](../docs/ECONOMY_REDESIGN.md). `request-selection` now owns
joint physical accessibility and uniform whole-pool prompt selection; its earlier
recency/group/similarity prompt-selection contracts above are retired. Template
recency and special/fixed request behavior remain separate.
