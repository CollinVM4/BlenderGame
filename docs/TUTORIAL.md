# Three-customer tutorial and arrival routing

New plot sessions receive three ordinary scripted queue customers: Red immediately, Cold at about eight seconds, Yellow at about sixteen seconds. The existing three-place queue, movement, order prompts, serving, grading and payout remain authoritative. Regular scheduling resumes after insertion. Missing, dismissed or unfulfilled tutorial customers are replaced through that queue; removal and bat recovery cannot complete an order. Waiting customers may be accepted or served early, and completed requests reconcile in order.

`TutorialOrders.luau` contains canonical request IDs, slots, recipes and arrival offsets. InventoryService grants real ingredient records once per plot session, skipping occupied slots: slot 3 has Cherries, Cherries, Strawberry; slot 4 has three Ice; slot 5 has three Banana. Protected slots 1–2 remain untouched. Unprotected slots already support mixed ingredient records and normal TAKE, values, ripening and smoothie ingestion. Starter grants are never replenished during the session, including after theft or discarding. Replacement ingredients can be gathered and stored through normal gameplay; carrying or recovering a loose ingredient resumes Glass guidance.

TutorialService publishes ClaimPlot -> Counter (Take Order) -> Stash -> Ladder -> reactive Stash/Blender -> Turbine -> Dispenser -> Serve. After the first stash pickup, Ladder gleams until a living player actually climbs within six studs of an owned ladder TrussPart. This learning step is retained through respawn and does not repeat after each ingredient. Early accepted ingestion and dispensing still reconcile without forcing obsolete steps, and missing ladder geometry does not block Glass guidance. The ingredient/blending/serving sequence repeats for the three requests. It reads customer snapshots, real cup ownership and BlendService snapshots instead of client claims or sequential interaction flags. A cup already dispensed or stored before order acceptance is reconciled. Successful fulfilled service by either plot member advances the shared orders. Reassignment cleans old targets and reads the new session; respawn does not reset the batch or queue.

Blender snapshots expose BatchId, AcceptedIngredientCount, ProgressPercent and ReadyToDispense. The count derives from the actual ingested ingredient list. The existing `READY` state means loaded enough to start blending; `COMPLETE` plus required progress and a result is the authoritative dispense-ready state. RequiredProgress is currently 65 physical progress units, so ProgressPercent normalizes those units to 100%. The tutorial never changes blending speed or economy. One/two accepted ingredients cannot enable Turbine; only a 100%-complete ready batch enables Dispenser. In-flight throws guide to Glass while moving; a settled missed throw returns to stash guidance without counting as ingestion.

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
2. Accept RED using TAKE ORDER. Confirm only slot 3 and its lowercase base gleam. Take the first ingredient: Ladder should gleam next, then Glass after actual climbing. Withdraw the remaining units and verify both Cherries and Strawberry use normal carry/TAKE behavior without repeating the ladder step.
3. Throw one and then two ingredients into Glass. Glass/stash guidance must remain reactive; Turbine must wait for all three accepted units. Miss a throw and recover it normally; the miss must not increase the accepted count.
4. Spin partially: Turbine continues gleaming. Complete to 100%: Turbine clears and Dispenser gleams. Dispense and verify the current customer gleams; serving grants the normal grade/payout.
5. Accept COLD and YELLOW while waiting, then repeat using slots 4 and 5. After all three fulfilled serves, every guided gleam disappears and random customer scheduling continues.
6. Reset/respawn while loading/blending, reinitialize the local controller, and join as a teammate. Verify no repeated grants/injections or stale gleams. Abandon/reclaim and check session targets reset without overwriting occupied stash slots.
7. Dismiss/destroy a tutorial customer or serve a wrong recipe: the same request must return through the queue with no automatic tutorial completion. Steal/discard starters and gather replacements normally; no repeat grants should occur. Confirm other plots are never highlighted.
