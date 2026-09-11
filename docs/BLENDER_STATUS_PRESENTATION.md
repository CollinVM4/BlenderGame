# Blender status presentation

`BlenderStatusPresentation` is a server-created cosmetic component bound to each
`PlayerPlot`, following `OwnerUserId` through `TycoonService.GetOwner`. The created
BillboardGuis replicate to all observers. Ownership changes disconnect the old
player, restore the new player's current state, and clear on release/leave.
Tag removal or removal from Workspace destroys only the component's own UI.

Authority remains in `BlendService`'s private per-player batches:

- Accepted count: `#batch.Ingredients`, published as `BlendIngredientCount` after
  successful consumption/insertion in `TryInput`. No physical clones are counted.
- Capacity: `Economy.MaxIngredients`, currently **3**, shared with BlendService.
- State: `batch.State`, published as `BlendState`; `COMPLETE` means ready to dispense.
- Successful dispense publishes `DISPENSED`, then defers `Reset`, which publishes
  `EMPTY` and count zero. `HasSmoothie` describes cup ownership, not batch readiness.

No new attributes, events, remotes, or authority APIs are added. The component
subscribes directly to the two existing attribute signals, including initial state
restoration. It never calls a gameplay mutation. Existing mechanics allow partial
batches to blend: active/completed states take precedence over loading guidance.

| State | Count presentation | Turbine prompt |
| --- | --- | --- |
| Empty / reset | `0 / 3` | LOAD INGREDIENTS TO BLEND! |
| Loading | `1 / 3` or `2 / 3` | LOAD INGREDIENTS TO BLEND! |
| Ready, full | `3 / 3`, green, second line LOADING COMPLETE! | SPIN TO BLEND! |
| Blending | Retains accepted count | BLENDING... |
| Complete | Retains accepted count | READY TO DISPENSE! |
| Dispensed | Retains accepted count until Reset | LOAD INGREDIENTS TO BLEND! |

## Studio setup

Create the origins **before Play**, once per assigned plot. Recommended hierarchy:

```text
Workspace
  Plots
    Plot1                         [Model; existing PlayerPlot tag]
      Blender                     [existing Model]
        Body                      [existing stationary BasePart]
          IngredientCountOrigin   [Attachment]
      Turbine                     [existing Model, anywhere inside Plot1]
        Support                   [stationary BasePart]
          TurbinePromptOrigin     [Attachment]
```

`Body`, `Turbine`, and `Support` are illustrative existing geometry names; only
`Blender`, `IngredientCountOrigin`, and `TurbinePromptOrigin` are looked up by name.
The count origin must be inside Blender; the prompt origin must be inside the same
plot. A direct `Blender/IngredientCountOrigin` is preferred when already authored;
otherwise the resolver accepts a unique nested Attachment, allowing proper parenting
to a physical part. The existing direct `Workspace/Blender` plot layout also works.
Direct marker children take precedence; duplicate nested markers warn and skip that
display. Missing/invalid markers skip only the affected display. Restart Play after
adding origins during a session.

Both origins also accept invisible anchored BaseParts (disable CanCollide, CanTouch,
and CanQuery). No new tags, ObjectValues, BillboardGuis, or TextLabels need authoring.
The existing gameplay `GetReference` remains BasePart-only; these cosmetic markers
use a separate local resolver.

Place IngredientCountOrigin about **2–3 studs above the blender rim**, centered over
the jar. Place TurbinePromptOrigin **2–3 studs above the stationary turbine support**,
offset toward the player's approach so it does not overlap the count/order text.
Avoid attaching it to spinning blades. Adjust Attachment.Position in Studio.

Runtime creates `IngredientCountDisplay/Status` and `TurbineStatusDisplay/Status`
under the respective origins. Text uses transparent backgrounds, GothamBold,
black outline at 0.25 transparency, and AlwaysOnTop, matching customer order styling.

## Tuning and validation

At the top of `src/server/Components/BlenderStatusPresentation.luau`:

- `TEXT_SIZE = 24` pixels; `MAX_DISTANCE = 80` studs.
- `COUNT_SIZE = 240 x 72`, `PROMPT_SIZE = 380 x 80` pixels.
- `COUNT_OFFSET` / `PROMPT_OFFSET` default to `(0, 0, 0)` world-space studs.
- `WHITE` / `FULL_COLOR` control normal and full-count colors.

Client camera-distance presentation is handled separately by
`src/client/Controllers/BlenderStatusDistanceController.luau`, initialized by the
client bootstrap. Its `PROFILES` constants are:

| Display | BandDistances | Scales | FadeDistance | HideDistance |
| --- | --- | --- | --- | --- |
| IngredientCountDisplay | 15, 35 | 1.0, 0.72, 0.55 | 50 | 60 |
| TurbineStatusDisplay | 12, 25 | 1.0, 0.70, 0.55 | 30 | 40 |

Distances are studs from the current camera to the Attachment.WorldPosition or
BasePart.Position. Scale stays fixed within three bands and is written only when
the band changes. `BAND_HYSTERESIS = 1` requires moving more than one stud beyond
a boundary to shrink, or more than one stud below it to grow. Initial registration
selects a band directly; large camera jumps can cross multiple bands in one update.
The final scale persists through the fade range. Smoothstep interpolation fades
both text and outline between FadeDistance and HideDistance each frame, without
interpolating size. One client-created `CameraDistanceScale` UIScale
under each centered Status label scales the existing 24px text; TextScaled remains
false. The client sets BillboardGui.MaxDistance to HideDistance (60/40 studs),
overriding the server's 80-stud default locally, and hides text at that boundary.
No instances are rebuilt per frame. Existing and late-replicating displays bind,
stream-out removes the scale, and camera replacements are read each render frame.
All plots are adjusted for each observer's own camera; ownership and text remain
entirely server-controlled. No Studio hierarchy changes or new remotes are needed.

Distance validation: 47 client assertions plus 28 server presentation assertions
pass. Focused controller Roblox-aware typecheck, StyLua, and Rojo build pass.
Client-bootstrap-inclusive analysis encounters existing StashPromptController
type errors at lines 36/39. Studio rendering/distance verification remains required.

Automated checks: 28 presentation assertions and 115 existing blender VFX assertions
pass. StyLua, Rojo build, and focused Roblox-aware component typecheck pass.
The full state suite stops in untouched movement coverage at `base stamina full at
110`; bootstrap-inclusive Roblox-aware analysis reports the existing CustomerService
line 337 possible nil `DisplayText`. No gameplay files were changed to address these.

Studio playtest still required: load three real ingredients, confirm rejection does
not increment the counter, spin, complete, dispense, and reset. With two clients,
check independent plots and owner release/reassignment. Confirm placement/readability
at normal gameplay distance; CLI tests simulate signals and cannot verify rendering
or engine network replication.
