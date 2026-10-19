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

- Repository: `src/shared/Constants/CashFeedback.luau`, `Image`.
- Studio: `ReplicatedStorage.Shared.Constants.CashFeedback`, `Image`.
- Value: `"rbxassetid://<your uploaded image ID>"`.

The current repository reference is `rbxassetid://122284146591659`. Its ownership,
permissions, moderation status and appearance have not been verified in Studio.
Collin must confirm it resolves to the supplied green cash image, or upload that
original and update both locations above. No replacement ID was invented. An empty
reference skips the burst; server payouts and world reward text remain independent.
There is no required Workspace or Framewisp export edit.

## Animation and Framewisp lifecycle

Five to eight images pop from the player's projected torso, staggered by 40?50 ms,
stretch, float for 150?200 ms, and accelerate along quadratic curves toward the
current TOP cash frame. The last image finishes in approximately 0.8?0.99 seconds.
At most 24 images coexist. Rapid serves share a render loop and retain independent
bursts; excess cosmetic bursts skip without affecting balance updates.

The destination uses the same UIRegistry semantic/reimport contract as UpgradesGui:
Desktop ? optional Content ? TOP ? CashDisplay ? Cash/{Coins}. Hidden, disabled,
missing, zero-size and ambiguous targets cannot receive a HUD punch. Resolution
first uses the primary path, then direct Cash/{Coins} labels and CashDisplay at
Content/Desktop level (including TOP directly under Desktop). Semantic roles,
optional Content and Frame/ScreenGui desktops retain the UIRegistry contract;
arbitrary descendant names are never used. Empty alternate desktops do not veto
one valid target; two valid active targets remain ambiguous. With no target, the
burst starts at screen center and flies back to center, with no HUD punch. Each animation frame resolves
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
7. Hide/delete the active cash HUD before and during flight; the burst must still
   complete, centered when started without a target. Replace/reimport the Framewisp root, retaining its semantic
   roles; the next serve must target the replacement. Test two active imports:
   effects should use screen center while ownership is ambiguous, then target the
   remaining valid HUD on a new serve.
8. Confirm authored cash sizing/strokes and the existing replicated cash balance
   binding remain intact after pulses, respawn and reimport. Listen for brief cues
   without excessive overlap.

## Opt-in Studio diagnostics (2026-10-19 repair)

On the Studio server Command Bar, enable the serving player:
`game:GetService("Players"):FindFirstChild("PLAYER_NAME"):SetAttribute("CashRewardDebug", true)`.
Read that client's Output. Disable by setting the attribute to false. Diagnostics
are off by default, disabled outside Studio, and capped at 20 lines per five seconds.

The controller logs the received moment/owner and the accept result: wrong moment,
owner mismatch, bad payload, bad BlendId, bad payout, duplicate or accepted. The
animation names empty-image, PlayerGui, camera, character/root, off-screen and
capacity gates, plus missing HUD targets and centered fallback. One real ImageLabel
per burst is sampled, with at most four pending probes. IsLoaded changes/cached
loads and ContentProvider fetch status identify successful versus failed loads;
a five-second timeout reports failure to load within that window (which can also
mean slow networking, not necessarily a bad ID). These probes do not delay animation.

Code inspection confirms the old missing-HUD gate both skipped new bursts and
deleted in-flight icons. The stale empty-default documentation/test also disagreed
with the configured ID. This establishes failure mechanisms, not which one occurred
in Collin's live session. No connected Studio session or Windows-control runtime
was available for this repair, so asset resolution and live acceptance remain unverified.

Studio acceptance still required: valid PNG renders pop/float/flight/punch on desktop
and mobile; invalid and empty references emit asset failures with diagnostics enabled;
hidden/reimported HUD keeps a visible burst and reports a missing target; teammate
serves animate only for their owner; D consolation animates while rejected serves do not.

Repair validation passed: `tests/run_cash_reward_tests.py` (real production modules
with engine doubles), Roblox-aware typecheck of all five changed runtime modules,
StyLua check of changed Luau files, fresh Rojo sourcemap/build and whitespace checks.
The suite covers malformed IDs/payouts, duplicate suppression, owner filtering,
D consolation, aliases/alternate roots, centered fallback and mocked asset load,
failure and timeout diagnostics. It does not verify image pixels or live serves.

## Previous implementation validation

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
