# Shared plot-session foundation

## Ownership and architecture

`TycoonService` is the sole plot membership/lifecycle and shared-economy authority. It stores plot-to-session, player-to-plot and session-ID indexes. Public session snapshots copy upgrade tables. `PlotId` is generated on the plot if absent; each claim gets a new `PlotSessionId`. Membership changes increment a session-wide revision, including joining, kicking, leaving and promotion. Jump tier is derived exclusively from the shared Jump upgrade index.

| Session-owned | Player-owned |
|---|---|
| Cash; Jump, Payout, MovementSpeed, SprintStamina, Hand and BlendSpeed indexes | Carried ingredients/cups; stash contents; selections and reservations |
| Blender ingredients, result, progress, dispense lock, reset/notification tokens and feedback deadlines | Character, weapon instance, combat cooldowns, current stamina and Studio movement overrides |
| Customer queue, scheduler, NPCs, routing, serve guard, request/template recency and special cooldowns | Discoveries, entitlement flags, personal statistics and other account/meta state |

PlayerData no longer stores cash or shared upgrades. Its injected runtime adapter provides compatibility cash/upgrade getters, setters and combined snapshots without a second authority. TycoonService does not depend on PlayerDataService. Shared callers explicitly use TycoonService. `GetPlot` and `GetOwner` remain available; owner means the current manager, while `IsMember` authorizes shared fixtures.

All selected upgrades keep their existing definitions and prices. BlendSpeed remains stored but has no new gameplay effect. CarryCapacity and StackSize stay personally owned: their isolated purchase adapter spends session cash and commits only the actor's personal tier. No pooled stash, teammate withdrawals or stash theft was introduced. Membership changes do not transfer or clear inventories/stash records; ordinary disconnect cleanup retains its existing personal lifetime behavior. The directly encountered capacity display mismatch was corrected to the existing configured starting/maximum values (3/7).

## Transactions and lifecycle

Purchases validate current membership, session identity, revision, exact next index, definition and affordability. Shared cash and tier change together before projections are published. Replaying the same next tier cannot buy another tier. A synchronous session transaction excludes competing purchases, servings, input/progress and dispensing. Reentrant departures queue behind an accepted transaction; once it commits, membership transitions run before disconnect cleanup. These transaction bodies must remain non-yielding.

Serving consumes only the acting member's cup and pays once into shared cash. Only that actor's DoubleCash entitlement is evaluated. Customer feedback attributes reach both members; the existing presentation channel broadcasts the result once. Shared movement/max stamina applies per character, while current stamina and debug overrides remain personal. Customer regular/fixed/special eligibility reads purchased session Jump, never debug attributes.

Promotion changes management only: session identity, economy, batch, queue, histories and cooldowns survive. Final departure changes status to Closing and revokes mappings first, invokes shared cleanup, then releases the plot. Generic BlendService/CustomerService RemovePlayer methods only clear personal projections. Delayed resets and customer callbacks retain session identity plus their existing batch/queue/movement tokens.

`BlendNeedsItems` has a shared 1.75-second visibility deadline and a separate 2.5-second rejection cooldown. Joining receives the current warning; promotion does not restart it. Old batch timers cannot clear a replacement batch's warning.

## Request and bootstrap wiring

The client bootstrap initializes `SessionInteractionController`. It listens to existing native prompt triggers and submits only prompts marked `SessionInteraction`, attaching the client's session ID and membership revision. The server bootstrap initializes GameplayService before binding components. CustomerService registers its take-order/serve prompts and DispenseButton registers its dispense prompt with GameplayService. There are no parallel native server Triggered handlers for those actions.

The server dispatches only registered, enabled, live prompts and validates the actor context before the service's membership, customer/batch, ownership and proximity checks. Upgrade requests also include context and expected tier; stale responses cannot update a new membership's UI. Internal server callers may capture current context at their synchronous entry point. New network adapters must always require submitted context, never replace missing/stale client context with current server values.

## Exact runtime files changed

- `src/client/Controllers/CustomerOrderController.luau`
- `src/client/Controllers/InteractionPromptController.luau`
- `src/client/Controllers/SessionInteractionController.luau`
- `src/client/Controllers/UpgradesController.luau`
- `src/client/UI/UpgradeDisplay.luau`
- `src/client/init.client.luau`
- `src/server/Components/BlenderInput.luau`
- `src/server/Components/BlenderVacuum.luau`
- `src/server/Components/DispenseButton.luau`
- `src/server/Services/BlendService.luau`
- `src/server/Services/CombatService.luau`
- `src/server/Services/CustomerService.luau`
- `src/server/Services/DevContentService.luau`
- `src/server/Services/GameplayService.luau`
- `src/server/Services/MovementService.luau`
- `src/server/Services/PlayerDataService.luau`
- `src/server/Services/TycoonService.luau`
- `src/server/init.server.luau`
- `src/shared/Types.luau`

Tests add `plot_session.spec.luau`, `plot_session_races.spec.luau`, `plot_session_progression.spec.luau`, `plot_session_requests.spec.luau`, `plot_session_feedback.spec.luau`, and `fixtures/session.luau`. Existing service fixtures/tests now bind real session authority and submit expected tiers/context. The state runner supports repeated `--suite` selections. Feedback presentation tests are separated from authoritative/integration suites.

## Validation

Focused session suites: **4/4 PASS** (`plot-session`, `plot-session-races`, `plot-session-progression`, `plot-session-requests`). The race matrix covers purchase, input, progress, dispense and serve with kick, leave, promotion and final teardown. Separate feedback timing suite: **PASS**.

Existing passing coverage: customer payout, customer serve payout, customer queue, compatibility payout, sprint, carry, throw-to-blender, carry selection/input, ingredient slots and smoothie survivors. Upgrade UI: **PASS**. Runner contracts: **5/5 PASS**. Roblox-aware Luau LSP typecheck, StyLua check, Rojo build and `git diff --check`: **PASS**. Typecheck retains the existing CharacterPhysicsService `LoadCharacterAppearance` deprecation warning.

The broader runs remain red at the same baseline failures reproduced on unchanged commit `c8ecb97`:

| Suite | Existing first failure |
|---|---|
| throw | Insufficient fixture cash to unlock all requested carry tiers |
| stash | "H: carry capacity remains three" |
| smoothie-world | "capacity failure retains world item" |
| smoothie | "capacity rejects extra smoothie" |
| customer-validation | Ingredient request expected outcome mismatch |
| legacy-state | "upgrade spends exact cash" (old price expectation) |
| legacy-movement | "comfortable movement" (old tuning expectation) |
| requests | "name is secondary and outlined" (presentation assertion) |
| world | "second ingredient cannot equip" |
| smoothie-roundtrip | "SETUP: take stored smoothie" |

State group: **4/9 PASS**, identical failing suite set to baseline. Integration group: **11/16 PASS**, including all four new suites; the five failures match baseline. Unrelated production behavior was not changed to satisfy these failures. Assertions after each suite's first failure remain unverified. New independent suites cover this migration's contracts despite those blockers.

Run the foundation checks with:

```powershell
python tests/run_state_tests.py --luau <luau.exe> --suite plot-session --suite plot-session-races --suite plot-session-progression --suite plot-session-requests
python tests/run_state_tests.py --luau <luau.exe> --suite plot-session-feedback
python tests/run_upgrade_ui_tests.py --luau <luau.exe>
python -B tests/test_state_runner.py
```

## Player-facing plot flow (current)

Players now enter unassigned. Player bootstrap no longer calls AssignPlot. Legacy GameService.StartDay and the Studio SpawnCustomer helper require an existing plot instead of allocating one. PlayerData/inventory/character initialization stays personal; no shared cash/upgrades or blender/customer runtime is created until a successful claim. The trusted AssignPlot API remains for compatibility and test setup; there are no automatic runtime callers. ClaimPlot selects an exact physical plot through that existing creation path and invokes SessionStarted exactly once. Joining only publishes/binds the existing session.

Walk within 32 studs of a plot's identity marker and click CLAIM PLOT or JOIN TEAM on its world billboard. Newly claimed sessions default to FriendsOnly. An owner gets MANAGE PLOT, with Open / Friends Only / Closed and Kick Teammate; the teammate gets LEAVE TEAM. Departing/kicked teammates become unassigned and may claim or join again. No lobby, invitation UI, TeamService, or new persistence system was added.

### Runtime files changed in this pass

- `src/server/Services/TycoonService.luau`: claim and policy validation, leave, join mode, identity projection.
- `src/server/Services/GameplayService.luau`: rate-limited request dispatch and physical proximity validation.
- `src/server/Services/GameService.luau`: StartDay cannot implicitly allocate a plot.
- `src/server/Services/DevContentService.luau`: SpawnCustomer cannot implicitly allocate a plot.
- `src/server/init.server.luau`: removes arrival assignment and initializes identities for existing tagged/legacy plots.
- `src/client/Controllers/PlotIdentityController.luau`: world portraits/actions, unassigned status and small management panel.
- `src/client/init.client.luau`: starts the identity controller.

Studio tooling: `docs/studio/CreateReferencePlot.luau` now authors the identity marker. Tests: `tests/plot_player_flow.spec.luau`, `tests/plot_identity.spec.luau`, and registration in `tests/run_state_tests.py`.

### Authorization and races

GameplayRequest handles ClaimPlot, JoinTeam, LeaveTeam, SetJoinMode and KickTeammate. It validates the live target and character distance to the authored marker (32 studs, including vertical distance), then delegates to TycoonService. It never replaces submitted contexts. Claims require an unassigned actor, tagged live empty plot and the expected ClaimRevision. PlotClaimRevision advances on release so a delayed empty-plot request cannot claim a replacement occupancy lifetime.

Join requires the expected PlotSessionId and MembershipRevision, active session, no current actor mapping, available teammate slot and permitted JoinMode. FriendsOnly uses a server IsFriendsWithAsync lookup under pcall. After yielding, it rechecks the original owner/session and player presence; JoinSession rechecks current active membership, revision, busy state and capacity before committing synchronously. Policy changes advance the same revision, invalidating pending joins and old management requests. Two claims/joins can only commit one winner.

Leave is teammate-only. Management and kick require the current owner and revision; kick targets only the current teammate user ID. Existing lifecycle guards revoke access before personal projection cleanup. Personal inventory/stash remain personally owned and are retained; existing MemberRemoved hooks clear departed blender/customer presentation and refresh movement/combat. Shared cash, upgrades, batch, queue, history and cooldowns remain in the original session. Disconnect promotion keeps that session and republishes the owner identity. Final departure closes/cleans once, clears identity and makes the plot claimable.

### Replicated identity

TycoonService projects attributes on each plot: stable PlotId, optional PlotSessionId, OwnerUserId / PlotOwnerName, optional TeammateUserId / PlotTeammateName, JoinMode, PlotMembershipRevision, PlotOccupancy and PlotCapacity (2). Empty plots also carry PlotClaimRevision. Player session/revision attributes remain the foundation's existing membership projection.

The client derives viewer actions from these attributes and its player identity; this grants no authority. Billboard updates are throttled to four per second and rebuilt only on presentation changes. Roblox headshots are cached by user ID, with an empty-image fallback after fetch failure. A separate client friendship cache controls FriendsOnly action visibility; the server independently verifies every join. Friendship visibility refreshes every 30 seconds, including after lookup failure. No owner-specific Studio objects are needed. Missing, removed or streamed-out identity markers hide presentation without changing membership/gameplay. Attribute replication can briefly be partial; any stale submitted action fails server validation.

### Exact Studio setup

1. Keep the existing six physical plot models under workspace.Plots, or tag each root PlayerPlot. Do not nest plot roots.
2. Inside each root, add exactly one BasePart named PlotIdentityOrigin. Set Anchored=true, Transparency=1, CanCollide=false, CanTouch=false and CanQuery=false. A 1x1x1 part is sufficient.
3. Place it above the front approach, roughly 10-12 studs above the ground, within 32 studs of where players will stand to click. An Attachment named PlotIdentityOrigin under an anchored plot part is also supported; its WorldPosition is used.
4. Preserve existing blender/customer fixture tags. No identity tag, owner wiring, GUI creation or remote creation is required. The updated reference-plot command-bar script includes the marker for newly created reference plots.
5. Sync server and client together with Rojo and start a fresh test session. Existing model geometry and plot count are not generated or redesigned by runtime code.

### Validation for this pass

PASS: new plot-player-flow integration suite and separate plot-identity client suite. Covers unassigned legacy startup, protected access, claim/reclaim/races, policy and lookup failure, yielding lookup vs policy/capacity/owner departure, network proximity/context validation, leave/kick, promotion, identity and portrait cache, and management request submission.

PASS: plot-session, plot-session-races, plot-session-progression, plot-session-requests, plot-session-feedback; customer-queue, customer-payout-serve, throw-blender, smoothie-survivors, sprint, client-presentation; upgrade UI and carry upgrade integration; all five runner contract tests.

PASS: full-src Roblox-aware Luau LSP typecheck (only the existing CharacterPhysicsService LoadCharacterAppearance deprecation warning), StyLua check of changed Luau files, Rojo build and git diff --check.

Legacy-movement still fails at "comfortable movement baseline applies". Reproduced on a temporary copy with the unchanged HEAD source. No unrelated production tuning was changed. The other previously documented baseline failures above remain untouched and were not rerun in this pass.

### Still requires Studio verification

No real two-client Studio playtest was run. Verify two unassigned arrivals, simultaneous physical claim, Open joins, FriendsOnly with actual friend/nonfriend accounts, Closed visibility, shared upgrades/batch/customer state immediately after joining, leave/rejoin, kick during interaction, owner disconnect promotion, final cleanup/reclaim, and stale request rejection. Check real replication/streaming, thumbnail failures, mouse/touch billboard input, label readability at all six authored markers, and customer scheduler/NPC behavior. CLI tests use engine doubles and cannot establish those engine-level results.
