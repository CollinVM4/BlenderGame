# World billboard convention

All world-space `BillboardGui` frames must be configured with
`WorldBillboardStyle.ApplyBillboard`. No direct `BillboardGui.Size` assignments
are allowed outside that implementation, including assignments through aliases,
constants, or conditional expressions.

The implementation lives in `src/shared/WorldBillboardStyle.luau`, available to
both server and client through `ReplicatedStorage.Shared.WorldBillboardStyle`.
`src/client/UI/WorldBillboardStyle.luau` re-exports it for existing client imports.
Rojo already maps `src/shared`; no additional Studio instances are required.

```luau
local Style = require(game:GetService("ReplicatedStorage").Shared.WorldBillboardStyle)
Style.ApplyBillboard(gui, {
    WidthStuds = 8.4,
    HeightStuds = 1.7,
    MaxDistance = 25,
    AlwaysOnTop = false,
})
Style.ApplyText(label, { TextScaled = true })
```

- Frame dimensions are positive, finite **studs**, supplied as `WidthStuds` and
  `HeightStuds`. `ApplyBillboard` uses `UDim2.fromScale`; BillboardGui Scale units
  are world studs. The retired pixel `Width`/`Height` fields are not accepted.
- `MaxDistance` is mandatory, positive and finite. Choose by purpose:
  interactions about 25, plot displays 40–60, transient feedback about 30 studs.
  Missing/invalid fields throw in Studio, warn and disable the view in production.
- Prefer `TextScaled = true` with proportional row containers. `ApplyText` retains
  its fixed `TextSize` default for compatibility; any new fixed-size world text
  needs a documented per-type reason. Do not impose a large minimum pixel font
  size that makes distant text overflow its shrinking world frame.
- Use proportional sizes/positions for visual children. Pixel offsets remain
  appropriate for transparent touch targets and small outlines.
- Touch target reference sizes are 112 x 112 pixels for ingredient/smoothie and
  260 x 96 for dispenser/generic padded touch. Convert each dimension to studs
  against the caller's visual canvas, then fill a separate active input billboard
  with a `UDim2.fromScale(1, 1)` button. `TouchCenterY` is a fraction of the visual
  canvas height. Projected target size varies with camera distance; verify at least
  44px equivalent at interaction range on a real device.
- New work explicitly passes `AlwaysOnTop = false`. Enable it only for a gameplay
  reason documented at the call site. This migration preserves existing overlay
  and occlusion behavior; the helper retains its legacy true default and false
  `ResetOnSpawn` default. Direct former callers explicitly preserve their old flags.
- Position in studs with `StudsOffset` / `StudsOffsetWorldSpace`. Preserve authored
  origins and content. Dimensionless `SizeOffset` must be normalized against the
  new frame, never divided by its now-zero pixel offsets.
- Use static sizes per type/state. No new global loops or per-frame resizing.
  The existing ingredient contact-plane positioning uses rendered canvas height
  to normalize its existing lift; it never changes the frame size.
- This is presentation only. Do not change gameplay, economy, replication,
  interaction requests, activation ranges, content, or show/hide state logic.
  Camera-distance culling is the intentional visibility change.
- `AnnouncementBanner` and other `ScreenGui` UI are outside this convention;
  their pixel sizes remain appropriate. Authored `SurfaceGui` stand signs are
  also distinct from BillboardGui frames.

Decorative billboards must explicitly set `BillboardGui.Active = false` and
`Active = false` on their decorative GuiObject children so they do not consume
world clicks/taps or block Throw. `ApplyBillboard` and `ApplyText` leave input
policy to callers; neither helper sets `Active`.

For padded touch prompts, the visual billboard and all decorative labels stay
inactive. A sibling `InteractionPromptTouchInput` billboard shares the Adornee,
contains only the full-quad `TouchTarget`, and remains active. Its stud dimensions
are visual studs * target reference pixels / visual canvas pixels. Its SizeOffset
normalizes the visual offset and TAP row center against its own dimensions;
property changes keep it aligned with mobile lift and subsequent caller offsets.
Registration and visibility checks use this input billboard; cleanup destroys both.
Desktop/gamepad retain their existing Action button input path.
The engine must verify that taps on the target work while nearby taps outside the
input quad pass through. CLI doubles cannot prove native GUI hit-testing.

## Implemented sizing candidates

These are the **implemented values, awaiting Collin's Studio tuning/sign-off**.
They are not claimed to be visually approved. This pass increases world text frames by approximately 20%, preserving the
reference canvases and MaxDistance values. The original conversion for sizes
not explicitly proposed is `round(pixels / 37.5, 1)`, using the requested
35–40 px/stud reference. Actual projection depends on viewport, FOV and distance.

| Type / source | Previous frame (px) | Implemented frame (studs) | Cull (studs) |
|---|---:|---:|---:|
| Shared interaction prompt | 300×56 | 8.4 x 1.7 | 25 |
| Stash interaction prompt | 300×56 | 8.4 x 1.7 | 30 |
| Customer action prompt | 220×44 | 7.1 x 1.45 | 25, or authored interaction distance |
| Dispenser touch visual | 300×80 | 8.4 x 2.52 | 25, or authored interaction distance |
| Ingredient card, keyboard/gamepad | 320×142 | 10.2 x 4.6 | 60 |
| Ingredient card, touch | 320×184 | 10.2 x 5.9 | 60 |
| Smoothie card | 460×194 | 14.8 x 6.2 | 60 |
| Generic world text / landmark | 300×56 default | 9.6 x 2.4 default | 60 default, finite authored override |
| Muncher purchase | 340×64 | 10.9 x 2.0 | 40 |
| Muncher FEED ME / BUSY hint (replaces feed prompt/status) | No prior hint | 6.6 x 1.7 | 25 |
| Muncher three-reel roll (SurfaceGui) | 6.6 x 3.2 stud billboard | Authored DisplayScreen Front face, 100 PixelsPerStud | N/A |
| Regular customer dialogue | 300×112 | 8.4 x 3.12 | 45; existing taken-order state allows 56.25 |
| Special customer dialogue + name | 270×84 | 8.64 x 2.64 | 45; existing taken-order state allows 56.25 |
| Customer bubble before dialogue styling | 270×56 | 8.64 x 1.8 | 45 |
| Customer result / D-grade result | 300×32 / 300×54 | 9.6 x 1.08 / 9.6 x 1.68 | 30 |
| Blender ingredient count | 240×72 | 7.68 x 2.28 | 40 |
| Blender status | 380×80 | 12.12 x 2.52 | 40 |
| Blender initial guidance | 323×68 | 9.6 x 2.04 | 40 |
| Lucky Block label | 160×22 | 4.8 x 0.96 | 45 |
| Stash expansion purchase | 340×64 | 7.2 x 1.68 | 30 |
| Stash stored value | 180×44 | 5.76 x 1.44 | 35 |
| Carried ingredient value | 180×44 | 7.2 x 1.8 | 100 |
| Farm growing/ready/purchase | 340×64 | 10.92 x 2.04 | 35 |
| Farm planting display | 340×100 | 10.92 x 3.24 | 35 |
| Stash ripeness | 120×24 | 3.84 x 0.72 | 35 |
| Plot claim/join label | 180×32 | 5.76 x 1.08 | 60 |
| Plot identity including portraits/actions | 280×200 | 9.0 x 6.36 | 60 |
| JackedNoob hit / response | 320×58 | 6.0 x 1.8 | 30 |
| Lock-base state | 240×90 | 7.68 x 2.88 | 35 |

The current working tree has no Muncher progress-meter or buff-countdown
BillboardGui; its server presentation module only resolves markers. Their former
176×80 / proposed 4.5×2.0 meter is not recreated by this migration.

The ingredient, smoothie and plot identity cards contain multiple rows and
portraits, so the proposed compact single-line prompt/identity dimensions would
compress their existing layout. Their frames instead use the measured conversion
above. Stash interaction uses the shared prompt proportions; expansion uses the
requested compact purchase dimensions.

## Layout repairs in this pass

Pixel child rows otherwise remain screen-sized even inside a shrinking frame.
Ingredient/smoothie rows, purchase rows, farm text/padding, customer name/result
rows, plot portraits/actions, Muncher hearts and ripeness/radial geometry now use
proportional layout. Ingredient/smoothie font constraints allow text to shrink
below the old 12px floor and grow with the frame. Other migrated world labels opt
into TextScaled after applying existing dialogue styling.

Customer result anchoring formerly divided by `Size.Y.Offset`, which becomes zero
with stud frames. The existing drop is normalized using the reference stud
conversion; reward rows remain centered at the existing body attachment. The
blender client distance controller also retains proportional text instead of
overriding it back to fixed pixels. No overflow is claimed visually resolved
until the Studio checks below are completed.

## Automated validation

Run these separately from authoritative gameplay suites:

```text
python tests/run_billboard_tests.py --luau <luau.exe>
python tests/run_world_text_tests.py --luau <luau.exe>
python tests/run_blender_status_tests.py --luau <luau.exe>
python tests/run_farm_presentation_tests.py --luau <luau.exe>
python tests/run_state_tests.py --luau <luau.exe> --suite muncher-presentation --suite jacked-noob-hit-presentation --suite lucky-block-view --suite customer-result --suite plot-identity
python tests/run_ingredient_prompt_tests.py --luau <luau.exe>
python tests/run_interaction_prompt_tests.py --luau <luau.exe>
python tests/run_mobile_prompt_tests.py --luau <luau.exe>
python tests/run_smoothie_prompt_tests.py --luau <luau.exe>
```

`run_billboard_tests.py` owns stud sizing, invalid fields/retired pixel fields,
Studio errors vs production warnings, explicit culling, preserved visibility
flags, TextScaled opt-in/default behavior, and the repository sizing lint.
The lint forbids all direct billboard Size writes outside the shared module,
including offset sizes hidden behind constants, typed parameters and aliases;
child pixel sizes remain legal; padded prompts now use stud-sized input billboards. It is a conservative source lint rather
than a complete Luau type analyzer.

Validation on 2026-10-20 for the mobile tap + world text + preview coverage pass:

| Check | Result |
|---|---|
| Interaction input/view and customer-only runner | PASS |
| Ingredient, mobile (full runner), smoothie and Scrapbook runners | PASS |
| Billboard convention lint, world text, blender status and farm runners | PASS |
| Muncher, customer result, plot identity, Lucky Block, stash and JackedNoob presentation | PASS |
| Discovery and smoothie-dispense authoritative suites | PASS |
| StyLua on changed Luau files | PASS |
| Roblox-aware changed-module typecheck excluding CustomerService | PASS |
| Changed-module typecheck including CustomerService | 25 existing errors, identical to isolated HEAD; no new diagnostics |
| Rojo 7.7 sourcemap and full place build | PASS |
| Full interaction runner | Existing retired Start Day expectations fail; reproduced with HEAD DayButton in isolation |
| Ingredient-hold, customer-order-text, ripeness-presentation | Existing failures reproduced on isolated HEAD; see pass report |
| Studio touch/emulation, world-text screenshots and sign-off | PENDING; required gate remains open |

See [implementation, validation limitations and Studio gate](MOBILE_TAP_VALIDATION.md)
and [preview asset coverage / canonical IDs awaiting verification](SCRAPBOOK_PREVIEW_COVERAGE.md).

The constructor audit covers all current ApplyBillboard call sites, including
the separate padded-touch input billboard. Pickup presenters delegate frame creation to the shared interaction
presenter; ripeness delegates to `RipenessPresentation.ConfigureIndicator`, which
uses the same shared style. No BillboardGui pixel-size assignment remains in `src`.

## Required Studio acceptance — pending

Collin must capture **before and after**, for every table row/type, at close,
intended-read and far zoom on desktop and one real mobile device. Use a copy of
the pre-migration place/branch for before shots. Record device, viewport, FOV,
camera distance and final tuned dimensions beside each screenshot. Do not merge
on the basis of CLI layout doubles alone.

1. Zoom through the full camera range. Frames, labels, portraits, hearts and
   ripeness geometry must shrink proportionally with the world.
2. At interaction range (10 studs for pickups) and intended plot read distances,
   verify text wrapping, long ingredient/customer/player names, all customer
   result grades, plot teammate columns, farm rows and purchase labels.
3. Just beyond each configured MaxDistance, verify engine culling. Check both
   customer order states and authored distance overrides.
4. On a real phone, verify ingredient and smoothie targets remain at least 44px
   equivalent, hold/release still works, clustered items activate once, and
   dispenser padding stays usable. Tap blank billboard areas and press Throw
   while carrying beside prompts: neither may be swallowed by the visual frame.
5. Preserve all strings, visibility state transitions, origins, AlwaysOnTop and
   ResetOnSpawn policy. Verify streamed/recreated views retain the convention.
6. Update this table with final tuned values and screenshot links; record
   Collin's sign-off. No Studio screenshots, real-device result or sign-off has
   been produced by this automated pass.

## Muncher casino follow-up

The Muncher feed prompt/status and fading hearts are replaced by the hint/reels
listed above. These dimensions await before/after Studio and real-device review.
See [casino rates, SFX setup, evidence gaps and acceptance](MUNCHER_CASINO_POLISH.md).
