# Blender vacuum assist

The optional server component changes loose ingredient assembly velocity only.
BlenderInput still detects overlap and calls BlendService.TryInput; BlendService
validates the plot, batch, registration and actual overlap before Consume removes
the private record and destroys the item. Throw/carry code is unchanged.

## Studio setup

The Rojo project maps scripts, not Workspace geometry. Author this in each plot:

```text
PlayerPlot
  Blender
    Body
    Blades
    InputZone                  [existing BlenderInput tag]
      VacuumTarget             [optional Attachment]
    VacuumZone                 [BlenderVacuum tag]
```

Tag the **VacuumZone BasePart itself** `BlenderVacuum`. Set Transparency=1,
Anchored=true, CanCollide=false, CanTouch=false, CanQuery=true. Use a block
roughly 4–6 studs tall above the opening, modestly wider than the hole. Its lower
edge should reach the opening. Keep the capture volume clear of solid body/rim
geometry. No world coordinates, generated geometry or appearance assumptions are
used. Select the invisible part in Studio Explorer to inspect its selection box.

TycoonService.GetReference(owner, "BlenderVacuum") resolves the unique tagged
BasePart in that owner's assigned plot, just like BlenderInput. Existing legacy
auto-tagging also recognizes an object **named BlenderVacuum** when no explicit
tag exists. A part named VacuumZone needs the tag. Missing, nonpart or duplicate
vacuum references disable the assist without affecting input setup. The existing
architecture supports one canonical input and vacuum per plot.

Target priority: direct `VacuumTarget` Attachment under InputZone, then under
VacuumZone, then InputZone's center plus its local UpVector times half its height
plus 0.5 studs. Put custom targets slightly above the ingestion zone, centered
over the actual opening, clear of solid geometry. Attachments should be parented
to a BasePart. Target Y is also the release plane; do not author it high above
the rim. Upright blenders are expected; downward steering follows world gravity.

## Physics and eligibility

One Heartbeat connection queries tagged, valid zones with GetPartsInPart and
deduplicates Resolve results. No Workspace descendant scan, teleport, per-item
connection, force instance, or ingestion call is added. Each frame recomputes
eligibility; leaving the volume, entering InputZone, passing below the target,
pickup, consumption, destruction or plot removal ends the assist. There is no
persistent force to clean up on reset. Physical collisions and gravity remain active.

Only IngredientService's private records qualify. Public unowned items must be
Claimable; owned items must match the plot owner, exactly as TryInput requires.
Characters, NPCs, tools, accessories, unregistered carry/stash/blender clones,
anchored parts and ingredients connected to external assemblies are excluded.
The existing Spawn API already assigns server network ownership.

**Existing carry throws and drops intentionally spawn public, claimable items.**
This feature does not assign ownership to those throws. Overlapping eligible
zones choose the nearest target, with lowest owner UserId breaking exact ties;
owned items can only choose their owner's zone. No ingredient receives two
steering updates in one frame.

Horizontal target error produces a desired centering velocity with a downward
bias. Exponential velocity blending becomes stronger nearer the opening in the
horizontal plane. Desired velocity and assisted acceleration are bounded.
Incoming velocities above MaxSpeed brake progressively rather than snapping to
the cap; gravity/collisions can also exceed that desired-speed limit.

All tuning is in `src/shared/Constants/BlenderVacuum.luau`:

| Constant | Default | Meaning |
| --- | ---: | --- |
| PullStrength | 7 | Near-center response per second |
| CenteringStrength | 6 | Horizontal velocity per stud of error |
| DownwardBias | 12 | Desired downward studs/second |
| MaxSpeed | 36 | Desired velocity magnitude cap |
| MaxAcceleration | 120 | Assisted velocity change per second |
| EdgeStrength | 0.3 | Fraction of pull at horizontal outer edge |
| TargetHeight | 0.5 | Fallback height above input top |
| MaxStep | 1/30 | Maximum steering timestep after hitches |

Zone bounds are the activation/release boundary; no extra activation radius or
outside-zone attraction is used. Set ServerStorage.DebugBlenderVacuum=true in
Studio for capture/release transition logs. Production visuals are unchanged.

## Validation

Run `python tests/run_blender_vacuum_tests.py --luau <luau.exe>`, plus existing
state, world and carry suites via `tests/run_state_tests.py`. The focused suite
uses real vacuum, ingredient, tycoon and blend modules with a fake engine
boundary; overlap lists are controlled fixtures, not a Roblox physics simulation.

Studio playtest is still required for feel: throw single and multipart ingredients
at the center and near each rim edge; try misses outside the zone, two simultaneous
items, pickup during attraction, reset and player departure. Test two adjacent
plots with overlapping zones and owned/public items. Verify the target and input
clear solid geometry and that large ingredients fit through the opening. Tune
zone size and pull together; collision geometry can still prevent ingestion.

Implementation validation: 636 vacuum assertions, 75 world ingredient assertions,
and 221 carry assertions pass. All 69 source files compile. Roblox-aware Luau LSP
analysis of changed production modules passes with the Rojo sourcemap and Roblox
definitions. StyLua and Rojo build pass. The full state suite stops at the existing
BlendVFX assertion `start clears copies and cancels arrival`; the same failure was
reproduced with committed HEAD sources. Studio physics playtesting was not run.
