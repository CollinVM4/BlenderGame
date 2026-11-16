# Plot claim freeze investigation

Reviewed checkout: `42d136f57c0167abaa6d6c05fdfd09e66d254155` (clean before this patch),
following the earlier review at `9ec68c2`. This is a temporary profiling patch,
with no performance fix or gameplay bypass. The main requested presentation files
and PlotClaimZones have no committed differences between those two revisions.

A RobloxStudioBeta process existed, but the Windows control helper could not
connect to its native pipe, including after retry and reset. A playable place and
a fresh claim could not be inspected. No Studio timing was collected. The
1.49–1.50 s gaps beginning 67–82 ms after client notification are prior evidence
supplied for this investigation, not a new measurement on this checkout.

The strongest source candidate is the fan-out from ripeness instance creation
into repeated GUI scans. Its timing and actual contribution still need a capture.

| Candidate and source | Trigger and source-derived cost | Timing evidence |
| --- | --- | --- |
| GUI scan fan-out: [TasksController](../src/client/Controllers/TasksController.luau) line 53, [TasksGui](../src/client/UI/TasksGui.luau) line 19; [WingsShopAdapter](../src/client/Controllers/WingsShopAdapter.luau) line 131, [IceGunShopAdapter](../src/client/Controllers/IceGunShopAdapter.luau) line 142, [CashBoostShopAdapter](../src/client/Controllers/CashBoostShopAdapter.luau) line 131; [UIRegistry](../src/client/UI/UIRegistry.luau) line 34 | Every PlayerGui descendant addition invokes Tasks refresh and queues one resolve in each of three shop adapters. All four traverse the entire PlayerGui through Registry.Desktops, even when their panels are closed. There is no debounce in these four consumers. A 245-instance burst therefore implies approximately 980 traversals, plus panel lookups and Tasks text writes. Cost scales with the runtime GUI size, not just the new instances. Removal queues Tasks refreshes individually too. | Inferred operation count; no Studio duration. Best first measurement. |
| Ripeness build: [RipenessPresentationController](../src/client/Controllers/RipenessPresentationController.luau) lines 22, 132, 158; [RadialProgress](../src/client/UI/RadialProgress.luau) line 50 | A 100 ms Heartbeat poll visits pads from every tagged stash, without ownership or distance gating. A changed item-ID/ripe signature destroys the slot GUI and builds every pip synchronously. One full starter stash builds 245 UI instances. Its parenting triggers the scans above. MaxDistance affects display, not construction. | Constructor count verified with current RadialProgress in a CLI double; runtime timing and number of rebuilds unmeasured. The poll phase fits the prior delay, but does not establish causation. |
| Server stash fan-out: [Stash](../src/server/Components/Stash.luau) lines 30, 62; [StashPresentation](../src/server/Components/StashPresentation.luau) lines 163, 210 | Each fixture subscribes to the global StashChanged event and ignores its owner argument. One update refreshes all fixtures, including other occupied plots. Refresh clears and rebuilds occupied slot displays, clones ingredients, strips tags/attributes, measures bounds and scales models. A full starter stash means 15 proxies per rebuild; other populated stashes add their proxies. | Inferred. Claim publication also triggers an ownership refresh. Depending on signal dispatch/replication, downstream work may arrive after notification. The prior model bypass weakens this as the sole cause; it did not bypass client ripeness construction/scans. |
| Tutorial gleam: [TutorialGleamController](../src/client/Controllers/TutorialGleamController.luau) lines 345, 419, 558, 598; [TutorialTargets](../src/shared/TutorialTargets.luau) lines 67, 77, 266 | Attribute callbacks can refresh repeatedly during publication, followed by 30 Hz active or 10 Hz inactive polling. Stable targets reuse effects, but target resolution still precedes the equality early return. Stash guidance scans tagged fixtures and descendants twice per refresh through Resolve and ResolveBeam; folder targets expand into visible parts. Marker updates measure model bounds when targeting models. Stage/target changes recreate highlights, marker and beam endpoints. | Inferred. Blender glass cloning is specific to the later Blender stage. Counter guidance has a three-second presentation delay, and initial Stash guidance a 2.5-second delay in TutorialPresentationState; neither is automatically a first-100-ms burst. |
| Identity: [PlotIdentityController](../src/client/Controllers/PlotIdentityController.luau) lines 102, 113, 178 | Every 250 ms, visit all plots, recursively find PlotIdentityOrigin, update pad labels, and rebuild member UI when the signature changes. Ownership and later thumbnail availability can each cause a rebuild. Thumbnail lookup runs in task.spawn. | Inferred; smaller construction burst than ripeness. |
| Claim-zone refresh: [PlotClaimZones](../src/server/Services/PlotClaimZones.luau) lines 96, 123 | Every 150 ms, refresh all plots, enumerate both visual subtrees, write part/zone properties and four sign text layers, then check players in both zones. Claim completion refreshes again. Sign styling is cached; part enumeration and text assignment are repeated. | Inferred; continuous server cost, rather than a unique client notification handler. |
| Tutorial hint: [TutorialHintController](../src/client/Controllers/TutorialHintController.luau) lines 31, 47, 90; [AnnouncementBanner](../src/client/UI/AnnouncementBanner.luau) line 69 | Active guidance refreshes each Heartbeat and on tutorial attributes. Banner creation is conditional, not per tick. LayoutTutorial runs before the unchanged-text early return and reassigns geometry/size constraints. | Inferred; instrumented to rule in/out aggregate refresh/layout cost. |

RadialProgress creates 13 instances: one root; four circles with Frame/UICorner
pairs; two clip Frames; and two UIGradients. Each pip adds an outer Frame plus a
center Frame/UICorner, making 16. Five slots with three ingredients each create
`5 * (1 + 3 * 16) = 245`: 5 BillboardGuis, 135 Frames, 75 UICorners and 30 gradients.
Even initially ripe pips construct radials before hiding them. Progress alone does
not change the signature; stable polls update existing views. ID/ripe changes,
partial attribute replication, clearing and refilling can cause more full builds.
Other plots join the same poll and can add work to that frame.

Other GUI consumers also react to the burst. UpgradesGui, SettingsGui,
ScrapbookPresentation and HotbarController coalesce scheduled updates, unlike
the four consumers above. Registry scanning within those consumers is covered by
the shared scan marker. FramewispMenus observes its own UI and Card3D roots;
stash BillboardGuis are separate PlayerGui children. Workspace-wide discovery
in WorldTextController, WorldStrokeController and CustomerOrderController is
startup work, followed by incremental callbacks. InteractionPromptController
can rescan visible prompt models when new workspace Attachments arrive; this
does not receive the PlayerGui ripeness descendants directly.

Claim order and latency boundaries:

1. PlotClaimZones.Step samples the pad every 150 ms, validates the live character,
   then calls Enter -> TycoonService.ClaimPlot -> AssignPlot.
2. TycoonService publishes plot OwnerUserId/PlotSessionId/identity and player
   membership/upgrades before SessionStarted. MemberChanged refreshes farm/lock
   membership, binds inventory, clears spawn reservation, reconciles tutorial,
   and refreshes movement/combat/blender/customer projections.
3. SessionStarted in server/init.server.luau line 84 starts lock/farm state,
   resets blender/muncher, and calls InitializeTutorialStash. InventoryService
   line 1020 brackets the yielding persistence open. Restored state then fires
   StashChanged (line 1059), which publishes the per-item stash attributes and
   builds physical presentation through Stash.
4. CustomerService.ActivateForPlayer enables the tutorial queue with a deferred
   first spawn, and tutorial membership reconciliation publishes stage/targets.
   AssignPlot returns and PlotClaimZones sends PlotClaimed. The persistence wait
   and initialization before that send are pre-notification latency.
5. StandIdentityController line 276 receives PlotClaimed and waits on Heartbeat
   for matching replicated membership, up to three seconds. OpenNameEditor starts
   a camera tween; Editor.Create already ran at controller initialization. The
   editor appears after the 0.48-second tween and optional focus after another
   three seconds. This is not a synchronous three-second busy loop. The prior
   automatic-naming bypass did not remove the separate ripeness/GUI scan path.

To capture one fresh normal claim:

1. Sync this checkout into the existing playable Studio place with Rojo. The
   Rojo build alone does not include the authored map. In **Edit** Command Bar run
   `workspace:SetAttribute("ProfilePlotClaim", true)` before starting Play.
2. Use the tutorial-active test profile with the same stash contents and plot
   population as the repro. Keep naming, stash presentation, guidance and normal
   customer arrival enabled. Record occupied plots and starter slot counts.
3. Start a fresh Play session. Enable Studio's client MicroProfiler before
   approaching the pad so it records native rendering/layout/replication work as
   well as the `Claim/...` scopes. Walk onto an available pad once.
4. Keep the window foreground and avoid Command Bar/debugger interaction during
   the first ten seconds after the claim. The client automatically freezes and
   dumps its buffer at +10 s; the server dumps at +15 s after send. Preserve both
   `[ClaimProfile]` summaries and all `[ClaimProfile/client]` and
   `[ClaimProfile/server]` JSON chunks, plus the MicroProfiler capture containing
   the hitch. Output is buffered during measurement.
5. Confirm the naming editor opens and a saved name reaches the stand sign;
   ripeness pips match all populated slots and keep progressing; tutorial
   counter/stash guidance appears at its normal time; the first customer walks
   in and can be ordered from. These visual/engine checks remain pending here.
6. Stop Play. Set ProfilePlotClaim to false (or remove the attribute) before the
   next normal session. The flag is sampled at module load. No extra remotes,
   assets, or authored attachments are needed. Re-run fresh Play for a repeat;
   the profiler deliberately records only the first claim in each process.

The first capture must establish the longest post-PlotClaimed PreRender interval,
its start offset, whether ripeness produces one 245-instance build or repeated
builds, and the scan call/instance counts caused by those builds. Compare
`ripeness.poll`, `radial.create`, `tasks.refresh`, `shop.*.resolve` and
`gui.desktops.scan` durations against that interval. Then check server stash
refreshes, tutorial work and identity/zone polls on the same timeline.

Each row has local `At` and synchronized `ServerAt` in seconds, with `Ms` for
elapsed spans. Frame rows bracket actual callback-to-callback wall time; they do
not use the engine dt as a proxy. Use server.claim.enter -> server.PlotClaimed.send
for claim initialization latency and stash.persistence.begin/end for the storage
portion. Use the client's own PlotClaimed mark as the origin for client frame
offsets. ServerAt permits approximate cross-process alignment; local At values
must not be compared between processes.

The client summary reports the longest interval starting after receipt,
overlapping callbacks/counts, and WorkIntervalUnionMs. Nested spans and counts
are inclusive: never add a parent and its children as independent cost. The union
avoids double-counting elapsed intervals, but is not exclusive CPU time. A scan
can schedule further callbacks after it returns. If callbacks explain only a
small fraction of the gap, use the native MicroProfiler lanes to distinguish
render/layout/gradient work, replication, GC, scheduling or external Studio work.
A coincident 245-instance build alone is insufficient to attribute 1.5 seconds.
No targeted gameplay toggle has been added; choose one only if the normal capture
leaves a specific question unresolved.

Buffers retain the newest 12,000 rows per process and report overwritten rows.
Snapshot() is available in each process via
`require(game.ReplicatedStorage.Shared.ClaimProfile).Snapshot()`; Dump() freezes
that process before printing. The patch adds profiling hooks in the candidates
above, the claim/restore/customer boundaries, client bootstrap and TutorialTargets.
UIRegistry's scan profiler is injected only during enabled client initialization.
The CLI fixture/runner resolve the diagnostic dependency without activating it.

Validation on this patch:

- Focused claim integration: stand-identity, plot-player-flow, starter-stash and
  tutorial-claim passed independently.
- Separate presentation: tasks-ui, tutorial-hints, tutorial-targets,
  tutorial-beam-stability, plot-identity, stand-editor and Framewisp menu runner
  passed. No unrelated movement/VFX/legacy suites were run.
- ripeness-presentation fails on a missing global Color3.fromRGB in its CLI spec;
  the identical failure reproduces on an isolated archive of the reviewed commit.
  No unrelated production change was made for it.
- A temporary CLI smoke check passed diagnostic gating, callback return/error
  preservation, nested overlap accounting, frame interval buffering and freeze;
  executing the current RadialProgress constructor confirmed 13 instances.
- StyLua on changed Luau and Rojo 7.7 build passed. Roblox-aware luau-lsp analysis
  with a fresh sourcemap reports the same 23 diagnostics as baseline: 22 missing
  DisplayText fields in CustomerRequests and one CustomerService grade-union
  error. ClaimProfile itself typechecks cleanly. Logs/build/sourcemaps and the
  isolated baseline are in `%TEMP%/BlenderGame-plot-claim-42d136f/`.

There is no before/after Studio frame comparison: no fix was made and no new
Studio claim ran. The next decision depends on measured scan/construction cost
and native frame attribution on the normal setup.
