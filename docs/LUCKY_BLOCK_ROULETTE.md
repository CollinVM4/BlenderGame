# Lucky Block Pass 2 ? world-space visual revision

The collector sees five actual imported 3D silhouettes at 0.00, 0.14, 0.28,
0.42 and 0.56 seconds. At 0.78 seconds, a fresh colored clone of the server-selected
winner appears. The roulette remains fixed 2.5 studs above the server-provided
collection Position while the player runs away. There is no reward card,
ViewportFrame, UI camera or generic power-up icon.

The winner pops from 0.85 to 1.25 times normalized size over 0.1 seconds, settles
back to 1.0 over 0.12 seconds, and emits a brief warm PointLight glow. A small
transparent reward-name label appears below the model. The colored winner remains
for 0.7 seconds after reveal, then shrinks away over 0.15 seconds; complete cleanup
occurs at 1.63 seconds. No power-up buffs or gameplay expiry clocks are implemented.

## Exact files changed by this revision

| Path | Change |
| --- | --- |
| `src/shared/Constants/LuckyBlockPresentation.luau` | Five-beat timing, world offset/size, tilt, pop tuning; remove card/glyph settings |
| `src/client/UI/LuckyBlockVisual.luau` | New private clone sanitizer, solid black treatment, bounding-box normalization and common pivot |
| `src/client/UI/LuckyBlockView.luau` | Replace card/viewports with actual local Workspace models, spatial sounds, pop/glow/shrink and disposal |
| `src/client/Controllers/LuckyBlockRouletteController.luau` | Require event Position and pass it to the world renderer; retain death/reset/departure cleanup |
| `src/server/Services/LuckyBlockService.luau` | Add Position to the existing nearby notification; no spawn/claim/selection changes |
| `tests/lucky_block.spec.luau` | Assert nearby and collector positions match |
| `tests/lucky_block_roulette.spec.luau` | Five distinct beats, revised reveal/hold/fade deadlines |
| `tests/lucky_block_view.spec.luau` | World rendering, six source names, multipart transforms, opaque black treatment, source preservation, pop/glow and disposal |
| `tests/lucky_block_controller.spec.luau` | Fixed collection location, nearby location, revised timing and missing-position rejection |
| `tests/run_state_tests.py` | Include the new visual helper in existing focused bundles |
| `tests/README.md` | Update focused suite responsibilities |
| `docs/LUCKY_BLOCK_ROULETTE.md` | Current implementation, asset setup and Studio acceptance |

The existing generic `LuckyBlockSequence` manager is reused unchanged; it reads
the five-beat timeline from configuration. `LuckyBlockConfig` identifiers, weights,
durations, spawn/respawn values and pickup cooldown/radius are unchanged.
The Studio-authored world template, Visual and Root, markers, existing floating/
rotation controller, ingredient inventory, combat and customers are untouched.
No asset files or replacement power-up models are created.

## Studio hierarchy and asset setup

```text
ServerStorage
??? LuckyBlockTemplates
    ??? LuckyBlock (existing Model; PrimaryPart = existing Root)
        ??? Visual (existing MeshPart; unchanged)
        ??? Root (unchanged)

ReplicatedStorage
??? LuckyBlockVisuals
    ??? DoubleCash (MeshPart or Model)
    ??? SuperJump (MeshPart or Model)
    ??? RainbowRampage (MeshPart or Model)
    ??? MegaBat (MeshPart or Model)
    ??? Magnet (MeshPart or Model)
    ??? Invincibility (MeshPart or Model)

Workspace
??? LuckyBlockSpawns (existing authored markers; unchanged)
??? LuckyBlockRoulette (short-lived client-only presentation folders)
```

Reward `IngredientMagnet` maps to visual `Magnet`; the other five names match their
reward identifiers. Import all six actual models. Each source and its intended
cloned descendants must be Archivable. Nested multipart models are supported;
roulette source models do not need a PrimaryPart. The wrapper pivot is centered
from the bounding box, and all geometry is scaled uniformly to a 2.6-stud maximum
dimension before placement. Relative part positions are preserved. Keep invisible
helper roots small: bounding boxes include them, and silhouette BaseParts are made
opaque, so oversized invisible helpers can distort the silhouette.

The server world template keeps its existing authored PrimaryPart/pivot; this
revision does not modify it. No new assets are needed for sound or glow. Existing
pickup PLIP supplies ticks, and throw PLOP supplies the stronger final pop, with
spatial attenuation from the fixed presentation anchor.

If an imported model is missing, nonarchivable, or has no usable geometry, the
renderer logs a warning naming the exact ReplicatedStorage path and displays a
small temporary text label. It never fabricates a replacement shape or UI icon.
Warnings are suppressed for a repeatedly missing reward until a valid copy succeeds.

The existing safe Rojo mapping is unchanged: LuckyBlockTemplates and LuckyBlockVisuals
preserve unknown Studio-authored children. The old cube file remains unreferenced.
A fresh Rojo build requires your saved Studio-authored world and visual assets; do
not reintroduce the old cube mapping. No live Studio sync or asset edits were run.

## Geometry and black-silhouette guarantees

Silhouettes are private clones of the actual imported geometry, cached once before
the roll. Each beat swaps one model into the presentation folder and moves the
previous silhouette back to an unparented hidden cache. No model is cloned every
silhouette beat. The final winner is freshly cloned from the source, not recolored
from a shadow. Nearby views clone only that fresh winner at reveal.

Every cloned BasePart is anchored with collision, touch and query disabled and zero
assembly velocity. Gameplay scripts, prompts, joints/constraints, Tools, audio and
inherited world tags/attributes are excluded from presentation copies.

During rolling, BaseParts use pure black Color, SmoothPlastic, no MaterialVariant,
Transparency 0, LocalTransparencyModifier 0 and Reflectance 0. MeshPart textures,
decals, SurfaceAppearance and SpecialMesh texture/vertex colors are suppressed.
Particles, lights, trails, beams and other colored visual effects are removed from
silhouettes. Solid-modeling parts use UsePartColor so authored union face colors do
not survive the black override; see [Roblox solid modeling documentation](https://create.roblox.com/docs/parts/solid-modeling).
The source art is never modified.

The fresh colored winner retains original colors, transparency, materials, textures,
SurfaceAppearance and supported original visual effects (attachments, particles,
lights, trails and beams), while still stripping gameplay and constraints. Tilt
and per-beat yaw make the rapid sequence lively; the final pose is identical for
collector and nearby viewers. Scale animation uses one NumberValue change listener
per short-lived view, with no new RenderStepped or server Heartbeat animation.

## Authority, multiplayer and lifecycle

The collector continues to receive `LuckyBlockPickedUp`. Its server-provided
Position is the static world spawn/pickup center. `LuckyBlockRevealed` now also
contains that exact Position; no new remote or client request was added. Both events
carry the authoritative RewardId, metadata duration, character identity, PickupId
and PickedUpAt. Nearby players receive only a final winning model at the same
position at PickedUpAt + 0.78, with no five silhouette frames broadcast.

The server still uses the existing 70-stud observer radius. Clients cannot submit,
reroll or influence rewards. Metadata remains DoubleCash 30s, SuperJump 12s,
RainbowRampage 10s, MegaBat 15s, IngredientMagnet 15s and Invincibility 8s; weights
remain 18, 22, 8, 15, 20 and 17 respectively.

Latency catches up to the current beat without replaying a backlog; expired
notifications are skipped. Unknown rewards or missing Position are rejected instead
of placing a roulette at the character. Moving, jumping or running away cannot
move the world anchor. Death, reset, departure and character stream-out still
cancel the presentation. Old-character events cannot attach to a replacement avatar.
Repeated pickups replace the prior view and cancel its timers. Disposal releases
both visible and hidden models, anchor, glow, sounds, tweens, label and connections.

## Focused verification

Run authoritative and presentation tests separately:

```text
python tests/run_state_tests.py --luau <luau.exe> --suite lucky-block
python tests/run_state_tests.py --luau <luau.exe> --suite lucky-block-roulette --suite lucky-block-view --suite lucky-block-controller
```

Changed feature-module Roblox-aware typecheck, StyLua, a fresh Rojo sourcemap and
Rojo build are required. Engine doubles verify six-name asset support, uniform
centering/scaling, multipart relative positions, source preservation, solid black
surfaces and effect removal, fixed event position, server reward matching, spatial
reveal, pop/shrink and repeated-pickup/death/reset cleanup. They do not render the
actual imported mesh art or prove native engine appearance. Presentation suites are
independent of the authoritative suite.

Completed validation: all four focused suites PASS; changed-module Roblox-aware
typecheck PASS; StyLua PASS; fresh sourcemap and Rojo build PASS. CLI logs and the
build are in the temporary `BlenderGame-luau-tools` directory using the
`lucky-block-world-revision` prefix. No native Studio rendering or multiplayer
playtest was run for this revision; the six real imported assets require the
checks below.

## Required Studio playtest

1. Sync into the saved place and verify the authored LuckyBlock Visual/Root,
   PrimaryPart, marker positions, bob/rotation, pickup radius/cooldown and respawn
   still work. Confirm the safe project mapping did not restore the old cube.
2. Import all six models with the exact names above. Roll repeatedly and inspect
   every silhouette: opaque black geometry only, no source textures, translucent
   surfaces, material variants, colored union faces, particles or lights. Check
   multipart spacing and normalized apparent sizes from several studs away.
3. Confirm five clean switches at roughly 0/.14/.28/.42/.56 seconds and the colored
   winner at .78 seconds. Compare it with the collector event's RewardId. Inspect
   winning colors/materials/textures, 1.25x pop/settle, glow, small name label and
   shrink-out after a .7-second hold. Verify tick/tick/tick/tick/tick/pop sounds.
4. Collect while sprinting past a block. The roulette must remain at the collection
   location + 2.5 studs, with no following overhead card or player tracking. Test
   jumping, throwing, combat and customer interactions during the sequence.
5. Use two clients. The nearby client sees the same colored winner and final pose
   at the same fixed location and reveal time, with no silhouette sequence. Test
   the 70-stud observer boundary and modest simulated latency.
6. Test rapid valid pickups, death/reset during both rolling and final reveal,
   respawn followed by collection, and streaming/departure of the collector.
   Confirm no stale callbacks, displaced models or leaked local folders remain.
7. Remove one imported asset temporarily. Expect a clear warning and tiny text-only
   fallback, never replacement geometry. Restore it and verify the next roll uses
   actual art again. Inspect the six source models to confirm no changes.
8. Check mobile and several camera angles under the place's actual lighting. There
   is no ViewportFrame camera that can hide incorrect authored orientations. Tune
   only the presentation size/tilt/yaw if needed; preserve the stable world system.

Stop after this visual revision. Do not implement buffs.
