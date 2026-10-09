# Mobile pickup and dispensing

The tap repair keeps lower-third ingredient positioning, transparent 80 x 80 px
ingredient targets, 220 x 80 px dispenser targets, and dedicated mobile Throw.
There are no new authored assets, gameplay remotes, distance or gameplay changes.

## Tap regression and repair

Pass 2 added a second hit-test after Roblox had already delivered InputBegan
to a real GUI button. MobilePromptTouchTargets.Center used WorldToViewportPoint
and compared its result to InputObject.Position without converting GUI insets.
Roblox documents that viewport projection ignores the inset while touch position
accounts for it. A valid button hit could therefore miss the synthetic rectangle
before InputHoldBegin, and the helper still claimed the finger on that miss.
An inset-aware event regression fails against the pre-fix helper and passes now.

The earlier tests generated their touch positions from the same helper formula,
so they did not exercise this mismatch. The helper also accepted only Touch,
removing the original clickable MouseButton1 path for touch UI/emulator input.

The repaired helper uses the actual transparent button InputBegan source,
checks view/source validity, claims the finger once, and calls InputHoldBegin.
There is no viewport/screen conversion or second hit-test in dispatch. Roblox
handles screen insets, billboard sizing/offsets, clipping and native UI stacking.
Clustered prompts use the native button source; custom nearest-center selection
has been removed. A finger can still activate at most one prompt through removal.
Clickable mouse input follows the pre-Pass-2 callback; nonclickable mouse input
and unrelated input types are rejected. The passive label is inactive and the
transparent button has a higher ZIndex than the label.

Matching InputEnded or Cancel releases the hold. View teardown and focus loss
also release safely. Holds are never ended immediately after Begin, and no timer
or arbitrary delay was added. Generated pickup/dispenser prompts retain their
native instant HoldDuration of zero. Desktop E/gamepad paths remain unchanged.

## Position and targets

Visible rotated bounds exclude invisible multipart pivot roots. The mobile TAP
center starts at center minus min(0.30 * height, 2.5 studs), clamped above the
visible bottom by min(0.15 studs, height / 2). SizeOffset aligns the input row.
Camera-based lift leaves its 34px visible row 2px above the projected bottom.
Geometry, distances and the existing shown-view updates remain unchanged.
Bounds remain a contact-plane proxy; slopes and buried geometry need playtests.

| Interaction | Before Pass 2 | Current mobile target | Visible text |
| --- | --- | --- | --- |
| Ingredient | 320 x 34 px row | 80 x 80 px | Compact and unchanged |
| Dispenser | 300 x 56 px row | 220 x 80 px | Compact and unchanged |

## Development diagnostics

Disabled by default; Studio-only on client and server. During a Play session,
enable from the server Command Bar:

    workspace:SetAttribute("DebugMobilePrompts", true)

Output stages use [MobilePrompt]: SHOWN, REGISTERED, TOUCH RECEIVED, TARGET
SELECTED, HOLD BEGIN, TRIGGERED, and ACTION DISPATCHED. Client Triggered and
server callbacks are labeled separately. ACTION DISPATCHED confirms the existing
service was called; it does not imply the server accepted a full/not-ready batch.
Reject logs identify disabled/hidden views, wrong input type, claimed fingers,
invalid source/ownership, disabled prompt service, or an already-held prompt.
Touch receipt includes input coordinates and actual GUI position/size.
There is no per-frame logging. Disable afterward:

    workspace:SetAttribute("DebugMobilePrompts", false)

Changed runtime files: MobilePromptTouchTargets, InteractionPromptPresentation,
IngredientPickupPromptController, InteractionPromptController, and the shared
MobilePromptDebug module. IngredientPickup and DispenseButton have diagnostic
calls only; their inventory/dispense dispatch and authorization logic are intact.
IngredientPickupPromptPresentation, IngredientPickupPromptStyle and
CarryInputController were inspected and preserved during this repair.

## Automated validation

    python tests/run_mobile_prompt_tests.py --luau <luau.exe>
    python tests/run_mobile_control_layout_tests.py --luau <luau.exe>
    python tests/run_state_tests.py --luau <luau.exe> --suite carry-input --suite carry --suite smoothie-dispense --suite stash --suite stash-prompts

Mobile prompt/input: 68 assertions pass. Mobile control/layout: 129 pass.
Carry, carry-input, smoothie-dispense, stash and stash-prompts all pass.
The prompt suite covers the inset regression, padding, rapid taps, clustered
single dispatch, stale views, identity/ownership, cancellation, clickable emulator
input, customer callback preservation, pickup/dispense without Throw, and debug
gating. It forwards mocked Triggered to real pickup and dispense components.
Actual ready/capacity/ownership/range/reentrancy/replay behavior is covered by
the independent authoritative smoothie-dispense suite.

The native GUI hit-test and ProximityPrompt engine are NOT emulated. CLI
InputHoldBegin doubles fire Triggered explicitly. These tests prove callback
dispatch and lifecycle, not that a physical touch reaches the rendered rectangle.
The layout fixture is independent of runtime activation and is used only for
existing positioning assertions. Changed runtime modules pass Roblox-aware
Luau LSP analysis with a fresh Rojo map; StyLua and Rojo 7.7 build pass.
The previously documented legacy prompt, smoothie fixture/payout and whole-src
typecheck failures are unrelated; no production changes were made for them.

## Required Studio/device acceptance

No Studio or physical-device execution was available to the repair agent.
Sync with Rojo, then enable diagnostics and use real touch or Device Emulator.

1. Walk out of range and back in to capture SHOWN and REGISTERED. Tap the center
   and invisible corner padding of ingredient TAP and a ready DISPENSE prompt.
   Require TOUCH RECEIVED -> TARGET SELECTED -> HOLD BEGIN -> client TRIGGERED
   -> server TRIGGERED -> server ACTION DISPATCHED, then inspect actual inventory.
2. If SHOWN/REGISTERED appear without TOUCH RECEIVED, inspect native GUI stacking,
   button bounds and CoreGui interception. Once input is received, there is no
   second coordinate gate. If HOLD BEGIN has no native TRIGGERED, inspect the
   logged HoldDuration, engine prompt visibility and matching release timing.
   If server dispatch appears without inventory transfer, inspect authoritative
   readiness, ownership/capacity and server feedback instead of bypassing checks.
3. Rapidly collect clustered ingredients with multiple fingers. Confirm a single
   ingredient per press, no stale targets after despawn/pickup, and no Throw.
4. Hold joystick/Sprint/Jump, swipe the camera, and use DISPENSE, STORE/TAKE and
   menu UI. Only the dedicated Throw button or console R2 should throw.
5. Test phone/tablet portrait and landscape, topbar/safe-area variations, multipart
   and rolling ingredients, steep camera angles, and sloped contact planes.
6. Fill inventory, press DISPENSE repeatedly, free a slot and retry. Require one
   smoothie per batch with preserved completed state on failure. Verify E,
   console prompts/R2, stash and customer interactions.

Coordinate sources: [InputObject.Position](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/InputObject.yaml),
[Camera projection](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/Camera.yaml).
Native button lifecycle follows [Roblox custom prompt example](https://create.roblox.com/docs/reference/engine/classes/ProximityPrompt).
