# Be a Blender! MVP architecture

The architecture now supports a filmable vertical slice, not a finished playable release. See [FILMING_VERTICAL_SLICE.md](FILMING_VERTICAL_SLICE.md) for the current physical controls, exact reference scene, filming commands and presentation events. The Rojo mappings are unchanged. Data is in memory and is lost when a player leaves. Studio fixtures are not included in this repository.

## Core loop and authority

Claiming a plot automatically starts an endless customer queue. Up to three customers walk to the counter and two waiting markers, each showing an order. Collect ingredients, blend, dispense, and serve only the counter customer. Waiting customers advance while the served NPC reacts and exits; timed arrivals refill free slots. See [CUSTOMER_QUEUE.md](CUSTOMER_QUEUE.md) for lifecycle, authority, configuration, and Studio setup.

Any valid combination can be served. Ingredients supply tags and blend colors. Recipe matching has been removed; the optional smoothie Discovery field remains nil for compatibility. Result color is the mean of the unit colors.

Grade measures preference fit and determines money. Reaction is an independent weighted roll. A D can roll `Launch`; this currently produces a reaction attribute/text label, **not a launch animation**. Sweet/Cold/Weird/Healthy/Red grade by matching-unit fraction (A ≥ 2/3, B ≥ 1/3, otherwise D for V1's 1–3 units). Surprise Me grades ingredient variety (three distinct = A, two = B, one = C).

## Services and initialization

The bootstrap explicitly loads services, injects dependencies, initializes existing/new players, starts sprint/network adapters, then binds components. There are no circular service requires. The registry is an intentionally small, loosely typed injection boundary; shared records and authoritative state use Luau types. No missing Workspace object is awaited.

| Module | Responsibility / main API |
| --- | --- |
| PlayerDataService | Cash, upgrade purchases, discovery/stat records, server-set entitlements. `GetSnapshot`, `GetCash`, `AddCash`, `SetCash`, `PurchaseUpgrade`, `GetUpgrade`, `HasEntitlement`, `SetEntitlement`. Persistence TODO is at `RemovePlayer`. |
| TycoonService | Assign one plot, release ownership, resolve fixtures. `AssignPlot`, `GetPlot`, `GetOwner`, `GetReference`. Old cash methods forward to PlayerDataService. Physical upgrade installation is TODO. |
| IngredientService | Sole world-unit registry and central definition access. `Spawn(id, cframe, owner?, claimable?)`, `Resolve`, `GetRecord`, `Consume`. Tagged/attributed objects without a server record are invalid. |
| InventoryService | Separate carried counts and indexed stash stacks. `AddUnit`, `RemoveUnit`, `ClaimWorldItem`, `ReleaseUnit`, `DropOne`, `Deposit`, `Withdraw`, `Steal`, `GetSnapshot`. Transfers take one unit, without yielding. |
| BlendService | Batch state, progress, contents, color, discoveries, genuine cup identity. `TryInput`, `Ready`, `AddProgress`, `Dispense`, `GetCup`, `ConsumeCup`, `Reset`, `ClearCup`, `GetSnapshot`. |
| CustomerService | Owned customers, waypoint movement, preferences, serving transaction, separate `CalculateGrade`, `SelectReaction`, `CalculatePayout`. `SpawnForPlayer`, `CanSpawn`, `Serve`, `GetSnapshot`; served callback notifies GameService. |
| GameService | Per-player orchestration only. `StartDay`, `IsServing`, `CustomerServed`, `FinishDay`, `ResumeDay`, `Reset`, `GetSnapshot`. No inventory, grading, or payout implementation here. |
| MarketService | One explicit physical stock unit per registered pedestal; per-pedestal timing and visible carry claims. `Register`, `Unregister`, `Step`, `Claim`, `SpawnDrop` (explicit ID). See INGREDIENT_WORLD_SPAWNS.md for migration. |
| CombatService | Optional placeholder slap Tool and server checks for equipped identity, facing, range, obstruction, cooldown, damage, knockback, stun and one-unit drop. `GrantHand`, `Slap`, `RemovePlayer`. |
| DevContentService | Opt-in Studio filming operations: `SpawnIngredient`, `ClearBlender`/`ResetBlender`, `PrepareCombination`, `SpawnCustomer`, `ForceReaction`, `ResetPlot`/`ResetScene`, `IsEnabled`. No dev remote. |
| GameplayService | Narrow, throttled client request adapter for a future inventory UI. Does not own gameplay state. |
| MovementService | Resolves purchased movement stats and temporary Studio movement overrides. Publishes display attributes and applies jump. `RefreshPlayer`, `ApplyCharacter`, movement getters, `SetStudioLevel`, `RemovePlayer`. |
| SprintService | Owns runtime stamina/sprint state and is the sole WalkSpeed writer. Consumes MovementService, preserves stun precedence, validates capacity changes, and resets through bootstrap on respawn. |
| PhysicsService | `GetSpinStrength` measures `AssemblyAngularVelocity.Magnitude`. `GetBlendDelta(part, dt?)` multiplies it by `Economy.BlendProgressScale` and elapsed seconds (default 1/60). `GetRPM` is display/debugging only. |
| AudioService | Existing sound assets and blend group behavior retained; return type clarified. |
| FilmingUtil | Output-only GameplayPresentation events and Studio-only DebugFilmLoop logging. |
| WorldUtil | Internal part lookup, living-player distance checks, prompt creation, tag attachment/cleanup; not a gameplay service. |

### Blend state machine

`EMPTY → LOADING → READY → BLENDING → COMPLETE → DISPENSED → EMPTY`

- First/second units enter LOADING; three units enter READY. The first measured physical spin seals a 1–2 unit batch through READY. Nothing loads while blending or complete.
- Inputs require a registered world unit owned by the plot owner and actual server overlap with that plot's detector. Rejected units are not consumed. Detector must have `CanQuery` enabled.
- Turbine Heartbeat reports only server-observed physical angular speed times `Economy.BlendProgressScale` times delta time. Stationary blades add zero; faster spin adds proportionally more, with no speed threshold, speed cap, per-frame cap, or upgrade multiplier. BlendService validates plot ownership, state, finite positive delta, and the completion cap. Physical coasting continues regardless of owner proximity.
- COMPLETE produces a record at 100%; discovery and smoothie stats increment once. Dispense requires ownership, proximity, Backpack, and no existing valid cup. A supplied `ServerStorage.Smoothie` Tool is cloned; otherwise a plain cup Tool is generated.
- The server stores the Tool's identity and result, independently of Tool attributes. Serving destroys/consumes it once. Attributes are presentation only. Dispense publishes DISPENSED, then defers EMPTY; the cup record survives that batch reset.
- `Reset` discards only the loaded batch. `ClearCup` removes a cup separately. Respawn clears the cup and reserved held prop, retains the batch/day/ordinary inventory, and clears movement stun. Leaving removes all per-player state and owned world items.

### Customer flow lifecycle

`PLOT_INACTIVE -> PLOT_ACTIVE -> PLOT_INACTIVE`

CustomerService owns ordered queues, guarded timed arrivals, request assignment, and advancement. TycoonService ownership callbacks activate/deactivate flow. GameService receives serve notifications only for legacy summaries; its day fields never stop the queue. No third-customer completion or daily special reset remains. See [CUSTOMER_QUEUE.md](CUSTOMER_QUEUE.md).

## Workspace/tag contract

Create physical models in Studio. Put plot fixtures under their owning plot; tags do not use arbitrary client-supplied plot IDs. All interactive static fixtures should be anchored. Avoid nested plots and duplicate fixtures of the same role in one plot.

| Tag / object | Required setup |
| --- | --- |
| `PlayerPlot` | Tag a Model/Folder per player plot, or use direct children of `workspace.Plots`. Assigned in name order; `OwnerUserId` is written by the server. A legacy `workspace.Blender` is treated as a single plot. |
| `BlenderInput` | One invisible anchored BasePart at the blender opening, inside the plot. `Transparency=1`, `CanCollide=false`, `CanQuery=true`. Make it deep/wide enough for the 0.1s overlap polling interval. |
| `IngredientSpawn` | Anchored BasePart anywhere in Workspace; String `IngredientId` matching a definition and optional Number `RespawnSeconds` (default 5). Spawns one unowned registered unit three studs above its top; refills after removal/consumption. See the station playtest in FILMING_VERTICAL_SLICE.md. |
| `TurbineWheel` | Prefer tagging the actual spinning blade BasePart inside the plot. Legacy Models must resolve to that blade. Keep the blade unanchored and preserve the physical turbine constraints so it can rotate. Physically push the wheel; progress comes only from server Heartbeat sampling. |
| `DispenseButton` | BasePart or Model with PrimaryPart inside plot. Component generates a Dispense prompt. |
| `StartDayButton` | BasePart/Model with PrimaryPart inside plot, near counter. Legacy physical fixture; its prompt is disabled. |
| `CustomerSpawn` | Anchored marker BasePart inside each plot; Horizontal marker top marks ground height. |
| `CustomerCounter` | Anchored marker BasePart for arrival/serving, inside plot. Keep within reach. |
| `CustomerWait1`, `CustomerWait2` | Anchored marker BaseParts for queue positions 2 and 3. |
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
| StartDay | none | Legacy idempotent activation for the owned plot; never forces a spawn. |
| ReleaseIngredient | ingredient ID | Removes one owned unit and throws it forward/up from the player's character; position and speed are server-selected. |
| Deposit | ingredient ID, slot index | One carried unit to the player's nearby stash. |
| Withdraw | nil, slot index | One unit from the player's nearby stash. |
| PurchaseUpgrade | Hand/StackSize/BlendSpeed/Payout/MovementSpeed/Jump/SprintStamina | Buys only the next level at the configured cash cost; movement purchases refresh resolved stats. |

Requests are throttled per player (0.15s); strings/slot bounds are checked before use. There is no remote for damage amounts, cash grants, blend completion, smoothie contents, reactions, or developer actions. World prompts independently enter validated service APIs. UI request responses and an inventory snapshot subscription remain TODO; `GetSnapshot` is server-only today.

Player attributes expose `playerCash`, `BlendState`, `BlendProgress`, `BlendIngredientCount`, `HasSmoothie`, `CurrentRecipeName`, `DayState`, `DayNumber`, `CustomersServedToday`, `DayGrade`, `CustomerSatisfaction`, `CustomerReaction`, and sprint state. DayButton also publishes `LastActionError`. These are output for future UI, never authoritative input. Existing UI stubs/client controller remain otherwise unchanged.

Security follows Roblox's guidance to validate even [ProximityPrompt interactions on the server](https://create.roblox.com/docs/scripting/security/client-server-boundary). Ingredients and unanchored turbines request [server network ownership](https://create.roblox.com/docs/physics/network-ownership). A full movement/teleport anti-cheat is outside this pass.

## FILMING VERTICAL SLICE

Current setup, commands, API semantics, events, testing limits and remaining Studio work are documented in [FILMING_VERTICAL_SLICE.md](FILMING_VERTICAL_SLICE.md). Use [studio/CreateReferencePlot.luau](studio/CreateReferencePlot.luau) in an empty Studio Edit session to create all placeholder fixtures without waiting for final assets.

`PrepareCombination` stages physical props above the assigned plot's tagged BlenderInput and resets the batch; it does not instantly ingest them. IngredientSpawn stations operate independently. `SpawnCustomer` starts/resumes a serveable day or returns the existing customer, keeping proximity validation. Legacy reset API names remain aliases. The pickup/throw Tool reserves exactly one inventory unit and uses server-selected launch velocity. Reaction IDs are replicated independently of grades, with no new polished animation/VFX.

## PLAYABLE MVP NEXT STEPS / intentional TODOs

- [ ] Build minimal inventory selection/HUD and feedback over the existing request adapter; implement snapshot sync, mouse aiming beyond the current character-facing throw, and full stash slot/deposit presentation.
- [ ] Playtest shared stock and one-unit stealing with two clients, capacity limits, protected slots, distance rejection and cooldowns. Tune market rotation, pickup feel and economic balance.
- [ ] Add the actual slap-hand asset, grant/equip/respawn wiring, upgrade visuals and combat presentation. Server-only test grant: `require(services.CombatService).GrantHand(player)`. Test walls, facing, death, stuns and drop immunity in Studio.
- [ ] Implement ant spawn/chase/damage/stun/defeat AI; call MarketService.SpawnDrop from a trusted defeat handler. No ant AI is implemented.
- [ ] Replace straight-line customer pivot movement with rig locomotion/pathfinding if the scene needs obstacles; add reaction animation/VFX. Existing chirps and serve sound are retained.
- [ ] Add physical plot upgrade application and upgrade purchase UI. Configured earned Hand/StackSize/BlendSpeed/Payout purchases already update their server values.
- [ ] Implement production persistence at PlayerDataService's boundary: loading, saving, failures, session ownership, shutdown and migrations. No datastore implementation or offline earnings exist here.
- [ ] Connect verified VIPStorage/DoubleCash entitlement checks; no purchase prompts or monetization fulfillment exists here.
- [ ] Add reconnect/death UX, automatic recovery if fixtures disappear mid-day, late-created plot assignment UX, and intentional handling of no free plots.
- [ ] Keep production development utilities inaccessible. Do not add a remote that forwards arbitrary service/function names.

## Validation

`tests/run_state_tests.py` bundles the actual service source into Luau CLI with a mocked Roblox boundary. It checks domain transactions and state, not physics, engine instance replication or graphics. Run `python tests/run_state_tests.py --luau <path-to-luau>`.

Available checks used for this pass: Rojo build, Luau syntax compilation of `src`, Luau LSP analysis with Roblox definitions plus a Rojo sourcemap, StyLua on touched Luau files, and the domain assertions. No Studio playtest is claimed.

Historical validation results for the architecture skeleton (before the filming slice): Rojo 7.7.0 build passed; all 36 source files compiled; Roblox-aware Luau LSP analysis passed without type errors; StyLua 2.5.2 passed on 31 touched Luau files; all 80 domain assertions passed; `git diff --check` passed. `default.project.json` has no diff. The installed Aftman shim could not locate its home directory, so verification used the existing versioned Rojo executable directly. Validation tools and build artifacts were kept in the system temporary directory.

```text
rojo build default.project.json -o <temporary-output>.rbxlx
rojo sourcemap default.project.json -o <temporary-sourcemap>.json
luau-compile <each-src-file.luau>
luau-lsp analyze --platform=roblox --sourcemap=<map> --definitions=<globalTypes.d.luau> src
stylua --check <changed-and-added-luau-files>
python tests/run_state_tests.py --luau <luau-executable>
git diff --check
```

Studio acceptance: boot an empty Workspace (warnings but no blocked bootstrap); then a one-plot scene for the endless queue loop; then two plots/clients for foreign input/dispense/serve rejection, contested claims, protected stealing, cooldowns, respawn and leave/reset cleanup. Remove/re-add tags and reparent fixtures out of/into Workspace to verify component detachment and rebinding. Missing customer markers prevent arrivals until repaired; the scheduler retries automatically.

## Movement upgrade foundation

PlayerDataService owns purchased levels and cash in private, in-memory records. Movement tracks retain definition indices 1?4; their replicated `MovementSpeedLevel`, `JumpLevel`, and `SprintStaminaLevel` attributes expose indices minus one (levels 0?3). Existing upgrade indexing is unchanged. Attributes are display output, never purchase authority. MovementService publishes effective displayed levels, including temporary Studio overrides; PlayerDataService records retain purchased levels.

| Display level | WalkSpeed | Sprint speed | Max stamina | Jump power equivalent | Cost to reach tier |
| --- | --- | --- | --- | --- | --- |
| 0 | 22 | 33 | 110 | 60 | 0 |
| 1 | 27 | 40.5 | 140 | 72 | 100 |
| 2 | 33 | 49.5 | 170 | 94 | 250 |
| 3 | 40 | 60 | 230 | 116 | 500 |

Tracks are independent. Tier values and temporary demo prices live only in `Constants/Upgrades.luau`. SprintConfig holds multiplier 1.5, drain 20/second, and regeneration 30/second with no delay. Full bars permit 5.5/7/8.5/11.5 seconds of continuous sprint.

MovementService resolves `BaseWalkSpeed`, `SprintWalkSpeed`, `MaxStamina`, and jump power from PlayerDataService. It publishes `BaseWalkSpeed`, `SprintWalkSpeed`, and `StaminaMax` alongside displayed levels, and emits its server-only Changed signal. SprintService consumes that signal to update capacity and speed immediately. MovementService does not depend on SprintService; dependencies flow from SprintService to MovementService to PlayerDataService and are injected by bootstrap.

SprintService alone writes Humanoid.WalkSpeed, on refresh/reset and Heartbeat: stunned = 0, sprinting = resolved sprint speed, otherwise resolved normal speed. It owns current stamina and sprint intent, publishing `StaminaCurrent` and `IsSprinting`. Increasing capacity adds only the capacity delta to current stamina, capped at the new max; decreases clamp current stamina. SetStaminaMax rejects nonpositive and nonfinite values. Exhaustion stops sprint at zero; the keyboard controller requires a fresh Shift press to restart. Dead/missing characters cannot keep sprint intent active.

Bootstrap owns the single CharacterAdded callback. It preserves existing inventory/cup/stun cleanup, reapplies resolved movement and jump, stops sprint, and fills stamina to the current purchased maximum. It handles characters already present during initialization. Missing Humanoids are awaited asynchronously for up to five seconds for jump application; stale characters and departed players are ignored. SprintService applies base speed immediately when possible or on its next update. With UseJumpPower false, jump uses `power^2 / (2 * workspace.Gravity)` without changing jump mode.

Studio movement commands use MovementService.SetStudioLevel for temporary overrides without changing purchased data. Overrides survive respawn; ResetMovement restores purchased movement stats. Leaving clears overrides and runtime state. These server-only APIs reject calls outside Studio Play.

The future Upgrades UI only sends `GameplayRequest:FireServer("PurchaseUpgrade", upgradeId)` and reads replicated server state/results. No UI is implemented. GameplayService reuses the same RemoteEvent in the server-to-client direction:

```lua
GameplayRequest.OnClientEvent:Connect(function(kind, result)
    -- kind == "PurchaseUpgradeResult"
    -- result = { success: boolean, reason: string, upgradeId: string?, level: number? }
end)
```

Reasons are `Success`, `InsufficientCash`, `MaxLevel`, and `InvalidUpgrade`. `level` is the current internal index minus one, including on insufficient-cash/max-level failures; invalid IDs have no level, and malformed IDs are not echoed. This result uses a zero-based level for legacy tracks as well, without changing their stored indices. The existing shared 0.15-second request throttle silently drops excess requests. The server derives costs, next index, and stat values; extra client arguments cannot dictate them. Successful movement purchases call RefreshPlayer. Direct server callers of PlayerDataService.PurchaseUpgrade must also refresh movement after a successful movement purchase.

Validation lives in `tests/server_state.spec.luau` and exercises the real services through a mocked Roblox boundary. Live Studio checks remain necessary for traversal feel, delayed character spawn, both jump modes, two-client attribute/result replication, sprint/stun interaction, and respawn. No new manually placed objects, map changes, UI, persistence, input modalities, or movement anti-cheat are required or added.

Historical movement foundation validation (before jump pad removal): 158 movement assertions passed, including pad handlers, purchase payloads, speed/stun behavior, stamina, jump modes, and respawn resets. The customer-only regression run (including VFX and movement coverage) passes. All source files compile, changed Luau files pass StyLua, Rojo 7.7.0 builds, and git diff --check passes. Full-suite execution stops at the pre-existing stash assertion `thin local X is thickness, display size is 4.4 studs`; this also reproduces from an isolated unchanged HEAD snapshot. Roblox-aware analysis reports no errors in movement changes but remains blocked by baseline errors in StashPromptController lines 36/39 and CustomerService line 337, also reproduced on unchanged HEAD. Live Studio validation has not been performed.

### Studio movement commands

In Play mode, select the **Server** Command Bar and run this complete snippet (change the selected player for multiplayer testing):

```lua
local dev = require(game:GetService("ServerScriptService").Server.Services.DevContentService)
local player = game:GetService("Players"):GetPlayers()[1]
assert(player, "Wait for a player to join")
dev.SetMovementSpeedLevel(player, 3) -- accepts 0, 1, 2, 3
dev.SetSprintStaminaLevel(player, 3) -- accepts 0, 1, 2, 3; full bar, stops sprint
dev.SetJumpLevel(player, 3)          -- accepts 0, 1, 2, 3
dev.PrintMovement(player)
```

To reset from a later Command Bar submission, bind locals again:

```lua
local dev = require(game:GetService("ServerScriptService").Server.Services.DevContentService)
local player = game:GetService("Players"):GetPlayers()[1]
dev.ResetMovement(player)
dev.PrintMovement(player)
```

These methods extend DevContentService and its existing StudioServices bridge. They require Studio, the server, Play mode, and a player currently in Players. Movement commands do not require EnableDevContent; other dev content tools retain their existing opt-in gate. Setters warn and return false on invalid levels or unavailable dev access. Missing runtime MovementService bindings raise explicit errors. They never spend cash or change purchased ownership. MovementService's lower-level override APIs also enforce Studio Play server access.

Each track has one temporary displayed-level override (0?3), which takes precedence over purchased state. The last setter for a track wins. ResetMovement clears speed, stamina, and jump overrides, reapplies actual purchased tiers, stops sprint, and fills purchased stamina. Overrides survive character respawns, which stop sprint and refill the effective maximum; leaving removes them. EnableDevContent does not affect movement commands; use ResetMovement when finished.

The stamina setter intentionally stops sprint and fills the selected maximum even when selecting the same tier again, so each timing test can start fresh. Speed/jump setters preserve ongoing sprint/stamina. Real purchases retain their existing capacity-delta behavior and remain underneath active debug overrides; reset reveals the latest purchased tier. The replicated level attributes and resolved speed/capacity attributes reflect effective overrides. Purchased levels remain private PlayerDataService state and are separately identified by PrintMovement. PrintMovement labels effective level, purchased level, and override separately, and prints authoritative stamina/sprint state plus actual Humanoid properties and StunnedUntil. It also returns the formatted string for inspection.

Live Studio verification remains necessary for the actual Command Bar bridge, Output readability, multiplayer selection/replication, traversal feel, and character lifecycle timing. Automated coverage includes all four debug tiers, cash/ownership isolation, runtime override enforcement, jump override precedence, reset/respawn/cleanup, print fields, and production/client rejection.

Movement Command Bar regression: a separate module cache loads the real DevContentService/StudioServices proxy before runtime publication. Tests then publish the runtime services and invoke speed, jump, stamina, reset, and print through that proxy with EnableDevContent absent/false. Assertions verify effective level attributes, resolved speeds, runtime Humanoid updates, ownership isolation, and explicit missing-bridge/missing-MovementService errors. Earlier movement tests initialized DevContentService directly and always enabled dev content, so they missed the silent opt-in gate and did not require effective level attributes. Live Studio command execution is still required; automated tests simulate the separate cache and bridge rather than attaching to a Studio session.
