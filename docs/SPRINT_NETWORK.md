# Sprint request queue fix

`SprintRequest` now carries only client-to-server boolean intent:
`SprintController` calls `FireServer(true/false)` on input transitions and
`SprintService.OnServerEvent` validates the payload and eligibility. The server
continues to own stamina, exhaustion, movement upgrades, and WalkSpeed with stun
precedence. Its existing `StaminaCurrent`, `StaminaMax`, and `IsSprinting` Player
attributes replicate presentation state. No `SprintStateChanged` event is needed.

Previously, the same remote also sent `FireClient` once per player per Heartbeat,
even while idle. At 60 Heartbeats/second this produces about 3,600 messages per
minute per client. Without an active client listener, buffering and dropped-event
counts grow continuously. The client requests themselves were already driven by
Shift input, not frames; it was the server's state return path that fired every
frame. See Roblox's [RemoteEvent documentation](https://create.roblox.com/docs/reference/engine/classes/RemoteEvent).

The checked-in controller did have an `OnClientEvent` listener, but it only
rewrote the same replicated attributes locally. Source inspection cannot establish
why that listener was absent in the reported Studio session. A stale/disabled or
errored client bootstrap is possible, but unconfirmed. The fix removes the
unnecessary sender and redundant receiver; it does not mask the warning with an
empty listener.

Repository search found one server initialization call, one client initialization
call, one Rojo mapping per bootstrap, and no sprint component or secondary sprint
loop. Both initializers now guard against repeated calls. Client input also
deduplicates intent, tracks both Shift keys, and stops sprint on window focus loss.
Holding Shift does not automatically restart sprint after exhaustion.

## Validation

Run `python tests/run_state_tests.py --sprint-only --luau <luau-executable>`.
The focused tests execute real sprint, controller, movement, configuration, and
player data modules using the existing fake Roblox boundary. They cover 2,048 idle
frames without a client state listener, 2,048 held-input frames, duplicate Init,
input transitions, authoritative stamina and upgrades, forged attributes, stun,
exhaustion, regeneration, missing/dead characters, and respawn reset.

Roblox-aware Luau LSP analysis uses a fresh Rojo sourcemap and Roblox definitions.
StyLua checks all touched Luau files; Rojo builds the existing project mapping.
The broader state suite also fails on unchanged HEAD at `base stamina full at 110`:
the current configuration starts at 60. This patch does not change balance values
or the ingredient spawning refactor.

No live Studio playtest was performed. No manual instances or mappings are needed.
Sync through Rojo and restart Play to discard old runtime connections. In a
two-client Play test, idle for a minute, press/release both Shift keys, exhaust
stamina, buy movement/stamina upgrades, and respawn. Confirm no SprintRequest queue
warnings and that server attributes and movement remain correct on both clients.
