# Codex pass: Tutorial V2 and guaranteed customer sequence

Implement on branch feature/tutorial-v2 only. Do not merge. Audit current code and tests before modifying. Preserve unrelated local and repo work. No Studio-only testing instructions in code changes.

## Requirements
1. Preserve the existing tutorial's first customer order/blend/turbine/dispense/serve path, but make customer #1 a simple RED request, satisfiable by three red ingredients in Locked Slot 1. Coordinate the slot contents contract with the separate starter-stash branch; do not implement starter-stash seeding here.
2. On the first successful tutorial serve, guarantee a total payout of at least $30,000 (not an unconditional extra $30k on top). Award once only; guard duplicate remote calls/reconnects and respect persistent completion. Verify actual Jump 1 + Bat 1 costs are affordable with $30k; report discrepancy rather than silently changing economy.
3. Replace the two separate upgrade steps with one combined hint: open UPGRADES and buy JUMP 1 and BAT 1. These are recommendations, NOT mandatory gates. Never block market guidance or completion on buying them. If user purchases one or both, hint should update/retire naturally.
4. Preserve Market introduction and jump-higher-for-better-ingredients guidance. Tutorial ends after first customer plus brief nonblocking guidance, not after customer #3.
5. Keep three guaranteed introductory customer positions in the existing customer queue/sequence: #1 simple red; #2 easy standard customer with normal payout; #3 CaseOh, the creator-themed special customer (NOT queso/cheese). Resolve the existing canonical CaseOh customer identifier and art/data; don't invent an ID or rename. Only #1 has payout floor. Keep regular customer selection after #3.
6. Polish tutorial hints with highlighted keywords (RED, UPGRADES, JUMP, BAT, MARKET), using existing rich-text/formatting and escaping where needed. Improve mobile hint position/readability using existing responsive layout, safe areas, hotbar and touch controls; don't alter other Framewisp panel behavior.
7. Preserve tutorial persistence, teammate/shared cash semantics, replay safety, and returning-player flow. Do not reset completed tutorials.

## Acceptance
- Fresh solo and two-player new sessions: first customer red, first serve pays >= $30k exactly once, both upgrades offered but optional; market guidance appears and tutorial completes.
- #2 easy regular, #3 CaseOh, normal computed payouts for both; #4 onward normal pool.
- Returning player never gets duplicate reward; purchase states don't deadlock.
- Desktop/mobile/console hints remain legible and don't obscure interaction controls.
- Add focused tests; run available test suites, StyLua, typecheck, Rojo build. Report pass/fail and pre-existing baselines. Do not merge or publish.
