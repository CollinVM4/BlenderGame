# Touch-button lookup and pending inventory updates

Follow-up to the reported v1586 failure, November 16, 2026. Incoming checkout:
`main` at `5141c4a61c1719d8b380d24f4a0aef860b466656`. The only incoming local
edit was `StandIdentityController.luau`; it was left untouched. Sprint Pass 2
remains paused.

During this work, the stand-name edit was committed separately as
`ce712dcdf7c69d23553f914db1a93b0f99c4073e`. Final HEAD is that commit plus this
uncommitted hotbar patch. The validation build's two changed hotbar modules
were compared with the checkout and match after line-ending normalization.
The build also includes the stand-name commit. No commit or publication was
made by this hotbar task.

Collin confirmed that the source revision synced for **v1586 is unknown**.
The path below is verified in this checkout; its presence in the published
v1586 scripts has not been independently verified. This patch's published
version and physical phone acceptance also remain pending.

## Verified path and changes

Before this change, early client initialization started HotbarController, whose
`update()` called its local `obstacles()`, then
`MobileControlLayout.HotbarObstacles()`, then
`ContextActionService:GetButton()`. Injecting a suspension at that lookup held
the hotbar pass. Inventory callbacks called `schedule()`, which returned while
`mutating` was true, leaving no follow-up inventory pass.

`HotbarObstacles()` now reads the mobile layout module's cached action button
references. Only the independent mobile controls update calls `GetButton()`.
While lookup is pending or actual buttons are absent, the hotbar uses the
existing predicted bounds. When a reference becomes available, a cache observer
schedules hotbar layout without looking up a button. Actual zero-size/hidden
buttons remain observed while predictions provide clearance. Unregistering an
action or replacing PlayerGui clears the cache. A suspended controls pass cannot
publish a reference after teardown or for a retired PlayerGui/action.

Inventory callbacks now retain one pending update while a pass is running.
After the current pass returns, the controller queues that follow-up; multiple
Tool events coalesce. The current pass captures its diagnostic trigger before
collection, preserving any new trigger for the next pass. Container rebinding
uses the same inventory request path. GUI changes made by rendering still do
not repeatedly schedule themselves.

The single-owner Backpack handoff, CoreGui retry budget, equip calls, ordering,
input guards and gameplay remotes are unchanged. The handoff function was
compared against incoming HEAD and is identical.

## Changed files

| File | Change |
| --- | --- |
| `src/client/UI/MobileControlLayout.luau` | Button-reference cache, cache observers, synchronous HotbarObstacles, stale lookup guards. |
| `src/client/Controllers/HotbarController.luau` | Subscribe to cache changes; retain/coalesce in-pass inventory events and their trigger; unsubscribe on teardown. |
| `tests/hotbar.spec.luau` | Suspended lookup, cache publication, pending arrivals/removals/classification; existing live-control case now obtains references through the controls update. |
| `tests/run_hotbar_tests.py` | Adds `lookup` and `updates` focused selectors. |
| `docs/HOTBAR_ASYNC_TOUCH_LOOKUP.md` | Evidence, validation and published-phone handoff. |

No Rojo mappings, exported UI instances or Studio attributes changed. Sync both
runtime modules together; a fresh client must load their matching APIs.

## Validation

| Check | Result |
| --- | --- |
| Incoming complete hotbar suite | PASS: 46 cases, 407 checks. |
| New lookup regression against isolated incoming HEAD | FAIL as expected: inventory cannot populate/take over while lookup is suspended. |
| New pending-update regression against isolated incoming HEAD | FAIL as expected: arrivals during a held update do not reconcile without another event. |
| Updated lookup group | PASS: 4 cases, 0 failed; portrait/landscape x Ice Gun/ingredient. |
| Updated pending-update group | PASS: 3 cases, 0 failed; arrivals, removals and late classification. |
| Updated complete hotbar suite | PASS: 53 cases, 474 checks, 0 failed. |
| Mobile control layout suite | PASS: 282 checks. |
| Roblox-aware Luau LSP typecheck | PASS: HotbarController, MobileControlLayout and HotbarGui; fresh Rojo sourcemap and Roblox definitions. |
| StyLua | PASS: all three changed Luau files. |
| `git diff --check` | PASS. |
| Rojo 7.7 build | PASS. |
| Same-build fresh joins, tap equip and late pickups on physical phone | PENDING: Collin. |

The lookup regression holds the real mobile layout pass at its fake CAS
boundary. With that lookup still suspended, the hotbar starts empty, accepts a
production pre-plot Ice Gun grant or an ingredient, takes over and equips by
activation. A second late pickup also populates and equips before lookup returns.
Completing lookup updates actual clearance without repeating successful CoreGui
disablement. The separate pending-update regression suspends layout after its
inventory snapshot, delivers Tool events, resumes that pass and verifies the
follow-up without another external event. These are controlled injections;
they do not establish the actual v1586 phone cause or native rendered pixels.

Focused commands:

```powershell
python -B tests/run_hotbar_tests.py --luau .validation-tools/luau.exe --case lookup
python -B tests/run_hotbar_tests.py --luau .validation-tools/luau.exe --case updates
python -B tests/run_hotbar_tests.py --luau .validation-tools/luau.exe
python -B tests/run_mobile_control_layout_tests.py --luau .validation-tools/luau.exe
```

Build, sourcemap, baseline snapshot, regression failure logs, validation logs and
LF-normalized source SHA256 manifest are retained outside the diff at
`C:\Users\COLLIN~1\AppData\Local\Temp\blender-hotbar-v1586-8q8782cs`.
The build includes the separately committed StandIdentityController change;
that change is outside this hotbar patch.

## Published acceptance - Collin

Stop Play, sync both changed runtime modules through `default.project.json`,
then start a fresh client. No additional instance cleanup or setup is needed
for this follow-up. Record the exact synced source commit and any uncommitted
changes, publish once, and record the **joined place version** separately.
Use that one new published version for every row below. An old v1586 join
cannot validate this uncommitted patch.

| Check on that published build | Status |
| --- | --- |
| Fresh portrait as Eatandpoop with early pre-plot Ice Gun: custom visible and tappable without rotation/commands; native bar visibly gone after takeover | PENDING |
| Fresh landscape with the same early Ice Gun: same result | PENDING |
| Fresh empty joins in each orientation, then late Ice Gun and ingredient pickup: slots appear, tap equips, no rotation/command needed | PENDING |
| Further late pickups after takeover: existing row updates, no duplicate bar or repeated native handoff | PENDING |

Inspect the actual bars and tap response. The existing admin-only
`;hotbardebug` remains read-only and can record the joined version and current
inventory snapshot after normal startup. It is not required to trigger startup
or pickups. Reply with the joined version and pass/fail for each scenario.

Source synced for v1586: **UNKNOWN**.
Source synced for this fix: **PENDING**.
New published version actually joined: **PENDING**.
Physical phone release acceptance: **PENDING**.
