# Scrapbook discovery backend

`DiscoveryService` validates canonical IDs, records discoveries in PlayerDataService's
`Discovery` field, and emits only the first acquisition/encounter. No GUI or DataStore
persistence is added. Legacy recipe `Discoveries` remains separate. New players start
empty; missing discovery categories in older in-memory profiles initialize lazily.

Ingredient acquisition commits through InventoryService's successful `equipVisual`
completion (world pickup and stash withdrawal/theft), successful `ClaimWorldItem`
consumption, or `AddUnit` server grants. Internal reservations do not award discoveries.
Spawning, proximity, failed consumption/equip, and smoothie contents do not unlock entries.

Special Customer discovery occurs after the customer record is inserted in the active
queue. Every current member of that plot session receives the encounter; other sessions
do not. Serving is unnecessary. Members joining later are eligible for subsequent
spawns, with no retroactive scan of existing customers.

## Client protocol

Remotes are created automatically under `ReplicatedStorage.Shared.Events`:

- `DiscoverySnapshot:InvokeServer()` returns only the caller's state:
  `{ Ingredients = { Strawberry = true }, SpecialCustomers = { caseoh = true } }`.
- `DiscoveryAdded.OnClientEvent` sends `{ Kind = "Ingredient", Id = "Strawberry" }`
  or `{ Kind = "SpecialCustomer", Id = "caseoh" }`, only for new discoveries.

`Types.DiscoveryState` and `Types.DiscoveryEvent` define these payloads. There is no
client discovery mutation endpoint. Future UI should subscribe before requesting its
snapshot and merge buffered deltas with it (unlocks are monotonic during a session).
No catalog is sent on either remote.

PlayerDataService snapshots serialize the same state under `Discovery`. Both snapshot
APIs copy both sets; callers cannot mutate canonical state through a snapshot.
`GetDiscoveryState` is a server-only mutable boundary used by DiscoveryService.

## Catalogs and presentation

`Shared.Constants.DiscoveryCatalog.GetIngredients()` returns all canonical ingredients
with Id, DisplayName, Rarity, Value, and JumpLocation. Metadata comes from `Ingredients`.
Entries sort by explicit Common, Uncommon, Rare, Mystery order, then stable ID.
The future UI can split rarity groups into rows of four.

`GetSpecialCustomers()` returns all Special mappings in `CustomerRequests.NPCs`,
including currently zero-weight entries, with Id, DisplayName, and MinJumpTier from
the mapped request. Entries sort by minimum jump tier, then ID. Explicit Regular
mappings are excluded; existing RequestId-only mappings retain special semantics.
For example, Walter White's canonical ID is `walter`, not `WalterWhite`.

Artwork, silhouettes, hiding names/values, and four-column layout belong to future UI.
No additional Studio setup is required; live two-client network smoke testing is still
needed before the UI ships.

## Validation

Run `tests/run_state_tests.py` with `--suite discovery --suite discovery-inventory
--suite discovery-customers` and the Luau executable. These cover discovery state,
replication isolation, legacy initialization, cleanup, catalogs, authoritative inventory
commit/rollback, and registered customer encounters across session membership.

Carry and stash integration regressions pass. Existing `customer-queue` and
`request-selection` failures reproduce in a separate pre-change working-tree baseline.
Full-project Roblox typecheck reports baseline errors in CustomerRequests (missing
DisplayText) and CombatService (optional BasePart); discovery changes add no new
unique diagnostics. StyLua, Rojo build, and git diff whitespace checks pass.
