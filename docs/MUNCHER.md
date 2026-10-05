# Muncher V1

`MuncherService` owns appetite, progress, multiplier and server expiration per
`PlotSessionId`. A teammate shares the plot's reward; leaving the team revokes
access immediately. Session closure clears progress and buffs, so a reassigned
plot starts fresh. Nothing persists across servers.

Balancing lives in `src/shared/Constants/Muncher.luau`: equally likely targets of
25 / 50 / 100, earning 1.25x for 300 seconds / 1.5x for 420 seconds / 2x for
600 seconds. Every accepted ingredient contributes one, regardless of its value,
rarity, type or ripeness. Completion resets progress and rolls another goal.
New rewards replace the previous multiplier and deadline, including weaker rewards.
Expiration uses `workspace:GetServerTimeNow()` and is checked on payout lookup,
so a delayed presentation tick cannot prolong a buff.

## Feeding and authority

World feeding is exclusively physical: carry/throw an ingredient into InputZone.
The component creates no Feed prompt or manual interaction callback and removes
legacy ProximityPrompts beneath InputZone, including ones added later. The service
API remains compatible, but its manual intake branch has no world interaction
binding. The server checks current membership, character health and action
eligibility. No new ingredient-ID or gameplay-state remote exists.

Thrown/loose world ingredients are scanned at 0.1-second intervals, resolved
through `IngredientService`'s private registry, verified against actual server
overlap and removed with `IngredientService.Consume`. Only the item's owner may
feed owned world items, and that player must belong to the receiving plot.
Unowned claimable ingredients overlapping the zone feed the plot's Muncher.
Unclaimable and frozen-until-pickup items are preserved. Smoothies, forged
attributes and arbitrary parts cannot enter either ingredient intake path.

Intake commits under the existing Tycoon session transaction without yielding.
Authoritative removal precedes progress; repeated contact with a removed item
cannot count again. A failed consumption never advances progress.
Blender, throwing, stash and ingredient lifetime implementations are unchanged.

## Payout and presentation

`CustomerService.CalculateOrderPayout` and the legacy `CalculatePayout` obtain the
bonus solely from `MuncherService.GetCashMultiplier`. It multiplies the final
cash chain alongside payout upgrades and DoubleCash, before rounding. Grading,
ingredient subtotals, stash values, costs and unrelated cash grants are unchanged.

`Components/Muncher` binds existing PlayerPlot tags and discovers direct fixtures
by name. `MuncherPresentation` creates a compact 176x80 Fredoka BillboardGui at
DisplayOrigin, shifted upward 0.65 studs (MaxDistance 36, AlwaysOnTop false).
Its 156x20 charcoal pill track has a green rounded fill, dark outer outline and
white rim; outlined title and count sit close above and below the meter.
Changed progress tweens over 0.2 seconds, clamped to [0, 1]. Accepted ingredients
immediately update the count and trigger a 15% count punch plus 2.5% bar bump.
Feeds show YUM! for 0.55 seconds, refreshed by each accepted feed. Completion
holds gold FULL! for 0.85 seconds with an 18% count punch and 7% bar bump,
while the new target updates immediately. The pre-feed snapshot detects completion
even when the new target matches the previous one; rewards/reset logic are untouched.
Each animation cancels its predecessor, scale pulses restart at 1 and reverse,
and idle polling does not restart tweens or clear temporary titles. FULL! takes
priority over normal feed titles during its hold; a newer completion refreshes it.
Version-guarded title callbacks cannot clear newer states, including after release
or destruction; release/destruction cancel active tweens.
The component also creates an independent, noncolliding
ingredient copy that travels to MouthOrigin for 0.18 seconds. This visual is never
registered as inventory and its completion has no gameplay effect. Missing
fixtures warn once per plot; missing artwork/UI/feedback does not prevent unrelated
gameplay. Late fixtures are discovered automatically.

**The entirety of `Visual`, including the pot, is the Muncher artwork. No code
independently manipulates `Visual.Potted Plant` or any other Visual descendant.**
FeedSfxOrigin remains available for future audio and is unused in V1.

## Studio setup and smoke checks

Keep the supplied direct hierarchy beneath each plot:

```text
Plot
  Muncher
    InputZone       (BasePart)
    MouthOrigin     (BasePart or Attachment)
    DisplayOrigin   (BasePart or Attachment)
    FeedSfxOrigin
    Visual          (all artwork, including pot)
```

Attachments must be parented appropriately in Studio; if using nested attachments,
put the named BasePart marker directly under Muncher instead. InputZone is made
anchored, invisible, noncolliding and queryable by the component. Place/size it
where throws should be accepted. No Muncher-specific tags or authored animations
are required. Plot tags use existing bootstrap discovery.

In Studio, verify no Muncher Feed prompt appears, carrying/throwing multipart items
through InputZone, UI readability/face clearance, mouth travel and collision
behavior. Check single and rapid feeds, fill settling, count/bar pulses, FULL! and
the fresh target (including consecutive identical targets). Confirm smoothie
rejection, all three goal rewards, weaker/stronger
replacement, expiration, shared team payouts, death, leaving, plot reassignment,
missing markers and interrupted cosmetic feedback. CLI mocks cannot validate
Roblox contact physics, network behavior or visual appearance.

## Automated validation

Run `python tests/run_state_tests.py --luau <luau.exe> --suite muncher` for real
inventory/ingredient/session/customer integration. This includes exact goal
completion, equal ingredient progress, duplicate/fake/stale rejection, expiration,
replacement, real boosted customer serving, grade/upgrade/entitlement composition,
unmodified costs/grants, team membership and plot reassignment.

Run `--suite muncher-presentation` separately for immediate counts, animated fill,
rapid-feed settling, scale recovery, completion/new targets, release/destruction,
physical-intake feedback, prompt removal, missing/late fixtures, nonblocking
intake and preservation of the full Visual artwork. The presentation polish pass
passes this suite, `muncher` and `throw-blender`, plus focused Roblox-aware
typecheck for both changed components, StyLua and Rojo build. Studio appearance,
contact physics and replicated tween smoothness remain manual smoke checks.
Existing `throw-blender`, `carry-selection` and `stash-integration` regressions pass.
StyLua and Rojo build pass. Full Roblox-aware typecheck has no added diagnostics;
existing CustomerRequests, CombatService, JackedNoobService and CustomerService
diagnostics also reproduce on unchanged HEAD. Existing `customer-payout` and
`customer-payout-serve` suites fail on unchanged HEAD with outdated expected
ingredient values. `plot-session-races` also fails on unchanged HEAD at
"purchase remains committed". These unrelated assertions and production systems
were not changed here.
