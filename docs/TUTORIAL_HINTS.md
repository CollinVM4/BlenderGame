# Three-customer hint polish

The existing server tutorial and RED -> COLD -> YELLOW queue remain authoritative. Plot claiming, arrival offsets, starter records, customer evaluation, payouts, combat and carry input dispatch are unchanged. No new Studio assets or remotes are required.

## Architecture and changed files

- `src/server/Services/TutorialService.luau`: retains the counter introduction until the player reaches its authored base (16 studs), then targets the customer with the new Order objective. Missing counter scenery falls back to the real order interaction. Ladder learning remains intact. Batch IDs associate accepted ingredients with the current tutorial order; an old full batch gets explicit finish/clear guidance, while a recipe already prepared for the next order reconciles normally. Stage publication also observes order identity and avoids interrupting ordinary hint transitions with a temporary HintReady=false.
- `src/shared/TutorialTargets.luau`: Order and Serve target the server-selected customer in the current plot session. Old-batch recovery uses the existing turbine/dispenser targets. Stash slot/base selection and the safe Glass proxy remain unchanged.
- `src/client/UI/AnnouncementBanner.luau`: extracts the existing Fredoka, outline, top-center safe-inset positioning, width/text constraints and pop/settle/exit animation. A local priority signal hides tutorial text synchronously throughout a global announcement queue, including exit animations.
- `src/client/Controllers/RareIngredientPresentationController.luau`: uses that shared banner and priority signal; existing payloads, formatting, queue order, countdowns and sounds are retained.
- `src/client/UI/TutorialHintText.luau`: short instructions and repetition policy. RED always receives text. COLD receives each action once, with repeated actions returning after six seconds without observed progress. YELLOW primarily uses gleams, with text after eight seconds of hesitation. These delays affect text only, never gameplay or highlights. Once visible, an objective persists until it changes.
- `src/client/Controllers/TutorialHintController.luau`: owner-local presentation driven by replicated server attributes. PreferredInput and the live CAS throw binding determine wording. It recovers after death, respawn, PlayerGui replacement and missing UI. Completion destroys its GUI/tweens and disconnects rendering, input and announcement subscriptions; player lifecycle observers remain available for a fresh plot session. Destroy disconnects all observers.
- `src/client/Controllers/CarryInputController.luau`: adds a read-only live gamepad binding label helper; input dispatch is unchanged.
- `src/client/init.client.luau`: initializes the hint controller independently beside the existing gleam controller.
- `tests/tutorial.spec.luau`, `tests/tutorial_gameplay.spec.luau`, `tests/tutorial_targets.spec.luau`, `tests/carry_input.spec.luau`: extend existing authoritative, integration and target/input contracts. The gameplay test now expects the retired DismissCustomer API to reject without paying or advancing, rather than expecting it to succeed.
- `tests/tutorial_hints.spec.luau`, `tests/run_state_tests.py`: add a separate presentation suite exercising real hint/banner controllers and global announcement drain.
- `docs/TUTORIAL.md`, this guide: updated behavior and validation instructions.

The current checkout configures base carry capacity as 3 in Upgrades. This change preserves that economy configuration. The integration suite explicitly exercises a capacity of 1, then an upgraded multi-carry capacity, so the guide works with either configuration.

## Validation

PASS: tutorial, tutorial-gameplay, tutorial-hints, tutorial-targets, carry-input, announcements, announcement-presentation. Contracts cover canonical order/stash identities, one-item alternation, multi-carry, missed throws and recovery, completed blending, actual cup ownership, committed payout, old-batch isolation, early next-order recipes, respawn, live input wording, fresh sessions and announcement non-overlap.

PASS: changed-file StyLua, Rojo build and fresh sourcemap. Client feature modules pass Roblox-aware Luau typechecking. Full-source analysis reports exactly the same 41 unique existing diagnostics as the pre-change workspace, with no additions. Existing diagnostics are in CustomerRequests, CustomerService, CombatService and JackedNoobService.

Isolated baseline failures: tutorial-claim cannot load the bootstrap's missing Unstuck dependency in its CLI fixture; Python test_state_runner.py has four stale manifest/source-bundle expectations, reproduced before this change. Their unrelated production systems were not modified. The old tutorial-gameplay dismissal expectation also failed on baseline and was corrected to the currently supported reject-without-mutation behavior.

CLI tests use engine doubles and do not prove native rendering, network replication or real contact physics. No live Studio session was run.

## Studio multiplayer/mobile/controller checklist

1. Start two clients on separate plots. Verify claim/counter introduction, customer order highlight, RED/COLD/YELLOW arrivals at 0/8/16 seconds and slots 3/4/5 only. First stash pickup should still teach ladder traversal, then Glass.
2. With one-item carry, miss/drop/recover ingredients and verify pickup/throw alternation. Test upgraded stacked carry. Turbine must wait for three accepted ingredients; touching it or spinning partially must not enable dispensing.
3. Finish blending, try an invalid/full-inventory dispense, then successfully dispense and serve. The customer highlight must wait for the actual cup; invalid serves must not pay or finish the tutorial. All hints/gleams must disappear after three fulfilled serves.
4. On a hybrid touch/mouse device and controller, switch PreferredInput while carrying. Confirm CLICK / TAP THROW / actual R2 or RT label changes, with no throw caused by the device switch. Confirm intentional Throw still works and weapons retain primary input.
5. Trigger mystery/cleanup announcements during each objective. Confirm the global text fully replaces tutorial text during entrance, hold and exit, and the latest objective returns afterward. Check top-center spacing against Framewisp/HUD at phone, tablet and desktop sizes.
6. Reset while carrying, blending or serving; recreate the tutorial GUI/PlayerGui and stream targets out/in. Confirm completed milestones do not restart, no stale highlights persist and the active objective returns.
7. Destroy a customer, serve a wrong recipe, prepare later orders early, join a teammate's plot and abandon/reclaim. Verify queue replacement, normal economy/payout, isolated other-player guides and fresh-session recovery. COLD should reduce repeated text; YELLOW should use highlights first and contextual text on hesitation.
