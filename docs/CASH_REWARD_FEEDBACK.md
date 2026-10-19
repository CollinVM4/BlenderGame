# Customer cash reward feedback

Cash effects consume the existing server `GameplayPresentation` / `CustomerReaction`
notification. Only a positive finite payout for the local serving player's UserId
with a nonempty server BlendId can animate. Blend IDs are remembered for the client
session, including respawns and skipped effects. No remote, reward calculation,
cash balance write, or serve validation was added. A committed D-grade consolation
payout still animates; rejected requests never emit the confirmed notification.

The world result displays the authoritative final payout with the existing colored
grade, or cash alone for wildcard orders. D-grade retry messaging and negative
freeloader amounts remain. The ingredient/base subtotal is removed. There was no
separate rarity-bonus row in this result renderer; existing Mystery announcements
and all payout bonuses remain unchanged.

The payout uses `HumanoidRootPart.CustomerRewardOrigin`, measured once at customer
creation, 0.35 studs below the resting head center. Dialogue/card heights and head
animation cannot lift it. The existing reaction-card drop, outline, distance limit
and four-second result hold remain. Exit snapshots also retain PlotSessionId so
the remaining reward stays visible to members of the same plot.

## Upload and configure

The supplied attachment contained the request text but no PNG binary. Upload your
original **Green Cash 1st Outline 64px.png** through Studio's Asset Manager and set:

- Repository: `src/shared/Constants/CashFeedback.luau`, `Image` (line 5).
- Studio: `ReplicatedStorage.Shared.Constants.CashFeedback`, `Image`.
- Value: `"rbxassetid://<your uploaded image ID>"`.

The default empty reference deliberately skips the cosmetic burst. Server payouts
and world reward text work immediately. No replacement icon or invented asset ID
is provided. There is no required Workspace or Framewisp export edit.

## Animation and Framewisp lifecycle

Five to eight images pop from the player's projected torso, staggered by 40?50 ms,
stretch, float for 150?200 ms, and accelerate along quadratic curves toward the
current TOP cash frame. The last image finishes in approximately 0.8?0.99 seconds.
At most 24 images coexist. Rapid serves share a render loop and retain independent
bursts; excess cosmetic bursts skip without affecting balance updates.

The destination uses the same UIRegistry semantic/reimport contract as UpgradesGui:
Desktop ? optional Content ? TOP ? CashDisplay ? Cash/{Coins}. Hidden, disabled,
missing, zero-size and ambiguous imports skip safely. Each animation frame resolves
the current target, so reimports and resize do not retain stale screen coordinates.
Absolute centers are converted relative to the effects canvas's actual origin;
WorldToScreenPoint projects the torso into the same inset coordinate system.
See Roblox's [GuiBase2d coordinate documentation](https://create.roblox.com/docs/reference/engine/classes/GuiBase2d)
and [Camera projection documentation](https://create.roblox.com/docs/reference/engine/classes/Camera).

The 1.08? arrival pulse multiplies an existing UIScale relative to its original
value, or creates a temporary UIScale. Cleanup restores the captured value/removes
the temporary scale, without changing authored Size or UIStroke. If Framewisp
changes that scale during the pulse, the effect yields ownership. Audio reuses the
existing pickup/throw PLIP/PLOP assets through GameplayAudioController at low volume,
limited to one short cue per burst/collection with overlap throttling. Listen in
Studio to confirm these existing clips fit the intended cash feel.

## Studio checks

1. Set the uploaded image reference, sync Rojo, and Play with two clients.
2. Serve A/B/C/D orders and wildcard orders. Compare the single world cash amount
   with the server cash increase; wildcard must have no letter grade. Check the
   existing grade colors, D retry line, and Mystery/rarity announcements.
3. Use regular and special rigs of different heights. Move/animate their heads;
   cash should stay just below the resting head center, remain legible over the rig,
   and avoid overlapping the reaction/name card. Check near/far camera distances.
4. Check 5?8 supplied green icons at the serving player's chest, outward pop/stretch,
   brief float, curved flight to the actual top cash frame, fade/shrink, and subtle
   HUD pulse. The other client must not show a burst for that player's serve.
5. Serve rapidly, retry the consumed cup, try serving with no cup, and reset during
   flight. There must be no duplicate payout or effect. Check that CashIcon and
   CashRewardEffects instances disappear after completion/reset.
6. Use Device Emulator for phone portrait/landscape and tablet, then resize desktop.
   Check torso origin, compact spread, GUI insets and correct cash destination.
7. Hide/delete the active cash HUD during flight; payouts must continue with graceful
   cosmetic cleanup. Replace/reimport the Framewisp root, retaining its semantic
   roles; the next serve must target the replacement. Test two active imports:
   effects should pause while ownership is ambiguous, then resume on a new serve.
8. Confirm authored cash sizing/strokes and the existing replicated cash balance
   binding remain intact after pulses, respawn and reimport. Listen for brief cues
   without excessive overlap.

## Validation

Passed: standalone cash presentation contracts (actual gate/controller/animation/
HUD modules), customer-result and gameplay-audio suites, existing upgrade/cash UI
suite with early and delayed UI, focused Roblox-aware module typecheck, StyLua,
Rojo build, and whitespace validation. These use mocked engine boundaries; live
Studio rendering/network/audio was not run.

Bootstrap analysis reports the same 22 unique pre-existing CustomerRequests
DisplayText diagnostics on a separate baseline snapshot, with zero new diagnostics.
Three requested economy/integration suites fail identically on that baseline:
customer-payout (StandIdentity receives a nameless test player), customer-payout-serve
(stale expected cash/grade), customer-wildcard (authored wildcard probability
expectation). Unrelated production/economy code was not changed to repair them.

## Files changed for this pass

- `src/server/Services/CustomerPresentation.luau`
- `src/client/init.client.luau`
- `src/client/Controllers/CashRewardController.luau`
- `src/client/Controllers/GameplayAudioController.luau`
- `src/client/UI/CashHud.luau`
- `src/client/UI/CashRewardState.luau`
- `src/client/UI/CashRewardAnimation.luau`
- `src/shared/Constants/CashFeedback.luau`
- `tests/customer_result.spec.luau`
- `tests/customer_payout_serve.spec.luau`
- `tests/gameplay_audio.spec.luau`
- `tests/cash_reward.spec.luau`
- `tests/run_cash_reward_tests.py`
- `docs/CASH_REWARD_FEEDBACK.md`

Existing tutorial/ingredient edits in the working tree belong to another pass and
were preserved.
