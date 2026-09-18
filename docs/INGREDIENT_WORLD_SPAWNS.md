# Authored ingredient world spawns

## Architecture and migration

`IngredientService.Spawn(id, spawnCFrame, owner?, claimable?)` remains the one
authoritative creation API. Normal markers, rare markers, MarketService,
DevContentService, inventory drops and throws all use it. `CreateVisual(id)` only
clones cosmetic geometry; it does not grant inventory or create a world record.
`Resolve(descendant)` walks ancestors to the private server record, not an attribute
or tag supplied by a client. The top-level spawned Model/BasePart receives
`IngredientWorldItem`, `IngredientId`, `WorldItemId`, and `OwnerUserId` metadata.

Previously, IngredientSpawn already had an explicit ID and per-marker timer, but
MarketService selected weighted rarity pools, anchored stock, and granted invisible
inventory through a pedestal prompt. MarketPedestals now require an explicit ID,
produce unanchored claimable stock, and use the stock's ordinary CarryPrompt.
The server-only `MarketService.Claim` API also equips one visible ingredient.
`SelectIngredient` was removed (no remaining repository callers); `SpawnDrop`
now requires an explicit ID. No random rarity selection is used for normal spawns.
The unused historical Economy.RarityWeights setting is not read by this path.

Existing IngredientSpawn parts need no migration. Existing MarketPedestals need
`IngredientId` set before Play and optionally `RespawnSeconds`. Missing/unknown
IDs warn and do not spawn. Existing tagged Model pedestals still resolve their
PrimaryPart (or the old WorldUtil fallback); put configuration on that resolved
part. Prefer tagging a BasePart directly for predictable placement. Remove any
manually authored old ClaimPrompt. Runtime no longer creates a pedestal prompt.
To convert a pedestal to the standard marker lifecycle, remove `MarketPedestal`
and apply `IngredientSpawn` to its part. Do not apply multiple spawn tags to one
marker. Duplicate normal/rare bindings and directly tagged market/marker overlap
are guarded, but a separately tagged Model and child remain distinct fixtures.

`IngredientSpawn.Bind` shares the single-active-item lifecycle between normal and
announced markers. The rare adapter creates a server-output-only RemoteEvent at
`ReplicatedStorage.Shared.Events.RareIngredientSpawned`. It broadcasts the explicit
ID, definition DisplayName, Type, and marker LocationName after creation succeeds.
The client controller shows an eight-second banner; a newer message replaces it.
There is no inbound event handler, inventory grant, blender grant, or event scheduler.
Active item state and timers remain private to the server component.

## Ingredient assets in Studio

1. Create `ServerStorage.Ingredients` and put a Model or BasePart directly inside
   it, named exactly like a key in `src/shared/Constants/Ingredients.luau`.
   `GoldenApple` is now defined as Rare, with Fruit/Sweet/Healthy/Yellow tags.
   Supply your authored GoldenApple asset; this change does not create fruit art.
2. Models need at least one descendant BasePart/MeshPart. Prefer a PrimaryPart
   centered on the fruit body, with the model pivot positioned and oriented for
   carrying and spawning. A model without a PrimaryPart gets a tiny invisible,
   noncolliding root at its authored pivot. Descendant order never selects its root.
3. Author scale in studs. Spawning does not rescale or rewrite mesh geometry.
   `PivotTo(spawnCFrame)` places the asset's pivot at the requested frame; geometry
   retains its position/orientation relative to that pivot. The supplied frame
   replaces the template's absolute world rotation, as before. Orient the authored
   pivot axes and marker axes accordingly. Avoid pivots far away from the fruit.
4. Parts become unanchored and queryable, and all parts are welded to the chosen
   root. Network ownership initially belongs to the server. Give visible parts
   appropriate CanCollide/collision geometry so fruit rests on the map. Imported
   multipart assets need no manual welds. Avoid articulated rigs, external joints,
   and constraints to objects outside the template: ingredients are rigid props.
5. Assets should contain visual geometry/materials/textures. Cloned tags, prompts,
   click detectors, and scripts are removed; gameplay supplies its own interaction.
   The original ServerStorage template is untouched. Missing or empty/invalid
   templates retain the existing colored 1.5-stud cube fallback for valid IDs.

Rojo maps code only; assets and Workspace fixtures must be authored and saved in
the Studio place. No Rojo project change or automatic map placement is required.

## Normal individual markers

Place an anchored BasePart in Workspace. Tag the part `IngredientSpawn`. Set all
attributes before Play (or before tagging); configuration is read when attached.
After editing attributes during Play, remove and re-add the tag to rebind.

| Attribute | Example | Behavior |
| --- | --- | --- |
| IngredientId (String) | Strawberry | Required definition ID; no rarity pool |
| RespawnSeconds (Number) | 10 | Positive finite delay; default 5 |
| FreezeSpawnedItem (Boolean) | true | Optional; holds this marker's runtime stock fixed until successful pickup. Missing/false keeps normal physics. |

The pivot spawns three studs above the marker's local top face. This preserves
existing marker placement; allow extra clearance for large authored fruit. Use a
transparent noncolliding marker over a solid surface if a visible block is unwanted.
Place common ingredients deliberately on lower rings and rarer ingredients at
specific higher/hidden locations, each with its own timer. Normal spawns are silent.

Legacy MarketPedestal uses IngredientId/RespawnSeconds but keeps its previous one-stud
top clearance and default Economy.MarketRespawnSeconds (12). Its one-second poll
can add up to one second before starting/refilling the cooldown after ordinary pickup.

## Jump 3 Rainbow Cloud rare marker

Place one anchored BasePart over the rainbow-cloud island's solid landing surface.
Tag it **only** `AnnouncedIngredientSpawn`. It uses the same three-stud pivot offset
and ordinary physical carry path. Location and island access are authored in Studio;
this refactor adds no jump progression or island geometry.

| Attribute | Example | Behavior |
| --- | --- | --- |
| IngredientId (String) | GoldenApple | One explicit ingredient |
| LocationName (String) | Rainbow Cloud | Announcement text; defaults to marker name |
| RespawnSeconds (Number) | 300 | Fixed cooldown when no valid min/max pair is set |
| MinRespawnSeconds (Number) | 240 | Optional minimum delay |
| MaxRespawnSeconds (Number) | 360 | Optional maximum, at least the minimum |
| FreezeSpawnedItem (Boolean) | true | Same optional freeze behavior as normal ingredient markers |

A valid positive finite min/max pair overrides RespawnSeconds for rare markers
only. Missing/invalid fixed delay defaults to 5, so configure rare cooldowns
explicitly. No Rarity check overrides the explicit ID; designers choose the rare
ingredient. The first item spawns immediately when the marker binds. Notifications
are transient appearance announcements to connected listeners, not replayed to late
joiners. Normal marker respawns never send this event.

There is one active spawned item per marker. Moving it within Workspace does not
refill the marker. Pickup consumes that registered instance and creates the existing
one-item Tool reservation, which starts the marker cooldown. Dropping or throwing
creates an independent ordinary world item and does not announce again. Thus a
winner can carry away stock while the location later respawns. Stashing/blending
still require the existing physical interactions. There is no multi-item carry.

Consumption, destruction (including the existing 120-second world-item lifetime),
or leaving Workspace retires stock and starts the cooldown. Reparented stock is
destroyed to prevent reintroduction of duplicate stock. Removing a marker/tag cancels
its pending timer and destroys its current loose stock, without affecting a Tool
already carried away. A rare item left untouched therefore expires after 120 seconds
and respawns after its configured delay.

## BasePart assumptions audited

| Code | Finding / handling |
| --- | --- |
| IngredientService.CreateVisual | Already cloned Models/BaseParts; first descendant was only an existence check. Now sanitizes cloned component tags/interaction/scripts. |
| IngredientService.Spawn | Previously unanchored each part without joining it. Now uses authored PrimaryPart or synthetic pivot root and welds every other part. |
| WorldUtil.Part / Near | Generic fallback still selects a descendant for non-ingredient fixtures. Spawned ingredient Models always have an explicit PrimaryPart before interaction, so this fallback cannot choose an arbitrary fruit part. |
| IngredientPickup | Requires a BasePart to host a prompt, not a BasePart item. Resolves the registered model root. |
| InventoryService.equipVisual | Already loops all descendant parts and welds them to a transparent Tool Handle. Single held reservation stays server-owned. |
| InventoryService.releaseHeld / ReleaseUnit / DropOne | Spawn by ID; velocity uses WorldUtil.Part. A joined assembly now carries every mesh along with the root. Release recreates authored visuals, as before. |
| BlenderInput / BlendService.TryInput | Input zone must be a BasePart. Overlap returns parts but Resolve identifies their registered ancestor Model; one Consume removes the whole ingredient, preventing duplicate ingestion from multiple overlaps. Root frame is used for presentation. |
| IngredientSpawn | Marker itself is intentionally a BasePart for CFrame and top-face Size. Spawned stock is Instance/Model-capable. |
| MarketPedestal / MarketService | Fixture resolves a BasePart for location/distance/config. Stock already typed Instance; removed anchoring and invisible AddUnit transaction. |
| DevContentService | Staging reference must resolve to the plot's unique BlenderInput BasePart. SpawnIngredient and PrepareCombination already call IngredientService.Spawn and return model-capable Instances. |
| Stash / InventoryService stash paths | Slot fixtures are BaseParts; contents are server ID/count state. Withdrawal uses CreateVisual then multipart equip. No world Model is treated as a single part. |
| StashPresentation | Already supports Models, strips interactions/tags, anchors all parts, normalizes pivots, and uniformly scales wrapper bounds. Its miniature display scale/orientation is intentional and unchanged. |
| BlendVFX | Already sanitizes all parts of CreateVisual clones and places cosmetic proxies. It does not create physical inventory. |
| CombatService / Dispenser | Combat delegates physical release to InventoryService; Dispenser delegates ReleaseUnit. Neither directly treats ingredient Models as BaseParts. |

The current batch limit stays three. No merge system exists in this path and none
was added. Future tiers will need server record/reservation/stash metadata changes;
ID-only drop/stash restoration must not be mistaken for persistence of arbitrary
per-instance tier attributes.

## Verification

Run `python tests/run_state_tests.py --world-only --luau <luau executable>` for the
focused real-service/component checks using the existing fake engine boundary.
Studio acceptance still needs two players: contest one rare pickup, carry/drop/throw
a multipart fruit, throw a leaf-first overlap into the blender, deposit/withdraw
from stash, verify independent marker timers and server-wide banners, and remove
tags/markers while occupied and while waiting. Check resting collision, welds,
orientation and scale with the actual authored assets. CLI tests cannot simulate
Roblox physics, replication or visual layout.

Validation for this change: 49 focused ingredient assertions, 115 VFX assertions,
and 74 upgrade UI assertions pass. StyLua on all changed/added Luau files, all 53
runtime source compilations, Rojo build, and `git diff --check` pass.

Unrelated existing failures, left unchanged:

- The full state suite fails at `base stamina full at 110`, reproduced before edits.
- Full Roblox-aware Luau LSP analysis reports three type errors in
  `StashPromptController.luau` (36 and 39), plus the nullable `DisplayText` access in
  `CustomerService.luau` (337, reported twice). An isolated HEAD snapshot produces
  the same errors. No changed runtime file has a reported type error.

## Files changed

- `src/server/Services/IngredientService.luau`: template sanitization, deterministic
  model root, rigid assembly, server network ownership.
- `src/server/Services/MarketService.luau`: explicit ID/timer, physical claims,
  retired-stock cleanup, explicit-ID SpawnDrop.
- `src/server/Components/IngredientSpawn.luau`: shared normal/rare lifecycle and
  optional min/max timing, duplicate-binding guard.
- `src/server/Components/AnnouncedIngredientSpawn.luau` (new): server announcement adapter.
- `src/server/Components/MarketPedestal.luau`: ordinary item pickup replaces pedestal prompt.
- `src/server/init.server.luau`: registers rare component.
- `src/client/Controllers/RareIngredientPresentationController.luau` (new): announcement banner.
- `src/client/init.client.luau`: starts presentation controller.
- `src/shared/Constants/Ingredients.luau`: GoldenApple definition.
- `tests/ingredient_world.spec.luau` (new): focused world, carry, blender, stash,
  normal/rare lifecycle, announcement, and market regressions.
- `tests/run_state_tests.py`: focused test entry point and rare adapter source.
- `tests/server_state.spec.luau`: updates market contract and new controller mock.
- `docs/MVP_ARCHITECTURE.md`: replaces obsolete weighted-market description.
- `docs/INGREDIENT_WORLD_SPAWNS.md` (new): audit, setup, migration, and validation report.

## Frozen tree stock

Studio setup (the marker itself must be a BasePart):

```text
Workspace
└── AppleTree
    └── AppleSpawner [tag: IngredientSpawn]
        Attributes:
            IngredientId = "Apple"       (String)
            FreezeSpawnedItem = true      (Boolean)
            RespawnSeconds = 5           (Number, optional)
```

Anchor the marker. Position it so its existing spawn transform,
`AppleSpawner.CFrame * CFrame.new(0, AppleSpawner.Size.Y / 2 + 3, 0)`, places
the apple pivot on the branch. The offset is unchanged. No tree weld or template
anchoring is needed. Use only one spawn tag; `AnnouncedIngredientSpawn` supports
the same Boolean. Market stock remains loose.

`IngredientSpawn.Bind` reads `FreezeSpawnedItem == true` for each new copy and
passes `FreezeUntilPickup` to `IngredientService.Spawn`. Unlike the ID/timer
configuration, changing this Boolean affects the next refill without rebinding;
it does not change existing stock. Spawn marks the registered outer MeshPart or
Model `FrozenUntilPickup = true` and anchors every BasePart, including a generated
pivot root for Models without a PrimaryPart. Only runtime clones change. Existing
welds, tags, identity, mass, collision/touch settings and pickup prompts are retained;
normal spawn preparation still enables CanQuery.

Pickup remains `IngredientPickup` -> `InventoryService.CarryWorldItem`. After
validation and unit reservation, `ClaimWorldItem` calls `Consume(object, true)`:
the service removes registration, unanchors all original parts, clears the frozen
attribute and destroys the consumed world object. `IngredientCarryPresentation.Attach`
clears the cloned visual's attribute and unanchors its parts before joining the
character assembly. The transaction is synchronous, so no physics frame occurs
between release and carry. Failed validation/reservation preserves frozen stock.
Drop/throw creates an ordinary world copy; stash uses the existing ID/count flow.

Vacuum rejects anchored assemblies; blender intake explicitly rejects frozen stock.
Contact does not release it. Existing lifetime expiry, removal, cleanup and respawn
rules still apply. A replacement is frozen again while the marker Boolean is true.

Regression coverage lives in the existing ingredient world, carry, prompt and vacuum
suites. In Studio, additionally verify the visible prompt on a branch, bump/contact
stability, multipart pickup without character anchoring, throw/drop into a blender,
stash round trip, and frozen refill. CLI mocks do not simulate Roblox physics.

Validation for frozen stock: ingredient world/prompt integration passed 176 assertions;
carry passed 221; vacuum passed 642. All 70 source files compiled, changed server
modules passed Roblox-aware Luau LSP checking, StyLua passed on touched Luau files,
Rojo build passed, and `git diff --check` passed. Full-source type checking still
reports four errors in unchanged `StashPromptController.luau` (lines 16, 36 and 39).
The standalone prompt UI suite fails at `rarity Uncommon`; the full state suite
fails at `start clears copies and cancels arrival` in blend VFX. Both test failures
were reproduced in a temporary baseline without the frozen-stock changes. No Studio
physics playtest was performed.

Files changed for this feature:
- `src/server/Components/IngredientSpawn.luau`
- `src/server/Services/IngredientService.luau`
- `src/server/Services/InventoryService.luau`
- `src/server/Services/IngredientCarryPresentation.luau`
- `src/server/Services/BlendService.luau`
- `tests/ingredient_world.spec.luau`
- `tests/ingredient_prompt.spec.luau`
- `tests/blender_vacuum.spec.luau`
- `tests/server_state.spec.luau` (clone physics and MeshPart mock fidelity)
- `docs/INGREDIENT_WORLD_SPAWNS.md`

`AnnouncedIngredientSpawn` and `IngredientPickup` retain their existing adapters;
their shared spawn and inventory paths provide the new behavior.

## Studio Spawn Preview

This is a true **Edit-mode Command Bar utility**, following the other `docs/studio`
authoring tools. It is not a runtime Script or an automatically installed plugin.
`docs/studio/IngredientSpawnPreview.luau` is outside `default.project.json` and is
not included in the Rojo place build. The utility checks `RunService:IsStudio()`
and `RunService:IsEdit()`, and disconnects/removes its visuals on leaving Edit
(including entering Play/Run or a paused test). The container is non-Archivable so
it is excluded from saving and cloning. See Roblox's [RunService API](https://create.roblox.com/docs/reference/engine/classes/RunService)
and [Instance.Archivable contract](https://create.roblox.com/docs/reference/engine/classes/Instance#Archivable).

1. Sync the project with Rojo in Studio and remain in **Edit mode**.
2. Create an anchored BasePart marker and tag it `IngredientSpawn` (or, for an
   announced marker, only `AnnouncedIngredientSpawn`). Configure it like this:

```text
Workspace
└── AppleTree
    └── AppleSpawner [IngredientSpawn]
        Attributes:
            IngredientId = "Apple"        (String)
            FreezeSpawnedItem = true      (Boolean)
            ShowSpawnPreview = true       (Boolean)
```

3. Open Studio's **Command Bar**, paste the entire contents of
   [`studio/IngredientSpawnPreview.luau`](studio/IngredientSpawnPreview.luau), and
   execute it once. The Apple template must exist in `ServerStorage.Ingredients`.
4. Move, rotate, or resize the marker until the translucent apple sits on the
   branch. Updates are live; no retagging or Play session is required. The cyan
   arrow beside the ghost points along the marker's **local forward (-Z)**.
5. Press Play. Previews are removed and the authoritative frozen runtime Apple
   uses the same placement. Pickup/carry/throw/drop are unchanged. After stopping
   Play, paste/run the utility again to start a new editing session.

`ShowSpawnPreview` missing/false creates no ghost and never affects gameplay.
Preview visibility is independent of `FreezeSpawnedItem`, so loose spawns can also
be authored with this tool. Both runtime and preview call
`IngredientSpawn.GetSpawnCFrame(marker)`:
`marker.CFrame * CFrame.new(0, marker.Size.Y / 2 + 3, 0)`.
Both also call the extracted `IngredientGeometry.CreateVisual` path for template
cloning, sanitization and generated Model pivot roots. `IngredientService.CreateVisual`
retains its API. Geometry is not rescaled or reoriented independently of runtime.

Ghosts live under `Workspace._IngredientSpawnPreviews`. Each group has a
`SourceMarker` ObjectValue linking to its actual marker, so duplicate names work.
Parts are anchored, locked, at least 0.5 transparent, and noncolliding, nontouching
and nonqueryable. More-transparent authored parts remain so. Scripts, interaction
objects, joints/constraints and gameplay tags/attributes are removed. Ghosts are
never registered with IngredientService and never receive pickup prompts. Source
templates are untouched; the runtime item remains the only authoritative stock.

Marker CFrame/Size, IngredientId, ShowSpawnPreview, name and ancestry changes update
live. Template property/pivot/geometry changes and template replacement trigger a
coalesced rebuild. Deletion, tag removal, hiding, or an invalid/missing template
removes the ghost; invalid configuration warns once until it changes. The preview
intentionally shows no ghost for missing geometry, even though runtime retains its
existing fallback cube. Fix the template to preview the intended authored asset.

To force a rebuild in the current Edit session:

```lua
_G.IngredientSpawnPreview.Refresh()
```

To remove all previews and disconnect all listeners:

```lua
_G.IngredientSpawnPreview.Stop()
```

Re-running the full utility also safely replaces its previous session. Deleting
its container stops the session; rerun to restore it. A same-named unrelated
container is not deleted: rename it before starting the utility. If shared Luau
source was changed after it was already required in the Command Bar, reopen the
place to clear Studio's module cache before starting a fresh session.

Preview changes in this pass: `IngredientSpawn.luau` (shared transform),
`IngredientService.luau` and new `IngredientGeometry.luau` (unchanged clone preparation
extracted for Edit-mode reuse), new `docs/studio/IngredientSpawnPreview.luau`, new
`tests/spawn_preview.spec.luau` and `tests/run_spawn_preview_tests.py`, plus this guide.
No Rojo mapping or runtime bootstrap change is required.

Preview validation: `python tests/run_spawn_preview_tests.py --luau <luau>` passes
52 mocked-Studio assertions, including runtime/helper parity, rotated and resized
markers, MeshPart/Model templates, ghost safety, duplicate names, live template
updates, warnings and cleanup. Existing world (176), carry (221), and vacuum (642)
assertions pass. All current source files plus the utility compile (71 files in
this validation), changed code and the utility pass Roblox-aware type checking,
StyLua passes, Rojo build passes, and `git diff --check` passes. Full-source checking
still reports the four existing `StashPromptController.luau` type errors and a
`LoadCharacterAppearance` deprecation warning. A Studio visual/physics playtest has
not been performed; verify an actual tree preview against its frozen runtime stock
and confirm Play/Stop cleanup in Studio using the workflow above.
