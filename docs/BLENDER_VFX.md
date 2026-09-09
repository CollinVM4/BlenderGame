# Blender presentation lifecycle

BlendVFX binds existing PlayerPlot instances. Gameplay ingestion, RPM/progress calculation, recipes, rewards, dispensing, reset semantics, and BlendProgressLights are unchanged.

## Ingredient notification correction

The previous observer compared a batch table received through BindableEvent with the original service table. Roblox copies table arguments, so the comparison rejected valid notifications before calling VFX. The mock boundary did not previously model that copying. See [Roblox's bindable argument documentation](https://create.roblox.com/docs/scripting/events/bindable).

BlendService now sends a private numeric notification token. Observers compare that scalar with the current batch's token, preserving stale-batch rejection without table identity. The API still returns a disconnectable RBXScriptConnection. Studio registration/notification logs count connected listeners. Batch reset does not reset the observers. Bootstrap injects the same BlendService instance into BlenderInput and BlendVFX; both initialize without yielding before Heartbeat ingestion.

TryInput notifies only after Consume succeeds and the batch is published. VFX logs receipt before owner filtering and verifies the current loaded batch. Rejections log their reason. CreateVisual is unchanged: it clones the ingredient template or uses its existing fallback. Copies are sanitized before entering IngredientVisuals: geometry/appearance only, no tags/attributes, anchored and noncollidable/nontouchable/nonqueryable. They tween from the accepted position to IngredientSlot1/2/3 WorldCFrames, with the legacy BlendVisualOrigin offsets retained when the slot set is incomplete (see BLENDER_VISUAL_TUNING.md) and survive LOADING/READY at zero progress. Start/reset/owner changes/detachment clear only the copies recorded as owned by that BlendVFX binding and cancel their tweens. Unrelated authored IngredientVisuals children are preserved. A fallback folder is removed only if it is empty. Reattachment restores loaded copies from the snapshot.

## Confirmed liquid presentation

The user confirmed the current SERVER Play hierarchy contains Blender.Liquid [Model] and its anchored Liquid [Part]. The earlier absent-hierarchy report came from an older Studio/runtime state; that investigation is resolved and no further hierarchy probe is needed.

Discovery selects that exact authored Blender.Liquid.Liquid Part first. Existing fallback paths and late-arrival handling remain defensive compatibility only. No geometry is created, destroyed, reparented, resized, or moved.

Original Color and finished Transparency are weakly cached per part across reattachment. Empty and zero-progress liquid is hidden, including BLENDING at progress zero. For normalized authoritative progress p, transparency is:

```text
T = 1 + (authoredFinishedTransparency - 1) * p
```

At p=1 the exact cached endpoint is assigned. For an authored finish of 0.2, 0/1/25/50/75/100 percent progress yields 1/0.992/0.8/0.6/0.4/0.2 transparency. The authored endpoint is preserved even if it is 1. Reset restores original Color and hides the part without overwriting its cached finished value. Size/CFrame never change.

Canonical color is the published BlendColor while developing and Result.Color on completion. Both come from BlendService's single existing ingredient BlendColor mean; the same Result.Color colors the dispensed cup.

## Active versus paused particles

Emitters are collected recursively beneath BlendVisualOrigin, but only ParticleEmitters whose names start with `Puff` are managed. This supports Puff1/Puff2/Puff3/Puff4 and additional puff variants without hardcoding exact names. No redundant container or tag is needed.

BLENDING persists while the turbine stops, so it is not an activity signal. Particles now activate only when authoritative progress increases. A single pending timer uses the latest increase timestamp. After **0.35 seconds** without another increase it disables and clears the cloud; it reschedules for the remaining grace time if progress advanced meanwhile. The next increase resumes particles. Completion/reset/owner change/detachment disables immediately and cancels the timer. No RPM/progress is calculated by VFX. Liquid holds its development during pauses.

## Temporary Studio logs

All diagnostics are gated by IsStudio. Representative single-plot sequence:

```text
[BlendVFX] bound plot=Plot1
[BlendVFX] bound blender path=Workspace.Plots.Plot1.Blender
[BlendVFX] child name=Liquid class=Model
... one line per direct child ...
[BlendVFX] IngredientVisuals found=true
[BlendVFX] BlendVisualOrigin found=true
[BlendVFX] liquid container direct=true
[BlendVFX] liquid nested part=true
[BlendVFX] liquid descendant candidates=1
[BlendVFX] liquid found=true path=Workspace.Plots.Plot1.Blender.Liquid.Liquid
[BlendVFX] liquid anchored=true archivable=true
[BlendVFX] emitters found=4
[BlendService] ingredient observer connected observers=1
[BlendVFX] ObserveIngredientAccepted connected=true
[BlendVFX] reset
[BlendService] accepted notify ingredient=Ice observers=1
[BlendVFX] accepted ingredient=Ice
[BlendVFX] visual source found=true
[BlendVFX] visual created=BlendIngredientVisual
[BlendVFX] blend active progress=1
... stop; 0.35 seconds since last progress increase ...
[BlendVFX] blend visual idle
... resume; next progress increase ...
[BlendVFX] blend active progress=2
[BlendVFX] complete
... dispense/reset ...
[BlendVFX] reset
```

Actual child/property values and observer counts reflect the server's instances. Missing liquid prints false/zero/<none>. Arrival/removal logs liquid hierarchy changed and a discovery summary. Active/resume logs contain positive progress and appear only on transitions. State BLENDING at zero progress does not activate presentation. Progress updates do not log every frame. Dispensing/reset logs one reset transition.

## Validation

Run python tests/run_state_tests.py --luau <executable> --vfx-only. Tests use real BlendService/BlendVFX and physical BlenderInput code with simulated engine signals, copied batch-table event payloads, and controlled timers. They cover accepted copies, stale notifications, optional hierarchies, late liquid arrival, grace/pause/resume, completion/reset, and cleanup. They do not prove the cause of the user's Edit/Play hierarchy difference or verify graphics/replication.

Current targeted result: 82 assertions passed, including the real CreateVisual template selection with multipart appearance preservation, owned-only cleanup, numeric tokens and copied-table regression, linear transparency checkpoints, and the 0.35-second pause/resume timer. All 45 source files compiled; touched runtime typecheck, StyLua, Rojo build, and whitespace checks passed. Full-suite validation still reaches the existing stash assertion expecting 4.4-stud displays.

Studio verification remaining: throw one and then multiple ingredients into the real InputZone; verify arrival, appearance, offset spacing and preblend visibility. Spin partially, stop longer than 0.35 seconds, resume, complete, and dispense. Confirm liquid development/canonical cup color and cloud coverage in the actual camera view. Repeat/reset during arrival and blending. The server hierarchy is already confirmed; rendered appearance, physics timing, and replication are not tested by the mock boundary.
