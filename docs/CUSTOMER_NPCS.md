# Custom customer avatars

## Studio setup

1. In Edit mode, use your avatar-import plugin, enter a Roblox username, and insert its rig into Workspace.
2. Inspect the imported content and remove unwanted scripts, Tools, and other plugin extras before playing. Configure its appearance. Standard R6/R15 rigs need no manual facing rotation.
3. Ensure the Model has a direct Humanoid and preferably a direct HumanoidRootPart. Enable Archivable on the model and required descendants. A valid PrimaryPart or the existing first-BasePart root fallback also works.
4. For a mapped special, add its **string** Model Attribute, for example `CustomerId = "steak"`. Regular avatars need no mapping.
5. Move regular Models into `ServerStorage.CustomerNPCs.Regular` and mapped specials into `ServerStorage.CustomerNPCs.Special`, as direct children of those Folders. Rojo creates this Folder and preserves manually authored children; save the Studio place to retain your imported assets. They are not stored in the source repository or reproduced by a fresh CLI build.
6. Optionally add an NPC mapping in `src/shared/Constants/CustomerRequests.luau` (the steak mapping already exists).
7. Start Play, then start a day. Verify Output shows `[CustomerService] selected type=Special template=SteakNPC customerId=steak displayName=Steak request=Steak jumpTier=1 forced=true` when that avatar reaches the counter. The player must have JumpLevel >= 1; specials are uncommon and capped at one per day.
8. Verify appearance, counter facing, order placement, proximity serving, and departure. Repeat with two players to check each plot independently.

```text
ServerStorage
  CustomerNPCs (Folder)
    Regular (Folder)
      BuildermanNPC (Model; optional unmapped CustomerId)
    Special (Folder)
      SteakNPC (Model; CustomerId = "steak")
        Humanoid
        HumanoidRootPart
        ...body parts, joints, clothing, accessories
```

No NPC CollectionService tag is required. Existing plot marker BaseParts still need the `CustomerSpawn`, `CustomerCounter`, `CustomerWait1`, `CustomerWait2`, and `CustomerExit` tags. Use one marker per role within the player's plot, with horizontal top surfaces at intended ground level. Move old pivot-height markers down to the floor; route direction now controls facing. Start Day is disabled; plot ownership starts the queue. Serving distance checks remain. See [CUSTOMER_QUEUE.md](CUSTOMER_QUEUE.md).

## ID and request contract

CustomerId is trimmed and **case-sensitive**. Missing, non-string, and whitespace-only values are absent. Model.Name and Roblox username never supply a fallback ID; renaming a model with CustomerId present does not change its request. The ID is captured privately on the server when cloned. Changing runtime attributes does not reroute an active order.

CustomerRequests exposes `Definitions` (the request array), `NPCs` (the mapping), `SpecialCustomerChance` (currently 0.32), `NormalizeCustomerId`, and `GetForNPC`. Existing in-repository array consumers were updated to `.Definitions`.

```luau
NPCs = {
    steak = { Type = "Special", DisplayName = "Steak", RequestId = "Steak", Weight = 1 },
    bacon = { Type = "Regular" },
    builderman = { Type = "Special", RequestId = "Sweet", Weight = 1 }, -- optional
}
```

The included definition is:

```luau
{
    Id = "Steak",
    DisplayText = "I want STEAK in my smoothie!",
    RequiredTags = { "Steak" },
    BasePayout = 105,
    MinJumpTier = 1,
    NPCOnly = true,
}
```

A fixed-request special is eligible only when the server-owned JumpLevel meets that request's MinJumpTier. Locked or invalid fixed requests remove the NPC from selection; they never substitute a random order on that special avatar. Eligible specials use the configured chance per arrival, limited by a per-player 300-second cooldown in Economy. Weights choose within the selected category (default 1, positive finite values). With no eligible special, or during the cooldown, selection uses regular templates or the generic fallback. The chance is not a guarantee of a special every cooldown interval.

Unconfigured NPCs are Regular. An explicit Regular always uses the normal random pool, even if RequestId is present. For compatibility, a RequestId-only mapping is Special. A Special without RequestId uses the normal eligible random pool. RequestId is resolved privately at spawn and reused at arrival/refresh. If its tier becomes unavailable before assignment/refresh, the special is removed; restore eligibility and let the arrival scheduler retry.

Regular random requests exclude NPCOnly and require MinJumpTier <= JumpLevel. Steak remains NPCOnly. No duplicate NPC tier setting is introduced. GameService calls CustomerService.BeginDay only on a new day; resume does not reset the cap. Player removal/reset clears in-memory selection history. No persistence is added.

Ingredient names alone do not satisfy required tags: authoritative validation still reads semantic tags in Ingredients.luau. This change does not edit ingredient definitions or the serving transaction.

## Templates and lifecycle

Each spawn chooses a valid direct child Model from the selected category, avoiding the player's previous template when alternatives exist. A repeat is never avoided by exceeding the special chance/cap; a lone regular may repeat. IDs need not be unique across visual variants. Invalid templates are skipped with a useful Studio warning once per template instance. An empty/missing/unusable folder uses a regular legacy ServerStorage.Customer template, then the generated torso/head fallback. A legacy template configured as Special cannot bypass special selection; put special templates in CustomerNPCs.Special. Flat children are ignored. Category/mapping mismatches are rejected: a mapped Special in Regular cannot impersonate a missing special, and unmapped models in Special cannot enter the regular pool.

Only clones are modified. Before entering Workspace, clones lose Script, LocalScript (including Animate), ModuleScript, Tool, ProximityPrompt, BillboardGui, and SurfaceGui descendants. Body parts, clothing, meshes, face decals, accessories, attachments, and rig joints remain. Extra constraints remain, while every BasePart remains noncolliding. The cloned HumanoidRootPart stays anchored for the deterministic PivotTo route. Connected body/limb parts are unanchored so existing Motor6Ds can animate; disconnected decorative parts remain anchored. No route physics constraints or network ownership calls are added. Inspect plugin imports in Edit mode as well; runtime clone cleanup does not sanitize originals placed in Workspace by the plugin.

R6 and R15 support the existing straight-line PivotTo movement. HumanoidRootPart takes precedence over PrimaryPart. There is no pathfinding. CustomerWalk uses the existing Humanoid/Animator, choosing a standard R6/R15 walk explicitly without relying on Animate. Imported scripts are removed. The model moves Spawn -> assigned queue marker -> Counter -> Exit facing travel direction. Each segment uses CFrame.lookAt(position, target) with a horizontal direction, so Roblox -Z forward points toward travel. Zero-length segments retain a safe horizontal facing. Marker rotations no longer cause backwards travel. The clone is normalized upright, then its pivot-to-bottom distance is measured from GetBoundingBox (including the box axes' vertical extents). Each route position uses marker center X/Z and marker top Y + measured distance. Optional finite numeric CustomerVerticalOffset adds a correction (default 0). Avatar size is never hardcoded. Normal R6/R15 rigs need no offset; unusual accessories extending below the feet affect visual bounds. The existing order bubble adorns Head or the resolved root. Departure and reset/player-leave cleanup remain unchanged.

CustomerService retains private owner, CustomerId, RequestId/request definition, model, readiness, and served state. CustomerId, RequestId, and OwnerUserId attributes are presentation/debug outputs. Request assignment occurs when queued; all three orders remain visible. Serving uses the same server-owned cup consumption, ingredient-ID metadata validation, once-only payout, and GameService callback. Success and failure both consume the order; only success pays. Economy.MaxCustomersPerPlot limits the waiting queue to 3; serving continues indefinitely.

## Validation

### Display name and billboard revision

`NPCs[id].DisplayName` is optional and presentation-only. Steak, Caseoh, Pirate, Walter, and Prankster have configured names. Special customers prefer the authored Humanoid.DisplayName, then configured DisplayName, normalized CustomerId, and finally the original model name. This name is captured before the clone is renamed. Regular/generic customers show CustomerNPC above the request in the existing OrderBubble. Neither the name nor imported username/Model.Name affects request identity.

The existing fixed-request path is retained: `candidateFor` resolves the configured RequestId and filters by MinJumpTier; `SpawnForPlayer` captures it as `record.FixedRequest`; `assignRequest` uses it when queued and on refresh without drawing a random request. Selection chance, transactions, and payouts are preserved; the daily cap is replaced by a continuous cooldown.

`CustomerBillboardExtraHeight = 2` in CustomerService adds `(0, 2, 0)` to the existing `(0, 2.5, 0)` StudsOffset, yielding `(0, 4.5, 0)` for every customer. The name row adds 28 pixels above the preserved 300-by-80 order area. Both labels retain transparent backgrounds, outlined GothamBold text, and AlwaysOnTop. Cloned Humanoids use the resolved DisplayName and DisplayDistanceType = None and HealthDisplayType = AlwaysOff so the custom row is the single overhead name. Source templates are untouched.

Previous pass validation: 307 focused customer assertions pass, including each configured special's fixed request/no random assignment, tier gating, name/fallback, refresh, generic behavior, offset axes, and existing serving success/failure/duplicate-payment/day-flow checks. World text (49 + 23) and interaction presentation (79) pass. All 70 source files compile; changed Luau files pass StyLua; Rojo build passes. Roblox-aware analysis has no errors in changed modules, but reports four existing StashPromptController type errors (lines 16, 36, and 39) and a CharacterPhysicsService deprecation warning. The broader `--customer-only` suite still stops at the previously documented BlendVFX assertion `start clears copies and cancels arrival`.

No new Studio setup is required for templates with valid CustomerId attributes. Live visual verification of the added row and nameplate suppression remains to be performed in Studio.

### Earlier NPC implementation validation

- Focused customer regression: `python tests/run_state_tests.py --requests-only --luau <luau.exe>`: 196 assertions pass, using real CustomerService, request config, PlayerDataService, and GameService with a mocked Roblox boundary/cup provider.
- Coverage includes forced/unknown/missing/invalid IDs, renaming, private ID capture, invalid mapping, template cloning and cleanup, malformed/non-archivable clones, root fallbacks, target-facing geometry, bounding-box ground alignment, offsets, special tier filtering/chance/cooldown, no immediate repeats, success/failure payouts, duplicate serve rejection, endless queues, generic fallback, and legacy templates.
- Character physics: 32 assertions; interaction prompts: 79; world text: 49 + 23 pass.
- Full state suite and `--customer-only` stop at `start clears copies and cancels arrival`; blender status stops at `readable world-space settings`; upgrade UI stops at `stale timer cannot clear new request`. All three failures reproduce in an isolated pre-change snapshot retaining the user's Ingredients edits.
- Changed Luau files pass StyLua; all 63 source Luau files compile; Rojo build passes. Roblox-aware analysis reports existing StashPromptController errors at lines 36/39, with no errors in the changed runtime modules.
- Live Studio avatar appearance, engine cloning/replication, and movement have not been play-tested here.

## Walk presentation and verification

`src/server/Services/CustomerWalk.luau` owns default animation IDs (R15 507777826,
R6 180426354), fade time, full locomotion weight, and playback speed. No new asset upload is required.
Imported Animate.walk assets are no longer used: their compatibility/permissions
were not verified by the old controller. The selected standard Animation stays
alive with its track. Playback waits for nonzero Length, with a bounded timeout.
If an asset cannot load, spawning and authoritative movement continue without
animation, and Studio Output explains the failure.

The start of a nonzero route segment starts walking, arrival fades it out, and departure
resumes it. No Humanoid Running/Animator event listeners are added. The existing
model Destroying handler disposes the track, including removal, day reset, and
finished departures. Marker resolution, route speed, requests, and payouts stay
unchanged.

Run `python tests/run_state_tests.py --requests-only --luau <luau.exe>` for the
selection/special lifecycle contracts and separate placement/walk presentation
checks. Authored avatars are stored only in Studio, so validate both rig types
there: subtle walk in/out, idle at counter, accessories attached, removal during
travel, and reset while a served customer is departing. Verify asset permissions
in the published experience if using an authored custom animation.

This pass: focused request/selection/lifecycle and placement/walk suites pass.
Roblox-aware typecheck of `src` passes with the existing CharacterPhysicsService
`LoadCharacterAppearance` deprecation warning. Changed Luau files pass StyLua;
Rojo build passes. No Studio visual smoke test was available.

## Post-serve feedback

`CustomerPresentation.Response` maps A/B to the assigned request's GoodResponse
and C/D/F to BadResponse. Missing or blank text retains the previous no-dialogue
fallback. Request fields are optional; response strings remain in request data.
The current authoritative serving path still grades A or D; no grading, validation,
payout, eligibility, reaction, or day-sequencing rules changed.

Feedback uses the existing typewriter and dialogue sound in OrderBubble. It can
remain visible during departure, then is removed with the customer. The existing
two-second departure delay is unchanged. Special name resolution and feedback
selection live in `src/server/Services/CustomerPresentation.luau`.

For this pass, 262 request/serving assertions and 42 presentation assertions pass.
Studio must still verify R6/R15 animation playback, feet alignment, stable counter
waiting with anchored roots, departure, and removal/reset during feedback.
The CLI doubles cannot verify physics or asset permissions. No new upload is
required for the default animations. Imported Animate.walk assets are ignored. Animation tracks are resources of the clone and are
removed through its existing destruction lifecycle.

## Anchored-root ownership correction

The removed `root:SetNetworkOwner(nil)` call attempted to assign the rig's physics
to the server. Checking only `root.Anchored` did not establish that its entire
assembly was unanchored. Route-controlled customers now make no network ownership
calls. AlignPosition/AlignOrientation and their target-update plumbing were removed.
Both route segments use the original PivotTo interpolation, with walk start/stop
commands at segment boundaries. Zero-distance segments stay idle.

Authored Studio avatar models are not included in this source checkout, so their
individual anchor flags cannot be inspected here. Clone preparation normalizes
connected limbs regardless of their authored anchor flags and preserves joints.
Verify both rig types and disconnected decorations in Studio.

## Nameplate and walk loading diagnostics

The Humanoid's built-in display is disabled through DisplayDistanceType.None and
HealthDisplayType.AlwaysOff. The custom BillboardGui and resolved title are unchanged.

Confirmed code defects in the previous walk implementation: unverified authored
assets took precedence over rig defaults, LoadAnimation/Play errors were silently
ignored, readiness was not checked, and the temporary Animation was destroyed
immediately after LoadAnimation. These do not prove the live avatar's exact failure.
This checkout contains no authored avatar rigs and exposes no Studio runtime tools.

CustomerWalk now selects R6 180426354 or R15 507777826, uses Movement priority,
weight 1, speed 0.8, and a 0.15-second fade. It keeps the Animation until cleanup,
waits up to five seconds for nonzero Length, and only starts a delayed clip if the
route is still moving. Arrival/destruction prevents stale playback. Root anchoring,
joints, route timing, and reactions are unchanged; competing tracks are reported,
not stopped automatically.

In Studio, filter Output for `[CustomerWalk]`. Each customer reports its original
template name, rig, selected asset, Animator found/created, load result, root anchor,
and Motor6D endpoints/enabled/anchor flags. Each segment reports readiness and
Play result, then IsPlaying, Length, weight, speed, priority, and competing tracks
immediately and once after the fade. There is no per-frame logging.

Verify a Regular and Special rig (both R6/R15 if authored):
1. Only the custom title/request UI appears; no default health/name UI.
2. Check `LoadAnimation success=true`, nonzero Length, `IsPlaying=true` and nonzero
   weight after fade. A zero initial weight during the fade is expected.
3. If loading fails or times out, include Roblox's asset/permission error. If the
   track is playing but limbs are still, check motor endpoints, disabled motors,
   independently anchored body parts, rig names, and competing higher-priority
   tracks in the same log. Inspect any rigid welds bypassing animated joints.
4. Observe walking on arrival/departure, idle at counter, and cleanup on reset.

Run only `python tests/run_state_tests.py --customer-presentation-only --luau <luau.exe>`
for this pass: 52 presentation assertions pass. Typecheck and StyLua pass; the
existing CharacterPhysicsService deprecation warning remains. Rojo build passes.
Visible playback and the exact live root cause remain unverified until Studio
Output and authored rigs can be inspected.
