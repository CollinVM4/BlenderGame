# Farm

Each plot session owns three sequential row purchases ($20,000 / $55,000 / $110,000).
`TycoonService` stores their count as the shared `FarmRows` upgrade (tier 1 means
zero rows), using its existing cash ledger and synchronous transaction lock.
Only server touch interactions with the plot's purchase pads can purchase rows;
the generic upgrade request cannot purchase `FarmRows`. Either teammate can pay.

`FarmService` owns LOCKED / EMPTY / GROWING / READY row state. Planting reads the
same authoritative selected/fallback carry record used by throwing, validates
its live Tool, and consumes exactly one through `InventoryService`. Equipped
smoothies cannot be planted. Set `Farmable = false` on any entry in
`src/shared/Constants/Ingredients.luau` to disable planting regardless of rarity.
`Dragon_Fruit`, `Gummy_Bear`, `Mystery`, `Player_Head`, and `Rainbow_Trout` are
opted out. Omitted/true preserves ingredient eligibility. The server also
checks ownership, distance, movement, and row state. Rarity is independent of
planting eligibility.
`src/shared/Constants/FarmEligibility.luau` resolves the definition rule for both
the farm prompt and authoritative planting. Ineligible selections show
"Cannot Plant This Item". The server rejects these attempts before consuming an
item or changing row state, including for dynamically created PlayerHead drops.
`FarmConfig` owns prices and reveal/proximity tuning.

On PC, press **E** when the plant prompt is visible to plant or replant. Aim
toward a crop's pickup prompt and press **E** to harvest it. Replanting ejects
any remaining crops as loose items. On a controller, use ButtonX on an empty
row and ButtonY to replant a ready row. On mobile, tap the plant or crop prompt.

`IngredientService.Spawn` creates three copies at the grow attachments. Crops
stay anchored and exempt from the loose-item sweep while in the row. Anyone
can harvest them. The last removal empties the row. Opponents cannot buy or
plant. Failed spawns warn, and each successfully spawned crop is still available.

Membership promotion preserves crops and purchases. Final session release
invalidates timers, destroys harvests, cancels reveals, restores authored
transforms and resets the pads. Plot unbinding also cleans up. Timers capture both
session identity and row generation. No persistence or new remotes are added.

## Grow times

One seed yields three copies. The server looks up the ingredient's
`JumpLocation` in `FarmConfig.GrowSecondsByJumpLocation` and divides that batch
duration by the plot's active farm multiplier. All three rows use the same timing.

| JumpLocation | Farmable catalog entries | Examples | 1× growth | 2× growth | Time saved |
| --- | ---: | --- | ---: | ---: | ---: |
| 0 | 20 | Apple, Blueberry, Ice | 30s | 15s | 15s |
| 1 | 11 | Pear, Pineapple, Steak | 60s | 30s | 30s |
| 2 | 10 | Crab, Fish, Milk | 2m | 1m | 1m |
| 3 | 7 | Melon, Pizza, Golden Potato | 4m 30s | 2m 15s | 2m 15s |

The table shows server durations. The on-screen countdown rounds remaining
time up to a whole second. The [shared pass](FARM_SPEED_PASS.md) scales only
the remaining work when a teammate with the pass joins or leaves. World spawns
use `Economy.RefillSeconds`, per-ingredient overrides, or authored timers for
announced spawns.

The boost saves 15s per JL0 batch and 30s per JL1 batch. A boosted JL1 batch
takes 30s against the configured 25–45s interval between successful normal
customer spawns.

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
3.5 studs over 0.8 seconds with Back/Out easing, ending at the exact saved CFrames.
Author their normal visible transparency/collision properties. Locked rows hide
parts, decals/textures and attached world GUIs and disable collision/touch/query.
Purchase pads must be touchable BaseParts, positioned where players can walk over
them. Runtime creates price billboards from FarmConfig.RowPrices and hides them
with the pad; remove old manually authored price text to avoid duplicates.
No purchase scripts or extra tags are required.

FarmMarkers is anchored, invisible and noncolliding; runtime enforces those
properties. Position its Attachments relative to each row, with PlantPoint within
10 studs of the intended player standing position. Place Grow attachments at
ingredient pivot height so harvests clear the dirt. Runtime creates a Custom-style
planting ProximityPrompt and client world-space presentation.
Missing Farm is optional; an incomplete Farm warns and
does not bind. Restart play after repairing an incomplete hierarchy.

## Validation

Presentation polish adds no required Studio objects to the hierarchy above.
`FarmPresentationController` reuses `WorldBillboardStyle` for fixed pixel canvases,
`DialogueTextStyle` for FredokaOne, charcoal outlines, white/gold/success colors,
and `InteractionPromptPresentation` for native keyboard/gamepad/touch input.
The planting name reads InventoryService's replicated `HeldIngredientId` action
target, including selected ingredient/fallback and equipped-smoothie semantics.
Server planting still resolves its own records independently.

Existing row `FarmState` is supplemented by `FarmGrowEnd` (server time, present
only while growing). Countdown and 0.4-second ellipsis run locally without remotes.
Harvests receive `SpawnSource = "Farm"` and `FarmSpawnTime` for presentation.
Clients animate fresh harvest pivots up from `HarvestPopDepth` over
`HarvestPopSeconds` (defaults 0.65 studs / 0.32 seconds, Back/Out), finishing at
the Grow attachment plus `HarvestVerticalOffset` (default zero, world Y).
Old streamed harvests do not replay the pop.

`GameplayAudio` centralizes the PLIP/PLOP assets and positional volume/rolloff.
Successful world pickup (`InventoryService.CarryWorldItem`) and committed planting
(`FarmService.plant`) emit `IngredientPickup` and `IngredientPlant`; intentional
ingredient throws (`InventoryService.ThrowHeld`) emit `IngredientThrow`.
`GameplaySfxService` broadcasts semantic names and world positions through the
server-output-only `Shared.Events.GameplaySfx` remote. Growth completion is silent.
Generic consumption, cleanup, forced drops, stash transfers and rejected actions
emit no SFX. Farm products use the normal world pickup path.

`GameplayAudioController` preloads the two reusable templates once and renders
known events locally with independent positional emitters, Ended cleanup and a
15-second Debris fallback. Early events wait for preload (up to 32 queued);
events beyond 50 studs from the camera are culled. No authored Sound instances
are needed. Check asset permissions and actual audibility in Studio.

Focused checks: `python tests/run_state_tests.py --suite gameplay-sfx --suite farm
--suite gameplay-audio --luau <luau.exe>`. Client rendering checks are reported
separately from authoritative/integration checks.

Run `python tests/run_farm_presentation_tests.py --luau <luau.exe>` separately
from gameplay. It covers displayed selection, invalid ingredients, native input
hints/touch forwarding, countdown/ellipsis, pad reset, streaming cleanup, multipart
pivot completion and unchanged ordinary spawns. Farm integration owns deadlines,
harvest metadata and audio event eligibility alongside existing gameplay contracts.

Studio smoke checks for this polish: keyboard/controller/mobile planting; change
selected ingredients and equip a smoothie near an empty row; watch growing/ready
states from two clients; pick up a harvest during its pop; verify multipart models
sit naturally at Grow attachments; reset/reclaim and stream the plot out/in.
Set valid permitted sound assets and verify positional plant/ready/pluck playback,
including the pluck finishing after its ingredient disappears. CLI doubles do not
establish real replication, rendered layout or audio playback quality.

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
