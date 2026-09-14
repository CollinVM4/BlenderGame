# Custom customer avatars

## Studio setup

1. In Edit mode, use your avatar-import plugin, enter a Roblox username, and insert its rig into Workspace.
2. Inspect the imported content and remove unwanted scripts, Tools, and other plugin extras before playing. Configure its appearance. Standard R6/R15 rigs need no manual facing rotation.
3. Ensure the Model has a direct Humanoid and preferably a direct HumanoidRootPart. Enable Archivable on the model and required descendants. A valid PrimaryPart or the existing first-BasePart root fallback also works.
4. Add a **string** Model Attribute `CustomerId = "steak"`.
5. Move the finished Model into `ServerStorage.CustomerNPCs` as a direct child. Rojo creates this Folder and preserves manually authored children; save the Studio place to retain your imported assets. They are not stored in the source repository or reproduced by a fresh CLI build.
6. Optionally add an NPC mapping in `src/shared/Constants/CustomerRequests.luau` (the steak mapping already exists).
7. Start Play, then start a day. Verify Output shows `[CustomerService] selected type=Special template=SteakNPC customerId=steak request=Steak jumpTier=1 forced=true` when that avatar reaches the counter. The player must have JumpLevel >= 1; specials are uncommon and capped at one per day.
8. Verify appearance, counter facing, order placement, proximity serving, and departure. Repeat with two players to check each plot independently.

```text
ServerStorage
  CustomerNPCs (Folder)
    SteakNPC (Model; CustomerId = "steak")
      Humanoid
      HumanoidRootPart
      ...body parts, joints, clothing, accessories
    BuildermanNPC (Model; optional CustomerId = "builderman")
```

No NPC CollectionService tag is required. Existing plot marker BaseParts still need the `CustomerSpawn`, `CustomerCounter`, and `CustomerExit` tags. Use one marker per role within the player's plot, with horizontal top surfaces at intended ground level. Move old pivot-height markers down to the floor; route direction now controls facing. CustomerCounter resolution, Start Day fixtures, and serving distance checks are unchanged.

## ID and request contract

CustomerId is trimmed and **case-sensitive**. Missing, non-string, and whitespace-only values are absent. Model.Name and Roblox username never supply a fallback ID; renaming a model with CustomerId present does not change its request. The ID is captured privately on the server when cloned. Changing runtime attributes does not reroute an active order.

CustomerRequests exposes `Definitions` (the request array), `NPCs` (the mapping), `SpecialCustomerChance = 0.12`, `MaxSpecialCustomersPerDay = 1`, `NormalizeCustomerId`, and `GetForNPC`. Existing in-repository array consumers were updated to `.Definitions`.

```luau
NPCs = {
    steak = { Type = "Special", RequestId = "Steak", Weight = 1 },
    bacon = { Type = "Regular" },
    builderman = { Type = "Special", RequestId = "Sweet", Weight = 1 }, -- optional
}
```

The included definition is:

```luau
{
    Id = "Steak",
    DisplayText = "I want STEAK in my smoothie!",
    RequiredTags = { "Steak" },
    BasePayout = 105,
    MinJumpTier = 1,
    NPCOnly = true,
}
```

A fixed-request special is eligible only when the server-owned JumpLevel meets that request's MinJumpTier. Locked or invalid fixed requests remove the NPC from selection; they never substitute a random order on that special avatar. Eligible specials get a 12% chance per customer slot, capped at one spawned special per three-customer day. Weights choose within the selected category (default 1, positive finite values). With no eligible special, or after reaching the cap, selection uses regular templates or the generic fallback. The chance is not a guarantee of a special every day.

Unconfigured NPCs are Regular. An explicit Regular always uses the normal random pool, even if RequestId is present. For compatibility, a RequestId-only mapping is Special. A Special without RequestId uses the normal eligible random pool. RequestId is resolved privately at spawn and reused at arrival/refresh. If its tier becomes unavailable before assignment/refresh, the special is removed; restore eligibility or use the existing GameService.ResumeDay recovery API.

Regular random requests exclude NPCOnly and require MinJumpTier <= JumpLevel. Steak remains NPCOnly. No duplicate NPC tier setting is introduced. GameService calls CustomerService.BeginDay only on a new day; resume does not reset the cap. Player removal/reset clears in-memory selection history. No persistence is added.

Ingredient names alone do not satisfy required tags: authoritative validation still reads semantic tags in Ingredients.luau. This change does not edit ingredient definitions or the serving transaction.

## Templates and lifecycle

Each spawn chooses a valid direct child Model from the selected category, avoiding the player's previous template when alternatives exist. A repeat is never avoided by exceeding the special chance/cap; a lone regular may repeat. IDs need not be unique across visual variants. Invalid templates are skipped with a useful Studio warning once per template instance. An empty/missing/unusable folder uses a regular legacy ServerStorage.Customer template, then the generated torso/head fallback. A legacy template configured as Special cannot bypass special selection; put special templates in CustomerNPCs.

Only clones are modified. Before entering Workspace, clones lose Script, LocalScript (including Animate), ModuleScript, Tool, ProximityPrompt, BillboardGui, and SurfaceGui descendants. Body parts, clothing, meshes, face decals, accessories, attachments, and rig joints remain. Extra constraints remain, while every BasePart is anchored and noncolliding as in the existing customer implementation. Inspect plugin imports in Edit mode as well; runtime clone cleanup does not sanitize originals placed in Workspace by the plugin.

R6 and R15 support the existing straight-line, anchored PivotTo movement. HumanoidRootPart takes precedence over PrimaryPart. There is no pathfinding or walk animation controller; imported Animate is unnecessary and removed. The model moves Spawn -> Counter -> Exit facing travel direction. Each segment uses CFrame.lookAt(position, target) with a horizontal direction, so Roblox -Z forward points toward travel. Zero-length segments retain a safe horizontal facing. Marker rotations no longer cause backwards travel. The clone is normalized upright, then its pivot-to-bottom distance is measured from GetBoundingBox (including the box axes' vertical extents). Each route position uses marker center X/Z and marker top Y + measured distance. Optional finite numeric CustomerVerticalOffset adds a correction (default 0). Avatar size is never hardcoded. Normal R6/R15 rigs need no offset; unusual accessories extending below the feet affect visual bounds. The existing order bubble adorns Head or the resolved root. Departure and reset/player-leave cleanup remain unchanged.

CustomerService retains private owner, CustomerId, RequestId/request definition, model, readiness, and served state. CustomerId, RequestId, and OwnerUserId attributes are presentation/debug outputs. Request assignment still occurs at arrival. Serving uses the same server-owned cup consumption, ingredient-ID metadata validation, once-only payout, and GameService callback. Success and failure both consume the order; only success pays. Economy.CustomersPerDay remains 3.

## Validation

- Focused customer regression: `python tests/run_state_tests.py --requests-only --luau <luau.exe>`: 196 assertions pass, using real CustomerService, request config, PlayerDataService, and GameService with a mocked Roblox boundary/cup provider.
- Coverage includes forced/unknown/missing/invalid IDs, renaming, private ID capture, invalid mapping, template cloning and cleanup, malformed/non-archivable clones, root fallbacks, target-facing geometry, bounding-box ground alignment, offsets, special tier filtering/chance/day cap, no immediate repeats, success/failure payouts, duplicate serve rejection, three-customer days, generic fallback, and legacy templates.
- Character physics: 32 assertions; interaction prompts: 79; world text: 49 + 23 pass.
- Full state suite and `--customer-only` stop at `start clears copies and cancels arrival`; blender status stops at `readable world-space settings`; upgrade UI stops at `stale timer cannot clear new request`. All three failures reproduce in an isolated pre-change snapshot retaining the user's Ingredients edits.
- Changed Luau files pass StyLua; all 63 source Luau files compile; Rojo build passes. Roblox-aware analysis reports existing StashPromptController errors at lines 36/39, with no errors in the changed runtime modules.
- Live Studio avatar appearance, engine cloning/replication, and movement have not been play-tested here.
