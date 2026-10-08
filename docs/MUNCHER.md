# Muncher purchase and buffs

Muncher remains the existing physical InputZone intake, ingredient registry /
inventory consumption, cosmetic mouth travel, feed audio path, Fredoka progress
BillboardGui, YUM! and FULL! feedback. No Feed ProximityPrompt or new gameplay
remote is introduced. Purchase and progress are session-only.

## Purchase and reveal

Touch the authored `Muncher.PurchasePoint1` BasePart to purchase for exactly
$100,000. The pad displays MUNCHER / $100K using the Farm purchase-signage convention:
a client-owned 340x64 BillboardGui in PlayerGui, with the pad itself as Adornee,
a two-stud StudsOffsetWorldSpace lift, AlwaysOnTop true, MaxDistance 28 and two
32-pixel Fredoka 24 rows (white title / gold price). No attachment is needed.
The label is stationary during the rise and follows the existing replicated
CanTouch / Transparency visibility policy; session reset re-enables the same GUI,
and removal/replacement of the pad cleans it up. `MuncherService.TryPurchase` verifies
the actor's current plot, the exact pad, character proximity/action eligibility,
and captured session membership. Owner or current teammate may purchase.

The existing `TycoonService.PurchasePersonalUpgrade` server cost/callback adapter
is reused: despite its historical name, it debits **session SharedCash** under
BeginTransaction, invokes a synchronous purchase commit, publishes both members'
cash and then releases the lifecycle lock. There is no second cash ledger or
purchase refactor. Insufficient funds return the existing `InsufficientCash`
reason and leave the pad and balance intact; the physical pad retains the same
silent unsuccessful-touch behavior as the farm/stash purchase pads.

The purchase commits once, hides/disables the pad and starts a 0.95-second,
six-stud Quad-Out rise. Studio positions are the resting positions.
`MuncherReveal` captures authored world transforms and applies one shared vertical
fraction on the server each Heartbeat. All nested artwork parts and gameplay
markers move together; PurchasePoint1 and its entire subtree stay fixed.
Part-backed attachments follow their parts; independent attachments are translated
as world markers. Artwork is anchored during controlled operation, with its
collision disabled underground / in motion and restored at rest. Binding cleanup
restores authored transforms and anchoring. Session release places the assembly
underground again and restores the purchase pad.

Only after the complete assembly reaches rest and the server deadline passes does
`CompleteReveal` enable intake. Both carried and world-item feed APIs reject
unbought / revealing Munchers without consuming anything. The component skips
world overlap intake while inactive and hides the progress display.

## Exactly 25 ingredients, one buff

Each successfully consumed valid ingredient contributes exactly +1. At 25,
existing FULL! feedback animates the green fill to completion, one equally likely
existing cash buff is selected, and progress resets to zero:

| Buff ID | Existing effect | Duration |
| --- | --- | --- |
| Cash125 | 1.25x customer cash payout | 300 seconds |
| Cash150 | 1.5x customer cash payout | 300 seconds |
| Cash200 | 2x customer cash payout | 300 seconds |

These are the complete existing Muncher buff pool; there were no Muncher movement
or farming effects to duplicate. CustomerService still obtains the multiplier
through the existing GetCashMultiplier API, without changing grades, ingredient
subtotals, other cash grants or purchase costs. Rewards remain scoped to the
plot session: teammates share them and departing members lose access.

A second batch can accumulate while a buff is active. At 25 it holds FULL until
the original server expiry; no multiplier replacement, stacking or deadline
extension occurs. Further ingredients are rejected and preserved. Expiry clears
the old effect; if a full batch is pending, exactly one new random buff starts for
300 seconds and progress resets. Server GetServerTimeNow is authoritative, checked
on every snapshot / payout lookup and while the component polls idle plots.

## Replication and presentation

The server projects `Purchased`, `Active`, `Progress`, `ActiveBuff` and
`BuffExpiresAt` attributes onto the authored Muncher. `GetSnapshot` retains
Multiplier and ExpiresAt compatibility fields and adds purchase / activation
state. The normal progress BillboardGui remains server-owned at DisplayOrigin.
Both track and green fill use their own UICorner with CornerRadius UDim.new(1, 0).
Rapid feed tweens cancel earlier fill/pulse work; guarded completion/title delays
cannot overwrite newer authoritative counts or released/destroyed displays.

MuncherPresentationController creates a compact Fredoka buff BillboardGui at
DisplayOrigin, above the normal meter (offset 2.35 versus 0.65 studs, MaxDistance
36). It renders the replicated buff name and a locally interpolated m:ss countdown
from the server expiry, including 5:00 and 0:01, and removes it at zero without
waiting for another server update. Gameplay duration stays entirely on the server.

The first access to an active Muncher in the player's current session shows:
`FEED MUNCHER to receive a temporary buff!`
It appears once per player/server session, including for teammates who join later.

Both Muncher and stash ripeness use `UI/TutorialTooltip`. A single CanvasGroup
fade includes background, lettering and the opaque DialogueOutline UIStroke that
previously outlived TextTransparency. Entrance is 0.18 seconds, exit starts at
4.3 seconds and lasts 0.45 seconds; completion destroys the whole GUI together.
The stash tutorial's rich text wording and hold/fade timing are preserved.

## Changed files

- src/shared/Constants/Muncher.luau
- src/server/Services/MuncherService.luau
- src/server/Components/Muncher.luau
- src/server/Components/MuncherPresentation.luau
- src/server/Components/MuncherReveal.luau (new)
- src/client/Controllers/MuncherPresentationController.luau (new)
- src/client/Controllers/RipenessPresentationController.luau
- src/client/UI/TutorialTooltip.luau (new)
- src/client/init.client.luau
- tests/muncher.spec.luau
- tests/muncher_presentation.spec.luau
- tests/run_state_tests.py (new module-source mappings only)
- docs/MUNCHER.md

Existing unrelated worktree edits were preserved.

## Validation and Studio setup

Keep the direct authored hierarchy under each tagged PlayerPlot:

```text
Muncher
  DisplayOrigin    (BasePart or Attachment)
  FeedSfxOrigin
  MouthOrigin      (BasePart or Attachment)
  Visual           (all authored artwork, including nested parts/models)
  InputZone        (BasePart)
  PurchasePoint1   (BasePart; touch pad at its authored accessible position)
```

No second authored position, extra tag or new remote is required. Part-backed
attachments keep their authored parenting. Do not weld purchase-pad geometry to
the moving artwork. The server makes the static fixture anchored and InputZone
invisible, noncolliding and queryable.

Focused suites: `python tests/run_state_tests.py --luau <luau.exe> --suite muncher
--suite muncher-presentation`. Gameplay verifies exact cost, insufficient cash,
foreign plot rejection, owner/team authority, duplicate purchase, locked/revealing
intake preservation, equal progress, exact threshold, all three effects and
300-second deadlines, expiry, full pending batches, preserved excess ingredients,
existing payouts and session reset. Presentation verifies rounded fill, rapid-feed
settling, feedback, multipart reveal / stationary pad / session release, countdown,
one-time tutorial and shared tooltip cleanup.

Validation: Muncher integration PASS (297 behavior checks, 17 setup checks), Muncher
presentation PASS (92 checks), focused Roblox-aware typecheck PASS, StyLua PASS,
and Rojo build PASS. Full src typecheck retains 203 pre-existing diagnostics,
identical to a pre-change copy that preserves the unrelated worktree edits.
`ripeness-presentation` fails on its pre-existing missing global Color3 fixture;
`throw-blender` fails on a pre-existing player double without DisplayName in
StandIdentity.DefaultName. Both reproduce with the unchanged Muncher/ripeness
implementation. Those unrelated fixtures and production systems were not changed.

Studio smoke remains necessary: two-client shared purchase contention, insufficient
cash touches, pad signage and location, multipart rise smoothness/collisions,
no intake during reveal, unchanged feed audio/vacuum/mouth feedback, capsule fill
at 1/25 and 25/25, pending FULL, readable countdown above the meter, both tutorial
fade-out outlines, leaving/rejoining and fresh plot reassignment. No Studio session
was run; CLI doubles do not prove engine physics, rendered layout or replication.


Purchase signage follow-up: the server-owned pad BillboardGui was replaced with
the Farm client convention described above; purchase logic, reveal, price and
buffs are unchanged. Muncher presentation and gameplay suites, focused typecheck,
StyLua and Rojo build pass. The unchanged HEAD Farm presentation suite also fails
its stale $1,000 expected price (FarmConfig currently sets row one to $20,000).
Repeated purchase/reset signage checks verify the same elevated GUI is reused,
with no duplicate purchase billboards; removing the pad disposes its GUI.
