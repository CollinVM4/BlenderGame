# Synchronized loose-ingredient cleanup

`IngredientService.Init` starts one server-owned repeating clock. Economy config
sets `WorldIngredientCleanupInterval = 360`,
`WorldIngredientCleanupWarningSeconds = 60`, and
`WorldIngredientCleanupCountdownSeconds = 5`. The server publishes the first
warning at T+300, the final countdown at T+355, and sweeps at T+360, preserving
the cadence across cycles. This reduces sweeps by one third from the previous
four-minute interval while keeping a bounded six-minute cleanup window. Actual
physics/memory impact still needs profiling in a populated Studio server.

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
Pending mystery announcements retain their order. Five seconds before the sweep,
one `IngredientCleanupCountdown` announcement takes the same immediate path. The
existing banner updates from 5 to 1 without repeating the entrance animation;
**LOOSE INGREDIENTS** and **5 SECONDS** (through **1 SECOND**) use red `#FF6666`
RichText accents, with the rest of the message white. Its server-time deadline
keeps the displayed seconds aligned after network/queue delays; expired countdowns
are skipped. There are no per-second server broadcasts or added sounds. Fredoka
styling, responsive sizing, outline and subtle entrance/exit animation remain
unchanged.

No new Studio objects or assets are required. Sync with Rojo, then smoke-check
that the one-minute warning appears, the red 5-to-1 countdown updates in place,
and the banner exits at cleanup while ordinary queued notices resume. Check phone
and desktop readability and profile loose-item buildup in a populated server.
Studio rendering and live performance have not been validated by CLI tests.

Focused validation:
`python tests/run_state_tests.py --luau <luau.exe> --suite ingredient-cleanup --suite announcements --suite announcement-presentation`.
The cleanup integration suite covers six-minute timing/repetition, both warnings,
absence of per-item expiration, late spawns, throws/drops, last-moment pickup, protected states and
market/station regeneration.

The separate announcement presentation suite checks red countdown copy,
server-deadline catch-up, expiry, invalid deadlines, and immediate queue priority.
