# Blender ready floor indicator

`BlenderReadyIndicator` is a presentation-only component registered by the server
bootstrap alongside `BlendProgressLights`. It binds `PlayerPlot` tags and resolves
the owner through `OwnerUserId` and `TycoonService.GetOwner`, like the lights.
Other players can see the world cue, but only that plot owner's state drives it.

Readiness is `BlendState == "COMPLETE"` and
`BlendProgress >= Economy.RequiredProgress` (currently **100**, not 1).
`READY` means ingredients are loaded and blending can begin; it is not dispensable.
The fifth progress light now shares this presentation predicate. Earlier milestone
lights are unchanged. No BlendService state, dispense authorization, or gameplay
rules were changed. Attribute signals update the disk immediately, including
DISPENSED/EMPTY/new-batch changes while progress still holds its previous value.

## Studio setup

For each existing tagged plot, author one marker:

```text
Plot [PlayerPlot tag]
+-- Blender
    +-- ReadyIndicatorOrigin
```

- Use an anchored BasePart with Transparency 1, CanCollide/CanTouch/CanQuery false,
  and CastShadow false. Put its **center at the floor surface**, near the dispenser
  where a six-stud circle will be visible and clear of blender geometry.
- Alternatively use an Attachment inside a blender BasePart and name it
  `ReadyIndicatorOrigin`; its WorldPosition defines the floor location. Nested
  markers are supported. Keep the name unique inside each blender.
- A legacy plot whose tagged root is itself named `Blender` is also supported.
- Marker rotation is ignored: the cylinder always lies horizontally. Its center
  is 0.1 studs above the marker, with a thickness of 0.15 studs and diameter 6.
- The generated `BlenderReadyFloorIndicator` is neon green, transparency 0.1 when
  active and 1 otherwise. It is anchored, non-colliding, non-touching, non-queryable,
  and casts no shadow. It has no interaction or gameplay authority.
- No pulse is used, so there are no tweens or background tasks to accumulate.
- Missing markers warn and skip the indicator without preventing lights/gameplay.
  Author markers before play; after adding one during play, remove/re-add the
  plot's PlayerPlot tag to bind it.

Ownership changes and player departure hide/rebind the indicator. Removing the
plot tag or removing the plot from Workspace disconnects listeners and destroys
the disk. Rebinding creates one disk. The generated disk is parented to its marker
so destruction of the authored hierarchy also removes its visual.

## Validation

Run `python tests/run_blender_ready_tests.py --luau <luau.exe>` for the independent
presentation suite. It executes the real indicator, light, and WorldUtil modules
against the shared Roblox test boundary. Coverage includes initial/partial/full
readiness, mismatched state/progress, dispense/reset/new batch, green inert geometry,
BasePart and Attachment placement, foreign owner isolation, reassignment/unowned
plots, departure, repeated transitions, tag removal/rebinding and Workspace exit.

37 focused assertions pass. Roblox-aware typecheck of src, StyLua on all touched
Luau files, Rojo build, and git diff --check pass. Typecheck retains an existing
LoadCharacterAppearance deprecation warning in CharacterPhysicsService.

Studio smoke test still required: view the circle from normal gameplay distance;
verify it lies flat without floor flicker or geometry occlusion; complete and
successfully dispense a batch; start another batch; repeat with two owned plots.
Check the fifth light and circle together. CLI tests cannot validate rendered
appearance, real transforms, or network replication. No Studio playtest was run.
