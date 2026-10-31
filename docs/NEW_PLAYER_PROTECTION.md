# Quiet, forfeitable new-player protection

Protection ends at the first tutorial completion, 480 elapsed eligible session
seconds, or successful PvP aggression. It never returns during that player
session. Rejoining creates fresh memory; eligibility follows the actual tutorial
stage. No persistence, saved-record mapping, remote, or client protection state
was added.

`ProtectionService` owns `TutorialComplete`, `TutorialPlaySeconds`, and
`ProtectionForfeited`. The clock is `os.clock()`, settled by one service-level
`RunService.Heartbeat` connection at one-second cadence, and synchronously before
queries, completion, and forfeiture. Each player has an accounting timestamp;
elapsed time is clamped at the named `PROTECTED_SESSION_LIMIT_SECONDS` constant.
Idle time and time across character deaths count. Completion/forfeiture stop
accumulation immediately. Queries cannot recreate removed/unknown players.

Existing players are initialized at service activation, preserving any published
`Complete` stage. In the local implementation, `TutorialService.AddPlayer`
publishes the initial stage synchronously; bootstrap calls it before protection
initialization for newly added players, before character/gameplay setup. There
is no delayed saved-tutorial readiness contract in this tree. This change does
not reset or otherwise modify TutorialService. PlayerRemoving removes protection
before potentially delayed plot cleanup; character removal does not reset it.

Changed runtime files:

- `src/server/Services/ProtectionService.luau`: memory, accounting, lifecycle.
- `src/server/Services/InventoryService.luau`: first hostile CanWithdraw gate
  after the existing friendly return; successful Withdraw forfeiture. Steal still
  routes through Withdraw. Tasks/stat/raid hooks remain intact.
- `src/server/Services/CombatService.luau`: central incoming player rejection,
  successful damage/stun forfeiture, delayed knockback protection recheck.
- `src/server/init.server.luau`: service registration, initialization, removal.

The local bat path applies stun/drop/ragdoll before damage. Its existing
`enemyRejection` calls the central rejection before those effects; successful
stun has a separate forfeiture hook. Delayed physics rechecks protection alongside
existing Lucky immunity. `DamagePlayer` now returns success only when health
actually decreases, rather than merely after attempting TakeDamage.
`IceGunProjectileService` already calls FreezeStatusService.Apply only after
DamagePlayer succeeds, and needs no edit. Repository search found no other
incoming player stun or knockback application path. Customer/JackedNoob impulses
target NPCs; fall damage calls TakeDamage independently and stays unchanged.

**PROPOSED/UNCONFIRMED: ice-triggered forfeiture** is implemented as requested,
pending Collin's design confirmation. Its trigger is the shared successful-damage
hook in CombatService.DamagePlayer (`forfeitProtection`); the ice integration
test explicitly labels this decision. Changing this policy requires reviewing
the shared damage API and ice damage/freeze flow, not just suppressing bat stun.

Protection is intentionally silent: a player who forfeits is not told they became
vulnerable; an attacker hitting a protected player gets no explanation. Only the
existing generic stash `PROTECTED!` result reaches the taker through
InteractStash. Silence was checked by feature diff review and automated checks
for that exact stash result and absent replicated bookkeeping. No UI/client,
TutorialHintText, fall-damage, world-pickup, or NPC production file was edited.
No Studio setup is required. Runtime validation used CLI engine doubles; no
live Roblox physics/network validation was performed.

## Validation (October 30, 2026)

Tools were already available outside the repository. Exact PowerShell arguments:

```powershell
$v = 'C:/Users/Collin Van Meter/AppData/Local/Temp/BlenderGame-lucky-block-validation-20261030-1541a6c'
$a = Join-Path $env:TEMP 'BlenderGame-protection-validation'
$rojo = 'C:/Users/Collin Van Meter/.aftman/tool-storage/rojo-rbx/rojo/7.7.0/rojo.exe'
$source = @('src/server/Services/ProtectionService.luau', 'src/server/Services/CombatService.luau', 'src/server/Services/InventoryService.luau', 'src/server/init.server.luau')
$specs = @('tests/protection.spec.luau', 'tests/protection_gameplay.spec.luau', 'tests/protection_ice.spec.luau')
python tests/run_state_tests.py --luau "$v/luau/luau.exe" --suite protection --suite protection-gameplay --suite protection-ice
python tests/run_state_tests.py --luau "$v/luau/luau.exe" --suite protection --suite protection-gameplay --suite protection-ice --suite tutorial-gameplay --suite customer-bat --suite combat --suite combat-launch --suite freeze-bat --suite icegun-combat --suite icegun-simulated-combat --suite stash --suite stash-integration --suite smoothie --suite bad-customer-stash --suite fall-damage --suite lucky-combat --suite lucky-inventory
python tests/run_state_tests.py --luau "$v/luau/luau.exe"
& "$v/stylua/stylua.exe" @source @specs
& "$v/stylua/stylua.exe" --check @source @specs
& $rojo sourcemap --output "$a/sourcemap.json"
& "$v/lsp/luau-lsp.exe" analyze --platform roblox --sourcemap "$a/sourcemap.json" --definitions "$v/roblox.d.luau" @source
& $rojo build -o "$a/protection.rbxlx"
git diff --check
```

- Protection specs: **3/3 pass**, 67 behavioral assertions, 19 setup validations.
  State is separate from stash/bat and ice integration. The runner registers all
  three in `tests/run_state_tests.py`.
- Focused selection: **16/17 pass**, exit 1. `smoothie` fails its existing extra-capacity
  assertion, which reproduces in the saved incoming tree. An earlier `stash`
  missing-Tasks-fixture-method failure was fixed by concurrent local work; its
  final focused/full runs pass.
- Full manifest: **105/137 pass**, exit 1; state 19/25, integration 52/68,
  presentation 34/44. Presentation failures did not block gameplay suites.
- Incoming baseline was copied before editing. Its aggregate command initially
  stopped on missing Tasks specs. Running every manifest entry separately with
  `python "$a/run_all.py"` yielded **97/134 pass** for that snapshot and
  **104/137 pass** for the then-current working tree, with **no passing-to-failing regression**.
  Four Tasks specs were added/fixed by concurrent local work during this task;
  their improvement and the later stash fixture fix are not attributed to protection.
  The final full run improved to 105/137; all 32 failures are incoming failures. One interim Tasks theft
  failure during that activity passed on repeated focused runs and the final
  full run, including a comparison using the incoming inventory/combat modules.
- Roblox-aware typecheck exits 1 with the **same 40 diagnostics as incoming**,
  with no added diagnostics: CombatService 9, CustomerRequests 22,
  JackedNoobService 8, CustomerService 1. ProtectionService has none.
  `python "$a/typecheck.py"` performed the before/after comparison with absolute
  source maps and normalized diagnostic locations. Runtime specs are checked
  through the generated CLI bundles, not standalone Roblox type environments.
- StyLua format/check, Rojo build, and `git diff --check`: **pass** (Git emits
  existing LF/CRLF conversion warnings).

The 32 retained full-manifest failures all also fail in the incoming snapshot:
`tutorial-hints`, `tutorial-claim`, `muncher-vacuum`, `ingredient-cleanup`,
`ripeness`, `ripeness-presentation`, `ripeness-lifecycle`, `discovery-customers`,
`jacked-noob-hit-presentation`, `plot-session-races`, `plot-session-progression`,
`plot-session-requests`, `plot-session`, `smoothie-world`, `smoothie`,
`customer-queue`, `customer-serve-anywhere`, `customer-validation`,
`customer-compatibility`, `sprint`, `legacy-state`, `legacy-movement`, `requests`,
`world`, `smoothie-roundtrip`, `bat-controller`, `ingredient-hold`, `vfx`,
`customer-order-text`, `customer-orders`, `blend-presentation`,
`icegun-presentation`. No unrelated production fixes were made.

Raw outputs and comparison scripts are in `$a`: `focused.txt`, `final-full.txt`,
`baseline-full.txt`, `baseline-independent.txt`, `final-independent.txt`,
`baseline-results.json`, `final-results.json`, `baseline-typecheck.txt`,
`final-typecheck.txt`, and `tasks-steal-without-protection.txt`.
