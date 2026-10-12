# UNSTUCK recovery

UNSTUCK is a server-authorized emergency recovery for recently ragdolled characters that are physically immobilized. The current placement strategy attempts a ten-stud vertical teleport, then returns the player to their currently assigned plot spawn if the local destination is unsafe. Neither method accepts client-provided destinations or plot IDs.

## Why the previous placement refused open areas

The previous code rejected colliders in a full-character radius sweep around the starting pose. Only the single chosen floor instance was exempted. An adjacent grass/floor piece inside that radius therefore rejected recovery, even on a flat open multipart floor. Noncollidable accessories and carried visuals enlarged the radius, and any TouchTransmitter on the supporting floor was considered dangerous. These are deterministic code-level rejection paths. A differential CLI reproduction using the saved pre-pass code confirmed that an embedded root on a flat, two-piece floor had a clear destination but was rejected on its second overlap query because the radius sweep hit the neighboring floor. The new resolver succeeded in the identical scene, lifting root Y from 1 to 11. The old resolver also rejected a harmless TouchTransmitter on its support. Regression tests now cover embedded bodies, neighboring grass pieces, large cosmetic/carried visuals, and harmless touch triggers.

Other previous refusal paths included the four-stud maximum lift, floor-above-root check, and four footprint rays that required the same support instance and less than 0.15 studs of height variation. The exact path responsible for the reported live grass-area failure cannot be identified without that character's runtime geometry/trace. The new primary method removes all of these requirements.

## Placement

`UnstuckPlacement.Find` proposes the current root CFrame translated by exactly ten world-space studs in Y. X/Z and the complete orientation are preserved. The server applies the equivalent transform with `Model:PivotTo`, moving the entire character and its carried items.

`IsUsable` checks direct avatar body parts separately at the proposed destination. It excludes the character itself from world queries and ignores noncollidable accessories, Tool/carry visuals, and empty space between limbs. Actual collidable gameplay accessories or carried parts still require physical clearance. It checks solid geometry in the body's collision group, explicit unsafe volumes, the existing blender `KillZone` tags, and Terrain. Harmless noncollidable decor or touch-trigger geometry does not reject a destination. Collidable decor remains a physical obstruction. No character sweep through the embedded starting position is required.

Terrain overlap is checked with destination body voxels. Fully occupied solid/water cells are rejected. Partially occupied grass cells are checked with Terrain-only surface probes so a cell containing grass below a clear foot does not automatically invalidate a spawn. Spatial and Terrain checks are approximations; unusual mesh/terrain shapes still require real Studio acceptance.

The local destination is not required to be floor supported. After the lift the character falls normally. A solid ceiling or locked barrier occupying the destination rejects it. This is an intentional emergency teleport, not a traversable path: intermediate obstacles do not trigger the old swept-volume rejection.

## Assigned-plot fallback

When local placement fails, UnstuckService calls the read-only `InitialSpawnService.GetAssignedSpawn` resolver. InitialSpawnService's assigned respawn path now calls the same function. It resolves current authoritative `TycoonService.GetPlot`, `PlotIdentity.PlayerSpawnOrigin`, the existing local three-stud vertical offset, and the local four-stud horizontal offset for teammates. Authored marker orientation is preserved.

The returned model pivot is converted to the corresponding root CFrame for the same destination body validation. A missing/released plot, missing marker, unsafe destination, or changed membership rejects fallback without moving the character. Recovery never claims/reserves an available plot or changes ownership/team membership. Ragdoll observations capture authoritative membership context; release, reassignment, or teammate membership changes invalidate stale recovery eligibility.

## Eligibility and restoration

The existing recent-ragdoll, measured immobility, movement-intent/abnormal-recovery checks, active stun/freeze restrictions, and twelve-second successful recovery cooldown remain. The service samples only recently ragdolled characters every 0.4 seconds. Healthy idle, normal movement, death, respawn, and legitimate gameplay locks cannot authorize either teleport.

The server validates placement before mutating character state, temporarily takes root network ownership, restores joints/collisions through RagdollService, moves the complete model, clears assembly velocities, reapplies authoritative movement/jump/sprint values, requests GettingUp, and restores previous ownership after 0.2 seconds. The owning client also requests GettingUp, guarded against stale-character responses. Health, inventory ownership, carried instances, and assigned plot identity are preserved. No combat deadlines, immunity, ForceFields, or invulnerability are modified.

`FallDamageService.NotifyRecoveryTeleport` explicitly resets only the current character's old peak/contact/settling history after a successful reposition. This is necessary because its general reposition tolerance is twelve studs, so a ten-stud lift may not be recognized by the existing discontinuity heuristic. A subsequent real descent/landing is tracked and damaged normally. Stale-character notifications cannot cancel another character's fall.

## Feedback and setup

Success is shown briefly even after the action button hides:

- Local recovery: `Unstuck!`
- Own-plot fallback: `Returned to your plot!`
- Both unavailable: `Unable to find a safe recovery position.`

Button visibility, PC U, console D-pad Up/GUI activation, touch/click, and Framewisp panel suppression retain their existing behavior. Feedback also respects open panels and clears on respawn.

No new Studio objects, authored GUI, or collision groups are needed. Existing `KillZone` volumes are recognized automatically, including nonqueryable tagged parts. Custom hazards can use the existing `UnstuckHazard` tag or `UnstuckUnsafe=true` attribute; attribute-only hazards must remain queryable. Harmless touch listeners need no changes. Existing R15 Avatar Joint Upgrade configuration and ragdoll collision suppression/restoration are unchanged in this pass.

## Files changed in the two-stage pass

- `src/server/Services/UnstuckPlacement.luau`: destination body/terrain/hazard checks and ten-stud proposal.
- `src/server/Services/UnstuckService.luau`: primary/fallback selection, current membership validation, fall notification, result feedback.
- `src/server/Services/InitialSpawnService.luau`: shared assigned-spawn resolver reused by existing respawns.
- `src/server/Services/FallDamageService.luau`: explicit authorized recovery teleport notification.
- `src/shared/Constants/UnstuckConfig.luau`: lift, clearance inset, and feedback duration; eligibility/cooldown values unchanged.
- `src/client/Controllers/UnstuckController.luau`: success/failure wording and brief success feedback; action bindings unchanged.
- Focused unstuck state/placement/fallback/UI, initial-spawn, and fall-damage tests; geometry/service fixtures; test manifest/README and this guide.

UnstuckPolicy, RagdollService, CombatService, CharacterPhysicsService, MovementService, SprintService, and bootstrap wiring were not changed in this pass. Unrelated workspace edits were preserved.

## Automated validation

```
python tests/run_state_tests.py --luau <luau.exe> --suite unstuck --suite unstuck-placement --suite unstuck-fallback --suite unstuck-ui --suite initial-spawn --suite fall-damage
```

State authorization, spatial-query integration, spawn fallback integration, and UI remain independent test groups. Joint/collision contracts stay in the existing ragdoll suite. FallDamageService owns stale-impact reset and subsequent genuine-fall contracts; InitialSpawnService owns rotated owner/teammate spawn resolution.

All six focused suites pass. Roblox-aware focused typecheck, StyLua, and Rojo build pass. Full-src typecheck has the same 41 unique existing diagnostics as a pre-pass copy, with no new diagnostics. Tests use controlled engine boundaries and do not simulate Roblox contacts, terrain surfaces, network replication, or rendering. No Studio session was run.

## Required Studio acceptance

1. On ordinary grass/BaseParts and Terrain, bat-ragdoll a normal, small, and wide/unusually proportioned R15 character. After legitimate stun ends, induce shallow floor entrapment and attempt movement. Confirm exactly ten studs of local lift at identical X/Z/orientation, normal subsequent falling, and restored movement/jump/sprint. Production CharacterPhysicsService normalizes scales; apply experimental scale changes after appearance normalization only in the test session.
2. Put solid ceiling/barrier geometry or a tagged hazard at the ten-stud destination. Confirm fallback to the current plot's PlayerSpawnOrigin, with three-stud vertical and four-stud teammate offsets. Test rotated spawn markers and partial Terrain cells beneath clear spawn feet. Check `Unstuck!` versus `Returned to your plot!` feedback.
3. With local recovery blocked, test owner and teammate simultaneously, missing/unclaimed plots, missing markers, blocked/hazardous spawns, and plot release/reassignment while the button is visible. There must be no arbitrary fallback, ownership/team change, or partial reposition on refusal.
4. Carry several ingredients and smoothies during both recovery methods. Confirm instance/ownership preservation, no loss/duplication, and normal subsequent throw/store/serve behavior. Verify health is unchanged and there is no added protection.
5. Exercise legitimate idle, normal walking/jumping, active stun/freeze, cooldown across another ragdoll, death, respawn, and another player's character. None should permit stale or unauthorized recovery.
6. Observe fall-damage diagnostics during the ten-stud lift and plot return. Confirm old peaks/contacts are reset at the authorized boundary, no false teleport landing occurs, and later actual large falls still deal normal damage.
7. Reset or die during temporary server ownership, then verify the fresh character has normal ownership/control. Test two-client replication, repeated recoveries, and other players remaining unaffected.
8. On PC/mobile/console verify unchanged button bindings and placement, success message expiry, failure text, panel suppression, and no interference with Throw/Sprint/Jump.
