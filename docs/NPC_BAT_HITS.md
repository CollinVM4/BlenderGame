# Cross-plot NPC bat hits

Bat contact still comes from CombatService's server-issued Tool overlap samples,
forward/range/line-of-sight checks and validated plot membership. A swing still
selects one nearest eligible target and consumes its token before dispatch.
PvP plot-session and Roblox-team friendly-fire rules are unchanged.

Customer combat lookup now searches the authoritative lifetime registries for
all active plots. Serving, taking orders and rejecting through buttons retain
membership/owner checks. Owner bat rejection of bad customers remains intact;
foreign hits use normal ragdoll recovery. Recovery follows the target's queue,
so the attacker's departure does not cancel it. Served customers remain outside
the queue and resume their exit route without replaying payouts.

JackedNoobService now receives validated bat hits through the shared service
registry. Hit immunity lasts the Bat level's stun duration plus BatConfig immunity.
His Protein reward, personal reward deadline, Talk prompt and respawn remain
separate. The authored R6 Noob is unsupported by the existing native R15 ragdoll
service; supported R15 rigs use its normal ragdoll, knockback and recovery.

JackedNoobHitReaction creates one replicated head-attached BillboardGui with
HEY STOP THAT in white Fredoka lettering with the shared dark outline. It pops
in, fades and expires after approximately two seconds. New reactions replace
old bubbles; death/removal/binding a replacement clears UI and sound. One spatial
Sound is restarted only after a 0.6-second reaction cooldown, preventing overlap.

## Modified files

- src/server/Services/CombatService.luau
- src/server/Services/CustomerService.luau
- src/server/Services/JackedNoobService.luau
- src/server/Services/JackedNoobHitReaction.luau (new)
- src/shared/Constants/JackedNoob.luau
- src/server/init.server.luau
- tests/customer_bat.spec.luau
- tests/jacked_noob.spec.luau
- tests/npc_combat.spec.luau (new)
- tests/jacked_noob_hit_presentation.spec.luau (new)
- tests/run_state_tests.py (suite registration)
- docs/NPC_BAT_HITS.md (new)

## Studio assets

No new manually authored GUI or remote is required. Keep the existing NPCId =
JackedNoob model with living Humanoid, Head and HumanoidRootPart, Workspace.NoobRoam,
and the existing server Bat Tool setup. Constants/JackedNoob reuses
GameplayAudio.CustomerHurtSoundId (rbxassetid://126967734395019), at volume 0.7
and 10?50 stud spatial falloff. Verify that the experience can play this existing
asset and that its sound suits Jacked Noob. If an approved replacement is needed,
set JackedNoob.HurtSoundId to that asset ID.

## Validation

Run with the repository's Luau executable:

```powershell
python tests/run_state_tests.py --luau <luau.exe> --suite npc-combat --suite customer-bat --suite jacked-noob --suite jacked-noob-inventory --suite jacked-noob-hit-presentation
```

All five focused suites pass. They cover server geometry and once-per-swing NPC
dispatch; own/foreign plot and teammate customer eligibility; multiple attackers;
dead/protected/unregistered/despawned targets; recovery preserving orders and
serving; interrupted exit; stale session recovery; Noob shared immunity, R15
recovery, reaction dispatch, death/respawn/removal; existing reward behavior; and
real reaction UI replacement, sound cooldown and expiry at an engine boundary.
The customer test delivers the impact heartbeat before stun expiry and checks
immunity immediately after recovery rather than after later exit timers.

StyLua passes for all feature Luau files. Rojo build passes. Roblox-aware LSP
analysis was run over src with a fresh sourcemap: the full check remains blocked
by existing type errors (including CombatService, JackedNoobService and customer
request definitions); no new error categories appear in the modified feature code.
The older combat suite fails on the existing unequip/newest-first throw assertion;
bad-customers fails on the existing floor-display attachment assertion. Both
reproduce with this feature removed in a temporary baseline. Unrelated production
systems were not changed to address those failures. The Python runner self-tests
also retain four pre-existing stale manifest/bundle assertions, reproduced in the
temporary baseline.

## Live Studio checklist

Use at least two players and two claimed plots, including a teammate. Verify an
owner hitting their customer, an owner hitting another plot's customer, and a
teammate hitting a different plot's customer. Two attackers hitting the same NPC
must not duplicate ragdoll while it is recovering/immune. Confirm allied players
still cannot be hit. Test taken/untaken orders, queue advancement while down,
serving after recovery, and served NPCs being hit during exit until despawn.

Hit Jacked Noob from each plot. Confirm spatial sound, readable outlined Fredoka
text, pop/fade timing and one bubble. Try rapid repeated swings, then kill/respawn
or remove him while reacting and verify no old UI/audio remains. Confirm roaming,
Talk and the 90-second personal Protein reward cooldown still work. Native overlap,
real pathfinding/physics, network replication, asset permission/playback and the
rendered animation still require Studio playtesting; no live Studio session ran.
