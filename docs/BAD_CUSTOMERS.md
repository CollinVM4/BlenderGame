# Bad customers: Bat-only encounters

Bad NPC encounters require purchased Bat Level 1 or higher in the current plot
session. `TycoonService.HasBat(player)` derives this from current assigned members
and `GetUpgrade(member, "Bat") >= 2` (tier 1 is displayed Level 0). `HasBat` and
`BadNPCEnabled` plot attributes are projections, never authorization inputs.
Purchases and membership publication recompute them. Equipped tools, character
death and respawn do not affect eligibility.

Bat purchases currently belong to `SharedUpgrades`: either assigned member can
purchase, and both receive that purchased tier. Leaving or promoting an owner
preserves the surviving session purchase; the final departure closes that session
and a new claimant starts at Level 0. No personal ownership ledger was introduced.

## Spawning and action retirement

Bad candidate selection (including Studio injection) is gated by authoritative
eligibility. The existing special chance, weights, cooldown, queue capacity,
tutorial gating and normal spawn intervals remain unchanged. Purchase publication
does not create an arrival.

CustomerService removes the authored `RejectButton` assembly on plot activation.
Its floor display/binding implementation is retired; the old helper module retains
only the support query needed by LockBase. There was no dedicated client REJECT
binding to remove. GameplayRequest explicitly drops `Reject` and `RejectCustomer`.
Legacy `RejectFront`, `RejectCustomer`, `DismissCustomer` and `ResolveRejectTarget`
service APIs are inert for compatibility. Legitimate customers cannot be dismissed.

## Combat and custody

CombatService retains server-issued equipped Tool identity, purchased tier,
alive/stun checks, impact timing, overlap, distance, facing and line of sight.
CustomerService additionally requires the attacker to belong to the exact target
session and have an authorized equipped Bat before calling its private rejection
pipeline. Either assigned member can defend; foreign plot members cannot reject
bad customers. Normal NPC combat retains its temporary ragdoll/recovery behavior.

Rejection exclusively claims the hit record before cancelling movement, timers
and interactions, releasing queue occupancy, or publishing recovered loot. The
lifetime registry retains the inert rig for bounded launch/recovery cleanup;
rejected records cannot accept further hits or resolve a replacement customer.
The existing rejection sound and ragdoll sequence remain. Dedicated rejection
impulse uses the existing 320 vertical / 12 horizontal tuning without the ordinary
Bat speed cap, which otherwise suppressed the dramatic launch.

A pre-commit hit prevents theft. A post-commit hit drops the exact ingredient record
through InventoryService's normal recoverable world-item registry, preserving ID,
ripeness and stored age. Thieves remain associated and hittable after leaving the
queue, through the final exit route. Only reaching CustomerExit commits successful
escape and permanently consumes custody. Timeout, failed route, NPC destruction,
plot reset or loss of eligibility releases any unescaped ingredient once.
Eligibility cancellation removes only active bad encounters, without launching
or penalizing the plot. Owner promotion does not cancel an eligible encounter.
Serving a freeloader still retains its existing penalty and exclusive serve claim.

## Validation

Run the focused integration tests separately from presentation:

```powershell
python tests/run_state_tests.py --luau <luau.exe> --suite bad-customers --suite bad-customer-stash --suite customer-bat --suite npc-combat
python tests/run_state_tests.py --luau <luau.exe> --suite bad-customer-presentation
```

All five pass; the existing `combat-launch` suite also passes. Roblox-aware typecheck runs against a fresh Rojo sourcemap and
retains the pre-change diagnostics (no added diagnostics). StyLua and Rojo build
pass. `customer-queue`, `customer-payout-serve`, `plot-session`,
`plot-session-progression` and `upgrade-sync`
fail identically in an isolated pre-change source copy; those existing payout/price
expectations were left untouched. Typecheck is not globally clean.

## Studio setup and smoke checks

Keep existing Bat assets, bad NPC templates, theft/queue/exit markers, sounds and
ragdoll assets. No new assets or remotes are required. Authored RejectButton
assemblies may be deleted from plot templates; runtime also removes them when a
plot activates.

Use a two-client Studio server to verify:

1. Level 0 permits normal arrivals but no thieves/freeloaders. Purchase Level 1;
   subsequent ordinary spawn ticks may select bad NPCs, with no forced arrival.
2. Each teammate can hit a waiting, stealing or escaping bad NPC. A foreign plot
   member cannot reject it. A normal regular/special NPC recovers and can be served.
3. Hit before theft windup ends, then after commit while escape movement is active.
   Verify no theft in the first case and pickup of the exact dropped item in the
   second. Let a thief reach the final exit and verify permanent removal.
4. Repeated/concurrent hits launch/drop once and leave replacement customers intact.
5. Unequip, die and respawn; encounters and purchased eligibility survive. Promote
   a teammate by owner departure; the encounter remains defendable. Close/reset a
   session mid-theft and verify unescaped loot is recoverable and a new claim has
   Level 0 eligibility.
6. Check actual sky launch, ragdoll, sound, landing recovery and bounded cleanup;
   normal knockback tuning stays unchanged. Confirm no REJECT UI remains and old
   REJECT requests cannot mutate the queue.

CLI doubles do not validate engine physics, replication or device rendering.
No Studio playtest was run.
