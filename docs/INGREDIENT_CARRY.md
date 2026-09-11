# Overhead ingredient carry

`InventoryService` still owns pickup validation, the exclusive held reservation,
Tool activation, and release/stash lifecycle. Previously, it welded a cloned
ingredient to a Tool `Handle`, letting Roblox's default right-hand grip determine
placement. There was no custom arm pose or animation.

`IngredientCarryPresentation` now welds an invisible `CarryAnchor` to
`HumanoidRootPart`. The Tool has `RequiresHandle = false` and no `Handle`, avoiding
a competing right-hand grip while preserving activation and unequip signals.
Models use their PrimaryPart (or the existing WorldUtil BasePart fallback);
BaseParts use themselves. Root-to-pivot offsets are preserved. All constituent
parts are massless, noncolliding, and welded to the anchor.

Position is calculated at equip from every part's oriented bounds and the head's
top in character-root space. The lowest ingredient corner clears the head even
for large, rotated fruit or an off-center PrimaryPart. Character scaling while
already holding an item requires re-equipping to recalculate clearance.

Tune `src/shared/Constants/IngredientCarry.luau`:

| Constant | Default | Meaning |
| --- | --- | --- |
| `HeightAboveHead` | `0.35` | Minimum gap in studs above the head; clamped to zero |
| `ForwardOffset` | `0` | Studs forward; negative moves backward |
| `RotationDegrees` | `Vector3.new(0, 0, 0)` | Root orientation, XYZ Euler degrees relative to the character |

These are server-read constants, not client-supplied attributes. Models are not
rescaled. Unusually tall hats and custom rigs may require additional clearance.

Temporary welds raise both R6/R15 shoulders and keep R15 elbows/wrists in a static
pose. Original Motor6D Enabled states are restored on clear, throw, drop, death,
unequip, and removal. No uploaded animation is required. This static weld pose is
the simplest path to add two-arm presentation without changing gameplay. It does
not solve hand contact against arbitrary fruit shapes or custom rig proportions.
For later animated transitions, replace only the arm-pose section with an
upper-body carry track; keep the ingredient anchor independent of the arms.

Throwing uses the current character root and the saved overhead pivot offset.
The original forward/up velocity, authorization, exclusive reservation, spawn
failure handling, and public ownership on release are unchanged. Drops retain
their existing position. Stash and blender ingestion logic are unchanged.

No Studio objects or animation assets need setup; sync with Rojo. Playtest R6 and
R15 with large multipart fruit, noncentral PrimaryParts, walking/jumping, throws,
stash deposit/withdrawal, death, and respawn. Confirm the arm pose on a second
client and tune clearance against the actual art. CLI tests cannot verify engine
weld physics, animation blending, or visual replication.

Run `python tests/run_state_tests.py --carry-only --luau <executable>` for focused
geometry and lifecycle checks, plus the existing `--world-only` regression suite.

Validation: 149 carry, 55 world, 32 sprint, 74 upgrade UI, and 115 VFX assertions
passed. All 55 runtime sources compiled; changed runtime modules passed
Roblox-aware type analysis; changed Luau files passed StyLua; Rojo build and
`git diff --check` passed. Full-suite execution stops at the unrelated assertion
`base stamina full at 110` (the current base setting is 60), reproduced with the
original InventoryService. Full-project type analysis still reports existing
errors in StashPromptController (36/39) and CustomerService (337).
