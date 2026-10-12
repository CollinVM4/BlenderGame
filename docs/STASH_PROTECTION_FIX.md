# Permanent stash protection and capacity

## Findings

The reported one-off lock on correctly numbered logical slot 5 was not reproduced.
The prior authoritative model protected only indices <= 2, so it did not classify
logical slot 5 as protected. Studio slots are named LockedSlot1/LockedSlot2 and
have no protection tags; those names remain unchanged.

A concrete presentation bug existed in StashPresentation.Refresh:
`state and state.Protected or (logicalIndex or SlotIndex or 0) <= 2`.
An authoritative false value fell through to an index guess. Missing numbering
became zero and displayed as protected, even on a part named Slot5. This fallback
is removed and has a regression test. This is a verified failure pathway, not proof
that it caused the transient behavior in the live Studio fixture.

The capacity bug was definite: ingredientSlotCapacity returned 1 for protected
slots and 3 for exposed slots. All ingredient slots now use capacity 3; mixed and
duplicate ingredients retain existing stacking, individual identity, and ripeness.
Smoothies continue to occupy a whole slot at capacity 1; emptying restores 3.

## Authoritative designations

NormalStash.SlotProtection is explicit server-owned metadata: `{ [1] = true,
[2] = true }`. It preserves the existing protected slots without a Studio migration.
There is no numeric cutoff or name/ancestor-based protection inference.

The resolved interaction BasePart may provide an optional boolean attribute
StashSlotProtected. Both true and false override default server metadata. With
no boolean override, a direct ProtectedStashSlot tag or the explicit configuration
entry designates protection. StashProtected is replicated output only.
No designation exists for slot 5 or upgraded slots 6-10 by default.

InventoryService refreshes metadata from the unique authoritative fixture for
snapshots, layout queries and transfers. Player and NPC theft share those rules;
NPC theft no longer separately excludes low indices. Stash prompt labels and UI
attributes reflect authoritative snapshot protection/capacity. Client availability
already consumes those attributes and requires no independent classification.

Second Storage still unlocks the same authored surfaces and 10-slot layout.
Existing raid deadlines and temporary post-raid protection are unchanged. Permanent
slot protection is independent of the upcoming temporary Base Lock feature.

## Changed files

- Economy.luau and StashSlots.luau: explicit protection metadata and resolver.
- InventoryService.luau: shared capacity, metadata, snapshots, theft and layout.
- Stash.luau and StashPresentation.luau: authoritative labels and protection output.
- stash_interaction.spec.luau: all ten slots, no/tag/metadata designations, capacity,
  full rejection, mixed/duplicate values, theft, ripening and owner TAKE; default
  first-two configuration and explicit false/NPC theft override.
- stash_integration.spec.luau: smoothie removal restores protected capacity 3.
- stash_expansion.spec.luau: terminology reflects explicit protection designations.
- stash_capacity_indicators.spec.luau: all ten slots and false/missing-index regression.
- PLAYER_STASH.md, SECOND_STORAGE.md and FILMING_VERTICAL_SLICE.md: setup contracts.

## Validation

PASS: stash (490 behavioral checks), stash-integration (16), stash-expansion (67),
bad-customer-stash (31), stash-capacity-indicators (394), stash-prompts (45), and
stash-presentation (79). State, integration and presentation ran independently.
Coverage includes all original and upgraded slots, direct tags, direct metadata,
no designation, ancestor tags/metadata and stale replicated protection, three-unit
storage, fourth STORE rejection without loss, theft rejection/success, values,
ripening, owner TAKE, teammates, rollback/replay and existing raid boundaries.

Changed-runtime Roblox-aware typecheck passes. Whole-source analysis reports 216
pre-existing diagnostics (220 before this change), with no new diagnostics.
StyLua and Rojo build pass.

Additional smoothie and smoothie-roundtrip suites fail identically in a temporary
copy of the pre-change workspace: carry-capacity fixture drift and a missing payout
helper respectively. Existing unrelated work was preserved.

No Studio tag edits or renaming are required for the existing layout. Rojo sync
and start a fresh session. Manual two-client Studio smoke checks remain unrun:
confirm 1/2 protected, 3-5 exposed, purchase Second Storage and confirm 6-10 exposed;
store three mixed ingredients, reject a fourth, check 3/3 and three physical lights,
TAKE/ripening/value refresh, theft and teammate access. Optional protection metadata
must be authored on the resolved interaction surface before Play.
