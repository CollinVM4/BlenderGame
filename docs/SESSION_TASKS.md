# Session-only Tasks implementation

Branch: `feature/session-tasks`. Working diff only; no commit, merge, or publication. Existing local work was preserved. The current checkout also received concurrent ProtectionService edits during implementation. `SESSION_TASKS.patch` contains only Tasks changes against the captured incoming working tree, excluding all pre-existing and concurrent feature changes. It is for review or application to that incoming snapshot; these changes are already present in the current workspace.

## C/D qualification clarification

The inspected `CustomerOrderEvaluation.Evaluate` sets IsFulfilled true only for A/B. This conflicted with the initial requirement to count C/D through that gate. The user explicitly clarified: "allow C/D ratings to count towards customer serve progress". CustomerService therefore passes evaluation.IsValid as Tasks qualification, separately from order success. All valid consumed non-Freeloader cups count, including C/D cups whose order is unfulfilled. Rejected operations and invalid cups count zero. Grading, order success, normal payout formulas, and protection remain unchanged. The real Serve integration test verifies A, B, C, and D ratings count once each.

## Implemented behavior

- TasksService owns the exact requested Serve/StealProgress state entirely in server memory. Bootstrap initializes it before gameplay and clears it and its listeners on player removal. No PlayerData record access, saved state, DataStore, remotes, or persistence were added for Tasks.
- Serve milestones are cumulative 3/10/20/30/+10. First reward locks before live serves; tier changes do not alter an active reward, and subsequent locks never decrease. Optional authoritative session-count reconciliation selects the next milestone without paying passed milestones. CustomersServed is never read.
- CustomerService.Serve calls RecordServe with evaluation.IsValid qualification after the order credit, inside its existing transaction. The server-owned customer record guards duplicate observations. Task bonus is included in the existing single CustomerReaction payout/feedback pass. Failed credits preserve the qualifying observation and an unpaid live crossing for a later serve/retry; guards advance only after successful credit. No yielding work was added to that sequence.
- TutorialStage observation distinguishes activation inspection from an in-session transition. Already Complete activates without tutorial cash or tutorial text. Observed completion pays the single configured $5,000 once through a standalone transaction. A deferred callback avoids nesting into the current serve transaction; failed/unavailable payment remains pending and can retry on a later cash/membership publication. Removal cancels queued payment. In the real tutorial, the third serve reaches NextCustomer; accepting the next regular order publishes Complete. The actual third serve independently pays the locked $9,000 Serve 3 milestone, despite the tutorial Jump purchase.
- InventoryService.Withdraw records successful non-friendly ingredient and smoothie transfers at its one shared success gate, then increments IngredientsStolen once. Steal delegates to Withdraw and has no additional hook. RemoveThiefIngredient remains separate and has no Tasks/stat hook. Existing friendly, equip, slot, lock, and raid protection gates are unchanged.
- Steal 10 pays max(configured $2,500 floor, configured 5% of current shared team cash), then resets and repeats. Failed payment preserves the transfer count and unsettled completion; a subsequent theft can settle it while retaining that new transfer. IngredientsStolen never resets with the task counter. Estimates refresh server-side on cash/membership publication.
- Standalone tutorial/steal payments use the existing GameplayPresentation remote and cash animation/ticker paths, with TaskReward accepted by CashRewardState and the existing GUID replay guard. No payment/claim endpoint or bonus banner was added. Steal feedback reports actual credited whole dollars after the existing cash authority applies rounding.

## Optional UI contract

The mapped export is `Framewisp_Hotbar.prepared.rbxmx`; inspection found no Tasks/ServeTask/StealTask hierarchy. No artwork, model, ScreenGui, layout, or style was authored. Server behavior works without the panel. TasksGui follows UIRegistry desktop/content/active-root resolution and importedChild-style semantic binding; missing or ambiguous hierarchy returns nil. Registry.Panels.Tasks is true.

Expected exported names, without role suffixes:

```text
Tasks
  ServeTask
    Objective (TextLabel)
    Progress (TextLabel)
    Reward (TextLabel)
  StealTask
    Objective (TextLabel)
    Progress (TextLabel)
    Reward (TextLabel)
```

Tasks is a direct child of the registry-resolved desktop content; each task entry is a GuiObject. The controller writes only text and tutorial progress visibility. It shows Finish the tutorial with the configured reward, then cumulative serve progress and its locked reward; steal reward is labeled as an estimate. It hides the numeric tutorial progress field because the existing tutorial has no numeric fraction contract. Server-owned display attributes: TasksTutorialComplete, TasksTutorialReward, TasksServeTotal, TasksServeThreshold, TasksServeReward, TasksStealProgress, TasksStealTarget, TasksStealReward. No Studio setup is required for server gameplay. Artwork placement/mobile readability remain with Collin as requested; no Studio testing tasks were added.

## Files in the focused patch

- `src/shared/Constants/TasksConfig.luau`
- `src/server/Services/TasksService.luau`
- `src/server/Services/CustomerService.luau`
- `src/server/Services/InventoryService.luau`
- `src/server/init.server.luau`
- `src/client/UI/UIRegistry.luau`
- `src/client/UI/TasksGui.luau`
- `src/client/UI/CashRewardState.luau`
- `src/client/Controllers/TasksController.luau`
- `src/client/init.client.luau`
- `tests/run_state_tests.py`
- `tests/tasks.spec.luau`
- `tests/tasks_serve.spec.luau`
- `tests/tasks_steal.spec.luau`
- `tests/tasks_ui.spec.luau`
- `tests/tutorial_gameplay.spec.luau`
- `tests/stash_interaction.spec.luau`

## Automated validation

Tools reused from the existing local validation directory: Luau 0.745, StyLua 2.6.0, Luau LSP 1.70.1 and its Roblox definitions, Rojo 7.7.0. No tools were downloaded. Tests use the repository's mocked engine boundary; no Studio/live runtime checks were run or claimed.

Focused task/state/integration/presentation and requested existing suites: 6/6 pass. The existing stash suite was additionally run and passes (490 behavioral checks); its PlayerData stub needed the new IncrementStat dependency, while authoritative theft-stat assertions live only in tasks_steal.spec.luau. Coverage includes actual special/wildcard/Freeloader serves, actual three tutorial serves and completion, transaction failures/retries/reentrancy, all four reward tiers, historical progress, indefinite thresholds, shared cash and all three formula examples, real successful/failed/protected/locked/raid/NPC/friendly ingredient/smoothie transfers, resetting progress versus stat totals, missing UI, and cleanup. C/D qualification follows the user clarification above.

Full current workspace: 105/137 pass (state 19/25, integration 52/68, presentation 34/44), exit 1. This includes three concurrent protection suites. Isolated Tasks-only tree: 102/134 pass, exit 1. Captured incoming checkout: 98/130 pass, exit 1. The exact same 32 failures reproduce in the incoming checkout; no new failures remain. Presentation runs remain separately classified.

StyLua formatting and check: exit 0 on all touched Luau files. Rojo sourcemap/build: exit 0. New Tasks modules plus UIRegistry/CashRewardState typecheck: exit 0. All touched production modules typecheck: exit 1, 40 diagnostics, exactly matching the incoming checkout after normalizing source locations: CustomerRequests 22, CombatService 9, CustomerService 1, JackedNoobService 8. No new diagnostics. git diff --check and focused patch git apply --check: exit 0.

Reproduction commands (PowerShell; equivalent direct CLI invocations executed by the validation subprocess runner):

```powershell
$tools = "$env:TEMP/BlenderGame-lucky-block-validation-20261030-1541a6c"
$out = "$env:TEMP/blender-tasks-mu7611ml"
$rojo = 'C:/Users/Collin Van Meter/.aftman/tool-storage/rojo-rbx/rojo/7.7.0/rojo.exe'
python tests/run_state_tests.py --luau "$tools/luau/luau.exe" --suite tasks --suite tasks-serve --suite tasks-steal --suite tasks-ui --suite customer-payout-serve --suite tutorial-gameplay
python tests/run_state_tests.py --luau "$tools/luau/luau.exe" --suite stash
python tests/run_state_tests.py --luau "$tools/luau/luau.exe"
python "$out/baseline/tests/run_state_tests.py" --luau "$tools/luau/luau.exe"
python "$out/tasks-only/tests/run_state_tests.py" --luau "$tools/luau/luau.exe"
$owned = Get-Content "$out/owned.json" | ConvertFrom-Json
$luauFiles = @($owned | Where-Object { $_ -like '*.luau' })
$sourceFiles = @($owned | Where-Object { $_ -like 'src/*' })
& "$tools/stylua/stylua.exe" $luauFiles
& "$tools/stylua/stylua.exe" --check $luauFiles
& $rojo sourcemap --output "$out/sourcemap.json"
& $rojo build -o "$out/tasks.rbxlx"
& "$tools/lsp/luau-lsp.exe" analyze --platform roblox --sourcemap "$out/sourcemap.json" --definitions "$tools/roblox.d.luau" $sourceFiles
& "$tools/lsp/luau-lsp.exe" analyze --platform roblox --sourcemap "$out/sourcemap.json" --definitions "$tools/roblox.d.luau" src/server/Services/TasksService.luau src/shared/Constants/TasksConfig.luau src/client/Controllers/TasksController.luau src/client/UI/TasksGui.luau src/client/UI/CashRewardState.luau src/client/UI/UIRegistry.luau
git diff --check
git -C "$out/baseline" apply --check "$PWD/docs/SESSION_TASKS.patch"
```

Baseline typechecking used the same source list restricted to files already present in `$out/baseline`, that directory as cwd, and its own Rojo sourcemap at `$out/baseline-sourcemap.json`. Raw logs, the incoming snapshot, isolated Tasks tree, and generated build are retained in `$out` outside the delivered diff.

Baseline-reproduced failures:

- `ripeness`
- `smoothie-world`
- `smoothie`
- `customer-validation`
- `customer-compatibility`
- `sprint`
- `tutorial-claim`
- `muncher-vacuum`
- `ingredient-cleanup`
- `ripeness-lifecycle`
- `discovery-customers`
- `plot-session-races`
- `plot-session-progression`
- `plot-session-requests`
- `plot-session`
- `customer-queue`
- `customer-serve-anywhere`
- `legacy-state`
- `legacy-movement`
- `requests`
- `world`
- `smoothie-roundtrip`
- `tutorial-hints`
- `ripeness-presentation`
- `jacked-noob-hit-presentation`
- `bat-controller`
- `ingredient-hold`
- `vfx`
- `customer-order-text`
- `customer-orders`
- `blend-presentation`
- `icegun-presentation`
