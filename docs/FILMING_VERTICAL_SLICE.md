# Film one smoothie

The slice implements physical pickup/throw, validated ingestion, 1–3 unit blending, deterministic color, a genuine one-use cup, customer grading/reaction, cash payout, and GameService completion. Tests exercise the real domain services against a mocked Roblox boundary. **Engine physics, Tool grip, prompt reach and replication still need a Studio Play test.**

## Current Studio Plot1

Keep these human-readable names. CollectionService tags identify gameplay fixtures; names and paths are for organization only. Sync the code with Rojo into your existing place. **Do not run the old placeholder scene generator over your real Plot1.**

```text
Workspace
+-- Plots
    +-- Plot1                              [PlayerPlot]
        +-- Blender
        |   +-- Body
        |   +-- Blades
        |   +-- Liquid
        |   +-- VFX
        |   +-- Glass
        |   +-- BlendVisualOrigin
        |   +-- InputZone                  [BlenderInput]
        +-- Customer Area
        |   +-- Counter                    [CustomerCounter]
        |   +-- Spawn                      [CustomerSpawn]
        |   +-- Approach
        |   +-- Exit                       [CustomerExit]
        +-- Dispenser                      (tag its physical button [DispenseButton])
        +-- ContentSpawnArea
        +-- Start Day                      (tag its physical button [StartDayButton])
        +-- Stash                          [PlayerStash]
        |   +-- LockedSlot1                 SlotIndex = 1
        |   +-- LockedSlot2                 SlotIndex = 2
        |   +-- Slot3                       SlotIndex = 3
        |   +-- Slot4                       SlotIndex = 4
        |   +-- Slot5                       SlotIndex = 5
        +-- Turbine Wheel                  (tag actual spinning blade BasePart [TurbineWheel])
        +-- plot space
```

| Studio object | Exact CollectionService tag | Requirements |
| --- | --- | --- |
| Plot1 | `PlayerPlot` | Model/Folder in Workspace; one assigned owner; avoid nested plots |
| Blender/InputZone | `BlenderInput` | Tag the BasePart itself; `CanQuery=true`, `CanCollide=false`, usually invisible and anchored |
| Actual turbine spinning blade | `TurbineWheel` | Prefer the actual unanchored blade BasePart; legacy Models must resolve to that rotating part |
| Physical dispenser button | `DispenseButton` | BasePart or Model resolving to its button BasePart |
| Physical Start Day button | `StartDayButton` | BasePart or Model resolving to its button BasePart |
| Customer Area/Spawn | `CustomerSpawn` | Resolves to a BasePart; anchored marker at NPC pivot height |
| Customer Area/Counter | `CustomerCounter` | Resolves to a BasePart; anchored, within serving reach |
| Customer Area/Exit | `CustomerExit` | Resolves to a BasePart; anchored exit marker |
| Stash | `PlayerStash` | Physical Model/BasePart; use a PrimaryPart near the slots for interaction distance |

Apply each role exactly once inside Plot1. For button/turbine Models, tag either the Model or the actual part, **not both**. Resolved parts must belong to their tagged fixture and assigned plot. Models should have explicit PrimaryParts; the existing physical-part fallback remains supported. Runtime fixture lookup uses tags only and returns no fixture for a missing, duplicate, or invalid role.

Stash slot **BaseParts** have Number attributes named exactly `SlotIndex`: `LockedSlot1=1`, `LockedSlot2=2`, `Slot3=3`, `Slot4=4`, `Slot5=5`. No slot tags are needed. Values must be unique integers. Visible names do not authorize slots or protection; inventory rules protect indices 1 and 2 for normal storage. Existing optional VIP slots 6-10 remain supported and must also be unique; this Plot1 needs only 1-5. Invalid/duplicate numeric slot indices do not receive stash prompts. Author slot attributes before Play so component binding sees them.

`Approach`, `ContentSpawnArea`, `Body`, `Blades`, `Liquid`, `Glass`, `VFX`, and `BlendVisualOrigin` need no additional gameplay tags. The current presentation hooks do not look these names up. Customers currently move directly Spawn -> Counter -> Exit; Approach is not used yet.

Legacy startup compatibility can auto-tag old fixture names only when that role has no tag inside the plot. An explicitly tagged `InputZone` therefore wins over a decorative object named `BlenderInput`. No instances are renamed. Old `workspace.Plots` children and the legacy top-level `workspace.Blender` remain compatible plot roots. New fixtures added during Play should be tagged explicitly.

Optional assets remain `ServerStorage.Ingredients` (Models/BaseParts named by ingredient Id), `ServerStorage.Smoothie` (Tool with Handle), and `ServerStorage.Customer` (Model with PrimaryPart). Missing templates use the existing placeholders.

## Exact filming commands

Start **Play**, switch the Command Bar to **Server**, and run this setup once per session:

```lua
game.ServerStorage:SetAttribute("EnableDevContent", true)
game.ServerStorage:SetAttribute("DebugFilmLoop", true)
```

Each command below is independent, with no reliance on Command Bar local variables surviving between submissions. For multiplayer replace `GetPlayers()[1]` with the intended player. APIs use the repository's **dot-call** convention.

Wait for the server's initialized message before running commands. In Studio, bootstrap publishes a server-only `ServerStorage.StudioServiceCalls` BindableFunction after initialization. Service modules required by Command Bar return shared tooling proxies that invoke the actual runtime services, preserving their dependencies, ingredient records, plot ownership, and blender state. No manual services table or service reinitialization is needed. This applies to direct `BlendService.TryInput(...)` calls as well as `DevContentService.ResetScene(player)` and `ResetPlot(player)`. Tooling cannot call service `Init`; calls before publication, in Edit mode, or from a client report an error. DevContent methods retain their `EnableDevContent` gate. Production creates no bridge and continues to use ordinary modules and `Init(services)`.

After syncing this change, stop and restart Play to rebuild the runtime and its bridge. Use dot calls, for example:

```lua
local services = game.ServerScriptService.Server.Services
local dev = require(services.DevContentService)
game.ServerStorage:SetAttribute("EnableDevContent", true)
local player = game.Players:GetPlayers()[1]
dev.SpawnIngredient(player, "Strawberry")
print(require(services.BlendService).GetSnapshot(player))
-- When ready to clear the scene:
-- dev.ResetScene(player)
```

The bridge forwards method arguments/results, not the services table or mutable module internals. Runtime scripts and components keep direct access to the original services.

Spawn Strawberry (four studs above your plot's tagged BlenderInput):

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

Spawn a serveable customer (stand near the tagged Start Day button first):

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

Validate the assigned Plot1 (prints each role and slot; returns `boolean, reportLines`):

```lua
local p = game.Players:GetPlayers()[1]; local ok = require(game.ServerScriptService.Server.Services.DevContentService).ValidatePlot(p); print("Plot valid:", ok)
```

A successful report starts `[Plot Validation] Plot1`, then `PASS PlayerPlot`, one PASS for each required role, and `PASS SlotIndex 1` through `PASS SlotIndex 5`. Failures identify missing/duplicate roles (duplicate paths are listed), nonphysical markers, a detector tagged on a Model, disabled CanQuery, nested plots, or invalid/missing/duplicate slot indices. Tags outside the assigned plot never satisfy its roles. Validation is read-only: it does not assign a plot, move/rename objects, add tags, or change gameplay state. If there is no assigned plot, it reports that failure. As with all dev commands, production or missing opt-in returns false without a validation printout.

`ResetBlender` and `ResetScene` remain aliases for `ClearBlender` and `ResetPlot`. `ForceReaction` also accepts `Love`, `Disgust`, `Freeze`, `NoobTransform`, the existing reaction IDs, or `nil` to return to weighted selection. Grade and payout never depend on the reaction.

`PrepareCombination` **stages physical props**. SpawnIngredient and PrepareCombination place props four studs above the assigned plot's tagged `BlenderInput` in its local frame, spreading a combination three studs apart. Staging requires a unique tagged InputZone BasePart in that plot; it returns no result if the plot or valid input is missing. Character position and legacy `IngredientSpawn` tags do not affect staging. It clears owned loose ingredients, a held ingredient, and the loaded batch. It leaves an existing smoothie cup/customer intact. `ClearBlender` only clears the batch. `ResetPlot` clears held/loose ingredients, cup, batch, active/exiting customers, and the day session; cash, upgrades and ordinary carried/stash inventory remain. A held physical unit is discarded on reset, respawn, or leaving.

`SpawnCustomer` starts a normal day, returns the existing active customer, or resumes a day whose next customer failed to spawn. It keeps normal proximity checks. The first two serves still spawn the next customer automatically; three finish the day. For one-shot takes, reset between customers. Missing markers produce warnings and a failed command, without blocking bootstrap.

Every dev API requires **both Studio and EnableDevContent=true**, including ValidatePlot and reset aliases. There is no developer remote. `DebugFilmLoop` is the only logging switch and is separately Studio-gated. Turn both attributes off after filming.

## Record the loop

1. Near the tagged Start Day button, spawn a customer and optionally force a reaction.
2. Prepare the combination above your plot's InputZone. Pick up each prop with its prompt. It equips automatically; click/tap to throw while equipped. Move close enough to face and throw into InputZone, tuning distance for your real blender placement. Repeat for up to three props. Aim follows character facing, not mouse position.
3. Check accepted count and LOADING/READY logs. One or two ingredients seal through READY on the first measured physical spin; three become READY immediately. A fourth stays in the world. Registered units must overlap this owner's detector; its 0.1-second polling accepts each only once.
4. Physically push the turbine wheel until COMPLETE. Keep the tagged blade unanchored with working rotation constraints. Server Heartbeat measures `blade.AssemblyAngularVelocity.Magnitude`: progress is angular speed times `Economy.BlendProgressScale` (default 3) times delta time. Faster spin gives proportionally faster progress; stopping the blade gives zero, and coasting still counts after stepping away. There is no turbine prompt. The existing billboard shows progress. Output logs progress at 10-point boundaries and the resulting color. `PhysicsService.GetRPM(blade)` is available for display/debugging only.
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

`FilmingUtil.Emit` is the only server sender: it calls `GameplayPresentation:FireAllClients(moment, ownerUserId, payload)`. There are no `FireClient` sends for this remote. `moment` is a string, `ownerUserId` is the owning player's numeric UserId, and `payload` is the table below. The server creates the RemoteEvent once; repeated `FilmingUtil.Init()` calls reuse it.

| Moment | Server call site | Payload | Frequency |
| --- | --- | --- | --- |
| BlendStarted | BlendService.AddProgress | `{ IngredientIds: {string} }` | Once on READY -> BLENDING |
| BlendProgressChanged | BlendService.AddProgress | `{ Progress: number }` (0-100) | Changed progress, at most 10 Hz per batch, plus immediate final progress |
| BlendCompleted | BlendService.AddProgress | `{ BlendId: string, Color: Color3, IngredientIds: {string}, RecipeId: string? }` | Once on completion |
| SmoothieDispensed | BlendService.Dispense | `{ BlendId: string, Color: Color3, Cup: Tool }` | Once on successful dispense |
| CustomerReaction | CustomerService.Serve | `{ BlendId: string, Customer: Model, ReactionId: string, Grade: string, Payout: number }` | Once on successful serve |

Instance fields can arrive as nil if the instance has not replicated to an observer. Ingredient lists are copies. GameplayPresentation is output-only; no server listener accepts client messages. Attribute snapshots remain available if a client misses an event.

`src/client/init.client.luau` starts `GameplayPresentationController` before SprintController. Its idempotent Init asynchronously waits for the server-created remote and attaches one `OnClientEvent` listener. The listener currently drains all kinds without adding effects, including unknown kinds and malformed payloads. Existing visuals continue to use replicated attributes and server-created UI/audio. Add future cosmetic handlers inside this controller, keeping the single subscription. No presentation event grants gameplay authority.

Progress throttling affects only notifications. Every accepted RPM delta still updates the server batch and its replicated attributes; turbine ingestion, state transitions, and completion calculations are unchanged.

Payout in the event is a display value after the transaction. It grants no authority. Result colors use the RGB mean of every unit, including repeated units and Mystery; there is no random color override. Recipes remain optional multiset discoveries.


No new VFX controller is installed. Love/Disgust/Freeze/Launch/NoobTransform are replicated reaction IDs, not physical effects. Existing basic text/audio/sparkles remain. Final blender/ingredient/customer art, grip tuning, reaction animation/VFX, and filming camera work remain Studio tasks. Ants, stealing, PvP, HUD, monetization and persistence were not extended.

## Validation and remaining checks

Completed checks for this change: **301 domain assertions passed**, all **38 source files compiled**, Roblox-aware Luau LSP analysis passed with **zero type errors**, StyLua passed on all **5 touched Luau files** (including tests), Rojo **7.7.0** build passed, and `git diff --check` passed. The LSP emitted only its CLI watch-registration warning; automatic watch support is irrelevant to the completed one-shot analysis. Build output and sourcemap are in the system temporary tools directory. `default.project.json` is unchanged.

Run `python tests/run_state_tests.py --luau <luau-executable>`, compile `src/*.luau` recursively, run Roblox-aware Luau LSP analysis with Rojo sourcemap/definitions, check touched files with StyLua, build with Rojo, and run `git diff --check`.

Domain tests cover genuine/duplicate/foreign ingestion; 1–3 units and state transitions; color averaging/Mystery/order; incomplete/duplicate dispense; pickup/throw reservation; one-use/foreign/forged cups; actual cash transactions; separate reactions/grades; real three-customer callbacks; presentation moments; production security and reset cleanup. The fake engine explicitly simulates overlaps and waypoint time: these tests cannot certify real collision detection or networking.

Studio acceptance still required: boot with no fixtures (warnings, no hang); create this plot; perform the full physical loop; test another player's pickup/dispense/serve rejection; reset while holding a prop; respawn with a cup; remove/restore customer markers; confirm client event delivery. No Studio Play session was run from this workspace.

## Files changed for Plot1 tag compatibility

| File | Change |
| --- | --- |
| `src/server/Services/TycoonService.luau` | Tag-only runtime lookup, duplicate rejection, reusable legacy auto-tagging that respects existing roles |
| `src/server/Services/DevContentService.luau` | Read-only Studio/opt-in ValidatePlot report; plot-scoped BlenderInput staging with a four-stud upward offset |
| `src/server/Components/Stash.luau` | Bind unique integer SlotIndex values independently of visible names |
| `src/server/init.server.luau` | Delegate legacy migration to TycoonService |
| `tests/server_state.spec.luau` | Real tag lookup, migration precedence, validation failure cases, production gate and plot-scoped staging tests |
| `docs/FILMING_VERTICAL_SLICE.md` | Current hierarchy, mapping, attributes, exact commands and validation |
