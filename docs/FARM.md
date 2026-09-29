# Farm v1

Each plot session owns three sequential row purchases ($1,000 / $3,000 / $8,000).
`TycoonService` stores their count as the shared `FarmRows` upgrade (tier 1 means
zero rows), using its existing cash ledger and synchronous transaction lock.
Only server touch interactions with the plot's purchase pads can purchase rows;
the generic upgrade request cannot purchase `FarmRows`. Either teammate can pay.

`FarmService` owns LOCKED / EMPTY / GROWING / READY row state. Planting reads the
same authoritative selected/fallback carry record used by throwing, validates
its live Tool, and consumes exactly one through `InventoryService`. Equipped
smoothies cannot be planted. `IngredientDefinition.Farmable = false` opts an
ingredient out; omitted means farmable. Unknown/missing rarity warns and uses
Common. `FarmConfig` owns prices, growth durations and reveal/proximity tuning.

After 30 / 45 / 90 / 180 seconds for Common / Uncommon / Rare / Mystery, the
normal `IngredientService.Spawn` creates three exact copies at the attachments.
They remain anchored until pickup and retain normal public pickup and world-item
expiry behavior (including pickup by opponents). Opponents cannot buy or plant.
Destroying/removal signals keep a row READY until all products are gone. Failed
spawns warn; any successful products still block planting until removed.

Membership promotion preserves crops and purchases. Final session release
invalidates timers, destroys harvests, cancels reveals, restores authored
transforms and resets the pads. Plot unbinding also cleans up. Timers capture both
session identity and row generation. No persistence, remotes or new UI are added.

## Studio setup

Author the following under each existing PlayerPlot root before starting play:

```text
Farm
  Row1
    PurchasePoint1 (BasePart)
    Visual (Model, Folder, or BasePart)
    FarmMarkers (BasePart)
      PlantPoint (Attachment)
      Grow1 (Attachment)
      Grow2 (Attachment)
      Grow3 (Attachment)
  Row2 (same children, with PurchasePoint2)
  Row3 (same children, with PurchasePoint3)
```

Place dirt Visuals at their final authored positions; use anchored parts without
welds to objects outside Visual. The server anchors their parts and rises them
3.5 studs over 0.5 seconds with Back/Out easing, ending at the exact saved CFrames.
Author their normal visible transparency/collision properties. Locked rows hide
parts, decals/textures and attached world GUIs and disable collision/touch/query.
Purchase pads must be touchable BaseParts, positioned where players can walk over
them. Author any desired pad price text yourself; runtime preserves/hides attached
SurfaceGui/BillboardGui content. No purchase scripts or extra tags are required.

FarmMarkers is anchored, invisible and noncolliding; runtime enforces those
properties. Position its Attachments relative to each row, with PlantPoint within
10 studs of the intended player standing position. Place Grow attachments at
ingredient pivot height so harvests clear the dirt. Runtime creates the default
planting ProximityPrompt. Missing Farm is optional; an incomplete Farm warns and
does not bind. Restart play after repairing an incomplete hierarchy.

## Validation

Run `python tests/run_state_tests.py --luau <luau.exe> --suite farm`.
The integration suite uses real farm, inventory, ingredient and plot services
with engine doubles. It owns farm purchase, consumption, growth, harvest and
session-lifecycle contracts. Existing carry-selection and plot-session/race suites
cover their own underlying selection and transaction contracts.

Passed: farm, carry-selection, plot-session, plot-session-races; focused typecheck
of changed service/config modules; StyLua on touched code (ingredient type block
only, preserving its pre-existing catalog formatting); Rojo build.
Full-src typecheck retains the baseline CustomerRequests missing DisplayText
errors; the world suite retains its baseline `second ingredient cannot equip`
failure. Both were reproduced using an isolated unchanged HEAD checkout.

Still verify in a two-client Studio session: actual walk-over touches and concurrent
team purchases, nonmember rejection, multipart rise/reset during a tween, prompt
distance/death/stun rejection, all three harvest positions and normal pickups,
owner promotion, final departure and plot reclaim during growth. CLI doubles do
not establish real physics, replication or visual quality.
