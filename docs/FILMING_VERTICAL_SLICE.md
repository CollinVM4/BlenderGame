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

## Ingredient spawn stations (V1)

In Edit mode, create a Folder named `Ingredient Spawns` directly under Workspace. Add three anchored, collidable Parts, about `8, 1, 8` studs, on level ground away from BlenderInput. Names are organizational; tag each **Part itself** `IngredientSpawn` using Studio's Tags property/Tag Editor. Set attributes before Play:

| Part | Tag | `IngredientId` (String) | `RespawnSeconds` (Number) |
| --- | --- | --- | --- |
| StrawberrySpawn | IngredientSpawn | Strawberry | 5 |
| BananaSpawn | IngredientSpawn | Banana | 5 |
| TireSpawn | IngredientSpawn | Tire | 5 |

No plot ownership, dev-content opt-in, models, or additional tags are required. Do not tag the Folder or manually add IngredientWorldItem. IngredientService.Spawn creates the registered item and supplies its definition's BlendColor cube when no optional template exists. Keep the stations level: spawn position is three studs above the station's top along its local up axis. Items are unanchored and settle under physics.

Each station holds one active world item, even if it rolls away or moves elsewhere within Workspace. Consumption, destruction (including the existing 120-second world-item expiry), or leaving Workspace starts the delay. An item moved out of Workspace is destroyed so it cannot later return as duplicate stock. Removing the tag, destroying the station, or moving it out of Workspace disconnects item listeners, cancels the timer, and destroys remaining stock. Retagging/re-entry starts fresh. Station configuration is read at attachment: retag after changing attributes during Play. Missing, nonnumeric, nonpositive, NaN, or infinite delays default to 5; invalid IDs/non-BaseParts warn and do not spawn. Old tagged staging tables need a valid IngredientId or their tag removed.

Short live verification (after Rojo sync and a fresh Play session):

1. On the Server view, confirm one colored item per station and no duplicates after more than five seconds. Select the spawned item (direct child of Workspace) to inspect IngredientWorldItem, IngredientId, and OwnerUserId=0.
2. With only these stations supplying unowned Strawberry items, run in the **Server Command Bar**:

   ```lua
   local ingredients = require(game.ServerScriptService.Server.Services.IngredientService)
   for _, item in game:GetService("CollectionService"):GetTagged("IngredientWorldItem") do
       local record = ingredients.GetRecord(item)
       if record and record.Id == "Strawberry" and not record.Owner then
           assert(ingredients.Consume(item) == "Strawberry")
           break
       end
   end
   ```

3. Confirm Strawberry returns once after about five seconds; Banana/Tire stay at one each. Delete the new Strawberry item in Server view, then remove StrawberrySpawn's tag before five seconds elapse. Wait longer than five seconds: no replacement. Reapply the tag: one appears immediately. Delete the station: its remaining item disappears and stays gone.

**Pickup/carry/throw:** unowned claimable station items and your own dev props now expose exactly one prompt, `Pickup` (`CarryPrompt`). Pickup equips a Tool; click/tap throws a new registered item owned by the thrower. A consumed station item starts that station's refill timer. Other players may see a prompt on your loose props, but their requests are rejected by the server. Nonclaimable market stock keeps its pedestal interaction.

The old Dispenser component also bound IngredientWorldItem and created `PickupPrompt` with `Collect <Ingredient>`, sending the unit directly into logical inventory through ClaimWorldItem. That tag binding is removed. Dispenser retains its DispenseIngredient/ReleaseUnit API; ClaimWorldItem remains the internal transaction used by physical carry. Stop and restart Play after syncing so the previous session's prompt listeners are gone. Verify both a fresh station item and its replacement show only Pickup. Market pedestal collection is unchanged.

Authorization lives in InventoryService's private `getLoosePickupRecord(player, object)`, shared by CarryWorldItem and ClaimWorldItem. It validates the current registry record, claimability, loose-item ownership (unowned or requesting owner), living character, and distance. Carry also requires a Backpack and an empty held slot. The existing AddUnit capacity check runs before consumption; claim-to-held transfer does not yield and consumes the original registry identity exactly once. The held reservation does not also count as a carried inventory unit. Failed consumption rolls back the inventory addition.

This ownership rule is scoped to **loose-world pickup**, not every inventory transfer. A future stash-to-held transaction must resolve the actual server-owned stash/slot, validate proximity and protection, and explicitly authorize owner withdrawal or stealing from an unprotected slot before reserving a unit. Protected slots remain owner-only. It must not treat client-provided SlotIndex/OwnerUserId attributes as permission or add a generic bypass flag to loose pickup. Existing stash code is unchanged; no new stash interaction is included here.

Live interaction verification after syncing and restarting Play:

1. Keep the station setup above and the assigned plot's BlenderInput. Walk within prompt range of StrawberrySpawn's item and activate Pick up. Confirm one equipped Strawberry Tool, the original loose item disappears, and the station refills after five seconds. While holding it, try another ingredient: it must remain in the world.
2. Face your blender opening, approach closely, and click/tap with the Tool equipped. Confirm the Tool disappears and the thrown item is accepted once: BlendIngredientCount increases by one. Repeated clicks must not create more ingredients. Throw follows character facing, not mouse aim.
3. In Studio's Server & Clients test with two players, approach the same station item and activate its prompt at nearly the same time. Exactly one player should equip it. Repeat on the next spawn with the other player activating first.
4. Have the winner throw onto open ground away from BlenderInput. The other player's pickup must fail; the owner can pick it up again. Move out of range and verify pickup is unavailable. For owned-dev regression, run the existing SpawnIngredient command below and confirm its owner can pick up and throw the prop as before.

Station stock is independent of DevContent resets; remove a station's tag to clear it for a take. Both station items and owned DevContent props can supply the filmed pickup/throw loop below. Live physics, prompt reach, Tool grip, and multiplayer replication still require Studio verification.


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

Unowned claimable and owned loose props receive pickup prompts; shared market collection retains its existing path. Pickup transfers the world unit into a server reservation owned by InventoryService, displayed using a clone of its visual model. Throw consumes that reservation and spawns a newly registered physical unit. Neither the held visual nor editable attributes authorize ingestion. The Tool can be unequipped/re-equipped without duplicating the reservation.

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


No new VFX controller is installed. Love/Disgust/Freeze/Launch/NoobTransform are replicated reaction IDs, not physical effects. Existing basic text/audio remain. Final blender/ingredient/customer art, grip tuning, reaction animation/VFX, and filming camera work remain Studio tasks. Ants, stealing, PvP, HUD, monetization and persistence were not extended.

## Validation and remaining checks

Ingredient station and pickup checks: **366 server-state assertions passed**, all **41 source files compiled**, Roblox-aware Luau LSP analysis passed with **zero type errors**, StyLua passed on all **7 touched Luau files** (including tests/reference setup), Rojo **7.7.0** build passed, and `git diff --check` passed. The LSP emitted only its CLI watch-registration warning. Station tests run the real component, WorldUtil.BindTag, and IngredientService registry with simulated signals/time; they cover initial spawn/color/registration, one active item, independent/default/custom delays, consumption, removal, retag/re-entry, invalid configuration, and cleanup/cancellation. Pickup tests initialize both Dispenser and IngredientPickup with station spawning and real BindTag/Prompt creation, assert exactly one Pickup prompt before and after refill, and exercise its carry transaction. They also cover the actual prompt, distance/alive/capacity failures, both contention orders, foreign loose ownership, metadata forgery, one held unit, owned-dev regression, and throw through the actual BlenderInput component. Build output and sourcemap are in the system temporary tools directory. `default.project.json` is unchanged. Live Studio verification remains required.

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
