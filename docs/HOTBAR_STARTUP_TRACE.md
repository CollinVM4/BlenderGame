# Mobile hotbar startup investigation

Device acceptance and the live v1540 cause remain open. This change adds narrow,
read-only checkpoints to the existing admin chat diagnostic. Sprint Pass 2 stays
paused. It preserves the production layout, serialization, retry budgets and
Backpack handoff behavior.

## Source and asset evidence

The Windows tree started clean at `686638b`, after `5806fb6`. It contains the four
post-5806 patches and their startup/handoff changes: hidden prepared bar, admin
chat command, render-entry counter, serialized renders and three initial retries.
The controller inspected here is the local source identified in the handoff;
the published v1540 script was not independently retrieved from Studio.

`default.project.json` mounts `Framewisp_Hotbar.prepared.rbxmx`. Its nine authored
slots evaluate to 104 x 104 design pixels with float32 Vector2 rounding, ratio 1.
Each Label uses FredokaOne, TextSize 9, icon size 0.75 x 0.75 and icon Y position
0.394230783. Number minima initially come from TextSize: 15 for slot 1, 14 for
slot 7 and 13 for the other slots. Framewisp can change text size before ownership;
the phone checkpoint records the actual minimum passed to TextService.

The sizing loop visits all nine bindings, including eight unoccupied slots when
only Ice Gun exists. Unoccupied Labels retain authored preview text; their Number
labels are also measured. Slot fit rejection is restricted to occupied bindings.
The test loader now imports the authored anchors and font families instead of
using defaults for them.

The inspected resize path has no explicit Luau wait. Its exits report missing
layout/parent, zero or insufficient host bounds, an occupied slot that cannot
fit, scroll/target mismatch, or layout ready. Normal errors propagate to the
render pcall, which reports an error and restores native access. The delayed
geometry recovery also calls resize directly, so a checkpoint alone does not
prove a render is in flight; use the counters and flight flag together.

The growth loop could theoretically fail to advance for some non-square ratios
when capped multiplication/division rounds inconsistently. The mounted ratio-1
export does not reproduce that condition. No growth-loop change was made.

[Roblox's TextService declaration](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/TextService.yaml)
does not tag GetTextSize as yielding; GetTextBoundsAsync is explicitly documented
as yielding. Neither the old status nor the experiments below establish a live
GetTextSize suspension, font-loading fault, or engine exception.

## Reproduction and guard experiment

`startup-trace` mounts the shipped export with a pre-plot Ice Gun at 390 x 844 and
844 x 390, both already present and arriving after initial layout. Vector2 results
use float32 rounding for these cases. All four cases hand off without rotation,
timers or admin commands. Tool selection, nine-slot canvas/swipe with slot 1
equipped, minimum tap targets and native fallback remain usable in the double.
The expected bar targets without action-control obstruction are 223.44 x 93 and
483.54 x 64; their slot bands are 89 and 60 pixels after the scrollbar.

The harness does not execute Framewisp's embedded LocalScripts or Roblox's glyph
rasterizer, native Backpack renderer or physical touch routing. Passing it does
not reproduce or disprove the phone failure.

A controlled one-call suspension was injected separately at the Ice Gun Label,
occupied Number 1, and unoccupied Number 2:

- With serialization: entries=1, returns=0, errors=0, flight=true, followup=true.
  Existing retries cannot advance layout. Native access remains available.
- An isolated in-memory copy with the guard removed allows a later render to
  hand off while the first remains suspended. Resuming the first completes it.
  This establishes the guard's effect under the injected condition only.
- With production serialization retained, resuming the measurement permits a
  normal handoff. An injected Number exception produces errors=1, flight=false,
  the exact failing checkpoint, and native fallback.

The guard-removal experiment is test-only. There is no shipped bypass setting.
Cause-specific regression coverage must follow once a live cause is established.

## Phone evidence to collect

Collin handles Studio and phone QA. Sync the changed controller, publish once,
and use the same published build for fresh portrait and landscape joins as
Eatandpoop. No new instances, attributes or Studio configuration are required.
The existing admin authorization and `;hotbardebug` command are retained.

On a failing pre-plot join, run **`;hotbardebug`** twice several seconds apart,
before rotating or using `hide`. Keep both complete `[Hotbar]` / `[Layout]`
reports. The read command does not reconcile layout or write Backpack state.

- `entries`, `returns`, `errors` distinguish render entry, normal return (including
  early fallback/pending returns), and caught exception. A return is not proof of
  a usable layout; check `layout ready` and the visible bars.
- `flight` means the render pcall is still running; `followup` means its guard has
  held another request; `queued` means a deferred render is scheduled.
- `age` is seconds since this controller session started; `flightAge` measures
  the current render. The checkpoint age measures time since the last boundary.
  Place version and current orientation are included.
- `[Layout]` identifies before/after host bounds, touch controls, bar assignment,
  slot growth, each Label/Number text call, canvas, measured-scroll check and
  reveal. It carries the binding index, occupancy, ratio, width/cap, actual font
  and minimum, wrapping bounds, text and returned text bounds when available.
  `before` with increasing age and unchanged entries/returns narrows the stalled
  operation. A changing report demonstrates progress instead.

Reports are emitted only on the existing admin request. No per-slot console spam,
extra retry timer or automatic Backpack disable was added.

Acceptance remains repeated fresh joins in both orientations in one build, with
early and late Tools: custom hotbar usable without commands/rotation, native bar
visually absent after handoff, slot 9 reachable by swipe with slot 1 equipped,
and native access when custom UI is unavailable. API false alone does not prove
the native pixels are absent.

## Validation

- Baseline focused hotbar suite passed before editing.
- `python -B tests/run_hotbar_tests.py --luau .validation-tools/luau.exe --case startup-trace`: passed.
- Full focused hotbar suite, including existing keyboard/controller contracts: passed.
- Roblox-aware Luau LSP typecheck with fresh Rojo sourcemap: passed.
- StyLua on changed Luau files and `git diff --check`: passed.
- Rojo 7.7 build: passed, temporary output `BlenderGame-hotbar-checkpoints.rbxlx`.

The Aftman shim could not locate its home in the sandbox. Validation used the
already-installed Rojo binary directly; no installation or permission change was
needed. Studio and physical-device acceptance were not run.
