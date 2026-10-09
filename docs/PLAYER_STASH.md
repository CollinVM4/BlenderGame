# Player stash

InventoryService owns stash contents and carried items. STORE and TAKE are explicit
commands: neither command becomes the other after a pause, an equip change, an empty
slot, or a rejection. There is no direction timer.

## Controls

Approach a slot using the existing proximity-prompt focus convention. Only the
focused slot is outlined and has a compact Fredoka panel showing STASH 2/3 and
separate STORE and TAKE buttons.

- Mobile: separate 138 × 56 touch buttons.
- Desktop: E stores one item; R takes one item. Both keys appear on the buttons.
  E uses the native focused prompt activation; R uses the separate TAKE action.
  STORE does not bind E a second time, so the native prompt cannot swallow a
  competing STORE callback.
- Console: ButtonX stores; ButtonY takes. Platform controller icons appear on the
  buttons. Focus starts on STORE; left/right navigates; normal controller GUI
  activation activates the selected action.

The panel occupies the center lane at 72% of screen height, away from right-hand
Jump/Throw/Sprint controls. Positions and meanings stay fixed. It dismisses when
focus changes, the prompt hides, the character dies, membership ends, or the player
moves out of range. Values, ripeness displays, and ingredient proxies keep their
existing world presentation. Unavailable actions dim and give a short reason when
pressed. Server rejection messages appear briefly, with no persistent instructions.

## Authoritative behavior

- Protected and exposed slots hold three mixed ingredient records. Only slots 1–2
  are permanently protected; second storage keeps its existing unlock and layout.
- A smoothie occupies an entire slot (1/1). Clearing it restores ingredient capacity
  (0/3). Blend identity and ordered ingredients survive a round trip.
- STORE uses the existing equipped selection and newest carried ingredient fallback.
  TAKE uses ripest-first ordering and the existing carry/equip path.
- Actual plot membership, teammates, fixture identity, character health/action state,
  proximity, carry capacity, and raid protection are validated by the server.
- Enemies cannot STORE or TAKE protected slots. Explicit TAKE from exposed slots
  retains the six-second shared raid window and thirty-second subsequent protection.
- Failed visual creation or equip restores exact stored records. Replicated counts,
  highlights, and availability are cosmetic; clients never edit contents.

The server creates Shared.Events.StashAction (RemoteFunction). Requests contain the
canonical authored StashPrompt, exactly STORE or TAKE, the actor session/revision,
the target session, and a monotonically increasing request ID. Stale contexts,
replays, invalid actions, and wrong prompts fail closed. A 60 ms request throttle
and synchronous actor/target transaction guards protect repeated input. The client
keeps one request pending until acknowledgement, animates the button immediately,
and waits for authoritative inventory replication.

InventoryService.InteractStash(player, index, owner, fixture, action) returns success
and an optional short rejection reason. Deposit, Withdraw, CanWithdraw, and Steal
retain their existing server APIs. StashChanged continues to drive displays.

## Studio setup and smoke checks

Rojo sync and start a fresh play session. No manually authored remotes or new assets
are needed. Keep one PlayerStash fixture per plot, unique base SlotIndex values 1–5,
and the existing authored expansion. Existing StashPromptOrigin attachments can stay;
the new panel uses screen UI and the canonical slot part for focus. For three physical
occupancy lights, provide three SlotIndicator parts in each locked-slot model;
missing lights do not change gameplay capacity.

Run a local server with an owner, teammate, and enemy. In device emulation, verify
both touch targets, portrait/landscape placement, controller icons/navigation, and
keyboard hints. TAKE twice with a pause longer than 0.6 seconds; STORE twice with a
pause; switch immediately; tap rapidly. Confirm three mixed ingredients in each
protected/exposed slot, one smoothie, ripest-first TAKE, failure preservation, team
access, theft timing, and second-storage focus. Real Studio/network/device smoke
checks remain necessary; CLI tests mock Roblox boundaries.

## Automated checks

Run python tests/run_state_tests.py --luau <luau.exe> --stash-only, then select
stash-expansion, carry-selection, ingredient-slots, and bad-customer-stash using
repeatable --suite flags. State, integration, and presentation report separately.
Also run Roblox-aware typecheck, StyLua on changed Luau files, and Rojo build.

## Validation results for this pass

All five stash-focused suites and stash-expansion, carry-selection, ingredient-slots,
and bad-customer-stash pass. Changed-runtime Roblox-aware typecheck, StyLua, Rojo
build, and whitespace checks pass. Whole-source typecheck has exactly the same
diagnostics as the pre-change workspace; no new diagnostics were introduced.

Additional smoothie, smoothie-roundtrip, and ripeness-lifecycle suites still fail
on baseline: old carry-tier/capacity assumptions, a missing HasEntitlement method
in the customer fixture, and stale ripeness value expectations respectively. These
failures are isolated from the passing stash suites. Unrelated production code was
left unchanged. The old stash value expectations were updated to configured
ingredient values after their failures were reproduced on baseline.

Studio device layout/navigation, real network latency, and multiplayer raid smoke
checks have not been executed.
