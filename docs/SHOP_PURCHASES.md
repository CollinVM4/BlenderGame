# Shop purchases

The authoritative source for this pass is the local `newestExport11426.rbxmx`.
Run `python tools/prepare_framewisp_ui.py` before Rojo sync/build. It reads that
file by default and generates the existing Rojo-mapped prepared UI asset without
changing the source export. No HotbarController or HotbarGui changes are needed.

The verified panel path is `Be a Blender! Desktop/Shop/ShopScroll/ShopList`.
The cards and authored purchase controls are:

- `Angel Wings/Angel WingsContent/Buy`, with `BuyLabel` and sibling
  `Robux/RobuxCost` authored as “BUY” and “299”.
- `Ice Gun/Ice GunContent/Buy`, with `BuyLabel` and sibling `Robux/RobuxCost`
  authored as “BUY” and “75”. The authored display is not a live price claim.
- `2x Cash/2x CashContent/Buy10` and sibling `Robux10/RobuxCost`, authored as
  “BUY” and “19”, alongside `10-MINUTES`.
- `2x Cash/2x CashContent/Buy30` and sibling `Robux30/RobuxCost`, authored as
  “BUY” and “29”, alongside `30-MINUTES`.

There are no authored Owned, Equip, or remaining-time elements. Shop adapters
only set Buy.Active and Buy.Selectable. They never write text or create labels.
The existing Ice Gun pedestal still provides equip interaction. Prices are
queried with a 30-second cache only for sale availability; managed Dashboard
pricing remains authoritative at purchase time.

`CashBoostRequest` only prompts Developer Product purchases. Product 3728323243
grants 600 seconds and product 3728323462 grants 1800 seconds, exclusively through
the single ProcessReceipt callback in CashBoostService. Failed grants, absent
players and unknown products return NotProcessedYet. Successful PurchaseIds are
remembered by player UserId for this server session and acknowledged on retries
without extending time twice.

PlayerDataService owns DoubleCashExpiresAt and the getters IsDoubleCashActive
and GetDoubleCashRemainingSeconds. Purchases extend `max(now, expiry)` by the
duration. Customer payouts use the active timer and preserve `max(shop, lucky)`;
repeat purchases never multiply the 2x factor. The compatibility entitlement
boolean remains true after expiry, but does not determine payout activity.

Boost time is session-only: leaving/rejoining loses it, as does a server restart.
Receipt history also does not survive a server restart. Persistence is deferred
to the separate DataStore pass.

The only Presentation.Create caller found passing math.huge was
IceGunDisplayController. Its argument now uses IceGunConfig.MaximumCameraDistance
(128), and the ignored Width/Height fields are removed. Presentation defaults
remain 8.4 by 1.7 studs. Neither the shared billboard guard nor pedestal text changed.

Validation uses the actual source/prepared export tree for Shop text preservation,
sale caching, button intents and ownership changes. State tests cover receipts,
stacking, retry, expiry and session loss; customer payout and Serve tests cover
the timer and Lucky max rule. The Ice Gun presentation suite executes the actual
renderer and checks enabled state, distance, size and existing pedestal text.

Validation results for this pass: cash-boost, customer-payout, customer-payout-serve,
Shop adapters against both exports, Ice Gun presentation, changed-file StyLua,
Rojo build and diff whitespace checks pass. Full-source Roblox-aware typechecking
has the same 212 normalized diagnostics as isolated HEAD code, with no additions.
Both code trees use the corrected local export for this comparison.

The customer-compatibility suite fails before payout setup because its player
fixture has no name for StandIdentity. The hotbar regression suite reaches
“new mounted export preserves existing upgrade and cash bindings” and fails;
the preparation suite passes 16 of 17 checks, failing its old expectation of
18 hotbar labels (the corrected export yields zero matching that test's names).
All three failures reproduce with baseline code and the same local export.
They remain isolated from the passing Shop/gameplay checks; no unrelated
implementation was changed. Studio/live acceptance below has not been run.

Studio and live acceptance still require actual purchase prompts and receipts:

- Open Shop and verify authored text stays unchanged through refresh and ownership
  changes. Already owned Wings disable Buy; test automatic Wings grants with the
  live owner account, not a Studio entitlement simulator.
- Buy Ice Gun with a non-owner account and verify pass 2022020489, ownership,
  disabled Buy and pedestal equip. No separate Shop Equip control was authored.
- Buy each cash product, verify its exact product id and duration, repeat while
  active to extend the same timer, and verify customer payouts return to normal
  after expiry while Lucky continues to use the max rule.
- Walk to the Ice Gun pedestal: Output must show no billboard validation error,
  and the enabled billboard must have MaxDistance 128 and size 8.4 by 1.7 studs.
- Verify the new authored hotbar sizes, Bat/Ice/ingredient/smoothie ordering and
  bottom docking on device. No hotbar implementation was changed in this pass.
