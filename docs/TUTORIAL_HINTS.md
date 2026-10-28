# Three-customer tutorial guidance

The opening stand claim and first RED customer receive top-center instructions and a directional yellow beam. After RED is successfully served, the beam retires for the rest of onboarding, including respawns and plot membership changes. COLD and YELLOW keep their normal yellow world highlights. Text, beams, and world highlights have independent eligibility; retiring the beam never disables TutorialGleamController.

All visuals are owner-local. This change does not modify server progression, ingredient ingestion, blending, dispensing, economy, carry authority, customer evaluation, or global announcements. No new Studio-authored assets or remotes are required.

## Instructions and destinations

| Objective | Instruction / timing | Beam destination |
|---|---|---|
| ClaimPlot | "Claim your smoothie stand!" immediately on joining | Available stand's ClaimVisual from TutorialSpawnTarget |
| Counter | "Head to your customer counter!" three seconds after claiming, while Counter remains current | Assigned plot's Customer Area/Counter/Base Structure/Base |
| Order | "Take the customer's order!" | Current TutorialCustomerTarget |
| Stash | "Grab ingredients from the stash!" 2.5 seconds after first accepted RED order | Exact TutorialStashSlot on the assigned plot (RED slot 3) |
| Ladder | Existing ladder instruction | Assigned plot's ladder |
| Blender | Existing device-specific throw instruction | Assigned plot's tagged BlenderInput, preferring VacuumTarget; Glass fallback |
| Turbine | "Spin to blend smoothie!" | Stationary central stem/shaft, preferably its existing stable attachment |
| Dispenser | "Dispense your smoothie!" immediately on readiness | Stable DispenserTextOrigin or actual dispenser interaction attachment; stable output part fallback |
| Serve | "Serve customer and get PAYED!" | Current TutorialCustomerTarget |

Claim guidance appears with the immediate instruction once a valid arrival target and living character exist; it does not wait for TutorialHintReady. The reserved/pinned stand must remain available. After claiming, targets resolve exclusively from the local player's PlotSessionId, and customers must match that session.

Counter and initial Stash delays remain shared by text, beam, and highlights through TutorialPresentationState. Deadlines cannot restore obsolete objectives. Character removal cancels pending delays; an unfinished delay restarts for the replacement avatar. Repeated Stash/Blender cycles resume immediately until authoritative ingestion advances the objective. Three accepted ingredients advance to Turbine; completed blending advances to Dispenser. FinishBatch and DrainBatch use the same stable turbine/dispenser targets.

Throw wording still follows PreferredInput and the live CAS binding: "Click to throw into the blender!", "Tap Throw to toss it in!", or "Press <bound button> to throw into the blender!". Global announcements retain banner priority without changing world guidance.

## Single continuous beam

Every objective uses one outer Beam plus its existing inner directional highlight. There are no waypoint chains, obstruction queries, floor probes, pathfinding requests, intermediate holders, or route segments. Intersecting the blender, its base, or other geometry cannot suppress the beam. Reliability takes priority over obstacle avoidance.

The outer Beam retains widths 0.26/0.195 studs, transparency 0.6, its yellow color, 20 segments and gentle 1.5/-1.5 curves. The bright inner Beam retains widths 0.11/0.085 and the same endpoints. The source is an Attachment on the current character's HumanoidRootPart at local (0, -0.5, +1.25), slightly behind the avatar.

TutorialBeamFlow retains its cached seventeen-keypoint gradient: a soft bright segment travels from Attachment0 (player) toward Attachment1 (objective) over 2.4 seconds, fades at the ends and repeats forward. The existing gleam Heartbeat selects a cached 30 Hz frame; it creates no sequences or extra animation connections per frame.

Consecutive objectives retarget the same beam pair and retain its source and animation phase. Both Beams remain enabled while valid active guidance exists. Only the destination Attachment changes when necessary. Repeated refreshes and player movement reuse the existing instances. Authored Attachments are never destroyed by tutorial cleanup.

## Stable turbine and dispenser endpoints

Turbine target resolution no longer uses TurbineWheel tags or a global TurbinePromptOrigin: the tag can intentionally identify the rotating blade, and the marker can be attached to moving geometry. The resolver searches the assigned plot's `Turbine Wheel` assembly (or its named `Turbine`/`turbine` equivalent) for `stem`/`Stem` or `shaft`/`Shaft`. The selected BasePart must be anchored or rigidly joined to an anchored assembly. It never substitutes a rotating blade, a temporary highlight proxy, or a calculated approach position.

A `TurbineBeamTarget` or `TurbinePromptOrigin` directly parented to that stationary stem is reused when available. Otherwise the client creates one Attachment on the stem, centered on a short stem or 2.5 studs above its local lower end on a tall vertical shaft. This local position is fixed throughout spinning and movement. Existing stationary stem/shaft geometry must remain part of the replicated plot; an unanchored spinning stem is deliberately not a valid substitute.

Dispenser guidance prefers the assigned plot's stable `DispenserTextOrigin`, followed by an actual ProximityPrompt Attachment inside `Dispenser`, then a stationary dispenser/output BasePart. Every reused Attachment must have a valid stationary BasePart parent. No route planner replaces this endpoint, and curvature never depends on obstruction tests.

Beam eligibility is independent of decorative highlight availability. Destroying or streaming a highlighted blade/anchor clears those highlights without tearing down a beam attached to the valid stationary stem. If the actual endpoint or character disappears, invalid effects are removed safely and the existing refresh loop retries. Replication of the stem, dispenser or authored attachment restores the current objective without a gameplay restart. Temporary local endpoint attachments are replaced only when the actual resolved target changes or disappears.

## Lifecycle

Death, character replacement, lost membership, tutorial cancellation/completion and controller shutdown remove invalid beams and locally owned Attachments. Authoritative objective changes retarget immediately; intentional Counter/Stash delays hide obsolete guidance. No navigation task or callback can revive an old objective because that routing layer has been removed.

TutorialOrderIndex > 1 permanently latches beam generation off for this local onboarding, including after respawn, membership changes or a stale return to index 1. Complete also retires beams. Text retains its existing session-scoped first-customer latch. Highlights continue for all three customers until TutorialActive becomes false.

## Changed files

- `src/client/Controllers/TutorialGleamController.luau`: one beam pair, fixed local stem endpoint, independent highlight cleanup and existing shared timing.
- `src/shared/TutorialTargets.luau`: stationary own-plot stem and stable dispenser target selection; other objective resolution and yellow highlight paths remain unchanged.
- `src/client/UI/TutorialBeamFlow.luau`: cached original single-beam animation; unused routed-gradient support removed.
- `src/client/UI/TutorialBeamNavigation.luau` and `TutorialBeamPath.luau`: removed along with their obstacle and multi-segment rendering code.
- `tests/tutorial_hints.spec.luau`: controller persistence, movement/spinning/geometry, retargeting, recovery and first-customer cleanup.
- `tests/tutorial_beam_stability.spec.luau`: fixed stem/shaft selection, stable authored endpoints, foreign/rotating target exclusion and late replication.
- `tests/run_state_tests.py`: replaces the obsolete routing suite with `tutorial-beam-stability` and removes deleted module loading.

## Validation

Run `python tests/run_state_tests.py --luau <luau.exe> --suite tutorial-beam-stability --suite tutorial-hints --suite tutorial-targets --suite tutorial --suite tutorial-gameplay`. Presentation suites remain separate from authoritative state and integration suites. Persistence regressions make geometry/pathfinding APIs fail if called, then verify that moving the avatar and spinning/removing decorative turbine parts retain the same enabled beam pair and fixed destination. Existing suites retain direction, timing, all other targets, first-serve retirement and later-customer highlights.

Latest stability pass: all five focused suites pass. Roblox-aware Luau LSP typechecking, changed-file StyLua, Rojo build and whitespace checks pass.

Also run Roblox-aware Luau LSP analysis with a fresh Rojo sourcemap, StyLua on changed Luau files, Rojo build and `git diff --check`.

The earlier `tutorial-claim` fixture dependency failure and four test-runner self-test manifest expectation failures were reproduced on isolated HEAD archives in previous passes. They are separate from these focused gameplay and presentation contracts.

CLI doubles do not prove native Beam rendering or the live authored plot's stem orientation/anchoring. A live Studio surface is unavailable through the current tools; the visual checks below remain pending.

## Required Studio acceptance

1. Claim a stand and confirm the unchanged immediate claim instruction, three-second counter delay and correct own-plot navigation. Accept RED and verify the shared 2.5-second stash delay and normal pickup/throw guidance.
2. Throw the third ingredient into the upper input. Confirm immediate "Spin to blend smoothie!" and one continuous beam to the stationary lower stem. Inspect its Attachment parent: it must be the fixed stem/shaft, never the spinning blade or a highlight proxy.
3. Move around, beneath and behind the blender. Spin the turbine. The stem endpoint must remain completely stationary, both Beam layers must stay connected, and intersecting machinery must never hide or rebuild them.
4. Reach 100% blend progress. Confirm immediate "Dispense your smoothie!" and the same beam pair retargeted to the actual stable dispenser interaction. Walk around the base and verify continuous connection even when the gentle curve passes through walls.
5. Verify the bright highlight always travels away from the player toward the destination. Check multiple camera angles, rotated plots, desktop/mobile sizes, and mouse/touch/controller throw wording.
6. Reset during blending/dispensing; stream out and restore the actual stem/dispenser; remove decorative highlight pieces. Valid fixed endpoints must survive decorative removal, replacement characters must receive a fresh source, and genuinely missing endpoints must recover without a stage reset.
7. Successfully serve RED and verify beam/temporary Attachment cleanup. Pause and respawn throughout COLD and YELLOW: opening walkthrough hints and beams stay retired; the upgrade hints below are explicit exceptions. Normal yellow highlights continue on gameplay stages. Verify owner-only visibility with two clients and unchanged global announcements.

## Upgrade guidance after tutorial serves (2026-10-28)

`TutorialService` now returns `BuyJump` after Red and `BuyBat` after Cold when the
corresponding purchased level is below 1 and current server cash covers catalog
row 2. Jump takes priority if both gates qualify. Purchases, pre-owned upgrades,
or insufficient cash let the next order's existing stage proceed. These are
guidance stages only: taking orders, preparing cups and serving remain available.
Conditions are re-evaluated on the existing Heartbeat; no skipped-state record,
new attribute, remote or persistence was added.

`TutorialHintText` uses "Tap Upgrade and buy JUMP 1!" / "Click Upgrade and buy
JUMP 1!" and "Tap Upgrade and buy a Bat Weapon!" / "Click Upgrade and buy a Bat
Weapon!". Gamepad uses the desktop fallback because no Upgrades menu binding
label exists. `TutorialPresentationState` bypasses opening text retirement for
both stages without enabling beams or adding a read delay. Existing banner
transitions still apply.

The only runtime reader of `TutorialCustomerTarget` is `TutorialGleamController`.
Unmapped Buy stages resolve no targets and existing cleanup clears prior gleams
and both beam layers, including when the stage arrives before the order index.
No target mapping, target publication exception, arrow/controller change or
Studio asset setup is needed. Existing alert pulses point to the Upgrade menu
or the relevant row inside the open panel.

Validation: `tutorial`, `tutorial-gameplay`, `tutorial-payout-serve`,
`tutorial-hints`, `tutorial-targets` and `tutorial-beam-stability` pass, as do
`run_upgrade_ui_tests.py` in both initialization modes. Tests cover affordability,
pre-ownership, purchase handoff, priority, serving Cold during BuyJump with the
cup consumed and payout credited, exact input wording, retirement bypass,
previous Serve beam cleanup and existing authored arrows. Red/Cold payouts and
first regular serves retain their existing expectations. StyLua, Rojo build and
whitespace checks pass. Roblox-aware analysis of the three changed runtime
modules reports the same 22 `CustomerRequests.DisplayText` dependency errors as
an isolated HEAD baseline, with no added diagnostics.

Studio acceptance remains pending: sync with Rojo and restart Play; serve Red,
buy Jump 1, serve Cold, buy Bat 1, and confirm Cold/Yellow guidance resumes after
each purchase. Verify both menu and panel arrows, touch/click wording, no world
beam or gleam during Buy stages, pre-owned and spent-cash skips, and unchanged
NextCustomer/Market flow, upgrade rows and cash ticker. No live Studio session
was used for this pass.
