# Dispenser interaction at maximum normal zoom

Small follow-up on `fix/customer-prompt-distance`; no merge or publish.

The repository's live smoothie interaction is created by `DispenseButton` for
every `DispenseButton`-tagged fixture across all plots. It creates `DispensePrompt`
on the resolved part and uses the authored `DispenserTextOrigin`. The provided
Studio hierarchy (`Workspace.Plots.<Plot>.Dispenser.ProximityPrompt`) is not
serialized in the Rojo project; inspect that instance in Play mode to confirm
it is the same interaction. No authored hierarchy or unrelated prompts are changed.

## Distance checks and changes

- Before: `WorldUtil.Prompt` supplied a 10-stud character activation radius;
  `InteractionPromptPresentation` independently culled its billboard at 25 studs
  from the camera. Both visual and separate mobile hit-target billboards culled.
- Now: the dispenser alone overrides `MaxActivationDistance` to
  `Economy.InteractionDistance` (12 studs), matching the existing authoritative
  `BlendService.Dispense` range. The global prompt default remains 10 studs.
- Dispenser billboards use the customer draw budget:
  `LocalPlayer.CameraMaxZoomDistance + 56.25`, updating with live zoom settings.
  At a 128-stud normal zoom limit this is 184.25 studs. The mobile hit target
  inherits the same limit automatically. Normal camera zoom moves the camera,
  so dispensing at maximum zoom requires no character range beyond 12 studs.

`BlendService.Dispense` continues to check completed batch state, membership,
actor/session authorization, server-measured distance, live character/gameplay
eligibility through `WorldUtil.Near`, inventory capacity, transaction ownership,
and duplicate/reentrant dispensing. The gameplay request adapter retains its
0.15-second throttle. No client distance or camera position is trusted by the
server. Input, sound feedback, prompt LOS/exclusivity, readiness, and reset logic
are unchanged. There is no new remote dispatch path.

## Validation

Passed:

- `python tests/run_interaction_prompt_tests.py --luau .validation-tools/luau.exe --customer-only`
  covers customer regressions plus dispenser keyboard E/gamepad/touch labels,
  native hold forwarding, max-zoom draw configuration, live zoom changes,
  ownership dispatch, duplicate-view prevention, and consistent activation
  configuration on two plot fixtures.
- `python tests/run_mobile_prompt_tests.py --luau .validation-tools/luau.exe --prompt-only`
  passes 63 checks, including matching visual/hit-target draw limits and native
  hold dispatch into the existing server callback.
- `python tests/run_state_tests.py --luau .validation-tools/luau.exe --suite smoothie-dispense`
  passes 18 behavioral checks: distant/foreign rejection, readiness, capacity,
  retry without losing the batch, and one-time/reentrant-safe grants.
- Roblox-aware Luau LSP typecheck of both changed runtime files, fresh Rojo
  sourcemap/build, StyLua on all four changed Luau files, and whitespace checks.

The incoming mobile prompt fixture failed because its fake Player lacked
`CameraMaxZoomDistance`, required by the preceding customer change. The shared
prompt fixture now supplies 128, and the mobile runner includes the real Economy
configuration. No remaining failures in these focused suites.

Changed runtime files: `DispenseButton.luau` and
`InteractionPromptPresentation.luau`. Supporting changes are the shared prompt
and mobile specs, their two runners, and this report.

## Studio-only verification

No new setup is required for existing tagged dispensers/origins. Live rendering,
native keyboard/gamepad activation, and physical-device touch cannot be simulated
by these engine doubles. With a completed batch, test each plot at maximum normal
zoom: stand at 10–12 studs, verify E / TAP / gamepad labels, dispense once, and
confirm no duplicate prompt or grant. Step beyond 12 studs and verify no dispense;
check capacity/readiness feedback, touch-target placement, and customer/other plot
prompts. Confirm the supplied authored ProximityPrompt path maps to the runtime
tagged interaction and that no legacy authored prompt duplicates it. Repeat on
real mobile and console hardware.
