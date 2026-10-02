# Ingredient ripeness backend

Only Fresh and Ripe exist. `shared/Constants/Ripeness` configures 120 stash
seconds and a 1.25 value multiplier. Ingredient definitions remain unchanged.

## Authoritative item lifecycle

`Types.IngredientItem` extends the existing stash unit representation with
`ItemId`, `RipenessStoredSeconds`, `RipenessStoredAt`, and `IsRipe`.
IngredientService creates the identity once (also exposed as WorldItemId).
Its private world record and InventoryService's private held record each carry
the unit in `Item`; stash slots contain the units directly in `Ingredients`.
Legacy count-facing claim/release APIs now retain unit lists internally while
their snapshots still expose counts.

Entering stash starts an interval using `workspace:GetServerTimeNow()` without
resetting accumulated time. Successful withdrawal commits that interval and
clears the timestamp. Failed withdrawal preserves the original interval.
Ripe permanently commits at 120 seconds; it never restarts aging. Time outside
stash does not count. Smoothies do not age.

`IngredientItem` provides pure timing/progress/value helpers and server-used
entry, exit, and promotion mutations. Snapshots and withdrawal resolve thresholds
lazily. One global, one-second-throttled heartbeat scan promotes untouched units
and emits StashChanged only when a threshold crosses, keeping existing totals
current. No per-item timers or per-frame progress replication are used.

Take and steal select the highest stored time, with Ripe capped at the threshold.
Equal progress preserves insertion order. Withdrawal quantity, capacities,
protection, and raid rules remain unchanged.

Throw, drop, pickup, ownership transfer, and legacy release retain the same unit
identity and aging data. BlendService preserves accepted units in
`IngredientItems` through batch result and smoothie data. Existing `Ingredients`
ID lists remain the compatibility projection for matching, grading, and colors.
Smoothie copy/result conversions copy unit metadata too.

## Economic contract

`IngredientItem.GetIngredientValue(unit, now)` is the effective-value authority:
base Value for Fresh, base Value times 1.25 for Ripe.
`GetSmoothieValue` sums each physical contribution; ID-only legacy smoothies are
treated as fresh. StashValue and customer payouts use these helpers.
World items replicate `EffectiveIngredientValue` for the existing pickup label.
There is no smoothie-wide ripeness multiplier. Grade, request base, upgrade,
entitlement, and rounding calculations retain their existing behavior.

## Client presentation contract

Inventory snapshots expose independent ingredient records, including ItemId,
IngredientId, IsRipe, RipenessStoredSeconds, and RipenessStoredAt.
Each physical stash slot also exposes:

- `RipenessSeconds`
- `StashItem1Id`, `StashItem1IngredientId`, `StashItem1IsRipe`,
  `StashItem1StoredSeconds`, `StashItem1StoredAt`
- The same fields for indices 2 and 3; absent units have nil attributes.

Protected slots use the same contract with at most one item. Array indices are
display positions; ItemId is stable identity. Clients use GetServerTimeNow and
the shared progress helper (or the equivalent clamped calculation) to animate
between state updates. Replicated values are presentation only, never proof of
ownership or authority.

Player attribute `RipenessTutorialShown` changes from false to true after the
first successful ingredient deposit in that player's session. It remains true
through subsequent stores and plot changes. A client may observe that transition
or consume the current true state if its controller starts late. Smoothie and
failed stores do not trigger it. The upcoming tooltip text is:

```text
Ingredients can RIPEN while stored.
RIPE Ingredients are worth +25%
```

The client now shows the one-time tooltip and independent stash progress pips.
Each stash slot needs a Studio-authored `Attachment` named `StashRipenessOrigin`
directly under the slot, alongside `StashPromptOrigin`, `base`, and `shine`.
Place it horizontally centered above the pad, a few studs high, and tune its
height against the value label in Studio. The pip billboard uses this attachment
as its world anchor and keeps a fixed 120 by 24 pixel size. If the attachment is
missing or has the wrong class, the billboard falls back to the slot itself.
`Constants/RipenessPresentation` sets a 36-stud distance for the stash value and
pips and their bright gold accent.
World pickup cards show rarity, Fresh/Ripe state, and effective value. Held
overhead ingredients keep one effective monetary value label, without rarity
or Fresh/Ripe text. Smoothie carry value remains visible. The new attachment
must be added to every existing and expansion stash slot in the Studio place;
Rojo does not map these authored slot instances. A Studio network smoke test of
replication and physical transfers remains recommended.

## Changed files and validation

Runtime: shared `Types`, `IngredientItem`, `Constants/Ripeness`; services
`IngredientService`, `InventoryService`, `BlendService`, `SmoothieItem`,
`StashValue`, `CustomerService`, `IngredientCarryPresentation`; component `Stash`;
UI `IngredientPickupPromptPresentation` (existing value label only).
The existing stash total display consumes snapshot Value. Concurrent prompt and
stash-display work was preserved.

New tests: `ripeness.spec.luau` and `ripeness_lifecycle.spec.luau`, registered in
`run_state_tests.py`; shared Roblox fixture loads the helper and exposes a
controllable heartbeat. Stash fixture records use physical item metadata.

Passed: ripeness state and lifecycle, stash state and integration, customer
payout state, smoothie survivors, ingredient slots, stash presentation, ingredient
prompt checks, StyLua, Rojo build, and whitespace checks. Changed feature modules
pass Roblox-aware typecheck excluding CustomerService's existing dependency errors.

Baseline-confirmed unrelated failures: world suite's old single-carry expectation;
customer-payout-serve's dialogue assertion; runner tests' outdated suite lists;
CustomerRequests missing DisplayText diagnostics and CustomerService's optional
Evaluation/grade typing diagnostics. These were reproduced on unchanged HEAD and
were not fixed by changing unrelated production code.
