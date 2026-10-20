# Ingredient throw placement

IngredientThrow.FindOrigin chooses a spawn point for a prepared world item. The
item materializes there with velocity; there is no launch corridor to validate.
Placement uses only the server character root and prepared item geometry. Clients
supply neither position nor direction.

The direction is the normalized horizontal root LookVector. Avatar front clearance
projects body/accessory bounds along it, ignoring Tools and IngredientCarryVisuals.
The conservative item radius includes off-center multipart geometry and existing
padding. `minimum = avatarFront + itemRadius + 0.25`; only `minimum > 32` rejects
placement and retains the held reservation.

Every candidate uses one height: root position plus `max(2, itemRadius)` studs up.
Candidates run in this strict order:

1. Straight (0 degrees), distances from `max(5, minimum)` descending by one stud,
   with the exact minimum always included last.
2. +20, -20, +40, -40 degrees around world Y, each using the same distance ladder.
3. If all candidates are occupied, force the straight spawn at minimum.

The first candidate whose GetPartBoundsInBox result is empty wins. The box uses
actual part extents in the item pivot frame, transformed by the root rotation at
spawn, including its center offset and 0.25 studs of padding on each side of every
axis. Thin and elongated items use their real box rather than a radius-sized cube.
Queries exclude the whole character and every purchased, active tagged-plot
Muncher, including busy munchers; vacuum/arrival handles those items. Queries
respect CanCollide. Other players and world geometry affect preferences.

There are no vertical rays, overhead launch-volume checks, corridor Blockcasts,
or stepped launch heights. Occupancy never rejects a throw. Minor penetration
on a forced spawn is expected; physics can pop the item out. Economic outcomes
still resolve through authoritative vacuum/arrival systems.

The returned frame retains the root rotation even for angled candidates. Inventory
releases exactly one carried item before publishing it, and impulse remains root
LookVector * 25 + (0, 18, 0). The existing 0.2-second thrower collision grace is
unchanged. Open ground keeps its preferred five-stud distance and arc.

With the player's ThrowDebug attribute true, server placement traces contain
`clear distance=<d> angle=<a>` or `placement forced distance=<minimum>`.

## Validation and Studio acceptance

The `throw` suite in tests/run_state_tests.py owns the placement matrix, geometry,
forced inventory release, muncher filtering, and maximum-distance rejection.
Related carry, ingredient-slots, carry-selection, throw-blender, throw-multiplayer,
and muncher-vacuum suites cover inventory and arrival integration.

No Studio asset or configuration changes are required. With ThrowDebug enabled:

- Throw under Central Market Yellow Shop's awning; the throw must succeed.
- Face a wall/counter point-blank; an angled or forced spawn must fly and release
  inventory.
- Throw at a nearby purchased active muncher; its vacuum must still feed arrivals.
- Throw on open ground; confirm the same preferred distance and arc.

CLI queries are boundary doubles and do not replace Studio physics playtests.
