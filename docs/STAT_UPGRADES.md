# Movement stat upgrades

Implemented from the final 2026-10-23 handoff. `src/shared/Constants/Upgrades.luau`
is the sole catalog source: speed has 15 purchases from 26 to 41, stamina has 14
from 60 to 130. Purchased step 0 is the free base at array index 1; purchased
step N is array index N+1. Jump, Bat, Carry, Payout and SprintConfig are unchanged
by this pass. Existing concurrent economy changes are preserved.

TycoonService already validates and charges the next catalog row and publishes
`<Track>PurchasedLevel` as array index minus one. MovementService already applies
catalog Values. Both Studio override entry points now derive their allowed step
range from the selected catalog rather than assuming 0-3. Their APIs are unchanged.

UpgradeDisplay binds only the purchased step. For stat cards, CurrentValue is
`SPEED <Value>` / `STAMINA <Value>`, NextValue is the next increment, and
PurchasePrice is the next cost in whole dollars. Existing authored labels are
retained; there are no three-level pip/segment elements in the inspected export.
MAX retains the purchased headline, clears cost, and disables buying. Capability
cards and tutorial Jump/Bat purchase arrows retain their existing behavior.

## Persistence audit

At implementation, `rg -n 'DataStore|SetAsync|UpdateAsync' src/server` found only
the PlayerDataService TODO stating that no DataStore writes exist. Cash and
upgrades remain session-only. No migration, legacy-value catalog, or migration
tests were introduced. Future persistence should start with the new catalog and
a versioned save format. If actually persisted old-format saves are introduced,
escalate the value-based round-up translation to Collin before changing them.

For historical reference only, the former speed catalog had values 26/32/37/41
and costs 0/20,000/125,000/400,000; stamina had values 60/80/100/130 and costs
0/15,000/100,000/300,000. An old array index 4 meant maximum; these were never saved.

## Automated validation

- `upgrade-sync`: catalog depth, base/max, increments, increasing costs and
  approved totals; real GameplayService/TycoonService purchases across every row,
  exact deductions and MAX rejection; mid-table application; catalog-derived
  Studio bounds without changing ownership; final sprint exhaustion at 6.5s.
- Standalone upgrade UI: all rows, supplied next-price examples, effective-stat
  changes while sprinting, MAX, capability presentation, delayed replication,
  replacement UI, affordability badges and tutorial arrows. Runs with UI present
  before Init and with UI imported later.
- `tutorial-gameplay`: real stash -> throw -> blend -> dispense -> serve starter flow,
  tutorial payout floors and first regular serves. The first tutorial serve alone
  must fund both initial movement purchases. `tutorial-payout-serve` separately
  retains the floor-specific contracts.
- Roblox-aware typecheck of the five changed runtime modules, StyLua on all
  touched Luau files, Rojo 7.7 build and whitespace checks pass.

Commands (use installed Luau tool paths):

```powershell
python tests/run_state_tests.py --luau <luau.exe> --suite upgrade-sync --suite tutorial-gameplay --suite tutorial-payout-serve
python tests/run_upgrade_ui_tests.py --luau <luau.exe>
```

The current deterministic serving run credited Red $10,000, Cold $20,000 and
Yellow $7,813 ($37,813 cumulative), followed by two regular wildcard serves at
$250 each. The first serve covers the combined $3,500 first stat purchases.
These are executions of the live server modules with fake Roblox boundaries,
not an engine playtest or a claim about every random regular order.

Before editing, the old upgrade-sync test failed on a stale Jump next-price
literal. That expectation now uses the catalog. The standalone sprint suite also
failed on the pre-change snapshot because its player fixture lacks a name for
StandIdentity; it was isolated and left unchanged. New stat application and
6.5-second timing coverage runs independently in upgrade-sync. Unrelated legacy
movement suites were not used as prerequisites.

## Studio acceptance still required

No new authored instances, attributes, assets or Studio setup are required.
Sync with Rojo and restart Play. No live Studio session was available for this
pass, so final playtest sign-off remains pending:

1. Run the actual starter sequence and first regular serves. Confirm the first
   speed/stamina purchases are accessible within the first few serves under the
   live payout system. Observe time to Carry 5 when movement purchases compete
   for cash; adjust prices only through the combined balancing playtest.
2. Buy through each stat track to MAX. Confirm gradual movement/stamina gains,
   final normal speed 41, and approximately 6.5 seconds of sprint at full stamina.
3. Inspect the rendered cards at supported viewport sizes, including STAMINA 130
   and full-dollar next prices. Confirm Jump/Bat rows and their tutorial arrows.
4. Browse while sprinting and while an effective movement modifier is active.
   Purchased headlines, next increments and prices must remain identical to idle.
   Lucky StarPower now preserves sprint stamina during drain ticks; it does not
   change purchased movement projections or the Studio override seam.
5. Confirm MAX hides the price, disables buying and cannot spend cash again.

Existing server Command Bar setters remain available through DevContentService:
`SetMovementSpeedLevel(player, step)`, `SetSprintStaminaLevel(player, step)` and
`ResetMovement(player)`. Overrides are effective state only and intentionally do
not change the shop's purchased headline or unlock purchases.
