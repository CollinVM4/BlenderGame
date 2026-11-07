# 2× Faster Farm

Pass ID: `2075211794`. Creator Hub base price: **29 Robux**, configured by the owner.
Description: **All farm rows on your current plot grow twice as fast. Your teammate gets the boost too.**

FarmService resolves the optional authored BasePart at
`Workspace.Plots.<Plot>.Farm.FarmSpeedRobux`, independently of row validation.
Keep `Sign` and `shine` parented to the pad. The service preserves authored
appearance and supplies a default Roblox proximity prompt, **Buy Farm Boost**.
Sign TextLabels read **2× FASTER FARM**. There is no scripted price label;
Roblox's modal supplies the actual localized price. No touch purchase is bound.
Missing or malformed pads do not disable farming.

Sales are hidden until Row 1 is unlocked (`FarmRows >= 2`) and every current
member has confirmed nonownership. Unknown ownership retries after 15 seconds.
One holder grants 2× growth to all unlocked rows; two holders still grant 2×.
Changing membership or entitlement rescales remaining growth time while preserving
completed work. Ready crops and harvest yield are unchanged. Session and generation
guards reject obsolete completions. Ownership comes from Roblox, with no added
datastore. A matching server purchase-finished event immediately confirms a purchase.

## Validation

Run `tests/run_state_tests.py --luau .validation-tools/luau.exe --suite farm --suite farm-boost`.
The shared fixture uses real farm, inventory and Tycoon session services with mocked
Marketplace, geometry and clocks. `farm` remains the home for ordinary farming;
`farm-boost` owns pass eligibility, cancellation/errors, ownership outages/retries,
mid-grow scaling, team/reclaim/reassignment and stale callback contracts.

Focused farm, farm-boost and Wings ownership suites pass. Changed-file StyLua and
Rojo build pass. Full-source Roblox-aware typecheck reports 212 existing error
headers, matching an isolated HEAD archive; no errors occur in changed modules.

## Studio and published-experience checks

Verify the authored pad/sign/shine render and fully hide on every plot; test the
default prompt on keyboard, touch and controller. With two clients, unlock Row 1
as the teammate, cancel once, then purchase while a crop is growing. Confirm
both members' later rows run at 2×, two holders do not stack, the sole holder's
departure preserves progress at 1×, and reset/reclaim cannot duplicate harvests.
Verify existing ownership on rejoin in a published test experience. CLI fixtures
cannot establish engine replication, real Marketplace billing, or rendered effects.

The owner will configure the 29 Robux base price and description in Creator Hub;
these external settings were not changed from this workspace.

References: [passes](https://create.roblox.com/docs/production/monetization/passes),
[regional pricing](https://create.roblox.com/docs/production/monetization/regional-pricing),
[MarketplaceService](https://create.roblox.com/docs/reference/engine/classes/MarketplaceService).
