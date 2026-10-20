# Mobile tap, world text and Index coverage pass

Code is implemented; Studio acceptance is pending. Mocked tests do not establish that native taps work.

## Changes

- `InteractionPromptPresentation` creates a separate active input BillboardGui only for padded touch. The inactive visual holds all text. The input billboard holds only a transparent full-quad active button, on the same Adornee.
- Input dimensions are visual studs times target reference pixels divided by caller canvas pixels. Ingredient uses 320 x 184, smoothie 460 x 194, dispenser 300 x 80. The 112 x 112 ingredient target is 3.57 x 3.59 studs after the text bump; smoothie is about 3.60 x 3.58. The dispenser's 260 x 96 target is 7.28 x 3.024 studs.
- Input offset and visibility follow the visual's properties, including caller SizeOffset and mobile contact-plane lift. Register checks the input billboard; existing finger claims, rejection reasons, native hold API, release/cancel/focus handling remain. Cleanup removes both billboards. Desktop/gamepad retain the existing input path.
- Audited every ApplyBillboard call site. World text sizes grow approximately 20%; reference row layouts and MaxDistance values stay unchanged. Exact sizes are in BILLBOARD_CONVENTION.md. Non-text Muncher SurfaceGui reels stay authored.
- ScrapbookPreviews covers all 53 canonical catalog ingredients. Scrapbook validation prints missing/extra IDs on failure. ScrapbookArtwork remains unchanged. Asset setup and the 37 newly covered IDs awaiting live verification are in SCRAPBOOK_PREVIEW_COVERAGE.md.

## Validation

Passed: interaction input/view and customer-only checks; ingredient, full mobile, smoothie, Scrapbook, billboard/lint, world text/controller, blender status/distance, farm, Muncher, customer result, plot identity, Lucky Block, stash and JackedNoob presentation; discovery and smoothie-dispense state checks; StyLua; Rojo 7.7 build/sourcemap.

Roblox-aware Luau LSP analysis passes for all changed modules excluding CustomerService. Including it produces 25 diagnostics identical to isolated HEAD: CustomerRequests DisplayText schema errors and CustomerService optional Evaluation / grade union errors. No new type diagnostics.

Baseline failures isolated without unrelated production changes:

- Full interaction runner reaches old expectations that Start Day is enabled/custom. The feature is already retired. Isolated HEAD DayButton reproduces the same failure; the original HEAD full runner fails earlier on old stash expectations. Current customer-only and view-only runs pass.
- ingredient-hold: `unset asset is inert with an equipped ingredient`.
- customer-order-text: `SETUP: unlock dialogue recipes`.
- ripeness-presentation: missing fixture `Color3.fromRGB`.
- All three latter suites reproduce the same failure on a separate HEAD checkout.

Prompt fixtures now locate sibling input billboards and emit property-change signals for layout/visibility synchronization. Updated stale prompt text/value/size expectations, dispenser gameplay registration fixture, processed mouse-input fixture, and customer plot-session fixture to match current APIs. No production gameplay changes were made for these repairs.

## Required Studio gate (not performed)

A Studio process is open, but this session has no callable Studio/native automation surface. Perform these tests with touch emulation or a touch device before accepting Fix 1:

1. Tap the TAP row for ingredient pickup, smoothie pickup and dispenser; verify the authoritative action happens once. Include clustered items, camera tilt, tiny/large ingredients and viewport rotation.
2. While carrying near the prompt, tap outside the input target and use Throw; the inactive visual quad must not consume the gesture. Confirm both native target hit and outside-target pass-through; CLI input delivery doubles cannot prove either.
3. Use a nonzero HoldDuration prompt. Hold to completion, release early, cancel touch, lose focus, hide/remove the prompt while holding, and try a second finger. Verify begin/complete/cancel through the native prompt API and no duplicate actions.
4. Inspect all world-text types at close, intended read and far distances, including long names and customer/blender states. Check alignment, wrapping, contact-plane lift and unchanged distance culling.
5. Run docs/studio/ScrapbookPreviewAudit.luau during Play. Place missing canonical assets from existing ingredient prefabs and inspect locked silhouettes and discovered models for every card. Record its actual missing list; repository coverage cannot prove Studio asset presence.

Record device/emulation profile, viewport, FOV, read distances, results and screenshots here. No Studio result or visual sign-off is claimed.
