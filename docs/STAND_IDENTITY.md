# Walk-in plot claiming and stand identity

This pass replaces claim/join billboard buttons with authored walk-in zones, adds
an authoritative session stand name, and opens a compact naming editor after a
committed claim. It does not add Settings or DataStore persistence.

## Architecture and behavior

The existing `TycoonService` owns plot mappings, session IDs, membership revisions,
claim revisions, atomic creation, teammate capacity, promotion and final cleanup.
`ClaimPlot`/`RequestJoin` remain the authority APIs. New sessions use the existing
`JoinMode = "Open"` policy (Anyone); existing FriendsOnly/Closed policy APIs,
management, kick and leave behavior remain available.

`PlotClaimZones` samples live character roots against each authored zone's oriented
bounding box every 0.15 seconds. It validates the player, living character, exact
zone/plot hierarchy, physical containment and the existing stunned-action gate,
then calls existing membership
operations with server-captured revisions. Entry is recorded before asynchronous
dispatch, and pending entries are guarded so a yielding friendship lookup cannot
create repeated requests. Remaining inside a zone does not retry; leave/reenter to
try again. Respawned characters count as new entrants. The claim API's synchronous
reservation prevents two entrants from becoming owner or initializing twice.

Only the winner receives `PlotClaimed(plot, sessionId, membershipRevision)`, after
the existing claim lifecycle commits. The client's intro waits briefly for matching
replicated attributes. A missing camera skips the intro without blocking ownership.

The legacy ClaimPlot/JoinTeam `GameplayRequest` paths now reject requests. Their
billboard buttons are removed. `PlotIdentityOrigin` remains intact for existing
portraits, management/leave actions, and proximity checks. New CLAIM PLOT and JOIN
STAND billboards are TextLabels attached to their separate authored label origins.

`session.StandName` and `session.StandNameRevision` are authoritative; `GetSession`
includes both. Replicated plot attributes project those values. The default is the
platform-moderated `DisplayName .. "'s Stand"`, committed during session creation;
long DisplayNames are shortened at grapheme boundaries to preserve the suffix.
Promotion preserves the session name; final cleanup clears it. The centralized
name limit is **27 visible graphemes**. Unicode horizontal spaces become ordinary
spaces and edge spaces are trimmed; empty, malformed UTF-8, multiline/control
characters, bidi overrides and oversized normalized submissions are rejected.

`StandIdentityService` owns the dedicated `SetStandName` RemoteFunction adapter.
It requires the owner, exact plot, session/membership revision and name revision,
guards concurrent saves and rate-limits attempts. It calls server
`TextService:FilterStringAsync(..., PublicChat)` followed by
`GetNonChatStringForBroadcastAsync`, the [Roblox public sign filtering path](https://create.roblox.com/docs/reference/engine/classes/TextFilterResult).
It copies submitted context and revalidates after both yielding operations. Only
a usable filtered result reaches the trusted `CommitFilteredStandName` transaction.
Errors, blank results and stale requests leave the previous name intact. Conservative
custom token masking occurs before Roblox filtering; already filtered hash runs
become `****` for display. Fully censored names may safely display `****`.

`StandSignPresentation.SetStandName` assigns the same authoritative text to Main,
Depth1, Depth2 and Shadow. The server updates these authored labels, so Roblox
replicates the same public sign to every client, including late arrivals. There is
no owner's local sign value and no runtime letter geometry. Styling uses the
existing Fredoka convention: white main face, dark 3px outline, lavender/gray depth
at 2/4px and charcoal shadow at 6px, with fixed safe insets, wrapping, scaling and
20–96px constraints. Only `Customer Area/Dynamic Sign Text` is targeted.

`StandIdentityController.OpenNameEditor(plot)` is the shared initial/future Settings
entry point. It preserves camera state, tweens to the authored marker in 0.48s,
then opens/focuses the small Fredoka editor. SAVE waits for server success; failures
permit retry or skip. SKIP/X/Escape/controller B close without a rename. Return uses
a 0.35s tween toward the previous view translated by character movement, then
restores Roblox camera ownership and the current humanoid. Token checks prevent
old tween/remote completions from modifying a newer editor. Death, respawn,
ownership/session/revision loss, destroyed plot/marker/UI, camera replacement,
player departure and external UI closure cancel cleanly. The turbine camera has a
small release/suspend hook so both controllers cannot drive the camera together.

The naming prompt's polished layout is capped at 320?154 pixels, with a charcoal
background at 0.28 transparency, a subtle outline, an 18px Fredoka title/input,
and a 36px input field. SAVE and SKIP sit side by side with slim 28px visual faces
inside 40px tap/controller targets. SAVE uses a muted green accent; SKIP and X
are quieter. Both dismissal controls use the same callback. Camera, rename,
filtering, membership and claim authority are unchanged by this polish pass.
The hidden-pad regression and near-only label range are covered in the separate
presentation suites. Studio rendering, mobile/controller usability and the
22-stud range still need visual acceptance; no live Studio session was available.

Future Settings hooks are explicitly marked in `OpenNameEditor` and server
`SetTeammateAccess(player, mode, context)`. Anyone maps to the existing Open policy;
future access checks belong in the single existing `RequestJoin` policy branch.

## Required Studio setup

Workspace plot geometry is authored in Studio and is not part of this Rojo tree.
Apply this hierarchy to **each** tagged PlayerPlot:

```text
Plot
|-- PlotIdentity
|   |-- ClaimZone
|   |-- ClaimVisual
|   |-- ClaimLabelOrigin
|   |-- TeammateZone
|   |-- TeammateVisual
|   `-- TeammateLabelOrigin
|-- SignCamera
|-- Customer Area
|   |-- Counter
|   |-- Dynamic Sign Text
|   |   `-- SurfaceGui (Adornee = Customer Area.Sign.board)
|   |       `-- TextRoot
|   |           |-- Shadow
|   |           |-- Depth2
|   |           |-- Depth1
|   |           `-- Main
|   `-- Sign
|       |-- legs
|       `-- board
|-- PlotIdentityOrigin
`-- existing content
```

1. Make the two zones anchored BaseParts, tall enough to contain a walking
   HumanoidRootPart. Runtime uses their **box bounds**, including for cylinder
   parts. Keep claim/join zones separate and away from unrelated walkways.
   Zones are forced invisible, noncolliding, nontouching and nonqueryable; no
   ClickDetector or ProximityPrompt is required. Remove any old claim-specific
   scripts/prompts from Studio assets; retain unrelated legacy-origin content.
2. Keep the existing authored blue visual geometry. BaseParts may be nested in
   each Visual model. Their authored transparency is preserved when below 1 and
   becomes 1 when inactive. A pad initially authored fully hidden uses an active
   transparency of 0, so the teammate pad can appear after claim. Set a part's
   optional `ActiveTransparency` attribute (0?1) to specify its visible appearance;
   use 1 for intentionally invisible helpers. Label origins may be BaseParts or
   Attachments. CLAIM PLOT/JOIN STAND labels have a 22-stud MaxDistance.
3. Add direct-child `SignCamera`: Anchored=true, Transparency=1, CanCollide=false,
   CanTouch=false, CanQuery=false. Author its CFrame to face the storefront, with
   a clear camera path from the claim pad. Code never moves this marker.
4. Keep the intentionally deleted ThreeDText contents removed. Preserve the
   physical sign face at `Customer Area.Sign.board`. `Dynamic Sign Text` is a
   direct child of `Customer Area` and can be a Folder/Model. The helper sets
   SurfaceGui.Adornee to that board; it does not change the Sign model or board
   transforms.
5. After Rojo sync, select that Dynamic Sign Text root and run
   [`AuthorStandSign.luau`](studio/AuthorStandSign.luau) in the Command Bar to author
   the GUI/layers. The helper removes no geometry. Set SurfaceGui.Face to the
   authored viewing side; it preserves physical transforms. Its 800×320 canvas
   supports 1–2 lines. Inspect Bob's Stand, Collin's Stand, Super Smoothies,
   Noob Smoothies and 27-grapheme names; adjust the physical face/canvas and
   palette to the actual storefront art as needed.

No unrelated ThreeDText signs or 3D text assets were changed. The editable sign
migration is implemented and provided as Studio authoring setup; existing place
geometry has not been edited from this workspace.

## Validation and limits

### Naming editor selection cleanup

The editor captures prior GUI selection when opening. It enters controller
navigation using `UserInputService.PreferredInput`, not gamepad availability.
All naming-editor dismissals release text focus, resolve selection, then hide the
editor through one idempotent routine. External disabling uses the same routine.
Mouse/touch dismissal clears editor selection or an unchanged stale pre-editor
selection. Selection moved to another UI is preserved. Controller dismissal
restores the prior target only if it remains in PlayerGui, selectable, visible
through its ancestors, outside the editor, and in enabled GUI layers. There is
no existing controller fallback; an invalid return target resolves to nil, with
Roblox navigation still enabled. Manage Plot and Upgrades styling is unchanged.

Studio-only diagnostics default to off. During Play, run this in the **client**
Command Bar before claiming a plot:

```luau
game.Players.LocalPlayer.PlayerGui.StandNameEditor:SetAttribute("DebugSelection", true)
```

Output tagged `[StandNameSelection]` records opening, focus gain/loss, Save,
Skip, X, Escape/Button B, focus release, selection cleanup/hiding, and the next
Heartbeat. Each entry includes SelectedObject, its full name, last/preferred
input, and TextBox focus. Reproduce with mouse/keyboard (including a connected
idle gamepad), touch, and active gamepad. Check that mouse/touch exits leave no
stale HUD selection, controller exits restore only valid targets, and an
independently opened menu keeps its selection. If the outline appears, compare
its button to SelectedObject at that instant. Set the attribute to false after
verification. No GUI authoring changes are required.

`stand-editor` covers selection state and dismissal paths using engine doubles;
it does not verify Roblox's visual selection rendering. Live Studio confirmation
of the intermittent outline remains required.

Focused integration: `stand-identity`, `plot-player-flow` pass. Separate presentation:
`stand-sign`, `stand-editor`, `plot-identity` pass. The existing turbine camera
runner also passes. These cover claim contention, live/assigned/physical gates,
session/name identity, teammate capacity/departure, pad restoration, filtered
renames, UTF-8 limits, filter failures, duplicate saves, stale name/membership/
lifetime requests, delayed attribute replication, editor reuse and camera cleanup.

```powershell
python tests/run_state_tests.py --luau <luau.exe> --suite stand-identity --suite plot-player-flow
python tests/run_state_tests.py --luau <luau.exe> --suite stand-sign --suite stand-editor --suite plot-identity
python tests/run_turbine_camera_tests.py --luau <luau.exe>
```

StyLua and Rojo build pass. Roblox-aware Luau LSP analysis was run across `src`:
it remains red with the **same baseline diagnostics and no additions**. Existing
CustomerRequests/CombatService and other working-tree diagnostics were preserved.
`plot-session` fails at “one shared deduction and tier”; `plot-session-races`
fails at “purchase remains committed”. Both reproduce in an isolated pre-feature
copy. The runner's three existing contract-test failures also reproduce there
(stale VFX-entry, first-suite and state-manifest expectations). No unrelated
production code or runner contracts were changed to hide those failures.
Scoped diff whitespace checks pass; the whole working tree has existing trailing
whitespace in `.validation.rbxlx`, which was not changed by this feature.

Studio multiplayer/rendering acceptance remains required: test two simultaneous
entrants, live filtering failure/success, all three pad states and teardown,
owner departure/promotion, camera path and respawn, rapid reopen, late-client sign
replication, mobile layout, long names and storefront palette/readability. CLI
engine doubles cannot verify actual camera collision, rendered font metrics,
Roblox filtering availability or Studio-authored geometry. Customer, blender,
stash, Muncher, farm, combat, economy, rewards and upgrades were not changed by
this pass; their unrelated suites were not run.

## Files changed by this pass

- `src/server/Services/TycoonService.luau`, `GameplayService.luau`:
  session identity/default policy and retirement of legacy network claim/join.
- New `src/server/Services/PlotClaimZones.luau`, `StandIdentityService.luau`,
  `StandSignPresentation.luau`: zones, filtering/rename adapter and sign projection.
- `src/server/init.server.luau`: starts the focused services.
- `src/shared/Types.luau`; new `src/shared/Constants/StandIdentity.luau`:
  session identity fields, name/zone/camera limits.
- `src/client/Controllers/PlotIdentityController.luau`,
  `TurbineCameraController.luau`; new `StandIdentityController.luau` and
  `src/client/UI/StandNameEditor.luau`; `src/client/init.client.luau`:
  labels, editor/camera handoff and early claim subscription.
- New `tests/stand_identity.spec.luau`, `stand_sign.spec.luau`,
  `stand_editor.spec.luau`; updated `tests/plot_player_flow.spec.luau`,
  `plot_identity.spec.luau`, `run_state_tests.py`, `README.md`.
- New `docs/studio/AuthorStandSign.luau` and this guide; updated
  `docs/PLOT_SESSIONS.md` to supersede the old entry-flow instructions.

Pre-existing uncommitted edits were preserved.

## Naming input and filtering update

The shared limit and Unicode helpers live in
`src/shared/Constants/StandIdentity.luau` (`MaxCharacters`, `Count`, `Truncate`,
`Normalize`, `DefaultName`). Both server validation and the live counter use
Roblox `utf8.graphemes()`. The editor hard-truncates to complete graphemes and
clamps byte-based caret/selection positions. A separate 4096-byte resource ceiling
allows combined accents and multi-codepoint emoji without treating bytes as visible
characters. Canonical Unicode composition is preserved; no ad hoc NFC converter
is used. Newline/control input is rejected, not silently joined into another name.

`src/server/Services/StandNameSanitizer.luau` owns the explicit profanity list and
rules: case-insensitive complete ASCII tokens, common explicit inflections and
punctuation between letters. Longer words, digits/underscore/non-ASCII token
neighbors and spaced-out words are deliberately left for Roblox moderation.
`StandIdentityService.RequestName` validates raw input first, masks it, calls
`TextService:FilterStringAsync` with the author UserId, and obtains
`GetNonChatStringForBroadcastAsync`. Masking and the post-filter hash-to-star display
transformation can expand short tokens, so only these trusted transformed strings
are fitted back to the limit and the final result is validated. Oversized raw
client submissions are never accepted through server truncation. Neither filter
stage can publish raw input on failure.

Publication stays in `TycoonService.CommitFilteredStandName` / `publishIdentity`:
only the final broadcast-safe text enters the authoritative session, plot
attributes and `StandSignPresentation.SetStandName` world labels. SAVE captures the
current raw TextBox value, waits for the server and displays its authoritative
reply. Pending-save guards on both client and server prevent overlapping requests.
SKIP/X, camera sequencing, membership and ownership checks are preserved.

`StandNameEditor` keeps the 320 x 154 Fredoka card and adds an understated counter
under the input. `FocusLost(enterPressed)`, `ReturnPressedFromOnScreenKeyboard`
and SAVE all use the same guarded callback, following the
[Roblox TextBox focus events](https://create.roblox.com/docs/reference/engine/classes/TextBox).
Controller selection links reach TextBox, SAVE, SKIP and X; opening on a gamepad
selects the box, and closing restores the previous selection when applicable.
The editor observes all three
[on-screen keyboard properties](https://create.roblox.com/docs/reference/engine/classes/UserInputService)
and its usable-area bounds, moving the card above the keyboard in inset-aware
coordinates. Temporary scaling is used only when the available height is smaller
than the card. Keyboard closure restores the original position and scale.

Validation for this update: focused `stand-identity`, `plot-player-flow`,
`stand-editor` and `stand-sign` suites pass. StyLua checks and the Rojo build pass.
Roblox-aware LSP typecheck has the same 14 unique diagnostics as the recorded
pre-pass `stand-polish-types.log`, with no new diagnostics in the naming modules.
Build, fresh sourcemap and typecheck output are in the temporary tool directory
as `stand-input.rbxlx`, `stand-input.json` and `stand-input-types.log`.
The Unicode CLI fixture models only
its named accent, emoji, modifier, ZWJ and flag vectors because standalone Luau
lacks Roblox's grapheme iterator. Layout checks validate coordinates and submission
contracts; they do not prove engine font rendering or a real native keyboard.

No new Studio assets or remotes need authoring. After Rojo sync, manually verify
in Studio Device Simulator (not run in this environment):

- Desktop: type, paste, delete and edit in the middle; test 0, 1, 27 and 28
  graphemes, combined accents, emoji and long DisplayName defaults.
- Narrow phone, larger phone/tablet, console/TV: open the keyboard, resize/rotate,
  and verify TextBox, counter, SAVE, SKIP and X remain readable and above it;
  close the keyboard and verify the original card position returns.
- Mobile/console: press on-screen Return, then rapidly SAVE; only one request
  should be pending. Navigate all controls with a controller and reopen the editor.
- Two clients: save profanity and separator variants, verify only the filtered
  result appears on every sign layer and for late joiners; filtering failure must
  retain the previous/default name. Verify SKIP/X and teardown still return camera
  control without renaming.
