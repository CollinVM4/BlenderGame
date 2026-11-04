# Wing entry resets the fall peak

Implemented against HEAD `510c519` on 2026-11-04. This pass changes only:

- `src/server/Services/FallDamageService.luau`
- `tests/fall_damage.spec.luau`
- `tests/wings_flight.spec.luau`
- `docs/WINGS_BOOST_FALL_RESET.md`

Existing Hotbar, Ingredient, Muncher, shared Types, and associated test/document
working-tree changes were retained. No Studio configuration changes are required.

## Step-0 findings and implementation

All named functions remain at the supplied paths. WingsService exports them as
`Service.IsWingControlled`, `Service.SetJumpHeld`, `Service.ResetFallEpisode`,
`Service.ObserveFallLanding`, and `Service.ConsumeGlideLandingProtection`; its
local `step` is present. IsWingControlled requires a flight, Powered OR Gliding,
server-observed JumpHeld, and eligibility. The existing FallDamage Heartbeat
wing-ascent branch was present with not-supported, positive peak, positive Y
velocity, and wing-control requirements. No earlier glide-cancel work was needed.

FallDamage State already held Character, Humanoid, Root, Supports, Ray, Airborne,
Peak, SoftTime, LastPosition, LastVelocity, Connections, and optional Trace.
The new boolean WasWingControlled starts false in ApplyCharacter and clears in
evaluateLanding and the local reset helper. Existing helper callers cover death,
authorized recovery teleport, reposition budget, anchored, swimming, climbing,
and seated states. Character removal discards the state; replacement initializes
a new one.

After LastPosition/LastVelocity update, one IsWingControlled result is computed
for each processed player tick. Episode start seeds WasWingControlled from that
result, so already-controlled takeoff is not an entry. In an existing airborne
episode, a positive peak plus false-to-true control emits `reset` with reason
`wing-boost` and previousPeak, zeros Peak/SoftTime, and reopens the wings fall
episode. WasWingControlled then records the sampled control regardless of
whether a reset fired. This check precedes wing-ascent and the normal peak
update. A negative velocity on the entry tick therefore immediately contributes
to the fresh peak after the reset; the reset does not discard that sample.

Airborne remains true. No cooldown or tap guard was added. The retained
wing-ascent branch uses the same sampled control value; its positive-peak guard
prevents a second reset on the entry tick. `wing-ascent` and `glide-protected`
diagnostic strings remain unchanged. Support/landing probes, compensation,
damage curve, ObserveFallLanding and protection consumption remain unchanged.
WingsService, client motion/input, ownership, and energy were not edited.

## Automated cases

| Contract | Result / authoritative test home |
|---|---|
| Powered partial slowdown, -220 to -40, then release/short fall | PASS: fall-damage and real wings-flight; one wing-boost with previousPeak=220, fresh landing peak=80/70, zero damage |
| Exhausted-energy Gliding, entry/hold at -20, then release | PASS: fall-damage and real wings-flight; actual exhausted energy in integration, one wing-boost, safe fresh peak |
| Boost, release, fresh lethal fall | PASS: fall-damage and wings-flight; full configured lethal damage |
| One reset per transition while holding several ticks | PASS: fall-damage; fresh peak persists after entry |
| Release, fresh peak, second engagement | PASS: fall-damage; second reset reports previousPeak=180, landing uses second fresh peak=70 |
| Already-controlled start and upward reversal | PASS: fall-damage; both zero/positive initial peaks, wing-ascent only, no wing-boost |
| Zero-peak entry | PASS: fall-damage; no reset emitted, later held descent can still become lethal |
| Hold through touchdown, Powered and Gliding | PASS: wings-flight; zero damage, glide-protected, one-shot consumption; reverse Heartbeat order retained |
| Release without a sampled boost | PASS: fall-damage and wings-flight; full original lethal damage, no grace |
| No wings / unowned spoofed display | PASS: fall-damage and wings-flight; full lethal damage |
| Input and ownership regressions | PASS: unchanged wings-input and wings-ownership |

Focused command:

```powershell
python tests/run_state_tests.py --luau .validation-tools/luau.exe --suite fall-damage --suite wings-flight --suite wings-input --suite wings-ownership
```

Final results: fall-damage 142 behavioral assertions; wings-flight 86;
wings-input 42; wings-ownership 20. All four suites pass.
Original pre-pass suites also passed before editing (124/76/42/20).
Running the extended fall-damage spec against only the original production
service fails the Powered negative-velocity reset check. A separate baseline
substitution selecting Gliding first fails its negative-velocity check too.
These checks substitute source at bundle-read time and never overwrite source.

Exact formatting/type/build commands executed:

```powershell
.validation-tools/stylua.exe src/server/Services/FallDamageService.luau tests/fall_damage.spec.luau tests/wings_flight.spec.luau
.validation-tools/stylua.exe --check src/server/Services/FallDamageService.luau tests/fall_damage.spec.luau tests/wings_flight.spec.luau
& 'C:\Users\Collin Van Meter\.aftman\tool-storage\rojo-rbx\rojo\7.7.0\rojo.exe' sourcemap default.project.json -o .validation-tools/wing-sourcemap.json
& 'C:\Users\Collin Van Meter\.aftman\tool-storage\rojo-rbx\rojo\7.7.0\rojo.exe' build default.project.json -o .validation-tools/wing-boost.rbxlx
.validation-tools/luau-lsp.exe analyze --platform roblox --definitions .validation-tools/globalTypes.d.luau --sourcemap .validation-tools/wing-sourcemap.json src/server/Services/FallDamageService.luau
.validation-tools/luau-lsp.exe analyze --platform roblox --definitions .validation-tools/globalTypes.d.luau --sourcemap .validation-tools/wing-sourcemap.json tests/fall_damage.spec.luau tests/wings_flight.spec.luau
git diff --check -- src/server/Services/FallDamageService.luau tests/fall_damage.spec.luau tests/wings_flight.spec.luau
```

StyLua, runtime Roblox-aware typecheck, Rojo sourcemap/build, and whitespace
checks pass. Standalone spec typechecking fails because these specs obtain
globals from the concatenated fixture (env, check, tick, etc.). Baseline and
current specs have the same 18 unique diagnostic messages, with none added.
Executable spec validation uses the existing bundled fixture runner above.
The PATH Rojo shim initially failed with "Home directory could not be found";
calling the installed 7.7.0 binary directly resolved it.

## Full manifest comparison

`python tests/run_state_tests.py --luau .validation-tools/luau.exe` was attempted
alongside a pre-pass comparison. Both stalled at muncher-presentation. A temporary
wrapper then ran the entire existing manifest with a 10-second subprocess limit
per suite, allowing failures/timeouts to remain separate and execution to continue:

```powershell
python .validation-tools/wing_baseline.py current
python .validation-tools/wing_baseline.py baseline
python .validation-tools/wing_baseline.py mutation --suite fall-damage
```

The baseline replaces only this pass's service and two spec files with HEAD
contents while preserving all unrelated working-tree changes. Current and
baseline have identical results: state 20/26, integration 53/69, presentation
35/46. No new failing suite. Pre-existing failures by name:

- State: ripeness, smoothie-world, smoothie, customer-validation,
  customer-compatibility, sprint.
- Integration: tutorial-claim, ingredient-cleanup, ripeness-lifecycle,
  discovery-customers, plot-session-races, plot-session-progression,
  plot-session-requests, plot-session, customer-queue, customer-serve-anywhere,
  legacy-state, legacy-movement, requests, world, smoothie-roundtrip, icegun-aim.
- Presentation: tutorial-hints, muncher-presentation (timeout),
  ripeness-presentation, jacked-noob-hit-presentation, bat-controller,
  ingredient-hold, vfx, customer-order-text, customer-orders, blend-presentation,
  icegun-presentation.

Logs, wrapper, sourcemap, and generated build were moved out of the diff to
`$env:TEMP\blender-wing-boost-validation-20261104`. The bounded full runs preceded
the final two explicit no-wings/release assertions; the final focused run above
includes those assertions. Production code was unchanged between these runs.

## Studio acceptance and build status

Automated validation targets local HEAD 510c519 plus this working-tree diff.
Generated artifact: `wing-boost.rbxlx` in the temporary validation directory.
No Studio playtest or published-game test was performed. This is an implemented
and automatically checked diff; live acceptance is still pending, not a verified
Studio or published build. No publish-lag claim can be made without those tests.

Enable the existing fall-damage trace and run each case from a lethal height:

| Studio case | Status | Expected evidence |
|---|---|---|
| Powered slowdown while velocity stays negative, release, short fall | NOT RUN | wing-boost between lethal peak and landing; only fresh-peak damage |
| Exhausted Gliding at -20, release, short fall | NOT RUN | wing-boost; only fresh-peak damage |
| Boost, release, independently lethal second fall | NOT RUN | full fresh lethal damage |
| Powered held through touchdown | NOT RUN | zero damage, glide-protected |
| Gliding held through touchdown | NOT RUN | zero damage, glide-protected |
| No wings | NOT RUN | ordinary lethal damage |
