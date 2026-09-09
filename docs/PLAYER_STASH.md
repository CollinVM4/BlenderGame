# PlayerStash V1

Implemented as physical storage, with no persistence, stealing, VIP capacity, or inventory UI.

## Authoritative state and API

`InventoryService` owns a per-Player table with five permanent slot records:

```luau
stashes[player][index] = {
    SlotIndex = index,
    IngredientId = nil, -- string while occupied
    Count = 0,
    Capacity = 5,
    Protected = index <= 2,
}
```

Empty slots retain protection and capacity. `GetSnapshot(player)` returns copied records; replicated attributes and display Instances are presentation only. Slots 1?2 are protected; 3?5 are unprotected regardless of names or client attributes. Reset preserves stash contents; disconnect clears them.

APIs in `src/server/Services/InventoryService.luau`:

- `Deposit(player, id, index)` validates the held server reservation, equipped state, alive state, uniquely tagged owned stash, unique actual slot, distance to that slot, matching type, and fixed capacity. The legacy id argument must match the reservation. It consumes the held Tool exactly once.
- `Withdraw(player, index, stashOwner?)` validates empty hands, authorization, alive state, fixture, and slot distance. It decrements one unit and uses the same private equip path as world pickup. No loose world item is created; failed equip restores the slot.
- `CanWithdraw(player, owner, index)` is the context-aware authorization seam. Owners may access all five slots. Both protected and unprotected non-owner access are currently denied; future stealing belongs here. The legacy `Steal` entry point returns false.
- `GetHeldIngredientId(player)` reads the reservation; `StashChanged` notifies presentation after changes and player cleanup.

## Presentation and interactions

`Stash.luau` binds one contextual ProximityPrompt per uniquely indexed slot. `StashPromptController.luau` adjusts that same prompt locally using replicated cosmetic metadata. Invalid interactions show a reason and still reject on the server.

`StashPresentation.luau` rebuilds a `StashDisplay` folder after changes. `IngredientService.CreateVisual` clones `ServerStorage.Ingredients/<IngredientId>` when it is a usable Model/BasePart; otherwise it creates a BlendColor part. Displays are at most 55% scale, additionally fitted to the slot. Four copies use a square arrangement, with the fifth raised in the center; a single copy is centered. The bounding box is placed above the slot surface.

Display descendants have all tags removed, including IngredientWorldItem. Prompts, click detectors, and scripts are removed before parenting into Workspace. Every BasePart is anchored, noncolliding, nonqueryable, and nontouchable. No display enters IngredientService's world records. Old displays are destroyed before rebuilding. Tag removal/unbinding destroys prompts and displays and disconnects component listeners.

## Required Studio setup

1. Keep the plot as an assigned `PlayerPlot` tagged object, or a child of `Workspace.Plots` supported by the existing plot assignment.
2. Put exactly one object tagged `PlayerStash` under that plot. A Model or Folder containing the slots works; no PrimaryPart is required for stash binding.
3. Provide five actual descendant BaseParts, each with a unique numeric integer `SlotIndex` attribute from 1 through 5. Existing `LockedSlot1`, `LockedSlot2`, `Slot3`, `Slot4`, `Slot5` names are fine. Set slot parts Anchored=true.
4. Do not manually add a second slot prompt or tag display objects as IngredientWorldItem. No authored protection, count, capacity, or owner attributes are needed.
5. Optional display/carry templates: `ServerStorage > Ingredients > Strawberry` (and other exact ingredient IDs), each a BasePart or Model containing a BasePart. Without templates the color fallback works.
6. Rojo sync the updated client bootstrap and new StashPromptController, StashPresentation modules along with existing changed modules. No new remotes or server bootstrap setup is required.

Runtime slot metadata is `StashOwnerUserId`, `StashIngredientId`, `StashCount`, `StashProtected`. The server publishes `HeldIngredientId` on the Player. None authorizes gameplay.

## Exact live Studio test (not yet executed)

1. Start a two-player local server. Confirm Player 1 owns Plot1 and stand within 10 studs of Slot3.
2. Pick up Strawberry from its IngredientSpawn station. Approach Slot3: expect ?Store Strawberry?. Interact once: hands empty, one miniature Strawberry visible.
3. Repeat pickup/store four times. Expect five display copies and Count=5. Pick up a sixth Strawberry and interact: expect ?Slot full (5/5)?, five copies, and the sixth still held.
4. Throw the sixth away from the stash/blender and leave it loose. With empty hands, interact with Slot3: expect ?Take Strawberry (5/5)? before activation, one held Strawberry afterward, and four display copies.
5. Deposit the withdrawn Strawberry, then withdraw it again. Counts must alternate 5/4 without extra Tools or loose items. With it held, direct Withdraw must reject; contextual interaction stores it.
6. Throw the held Strawberry away. Pick up Banana and try the occupied slot: reject with Banana still held. Store Banana in empty Slot4 to empty hands. Withdraw Slot3 repeatedly, throwing each away; the last withdrawal clears IngredientId and removes the display folder. The next withdrawal rejects.
7. Player 2 tries Plot1 slots 1 and 3: both reject. Repeat storage/withdrawal in slot 1 as the owner; it works and is labeled protected.
8. Inspect display descendants in Explorer: no IngredientWorldItem tags, pickup prompts, or scripts; all BaseParts anchored with CanCollide/CanQuery/CanTouch=false. Try clicking/picking up a display: no effect.
9. Reset while holding a withdrawn item: it drops through the existing held cleanup, stash counts stay correct. Disconnect Player 1: displays clear. A newly assigned owner starts with empty slots.
10. Recheck loose pickup, throw, another player's pickup of that loose item, and thrown ingredient ingestion through BlenderInput/RPM blending.

## Verification

`python tests/run_state_tests.py --luau <path-to-luau>` exercises real service modules against the repository's mocked Roblox boundary. Added cases cover stacking, type/capacity rejection, no duplicate transfers, empty hands, authorization, distance/death/index validation, duplicate slot indices, snapshot isolation, failed visual/equip rollback, fallback/template displays, inert proxies, reset, and disconnect cleanup. Existing pickup/throw/BlenderInput cases remain in the suite.

This pass changes InventoryService, IngredientService, Stash, shared Types, client bootstrap, and the test runner/spec; adds StashPresentation, StashPromptController, and this guide. Other pre-existing workspace edits are retained.
