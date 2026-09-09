# Simple customer request slice

Requests live in `src/shared/Constants/CustomerRequests.luau`: stable `Id`, `DisplayText`, `RequiredTags`, and `BasePayout`. Red, Sweet, and Cold each pay $25. Add an entry with `RequiredTags = { "Red", "Sweet" }` to require both tags; different ingredients may supply them. Ingredient semantic tags live in `src/shared/Constants/Ingredients.luau`, not CollectionService tags on physical props.

Start Day still uses `DayButton` or `GameplayRequest("StartDay")` → `GameService.StartDay` → `CustomerService.SpawnForPlayer`. The existing fast three-customer day is retained, with one active order per owner. Served customers can leave while their successor approaches. No timer was added.

`TycoonService.GetReference(player, role)` takes a Player (not a plot). Customer roles use CollectionService tags `CustomerSpawn`, `CustomerCounter`, and `CustomerExit` inside that player's assigned plot. Tag one marker BasePart for each role. Tagged BaseParts take precedence over legacy tagged containers. Without a tagged BasePart, a legacy container must contain exactly one BasePart named for the role, or only one BasePart total; its PrimaryPart/first arbitrary part is no longer used. Duplicate marker parts, ambiguous containers, and Start Day button targets fail with a diagnostic reason. No generic reference tag or reference attribute is used. Children of `Workspace.Plots` also support legacy objects named exactly by role through automatic tagging when assigned. Explicit tags take precedence. The existing direct pivot movement goes Spawn → Counter → Exit; no pathfinding or walk animation is added. Put spawn near the counter for quick testing, with marker CFrames at NPC pivot height.

The request is selected only after arrival and shown in the existing `OrderBubble` BillboardGui, adorning Head when available and the root otherwise. The server creates `ServePrompt`, `RequestId`, `Preference`, and result attributes automatically. Optional `ServerStorage.Customer` and `ServerStorage.Smoothie` templates retain their existing fallbacks.

Serve path:

1. Customer `ServePrompt.Triggered` verifies the actor is the owner and calls `CustomerService.Serve`.
2. Serve checks ready state, active day, and server distance.
3. `BlendService.ConsumeCup` → `GetCup` authenticates the recorded Tool in the owner's Backpack/Character, copies the completed server smoothie, and destroys/clears the cup. Ingredient IDs came from accepted world ingredients, blend completion, and `Dispense`; Tool attributes are not read as contents.
4. The order is removed from active state without yielding. `CustomerService.ValidateRequest` resolves those ingredient IDs against metadata and requires at least one ingredient for each required tag. Extra ingredients are allowed; unknown ingredients and empty smoothies fail.
5. Only a match calls `PlayerDataService.AddCash` with the request's base payout. Private in-memory `records[player].Cash` remains authoritative; `SetCash` replicates `playerCash` using the existing convention. This slice does not apply the legacy grade/upgrade payout formula or add persistence.
6. Success uses Smile, grade A, serve sound, and sparkles. Failure uses Disgust, grade D, rejection sound, and no payout. Both destroy the order billboard immediately, cancelling its typewriter task. Both consume the cup, complete the turn, leave/despawn, and notify `GameService.CustomerServed`. `Serve` returning true means the cup transaction completed, including a mismatched order. Legacy grading/payout helpers remain callable; Studio forced reactions still override cosmetics only.

Studio Output logs spawn, assigned request, evaluated IDs, blend ID, success/failure reason, payout, and resulting cash automatically while `RunService:IsStudio()`. No debug attribute is required.

## Studio setup and playtest

No new tags or hand-authored attributes are needed for an already configured plot. If customer fixtures are missing, add three anchored marker parts inside the plot and tag them `CustomerSpawn`, `CustomerCounter`, and `CustomerExit`. Retain the existing `StartDayButton`, `BlenderInput`, `TurbineWheel`, and `DispenseButton` fixtures. Keep customer paths clear and the counter within interaction reach. Ingredient stations use the existing `IngredientSpawn` tag and `IngredientId` attribute; semantic request tags require only the ingredient configuration.

1. Sync Rojo and start Play. Start a day near the plot's button. Confirm one customer approaches, then shows one configured request above its head. Repeated starts must not duplicate it.
2. Blend Strawberry + Ice (covers all three initial requests), dispense, and serve. Verify +$25 in authoritative cash / `playerCash`, cleared order bubble, positive reaction, and departure. Repeated serving cannot pay again.
3. Serve Tire to the next request. Confirm a missing-tag reason in Output, cleared order bubble, negative reaction, and unchanged cash. The next customer/day remains playable.
4. In a two-player test, another player must not serve or receive cash from your customer/cup. Check arrival, bubble placement, physical proximity, audio, and departure in Studio; CLI tests do not simulate these engine visuals/physics.

## Marker / prompt debugging fix

Recommended Studio hierarchy (marker parts anchored; positions are NPC pivot positions):

```text
Workspace
  Plots
    Plot1 [PlayerPlot]
      Customer Area                       (no role tag needed)
        CustomerSpawn [CustomerSpawn]
        CustomerCounter [CustomerCounter]
        CustomerExit [CustomerExit]
      StartDayButton [StartDayButton]
```

Tags are shown in brackets. Marker names may differ when explicitly tagged. No marker attributes are required. Remove stale customer-role tags from containers/buttons for clarity; legacy container tags are tolerated when the actual marker part is tagged. Do not tag both a button and a marker with CustomerCounter. Runtime logs print the resolved full route; failures print conflicting paths. Restart Play after Rojo sync so old runtime NPCs/scripts are replaced.

Previously, GetReference rejected any role with more than one tagged descendant. A CustomerCounter-tagged area plus a newly tagged marker therefore returned nil. With only the area tagged, WorldUtil.Part selected the area's PrimaryPart/first descendant BasePart, potentially the Start Day button. This combination is reproduced in tests; the live Studio place hierarchy is not stored in this repository and was not inspected directly.

CustomerService itself created the gray panel through TextLabel.BackgroundColor3 with default opaque transparency. There is one code-created order system; a ServerStorage.Customer template could additionally carry GUIs. The flow now removes cloned BillboardGui/SurfaceGui descendants and creates one transparent OrderBubble with white 24px outlined text, AlwaysOnTop, Head/root adornee, and 80-stud range. The configured request text remains unchanged and wraps within the billboard. No new ScreenGui is created.
