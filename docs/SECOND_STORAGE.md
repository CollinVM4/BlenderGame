# Second Storage

The physical walk-over pad purchases `SharedUpgrades.SecondStorage` tier 2 for
8,000 shared cash. Tier 1 gives five slots; tier 2 gives ten. `Upgrades.SecondStorage`
is the only price/capacity definition. `PurchaseSecondStorage` uses the existing
session transaction lock and validates membership against the target plot.
Generic `PurchaseUpgrade` rejects this ID. Purchases are non-persistent, survive
owner promotion, and reset on final session release.

## Studio hierarchy

The hierarchy below matches the actual Studio hierarchy supplied by the user.
The generated Rojo place does not include authored plot assets. No live Studio
inspection is claimed.

```text
PlayerPlot
  Stash                  existing PlayerStash fixture
    LockedSlot1          existing surface SlotIndex = 1
    LockedSlot2          existing surface SlotIndex = 2
    Slot3                existing surface SlotIndex = 3
    Slot4                existing surface SlotIndex = 4
    Slot5                existing surface SlotIndex = 5
  UpgradeStash
    base                 purchased structure
    Slot6                logical 6
    Slot7                logical 7
    Slot8                logical 8
    Slot9                logical 9
    Slot10               logical 10
    PurchasePoint        BasePart, direct Touched binding
    shine                untouched authored decoration
```

The existing first row still requires unique integer SlotIndex attributes 1-5.
Legacy auto-tagging now recognizes direct child `Stash` when there is no existing
PlayerStash tag. Keep exactly one PlayerStash fixture per plot; do not tag the
second row. No added scripts, tags, or renaming are required for UpgradeStash.
Second-row slots may be BaseParts, Models with an authored PrimaryPart interaction
surface, or containers with one BasePart. A multipart container without a
PrimaryPart must have exactly one surface marked with its logical SlotIndex (6-10).
Decorative lock geometry is allowed. Ambiguous/missing expansion surfaces warn
and prevent the purchase pad from binding.

Only `base` and `Slot6`-`Slot10` are captured for the reveal; `PurchasePoint` and
`shine` never move with it. Authored transforms are final transforms.
Purchased geometry is anchored, hidden and made
noninteractive until purchase. The pad disappears immediately; the row rises
3.5 studs over 0.5 seconds using Back/Out easing. Contextual prompts and server
slot access become available when the reveal finishes. On release or unbinding,
tweens are cancelled, authored transforms restored, and the row locked again.
Generation guards prevent retired completion callbacks from enabling recycled plots.
The client billboard uses the same WorldBillboardStyle and DialogueTextStyle as
farm pads (340x64 pixels, 24px text, white title, gold price, 40-stud distance).

## Protection and ownership

Only logical slots 1 and 2 are protected. Existing code protects numeric positions,
not names, and NormalStash.Protected remains 2. Therefore slots 6-10 are all
unprotected. This preserves the existing two-total-position protection rule.
No VIP changes were made.

Contents remain in the existing per-player inventory records. Physical plot prompts
resolve the current plot owner, teammates can store/take via the existing friendly
access rules, and promotion changes the physical stash's owner as before. Contents
are not pooled or migrated. Ingredient stack limits, smoothie identity, theft and
raid protection all use the existing InventoryService paths.

## Changed files

- `src/shared/Constants/Upgrades.luau`: price and capacity tiers.
- `src/server/Services/TycoonService.luau`: shared tier, locked purchase, projection, legacy Stash lookup.
- `src/server/Services/StashSlots.luau`: common authored-to-logical resolver.
- `src/server/Services/StashExpansionService.luau`: physical pad, reveal and reset lifecycle.
- `src/server/Services/InventoryService.luau`: capacity and physical-slot validation.
- `src/server/Components/Stash.luau`: reuse existing contextual prompts for both rows.
- `src/server/Components/StashPresentation.luau`: logical protection metadata.
- `src/client/Controllers/StashExpansionController.luau`: purchase billboard.
- `src/server/init.server.luau`, `src/client/init.client.luau`: initialization.
- `tests/stash_expansion.spec.luau`, `tests/run_state_tests.py`: focused integration suite.
- `docs/SECOND_STORAGE.md`: setup and behavior documentation.

Existing unrelated working-tree farm/audio edits are preserved.

## Validation and remaining manual check

Run `python tests/run_state_tests.py --luau <luau.exe> --suite stash-expansion`.
The suite exercises pad membership/cash/replay, protected mapping, real contextual
prompt routing, all expanded slots, smoothie/theft reuse, promotion, release and
stale callbacks. Related stash integration and plot progression/race suites pass.
Changed runtime modules pass Roblox-aware typecheck; StyLua and Rojo build pass.
The existing stash state suite fails its refreshed-burst timeout assertion on both
this change and unchanged HEAD. Full-source typecheck reports the same 78 CustomerRequests DisplayText diagnostics
on this change and unchanged HEAD; these are not repaired in this feature.

After Rojo sync, verify the hierarchy above in Studio. No setup changes should be
needed for the supplied BasePart hierarchy. For multipart slots, set the interaction
surface as PrimaryPart (or use the logical SlotIndex rule). Playtest two teammates
and an opponent: pad label, rejected purchases, one charge on overlap, reveal,
slot prompts, and final release during a reveal. Visual tween appearance and
actual Studio physics/network behavior have not been live-tested.

## Hierarchy mismatch fix

The original resolver expected LockedSlot1/LockedSlot2/Slot3-Slot5 in UpgradeStash
and mapped local indices 1-5 to 6-10. With the actual Slot6-Slot10 names it returned
no expansion slots. StashExpansionService returned at its slot validation before
hidden-state initialization and before connecting PurchasePoint.Touched. This
explains both the visible structure and inert pad. The resolver now uses the
actual names directly, and capture explicitly includes only base plus those slots.
The pad was already resolved directly as a BasePart and still uses that path.

This fix changes StashSlots.luau, StashExpansionService.luau,
tests/stash_expansion.spec.luau, and this document. No Studio renaming, new tags,
or additional pad children/scripts are required. Restart the play session after
sync so the corrected service binds the authored hierarchy.
