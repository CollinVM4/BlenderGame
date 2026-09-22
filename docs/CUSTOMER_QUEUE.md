# Always-on customer queue

Plot ownership starts customer flow automatically through TycoonService's injected activation callback. No Start Day interaction is required. CustomerService owns one ordered `Customers` array per player and the plot identity for that flow session.

## Studio setup

Inside each plot, provide one anchored BasePart for each role:

| Role/tag | Purpose |
| --- | --- |
| CustomerSpawn | Entrance |
| CustomerCounter | Queue position 1; only serveable customer |
| CustomerWait1 | Queue position 2 |
| CustomerWait2 | Queue position 3 |
| CustomerExit | Served customer departure |

Existing plots need the two waiting markers added. Explicit tags win; legacy parts named exactly by role are automatically tagged. Set horizontal marker tops at intended ground level and leave clear walking routes. Move markers in Studio as needed. `docs/studio/CreateReferencePlot.luau` includes the waiting markers. Missing/ambiguous markers prevent spawning and retry after repair; they never fall back to the Start Day button.

All three customers receive requests when queued and keep their owner-visible order bubbles while approaching, waiting, and advancing. The existing client controller enables every owned bubble; it does not filter by queue index. Waiting prompts stay disabled. Counter serving becomes available after arrival.

## Scheduling and lifecycle

Economy config sets a maximum of 3, an initial delay of 2-5 seconds, normal arrivals 35-65 seconds apart, and full/failed-spawn retries every 5-10 seconds. A full queue retains a pending arrival through short retries. Serving does not spawn an instant replacement or reset the arrival timer.

`ActivateForPlayer` is idempotent for the current owned plot. A delayed callback captures the queue session itself and revalidates both its identity and plot ownership. `DeactivateForPlayer` invalidates that session before removing waiting and departing NPCs. Plot release, removal from Workspace, reset, and player departure stop the flow. Explicit reactivation starts a new initial delay. Stale callbacks cannot populate a replacement session.

`RefreshQueue` resolves each record's current marker. Per-record route tokens invalidate movement toward previous positions, including customers still entering when the front is served. Requests are retained during advancement. Existing PivotTo movement, ground placement, R6/R15 walk animation, and AnimationConstraint compatibility remain in use.

## Serving and special customers

The server accepts only the ready front customer on the player's current plot, within interaction distance, using a genuine server-owned cup. Each prompt supplies its own model identity, so a waiting or retired prompt cannot accidentally serve the new front. The transaction locks readiness before cup consumption, removes the served record without yielding, then validates request requirements and pays through PlayerDataService. Tags, ingredient requirements, exclusions, exact multisets, tier filtering, and NPC mappings remain authoritative.

Success and failure both complete an order. Existing reaction dialogue/audio and payout rules remain. The served NPC reacts, waits two seconds, walks to CustomerExit, and is cleaned up; the next customer advances concurrently.

Special selection retains `CustomerRequests.SpecialCustomerChance`, weights, tier/NPCOnly filtering, regular fallback, and regular template/request recency. `Economy.SpecialCustomerCooldownSeconds = 300` limits specials per player using the last successfully queued special's timestamp. Deactivation/reactivation and legacy BeginDay do not clear it; player removal clears runtime history.

## Compatibility

The physical Start Day object can remain. DayButton disables its authored prompt and creates no new interaction. The old StartDay remote and GameService.StartDay/ResumeDay idempotently activate the queue; they do not force arrivals. CustomerService.BeginDay is a no-op. GameService.FinishDay returns false.

Legacy DayState/DayNumber/DayGrade/CustomersServedToday attributes remain for callers, but never gate spawning or serving. The serve counter is session-wide, and Grades/DayGrade retain only the latest grade to avoid an unbounded endless-session list. CustomerFlowState publishes PLOT_ACTIVE/PLOT_INACTIVE. GameService.Reset stops customer flow until reactivation. The gated Studio SpawnCustomer helper explicitly activates and immediately spawns for filming.

## Validation

- `python tests/run_state_tests.py --customer-queue-only --luau <luau.exe>`: plot activation, timers, capacity, marker destinations, requests, eligibility, advancement, replay prevention, endless refills, stale movement/session callbacks, ownership release, and special cooldown.
- `--request-validation-only`: existing pure validation, compatibility helpers, and request/serve integration, including once-only payouts and failure behavior.
- `--customer-presentation-only`: owner visibility for all three bubbles, placement, and R6/R15 walk behavior; reported independently of authoritative gameplay.
- `--smoothie-only`: existing genuine blend/dispense/stash/serve and smoothie lifecycle coverage.

Studio smoke test: claim a plot without pressing Start Day; wait for three arrivals and verify all orders are legible. Serve the counter while a waiter is entering; verify both waiters advance with unchanged requests, only the new counter enables serving, and the served NPC reacts/exits concurrently. Serve at least five customers, test a full-queue timer then free a slot, release/reclaim the plot, and repeat with two clients and imported R15/AnimationConstraint rigs. CLI doubles cannot certify actual rendering, replication, or animation assets.

Implementation validation: queue integration, request integration, compatibility helpers, customer order visibility, placement/walk, smoothie survivors/geometry, Roblox-aware typecheck, StyLua, and Rojo build pass. Remaining existing test failures were reproduced on a copy of the pre-change code with the user's working-tree configuration: customer-validation expects Apple+Ice not to satisfy Sweet; smoothie-world/smoothie expect older carry capacities; smoothie-roundtrip fails its stash take setup; legacy-state expects one held ingredient. These failures were kept separate from queue implementation tests. No Studio play session was run.
