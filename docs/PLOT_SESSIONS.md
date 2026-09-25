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

## Studio and remaining enablement

No authored model, tag, asset or Rojo mapping changes are required. Sync both server and client changes together and start a fresh Play session. No real Studio two-client session was run; CLI engine doubles do not verify actual replication, prompt input, streaming, physics or NPC pathfinding.

Single-player auto-assignment remains the default. There is no TeamService, team-selection UI, public join/kick remote, invitation flow or portrait/name presentation. `JoinMode` defaults to Closed; low-level server-only JoinSession/Kick APIs are the foundation for a later validated social layer, not an invitation policy. JoinSession expects an unassigned player and a current owner context.

For a fresh two-client Studio smoke test, use the Server Command Bar after bootstrap:

```luau
local t = require(game.ServerScriptService.Server.Services.TycoonService)
local p = game.Players:GetPlayers()
local owner, teammate = p[1], p[2]
t.RemovePlayer(teammate)
assert(t.JoinSession(teammate, owner, t.GetRequestContext(owner)))
```

Verify both clients see the same cash/batch/orders, can purchase/serve/dispense, receive only their own cups, and retain the same session and queue when the owner disconnects. Then verify final departure cleanup and plot reuse. Later work includes deliberate join/invitation/consent policy and UI, management controls, persistence/recovery rules, and the unresolved CarryCapacity/StackSize/stash ownership policy. No final team UI is included here.
