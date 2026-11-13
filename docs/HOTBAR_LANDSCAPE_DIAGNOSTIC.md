# Pass 1: landscape cold-start evidence

Base: `main` at `4a8171aaf36651d60c415fac492d945d49ed6460`.
Diagnostic build marker: `4a8171a+hotbar-diagnostic-v1`.
Portrait cold start works on the user's phone. Landscape still shows two bars
with both prior patches. The second bar's identity is **not confirmed**.
Pass 1 remains open; Sprint redesign / Pass 2 has not started.

## Trace and limits

- `src/client/init.client.luau` starts HotbarController once, in an independent
  task before unrelated yielding controllers. `Init` is idempotent per required
  ModuleScript; it reconciles PlayerGui replacement. Cloned Client/ModuleScript
  trees have independent module state, so that guard does not exclude copies.
- `UIRegistry.Desktops` scans all descendants. `ActiveRoot` requires visible
  ancestry and enabled ScreenGuis. `Child` rejects ambiguous sibling roles.
- `HotbarGui.Find` rejects multiple active desktops and competing authored and
  reparented bars. It only accepts a reparented bar under a direct `HotbarHost`
  with the ownership marker. Rejection retains native fallback; it does not
  hide arbitrary unowned Studio GUI copies.
- HotbarController moves the existing bar into a full-screen `HotbarHost`, adds
  `HotbarScroll`, and clones individual slots. It does not clone whole bars or
  roots. A stale/repeated session can encounter an existing host; sessionVersion
  only coordinates starts within that module instance.
- The prepared XML contains **one ScreenGui and one Hotbar**, no authored hosts.
  Its five embedded LocalScripts do not start HotbarController or set Backpack
  CoreGui state. Their Clone calls copy sounds/styling/effects, not hotbars.
- `default.project.json` maps that one export to `StarterGui.Framewisp_CCVVMF`
  (the XML root is internally named `Framewisp_RMMRUE`) and maps one Client tree.
  `StarterGui.$ignoreUnknownInstances = true` preserves other Studio instances.
  The repository cannot inventory the current published place's unknown GUI.
- Only HotbarController sets Backpack CoreGui state in repository client code.
  Existing touch reassertions remain at 0.25 and 1 second; no new retries were
  added. The existing cold-start double lets a later write clear simulated
  native pixels. Passing it does not prove the real phone behaves that way.

## Enable once, for your account only

1. Sync this working tree with Rojo into the **existing Studio place that shows
   the problem**. Preserve its Studio-authored GUI during this investigation.
   Opening the generated Rojo-only build as a replacement could remove the very
   duplicate we need to identify.
2. In Studio's Command Bar, outside Play mode, replace the number below with
   your Roblox account's numeric UserId and execute:

   ```luau
   workspace:SetAttribute("HotbarDiagnosticUserId", 12345678)
   ```

   This Workspace number attribute is the single opt-in. It must be present
   before the client starts. Other players receive no diagnostic UI or logging.
   Studio test players may have a different UserId; use that test player's ID
   when doing the separate Studio run. There is no RemoteEvent or server upload.
3. Publish the updated existing place. Join a fresh server on the phone so it
   runs the new place version. The report includes PlaceId, PlaceVersion, JobId
   and the diagnostic build marker; missing capture buttons indicate an old
   build, wrong UserId, or missing attribute. Do not proceed with an uninstrumented
   reproduction.

## Capture without losing the cold start

1. Leave the experience, hold the phone in landscape **before joining**, and
   join fresh. Do not rotate during loading. Obtain/retain at least one Tool;
   the custom bar intentionally hides when inventory is empty.
2. While both bars are still visible, tap **Hotbar: capture** at the top. It
   changes to **Captured #1**. Take a screenshot including both bars and this
   marker. Do not open the report or developer console yet, since those cover
   the game view.
3. Rotate once to portrait. Immediately tap capture again (**Captured #2**) and
   take another screenshot. Orientation and camera viewport changes also take
   automatic deferred snapshots, so the transition is recorded before a manual
   tap can happen. Record which bar disappeared and whether the surviving bar
   equips and unequips the Tool. If useful, return to landscape and capture #3.
4. Now tap **Show / hide report**. The read-only multiline text can be selected
   and copied; send the complete text with both screenshots. If the phone does
   not expose text selection, screenshot the relevant report sections or obtain
   the `[HotbarDiagnostic]` lines from the client developer console. Studio runs
   also print those lines to client Output. Do not infer phone results from the
   Studio run. In a running Studio client, the complete shared buffer is also:

   ```luau
   print(game:GetService("Players").LocalPlayer.PlayerGui.HotbarDiagnosticLog.Value)
   ```

   Include `controllerStart`, `controllerBar`, `backpackWrite`, `backpackRead`,
   and each `snapshot` through `snapshotEnd`, especially manual #1 and #2.
   Logs are shared across copied diagnostic modules and controller restarts in
   the same PlayerGui. They are bounded to 1 MiB; the report states dropped lines.
   Collect the report before leaving or replacing PlayerGui.
5. Run a separate fresh portrait join and capture it too. Keep its report and
   screenshots separate from the landscape-first session.
6. To disable for subsequent joins, remove the attribute and publish again:

   ```luau
   workspace:SetAttribute("HotbarDiagnosticUserId", nil)
   ```

   The setting is read at controller start; removing it is not a live-session
   toggle. Diagnostic hooks/module should be removed after the cause is fixed.

## Reading the evidence

`liveGui` inventories PlayerGui ScreenGuis, desktops, bars and hosts, including
same-named siblings. `starterTemplate` inventories the client-visible StarterGui
templates separately; templates are **not** additional rendered bars. Each
record includes an instance ID plus full path. IDs are stable within a diagnostic
session and distinguish equal paths; the session prefix distinguishes cloned
modules. `controllerStart` records actual starts; `clientScript` inventories
LocalScripts and HotbarController modules. Presence alone does not prove a script
ran. `controllerBar` identifies the controller's chosen bar.

Visibility reports include Visible/Enabled ancestry, CanvasGroup transparency,
absolute position/size and clipping against ancestors and the ScreenGui bounds.
`barButton` records slot geometry, visibility and Active/Selectable. Effective
visibility is a geometry/ancestry estimate, **not** a pixel or occlusion test.

Two distinct visible custom bar IDs with visible slots support the duplicate
custom-GUI path; compare roots, templates and controller ownership. One visible
custom bar with two bars on the screenshot supports investigating native
Backpack or another unrecognized UI. The diagnostic does not access protected
CoreGui descendants, so it cannot positively identify native pixels itself.

`backpackWrite` records requested value, reason, pcall success/error;
`backpackRead` and snapshots record GetCoreGuiEnabled results/errors. A successful
disable and a returned `false` mean only the API setting. `nativeRendered` stays
`UNKNOWN: compare phone screenshot`, even when the setting is false. Arbitrary
Studio scripts' own API calls are not intercepted.

No corrective behavior or confirmed-failure regression is claimed yet. Use the
captures to choose the smallest fix and add that failure path to the existing
hotbar test home; do not extend retry timing speculatively.

## Validation and handoff

The diagnostic contract case exercises the actual module with engine doubles:
per-user opt-in, controller read/write capture, API/pixel distinction, same-path
duplicate identification, hidden-bar reporting, Tool selection and native
fallback. It does not simulate the phone renderer.

Run from the repository root:

```powershell
python tests/run_hotbar_tests.py --luau .validation-tools/luau.exe --case diagnostic
python tests/run_hotbar_tests.py --luau .validation-tools/luau.exe --case dock-landscape
python tests/run_hotbar_tests.py --luau .validation-tools/luau.exe
$hotbarDiagnosticOut = Join-Path $env:TEMP 'blender-hotbar-diagnostic'
$hotbarRojo = 'C:\Users\Collin Van Meter\.aftman\tool-storage\rojo-rbx\rojo\7.7.0\rojo.exe'
.validation-tools/stylua.exe --check src/client/UI/HotbarDiagnostic.luau src/client/Controllers/HotbarController.luau tests/hotbar.spec.luau
& $hotbarRojo sourcemap default.project.json --output "$hotbarDiagnosticOut/sourcemap.json"
.validation-tools/luau-lsp.exe analyze --platform roblox --sourcemap "$hotbarDiagnosticOut/sourcemap.json" --definitions .validation-tools/globalTypes.d.luau src/client/UI/HotbarDiagnostic.luau src/client/Controllers/HotbarController.luau
& $hotbarRojo build default.project.json --output "$hotbarDiagnosticOut/hotbar-diagnostic.rbxlx"
git diff --check
```

Studio and physical mobile QA belong to the user. Close Pass 1 only after a
fresh landscape join has exactly one usable custom bar without rotating and a
separate fresh portrait join still works. This diagnostic build is the evidence
handoff, not a claim that those acceptance criteria pass.

Validation on this handoff: diagnostic case, landscape docking case, complete
hotbar suite, changed-module Roblox-aware typecheck, StyLua and Rojo build all
pass. `git diff --check` passes. The analyzer prints only its existing tool-level
watched-files registration warning. No unrelated suites or computer mode ran.
Build: `%TEMP%/blender-hotbar-diagnostic/hotbar-diagnostic.rbxlx` (opt-in off by
default; use the existing Studio place for the reproduction as described above).

Changed files: `HotbarController.luau` adds gated observer hooks and call-reason
labels; `UI/HotbarDiagnostic.luau` contains the temporary observer/report;
`tests/hotbar.spec.luau` and `tests/run_hotbar_tests.py` add its focused contracts;
this document records the trace and QA procedure. HotbarGui, UIRegistry, client
startup, the export, and the Rojo mapping are unchanged.
