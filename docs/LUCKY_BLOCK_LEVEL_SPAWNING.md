# Lucky Block level spawning

Configured level order is Level0, Level1, Level2, Level3. SlotsPerLevel is 3/1/1/0; startup reserves five block slots. Claim pickups are separate and do not occupy marker slots.

Level0Sync enables a shared 180-240 second clock. The first retirement starts it; subsequent claims do not start/reset it. At expiry the service populates all empty Level0 slots, preserving unclaimed models, then the next retirement can start a new clock. External destruction/reparenting or marker removal retains the existing replenishment behavior and also uses this shared clock.

Level1 and Level2 keep independent randomized 180-240 second schedule callbacks. Level3 has no slot, callback or missing-marker warning. Every enabled level warns if valid markers are fewer than its configured slots. Failed marker/template population retries after five seconds.

Markers must be existing BaseParts tagged LuckyBlockSpawn. Either set Level to 0-3 or Level0-Level3, or group beneath a Level folder/model directly inside LuckyBlockSpawns. The container can be a Folder or Model. Invalid attributes/groups are skipped with a warning. Legacy unassigned markers default to Level0 with a warning. Selection uses unused markers in the slot's own level and avoids its previous marker when alternatives are available. No markers or fallback locations are created.

Block origins retain marker height/2 plus HeightOffset 3. Unchanged animation/poll/radius/cooldown settings are in LuckyBlockConfig. Authored marker counts are unavailable in this checkout; required counts are at least 3/1/1 for enabled levels.

The lucky-block state suite owns distribution, shared and independent clock contracts, retained stock, previous-marker avoidance and missing-marker recovery. See [validation](LUCKY_BLOCK_VALIDATION.md).
