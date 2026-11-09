# One-time starter stash

Implemented on `feature/starter-stash`; no merge, publish, or live DataStore write
was performed during development.

| Authored logical slot | Canonical ingredient IDs | Catalog classification |
|---|---|---|
| LockedSlot1 / 1 | Apple, Cherries, Strawberry | Red |
| LockedSlot2 / 2 | Banana, Lemon, Pear | Yellow |
| Slot3 / 3 | Ice, Ice, Ice | Cold |
| Slot4 / 4 | Cabbage, Carrot, Mushrooms | Veggie |
| Slot5 / 5 | Milk, Milk, Milk | Milk |

Ice and Milk are the only catalog entries in their respective categories. Every
unit has its own ItemId; duplicate IDs are normal ingredient records. Mixed
ingredient stacks already support three records in both protected and exposed
slots. Existing server slot resolution, protection designations, raid deadlines,
ownership checks, and shared presentation remain authoritative.

## Persistence and shared ownership

The repository previously had no gameplay DataStore adapter: PlayerDataService
and plot progression were in memory. This change adds only stash persistence:
`PlayerStash_v1`, default scope, key `Player_<founding owner UserId>`. It does not
migrate an unspecified external data store or persist cash, upgrades, tutorial
completion, or carried inventory.

The first successful UpdateAsync creates the complete starter stash and a lease
atomically, before publishing any units. Existence of a version-1 stash record is
the permanent grant receipt, including when Slots is empty. Existing records are
loaded without generating new units; unsupported records or API failures reject
the claim without replacing data. Slot records contain ingredients or a single
smoothie; capacities, counts, and protection are derived again on restore.
DataStore metadata and associated user IDs are retained on writes.

The original owner's save key follows the shared session through teammate
promotion. Only one session may open that progression. A departing founder cannot
open another independent copy while the promoted teammate still uses that stash.
Joining an existing plot does not open or seed the joining player's progression.
Closing the shared session saves to the founder's key and releases its lease.

The lease lasts 180 seconds, renews every 30 seconds, and rejects another server's
load while active. Expired leases disable live stash transfers. Old lease tokens
cannot overwrite a newer server's state. Failed loads never fall back to new
defaults. Restoration checks both the live session ID and the original inventory
ledger after the yielding call; it cannot replace a new ledger created meanwhile.

Changes stage detached records on the existing StashChanged event, coalesce writes
over six seconds, retry through the 30-second writer, and flush at session close
and BindToClose. Close retries three times and retains failed profiles for later
release attempts. As with autosaved state, a process crash or prolonged DataStore
outage can lose mutations since the last successful write; cross-inventory trades
are not durable distributed transactions. The initial grant receipt is committed
before the first visible grant, so loading never runs the grant factory again.

Stored ingredient origin, accumulated ripeness, source identity, announcement
ownership, and smoothie unit records persist. Offline time does not advance stash
ripeness. Server-local appearance cache tokens are not serialized; dynamic player
heads retain source identity and use the existing visual fallback after restart.

## Changed files

- StarterStash: ordered server-owned grant data, validated against actual tags.
- StashRecords: DataStore-safe ingredient/cup encoding and restoration.
- StashPersistence: atomic acquisition, lease, saves, retries, shutdown.
- InventoryService: restore/seed integration, mutation staging, shared-session
  cleanup, and rejection of transfers while loading or after lease expiry.
- Server bootstrap: persistence lifecycle initialization.
- TutorialOrders: only slot/ingredient references follow the new stash; Red,
  Cold, Yellow sequencing, arrival times, payout floors, and state machine stay
  unchanged. Actual ingredient values continue through the normal payout formula.
- TutorialTargets: also accepts the authored LockedSlot1/LockedSlot2 names.
- Test manifest, new starter suite and DataStore fixture, and affected tutorial
  fixtures/specs. Grant lifecycle tests have one home in starter-stash; bootstrap
  tests retain bootstrap wiring checks.

No changes to tutorial stages, serving/payout code, customer sequencing, or prompt
draw distance were made.

## Validation

Run the following with the installed Luau executable:

```powershell
python tests/run_state_tests.py --luau <luau.exe> --suite starter-stash --suite stash --suite stash-integration --suite stash-expansion --suite bad-customer-stash --suite tutorial --suite tutorial-claim --suite tutorial-gameplay
python tests/run_state_tests.py --luau <luau.exe> --suite tutorial-targets --suite stash-presentation --suite stash-prompts
```

All eleven selected suites pass. Starter-stash covers separate owners, protected
and ordinary theft, normal raid protection expiry, depletion, reset/reclaim,
teammate joins, promotion, another server loading saved/empty records, competing
leases, stale writes/restores, failed reads/saves, in-flight save staging, invalid
IDs, cups/provenance, preparation rollback, and departure during initialization.

StyLua checks on all changed/new Luau files and Rojo 7.7 build pass. Full-source
Roblox-aware luau-lsp analysis reports 212 TypeError headers, exactly identical
after path normalization to an isolated git archive of pre-change HEAD. There
are no new type diagnostics. Tools: Luau 0.745, StyLua 2.6.0, luau-lsp 1.70.1,
and the installed Roblox definitions used by prior validation.

The four extra plot-session regression suites reproduce their exact failures on
the isolated baseline and remain unchanged:

| Suite | Baseline and current failure |
|---|---|
| plot-session | one shared deduction and tier |
| plot-session-races | purchase remains committed |
| plot-session-progression | SETUP: buy shared Jump |
| plot-session-requests | two same-tier network requests purchase once |

`python -B tests/test_state_runner.py` reports the same four failures out of five
tests on baseline and current: stale default/group manifest assumptions, first
presentation-suite ordering, and omitted smoothie-dispense selection. Two prior
tutorial suite failures were also reproduced on baseline and fixed only in test
boundaries: missing unrelated bootstrap doubles and IsDoubleCashActive in the
onboarding payout dependency double.

## Required Studio checks

No new assets, attributes, remotes, or tag changes are needed. Keep the existing
unique SlotIndex surfaces 1-5 and the first two protected designations. Use a
published test experience with Studio API access enabled and separate test user
IDs/records; unavailable API access intentionally rejects claims instead of
granting a session-only replacement. See Roblox's [DataStore documentation](https://create.roblox.com/docs/cloud-services/data-stores).

Studio/network verification was not available in this CLI session:

1. Two clients on separate plots: verify the ordered five slots and fifteen units
   each, then join one plot as teammates and inspect the same rendered stash and
   counts from both clients.
2. Check first-two-slot protection, theft from slots 3-5, raid deadlines, owner
   departure/promotion, and the unchanged shared stash display after promotion.
3. Drain or steal the stash; reset, reclaim, leave/rejoin, and restart the test
   server. Verify persisted empty slots remain empty and deposits keep identities.
4. Accept tutorial Red: LockedSlot1/base gleams, the three fruits progress through
   normal carry/blend/serve, and Cold/Yellow guidance selects slots 3/2.
5. Exercise denied API access, overlapping server acquisition, delayed load/save,
   and shutdown. Claims must fail closed; unsupported records must remain intact.
