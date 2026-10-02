# Synchronized loose-ingredient cleanup

`IngredientService.Init` starts one server-owned repeating clock. Economy config
sets `WorldIngredientCleanupInterval = 240` and
`WorldIngredientCleanupWarningSeconds = 60`. The server publishes the warning at
T+180 and sweeps at T+240, preserving the cadence across cycles.

The sweep snapshots IngredientService's authoritative registry and calls Consume
for each currently loose world object. Position, plot ownership, age, rarity and
frozen spawn state do not exempt it. Newly dropped or thrown ingredients join the
next sweep, even if they have only been loose for a few seconds. Normal removal
notifications still drive station, market and farm lifecycle behavior.

Pickup and blender acceptance consume the loose object. Carried Tools/overhead
visuals, stash contents (including protected slots and smoothies), and blender
batch data are separate representations and never enter this sweep. Loose
smoothies belong to their separate service and are unchanged.

The old per-item Debris expiration and WorldItemLifetime setting are removed.
Existing gameplay removal paths, such as pickup and session teardown, still work.

The existing AnnouncementService transport publishes a ServerAnnouncement:
**LOOSE INGREDIENTS CLEAR IN 1 MINUTE!** Its Immediate flag places it ahead of queued
ordinary messages and ends the currently visible message's hold on the next
0.1-second check. The existing short exit then plays before the warning enters.
Pending mystery announcements retain their order. Fredoka styling, responsive
sizing, outline and subtle entrance/exit animation remain unchanged.

No Studio setup or manual visual test is required for this pass.

Focused validation:
`python tests/run_state_tests.py --luau <luau.exe> --suite ingredient-cleanup --suite announcements --suite announcement-presentation`.
The cleanup integration suite covers timing/repetition, absence of per-item
expiration, late spawns, throws/drops, last-moment pickup, protected states and
market/station regeneration.
