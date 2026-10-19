# Muncher casino polish - provisional review

Implemented 2026-10-19. Current rates and approved Cheap-floor exception are recorded in [the retune review](MUNCHER_REWARD_RETUNE.md). Balance review and Studio/device feel verification remain pending. Rates are provisional inputs to Pass 3 telemetry.

## Behavior and boundaries

Feeding is throw -> vacuum -> `TryStartConversion(..., "WorldVacuum", ...)`. The component removes authored intake prompts and creates no feed prompt; `TryFeed`, the client prompt hooks, and the carried-input conversion branch are removed. Purchase pad behavior remains intact.

The existing world eligibility, capture thresholds, movement gate, registry reservation, immunity, lifecycle lock, output recovery, and settlement timing remain intact. Chew is still 1.65 seconds and spit cooldown 0.15 seconds. The server passes authoritative catalog input value into reward selection. PlayerHead uses the existing $5K fallback when needed and is never an output.

Busy intake needs an additional bounded mouth observation on the existing component update because normal attraction stops while busy. It uses the same registry/owner/team/immunity eligibility and line-of-sight checks, never applies forces or calls the conversion transaction, and projects only a rate-limited `BusyUntil` attribute. An item flashes once per arrival, rather than repeatedly while stationary. Direct internal conversion attempts rejected as busy project the same feedback. No new remote or global loop was added.

The local hint says **FEED ME** when purchased, revealed, idle, past spit cooldown, and in the viewer's plot session. It does not require carrying an item. Visitors/locked/revealing/busy machines hide it, except for a 0.3-second **BUSY...** flash after an eligible rejected arrival. A small horizontal jitter overlays the existing chew wobble without replacing its saved rest positions.

Three clipped vertical heart strips spin fast for about 0.957 seconds, decelerate, and stop left to right at **1.254 / 1.4025 / 1.551 seconds**. Spin colors use the input tier's configured output rarity palettes from `IngredientPickupPromptStyle.RarityStyles`; every stopped reel uses the predetermined actual output rarity. The output-colored mouth glow reaches full brightness at the final lock. Interruption removes the reels, glow/carrier and spin loop and restores artwork. Spit Highlight pop is retained. One-shot ticks/chord use independent spatial emitters so the chord can finish after the spit removes the roll carrier.

## Rates for Collin review

Superseded by [the non-blocking hint and fun-first retune review](MUNCHER_REWARD_RETUNE.md).
The current guardrail is 110%, with the approved sub-$1,053 Cheap lottery exemption,
99% Rock at floor, and 70% proportional upgrade shift. That review contains all
recomputed weights, EV, win/push/loss comparisons, worst-case degrade, and the
remaining mathematical conflicts. The former 95% policy and pending-exception
language below are historical validation notes, not current balance policy.

## SFX setup

No suitable casino clips were found among the configured pickup/throw/combat clips. Supply approved Roblox asset IDs in `src/shared/Constants/Muncher.luau`:

| Config field | Asset ID now | Purpose |
|---|---|---|
| `SpinSoundId` | `""` | Spin loop; stopped at final lock or interruption |
| `ReelStopSoundId` | `""` | One tick at each of three stops |
| `WinSoundId` | `""` | Final lock-in/win chord |

Empty IDs are inert and excluded from preload. No busy sound is configured. Audio uses `GameplayAudioController` templates and existing volume/rolloff settings. With the defaults the roll is intentionally silent; audible acceptance requires these IDs.

## Billboard sizing and Studio evidence - pending

The decorative hint uses `WorldBillboardStyle.ApplyBillboard` with explicit occlusion/culling. The roll uses an inactive, occluded `SurfaceGui` on the authored `DisplayScreen` BasePart, with `Face = Front`, `SizingMode = PixelsPerStud`, and `PixelsPerStud = 100`. Both use proportional child layout and TextScaled. The roll has no billboard distance culling.

| View | Before | Proposed after | MaxDistance |
|---|---|---|---:|
| Feed invitation | E/X/touch feed prompt; no FEED ME hint | FEED ME / brief BUSY..., 5.5 x 1.4 studs, 2.2 studs above MouthOrigin (InputZone fallback) | 25 |
| Chew | Three reels in 6.6 x 3.2 stud billboard | Three reels on authored DisplayScreen Front face, 100 PixelsPerStud | N/A |

These dimensions are implementation candidates, **not Studio-verified**. A Studio process exists, but this session exposes no `node_repl`/Windows automation runtime or Studio execution connector. No screenshots or physical-phone results have been produced.

| Capture | Before desktop / mobile | After desktop / mobile |
|---|---|---|
| FEED ME idle hint, teammate/visitor, busy flash | Pending / Pending | Pending / Pending |
| Cheap roll | Pending / Pending | Pending / Pending |
| Standard roll | Pending / Pending | Pending / Pending |
| Premium roll | Pending / Pending | Pending / Pending |
| High Roller roll | Pending / Pending | Pending / Pending |

Use a pre-change place for before captures. On desktop and a real phone, record device/viewport/FOV/distance, and capture close / intended plot read / far views. Verify hint culling beyond 25 studs and fixed roll orientation while orbiting/zooming, no E/X/touch feed affordance, actual-rarity final symbols, all stops before spit, configured sounds, and interrupted/streamed-away cleanup. Throw a second eligible item during Processing and failed-output Spitting: shake/BUSY must appear, the item remains intact, and the original reward remains unchanged. Verify visitors and immune outputs cannot trigger busy feedback.

For mobile, test carry -> aim -> native Throw button -> vacuum beside pickup billboards, tapping blank decorative space, with ingredient and weapon tools equipped as appropriate. The existing carry-input suite passes the native CAS ThrowHeld route and distinguishes touch from synthesized mouse input; physical vacuum integration covers real ThrowHeld-created objects. **This is not confirmation of native GUI hit-testing or the full loop on a real phone.** No throw-path problem was found in those automated checks; mobile acceptance remains pending.

Collin must approve the rates/constraint resolution and roll feel before merge. No approval is recorded.

## Validation and changed files

- Historical casino-pass reward validation used 95%. Current 110% validation and the approved Cheap-floor exemption are recorded in [the retune review](MUNCHER_REWARD_RETUNE.md).
- Cross-system conversion/vacuum: `muncher`, `muncher-vacuum` PASS.
- Client presentation/audio: `muncher-presentation`, `gameplay-audio` PASS, including empty-ID silence, configured clips, staggered lock colors and mid-spin cleanup.
- Throw dependency: `carry-input` PASS. No carry/input production file changed.
- Billboard convention lint and shared style contracts PASS.
- Roblox-aware luau-lsp analysis of the eight changed production modules with fresh Rojo sourcemap/Roblox definitions PASS.
- StyLua check of changed Luau files, Rojo 7.7 full place build, and focused whitespace check PASS.
- Studio/device visual acceptance and Collin balance approval PENDING.

Production files:

- `src/shared/Constants/Muncher.luau`: provisional base pools, interpolation ceilings, busy duration, empty SFX IDs.
- `src/server/Services/MuncherRewards.luau`: input-value-dependent effective weights and selection.
- `src/server/Services/MuncherService.luau`: sole physical feed entry, actual-value roll, InputTier projection, busy notification.
- `src/server/Services/MuncherVacuum.luau`: bounded observation of busy arrivals only; normal intake/forces unchanged.
- `src/server/Components/Muncher.luau`: remove prompt creation/wiring; project InputTier.
- `src/client/Controllers/MuncherPresentationController.luau`: eligible idle hint, busy flash, bounce-in; remove prompt hooks.
- `src/client/UI/MuncherEffects.luau`: three-reel lifecycle, rarity colors, timing, glow, jitter and audio cues.
- `src/client/Controllers/GameplayAudioController.luau`: optional slot templates and cancellable spatial spin.

Tests: `tests/muncher.spec.luau`, `tests/muncher_vacuum.spec.luau`, `tests/muncher_rewards.spec.luau`, `tests/muncher_presentation.spec.luau`, `tests/gameplay_audio.spec.luau`. Documentation: this file and the Muncher rows in `docs/BILLBOARD_CONVENTION.md`. Other existing/concurrent working-tree changes are outside this pass.

## Surface display and prompt input follow-up

Studio setup: each Muncher must contain an authored BasePart named `DisplayScreen`,
with its Front face oriented outward on the machine front. Author its position,
size, and aspect ratio in Studio. Runtime code does not create or resize the
screen. Place it outside `Visual` if it should remain still during the existing
artwork wobble. A missing or incorrectly typed part raises an error naming
`DisplayScreen` and the model before roll/glow creation; there is no fallback.
The configured density is 100 PixelsPerStud, pending visual tuning in Studio.
Clipped reel windows, rarity colors, tick/win timing, glow, wobble and spit pop
retain their existing behavior.

Padded mobile prompt billboards set `Active = false`; their explicit pixel
TouchTarget remains active. `MobilePromptTouchTargets` checks the live view and
button rather than requiring the billboard itself to be active. Desktop,
gamepad and unpadded touch retain the existing button path. No throw remote,
server logic, prompt visibility or distance setting changed.

Automated validation: `muncher-presentation` passes (49 assertions), as do these
focused runners (add `--luau <luau.exe>`):

- `python tests/run_interaction_prompt_tests.py --input-only` (30 assertions)
- `python tests/run_ingredient_prompt_tests.py --input-only` (66 assertions)
- `python tests/run_mobile_prompt_tests.py --prompt-only` (57 assertions)

Full runners reproduce existing baseline failures: interaction expects stash
STORE despite its test dispenser action override; ingredient expects stale
Fresh/value catalog text; mobile's legacy carry fixture lacks InputBegan and
expects the retired ThrowHeldMouse CAS binding. These failures were reproduced
with pre-change prompt modules/specs in a temporary copy. No unrelated production
behavior changed to satisfy them. Focused selectors leave default coverage intact.

Roblox-aware typecheck of the three changed UI modules, StyLua on changed Luau,
and a fresh Rojo build pass. Grep confirms no unconditional `gui.Active = true`
remains in prompt UI modules. Desktop clicking passes the native hold API test.

Studio and real-phone acceptance remain pending: this session has no callable
Windows automation/Studio execution tool or physical-device connection. In Studio,
author DisplayScreen, orbit/zoom during a roll, verify stops/SFX, and interrupt
or stream away during spin. Remove DisplayScreen to verify the named error.
On a real phone, carry beside another ingredient and repeatedly tap Throw with
the pickup card overlapping it; taps outside TouchTarget must reach Throw.
Also verify pickup tap/hold/release, desktop clicks/E and gamepad. No screenshots
or device verification are claimed.
