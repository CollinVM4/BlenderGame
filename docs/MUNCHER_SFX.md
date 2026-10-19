# Muncher SFX and result reels

The server compares the committed output's catalog base value with the input's
catalog base value. Higher is `Win`, lower is `Lose`, equal is `Push` (including
Rock returning Rock and equal-value jackpots). Ripeness never affects this label.
Reward pools, interpolation, odds, jackpot weights and settlement are unchanged.

`MuncherService.GetSnapshot` supplies `OutputId` and `ResultKind`. The component
publishes these with rarity/tier before phase and publishes `Sequence` last.
The client reads the result at final lock; no remote was added.

| Cue | Asset | Moment |
| --- | --- | --- |
| Insert | `106774791990073` | Observed conversion start at the mouth |
| Roll | `132738338678605` | Loop from reel creation until final lock |
| Win | `76556910414303` | Final lock for higher catalog value |
| Lose | `137571524170744` | Final lock for lower catalog value |
| ReelStop | Empty | Inert tick hook; Push has no fanfare |

All clips reuse GameplayAudioController templates: volume **0.7**, minimum
rolloff **10 studs**, maximum rolloff **50 studs**. Only Roll loops. Cleanup
destroys that loop on phase interruption, replacement sequence or view removal.
Already-locked late observations do not replay sounds. One-shots use the existing
independent spatial emitters so normal roll cleanup does not truncate the final cue.

Symbols prefer `ScrapbookArtwork.GetIngredient`; its current PNG map is empty,
so they use `IngredientViewport` and sanitized copies of the existing ingredient
prefabs in `Shared.ScrapbookPreviewAssets`. `ScrapbookPreviews` now also allows
Rock, Mushrooms, Protein, Pear, Honey, Crab, Coconut and Pizza, covering every
Muncher candidate. This also enables their established scrapbook previews.
No new art, thumbnail IDs or substitute geometry was introduced.

Each reel caches its tier's five candidates once, moves their containers while
spinning and shows only the predetermined output at lock. The existing rarity
palette outlines each reel. Win briefly tints symbols gold; Lose briefly dims
them; both ease back to white over 0.12 seconds. Push adds no accent.

The Front-face SurfaceGui stays at 100 PixelsPerStud. Fast spin ends at 0.957s;
reels stop at 1.254/1.4025/1.551s. FEED ME, busy feedback, throw-only feeding,
display mounting and geometry restoration retain their existing behavior.

Changed production files: `Constants/Muncher`, `Constants/ScrapbookPreviews`,
`MuncherRewards`, `MuncherService`, the `Muncher` component,
`GameplayAudioController`, and `MuncherEffects`. Regression coverage lives in
`muncher_rewards`, `muncher`, `muncher_presentation`, `gameplay_audio` and the
existing `scrapbook_ui` suite. The existing `muncher-vacuum` suite also passes.
Roblox-aware typecheck, StyLua and Rojo build pass.

## Studio and phone acceptance (pending)

No Studio runtime, listening session or physical-device verification was performed.

- Keep the authored `DisplayScreen` BasePart (Front face) and `MouthOrigin` marker.
- Ensure `ServerStorage.Ingredients` contains the canonical prefabs for every
  RewardPools entry; check startup for missing preview-prefab warnings.
- Ensure the experience can play all four supplied audio assets.
- Feed each tier: hear Insert once, Roll during spin, then the matching Win/Lose
  cue or a silent Push. Confirm all three symbols match the spawned ingredient.
- Observe the short gold/dim accents and the output rarity outlines. Orbit/zoom
  to confirm the screen remains fixed and icons stay legible.
- Interrupt during spin, including during busy feedback, and replace/remove the
  view: the loop must stop with no stale result cue and no leftover previews.
- On a phone, check symbol legibility and the 0.7 mix beside other gameplay audio.
