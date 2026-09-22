# Simple customer request slice

Custom avatar setup and NPC overrides are documented in [CUSTOMER_NPCS.md](CUSTOMER_NPCS.md).

Requests live in `src/shared/Constants/CustomerRequests.luau` under `Definitions`: stable `Id`, `DisplayText`, `RequiredTags`, `BasePayout`, and `MinJumpTier`. Red, Sweet, and Cold each pay $25. Add an entry with `RequiredTags = { "Red", "Sweet" }` to require both tags; different ingredients may supply them. Ingredient semantic tags live in `src/shared/Constants/Ingredients.luau`, not CollectionService tags on physical props.

CustomerService reads the server-owned `JumpLevel` attribute (0–3), initialized by PlayerDataService and updated by MovementService, including Studio overrides. For NPCs without a valid explicit override, both spawning and order refresh build a non-NPCOnly pool where `JumpLevel >= MinJumpTier` before choosing uniformly at random. Missing JumpLevel defaults to 0. Empty pools warn and prevent spawning or remove the affected arriving/refreshing customer. No progression API extension is needed; tag validation and payouts are unchanged. Request IDs are unique; the duplicate Cold entry was removed.

Set `MinJumpTier` to the earliest area tier providing every required tag. **Seafood and Cold currently use tier 3 placeholders for the designer to configure**; Red, Sweet, Weird, and Yellow use tier 0. The queue requires the five plot markers below. Run focused regression coverage with `python tests/run_state_tests.py --requests-only --luau <luau-executable>`.

Plot ownership automatically activates an endless, timed three-place queue. All orders are assigned on spawn and visible to the owner; only the counter customer can be served. See [CUSTOMER_QUEUE.md](CUSTOMER_QUEUE.md).

`TycoonService.GetReference(player, role)` takes a Player (not a plot). Customer roles use CollectionService tags `CustomerSpawn`, `CustomerCounter`, `CustomerWait1`, `CustomerWait2`, and `CustomerExit` inside that player's assigned plot. Tag one marker BasePart for each role. Tagged BaseParts take precedence over legacy tagged containers. Without a tagged BasePart, a legacy container must contain exactly one BasePart named for the role, or only one BasePart total; its PrimaryPart/first arbitrary part is no longer used. Duplicate marker parts, ambiguous containers, and Start Day button targets fail with a diagnostic reason. No generic reference tag or reference attribute is used. Children of `Workspace.Plots` also support legacy objects named exactly by role through automatic tagging when assigned. Explicit tags take precedence. The existing PivotTo movement and rig animations take customers from Spawn to their assigned marker, forward through the queue, then to Exit. Put spawn near the counter for quick testing, with horizontal marker top surfaces at floor height (see the custom NPC guide).

The request is selected when queued and shown in the existing `OrderBubble` BillboardGui, adorning Head when available and the root otherwise. The server creates `ServePrompt`, `RequestId`, `Preference`, and result attributes automatically. Optional `ServerStorage.Customer` and `ServerStorage.Smoothie` templates retain their existing fallbacks.

Serve path:

1. Customer `ServePrompt.Triggered` verifies the actor is the owner and calls `CustomerService.Serve`.
2. Serve checks counter readiness, current plot ownership, and server distance.
3. `BlendService.ConsumeCup` → `GetCup` authenticates the recorded Tool in the owner's Backpack/Character, copies the completed server smoothie, and destroys/clears the cup. Ingredient IDs came from accepted world ingredients, blend completion, and `Dispense`; Tool attributes are not read as contents.
4. The order is removed from active state without yielding. `CustomerService.ValidateRequest` resolves those ingredient IDs against metadata and requires at least one ingredient for each required tag. Extra ingredients are allowed; unknown ingredients and empty smoothies fail.
5. Only a match calls `PlayerDataService.AddCash` with the request's base payout. Private in-memory `records[player].Cash` remains authoritative; `SetCash` replicates `playerCash` using the existing convention. This slice does not apply the legacy grade/upgrade payout formula or add persistence.
6. Success uses Smile, grade A, serve sound, and sparkles. Failure uses Disgust, grade D, rejection sound, and no payout. Both destroy the order billboard immediately, cancelling its typewriter task. Both consume the cup, complete the turn, leave/despawn, and notify `GameService.CustomerServed`. `Serve` returning true means the cup transaction completed, including a mismatched order. Legacy grading/payout helpers remain callable; Studio forced reactions still override cosmetics only.

Studio Output logs spawn, assigned request, evaluated IDs, blend ID, success/failure reason, payout, and resulting cash automatically while `RunService:IsStudio()`. No debug attribute is required.

## Studio setup and playtest

Existing plots need CustomerWait1 and CustomerWait2 marker parts. Follow [CUSTOMER_QUEUE.md](CUSTOMER_QUEUE.md) for the five required markers and the Studio smoke test. Start Day is disabled; claiming a plot starts timed arrivals. All three order bubbles remain visible while the queue advances. Existing blender, stash, and ingredient fixtures retain their setup.

## Marker / prompt debugging fix

Recommended Studio hierarchy (marker parts anchored; positions are NPC pivot positions):

```text
Workspace
  Plots
    Plot1 [PlayerPlot]
      Customer Area                       (no role tag needed)
        CustomerSpawn [CustomerSpawn]
        CustomerCounter [CustomerCounter]
        CustomerWait1 [CustomerWait1]
        CustomerWait2 [CustomerWait2]
        CustomerExit [CustomerExit]
      StartDayButton [StartDayButton]
```

Tags are shown in brackets. Marker names may differ when explicitly tagged. No marker attributes are required. Remove stale customer-role tags from containers/buttons for clarity; legacy container tags are tolerated when the actual marker part is tagged. Do not tag both a button and a marker with CustomerCounter. Runtime logs print the resolved full route; failures print conflicting paths. Restart Play after Rojo sync so old runtime NPCs/scripts are replaced.

Previously, GetReference rejected any role with more than one tagged descendant. A CustomerCounter-tagged area plus a newly tagged marker therefore returned nil. With only the area tagged, WorldUtil.Part selected the area's PrimaryPart/first descendant BasePart, potentially the Start Day button. This combination is reproduced in tests; the live Studio place hierarchy is not stored in this repository and was not inspected directly.

CustomerService itself created the gray panel through TextLabel.BackgroundColor3 with default opaque transparency. There is one code-created order system; a ServerStorage.Customer template could additionally carry GUIs. The flow now removes cloned BillboardGui/SurfaceGui descendants and creates one transparent OrderBubble with white 24px outlined text, AlwaysOnTop, Head/root adornee, and 80-stud range. The configured request text remains unchanged and wraps within the billboard. No new ScreenGui is created.
