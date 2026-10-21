# Tutorial purchase alerts

`TutorialAlertState` owns session-only latching and clearing for Jump 1, then
Stun-Bat tier 1. Costs come from `Constants/Upgrades` at index 2. Reaching a
threshold latches its beat even if cash later falls; purchasing its target clears
it permanently. Both beats update before priority selection, so buying Jump can
activate an already-latched Bat beat immediately. Tutorial completion suppresses
all further alerts for this client session. No persistence or remotes are added.

`TutorialAlertController` reads replicated tutorial, cash and purchased-level
attributes and subscribes to Upgrades open/close notifications. It shows the
menu arrow while closed and the active purchase arrow while open. The existing
affordability badge remains independent. There are no polling loops.

## Required authored UI

The checked-in `new_export102126v2.rbxmx` contains all three arrows. Framewisp
strips the Figma `_pulse` suffix on export; the exported names are the binding
contract. Import the v2 export as-is for visual acceptance:

- Active Desktop content → `LeftMenu` → `Alert`, beside the Upgrades button.
- `Panel:Upgrades` / `Upgrades` → `Jump1Alert`, directly under the panel,
  positioned at the Jump card BUY.
- Same panel → `BatAlert`, directly under the panel, positioned at Stun-Bat BUY.

All three are `ImageLabel` instances exported with `Visible = true`. The controller
force-hides them on bind regardless of authored visibility; no Figma changes are
needed. The adapter accepts both tagged and exported names, while panel keys and
state outputs use `Jump1Alert` and `BatAlert`. Missing arrows
are a no-op; code never fabricates artwork. A preauthored `UIScale` is reused;
otherwise the controller creates only a `TutorialAlertScale` effect. While shown,
scale repeats 1 → 1.15 → 1 with Sine/InOut easing and 0.6 seconds per half-cycle.
Hiding or rebinding cancels the tween and restores scale 1. The normal
`UpgradesGui.Observe` lifecycle handles replacement arrows and Desktop roots.

## Validation

- `python tests/run_tutorial_alert_tests.py --luau <luau.exe>`: pure presentation
  state, independent of UI fixtures and authoritative gameplay suites.
- `python tests/run_tutorial_alert_export_tests.py --luau <luau.exe>`: real v2
  exported paths/classes/visibility, state-to-panel keys and tagged-name fallback.
- `python tests/run_upgrade_ui_tests.py --luau <luau.exe>`: existing upgrade/badge
  contracts plus arrow visibility, pulse lifecycle and authored-arrow reimport,
  with both early and delayed UI initialization.
- `python tests/run_framewisp_menu_tests.py --luau <luau.exe>`: existing menu routing.
- `python tests/run_state_tests.py --luau <luau.exe> --suite tutorial --suite tutorial-hints --suite tutorial-targets --suite tutorial-beam-stability`.

Studio smoke: earn the Jump threshold without buying it, open/close Upgrades,
spend below the threshold, then buy Jump. Reach or already hold the Bat threshold,
open Upgrades and buy Bat. Verify only the correct arrow pulses and the existing
badge behaves as before. Complete the tutorial with an active beat and verify
arrows stay hidden. Reimport the authored UI during an active beat and verify the
replacement arrow resumes while the retired arrow stops. CLI doubles cannot
validate rendered placement, native tween appearance, or replication timing.
