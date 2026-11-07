# Codex pass: One-time preloaded starter stash

Implement on branch feature/starter-stash only. Do not merge. Inspect canonical ingredient IDs, stash slots, persistence and protection rules first.

## Requirements
- Seed a brand-new plot owner's stash ONCE for the player's initial game progression, not each join, plot claim, death, or server restart. Respect DataStore existing records and never overwrite a returning player's stash.
- Populate five slots using existing stash ingredient records and valid stack/capacity rules:
  * Locked Slot 1: three RED ingredients, suitable for tutorial customer #1's simple RED smoothie.
  * Locked Slot 2: three YELLOW ingredients.
  * Slot 3: three COLD/FROZEN ingredients.
  * Slot 4: three assorted VEGETABLE ingredients.
  * Slot 5: three MILK ingredients.
- Use canonical catalog IDs and actual trait/color classification; don't fabricate IDs or silently use invalid ingredients. If an exact category has insufficient distinct ingredients, allow duplicates where valid and report the selection.
- Preserve authored slot order and the two locked/protected slots; slots 3-5 retain existing stealing rules, and become stealable according to normal protection windows. Do not grant theft through locked slots.
- Seed through server-authoritative stash/data APIs, not client-only visuals. Must persist correctly and not be duplicated when teammates join. Do not re-seed if initial stash is emptied/stolen.
- Keep stash visibility to both players as intended; preserve plot owner/teammate shared-state model. Avoid overwriting a live session during late persistence restore.
- Do not change tutorial state machine, payout, customer sequencing, or prompt draw distance; another branch owns those.

## Acceptance
- Fresh new owner gets 5 correctly ordered slots, 3 ingredients each, with valid IDs and protected/unprotected behavior.
- Two fresh players joining separate plots each receive their own initial stash; teammate joining does not create a second stash.
- Theft from eligible slots behaves normally; lock slots protected.
- Rejoin, reset, plot reclaim, and datastore restore do not duplicate or refill stash; persisted emptied stash remains emptied.
- Focused tests + available suites, StyLua, typecheck, Rojo build; report results and baseline failures. Do not merge or publish.
