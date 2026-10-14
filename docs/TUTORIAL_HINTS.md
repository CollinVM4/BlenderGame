# Three-customer hint polish - Pass 3

The opening stand-claim and counter-navigation instructions are preserved. Only customer 1 (RED) receives the customer instructional walkthrough. After its committed successful serve, text stays disabled for COLD and YELLOW, including on hesitation or respawn. Their server progression and existing yellow highlights continue. Global announcements remain independent and take priority over tutorial text.

All presentation is owner-local. Plot claiming, spawn assignment, customer order acceptance, stash withdrawals, carry mechanics, accepted blender ingestion, completed blending, cup grants and committed serving/payout remain server-authoritative. No new Studio-authored assets or remotes are required.

## Current instruction sequence

1. On joining without a stand, show **"Claim your smoothie stand!"** immediately as the FIRST tutorial instruction. This banner does not wait for the existing server-controlled claim-world-highlight readiness. Remove only the separate PlotIdentityController status message "Claim an available PLOT!". Claim/join labels and actual plot actions remain available.
2. After successfully claiming a stand, clear the claim banner and wait three seconds before showing **"Head to your customer counter!"** for the initial Counter objective. Reaching the counter early advances to Order and cancels this obsolete hint.
3. At the first-customer order interaction, show **"Take the customer's order!"**.
4. On the first RED Stash objective following accepted order, clear the order banner immediately. After 2.5 seconds, show **"Grab ingredients from the stash!"**, the correct slot/base gleam and the directional beam together. Advancing early cancels this presentation delay; repeated one-item pickups resume immediately.
5. Preserve Ladder teaching, then show device-specific sentence-case wording from PreferredInput and the real CAS throw binding: "Click to throw into the blender!", "Tap Throw to toss it in!", or "Press <bound button> to throw into the blender!". Reading/changing the hint never dispatches input.
6. **"Spin to blend smoothie!"** and the existing turbine highlights continue until authoritative completion.
7. Preserve the original post-blending Dispenser objective and **"Dispense your smoothie!"** instruction. Show it immediately on readiness, even if another hint was animating out. Keep the dispenser highlighted until the server observes actual smoothie ownership.
8. After smoothie collection, show **"Serve customer and get PAYED!"** and highlight the active customer. There is no additional counter-navigation substage or three-second delay here. This hint remains until authoritative progression changes after a successful serve/payout. Early successful service cancels all pending RED hints.

## Directional beam

The yellow outer Beam is 62.5% thicker than Pass 2: widths 0.26/0.195 studs, with transparency 0.6. Two local Attachments connect HumanoidRootPart local position (0, -0.5, +1.25), behind the avatar, to the current stash slot part. Parenting these attachments naturally follows avatar and slot movement without continuously moving world-space attachments.

A narrower, brighter yellow-white inner Beam shares the same endpoints and gentle 1.5/-1.5 curves. Its soft transparency segment advances from normalized distance 0 (player Attachment0) to 1 (stash Attachment1) over 2.4 seconds, fading at both ends before repeating. It uses an animated gradient, avoiding texture assets and texture-speed direction assumptions. Seventeen ordered keypoints stay below the engine's twenty-keypoint limit; twenty Beam segments render the gradient.

The implementation follows the [Roblox Beam reference](https://create.roblox.com/docs/reference/engine/classes/Beam) and [NumberSequence reference](https://create.roblox.com/docs/reference/engine/datatypes/NumberSequence). Automated tests verify increasing peak position and repeat direction. Native rendering and visual direction have **not** been verified in Studio: the current tools do not expose a live Studio surface. This remains a required visual acceptance check, not a claimed result.

Both Beams and both Attachments are destroyed on pickup/objective changes, death/respawn, target removal, tutorial cancellation/completion or controller shutdown. Flow uses the gleam controller's existing Heartbeat; no extra animation connection survives cleanup. Missing/recreated targets recover through the existing resolver. Only RED's active Stash objective gets these Beams; COLD/YELLOW retain their normal gleams.

## Lifecycle and authority

TutorialPresentationState coordinates text and world guidance using local deadlines. It creates no delayed tasks, sends no remotes and writes no gameplay attributes. Character removal cancels pending deadlines. If a still-valid objective survives respawn, its pending presentation delay restarts for the new avatar. Completed presentation milestones stay completed, and obsolete messages cannot override a later objective. UI recreation preserves current progression and timing.

TutorialOrderIndex > 1 latches instructional text off until a genuinely new PlotSessionId. Later customers retain the original target selection and progression, without instructional messages or RED beams. TutorialHintController disconnects active rendering/input/announcement subscriptions when text is disabled; its player lifecycle observers remain for a fresh session. Destroy disconnects all observers.

The current checkout configures base carry capacity as 3 in Upgrades. This pass leaves the economy unchanged; integration tests exercise both a one-item capacity and upgraded stacks.

## Pass 3 changed files

- `src/client/Controllers/PlotIdentityController.luau`: removes the actual startup claim-status prompt, preserving plot actions, labels and failure feedback.
- `src/client/Controllers/TutorialPresentationState.luau`: three-second initial counter timing, 2.5-second first-stash timing, cancellation and first-customer text latch.
- `src/client/Controllers/TutorialHintController.luau`: shows the initial stand-claim instruction immediately and retains immediate smoothie collection readiness.
- `src/client/Controllers/TutorialGleamController.luau`: synchronizes objective highlights and thicker outer/animated inner stash Beams; shared cleanup for both Beams.
- `src/client/UI/TutorialBeamFlow.luau`: asset-free, forward-only repeating transparency segment.
- `src/client/UI/TutorialHintText.luau`: preserves ClaimPlot, Counter and Dispenser instructions; provides exact Serve, sentence-case throw and turbine wording.
- `tests/tutorial_hints.spec.luau`, `tests/plot_identity.spec.luau`, `tests/run_state_tests.py`: focused timing, direction, startup removal, lifecycle and new-module test loading.
- This guide: behavior, changed files and Studio checks.

No server service, customer order, economy, inventory/carry dispatcher, announcement producer, Framewisp menu or Rojo mapping changed in Pass 3.

## Validation

PASS: tutorial-hints, tutorial-targets, plot-identity, tutorial and tutorial-gameplay. Presentation cases cover immediate stand claiming before world-highlight readiness, three-second initial counter navigation, shared 2.5-second stash timing, thicker forward-flowing beams, repeated pickup, original dispensing, direct serving, reset/rapid objective cancellation, later-customer silence and real global announcement priority. Retained state/integration suites cover all three customers, accepted ingestion, completed blending, cup grants and committed payout.

PASS: Roblox-aware typecheck of the tutorial presentation modules, changed-file StyLua, fresh Rojo sourcemap/build and whitespace validation. No new Studio setup is required.

The tutorial-claim integration suite reproduces on HEAD with a pre-existing bootstrap fixture failure while loading UnstuckService's shared event dependency; it is reported separately from the passing tutorial suites. CLI tests use engine doubles and do not prove native render appearance, multiplayer replication or contact physics. No live Studio session was run.

## Studio multiplayer/mobile/controller checklist

1. Start two clients and claim separate plots. Confirm "Claim your smoothie stand!" appears immediately before claiming and "Claim an available PLOT!" never appears. After claiming, wait three seconds for "Head to your customer counter!". Reach the counter and confirm "Take the customer's order!". Spawn/claim labels, claim interaction and environmental highlights should work.
2. Accept RED and time 2.5 seconds: the order hint clears immediately, then stash text, slot 3/base gleam and both Beams appear together. Pick up before the deadline and confirm no delayed stash text/beam later. Repeat with one-item carry and upgraded stacks.
3. **Visually verify beam direction in Studio:** stand, walk and turn while looking along the beam. The bright portion must move from behind the avatar toward slot 3 and repeat at a comfortable pace, never moving back toward the avatar. Check at multiple camera angles and phone/desktop sizes; the thicker translucent outer curve should remain visible without obscuring the face/view. Pickup and respawn must remove both Beams and Attachments, with no jitter or accumulating instances.
4. Switch mouse/touch/controller while carrying. Confirm sentence-case wording and the actual R2/RT binding, with no unintended throw. Test real throw ingestion/misses, turbine activation without completion and "Spin to blend smoothie!".
5. Finish blending: "Dispense your smoothie!" and dispenser highlight must appear immediately. Failed/full-inventory collection attempts must retain them. After successful collection, exact "Serve customer and get PAYED!" and the correct customer highlight should appear without another counter hint or delay, and persist through failed serves until real successful payout.
6. Reach the initial counter or accept the first order before either opening delay ends, reset during either delay, destroy/recreate the tutorial GUI and stream targets out/in. Verify no stale instruction, beam or highlight returns. Early serving must remain valid without waiting.
7. Trigger mystery/cleanup announcements during each RED stage and during COLD/YELLOW. Confirm announcement priority through entrance/hold/exit and no text overlap. After RED is successfully served, pause at all COLD/YELLOW actions for 20 seconds and respawn: no tutorial text or RED beam, but correct highlights, real gameplay progression and ordinary global announcements remain. Confirm other clients never see the owner's local hints/beams.
