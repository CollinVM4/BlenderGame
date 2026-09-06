# Be a Blender! MVP architecture

This is an executable server skeleton, not a finished playable release. The Rojo mappings are unchanged. Data is in memory and is lost when a player leaves. Studio fixtures are not included in this repository.

## Core loop and authority

PREP: collect shared market stock, optionally fight, and deposit carried ingredients in the plot stash. Start Day at your plot. A customer moves from the spawn marker to the counter and requests a loose preference. Release 1–3 owned units into the blender detector, turn the turbine, dispense a cup, and serve it. After three customers, the day receives a grade and finishes. Prepare/upgrades and another Start Day repeat the loop.

Any valid combination can be served. Ingredients supply tags and blend colors. Recipes are optional exact-multiset discoveries, including repeated ingredients; they are never customer requirements. Result color is the mean of the unit colors.

Grade measures preference fit and determines money. Reaction is an independent weighted roll. A D can roll `Launch`; this currently produces a reaction attribute/text label, **not a launch animation**. Sweet/Cold/Weird/Healthy/Red grade by matching-unit fraction (A ≥ 2/3, B ≥ 1/3, otherwise D for V1's 1–3 units). Surprise Me grades ingredient variety (three distinct = A, two = B, one = C).

## Services and initialization

The bootstrap explicitly loads services, injects dependencies, initializes existing/new players, starts sprint/network adapters, then binds components. There are no circular service requires. The registry is an intentionally small, loosely typed injection boundary; shared records and authoritative state use Luau types. No missing Workspace object is awaited.

| Module | Responsibility / main API |
| --- | --- |
| PlayerDataService | Cash, upgrade purchases, discovery/stat records, server-set entitlements. `GetSnapshot`, `GetCash`, `AddCash`, `SetCash`, `PurchaseUpgrade`, `GetUpgrade`, `HasEntitlement`, `SetEntitlement`. Persistence TODO is at `RemovePlayer`. |
| TycoonService | Assign one plot, release ownership, resolve fixtures. `AssignPlot`, `GetPlot`, `GetOwner`, `GetReference`. Old cash methods forward to PlayerDataService. Physical upgrade installation is TODO. |
| IngredientService | Sole world-unit registry and central definition access. `Spawn(id, cframe, owner?, claimable?)`, `Resolve`, `GetRecord`, `Consume`. Tagged/attributed objects without a server record are invalid. |
| InventoryService | Separate carried counts and indexed stash stacks. `AddUnit`, `RemoveUnit`, `ClaimWorldItem`, `ReleaseUnit`, `DropOne`, `Deposit`, `Withdraw`, `Steal`, `GetSnapshot`. Transfers take one unit, without yielding. |
| BlendService | Batch state, progress, contents, color, discoveries, genuine cup identity. `TryInput`, `Ready`, `AddProgress`, `Interact`, `Dispense`, `GetCup`, `ConsumeCup`, `Reset`, `ClearCup`, `GetSnapshot`. |
| CustomerService | Owned customers, waypoint movement, preferences, serving transaction, separate `CalculateGrade`, `SelectReaction`, `CalculatePayout`. `SpawnForPlayer`, `CanSpawn`, `Serve`, `GetSnapshot`; served callback notifies GameService. |
| GameService | Per-player orchestration only. `StartDay`, `IsServing`, `CustomerServed`, `FinishDay`, `ResumeDay`, `Reset`, `GetSnapshot`. No inventory, grading, or payout implementation here. |
| MarketService | One physical stock unit per registered pedestal; weighted rarity selection, atomic claims and respawn. `Register`, `Unregister`, `Step`, `Claim`, `SelectIngredient`, `SpawnDrop` for future ants. |
| CombatService | Optional placeholder slap Tool and server checks for equipped identity, facing, range, obstruction, cooldown, damage, knockback, stun and one-unit drop. `GrantHand`, `Slap`, `RemovePlayer`. |
| DevContentService | Opt-in Studio filming operations: `SpawnIngredient`, `ResetBlender`, `PrepareCombination`, `SpawnCustomer`, `ForceReaction`, `ResetScene`, `IsEnabled`. No dev remote. |
| GameplayService | Narrow, throttled client request adapter for a future inventory UI. Does not own gameplay state. |
| SprintService | Existing sprint/stamina behavior. Rejects non-boolean requests and respects the server's short movement stun. |
| PhysicsService | Existing spin sampling. `GetBlendDelta(part, dt?)` supports framerate-independent progress and preserves one-argument behavior. |
| AudioService | Existing sound assets and blend group behavior retained; return type clarified. |
| WorldUtil | Internal part lookup, living-player distance checks, prompt creation, tag attachment/cleanup; not a gameplay service. |

### Blend state machine

`EMPTY → LOADING → READY → BLENDING → COMPLETE → DISPENSED → EMPTY`

- First/second units enter LOADING; three units enter READY. The first positive turbine interaction seals a 1–2 unit batch through READY. Nothing loads while blending or complete.
- Inputs require a registered world unit owned by the plot owner and actual server overlap with that plot's detector. Rejected units are not consumed. Detector must have `CanQuery` enabled.
- Turbine component only reports server-observed spin using delta time or a fixed prompt interaction. BlendService validates living-player proximity, plot ownership, state, finite positive delta, upgrades, and the completion cap. Prompt turns are limited to one per 0.25 seconds.
- COMPLETE produces a record at 100%; discovery and smoothie stats increment once. Dispense requires ownership, proximity, Backpack, and no existing valid cup. A supplied `ServerStorage.Smoothie` Tool is cloned; otherwise a plain cup Tool is generated.
- The server stores the Tool's identity and result, independently of Tool attributes. Serving destroys/consumes it once. Attributes are presentation only. Dispense publishes DISPENSED, then defers EMPTY; the cup record survives that batch reset.
- `Reset` discards only the loaded batch. `ClearCup` removes a cup separately. Respawn clears the cup, retains the batch/day/inventory, and clears movement stun. Leaving removes all per-player state and owned world items.

### Day state machine

`PREP → SERVING → FINISHED → SERVING …`

StartDay checks an assigned plot, living-player distance to its button/counter, and the three customer markers before committing. Duplicate starts are rejected. Successful serving consumes a server cup, computes grade/reaction/reward, awards cash, removes the active customer, then notifies GameService. The first two callbacks spawn successors; the third ends the day. Grade scores A=4/B=3/C=2/D=1 are averaged and rounded at 3.5/2.5/1.5 thresholds.

If a marker disappears between customers, the day remains SERVING and warns. Restore the marker and call `GameService.ResumeDay(player)` from the server; it refuses an already active customer. `Reset` returns to PREP for scene recovery. Customers already served exit independently and are cleaned on leave/reset as well.

### Inventory, market, combat, economy defaults

- Carried inventory is one stack per ingredient ID, cap 5 (earned upgrade to 10). There is no total carried-slot limit in this skeleton. Materializing/throwing a unit removes it from carried counts; collecting it returns it to counts. Throw position/velocity are computed on the server. Physical holding/aim controls are TODO.
- Normal stash: five slots, first two protected. VIP: ten slots, first five protected. Each slot is one ingredient stack. Capacity/protection use server entitlements, not attributes. Downgrading VIP preserves inaccessible upper slots in memory rather than deleting items. A production entitlement adapter must define retention across saves.
- Steals require living-player proximity to the victim stash, an unprotected valid slot, and room in the thief's stack. One unit moves per success. Thief cooldown is 3s; victim protection is 5s. Failed transfers do not remove items.
- Market stock is free in this skeleton. One claimant wins; full inventory leaves stock intact. Refill after claim is 12s. Unclaimed world stock expires after 120s, then refills with another rarity-weighted selection. Tags removed/re-added and objects moved out of/into Workspace detach/rebind components.
- Slap Tool must be granted by a trusted server caller. Three earned Hand levels define damage/knockback/size. Slap cooldown 0.8s; range 8 studs; movement stun 0.5s with 1s immunity after it; carried-unit drop protection 4s. Only logical carried inventory participates in slap drops; an already-thrown world item is not dropped again. NPC combat/ants are TODO.
- Cash payout is floor(base 25 × grade multiplier × earned Payout upgrade × optional DoubleCash). VIP Storage and DoubleCash default false. No pass IDs, receipts, prompts, or MarketplaceService calls are implemented.

## Workspace/tag contract

Create physical models in Studio. Put plot fixtures under their owning plot; tags do not use arbitrary client-supplied plot IDs. All interactive static fixtures should be anchored. Avoid nested plots and duplicate fixtures of the same role in one plot.

| Tag / object | Required setup |
| --- | --- |
| `PlayerPlot` | Tag a Model/Folder per player plot, or use direct children of `workspace.Plots`. Assigned in name order; `OwnerUserId` is written by the server. A legacy `workspace.Blender` is treated as a single plot. |
| `BlenderInput` | One invisible anchored BasePart at the blender opening, inside the plot. `Transparency=1`, `CanCollide=false`, `CanQuery=true`. Make it deep/wide enough for the 0.1s overlap polling interval. |
| `TurbineWheel` | Tag the actual spinning blade/stem BasePart (or Model with PrimaryPart) inside the plot. Preserve your existing turbine constraints. A generated Turn prompt also supplies manual progress for filming. Stand within 12 studs of the tagged part. No rope. |
| `DispenseButton` | BasePart or Model with PrimaryPart inside plot. Component generates a Dispense prompt. |
| `StartDayButton` | BasePart/Model with PrimaryPart inside plot, near counter. Component generates Start Day prompt. |
| `CustomerSpawn` | Anchored marker BasePart inside each plot; CFrame marks the NPC's pivot, not its foot. |
| `CustomerCounter` | Anchored marker BasePart for arrival/serving, inside plot. Keep within reach. |
| `CustomerExit` | Anchored exit marker BasePart inside plot. Route is straight-line spawn→counter→exit, without pathfinding or obstacle avoidance. |
| `MarketPedestal` | Anchored BasePart/Model with PrimaryPart in the shared market. One auto-generated physical stock unit and Collect prompt. No IngredientId attribute needed. |
| `PlayerStash` | Model with PrimaryPart, inside plot. Optional child Slot1…Slot10 BaseParts with integer `SlotIndex` attributes generate take/steal prompts. Put slots within 12 studs of the primary part. Deposit uses the API/remote until inventory UI is built. |
| `IngredientWorldItem` | Applied **by IngredientService**, together with IngredientId/OwnerUserId attributes. Tagging a decorative ingredient by hand does not register or grant it. |
| `ServerStorage.Ingredients` | Optional Folder of Models/BaseParts named by ingredient ID. Models need a PrimaryPart and welded parts; avoid scripts/Tools in templates. Missing templates use colored cubes. |
| `ServerStorage.Smoothie` | Optional Tool with a normal unanchored Handle and welded decorations. Missing template generates a plain cup. |
| `ServerStorage.Customer` | Optional Model with a PrimaryPart. The skeleton anchors all its parts and moves its pivot. Missing template generates the existing style of simple torso/head customer. |

Legacy named fixtures under `workspace.Plots`/`workspace.Blender` receive corresponding tags at startup. `Turbine/.../blade` or `stem` is recognized. Fixtures added later should be tagged explicitly. Tag binding responds to tag additions/removals and ancestry changes; no hardcoded Plot1 wait remains. Plot assignment retries on StartDay if no plot existed at join.

Customer `StoreCustomer` tags no longer auto-create a global customer. Migrate its visual model to `ServerStorage.Customer` and supply plot markers. `CreateCustomer(spawnTarget, owner)` remains a colon-call adapter, but owner is required and plot markers now determine placement. `ServeCheck` authenticates cups; `GetSatisfaction` returns a letter grade; `RefreshOrder` rerolls a preference. The old `ActiveCustomer` singleton and public mutable customer table are replaced by per-player `GetSnapshot`.

## Network and presentation

Existing SprintRequest remains server-created. New `ReplicatedStorage.Shared.Events.GameplayRequest` is a RemoteEvent with the positional request contract `(action, id?, slot?)`:

| Action | Arguments | Server behavior |
| --- | --- | --- |
| StartDay | none | Ownership/proximity/fixture/day validation. |
| ReleaseIngredient | ingredient ID | Removes one owned unit and throws it forward/up from the player's character; position and speed are server-selected. |
| Deposit | ingredient ID, slot index | One carried unit to the player's nearby stash. |
| Withdraw | nil, slot index | One unit from the player's nearby stash. |
| PurchaseUpgrade | Hand/StackSize/BlendSpeed/Payout | Buys only the next level at the configured cash cost. |

Requests are throttled per player (0.15s); strings/slot bounds are checked before use. There is no remote for damage amounts, cash grants, blend completion, smoothie contents, reactions, or developer actions. World prompts independently enter validated service APIs. UI request responses and an inventory snapshot subscription remain TODO; `GetSnapshot` is server-only today.

Player attributes expose `playerCash`, `BlendState`, `BlendProgress`, `BlendIngredientCount`, `HasSmoothie`, `CurrentRecipeName`, `DayState`, `DayNumber`, `CustomersServedToday`, `DayGrade`, `CustomerSatisfaction`, `CustomerReaction`, and sprint state. DayButton also publishes `LastActionError`. These are output for future UI, never authoritative input. Existing UI stubs/client controller remain otherwise unchanged.

Security follows Roblox's guidance to validate even [ProximityPrompt interactions on the server](https://create.roblox.com/docs/scripting/security/client-server-boundary). Ingredients and unanchored turbines request [server network ownership](https://create.roblox.com/docs/physics/network-ownership). A full movement/teleport anti-cheat is outside this pass.

## FILMING MVP NEXT STEPS

- [ ] Create one plot and all blender/day/customer fixtures above; first test with placeholder assets.
- [ ] In Studio Play, set `ServerStorage` attribute `EnableDevContent=true`. It is false/unset by default and is additionally blocked outside Studio, even if published enabled.
- [ ] Use the **server** Command Bar after bootstrap (replace player selection in multiplayer):

```lua
local player = game.Players:GetPlayers()[1]
local services = game.ServerScriptService.Server.Services
local dev = require(services.DevContentService)
game.ServerStorage:SetAttribute("EnableDevContent", true)
dev.ResetScene(player)
-- Stand by your StartDayButton/counter or use its prompt.
require(services.GameService).StartDay(player)
dev.PrepareCombination(player, { "Strawberry", "Banana", "Ice" })
dev.ForceReaction(player, "Launch") -- selects a reaction ID, not animated VFX
```

- [ ] Turn turbine, dispense, and serve. Repeat three times and confirm FINISHED/grade/cash. `PrepareCombination` loads through the registered input path and clears previous owned loose props first; it does not grant inventory or complete the blend.
- [ ] For physical drop shots use `dev.SpawnIngredient(player, "Tire")`, which spawns above the detector; use `dev.ResetBlender(player)` to discard a batch. `ResetScene` also removes cups, active/exiting customers and owned loose ingredients; it retains cash/upgrades/inventory.
- [ ] `dev.SpawnCustomer(player)` stages a customer without starting a day; serving still requires SERVING. Reset that staged scene before using Start Day.
- [ ] Add final ingredient/cup/customer models, tune detector and turbine placement, and create reaction animations/VFX as a separate presentation step.
- [ ] Capture sweet, weird, and D-grade/rare-reaction combinations after live Studio verification. Disable the opt-in flag when done.

## PLAYABLE MVP NEXT STEPS / intentional TODOs

- [ ] Build minimal inventory selection/HUD and feedback over the existing request adapter; implement snapshot sync, held-unit/aim interaction, and full stash slot/deposit presentation.
- [ ] Playtest shared stock and one-unit stealing with two clients, capacity limits, protected slots, distance rejection and cooldowns. Tune market rotation, pickup feel and economic balance.
- [ ] Add the actual slap-hand asset, grant/equip/respawn wiring, upgrade visuals and combat presentation. Server-only test grant: `require(services.CombatService).GrantHand(player)`. Test walls, facing, death, stuns and drop immunity in Studio.
- [ ] Implement ant spawn/chase/damage/stun/defeat AI; call MarketService.SpawnDrop from a trusted defeat handler. No ant AI is implemented.
- [ ] Replace straight-line customer pivot movement with rig locomotion/pathfinding if the scene needs obstacles; add reaction animation/VFX. Existing chirps, serve sound and sparkles are retained.
- [ ] Add physical plot upgrade application and upgrade purchase UI. Configured earned Hand/StackSize/BlendSpeed/Payout purchases already update their server values.
- [ ] Implement production persistence at PlayerDataService's boundary: loading, saving, failures, session ownership, shutdown and migrations. No datastore implementation or offline earnings exist here.
- [ ] Connect verified VIPStorage/DoubleCash entitlement checks; no purchase prompts or monetization fulfillment exists here.
- [ ] Add reconnect/death UX, automatic recovery if fixtures disappear mid-day, late-created plot assignment UX, and intentional handling of no free plots.
- [ ] Keep production development utilities inaccessible. Do not add a remote that forwards arbitrary service/function names.

## Validation

`tests/run_state_tests.py` bundles the actual service source into Luau CLI with a mocked Roblox boundary. It checks domain transactions and state, not physics, engine instance replication or graphics. Run `python tests/run_state_tests.py --luau <path-to-luau>`.

Available checks used for this pass: Rojo build, Luau syntax compilation of `src`, Luau LSP analysis with Roblox definitions plus a Rojo sourcemap, StyLua on touched Luau files, and the domain assertions. No Studio playtest is claimed.

Validation results for this implementation: Rojo 7.7.0 build passed; all 36 source files compiled; Roblox-aware Luau LSP analysis passed without type errors; StyLua 2.5.2 passed on 31 touched Luau files; all 80 domain assertions passed; `git diff --check` passed. `default.project.json` has no diff. The installed Aftman shim could not locate its home directory, so verification used the existing versioned Rojo executable directly. Validation tools and build artifacts were kept in the system temporary directory.

```text
rojo build default.project.json -o <temporary-output>.rbxlx
rojo sourcemap default.project.json -o <temporary-sourcemap>.json
luau-compile <each-src-file.luau>
luau-lsp analyze --platform=roblox --sourcemap=<map> --definitions=<globalTypes.d.luau> src
stylua --check <changed-and-added-luau-files>
python tests/run_state_tests.py --luau <luau-executable>
git diff --check
```

Studio acceptance: boot an empty Workspace (warnings but no blocked bootstrap); then a one-plot scene for the complete three-customer loop; then two plots/clients for foreign input/dispense/serve rejection, contested claims, protected stealing, cooldowns, respawn and leave/reset cleanup. Remove/re-add tags and reparent fixtures out of/into Workspace to verify component detachment and rebinding. Missing customer markers must leave the day unstarted or recoverable via ResumeDay.
