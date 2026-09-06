# Film one smoothie

The slice implements physical pickup/throw, validated ingestion, 1–3 unit blending, deterministic color, a genuine one-use cup, customer grading/reaction, cash payout, and GameService completion. Tests exercise the real domain services against a mocked Roblox boundary. **Engine physics, Tool grip, prompt reach and replication still need a Studio Play test.**

## Reference scene

Sync with Rojo. In a blank Studio place, paste the entire contents of [`studio/CreateReferencePlot.luau`](studio/CreateReferencePlot.luau) into the **Edit-mode Command Bar**. It creates all required placeholder fixtures and refuses to overwrite existing plots. It does not enable developer commands. Alternatively, create this exact hierarchy manually:

```text
Workspace
└─ Plots (Folder)
   └─ ReferencePlot (Model) [PlayerPlot]
      ├─ Floor (Part)
      ├─ PlayerSpawn (SpawnLocation)
      ├─ BlenderBase (Part)
      ├─ BlenderInput (Part) [BlenderInput]
      ├─ IngredientSpawn (Part) [IngredientSpawn]
      ├─ TurbineWheel (Part) [TurbineWheel]
      ├─ DispenseButton (Part) [DispenseButton]
      ├─ StartDayButton (Part) [StartDayButton]
      ├─ CustomerSpawn (Part) [CustomerSpawn]
      ├─ CustomerCounter (Part) [CustomerCounter]
      └─ CustomerExit (Part) [CustomerExit]
ServerStorage
├─ Ingredients (optional Folder; Models/BaseParts named by ingredient Id)
├─ Smoothie (optional Tool with Handle)
└─ Customer (optional Model with PrimaryPart)
```

Bracketed names are exact CollectionService tags. All static reference parts are anchored. No authored gameplay attributes are required. Avoid duplicate roles and nested plots. Marker positions are NPC pivot positions, not feet.

| Part | Position | Size | Properties |
| --- | --- | --- | --- |
| Floor | 0, -0.5, 0 | 50, 1, 50 | Collidable |
| PlayerSpawn | 0, 0.5, 14 | 6, 1, 4 | Neutral |
| BlenderBase | 0, 0.5, -6 | 10, 1, 8 | Collidable |
| BlenderInput | 0, 4, -6 | 9, 7, 7 | Transparency=1, CanCollide=false, CanQuery=true |
| IngredientSpawn | 0, 2, 9 | 10, 1, 4 | Collidable staging table; keep level |
| TurbineWheel | 7, 3, -4 | 2, 2, 2 | Manual Turn prompt works while anchored |
| DispenseButton | 7, 3, 0 | 2, 1, 2 | Generated Dispense prompt |
| StartDayButton | 7, 3, 5 | 2, 1, 2 | Generated Start Day prompt |
| CustomerSpawn | 18, 3, 6 | 1, 1, 1 | Invisible, noncollidable |
| CustomerCounter | 11, 3, 2 | 1, 1, 1 | Invisible, noncollidable |
| CustomerExit | 18, 3, -8 | 1, 1, 1 | Invisible, noncollidable |

The generous detector is for initial reliable capture. Resize it around your actual blender opening after validating throw trajectories. Turbine constraints are optional: the reference uses ten Turn interactions, at least 0.25 seconds apart, at default upgrade level. Real spin remains supported.

## Exact filming commands

Start **Play**, switch the Command Bar to **Server**, and run this setup once per session:

```lua
game.ServerStorage:SetAttribute("EnableDevContent", true)
game.ServerStorage:SetAttribute("DebugFilmLoop", true)
```

Each command below is independent, with no reliance on Command Bar local variables surviving between submissions. For multiplayer replace `GetPlayers()[1]` with the intended player. APIs use the repository's **dot-call** convention.

Spawn Strawberry on the staging table:

```lua
local p = game.Players:GetPlayers()[1]; assert(require(game.ServerScriptService.Server.Services.DevContentService).SpawnIngredient(p, "Strawberry"))
```

Prepare Strawberry/Tire/Noob as three physical props:

```lua
local p = game.Players:GetPlayers()[1]; assert(require(game.ServerScriptService.Server.Services.DevContentService).PrepareCombination(p, { "Strawberry", "Tire", "Noob" }))
```

Clear just the blender batch:

```lua
local p = game.Players:GetPlayers()[1]; assert(require(game.ServerScriptService.Server.Services.DevContentService).ClearBlender(p))
```

Spawn a serveable customer (stand near StartDayButton first):

```lua
local p = game.Players:GetPlayers()[1]; assert(require(game.ServerScriptService.Server.Services.DevContentService).SpawnCustomer(p))
```

Force Launch for the current customer:

```lua
local p = game.Players:GetPlayers()[1]; assert(require(game.ServerScriptService.Server.Services.DevContentService).ForceReaction(p, "Launch"))
```

Reset the plot's filming state:

```lua
local p = game.Players:GetPlayers()[1]; assert(require(game.ServerScriptService.Server.Services.DevContentService).ResetPlot(p))
```

`ResetBlender` and `ResetScene` remain aliases for `ClearBlender` and `ResetPlot`. `ForceReaction` also accepts `Love`, `Disgust`, `Freeze`, `NoobTransform`, the existing reaction IDs, or `nil` to return to weighted selection. Grade and payout never depend on the reaction.

`PrepareCombination` now **stages physical props**, replacing its old instant-ingestion behavior. It clears owned loose ingredients, a held ingredient, and the loaded batch. It leaves an existing smoothie cup/customer intact. `ClearBlender` only clears the batch. `ResetPlot` clears held/loose ingredients, cup, batch, active/exiting customers, and the day session; cash, upgrades and ordinary carried/stash inventory remain. A held physical unit is discarded on reset, respawn, or leaving.

`SpawnCustomer` starts a normal day, returns the existing active customer, or resumes a day whose next customer failed to spawn. It keeps normal proximity checks. The first two serves still spawn the next customer automatically; three finish the day. For one-shot takes, reset between customers. Missing markers produce warnings and a failed command, without blocking bootstrap.

Every dev API requires **both Studio and EnableDevContent=true**, including aliases. There is no developer remote. `DebugFilmLoop` is the only logging switch and is separately Studio-gated. Turn both attributes off after filming.

## Record the loop

1. Near StartDayButton, spawn a customer and optionally force a reaction.
2. Prepare the combination. Pick up each prop from the table with its prompt. It equips automatically; click/tap to throw while equipped. Walk to about `(0, 3, 6)` and face toward the blender (negative Z) before throwing. Repeat for up to three props. Aim follows character facing, not mouse position.
3. Check accepted count and LOADING/READY logs. One or two ingredients seal through READY on the first Turn; three become READY immediately. A fourth stays in the world. Registered units must overlap this owner's detector; its 0.1-second polling accepts each only once.
4. Stand by TurbineWheel and use Turn until COMPLETE. The existing billboard shows progress. Output logs progress at 10-point boundaries and the resulting color.
5. Use Dispense. A colored Smoothie Tool appears in the Backpack; equip it for the shot. One outstanding cup is allowed. DISPENSED resets the batch to EMPTY on the next deferred task, while the cup remains valid.
6. Approach the waiting customer and use Serve smoothie. The server computes grade/payout, consumes the cup once, grants cash through PlayerDataService and calls GameService. Check the customer log, `playerCash`, and `CustomersServedToday`.

Owned loose props receive pickup prompts; shared market collection retains its existing path. Pickup transfers the world unit into a server reservation owned by InventoryService, displayed using a clone of its visual model. Throw consumes that reservation and spawns a newly registered physical unit. Neither the held visual nor editable attributes authorize ingestion. The Tool can be unequipped/re-equipped without duplicating the reservation.

## Tags, attributes and templates

- IngredientService alone applies `IngredientWorldItem`, `IngredientId`, `OwnerUserId`, and `WorldItemId`. Instance identity in its server registry is the authority; GUIDs/attributes are presentation/debug metadata. Never hand-tag decorative objects as gameplay ingredients.
- The server writes `OwnerUserId` on plots/customers. Cups receive `CupId`, `BlendId`, `RecipeName`, and `IsFinished`; the actual Tool identity and contents remain server-owned. A cup moved into another player's Backpack is invalid for both players.
- Player output attributes retain `BlendState`, `BlendProgress`, `BlendIngredientCount`, `HasSmoothie`, `CurrentRecipeName`, `playerCash`, day attributes, `CustomerSatisfaction`, and `CustomerReaction`. Customer models expose `Preference`, `Reaction`, and `Grade`. No client attribute is read to authorize rewards.
- Optional ingredient templates need valid Models/BaseParts with sensible pivots; Models need PrimaryPart and welded geometry. Keep templates free of scripts, Tools, and prompts. Standard-sized props (about 1.5 studs) fit the staging/throw setup. Missing templates use colored cubes. All nine requested ingredients exist; Spinach is retained for compatibility.
- Optional Smoothie is an unanchored Tool with a Handle and welded decorations. Optional Customer is a Model with PrimaryPart. Missing templates generate plain cups and simple torso/head customers. No asset uploads are required to test the loop.

## Presentation contract

Listen on the client to `ReplicatedStorage.Shared.Events.GameplayPresentation.OnClientEvent(moment, ownerUserId, payload)`. It is server-created and output-only; no server listener accepts client messages. Events broadcast for observers/recording. Attribute snapshots remain available if a client misses an event.

| Moment | Payload |
| --- | --- |
| BlendStarted | IngredientIds (copied list) |
| BlendProgressChanged | Progress (0–100) |
| BlendCompleted | BlendId, Color (Color3), IngredientIds, RecipeId (optional) |
| SmoothieDispensed | BlendId, Color, Cup (Tool; may not be replicated to other players yet) |
| CustomerReaction | BlendId, Customer (Model), ReactionId, Grade, Payout |

Payout in the event is a display value after the transaction. It grants no authority. Result colors use the RGB mean of every unit, including repeated units and Mystery; there is no random color override. Recipes remain optional multiset discoveries.

```lua
-- LocalScript example for a later presentation controller:
local events = game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Events")
events:WaitForChild("GameplayPresentation").OnClientEvent:Connect(function(moment, ownerUserId, payload)
    if moment == "BlendCompleted" then
        print(ownerUserId, payload.BlendId, payload.Color)
    elseif moment == "CustomerReaction" then
        print(ownerUserId, payload.ReactionId)
    end
end)
```

No new VFX controller is installed. Love/Disgust/Freeze/Launch/NoobTransform are replicated reaction IDs, not physical effects. Existing basic text/audio/sparkles remain. Final blender/ingredient/customer art, grip tuning, reaction animation/VFX, and filming camera work remain Studio tasks. Ants, stealing, PvP, HUD, monetization and persistence were not extended.

## Validation and remaining checks

Completed checks for this change: **270 domain assertions passed**, all **38 source files compiled**, Roblox-aware Luau LSP analysis passed with **zero type errors**, StyLua passed on all **13 touched/new Luau files** (including tests and fixture script), Rojo **7.7.0** build passed, and `git diff --check` passed. The LSP emitted only its CLI watch-registration warning; automatic watch support is irrelevant to the completed one-shot analysis. Build output and sourcemap are in the system temporary tools directory. `default.project.json` is unchanged.

Run `python tests/run_state_tests.py --luau <luau-executable>`, compile `src/*.luau` recursively, run Roblox-aware Luau LSP analysis with Rojo sourcemap/definitions, check touched files with StyLua, build with Rojo, and run `git diff --check`.

Domain tests cover genuine/duplicate/foreign ingestion; 1–3 units and state transitions; color averaging/Mystery/order; incomplete/duplicate dispense; pickup/throw reservation; one-use/foreign/forged cups; actual cash transactions; separate reactions/grades; real three-customer callbacks; presentation moments; production security and reset cleanup. The fake engine explicitly simulates overlaps and waypoint time: these tests cannot certify real collision detection or networking.

Studio acceptance still required: boot with no fixtures (warnings, no hang); create this plot; perform the full physical loop; test another player's pickup/dispense/serve rejection; reset while holding a prop; respawn with a cup; remove/restore customer markers; confirm client event delivery. No Studio Play session was run from this workspace.

## Files changed

| File | Change |
| --- | --- |
| `src/server/Services/BlendService.luau` | Blend ID, transition/result/progress/dispense events and debug logs |
| `src/server/Services/CustomerService.luau` | Reaction event and authoritative serve log |
| `src/server/Services/DevContentService.luau` | Physical staging, serveable customer startup, clear/reset aliases |
| `src/server/Services/IngredientService.luau` | WorldItemId metadata and queryable physical parts |
| `src/server/Services/InventoryService.luau` | Reserved physical Tool pickup/throw and cleanup |
| `src/server/Services/FilmingUtil.luau` (new) | Output event transport and Studio log gate |
| `src/server/Components/IngredientPickup.luau` (new) | Owned ingredient pickup prompt adapter |
| `src/server/init.server.luau` | Presentation/pickup initialization, staging tag migration, respawn cleanup |
| `src/shared/Constants/Ingredients.luau` | Id metadata and missing requested ingredients |
| `src/shared/Constants/Customers.luau` | Required filming reaction IDs, existing IDs retained |
| `src/shared/Types.luau` | Optional BlendId on smoothie snapshots |
| `tests/server_state.spec.luau` | Engine boundary extensions and real film-loop transaction assertions |
| `docs/studio/CreateReferencePlot.luau` (new) | Non-overwriting Edit-mode placeholder scene generator |
| `docs/FILMING_VERTICAL_SLICE.md` (new) | Current scene/API/presentation/verification guide |
| `docs/MVP_ARCHITECTURE.md` | Updated architecture links and changed filming semantics |
