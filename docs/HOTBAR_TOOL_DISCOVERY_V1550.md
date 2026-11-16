**v1550 Tool discovery follow-up: diagnostics-only build**

The zero-slot phone failure is still unverified and unfixed. This checkout adds
a read-only inventory snapshot to the existing admin-only `;hotbardebug` and fixes
a separately reproduced stale readiness message. It must not be described as a
completed Ice Gun discovery fix or phone acceptance.

Incoming source was clean `main` at
`e3d749c69a61dba7f3f8c7412b7bb9d5239e4343`. There were **no incoming staged,
unstaged, or untracked changes**. The earlier rebuild's uncommitted handoff was
subsequently committed as `f9a874bdb5c662c93b616c6a63ef454e4f2d9fed`.
The incoming HotbarController, HotbarGui, and MobileControlLayout sources also
match the embedded sources in the saved rebuild Rojo build byte-for-byte after
normalizing line endings. The later `58f7694` client ClaimProfile initialization
is present and preserved. The old handoff's six-file digest therefore does not
identify this incoming tree.

The failing joined place version **1550** comes from Collin's supplied phone
evidence, not an independently inspected running session. No new Studio or
physical phone session was run here. Collin still needs to sync and publish.

Source trace:

1. `default.project.json` maps `src/client` into StarterPlayerScripts.Client and
   `assets/icegun/IcicleGun.rbxmx` into ServerStorage.Weapons.IcicleGun.
   `init.client.luau` spawns HotbarController.Init before yielding unrelated
   controllers. Start constructs PlayerGui.BlenderHotbar, captures Character,
   discovers Backpack, binds container child events, and queues reconciliation.
2. `src/server/init.server.luau` invokes IceGunService.AddPlayer and
   ApplyCharacter independently of plot claims. IceGunService.issueTool clones
   the sanitized Tool, sets **boolean** IceGunWeapon=true, registers the issued
   instance, then parents it into Backpack. A purchase may subsequently equip it.
   The serialized template itself has no IceGunWeapon attribute.
3. collect scans the observed Backpack and Character only while Character is
   current and not removing. owned additionally validates the Tool's immediate
   parent and Backpack's Player parent. Raw Tools receive identity-based
   deduplication, ordering sequence, and ancestry/equip/name/classification
   attribute watchers before Classify runs. IceGunWeapon must equal boolean true;
   a Tool name alone does not classify an Ice Gun. Existing late-attribute
   watchers already re-run collection.
4. update creates or retains each accepted Tool's slot, sets the Ice artwork and
   label, selects Character Tools, lays out the bar, and requests takeover only
   when the existing view/character gates pass. Native access remains until then.
5. In the baseline, requestCore could return early for an already completed
   native target without refreshing the readiness reason. Thus `waiting for
   first Tool` could describe an earlier update. The corrected reason is purely
   diagnostic; API targets, attempts, retry timing, and ownership are unchanged.

The previous fixture named its synthetic Tool `Ice` and set IceGunWeapon before
parenting it. New discovery cases use the production IceGunService.AddPlayer /
GrantIfOwned path with confirmed fake Marketplace ownership, no plot dependency,
and the actual Rojo-mapped template's class/name hierarchy and boolean properties.
The engine boundary still doubles geometry, commerce, events, and replication.
All 10 new discovery cases pass on **both** incoming production source and the
diagnostic checkout. No step dropping the real phone Tool has been identified.
The stale-reason regression fails on the incoming source and passes here; it is
not a regression proving the zero-slot failure fixed.

Changed files:

| File | Change |
| --- | --- |
| `src/client/Controllers/HotbarController.luau` | Current readiness reason; tagged inventory event/update metadata; read-only live/observed container and Tool snapshot. |
| `tests/hotbar.spec.luau` | Real-grant arrival/parent matrix, late classification, populated late Backpack, diagnostic discrimination and read-only behavior. Existing lifecycle tests retain Character/Backpack replacement coverage. |
| `tests/run_hotbar_tests.py` | Loads real grant modules and mapped template; discovery/diagnostic selectors; `--source-root` compares unchanged snapshots without replacing local work. |
| `docs/HOTBAR_TOOL_DISCOVERY_V1550.md` | Evidence, validation, capture instructions, and pending acceptance. |

Validation on November 16, 2026:

| Check | Result |
| --- | --- |
| Incoming hotbar runner | PASS: 31 cases, 285 checks. |
| New discovery group against isolated incoming source | PASS: 10 cases, 95 checks; phone zero-slot failure not reproduced. |
| Stale-readiness diagnostic regression against incoming source | FAIL as expected: reports waiting for first Tool instead of waiting for selectable character. |
| Current complete hotbar runner | PASS: 46 cases, 407 checks, 0 failures. |
| Focused Roblox-aware Luau LSP analysis | PASS: 3 hotbar runtime modules, 0 type errors; fresh Rojo sourcemap and installed Roblox definitions. |
| StyLua | PASS: both changed Luau files. |
| git diff --check | PASS. |
| Rojo 7.7 build | PASS. |
| Zero-slot discovery regression and fix | PENDING: requires the failing runtime snapshot. |
| New published version / phone acceptance | PENDING: Collin. |

Coverage includes early/late arrivals in portrait and landscape, both initial
Tool parents (including equipped startup), repeated tap equip/unequip with one
identity slot, nil/string/late boolean classification, Character before Backpack,
Backpack before Character, and replacement Character/Backpack lifecycles.
Snapshot tests deliberately withhold lifecycle events to verify discrimination;
they do not establish that Roblox missed such events on the phone.

Artifacts are retained outside the diff at
`C:\Users\COLLIN~1\AppData\Local\Temp\blender-hotbar-v1550-0ebb3067a9cd4e06b61e205a8d9bb352`:
base commit, incoming clean status/empty working-tree patch, base archive and
isolated source, current patch, source manifest, validation results, sourcemap,
and `BlenderGame-hotbar-v1550-diagnostic.rbxlx`.

The incoming LF-normalized six-file runtime digest is
`8a0890eb4a4a93ebdcca952901c864d457fbff388d28c87d801beb6710a2ee1a`.
The tested diagnostic runtime digest is
`074536b25b8aa31dde31cdc73a969d4045554589e0ddf609203230a8db74fd3c`.
Digest algorithm matches the earlier handoff: SHA-256 of path + NUL + LF-normalized
UTF-8 contents + NUL, in order: HotbarController, HotbarGui, MobileControlLayout,
init.client, default.project.json, Framewisp_Hotbar.prepared.rbxmx.
This is base revision plus local changes, with no new commit created here.

Collin's next capture:

1. Stop Play, sync **this checkout's default.project.json**, start a fresh session,
   and publish the diagnostics build to the intended place. No new Studio
   objects, attributes, entitlements, or server commands are required. Retain
   existing admin authorization. Record the exact source commit plus local patch
   or runtime digest at sync.
2. Fresh join as **Eatandpoop** with the account's ordinary pre-plot Ice Gun.
   When the failure is visible, **before tapping a Tool, rotating, claiming a
   plot, respawning, or using a grant command**, enter the single command:

   ```text
   ;hotbardebug
   ```

3. Capture the entire one-report message from chat or client output. Keep these
   exact fields:

   | Line | Required fields |
   | --- | --- |
   | `[Hotbar]` | `place v...`, orientation, `owner`, readiness reason, `safe`, `slots`, `visible`, `native`, `write`, `read` |
   | `inventory` | `update`, `trigger`, `accepted`, `age`, `queued`, `pending`, `removing` |
   | `BP` and `CH` | `live`, `observed`, `match`, `raw`, `observedRaw` |
   | Every `Tool` | identity, `name`, `parent`, `IceGunWeapon=value:type`, `class`, `gate`, `watched`, `lastAccepted` |

   `BP` is Backpack; `CH` is Character. `#` identifiers compare actual instances
   within this report even when their paths/names match. raw counts and Tool
   lines come from both live and observed containers. `watched` means Tool
   signals were bound; `lastAccepted` refers to the last completed collection.
   The snapshot performs no collect, rebind, equip, attribute write, or CoreGui
   write before reporting. Legacy `hide` also remains a diagnostic read.
4. A mismatch identifies stale container observation. A live owned Tool with
   `class=reject:...` identifies filtering. A live class=Ice Tool with
   lastAccepted=false, together with queued/pending/age/update, distinguishes an
   unprocessed or stale collection. Supply this complete report to target the
   normal event path; do not infer a filtering or binding fix without it.

After a verified fix is implemented and tested, Collin publishes that checkout
once and repeats fresh **portrait and landscape joins on the same published
version** as Eatandpoop. Before any command/rotation/plot claim, the pre-plot gun
must appear in the custom bar and tap equip/unequip; native Backpack pixels must
be gone after takeover. Test already-equipped startup separately where QA setup
supports it. Record the source revision and actual joined PlaceVersion for every
row. CLI CoreGui doubles/readback do not establish phone pixels or tap routing.

| Release record | Status |
| --- | --- |
| Reported failing phone version | 1550, supplied evidence. |
| Diagnostic source actually synced/published | PENDING, Collin. |
| Diagnostic actual joined place version and full report | PENDING, Collin. |
| Verified zero-slot cause, normal-path fix, failing-baseline discovery regression | PENDING. |
| Fixed source revision and actual joined place version | PENDING. |
| Same-build fresh portrait / fresh landscape / supported equipped-start phone checks | PENDING. |

Slot sizing, safe-area layout, ordering, identity deduplication, Humanoid selection,
CoreGui retry policy, and Sprint Pass 2 were left unchanged.
