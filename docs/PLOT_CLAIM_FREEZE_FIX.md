# Plot claim GUI refresh fix

The client fix scopes structural refreshes to the existing UIRegistry Desktop,
Content and Tasks/Shop panel contracts. Runtime stash billboards outside that
authored tree do not schedule any of the four consumers. Each consumer sets its
pending flag before deferring, clears it when the callback starts, and resolves
the current UI at that time. Initial binding and attribute/price/ownership
updates retain their existing paths.

Shop adapters also reconcile their current Buy controls before binding. Replaced
or detached controls lose their old handlers; current controls retain their
existing handlers. Panel Destroying cleanup remains in place. This covers whole
export replacement, same-root reattachment, and a card/control replacement inside
an existing panel.

Runtime changes are limited to:

- `src/client/Controllers/TasksController.luau`
- `src/client/Controllers/WingsShopAdapter.luau`
- `src/client/Controllers/CashBoostShopAdapter.luau`
- `src/client/Controllers/IceGunShopAdapter.luau`
- `src/client/UI/UIRegistry.luau`

All incoming Studio-only ClaimProfile hooks remain available. Stash ripeness,
stand naming, tutorial guidance and customer loading retain their existing code.

## Measurement status

The before capture below was supplied with the task, based on profiling patch
`42d136f57c0167abaa6d6c05fdfd09e66d254155`. It was not recaptured during this pass.

| Client measurement | Before, Studio | After, Studio |
| --- | --- | --- |
| Longest post-claim PreRender gap | 1,556 ms, starting about +28 ms | Pending fresh claim capture |
| Desktop scans during that gap | 923 | Pending |
| Desktop scan time during that gap | 1,438 ms | Pending |
| Descendants visited cumulatively | 2.24 million | Pending |
| Stash ripeness build | 229 GUI instances in 4.9 ms, inside the gap | Pending |
| Tasks / Wings / Cash Boost / Ice Gun refreshes from stash additions | 229 each | Pending |

The CLI regression simulates a 229-instance stash billboard burst and observes
**zero refreshes in all four consumers and zero desktop scans**. Relevant batches
coalesce to one refresh per affected consumer. These are functional regression
results, not Studio frame measurements or evidence of engine/render timing.

Roblox Studio and Rojo processes were running, but the Windows computer-use
connection returned `Computer Use native pipe is unavailable` on initial access,
retry, and after resetting the JS session. No fresh Play session or visual claim
verification was performed.

## Local validation

Passed:

- `python tests/run_gui_binding_tests.py --luau .validation-tools/luau.exe`:
  startup and late mount; unrelated addition/removal fan-out; relevant burst
  coalescing; latest Tasks progress; attribute updates; replacement Buy buttons;
  inert old controls; same-root reattachment; semantic export replacement; late
  required-control recovery; ownership updates after replacement. The same
  regression against the incoming source snapshot fails at the stash fan-out
  contract, as expected.
- `python tests/run_state_tests.py --luau .validation-tools/luau.exe --suite tasks-ui`.
- Existing Shop text/state/purchase contracts against
  `Framewisp_Hotbar.prepared.rbxmx`, using a temporary copy of the existing runner
  selecting just that available export. Its fixture now supplies the standard
  DescendantRemoving event used by the adapters.
- StyLua format/check on the five runtime files and both changed Luau specs.
- Roblox-aware luau-lsp analysis of the five changed runtime files, with a fresh
  Rojo sourcemap and `.validation-tools/globalTypes.d.luau`: exit 0.
- Rojo 7.7 sourcemap/build and `git diff --check`.

Pre-existing checks reported separately:

- Whole-source typecheck: 212 TypeError occurrences on both the incoming source
  snapshot and the fix. Normalized diagnostic multisets match exactly (39
  distinct headers), covering CustomerRequests DisplayText, CombatService,
  CustomerService and JackedNoobService. No added diagnostics.
- The unmodified `tests/run_wings_shop_tests.py` stops before loading production
  code because `newestExport11426.rbxmx` is missing. The same missing-file failure
  reproduces against the incoming snapshot; the available prepared export passes
  separately as described above.

Logs, the incoming source snapshot, sourcemaps, build and temporary runner copies
are in `%TEMP%/BlenderGame-claim-freeze-fix/`. The Aftman shim could not find its
home directory in this execution environment; build validation used the already
installed Rojo 7.7 binary directly.

## Remaining Studio verification

Use the same playable authored place, profile, stash contents and plot population
as the before capture. The Rojo build by itself does not include the map. Sync
the checkout, then in Edit Command Bar run:

```luau
workspace:SetAttribute("ProfilePlotClaim", true)
```

Start fresh Play and claim normally. Keep the window foreground during capture;
leave starter stash ripeness, stand naming, tutorial guidance and normal Red
arrival active. Preserve the automatic client `[ClaimProfile]` summary and JSON
chunks at +10 seconds. Record the longest post-claim PreRender gap, its desktop
scan count/time, and all four refresh counts. Verify stash construction does not
cause those refreshes and scans no longer scale with its GUI instance count. If
the longest frame is outside the stash build, report the frame containing that
build with the same scan and refresh metrics as well.

Visually verify the stash/pips build and keep progressing, the naming editor and
saved sign work, tutorial guidance appears, Red arrives normally, and claiming
stays responsive. Stop Play and clear the profiling flag for normal sessions.
No additional Studio assets, remotes or setup are required.
