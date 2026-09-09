# Held ingredient drop: live Studio verification

No new Studio objects, tags, remotes, or input-zone changes are required. Sync with Rojo, start Play with the existing working plot/stations and thick BlenderInput, and wait for the services-initialized message. Use the **Server** Command Bar for the commands below. These checks must run before the normal world-item lifetime expires.

## Ownership and state

| State | Authoritative state | Physical representation |
| --- | --- | --- |
| WORLD | IngredientService record: ingredient ID, owner nil for station stock (or existing player owner), Claimable=true | Registered, tagged IngredientWorldItem with IngredientId, WorldItemId and OwnerUserId |
| HELD | Original world record consumed. InventoryService reserves one unit with the same ingredient ID exclusively for the holding player. This unit is not also in Carried. | Ingredient visual welded to the equipped Tool Handle; no world-item tag or pickup prompt on the carried visual |
| DROPPED / THROWN | Spawn registers one new world record with Owner=nil, Claimable=true and the same ingredient ID. Only after success is the held reservation cleared and its Tool destroyed. | Physical IngredientWorldItem in front of the original character, with a fresh WorldItemId, unchanged IngredientId and OwnerUserId=0 |

DropHeld does not apply the throw impulse. Activated still throws at forward speed 25 plus upward speed 18. IngredientService.Spawn recreates the normal template/fallback, metadata, network ownership, pickup tag and lifetime. Any nearby living player with capacity and empty hands can pick up a dropped/thrown item; the first successful claim consumes its world record, preventing a second claim. Stash ownership and slot protection are unchanged. BlenderInput accepts registered, claimable unowned items with the existing plot-owner, input-reference and server overlap checks; foreign-owned items and nonclaimable unowned stock remain rejected.

Death and character removal drop through DropHeld, retaining the original character root even if Player.Character is already nil. Disconnect calls InventoryService cleanup before IngredientService cleanup: the held unit is restored as unowned and survives departing-player-owned world-item cleanup. The final disconnect state has no held unit and exactly one claimable loose replacement, subject to normal pickup, ingestion and lifetime expiry. Explicit ClearHeld remains the destructive developer reset API.

## Exact playtest

1. Pick up a station ingredient normally. Confirm one visible ingredient in the hand and one ingredient Tool in Character. Press its hotbar number again to unequip. Confirm the Tool disappears from both Character and Backpack and one physical ingredient appears in front of the player. Repeat by switching to another Tool (for example the existing hand weapon).

2. For precise registry assertions, start with empty hands and run this server fixture. It uses the same real Spawn and pickup component as loose station stock. In a multiple-client session, replace GetPlayers()[1] with the intended player's name lookup.

   ```luau
   DropCheck = {}
   DropCheck.Player = game:GetService("Players"):GetPlayers()[1]
   DropCheck.Inventory = require(game.ServerScriptService.Server.Services.InventoryService)
   DropCheck.Ingredients = require(game.ServerScriptService.Server.Services.IngredientService)
   DropCheck.Before = {}
   for _, item in game:GetService("CollectionService"):GetTagged("IngredientWorldItem") do
       DropCheck.Before[item] = true
   end
   DropCheck.Stock = DropCheck.Ingredients.Spawn("Banana", DropCheck.Player.Character.HumanoidRootPart.CFrame * CFrame.new(0, 2, -3), nil, true)
   DropCheck.Carried = DropCheck.Inventory.GetSnapshot(DropCheck.Player).Carried.Banana or 0
   ```

3. Use the fixture's normal Pickup prompt. Run:

   ```luau
   assert(DropCheck.Ingredients.GetRecord(DropCheck.Stock) == nil)
   DropCheck.Tool = DropCheck.Player.Character:FindFirstChild("Banana (click to throw)")
   assert(DropCheck.Tool and DropCheck.Tool:FindFirstChild("Handle"))
   assert((DropCheck.Inventory.GetSnapshot(DropCheck.Player).Carried.Banana or 0) == DropCheck.Carried)
   ```

4. Unequip using the hotbar. Run:

   ```luau
   local found = {}
   for _, item in game:GetService("CollectionService"):GetTagged("IngredientWorldItem") do
       local record = DropCheck.Ingredients.GetRecord(item)
       if not DropCheck.Before[item] and record and record.Owner == nil and record.Id == "Banana" then
           assert(record.Claimable)
           assert(item:GetAttribute("IngredientId") == "Banana")
           assert(item:GetAttribute("OwnerUserId") == 0)
           assert(item:GetAttribute("WorldItemId"))
           table.insert(found, item)
       end
   end
   assert(#found == 1, "Expected exactly one restored world unit")
   DropCheck.Dropped = found[1]
   assert(DropCheck.Tool.Parent == nil)
   for _ = 1, 5 do assert(DropCheck.Inventory.DropHeld(DropCheck.Player) == nil) end
   assert((DropCheck.Inventory.GetSnapshot(DropCheck.Player).Carried.Banana or 0) == DropCheck.Carried)
   print("PASS: one world unit, cleared held state, repeat drop rejected")
   ```

5. Pick up DropCheck.Dropped through its prompt. Confirm its GetRecord now returns nil and the hand visual returns. Face the owned blender's input and click/tap to throw. Confirm the arc is unchanged, the ingredient disappears on contact, and the blender ingredient count increases exactly once. Repeat on a touch client to verify tap activation. Also repeat a direct pickup-to-throw cycle without unequipping.

6. Pick up another fixture and use Reset Character, or set the server Humanoid.Health to 0. Confirm one unowned, claimable world item drops at the old character, no ingredient Tool survives respawn, and either player can pick it up again. Repeat with unequip immediately followed by reset. Run DropHeld repeatedly after respawn: all calls return nil. The new character must not generate a second copy.

7. With another held fixture, run `DropCheck.Player.Character:FindFirstChild("Banana (click to throw)"):Destroy()` on the server. Confirm one world item and no held reservation. This tests external Tool cleanup separately from normal unequip.

8. Start a local server with two clients. Client 1 picks up then unequips an ingredient; client 2 picks up the dropped item and throws it. Client 1 must be able to pick up that thrown item. Repeat both drop and throw while both clients attempt the next pickup together: exactly one player gets the Tool, the world item disappears once, and the loser gets no inventory unit. Reverse the pickup order to verify either player can win.

9. Pick up an ingredient in client 1 and close that client while client 2 observes. After PlayerRemoving completes, confirm no Tool remains for the departed player and exactly one unowned, claimable replacement exists. Client 2 must be able to pick it up. Repeat with client 1 resetting immediately before leaving; there must still be only one replacement.

## Automated verification

The suite covers unequip, authoritative metadata, cleared reservation, fallback carry visual, re-pickup and Activated throw, blender consumption, repeated and reentrant signals, failed Spawn retaining the Tool/reservation for retry, death, missing Character, external Tool destruction, and disconnect cleanup ordering. Drop and throw each test both claim winners, loser rejection, exclusive held reservations, and ownership release. Blender checks include unowned ingestion and rejection for absent overlap, wrong plot owner and nonclaimable unowned stock. It uses a mocked Roblox boundary; it does not prove engine rendering, replication, physics, or input delivery.

Validated: 433 state assertions, compilation of all 41 source files, Roblox-aware Luau LSP analysis, Rojo build, StyLua for touched Luau files, and git diff whitespace checks. Live Studio steps above remain to be run.
