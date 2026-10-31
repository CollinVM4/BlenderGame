# Lucky Block world presentation

LuckyBlockSequence retains its five-beat TickTimes and reveal/hold/fade timing. LuckyBlockView renders private local Workspace clones at the server-provided Position, sanitizes imported geometry through the LuckyBlockVisual wrapper/shared LuckyBlockRewardVisual, and preserves existing silhouette, pop, scale, sound, fade and cleanup behavior. Nearby observers see the final reveal only. Client death/reset/leave cleanup affects presentation, never the server's pending public pickup.

LuckyBlockPresentation.Rewards maps seven server IDs to Visual and Name. CashBoost uses 2xCash, StarPower uses Star, MegaBat and Invincibility retain their existing assets. PantryPack, TopShelf and MysteryBox use identically named authored models. No old reward key or RainbowRampage alias is retained. Controllers perform data-driven lookups; their production code required no changes.

Missing/malformed art is handled by the existing warning/text-only path. No reward model geometry is generated. Keep the existing imported assets in ReplicatedStorage.LuckyBlockVisuals; Rojo preserves unknown instances there. Those authored prize models are unavailable in this repository. See [asset limitations and server reward behavior](LUCKY_BLOCKS.md).

The output-only LuckyBlockPickedUp and LuckyBlockRevealed payload contract is unchanged. DurationSeconds describes the prize duration; the authoritative expiry starts only when a living player collects the later public pickup. The server computes its spawn deadline from RevealSeconds + HoldSeconds + FadeSeconds. Its separate replicated world billboard uses WorldBillboardStyle with LabelMaxDistance 60.

Presentation tests remain separate: lucky-block-roulette owns sequence timing, lucky-block-view owns renderer/sanitizer/asset fallback, and lucky-block-controller owns notification identity and client cleanup. Test fixtures now use the seven current reward IDs. See [validation](LUCKY_BLOCK_VALIDATION.md).

## Persistent prize handoff and claim HUD

Roulette fade removes only its transient label/light when a real PickupId is present. Its settled colored prize survives sequence end, roller death or leave until the public pickup's art (or terminal state) arrives. Shared preparation/pose keeps authored scale and orientation consistent. LuckyBlockPickupHandoff prevents partially replicated public art from overlapping the local prize, then switches ownership in one render update. The server still activates collection after RevealSeconds + HoldSeconds + FadeSeconds and awards independently of all client presentation.

Public collectibles use authored reward visuals, with no LuckyBlockWorld animation tag. A Terrain Attachment supplies the finite-distance label even when art is absent. Missing art never substitutes a block or generated geometry. Successful claim/expiry removes art and label; failed claim restores the same reward until its original expiry.

LuckyBlockHudController rebuilds a personal stack from server expiry/instant-confirmation attributes. DialogueTextStyle supplies Fredoka/white/thick outline; entries sit below banners in central safe HUD space. Countdown rendering reads server time rather than starting a receipt-duration clock. See [the presentation update report](LUCKY_BLOCK_PRESENTATION_UPDATE.md).
