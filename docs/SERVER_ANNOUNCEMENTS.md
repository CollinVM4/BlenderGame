# Server announcements

All announcements use the existing output-only `RareIngredientSpawned` remote
and `RareIngredientPresentationController`. The prior implementation had a
spawn-only timed label, no animation or SFX, and no Mystery serve broadcast.

`AnnouncementService` publishes spawn, acquisition and serve payloads.
`AnnouncementFormat` owns escaped RichText, copy, duration limits and stable
priority ordering. The controller uses shared `DialogueTextStyle` Fredoka text,
white lettering, a dark 2.5px outline and selective gold/purple/green accents.
Its safe-inset upper-center banner is 92% wide with a 780px maximum. Text scales
between 18 and 32px. Entrance takes 0.24s from 0.93 scale and a small upward
offset, followed by a 3.5s hold and a 0.18s upward fade. Pending high-priority
events go first; equal priorities remain FIFO. Ordinary events preserve the
visible message's hold. Immediate server notices and the ingredient cleanup countdown interrupt that hold and lead the queue;
the countdown updates in place using its server-time deadline. See
[ingredient cleanup](INGREDIENT_CLEANUP.md) for timing and red accents. The quiet
entrance cue reuses the existing blender-ready ding
and stops after at most 1.5s.

Mystery rarity is read from ingredient definitions. Both existing ingredient
spawner tags establish server-only acquisition provenance for Mystery stock;
the announced tag retains its spawn broadcast and location. Successful world
pickup establishes the last acquiring UserId. That metadata follows the unit
through carry records, individual stash entries, drops and throws. Successful
acquisition by a different player announces again, including theft. Equip,
same-player retrieval and failed transfers stay silent. Metadata is excluded
from inventory snapshots and does not alter stash access, capacity or contents.
Other grants/farms do not gain spawner acquisition announcements.

Serving publishes once after the existing cup consumption and cash credit,
using the actual payout, regardless of customer reaction or grade. Multiple
Mystery ingredients in one smoothie still produce one announcement.
`MoneyFormat.Announcement` supports K/M units with up to two decimal places;
the existing `Compact` world-label rounding remains unchanged.

Future server callers can use:

```lua
services.AnnouncementService.Publish({
    Type = "ServerAnnouncement",
    Text = "A world event has begun!",
    Duration = 4, -- Hold seconds, clamped to 2–8
    SoundType = "Mystery", -- Omit for silence
    Priority = 0, -- Mystery events use 10
})
```

Plain text is escaped by default. Only trusted server-authored markup should
set `RichText = true`. There is no inbound announcement remote handler.

## Validation

Focused suites: `announcements`, `announcement-presentation`, `carry`,
`stash-integration`, and `customer-payout-serve` pass. These cover the actual
spawner adapter, successful/failed pickups and theft, stash/throw/drop ownership,
equip suppression, real serving/replay with credited payout, formatting and
pending priority ordering. Presentation checks run separately from gameplay.

StyLua and Rojo build pass. Roblox-aware Luau LSP analysis has no new errors
relative to an isolated HEAD baseline. Both report existing errors in
`CustomerRequests` (optional display text) and `CombatService` (optional bat
state). The older `world` and `stash` suites fail identically on HEAD: the former
expects a second ingredient not to equip; the latter has an incomplete
`syncHeld` fixture. No unrelated production fixes were made.

## Studio smoke checks

No new Studio objects or asset IDs need authoring. Sync with Rojo; existing
`IngredientSpawn` / `AnnouncedIngredientSpawn` tags, `IngredientId` and optional
`LocationName` attributes remain the setup. Spawn timing and economy are unchanged.

Studio rendering/audio and multiplayer checks have not been run:

1. Use two clients. Spawn and collect Mystery stock; both see one spawn/location
   message and one collector DisplayName message. Repeat equip and own-stash
   retrieval; neither should add a message. Steal it; both see the new acquirer.
2. Serve a Mystery smoothie. Compare the announced amount with the credited
   payout; repeated serving must not replay it.
3. Queue spawn, pickup, serve and a low-priority message together. Confirm one
   banner at a time, readable holds, stable priority and entrance-synced sound.
4. Check phone portrait/landscape, tablet, desktop and ultrawide emulation with
   long DisplayNames/locations. Verify top-bar clearance, wrapping, dark outline,
   constrained width and gameplay visibility against busy scenery.
5. Respawn during an announcement. The existing GUI/queue should persist without
   a duplicate listener or duplicate sound. Listen for suitable cue volume.
