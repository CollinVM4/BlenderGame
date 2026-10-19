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
    WidthStuds = 7,
    HeightStuds = 1.4,
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
- Touch targets remain `UDim2.fromOffset`, at least 44 pixels equivalent on a real
  device at interaction range. Ingredient/smoothie targets are 80×80; dispenser
  targets are 220×80. `TouchCenterY` is a fraction of the visual canvas height.
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

For padded pickup prompts, use the stud-sized visual frame plus the explicit
pixel-sized transparent `TouchTarget`. Decorative labels are inactive. Keep the
active input rectangle minimal; never add a full-canvas transparent button behind
the decorative rows. `BillboardGui.Active` remains enabled as the native input
gate. The engine must verify that empty parts of the frame do not swallow taps or
block Throw; the CLI double cannot prove native GUI hit-testing.
See Roblox's [BillboardGui input and stud-sizing reference](https://create.roblox.com/docs/reference/engine/classes/BillboardGui).

## Implemented sizing candidates

These are the **implemented values, awaiting Collin's Studio tuning/sign-off**.
They are not claimed to be visually approved. The starting conversion for sizes
not explicitly proposed is `round(pixels / 37.5, 1)`, using the requested
35–40 px/stud reference. Actual projection depends on viewport, FOV and distance.

| Type / source | Previous frame (px) | Implemented frame (studs) | Cull (studs) |
|---|---:|---:|---:|
| Shared interaction prompt | 300×56 | 7.0×1.4 | 25 |
| Stash interaction prompt | 300×56 | 7.0×1.4 | 30 |
| Customer action prompt | 220×44 | 5.9×1.2 | 25, or authored interaction distance |
| Dispenser touch visual | 300×80 | 7.0×2.1 | 25, or authored interaction distance |
| Ingredient card, keyboard/gamepad | 320×142 | 8.5×3.8 | 25 |
| Ingredient card, touch | 320×184 | 8.5×4.9 | 25 |
| Smoothie card | 460×194 | 12.3×5.2 | 25 |
| Generic world text / landmark | 300×56 default | 8.0×2.0 default | 60 default, finite authored override |
| Muncher purchase | 340×64 | 9.1×1.7 | 40 |
| Muncher FEED ME / BUSY hint (replaces feed prompt/status) | No prior hint | 5.5 x 1.4 | 25 |
| Muncher three-reel roll (SurfaceGui) | 6.6 x 3.2 stud billboard | Authored DisplayScreen Front face, 100 PixelsPerStud | N/A |
| Regular customer dialogue | 300×112 | 7.0×2.6 | 45; existing taken-order state allows 56.25 |
| Special customer dialogue + name | 270×84 | 7.2×2.2 | 45; existing taken-order state allows 56.25 |
| Customer bubble before dialogue styling | 270×56 | 7.2×1.5 | 45 |
| Customer result / D-grade result | 300×32 / 300×54 | 8.0×0.9 / 8.0×1.4 | 30 |
| Blender ingredient count | 240×72 | 6.4×1.9 | 40 |
| Blender status | 380×80 | 10.1×2.1 | 40 |
| Blender initial guidance | 323×68 | 8.0×1.7 | 40 |
| Lucky Block label | 160×22 | 4.0×0.8 | 45 |
| Stash expansion purchase | 340×64 | 6.0×1.4 | 30 |
| Stash stored value | 180×44 | 4.8×1.2 | 35 |
| Carried ingredient value | 180×44 | 4.8×1.2 | 35 |
| Farm growing/ready/purchase | 340×64 | 9.1×1.7 | 35 |
| Farm planting display | 340×100 | 9.1×2.7 | 35 |
| Stash ripeness | 120×24 | 3.2×0.6 | 35 |
| Plot claim/join label | 180×32 | 4.8×0.9 | 60 |
| Plot identity including portraits/actions | 280×200 | 7.5×5.3 | 60 |
| JackedNoob hit / response | 320×58 | 5.0×1.5 | 30 |
| Lock-base state | 240×90 | 6.4×2.4 | 35 |

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
child pixel touch targets remain legal. It is a conservative source lint rather
than a complete Luau type analyzer.

The requested legacy prompt runners currently reproduce baseline blockers:
ingredient expects “Fresh” instead of current “Unripe”; interaction fails
“stash store retains key and action”; mobile reaches a missing InputBegan fixture
signal in CarryInputController; smoothie source bundling produces a malformed
escape sequence. Ripeness presentation also reproduces a baseline missing
`Color3` fixture global. These are isolated presentation failures; production
gameplay code was not changed to satisfy them.

Validation on 2026-10-19:

| Check | Result |
|---|---|
| Shared billboard unit contracts + repository sizing lint | PASS |
| World text and controller | PASS |
| Blender status and client distance presentation | PASS |
| Farm presentation | PASS |
| Muncher, JackedNoob hit, Lucky Block, customer result, plot identity | PASS (5/5 isolated presentation suites) |
| StyLua on the Luau files changed in this pass | PASS |
| Roblox-aware focused typecheck of changed modules excluding CustomerService | PASS |
| CustomerService and dependencies typecheck | FAIL: existing CustomerRequests DisplayText schema and CustomerService evaluation/grade diagnostics; no new diagnostics compared with isolated HEAD |
| Rojo 7.7 sourcemap and full place build | PASS |
| Ingredient, interaction, mobile and smoothie prompt runners | FAIL: same baseline blockers described above |
| Ripeness presentation runner | FAIL: same baseline Color3 fixture blocker described above |
| Studio/device screenshots and Collin sign-off | PENDING |

The constructor audit covers 17 current source files, including the newer Muncher
hearts view. Pickup presenters delegate frame creation to the shared interaction
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
