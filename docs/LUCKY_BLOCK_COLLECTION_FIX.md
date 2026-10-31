# Lucky Block collection / imported reveal fix

`LuckyBlockVisual.Clone` used native `Instance:Clone`, then manually cleared every
attribute. Clearing an imported `RBX_ReimportId` triggered the CoreScript permission
error. Native cloning already preserves attributes safely, so the sanitizer now
performs no manual attribute writes: all `RBX_` attributes are excluded from script
assignment/clearing, and legitimate attributes survive. Studio templates and their
import metadata remain untouched. Geometry, colored winner art, silhouette styling,
script/tag removal and inert physics retain their existing behavior.

Preparation/normalization errors now destroy partial clones and return `nil` to the
existing text fallback. The roulette timeline, sounds, fade and cleanup still run;
a subsequent healthy pickup can display its model. The server spawning path also
uses native cloning and only assigns its own named gameplay attributes, so it has
no equivalent protected-metadata write.

## Collection trace

1. `LuckyBlockService` polls every 0.15 seconds; collection uses the living player's
   root within four studs of the server block root, with the existing gameplay lock
   and 0.75-second player cooldown. This is proximity collection, not a `Touched`
   handler; the anchored art has collision and touch disabled.
2. The server selects one reward from the existing weighted configuration.
3. `retire` removes the claimable record before destruction or remote publication.
   It schedules that level's 180–240 second replacement and destroys the block.
   Competing/reentrant claims cannot select or publish another reward for it.
4. `LuckyBlockPickedUp` sends the collector the authoritative reward, position,
   character, pickup ID and timestamp. Nearby observers get `LuckyBlockRevealed`.
5. The client validates identity/timing and deduplicates pickup IDs. The local world
   roulette shows silhouette beats, then the colored winner at 0.78 seconds, holds
   for the currently configured 1.7 seconds, and fades for 0.15 seconds. Tick/pop
   sounds, scaling, glow and cleanup remain unchanged. Invalid art uses text.
6. After reveal/hold/fade, the server publishes a separate public claim pickup.
   The collector receives its buff or ingredient prize; the roller need not remain.
   Block slots replenish with the 3/1/1/0 distribution. See [current server lifecycle](LUCKY_BLOCKS.md).

The imported-attribute repair remains in effect. Server rewards are now implemented;
exactly-once coverage includes atomic pickup claims and rollback-safe ingredient batches.

## Historical repair validation and Studio checks

Focused suites: `lucky-block`, `lucky-block-view`, `lucky-block-controller`, and
`lucky-block-roulette`. They cover protected metadata writes on imported model
roots/descendants, legitimate attributes, template preservation, malformed-art
fallback and later recovery, sounds, animations/cleanup, duplicate claims, and
collection/independent respawn for every level. Stale asset-name and hold-duration
expectations were reproduced against the original implementation and updated to
the existing presentation configuration; production tuning was not changed.

Results: all four suites pass (275 behavioral checks). Roblox-aware focused
typecheck of the server and reveal modules, changed-file StyLua, fresh Rojo
sourcemap/build and whitespace validation pass. Running the new imported-asset
regression with the original sanitizer reproduces the reported line-44 permission
error and the same View/Create stack.

No new Studio setup is required. Native engine validation still requires:

- Use the real imported assets carrying `RBX_ReimportId`; run into a block on each
  level and confirm no permission error, correct art/colors and tick/pop sounds.
- With two players contacting one block, confirm one collector event and the same
  nearby winner. Check death/reset, subsequent pickups and local folder cleanup.
- Temporarily make one reward asset unavailable, verify text fallback completes,
  then restore it and collect again. Confirm source metadata stays intact.
- Observe each collected level's independent 3–4 minute respawn with normal tuning.
  Rendering, audio playback, physical movement, networking and actual Studio import
  permissions are not simulated by the CLI engine doubles.
