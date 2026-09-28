# Stash stealing and protection

Each stash has five slots. Slots 1–2 always reject enemy withdrawal. Slots 3–5 allow enemy withdrawal until carry capacity is full. The first successful theft starts one six-second window for the whole stash; later thefts do not extend it. At the deadline, all exposed slots reject enemies for thirty seconds. Owners and current teammates can store and take throughout both phases.

`Economy.NormalStash` configures `IngredientCapacity` (3), `RaidWindowSeconds` (6), and `RaidProtectionSeconds` (30). Ingredients are individual records in insertion order; withdrawals take the last record. A smoothie occupies one entire slot and retains its blend identity and ingredient list. Snapshot records are copied. Failed visual creation or equip leaves the exact stash contents intact and does not start a raid.

`InventoryService` validates active plot membership, canonical fixture and slot identity, character health, action eligibility, proximity, and carry capacity. Enemy interactions always take. Friendly interactions retain the existing 1.2-second successful-transfer burst direction. Replicated direction and session-scoped raid deadlines only drive presentation; the server never accepts client ownership, direction, protection, or capacity claims.

Raid state is keyed by the authoritative plot session ID and removed through the bootstrap's `SessionEnded` hook. Deadlines are evaluated when needed, with no delayed tasks. The existing prompt heartbeat evaluates replicated deadlines so protection starts and ends without rebuilding displays or scheduling per-slot timers. `StashPresentation` creates each mixed ingredient proxy independently using the existing anchored, noninteractive geometry path.

## Validation

Run `python tests/run_state_tests.py --luau <luau.exe> --stash-only` for authoritative stash contracts, real plot/smoothie integration, display geometry, and client prompts in separate processes. All four suites pass. Runner contracts, focused runtime typecheck, StyLua, Rojo build, and whitespace validation pass.

Full-source typecheck has the same 26 unique pre-existing `CustomerRequests` missing-`DisplayText` diagnostics as baseline. Existing `smoothie` and `smoothie-roundtrip` suites fail on baseline as well: outdated carry-capacity expectations and a one-second wait for the 1.2-second burst. These unrelated tests and production systems were left unchanged; the new stash integration suite covers dispensed smoothie theft and rollback directly.

## Studio smoke test

No new assets, tags, remotes, or authored attributes are required. Keep one `PlayerStash` fixture per plot with five uniquely indexed BaseParts (`SlotIndex` 1–5). Sync through Rojo and start a fresh play session.

Use three clients with two on one team. Store three different ingredients in one slot and a smoothie in another. Verify teammate access, permanent protection, repeated enemy theft while already carrying an item, shared raid timing across exposed slots, protection expiry, full-carry rejection, and team access during protection. Leave/reassign the plot during a raid and confirm the new session is unprotected. Check replicated labels and mixed displays from both teams. Automated tests mock Roblox boundaries; this multiplayer Studio smoke test has not been run.
