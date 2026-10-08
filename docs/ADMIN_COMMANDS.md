# Server admin commands

After claiming or joining a stand, type `;addCash 100000` in Roblox chat.
Command names are case-insensitive and argument whitespace is tolerant.
There is one amount argument and no player targeting. Positive finite amounts
up to 1,000,000,000 are accepted; decimals are floored and results below 1 are
rejected. Successful executions have a 0.35-second per-player cooldown.

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

With TextChatService chat, the service registers a `TextChatCommand` for
`;addcash`, hidden from autocomplete. Roblox intercepts recognized commands
without broadcasting them, including unauthorized attempts. Unknown commands
remain ordinary chat. Legacy chat uses server `Player.Chatted` and commands
remain visible. The chat mode is read from the existing place, not changed.
The dispatcher is shared, so command registration and parsing use the same
case-insensitive names. Player departure clears cooldowns and legacy chat
connections; resolved permissions remain global for the server lifetime.

No additional instances or assets need to be authored in Studio. Sync with Rojo
and publish the updated server scripts. Keep normal Roblox chat enabled. Studio
test players usually have synthetic IDs and will not match the real admins;
use the real accounts in a private server for the final chat smoke test.

Focused automated integration suites use real TycoonService cash storage and
publication, with Roblox chat and username lookups simulated:

```text
python tests/run_state_tests.py --suite admin --suite admin-legacy
```

In a private server, verify the three identity mapping logs, then run
`;addCash 100000` while sharing a stand and check that both cash UIs increase
by the same amount. Check mixed case, a duplicate within 0.35 seconds, and a
non-admin attempt. Modern chat interception needs this engine smoke test;
the CLI fixture does not emulate Roblox's alias matcher or network delivery.

Implementation validation: both admin suites pass (31 behavioral checks per
chat adapter). StyLua and Rojo build pass. The admin modules have no focused
type diagnostics; full-source typecheck has the same diagnostics as a snapshot
of the pre-admin working tree. Existing `plot-session` and `plot-session-races`
suites fail at `one shared deduction and tier` and `purchase remains committed`,
respectively, on both that baseline and the current tree. Those economy tests
and their production systems were left unchanged. No Studio/private-server
playtest was performed.
