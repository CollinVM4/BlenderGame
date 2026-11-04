# Muncher roll presentation pass — 2026-11-04

Implementation and focused automation are complete. Device acceptance is pending;
this report does not establish that the phone hitch is resolved.

Changed files:

- `src/client/UI/MuncherEffects.luau`: cached reels, bounded content queue, pure
  movement helpers, separate roll reset and view cleanup.
- `tests/muncher_presentation.spec.luau`: extended the existing fake-Instance
  presentation harness and replaced its obsolete full-pool/destructive-reset
  expectations with the fixed-slot contract.
- `docs/muncher-roll-performance.md`: this report.

## Local-tree gates

All requested implementation locations still match the supplied paths. Before this
change, `Effects.Bind(model, playerGui)` returned animate/restore functions;
restore destroyed the GUI/carrier and cleared reels. Roll start constructed the
authored DisplayScreen SurfaceGui and one Frame/ImageLabel/preview per pool entry
per reel. `ReelStop(index)` remains `ChewSeconds * (0.76 + (index - 1) * 0.09)`;
`ChewSeconds` remains 1.65. Pool sizes are 12, 11, 18, 16.

`IngredientViewport.Create(image: ImageLabel, id: string, silhouette: boolean?)`
returns an idempotent cleanup function, or nil for unsupported IDs/missing models.
Its ViewportFrame is a sibling of the ImageLabel under the symbol Frame.
`ScrapbookArtwork.Ingredients` remains empty. No helper change was needed.

`GameplayAudioController.Init` already creates/preloads templates for nonempty
Muncher sound IDs using `ContentProvider:PreloadAsync`; `PlayMuncher` clones the
template. The configured ReelStop ID is empty and therefore silent. Audio code,
IDs and configuration are unchanged. Server, vacuum, pools, artwork, output,
controller calling convention and unrelated systems are unchanged.

## Resulting contract and counts

Bind creates 37 persistent GUI instances: one SurfaceGui, three windows, three
outlines, fifteen slot Frames and fifteen ImageLabels. It creates no previews.
`SurfaceGui.Enabled = false` stops rendering between rolls. Only external cleanup
destroys the cached structure; roll reset disposes previews, restores artwork,
stops the loop and destroys the carrier/light. Insert's sequence guard is retained.

Each reel has five slots, initially Y = -2, -1, 0, 1, 2 and indices N, 1, 2, 3, 4
(modulo N). Distance uses the original speed/deceleration formula. A slot reaching
Y >= 2 subtracts five per wrap; its pool index subtracts five modulo N, equivalent
to placing it immediately before the previous top entry. Multiple wraps in a
skipped frame are supported. Only changed contents enter the deduplicated queue.

Queue processing creates at most two previews per Bind per animation tick, with
locked outputs first, currently visible symbols next, the entering boundary next,
then hidden positions in ascending Y order. Unready slots stay hidden. Spin
visibility is exactly ready content with -1 < Y < 1: at most two previews per reel,
six per view. Stops reuse the nearest slot at Y = 0 for the true output. Invalid
outputs warn once per Bind and retain the centered candidate. Stop times, cue
paths, tint/tween, outline, glow, wobble and busy jitter remain intact.

The following are code-derived counts, verified with the counted preview stub;
they are not profiler measurements. Structural counts exclude preview subtrees
and unchanged audio clones.

| Tier | Pool entries | Old roll-start structural instances | New structural instances | Old new previews/model clones | New previews/model clones in start tick |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1 | 12 | 81 | 2 | 36 | <= 2 |
| 2 | 11 | 75 | 2 | 33 | <= 2 |
| 3 | 18 | 117 | 2 | 54 | <= 2 |
| 4 | 16 | 105 | 2 | 48 | <= 2 |

Each real preview adds a ViewportFrame, WorldModel, Camera and its cloned model
subtree. Thus old total new instances are `9 + 15*N + C(3*N)`, where `C(k)` is
the instance count of k cloned model subtrees. New start-tick total is
`2 + 3*k + C(k)`, with k <= 2. Structural roll initialization itself creates
only the carrier/light; queued work runs later in that animation call. A fully
assigned roll holds at most fifteen previews instead of 33–54.

## Automated validation

The existing harness drives the actual Bind with fake Instances and a counted
Viewport.Create boundary. It does not render Roblox 3D or measure device frames.

| Requested case | Result |
| --- | --- |
| Fixed structure | PASS: three windows, fifteen Frames/ImageLabels, retained identities across five rolls |
| Start budget and initialization | PASS: <= 2 preview creations every tick; start creates only carrier/light plus two stub previews; fifteen contents complete in eight fixed-time ticks; visible positions first |
| Wrap/order invariant | PASS: sequential indices and unit spacing for sizes 1, 2, 4, 11, 12, 16, 18, including exact boundaries and multiple-wrap jumps |
| Spin visibility | PASS: readiness and strict (-1, 1) range, <= 2 visible per reel |
| Output stops | PASS: every real candidate in all four tiers for Win/Lose/Push; single centered output, staggered cues, final result sound/tint; malformed-output fallback |
| Tier reuse | PASS: tiers 3, 1, 3, 4, 2 reuse the same GUI/slots and obey the start budget |
| Cleanup | PASS: per-roll preview disposal, interruption, repeated external cleanup, no retained GUI/previews, no queued work after cleanup; each stored preview cleanup called once |
| Existing focused suites | PASS: muncher-rewards, muncher-vacuum, muncher, gameplay-audio, gameplay-sfx |

Commands run from the repository root:

```powershell
python tests/run_state_tests.py --luau .validation-tools/luau.exe --suite muncher-presentation
python tests/run_state_tests.py --luau .validation-tools/luau.exe --suite muncher-rewards --suite muncher-vacuum --suite muncher --suite gameplay-audio --suite gameplay-sfx
.validation-tools/stylua.exe --check src/client/UI/MuncherEffects.luau tests/muncher_presentation.spec.luau
.validation-tools/luau-lsp.exe analyze --platform roblox --sourcemap sourcemap.json --definitions .validation-tools/globalTypes.d.luau src/client/UI/MuncherEffects.luau
& 'C:\Users\Collin Van Meter\.aftman\tool-storage\rojo-rbx\rojo\7.7.0\rojo.exe' build default.project.json --output .validation.rbxlx
```

All commands pass. The Luau spec compiles/executes through the existing injected
harness; production-module typechecking reports no diagnostics. The LSP prints
its usual watched-file registration warning. The `rojo` Aftman shim initially
failed with “Home directory could not be found”; invoking the installed 7.7.0
binary directly built successfully. No unrelated failing suite was encountered.
Broad unrelated regression suites were not run.

## Studio/device acceptance — pending

Build produced: `.validation.rbxlx`, then preserved at
`C:\Users\Collin Van Meter\AppData\Local\Temp\BlenderGame-muncher-roll.rbxlx`
to keep the tracked validation artifact out of the diff. Project BlenderGame,
Rojo 7.7.0. Device tested:
none. No Studio or phone playtest was performed. No authored asset/setup change is
required; DisplayScreen is now validated at Bind time.

1. First Tier 3 roll on the lowest-spec phone: NOT RUN. Verify immediate icon
   presentation, initial blank duration, frame hitch and frame rate. Also profile
   joining/Bind: it now creates 37 GUI instances but zero model previews; no claim
   is made that first-join work is hitch-free.
2. At least five consecutive rolls including a tier change: NOT RUN on-device.
   Verify visual equivalence, speed curve, approximately 1.25/1.40/1.55-second
   stops, final icons and tint. Automation covers state/contracts only.
3. Interrupt through walk-away, respawn and plot removal, then roll again: NOT RUN
   in Studio. Verify no stale SurfaceGui, frozen reel or orphan preview.

These acceptance checks remain necessary before calling the performance fix
accepted. In particular, the two-preview budget intentionally permits hidden
unready slots; automated results do not establish the requested maximum blank
duration on a phone.
