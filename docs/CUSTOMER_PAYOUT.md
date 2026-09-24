# Customer payout and feedback

Request `BasePayout` values remain in authored units. Awards apply the economy's
20x cash scale once, then A-grade 1.5x, the highest qualifying rarity, the player's
Payout upgrade, and Double Cash. Missed requests use all consumed ingredients to
find rarity, apply 15% of that unrounded A-grade value, and display D. Only the
final amount is rounded, using nearest-integer rounding.

Successful requests consider only ingredients matching a requested tag (including
case-insensitive tag groups) or required ingredient slot/alternative. Exact recipes
receive one maximum rarity multiplier, not a product of ingredient multipliers.
The server reads the consumed cup and assigned request; the existing customer lock,
cup consumption, and queue removal remain in place.

At starting Payout without Double Cash, a base-25 Blue request pays $750 with
Blueberry, $1,313 with Fish, and $197 when missed with Noob. Other ingredients in
these examples are common Banana fillers.

The separate `CustomerResult` billboard shows grade, actual awarded cash with
commas, and rarity. D also says `TRY AGAIN`. It shares the order's head anchor and
view distance, starts disabled, and is enabled locally only for the owner. A
size-relative screen offset places it above the existing dialogue/name bubble;
the result expires after two seconds. Dialogue and cosmetic reactions remain
independent. The offset follows Roblox's documented
[BillboardGui SizeOffset semantics](https://create.roblox.com/docs/reference/engine/classes/BillboardGui#SizeOffset).

## Changed files

- `src/shared/Constants/Economy.luau`: cash scale, consolation fraction, rarity multipliers.
- `src/shared/Constants/Upgrades.luau`: existing costs scaled 20x; Payout tiers 1, 1.3/$3,000, 1.7/$9,000.
- `src/server/Services/CustomerService.luau`: authoritative order payout and result creation; compatibility payout helper also uses the cash scale.
- `src/server/Services/CustomerPresentation.luau`: separate timed result graphic.
- `src/client/Controllers/CustomerOrderController.luau`: owner visibility for both order and result.
- `tests/customer_payout.spec.luau`: payout formulas, qualifying ingredients, exact Mystery recipe, upgrades, entitlement, rounding, and scaled costs.
- `tests/customer_payout_serve.spec.luau`: real serving transaction, authoritative ingredients despite forged tags, reentrant/replayed serve protection, awarded cash, independent reaction/dialogue, and result wiring.
- `tests/customer_result.spec.luau`: displayed values, comma formatting, separation, lifetime, ownership, and streamed/removal visibility.
- `tests/customer_queue.spec.luau`, `tests/customer_requests.spec.luau`, `tests/smoothie_roundtrip.spec.luau`: payout expectations and economy-related fixtures updated.
- `tests/fixtures/roblox.luau`: Vector2 support for result positioning.
- `tests/run_state_tests.py`: separate focused gameplay and presentation selectors; UTF-8 source bundling for display symbols.
- `tests/test_state_runner.py`: manifest expectations updated.
- `docs/CUSTOMER_PAYOUT.md`: this implementation and validation record.

The pre-existing working-tree edits to `src/shared/Constants/Ingredients.luau`
were preserved and used as the catalog source of truth.

## Validation

Run with the local Luau executable:

```text
python tests/run_state_tests.py --luau <luau.exe> --customer-payout-only
python tests/run_state_tests.py --luau <luau.exe> --customer-result-only
python tests/run_state_tests.py --luau <luau.exe> --customer-presentation-only
python tests/run_state_tests.py --luau <luau.exe> --request-validation-only
python tests/run_state_tests.py --luau <luau.exe> --customer-queue-only
python tests/run_state_tests.py --luau <luau.exe> --smoothie-only
python tests/run_upgrade_ui_tests.py --luau <luau.exe>
python -B tests/test_state_runner.py
```

Passing: payout state (40 assertions), payout serve integration (22 assertions),
result presentation (9 assertions), all four existing customer presentation suites,
customer compatibility, smoothie survivors, smoothie geometry, and all four
Python runner checks. Presentation runs separately from gameplay validation.

Roblox-aware Luau LSP analysis of all `src` with a fresh Rojo sourcemap: PASS
(existing deprecated `LoadCharacterAppearance` warning only). StyLua on every
changed/new Luau file, excluding the untouched user-edited ingredient catalog:
PASS. Rojo 7.7 build and `git diff --check`: PASS. Build and analysis artifacts
are in the system temporary directory (`payout.rbxlx`, `payout.sourcemap.json`,
`payout-typecheck.log`).

The following failures were reproduced before changes, with the user's catalog
edits retained. No unrelated production fixes were made:

| Suite | Existing failure |
|---|---|
| customer-validation | Ingredient request expected outcome differs from current catalog tags |
| requests | Special bypasses recent request and NPCOnly exclusion |
| customer-queue | Each customer publishes owner-visible order text (literal-text assertion) |
| smoothie-world | Capacity failure preserves dropped cup |
| smoothie | Capacity rejects extra smoothie |
| smoothie-roundtrip | Setup: take stored smoothie |
| upgrade UI | Jump from replicated level |

The first six were run on the untouched working tree before editing. Upgrade UI
was also checked in a temporary baseline copy with changed tracked files restored
from HEAD and the user's ingredient edits retained. Baseline/final focused logs
are saved as `payout-baseline-*.log` and `payout-final-*.log` in the temporary directory.

## Studio checks still needed

No new assets or manual Studio setup are required; sync with Rojo. No Studio
play session was run. Check with two clients that only the plot owner sees the
result, including streaming in/out; verify three-line legibility and separation
from dialogue at different zooms and NPC heights, and two-second cleanup. Serve
real blended cups for the three examples, an exact Mystery recipe, and upgraded/
Double Cash players. Confirm cash, independent reactions/dialogue, queue advancement,
and that rapid or repeated prompts cannot consume/pay the same cup twice.

## Take Order interaction

Customers receive their assigned request on spawn but keep the order bubble hidden
and silent until the owner uses the native **[E] Take Order** proximity prompt.
All three queue positions support taking orders. The server checks the current
plot owner, queue membership, distance, and one-time reveal state. Taking an order
never consumes the held cup, rerolls the request, or awards money. At the counter,
the separate Serve smoothie prompt becomes available after taking the order;
waiting customers retain their revealed dialogue when they advance.

`CustomerService.luau` owns the reveal state and prompt lifecycle;
`CustomerOrderController.luau` gates the bubble on ownership and reveal state.
The existing typewriter/audio path runs on reveal. Model destruction and plot
reset invalidate typing and destroy prompts. Serve results remain a separate,
owner-visible two-second graphic with the actual rounded payout.

Current validation: payout and serving suites, queue integration, request
integration/compatibility, customer presentation, result display, Python runner
contracts, Roblox-aware typecheck, StyLua on feature files, and Rojo build pass.
The customer-validation suite's ingredient-request expectation also fails in the
untouched pre-edit working-tree copy (`take-order-baseline-l1bepium` under the
system temporary directory). No unrelated gameplay changes were made to fix it.
Typecheck reports only the existing LoadCharacterAppearance deprecation warning.

Additional Studio checks: with two clients, take all three orders in any order;
confirm no arrival chirps, progressive reveal chirps, persistent owner-only text,
and no retrigger audio. Hold a completed cup while taking an order and verify it
remains held and cash is unchanged. Check the native E prompt switches to the
separate counter Serve interaction, including keyboard, gamepad, and touch.
Reset the plot during typing and check for stale prompts, text, or audio. No new
assets or manual setup are required. Studio engine checks were not run here.
