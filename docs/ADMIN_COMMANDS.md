# Server admin commands

Type `;giveicegun ExactUsername` to give an online player one Ice Gun for their
current life. Use their Roblox username, not their display name; username
matching is case-insensitive. This uses the same admin permissions and cooldown
as `;addcash` and does not require either player to have a stand.

The gun appears in the target's Backpack and supports normal hotbar selection
and firing. Death, character removal, or leaving removes the temporary grant;
it does not return on respawn or rejoin. Repeating the command while the gun
exists reuses it. Dead players or players without a character/Backpack cannot
receive a grant. The command never grants or saves gamepass ownership. Players
who already own the pass still keep their normal permanent respawn access.

Sync the updated `AdminService` and `IceGunService` with Rojo and restart Play
or publish. Existing Ice Gun assets are required; no additional Studio setup is
needed. In a private server, grant to a nonowner, select and fire the weapon,
then reset and confirm it is gone. Also check a non-admin cannot grant one.

Type `;givewings ExactUsername` to equip an online player's living character
with Flight Wings for their current life. They can hold Jump to fly and glide.
The grant ends on death, character removal, or leaving. Gamepass ownership
continues to control automatic grants on future spawns.

Type `;addcash 100000` to credit your stand, or
`;addcash 100000 ExactUsername` to credit the named online player's stand.
Only the recipient needs to have claimed or joined a stand. The command uses
exact, case-insensitive Roblox usernames. Positive finite amounts up to
1,000,000,000 are accepted, decimals are floored, and results below 1 are
rejected. Command names are case-insensitive. Successful executions have
a 0.35-second cooldown per admin.

`src/server/Admin/AdminConfig.luau` is server-only. Numeric `AdminUserIds` are
canonical. The configured bootstrap names are Eatandpoop, KarmaReaper2, and
snipernosniping1234. Each is resolved once at startup with
`Players:GetUserIdFromNameAsync`, independently of normal service startup.
Successful IDs are cached for the server lifetime and logged as
`[Admin] Username -> UserId`. Failed lookups warn and grant no permission.
Commands sent before identity resolution finishes are ignored.

The workspace could not reach Roblox's username API during implementation, so
no real numeric IDs were verified. For permanent authorization across username
changes, copy the live server's resolved IDs into `AdminUserIds` and remove the
corresponding bootstrap names. No name, display name, attribute, or client GUI
grants command permission; every invocation checks the player's numeric ID on
the server. There is no admin RemoteEvent or arbitrary-code command.

Cash follows `TycoonService.AddCash` -> `SetCash` -> active session transaction
-> `session.SharedCash` -> existing `publish(session)`. The owner's and
teammate's existing `playerCash` projections both update through that publisher.
No economy, persistence, membership, or cash UI behavior was changed.

With TextChatService chat, the service registers hidden `TextChatCommand`
instances for `;addcash`, `;giveicegun`, `;givewings`, and `;hotbardebug`.
Roblox intercepts recognized commands without broadcasting them, including
unauthorized attempts. Unknown commands
remain ordinary chat. Legacy chat uses server `Player.Chatted` and commands
remain visible. The chat mode is read from the existing place, not changed.
The dispatcher is shared, so command registration and parsing use the same
case-insensitive names. Player departure clears cooldowns and legacy chat
connections; resolved permissions remain global for the server lifetime.

No additional instances or assets need to be authored in Studio. Sync with Rojo
and publish the updated server scripts. Keep normal Roblox chat enabled. Studio
test players usually have synthetic IDs and will not match the real admins;
use the real accounts in a private server for the final chat smoke test.

Focused suites cover real TycoonService cash storage and publication, wings
grants and input, and simulated Roblox chat and username lookups.

```text
python tests/run_state_tests.py --suite admin --suite admin-legacy --suite wings-ownership --suite wings-input
```

In a private server, verify the three identity mapping logs, then run
`;addcash 100000` while sharing a stand and check that both cash UIs increase
by the same amount. Run `;addcash 100000 ExactUsername` with a player on another
stand and check their balance. Give wings to a nonowner, test holding Jump,
and reset to verify the grant expires. Check mixed case, a duplicate within
0.35 seconds, and a non-admin attempt. Modern chat interception needs this engine smoke test.
The CLI fixture does not emulate Roblox's alias matcher or network delivery.

Original admin command validation: both admin suites passed (31 behavioral checks per
chat adapter). StyLua and Rojo build pass. The admin modules have no focused
type diagnostics; full-source typecheck has the same diagnostics as a snapshot
of the pre-admin working tree. Existing `plot-session` and `plot-session-races`
suites fail at `one shared deduction and tier` and `purchase remains committed`,
respectively, on both that baseline and the current tree. Those economy tests
and their production systems were left unchanged. No Studio/private-server
playtest was performed.
