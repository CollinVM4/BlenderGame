# Three-customer tutorial and arrival routing

New plot sessions receive three scripted queue customers. Red arrives immediately, Cold around eight seconds, and CaseOh around sixteen seconds. A missing or dismissed customer is replaced through the queue. The Red delivery advances after any valid smoothie at the normal grade. Cold and CaseOh use normal fulfillment rules. Regular customer scheduling resumes after the scripted arrivals.

`TutorialOrders.luau` contains canonical request IDs, slots, recipes and arrival offsets. InventoryService grants real ingredient records once per plot session, skipping occupied slots: slot 3 has Cherries, Cherries, Strawberry; slot 4 has three Ice; slot 5 has three Banana. Protected slots 1–2 remain untouched. Unprotected slots already support mixed ingredient records and normal TAKE, values, ripening and smoothie ingestion. Starter grants are never replenished during the session, including after theft or discarding. Replacement ingredients can be gathered and stored through normal gameplay; carrying or recovering a loose ingredient resumes Glass guidance.

TutorialService publishes ClaimPlot -> Counter introduction -> Order (Take Order) -> Stash -> Ladder -> reactive Stash/Blender -> Turbine -> Dispenser -> Serve. Guidance starts with the red stash ingredients. Three carried ingredients from any source can fill the blender and lead to the ladder hint. Ladder then gleams until the player climbs near their plot's truss for at least 0.15 seconds and rises half a stud. A jump directly out of that climb counts toward the rise. Stepping away resets the contact timer. A completed climb is retained through respawn. Early accepted ingestion and dispensing still reconcile without forcing obsolete steps, and missing ladder geometry does not block Glass guidance. The ingredient, blending and serving sequence teaches the first delivery using customer, inventory and blender snapshots. A valid carried cup or a matching stored cup can be recognized after order acceptance. A valid delivery by either plot member advances the shared Red order. Reassignment cleans old targets and reads the new session; respawn does not reset the batch or queue.

Blender snapshots expose BatchId, AcceptedIngredientCount, ProgressPercent and ReadyToDispense. The count derives from the actual ingested ingredient list. The existing `READY` state means loaded enough to start blending; `COMPLETE` plus required progress and a result is the authoritative dispense-ready state. RequiredProgress is currently 65 physical progress units, so ProgressPercent normalizes those units to 100%. The tutorial preserves blending speed. The first valid delivery to tutorial Red has a one-time $30,000 minimum, including C and D grades. The floor applies before shared payout feedback. Cold, CaseOh, and normal customers use their calculated payouts. One/two accepted ingredients cannot enable Turbine; only a 100%-complete ready batch enables Dispenser. In-flight throws guide to Glass while moving; a settled missed throw returns to stash guidance without counting as ingestion.

See [tutorial hint polish](TUTORIAL_HINTS.md) for announcement-style text, input wording, old-batch recovery, changed files and the updated validation checklist.

## Studio setup

No new remotes, scripted customer templates or decorative ingredients are needed. Keep the existing PlayerPlot, PlayerStash and reference tags, normal customer rigs, and unique SlotIndex attributes on the stash interaction surfaces. Required customer references are CustomerSpawn, CustomerCounter, CustomerWait1, CustomerWait2 and CustomerExit.

The supplied authored stash names are resolved exactly: `Stash > Slot3 > base`, with corresponding nested paths for Slot4 and Slot5. A slot Model already includes its base and receives one gleam; a slot BasePart and its separate nested base each receive one. The resolver never highlights the whole stash or unrelated slots, and ambiguous SlotIndex surfaces are omitted. If your base has a different name/path, update TutorialTargets to the exact authored path. Only geometry in the player's current plot can be a stash target.

Retain the existing visible paths in TutorialTargets:

- PlotIdentity > ClaimVisual (not the invisible ClaimZone).
- Ladder model containing its climbable TrussParts.
- Blender > Glass.
- Turbine Wheel > turbine > anchor, blade, stem.
- Dispenser.
- Customer Area > Counter > Base Structure > Base.

Serve targets the server-selected current customer, guarded by its plot session ID. All gleams remain local. ClaimPlot keeps its initial 4.5-second hint delay and then gleams indefinitely until claimed. Glass retains the transparent local UnionOperation proxy; authored Glass geometry is never changed. Death, membership changes, missing assets and controller shutdown remove stale highlights.

Arrival routing is unchanged: provide PlotIdentity > PlayerSpawnOrigin as an Attachment at the intended HumanoidRootPart position/facing outside ClaimZone. Optional unique numeric SpawnOrder controls plot order. InitialSpawnService reserves available marked plots for 25 seconds; claim hints retain their existing pin after reservation expiry.

## Focused validation

Run `tests/run_state_tests.py` with suites `tutorial`, `tutorial-gameplay`, `stash-integration`, and `plot-player-flow` for state/integration. Run `tutorial-targets` separately for presentation. These suites pass. StyLua and Rojo build pass. The Roblox-aware focused typecheck has the same 42 pre-existing diagnostics as the saved pre-change workspace, with no added diagnostics.

Related regression suites reproduce these failures on the saved pre-change workspace and remain untouched:

- customer-queue: `front consumes and pays once`.
- plot-session-requests: `two same-tier network requests purchase once`.
- request-selection: `purchase authoritative jump upgrade`.
- customer-wildcard: `authored wildcard probabilities`.

The CLI tests model engine movement/overlap and do not prove authored asset placement or actual network physics. Studio smoke verification remains required.

## Manual Studio verification

1. Start two clients and claim separate plots. Confirm exact slots 3–5, untouched protected slots, immediate Counter guidance, RED/COLD/YELLOW arrivals at about 0/8/16 seconds, and all three queue positions occupied within a minute.
2. Accept RED using TAKE ORDER. Take one or two ingredients and check that Stash still gleams. Carry three ingredients from the stash or market and check that Ladder gleams. Brush past the ladder, then climb it normally. Glass should gleam after the climb. Partial carry after using the ladder or loading the blender still guides to Glass.
3. Throw one and then two ingredients into Glass. Glass/stash guidance must remain reactive; Turbine must wait for all three accepted units. Miss a throw and recover it normally; the miss must not increase the accepted count.
4. Spin partially: Turbine continues gleaming. Complete to 100%: Turbine clears and Dispenser gleams. Dispense and verify the current customer gleams; serving grants the actual grade and at least $30,000 for tutorial Red, followed by the upgrade hint.
5. Check that Jump and Bat can be bought with the first payout. Interact with the Cold customer to proceed to the market guidance. Cold and CaseOh should use their ordinary calculated payouts.
6. Reset/respawn while loading/blending, reinitialize the local controller, and join as a teammate. Verify no repeated grants/injections or stale gleams. Abandon/reclaim and check session targets reset without overwriting occupied stash slots.
7. Dismiss or destroy Red and confirm that a replacement arrives. Serve Red a valid off-recipe smoothie and confirm that the grade reflects the recipe, the payout reaches the floor, and Cold is next.

## Ladder and payout floor validation

Run `python tests/run_state_tests.py --luau <luau.exe> --suite tutorial --suite tutorial-payout-serve --suite tutorial-gameplay --suite carry`.
All four suites pass, covering incomplete/wrong/duplicate ingredients, real inventory and stash flow, payout eligibility, credited cash, result GUI and CustomerReaction payloads. The payout suites share `fixtures/customer_payout.luau` so legacy payout failures cannot prevent the tutorial cases from executing.

StyLua, Rojo build and whitespace checks pass. Focused Roblox-aware typecheck retains the same 25 diagnostics as baseline. The legacy `customer-payout-serve` cash expectation, `tutorial-claim` missing-module harness failure, and four Python state-runner contract failures reproduce on baseline; unrelated production code is unchanged. No new Studio setup is required. Live Studio acceptance has not been run.


## Market send-off and progressive farm guidance

After the first tutorial order is served, the upgrade recommendation and next
customer interaction lead to `TutorialStage = Market`. `TutorialActive` stays
true. The hint reads "Visit the MARKET for more ingredients!" and the beam points to
`Workspace/Central Market/CentralMarketBase` (BasePart). Reaching the floor
begins MarketJump on the next server refresh. Missing market scenery uses a
seven-second fallback.
Market presentation explicitly bypasses the first-order instruction retirement.

Once opening onboarding is complete, the first server refresh observing the session
owner with at least $20,000 starts `FarmTutorialStage`: empty -> `BuyRow` -> `Plant`
-> quiet growth -> `Harvest` -> `Done`. It stays `Done` until the session changes; teammates never start it.
An owner already holding $20,000 at opening completion starts immediately. The
ordered step table reads FarmService's copied row snapshot, holds BuyRow for the
0.8-second reveal after observing Row 1's purchase, and completes Plant when that
row contains a planted ingredient. RevealSeconds is now 0.8 for the farm tween and
server tutorial hold alike. No client attributes authorize gameplay actions.

BuyRow uses "Buy a farm row!" and `Farm/Row1/PurchasePoint1`. Plant uses "Plant an
ingredient!" and children named `Pebble` and `plank2` under `Farm/Row1/Visual`, or
`Pebble & plank2` for a combined export. Missing spot names fall back to Visual.
These Workspace farm/map assemblies are Studio-authored and absent from the
repository's Rojo model assets; retain these names in the live scene. No new tags,
remotes or UI assets are required. Both stages reuse the existing announcement
hint typography/position/animation and gleam/beam. Their effective stage is selected
only while opening onboarding is inactive, independently of opening completion
latches; Done and empty show nothing.

Validation: tutorial state, tutorial-gameplay, tutorial-payout-serve, farm,
tutorial-targets, tutorial-hints and tutorial-beam-stability pass. Changed-file
StyLua and Rojo build pass. Focused Roblox-aware typecheck has the same 22
CustomerRequests DisplayText diagnostics as the saved pre-change working tree,
with no added diagnostics. tutorial-claim still fails loading the missing
UnstuckService dependency in its harness, reproduced on that baseline. Live Studio
acceptance (market navigation, row rise, planting, owner/teammate view) remains to
be run.


## Market/farm addendum

After the first tutorial serve and upgrade recommendation, `NextCustomer` waits
for the next customer interaction. `TutorialCustomerTarget` publishes its model.
The hint is "See what the next customer wants!". Taking the order starts a
two-second server reading pause before Market. NextCustomer, Market, and
MarketJump bypass opening instruction retirement.

MarketJump flashes `Workspace/Central Market/JUMP1HIGHLIGHT` (BasePart), with
"JUMP HIGHER to reach better ingredients!". For both Market targets the server
checks straight down to the surface from the player's root, using their avatar's
standing height plus 1.5 studs. Non-collidable markers can fall back to their
oriented bounds. Reaching the first raised platform completes the step on the
next server refresh, including during the preceding Market hint. A missing jump
target advances after seven seconds. Use the top of the first raised platform as
`JUMP1HIGHLIGHT` in Studio.

Farm guidance now follows BuyRow -> Plant -> quiet growth -> Harvest -> Done.
FarmService's READY state and copied Products identify completed growth. It
publishes `TutorialHarvestTarget` ObjectValues under the row for each actual live
product and retires them on collection/removal/reset. Harvest flashes Row 1's
remaining production (up to three), falling back to its planting Visual when
references are unavailable, with "Harvest your ingredients!". The existing
FarmService EMPTY transition after the last product removal completes Harvest.
NextCustomer and Harvest wording remain placeholders for Collin to confirm.

Studio acceptance starts by serving the first tutorial customer, taking the next
order, and checking the reading interval. Approach the market, pass below
the jump highlight, then land on the raised platform. Repeat with a fast arrival
and confirm the jump hint still appears. Buy Row 1 at $20K, plant, wait for
growth, and collect all three highlighted products. Automated doubles do not
replace this live replication/navigation check.

Addendum validation: all six focused suites (tutorial, tutorial-gameplay, farm,
tutorial-targets, tutorial-hints, tutorial-beam-stability), StyLua, Rojo build and
whitespace checks pass. Focused Roblox-aware typechecking reproduces the same
25 diagnostics on HEAD and this change, with no added diagnostics. Live Studio
acceptance remains to be run.
