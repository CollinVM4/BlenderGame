# Assigned plot respawns

The existing server bootstrap calls InitialSpawnService.ApplyCharacter for every
CharacterAdded event, including automatic respawns and manual resets. Previously,
the service consumed one attempt per player and skipped assigned players entirely.
Only the unclaimed first-arrival tutorial route now uses that one-time limit.

After HumanoidRootPart is ready, TycoonService.GetPlot resolves the current active
session for both owners and teammates. There is no additional ownership registry.
The character pivots to PlotIdentity.PlayerSpawnOrigin.WorldCFrame multiplied by
CFrame.new(0, 3, 0). Teammates receive another four studs along the marker's local X
axis. Facing follows the attachment, and assembly velocities are cleared.

Membership is resolved after waiting; there are no further yields before the
teleport. Removed players, obsolete characters, dead characters and missing roots
are skipped. Missing or invalid markers retain default placement. Unclaimed
respawns retain Roblox's default placement; the existing first-arrival tutorial
placement and reservations are preserved. Death timing, fall damage, session
ownership, character physics and ragdoll recovery are unchanged.

## Validation

Run the initial-spawn, plot-player-flow and fall-damage suites with
 tests/run_state_tests.py and the Luau CLI. Respawn-specific contracts live in
 tests/initial_spawn.spec.luau: repeated owner deaths, teammate resets, attachment
world position/facing, release and reassignment during root loading, stale/dead
characters, missing roots/markers and unclaimed fallback. These three suites,
focused Roblox-aware typecheck, StyLua and Rojo build pass.

## Studio smoke checks

Each plot needs its existing PlotIdentity.PlayerSpawnOrigin Attachment with the
intended world position and facing. No new SpawnLocation, script or connection is
required. Verify that the marker and teammate offset have clear standing space.

With two clients:

1. Claim a plot and join it as a teammate. Kill each player through lethal fall
   damage, then use Reset Character. Both should return above that plot's marker,
   with the teammate offset and unchanged respawn delay.
2. Repeat each death/reset several times. Check the characters land normally,
   retain their avatar physics and never return to world origin instead of the
   assigned plot. Also reset while ragdolled and check the new rig recovers normally.
3. Leave or kick a teammate while dead, then claim a different plot before respawn.
   The next character should use the new plot. Release a session without assigning
   another plot and confirm default spawn behavior.
4. Reset an unclaimed player after their first arrival. Confirm normal lobby/default
   spawn behavior and no new tutorial teleport or automatic claim.

CLI doubles do not validate Roblox death/reset timing, physical landing, avatar
loading or multiplayer replication. These Studio playtests remain manual acceptance
checks and were not run as part of the automated validation.
