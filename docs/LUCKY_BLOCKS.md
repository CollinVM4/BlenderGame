# Lucky Blocks — Pass 1

This is the Pass 1 foundation record. [Pass 2](LUCKY_BLOCK_ROULETTE.md) now adds
roulette presentation and supersedes the original default-model Rojo mapping:
the template is preserved as a Studio-authored asset and is no longer synced from
`assets/luckyblock/LuckyBlock.rbxmx`. The runtime world spawning/pickup/animation
behavior below is unchanged; roulette does not apply buffs.

Pass 1 spawns instant world pickups, selects a server-owned reward, and publishes
the result. It does not apply buffs, start buff timers, grant inventory items, or
display a roulette. Duration values are provisional metadata for a later pass.

## Files

| Path | Responsibility |
| --- | --- |
| `src/shared/Constants/LuckyBlockConfig.luau` | Asset names, reward IDs/weights/durations, spawn target, respawn range, pickup checks, animation tuning |
| `src/server/Services/LuckyBlockService.luau` | Marker lifecycle, authoritative claims, reward selection, stock cap and delayed replacement |
| `src/client/Controllers/LuckyBlockPresentationController.luau` | Smooth local bob/rotation and streamed tag discovery |
| `assets/luckyblock/LuckyBlock.rbxmx` | Reusable gold question-mark cube; synced to ServerStorage by Rojo |
| `src/server/init.server.luau`, `src/client/init.client.luau` | Independent service/controller startup |
| `default.project.json` | Template mapping; preserves Studio-authored sibling templates |
| `tests/lucky_block.spec.luau`, `tests/run_state_tests.py` | Focused authoritative suite and manifest registration |

The implementation reuses `WorldUtil.BindTag` and `WorldUtil.Near`. Existing
ingredient records, pickup components, rare/mystery spawners, farm management,
inventory ownership and loose-item cleanup are unchanged. Lucky Blocks never
receive ingredient tags or enter the inventory registry. Only Lucky Block clones
owned by the service are retired by its lifecycle.

## Exact Studio setup

Rojo supplies the template. Author the spawn markers in your existing place:

```text
ServerStorage
└── LuckyBlockTemplates (Folder)
    └── LuckyBlock (Model, Archivable = true, PrimaryPart = Root)
        └── Root (Part, 3 × 3 × 3)
            └── QuestionMark (SurfaceGui)
                └── Label (TextLabel, Text = "?")

Workspace
├── LuckyBlockSpawns (Folder, authored in Studio)
│   ├── Spawn01 (Part, tag: LuckyBlockSpawn)
│   ├── Spawn02 (Part, tag: LuckyBlockSpawn)
│   ├── ...
│   └── Spawn10 (Part, tag: LuckyBlockSpawn)
└── LuckyBlocks (Folder, runtime-created)
    └── LuckyBlock (runtime clones; tag: LuckyBlockWorld)

ReplicatedStorage
└── Shared
    ├── Constants
    │   └── LuckyBlockConfig (ModuleScript)
    └── Events
        └── LuckyBlockPickedUp (RemoteEvent, runtime-created)
```

Place **8–12 markers**; ten is the suggested starting layout. Their folder and
names are organizational: the server discovers the `LuckyBlockSpawn` tag on each
BasePart anywhere in Workspace. Do not put ingredient spawn tags on these markers.
Set marker properties to `Anchored = true`, `Transparency = 1`, `CanCollide = false`,
`CanTouch = false`, and `CanQuery = false`. A `1 × 1 × 1` marker centered half a stud
below a floor surface puts its top on the floor. Keep its local Y axis upright.
Use its CFrame for the spawn location and initial yaw.

**No authored attributes are required** on markers or the template. The server
places the model pivot three studs above the marker's top. With the supplied
template, `PrimaryPart = Root` places the pivot at the cube center. A custom
template should use a centered root and the same pivot relationship so proximity
and visible placement agree. Decorative parts can be nested under the Model;
the service anchors every part and disables collision/touch/query. It strips copied
tags, scripts, ModuleScripts and ProximityPrompts from clones before publication.
Keep the template purely visual and do not embed Tools or gameplay constraints.

To use another model, add an archivable Model under `ServerStorage.LuckyBlockTemplates`,
set its PrimaryPart, and change `ModelName` in the shared config. Both folder and
model names are configurable. Missing/invalid templates warn once and retry while
preserving pending stock, without blocking other systems. Edit the source asset
to change the Rojo-managed default model; Studio edits to it can be overwritten
by a later sync.

Runtime clones receive `LuckyBlockOrigin` (CFrame) and `LuckyBlockSpawnTime`
(server-time number) for presentation. Do not author or use them as ownership
proof. The client retries reading these attributes each render frame to tolerate
replication order. Tagged models added later or streamed back in join the animation.

### Multipart imported model compatibility

The current animation moves the entire tagged Model with `Model:PivotTo`, so
Parts/MeshParts in nested Models or Folders move together. No particular `Root`
or `Visual` child name is required. Welds are not needed for this anchored cosmetic
movement: every descendant BasePart is anchored by the server. Keep the imported
visuals inside the single template Model; external geometry will not follow it.

Preserve these authoring assumptions:

- Set the outer template Model's PrimaryPart to an archivable BasePart descendant
  at the intended visual/pickup center. An invisible helper Part is suitable. Keep
  the Model and all intended cloned descendants archivable.
- Use an upright, centered root with `PivotOffset = CFrame.identity` for the
  simplest match to the default. Model pivots follow the PrimaryPart's pivot;
  editing `Model.WorldPivot` alone does not override an assigned PrimaryPart.
  See [Roblox pivot tools](https://create.roblox.com/docs/studio/pivot-tools).
- Pickup uses `PrimaryPart.Position`, while spawn placement, reward-event Position
  and client rotation use the model pivot. A translated PrimaryPart.PivotOffset
  separates those centers and can make the visible block orbit the pickup center.
  A rotated pivot offset can change the imported art's intended orientation. Center
  the geometry relative to the root instead of compensating with a displaced pivot.
- Pickup remains a four-stud sphere around the static server PrimaryPart, regardless
  of the model's size, bounding box or helper root size. The client-only 0.5-stud bob
  does not move that sphere. Scale unusually large imports and check reachability;
  the current three-stud spawn height does not adjust for imported dimensions.
- With StreamingEnabled, set the outer template's `ModelStreamingMode = Atomic`
  so its root and multipart visuals stream together. The current controller checks
  Model ancestry and presentation attributes, without waiting for every mesh or
  the PrimaryPart to arrive. A non-atomic import can temporarily animate an
  incomplete model. See [Roblox instance streaming](https://create.roblox.com/docs/workspace/streaming).

No runtime animation or pickup changes were needed for a correctly authored static
multipart model. An actual imported asset still needs Studio validation: check
relative part placement during rotation, centered pickup reach, floor clearance,
two-client collection, and streaming out/back in. Skinned/deforming animation is
outside this static-model compatibility inspection.

## Behavior and configuration

Five random distinct markers receive initial stock. `Spawn.ActiveLimit` can be
set to four through six. The limit includes active blocks and reserved replacement
slots, so rapid pickups cannot schedule extra stock. The visible count can fall
below the target during cooldown or when fewer markers are available.

Each removal reserves exactly one replacement for a randomized **25–40 seconds**
later, then chooses a currently unused authored marker. A block can return to the
same marker, but replacement is not tied to that location. Server load/polling may
delay publication past a deadline; the poll adds up to 0.15 seconds under normal
conditions. No replacement appears early. Missing markers/assets retain pending
slots until authoring becomes usable. Untagging/moving a marker out of Workspace
retires its active stock; externally destroyed or reparented clones also replenish
through the same capped lifecycle, without a reward.

The server checks physical root proximity every 0.15 seconds. A connected player
with a living Humanoid and an unlocked gameplay action state must be within four
studs of the static server block root. A successful claim applies a 0.75-second
per-player pickup cooldown. No client pickup request, position, reward or timer is
accepted. The block's record is removed before destruction or result publication;
competing/reentrant claims fail. The visible block bobs locally by 0.5 studs over
2.5 seconds and rotates 45 degrees/second. There is no server Heartbeat animation.

| Reward ID | Weight / percent | Duration metadata (seconds) |
| --- | ---: | ---: |
| DoubleCash | 18 | 30 |
| SuperJump | 22 | 12 |
| RainbowRampage | 8 | 10 |
| MegaBat | 15 | 15 |
| IngredientMagnet | 20 | 15 |
| Invincibility | 17 | 8 |

The server uses its own loaded config table for every selection. Weights total
100 initially; selection also supports other positive totals. Keep reward weights
positive, durations nonnegative, and timing/animation periods positive when tuning.

The collector receives `Shared.Events.LuckyBlockPickedUp.OnClientEvent` with:

```luau
{
    RewardId = "DoubleCash", -- server-selected string
    DurationSeconds = 30,   -- metadata only, no effect or running expiry
    Position = Vector3.new(...), -- server spawn-pivot position
}
```

This is an output-only notification. Pass 1 has no consumer UI or roulette; future
presentation can subscribe to it. Future authoritative effects must be applied
on the server and must not treat a client response to this event as a grant.

## Validation

Run `python tests/run_state_tests.py --luau <luau.exe> --suite lucky-block`.
The suite loads the real service and real `WorldUtil` with engine doubles. It covers
missing assets/recovery, five-at-ten spawning, distinct markers, distance/death/lock
rejection, unregistered objects, simultaneous and reentrant single claims, per-player
cooldown, automatic proximity pickup, reward/weight boundaries, randomized delay
bounds, external removal/reparenting, marker retirement, stale timers, and marker
scarcity. It cannot prove native physics or replication behavior.

Validation for this pass:

- Lucky Block focused suite: PASS (51 behavioral assertions), including exact
  `LuckyBlockPickedUp.DurationSeconds` values for all six rewards and unchanged
  weighted selection boundaries.
- Existing ingredient cleanup, farm and rare/mystery announcement integration suites: PASS.
- Existing ingredient `world` suite: FAIL at `InventoryService:721`, missing fixture
  `TycoonService.GetPlot`; reproduced unchanged from a clean HEAD archive. Unrelated
  production code was not changed to address it.
- StyLua on new/changed Lucky Block Luau and bootstraps: PASS.
- Rojo build and fresh sourcemap: PASS.
- Roblox-aware typecheck of the three new Lucky Block modules: PASS.
- Roblox-aware full `src` typecheck: 41 unique existing diagnostics; a separate copy
  of the current workspace with this feature removed produces the same 41 and zero
  new diagnostics. Full-project typecheck therefore remains red.
- Runner self-tests: 1/5 pass; the same four failures reproduce from a clean HEAD
  archive. Their hard-coded suite lists/order and VFX source detection are stale;
  the new manifest entry also appears in the existing state-list mismatch. These
  unrelated runner assertions were left unchanged.
- Studio playtest: not run; use the checklist below.

Build, sourcemap and validation logs were saved under the temporary
`BlenderGame-luau-tools` directory.

The duration metadata follow-up changed only config durations, event-payload test
expectations, and this guide. Its focused suite, StyLua, feature typecheck, fresh
sourcemap and Rojo build all pass. Full `src` typecheck was compared against a
separate snapshot using the pre-follow-up config: both report the same 41 unique
existing errors, with no new errors. Reward weights and runtime pickup/animation
code remain unchanged. Follow-up logs use the `lucky-block-followup` filename prefix.

## Studio validation checklist

1. Sync Rojo. Verify the reusable model's PrimaryPart is Root, and place/tag ten
   accessible, well-separated markers. Start a server with two clients; confirm
   five blocks appear at distinct markers and no pickup prompts exist.
2. Verify smooth floating/rotation on both clients. Inspect server roots: they
   remain anchored at the authored spawn position. With StreamingEnabled, leave
   and return to an area and verify animation resumes without duplicates.
3. Walk into a block. Confirm it disappears for both clients and the collector
   receives exactly one result. Observe the RemoteEvent with a temporary local
   listener if needed; no buff or roulette should run.
4. Have both players reach the same block together. Confirm exactly one receives
   a result. Rapidly visit neighboring blocks; one player cannot claim twice
   within 0.75 seconds, and can collect after that cooldown.
5. Stand far away, die/reset, and test a gameplay action lock near a block. Confirm
   no invalid pickup is granted. Firing `LuckyBlockPickedUp:FireServer(...)` with
   fabricated positions/rewards must have no effect.
6. Time several replacements: they appear after 25–40 seconds plus polling/server
   delay, always at authored markers, never exceeding five active blocks. Repeat
   after collecting every active block.
7. Untag/remove an occupied marker, destroy/reparent a runtime clone, and remove
   all markers. Confirm no reward is granted for administrative removal, no block
   survives a removed marker, and no delayed callback recreates unavailable stock.
   Restore markers and confirm pending stock recovers within the cap.
8. Remove the template or its PrimaryPart before starting. Confirm a clear warning
   and that ingredient/farm systems still start. Restore it and verify stock recovers.
9. Confirm existing ingredient prompts, ordinary/rare/mystery respawns, farm
   harvest, carry/stash ownership and loose-item cleanup still behave normally.
