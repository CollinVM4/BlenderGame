# Tutorial objective visibility

Implemented on `feat/tutorial-objective-visibility`. No merge or publication.

The existing `TutorialGleamController` still consumes `TutorialPresentationState`
and `TutorialTargets`. The server assigns stages, stash slots, plot membership,
and customer references as before. Progression, rewards, readiness delays, hint
text retirement, and audio are unchanged by this pass.

World guidance now remains available for later active objectives rather than
retiring with first-order instructions. Upgrades continues to use its existing
UI alert presentation because that objective has no world target.

## Changed files

- `src/client/Controllers/TutorialGleamController.luau`: brighter yellow Highlights,
  a brief activation flash and subtle pulse, wider flowing navigation beams,
  marker ownership and cleanup, and throttled active/inactive updates. The outer
  navigation beam is 72% transparent to emphasize the traveling energy.
- `src/client/UI/TutorialObjectiveMarker.luau`: one local vertical beacon and
  bouncing downward triangle without a rectangular shaft or extra labels. Constant pixel sizing
  preserves readability; distance, field of view, and viewport height determine
  clearance above prompts. No input handlers, particles, or Lighting changes.
- `tests/tutorial_hints.spec.luau`: world-marker visibility, camera sizing,
  animation, transition/completion/respawn cleanup, and continued later guidance.
  This file already contained uncommitted user changes, which were preserved.
- `tests/tutorial_targets.spec.luau`: observable activation-flash/pulse behavior
  replaces expectations about the previous tween implementation.
- `tests/run_state_tests.py`: loads the new presentation module.
- This document.

The two navigation beams are reused while retargeting. There is one beacon/arrow
per active world objective, even when its authored geometry needs several
Highlights. Target loss immediately hides an invalid endpoint; streaming retries
resolve missing assets without waiting. Character removal, death, lost membership,
completion, and controller shutdown clear the owned effects. Authored attachments
are never destroyed. Active presentation updates at no more than 30 Hz; inactive
target discovery is limited to 10 Hz.

## Validation

Passed:

- Focused `tutorial-hints`, `tutorial-targets`, and `tutorial-beam-stability`
  presentation suites.
- Authoritative `tutorial` state suite, run separately from presentation.
- Roblox-aware Luau LSP typecheck of both changed runtime modules with a fresh
  Rojo sourcemap and installed Roblox definitions.
- StyLua check of both changed runtime modules and both changed Luau specs.
- Rojo build of `default.project.json`.
- Git whitespace check.

## Studio acceptance still required

No additional Studio authoring or setup is required: Rojo maps the new module
automatically. Rendering and device emulation have not been verified in Studio.

1. Play through claim, counter/order, stash, ladder/blender, turbine, dispenser,
   serving, next customer, market/jump, and farm purchase/plant/harvest. Include
   the recovery blending/dispensing stages. Confirm only the actual current
   objective is yellow, and its arrow, beacon, and flowing beam agree.
2. At maximum normal zoom, inspect bright/dark scenery and occluded targets on
   desktop, mobile portrait/landscape, and console. Check yellow contrast, arrow
   shape, prompt clearance, and unobstructed touch input.
3. Progress rapidly between pickup/throw objectives. Confirm immediate removal
   of previous Highlights/markers, a brief flash, and a smooth new entry.
4. Reset/die, switch plots, stream targets out/back, and complete both tutorials.
   Confirm no stale or duplicate arrow/beacon survives and resumed guidance uses
   the current character and objective. Check existing tutorial audio.
