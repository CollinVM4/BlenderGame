# Lucky Blocks: session rewards

LuckyBlockService owns weighted rolls, public claim pickups, spawn clocks and buffs in server memory. Rolling reveals a prize; collecting the later pickup awards it to that collector, who may differ from the roller. There is no client pickup endpoint or acknowledgment.

| Reward | Weight | Duration at claim | Effect |
|---|---:|---:|---|
| CashBoost | 15 | 90 seconds | 1.5x cash; max with shop DoubleCash, then existing Muncher factor |
| StarPower | 13 | 10 seconds | Reject player damage, bat stun/knockback and ice freeze; sprint without stamina drain |
| MegaBat | 17 | 15 seconds | Half swing cooldown, double slap launch; same tier and eligibility |
| Invincibility | 17 | 8 seconds | Reject player damage, bat stun/knockback and ice freeze |
| PantryPack | 20 | Instant | Three uniform ingredient draws from tiers 0 through collector's purchased Jump tier |
| TopShelf | 10 | Instant | One uniform draw at collector's purchased Jump tier |
| MysteryBox | 8 | Instant | One uniform draw across all tiers, excluding Player_Head and Dragon_Fruit |

Timed buffs use workspace:GetServerTimeNow(). Reclaiming replaces that buff's expiry with now plus its duration; different buffs coexist. Neither immunity changes fall damage, stealing or raid/slot/base protection. RemovePlayer clears buffs and both claim cooldowns, without removing world prizes.

## Roll and public pickup

TryClaim preserves the output-only LuckyBlockPickedUp and nearby LuckyBlockRevealed payloads: RewardId, optional DurationSeconds, Position, Character, PickedUpAt, PickupId, and observer UserId. Roller presentation and observer reveal still use the existing five-beat timeline, 0.78-second reveal, 1.7-second hold, 0.15-second fade, and 70-stud observer distance.

After firing those notifications, task.delay schedules the public pickup using the sum of those three presentation constants. Roller death/disconnection cannot cancel it. A tagged, non-geometric identity container replicates during the reveal; it is not yet claimable. At the unchanged server deadline, the server resolves LuckyBlockPresentation.Rewards[id].Visual from ReplicatedStorage.LuckyBlockVisuals and prepares authored art through shared LuckyBlockRewardVisual. Public art uses the exact normalized size, centered pivot and settled reveal pose as the client winner, anchored and stationary. Only unopened LuckyBlockWorld models bob and rotate.

The client retains the local colored prize through roulette fade/end/cancellation, while fading roulette-only lettering/light. LuckyBlockPickupHandoff hides partial public geometry/effects, waits for the matching PickupId and expected part count, removes the local prize, then exposes the public art in one render update. Claim/expiry state also releases the local prize if it arrives before art. There is no client acknowledgment. Claimed containers retain only terminal metadata until original expiry so late replication cannot resurrect a reveal; geometry and label are removed immediately on claim. Failed awards restore the same container, appearance and remaining lifetime.

A finite 60-stud WorldBillboardStyle reward-name label uses a Terrain Attachment for its world position. Missing/malformed authored prize models warn by mapped asset name and leave this readable label-only collectible; no Lucky Block, invisible part or substitute geometry is created. Position-based proximity preserves the same living/gameplay-lock/radius checks for both normal and label-only pickups.

Both lifecycle stages use living, unlocked characters within four studs, polled every 0.15 seconds. Their 0.75-second per-player cooldowns are separate. Pickups expire 60 seconds after server creation; expiry grants nothing. The first eligible collector claims atomically before world removal and award. No remote controls the prize, target, inventory or buff clock.

## Ingredient transaction and carry

Lucky draws all IDs before validation. InventoryService.PrepareIngredientReward validates gameplay state, carried-state initialization, Backpack, living Humanoid/root, every definition and every authored ingredient template. It builds all visuals before the pickup commits; Lucky does not depend on generated fallback geometry. Missing selected art leaves the prize available until its original expiry, without exclusions or capacity reservations.

The returned one-shot, synchronous transaction calls GrantIngredient(player, id, true). If any grant returns false or throws, it removes only newly added held records and restores the previous selection. Discovery notifications happen only after the entire batch succeeds; notification errors cannot reopen a committed reward. A failed award restores the same PickupId with its original expiry. There are no yielding calls in this grant path.

GrantIngredient's optional allowOverfill defaults to false and bypasses only its capacity check and the private equipVisual capacity check. Normal ingredient grants, world ingredients, stash withdrawals, world smoothies and GrantSmoothie retain their capacity gates. New ingredient records have Origin Unknown; Lucky never calls GrantSmoothie. Purchased carry capacity is unchanged.

The carry audit found native Backpack selection, ThrowHeld, overhead stacking, actual CarryCount publication, smoothie serving and storage already iterate/use the full held stack without carry-capacity truncation. Store checks stash-slot capacity. No custom hotbar, expiry, overfill UI or count clamp was added. The extra private equipVisual gate was the only overfill blocker changed.

## Personal claim feedback

After successful timed claims, the server writes LuckyBuff<RewardId>ExpiresAt on the actual claimer. Instant rewards write LuckyInstant<RewardId>Until for a brief 2.5-second confirmation. These are server-owned session attributes and do not authorize gameplay. No attributes are written on roll or failed award. Death does not clear them or the existing buffs; RemovePlayer clears the player's state.

LuckyBlockHudController reads only LocalPlayer attributes using workspace:GetServerTimeNow(). LuckyBlockMessages computes ceil(max(0, expiry-now)); expired rows disappear. Entries are keyed by reward ID, so refresh updates an existing row and different buffs stack. Instant confirmations show COLLECTED without a duration. Recreating PlayerGui/the ScreenGui rebuilds the current state from attributes.

The compact HUD uses shared DialogueTextStyle (FredokaOne, white, 2.5px dark outline) and a composited CanvasGroup entrance fade. It occupies the central 36% of CoreUISafeInsets space, below the tutorial/announcement banner and above the hotbar/mobile control region; row height responds to available viewport height. ResetOnSpawn is false. No hotbar or control logic changes.

## Authored assets and compatibility

Keep ServerStorage.LuckyBlockTemplates.LuckyBlock as an archivable Model with a PrimaryPart. Reward presentation reads ReplicatedStorage.LuckyBlockVisuals. CashBoost reuses 2xCash and StarPower reuses Star; MegaBat and Invincibility retain their visuals. PantryPack, TopShelf and MysteryBox expect models of those names. Missing reward art warns once per mapped name when spawned; the existing client renderer also warns once per missing asset, retaining safe text presentation. No geometry is invented.

The checkout's Rojo mappings preserve unknown authored assets but contain no reward models or authored Workspace spawn markers. The checked-in XML exports also contain no LuckyBlockVisuals, PantryPack, TopShelf, MysteryBox or LuckyBlockSpawns tree. The three prize models are therefore unverified/missing from repository sources: Collin asset tasks. Live authored marker counts cannot be reported from this checkout. Required counts are Level0 >= 3, Level1 >= 1, Level2 >= 1; Level3 is disabled.

There is no announced-only catalog flag/set. TODO(LuckyMysteryAnnouncedOnly) identifies that missing source of truth. AnnouncedIngredientSpawn is a marker tag, not a catalog eligibility set. The catalog's actual IDs are Player_Head and Dragon_Fruit; its pre-existing PlayerHead alias is also excluded defensively. No RainbowRampage compatibility alias was needed. The ordinary IngredientGeometry fallback was discovered locally and is deliberately not used by Lucky preparation.

See [presentation update validation](LUCKY_BLOCK_PRESENTATION_UPDATE.md), [spawn distribution](LUCKY_BLOCK_LEVEL_SPAWNING.md), [presentation](LUCKY_BLOCK_ROULETTE.md), and [implementation validation](LUCKY_BLOCK_VALIDATION.md). This pass adds no Studio testing tasks, persistence, products, tasks, hotbar, or protection changes.
