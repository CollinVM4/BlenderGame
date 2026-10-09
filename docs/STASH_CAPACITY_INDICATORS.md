# Stash capacity indicators

`StashPresentation.Refresh` colors the authored `SlotIndicator` BaseParts from
the existing authoritative slot snapshot. Stored ingredient entries fill indicators
green (`0, 255, 0`); unused indicators remain red (`117, 0, 0`). Smoothie occupancy
uses its snapshot count and capacity. Both protected and exposed ingredient slots
have capacity three; a smoothie has capacity one.

Indicators are collected beneath the resolved slot part or its containing slot
model, including duplicate names and nested parts. Fill order follows local X,
then Y and Z, relative to the interaction base. Only Color changes. Occupancy is
clamped to authoritative capacity and available indicators; extra parts stay red.
Missing indicators, unavailable storage, and malformed contents are safe.

The existing initial refresh and StashChanged refresh update indicators on deposit,
withdrawal, theft, owner changes, and expansion availability changes. No polling or
new assets are required. Keep SlotIndicator parts inside their existing slot models.

## Automated validation

Run `python tests/run_state_tests.py --luau <luau.exe> --suite stash-capacity-indicators`.
This presentation suite covers protected/base/expanded slots, empty/partial/full
transitions, mismatched indicator counts, rotated ordering, geometry preservation,
separate slot isolation, missing parts, and malformed snapshots.

## Studio smoke checks (not run)

1. For LockedSlot1 and LockedSlot2, confirm three ingredients fill three lights,
   successive withdrawals clear them, and a fourth ingredient is rejected.
2. For a regular slot with matching capacity, deposit successive ingredients and
   confirm local left-to-right green fill; withdraw and confirm unused units turn red.
3. Trigger bad-customer theft and ordinary stealing; confirm the affected slot
   immediately loses one green indicator, including red after its last removal.
4. Purchase second storage and repeat the occupancy checks on its resolved slots.
5. Confirm prompts, ripeness UI, protected-slot rules, smoothie storage, and the
   second-storage purchase/reveal still behave as before.
6. Check slots with missing/fewer/extra indicators and verify safe clamping with
   unchanged gameplay capacity and authored geometry/materials.
