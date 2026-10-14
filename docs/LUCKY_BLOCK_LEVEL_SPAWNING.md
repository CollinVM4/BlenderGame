# Lucky Block level spawning

The server initially spawns one Lucky Block in each configured level, for four
active blocks across ten markers. A collected, destroyed, reparented, or removed
block leaves only its own level empty for a randomized 180–240 seconds. A delayed
callback then chooses a random available marker in that level, avoiding the last
marker when another eligible marker exists. No player needs to be nearby.

## Recommended Explorer hierarchy

Move your existing markers into these groups without changing their world positions.
Both the spawn container and level groups may be Folders or Models. Keep the
`LuckyBlockSpawn` tag on **each BasePart marker**, not on the groups.
The 3/3/2/2 distribution below is an example; assign markers according to their
actual progression area and give every level at least one marker.

```text
Workspace
├── LuckyBlockSpawns (existing Folder or Model)
│   ├── Level0 (Folder or Model)
│   │   ├── Spawn01 (existing Part, tag: LuckyBlockSpawn)
│   │   ├── Spawn02 (existing Part, tag: LuckyBlockSpawn)
│   │   └── Spawn03 (existing Part, tag: LuckyBlockSpawn)
│   ├── Level1 (Folder or Model)
│   │   ├── Spawn04 (existing Part, tag: LuckyBlockSpawn)
│   │   ├── Spawn05 (existing Part, tag: LuckyBlockSpawn)
│   │   └── Spawn06 (existing Part, tag: LuckyBlockSpawn)
│   ├── Level2 (Folder or Model)
│   │   ├── Spawn07 (existing Part, tag: LuckyBlockSpawn)
│   │   └── Spawn08 (existing Part, tag: LuckyBlockSpawn)
│   └── Level3 (Folder or Model)
│       ├── Spawn09 (existing Part, tag: LuckyBlockSpawn)
│       └── Spawn10 (existing Part, tag: LuckyBlockSpawn)
└── LuckyBlocks (Folder created by the service; four runtime clones normally)

ServerStorage
└── LuckyBlockTemplates (existing Folder)
    └── LuckyBlock (existing archivable Model with PrimaryPart)
```

Marker names are arbitrary. Groups must be named exactly `Level0` through `Level3`
and be direct children of `LuckyBlockSpawns`; markers may be nested inside them.
Keep existing marker CFrames, sizes, tags and properties. Recommended marker
properties remain Anchored=true, Transparency=1, CanCollide=false, CanTouch=false,
CanQuery=false. Do not add ingredient spawn tags. No asset, UI, sound, or Rojo
mapping changes are needed. The template remains authored in Studio.

For a flat hierarchy, leave every marker where it is and add a **Level** attribute
to each BasePart: Number `0`, `1`, `2`, or `3`, or String `Level0`, `Level1`, `Level2`,
or `Level3`. Explicit attributes override grouping. Existing tagged markers outside
the container also support this attribute. Invalid attributes are skipped with a
warning. Untyped legacy markers outside level groups default to Level0 and warn;
they cannot supply the other three levels until assigned. Invalid level group
classes are skipped. Grouping alone does not turn untagged parts into markers.

## Configuration and lifecycle

Central tuning lives in `src/shared/Constants/LuckyBlockConfig.luau`:

| Setting | Default |
| --- | ---: |
| `Spawn.MaxActivePerLevel` | 1 |
| `Respawn.MinRespawnSeconds` | 180 |
| `Respawn.MaxRespawnSeconds` | 240 |
| `Spawn.RetrySeconds` | 5 |

Keep MaxActivePerLevel at 1 for the four-block global target. The cap is represented
by reserved slots; each slot owns at most one model or one pending callback.
Retirement commits ownership removal before destruction and reward publication,
so simultaneous/replayed claims cannot create extra rewards or replacement timers.
Unexpected removal uses the same cooldown and gives no reward. Marker untagging
or departure from Workspace retires its block through the existing lifecycle.

Each missing level warns by name. Missing markers or an invalid template retain
their slot and retry every five seconds; repairing the configuration replenishes
the level without requiring players or restarting the server. Successful initial
population happens synchronously during Init when markers and template are valid.
Timer execution can be delayed by server load, but never intentionally shortened.
Spawning has no per-frame polling; the existing 0.15-second authoritative proximity
pickup poll is preserved. Rewards, weights, duration metadata, remote payloads,
reveal UI, animations, visuals, collision settings and sounds are unchanged.

## Validation

Run `python tests/run_state_tests.py --luau <luau.exe> --suite lucky-block`.
The authoritative suite covers four-level initialization/caps across ten markers,
folder/model and flat-attribute discovery, level isolation, duplicate/reentrant
claims, timer bounds including both endpoints, location rotation, missing/invalid
levels, late marker/asset recovery, destruction/reparenting, and unchanged weighted
reward and nearby reveal payloads. It uses engine doubles; Studio replication and
rendering still need a Play check.

The existing roulette, view and controller presentation suites were run separately.
Their failures reproduce with the pre-change service/config: imported visual name,
world-model beat replacement, and completion cleanup assertions respectively.
They are isolated from the passing authoritative suite; presentation production
code and tests were not changed in this pass.

Studio smoke check: start a server with all four groups and verify one block per
level. With two players, collect Level2 together and verify one reveal/reward,
three remaining blocks, and a Level2 replacement at another marker after 3–4
minutes. Destroy one runtime clone and verify only its level replenishes without a
reward. Confirm the existing reveal, sound and animation sequence visually.
