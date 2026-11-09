# Customer action visibility at normal maximum zoom

Implemented on `fix/customer-prompt-distance`; no Studio setup is required.

## Trace and cause

`CustomerService` creates `TakeOrderPrompt` and `ServePrompt` on each customer root
through `WorldUtil.Prompt`. Both are Custom ProximityPrompts, with a 10-stud native
activation radius and `RequiresLineOfSight = false`. Take Order is enabled until
the order is revealed; Serve is enabled after reveal when the customer is ready.
They are successive actions, not two simultaneously enabled prompts.

`InteractionPromptController` receives native `PromptShown`/`PromptHidden`, resolves
`ServePromptOrigin`, filters plot membership, and creates/removes one shared
`InteractionPromptPresentation` billboard. All devices use this path: keyboard
uses the prompt key (normally E), gamepad uses its GamepadKeyCode, and touch uses
TAP plus `InputHoldBegin`/`InputHoldEnd`. There is no separate customer touch or
console distance gate.

The premature draw gate was `InteractionPromptDisplay.MaxDistance = 25`, measured
from the camera. Order bubbles instead use 45 studs, rising to 56.25 for revealed
regular orders. `CustomerOrderController` gates order visibility by session and
reveal state; it adds no camera-distance check. Thus the action billboard could
be culled even while the engine prompt was eligible and the order remained visible.

The repository does not override normal `CameraMaxZoomDistance`; the live Player
property includes the place's configuration. Turbine/film cameras are separate
scriptable modes and are outside this change's normal-camera guarantee.

## Targeted change

Only customer action billboards receive a finite draw budget of the local player's
`CameraMaxZoomDistance + 56.25` (or a larger explicit presentation override). The
existing largest order radius supplies space for the nearby customer and rig/focus
offset. The budget updates when the normal zoom limit changes without recreating
the view. For example, a 128-stud zoom limit yields 184.25 studs of draw distance.
Order bubbles, appearance, anchor placement, and unrelated prompt limits are unchanged.

Roblox documents [native prompt eligibility](https://create.roblox.com/docs/ui/proximity-prompts)
as character-distance based, while [BillboardGui.MaxDistance](https://create.roblox.com/docs/reference/engine/classes/BillboardGui)
is camera-distance based. No built-in distance workaround or remote input path
is needed: native events still control the view's lifetime and keyboard/gamepad
input. Native LOS, exclusivity, and enabled state are unchanged. Both server
`TakeOrder` and `Serve` retain `WorldUtil.Near(..., Economy.InteractionDistance)`
(12 studs), actor/session validation, and their existing state checks. Increasing
the billboard budget grants no activation range.

## Validation

- `run_interaction_prompt_tests.py --customer-only`: passes, covering both actions
  and keyboard/gamepad/touch labels, appearance, ownership, streaming, zoom budget,
  live zoom configuration, native hiding, and unchanged unrelated draw limits.
  The new zoom-budget assertion fails against the original runtime module.
- Roblox-aware `luau-lsp analyze` of the changed runtime module with a fresh Rojo
  sourcemap and Roblox definitions: passes.
- StyLua on both changed Luau files and Rojo build: pass.
- `customer-queue`, `customer-serve-anywhere`, and `customer-validation`: fail
  identically on unchanged HEAD. Respectively: missing dependency call in
  `CustomerService.CalculateOrderPayout` line 803; fixture cannot spawn a customer;
  legacy assertion `one Red ingredient suffices despite extras`. No unrelated
  production fixes were made. Queue distance/reveal rejection checks execute before
  its payout failure, but these failures prevent claiming complete gameplay acceptance.

These tests use engine doubles; live rendering and device interaction remain
unverified. In Studio, stand within 10 studs, zoom to the Player's normal maximum,
and check Take Order, then Serve with a cup, on desktop and device emulators.
Confirm E/TAP/gamepad labels, successful actions, no duplicate view, native hiding
on leaving range, server rejection outside 12 studs, unchanged order bubble range,
and unchanged nearby dispenser/plot prompts. Verify on real mobile/console too.
