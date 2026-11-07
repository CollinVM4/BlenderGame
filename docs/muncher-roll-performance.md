# Muncher roll preview cache - 2026-11-07

This pass builds on the current checkout, including its existing uncommitted
Muncher screen-resolution and hint/controller work. The original scope reference
is main at `d3463c7fc46567b9a3b65e4e7f79fa3c0bfbdb94`. Server rewards,
audio configuration, timing and authored assets are unchanged.

## Implementation

- `src/client/UI/MuncherPreviewCache.luau`: one client-wide cache, **24 prepared
  previews total including leases**, **three copies per ingredient**, and one
  deduplicated idle work queue. Lease/release only attach or detach existing
  previews. Idle eviction selects released entries outside the desired working
  set; final presentation teardown disposes everything once.
- `src/client/UI/IngredientViewport.luau`: `Prepare(id, silhouette?)` returns
  `Attach(image)`, `Release()` and idempotent `Destroy()` operations. Preparation
  retains the existing sanitizer, uniform normalization, camera and resize
  framing. Existing `Create(image, id, silhouette?)` still returns cleanup or nil.
- `src/client/UI/MuncherEffects.luau`: assignment chooses authored images, leased
  previews, then reusable fitted catalog-name labels. All content is immediately
  ready, including a completely cold cache. The three original stop deadlines
  reveal the replicated output exactly (1.254 / 1.4025 / 1.551 seconds).
  Five-slot wrap math, screen clipping, rarity, audio and result cues remain.
  Wrap/reset return leases, clear old images/text and retain prepared resources.
  Already-reset idle views skip repeated reset work.
- `src/client/Controllers/MuncherPresentationController.luau`: Heartbeat performs
  shared warming only near purchased, active Munchers and a living character,
  within the existing 36-stud presentation distance. Any bound processing/rolling
  view pauses preparation and eviction. Character removal disposes views; death
  cancels rolls; sequence/tier changes and view removal release ownership. Reel
  SurfaceGuis use explicit controller respawn cleanup instead of engine automatic
  destruction, so leases return before their slot trees are destroyed.

Warming schedules **at most one preparation per 0.1 seconds**, without catch-up
bursts. Recent tiers and outputs rank first. The highest-priority eight IDs form
an intentionally stable working set of up to three copies each, preventing a
large tier from continually evicting itself. The full catalog is never warmed
at startup. Requests are rebuilt from eligible views, so removed/distant views
and old sequences cannot execute stale jobs. Missing assets fall back to names
and can retry after five seconds. A full 24-preview working set takes at least
2.3 seconds of uninterrupted idle scheduling if the first build is immediate;
this is a scheduling estimate, not a measured loading time or frame-time bound.

## Focused validation

- `tests/muncher_presentation.spec.luau`: counted preparation/disposal boundary,
  cold/warm exact stops, consecutive-roll/wrap reuse, tier changes, duplicate
  symbols/multiple views, global/copy caps, released-only eviction, missing-asset
  retry, shared job budget, proximity gate, interruption, respawn, removal and
  opt-in single-summary timing. Active spins, including cold starts and final
  stops, perform zero preview preparations/builds and zero preview destroys.
  Geometry cloning is reachable only through preparation, outside the spin.
- `tests/run_state_tests.py`: includes the new cache in the existing harness.
- `tests/scrapbook_ui.spec.luau`: adds real renderer release/reattach coverage;
  existing creation, geometry, framing and silhouette checks still pass.
- `tests/fixtures/scrapbook_ui.luau`: fake reparenting now removes the old parent's
  child reference, matching Roblox when a prepared preview is released.

Commands (repository root):

```powershell
python tests/run_state_tests.py --luau .validation-tools/luau.exe --suite muncher-presentation
python tests/run_scrapbook_ui_tests.py --luau .validation-tools/luau.exe
.validation-tools/stylua.exe --check src/client/UI/MuncherEffects.luau src/client/UI/MuncherPreviewCache.luau src/client/UI/IngredientViewport.luau src/client/Controllers/MuncherPresentationController.luau tests/muncher_presentation.spec.luau tests/scrapbook_ui.spec.luau tests/fixtures/scrapbook_ui.luau
& 'C:\Users\Collin Van Meter\.aftman\tool-storage\rojo-rbx\rojo\7.7.0\rojo.exe' sourcemap default.project.json --output .validation-tools/muncher-sourcemap.json
.validation-tools/luau-lsp.exe analyze --platform roblox --sourcemap .validation-tools/muncher-sourcemap.json --definitions .validation-tools/globalTypes.d.luau src/client/UI/MuncherEffects.luau src/client/UI/MuncherPreviewCache.luau src/client/UI/IngredientViewport.luau src/client/Controllers/MuncherPresentationController.luau
& 'C:\Users\Collin Van Meter\.aftman\tool-storage\rojo-rbx\rojo\7.7.0\rojo.exe' build default.project.json --output .validation-tools/muncher-cache-validation.rbxlx
```

Both focused runners, StyLua, Roblox Luau typecheck and Rojo build pass. The LSP
emits its usual watched-file registration warning. No unrelated suites were run.
Generated validation files are removed after checking.

## Studio timing and pending acceptance

No asset/setup change is required. For optional timing, set the Workspace boolean
attribute `MuncherPresentationTiming` to true in Studio before a roll. Default is
off; non-Studio sessions never print timing summaries. Each completed/interrupted
roll prints one summary on reset, with per-roll preview builds/destroys/hits/
misses, worst RenderStepped delta (`worstFrame`), worst active reel callback CPU
duration (`worstUpdate`), and the client's maximum measured preparation duration
(`warmBuildMax`, including failed attempts). The frame delta can include work
outside this UI. Cache counters are client-wide; overlapping rolls share them.
No per-frame or per-build log spam is emitted.

**No comparable Studio/device runtime measurement has been taken in this pass.**
Synthetic harness timing is not a device measurement. Actual frame-time
improvement, warm-build cost, viewport attachment/rendering cost, and other
residual frame cost remain pending. One job is a scheduling cap, not a guarantee
that a single complex model will fit a frame budget. Record these summary values
and a comparable MicroProfiler capture for cold/warm rolls on the same device,
including nearby idle warming, consecutive rolls, tier changes, respawn and
multiple machines, before accepting the hitch improvement.
