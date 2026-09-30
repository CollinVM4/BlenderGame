# Bat / PvP stun v1

Bat is a shared plot upgrade. New sessions start at BatLevel 0 (upgrade array
index 1), with no Tool. The existing upgrades panel purchases Bat levels 1-3
using the normal cash transaction and membership revision. Both members receive
access immediately; promotion retains the session upgrades, leaving revokes
access, and respawn reconstructs one Tool from the session. No persistence was
added; plot upgrades retain the existing in-memory lifetime.

Prices are **1500 / 4500 / 9000** in `src/shared/Constants/Upgrades.luau` (`Bat`).
Combat tuning lives in `src/shared/Constants/BatConfig.luau`:

Contact requires overlap with the equipped server-configured Hitbox. `Reach` is
not a strict root-distance gate. `MaxRootDistance = 8`, multiplied by level Scale,
bounds both victim root distance and observed Hitbox center distance from the
attacker (8 / 8.96 / 10 studs). This is an anti-exploit sanity bound, not a larger
query volume. Authored Hitbox geometry remains unchanged.

| Level | Visible scale | Reach (studs) | Stun (seconds) |
|---|---:|---:|---:|
| 1 | 1.00 | 5.0 | 1.5 |
| 2 | 1.12 | 5.75 | 2.25 |
| 3 | 1.25 | 6.5 | 3.0 |

Cooldown is 1.1 seconds, and immunity after stun is
2.5 seconds. Misses consume the swing cooldown. The gameplay request adapter
also retains its 0.15-second per-player request throttle.

`HitActiveStart = 0.08`, `HitActiveEnd = 0.50`, and `HitSampleInterval = 0.04`
control a repeated server sampling window. One delayed callback waits for startup;
after each miss it schedules only the next sample. Sampling stops at the deadline,
without replaying contacts missed during server delays. Each sample reads the
live equipped Hitbox CFrame and Size. The first valid victim consumes the swing.
Eligibility and captured membership context are revalidated on every sample;
unequipping invalidates the swing even if the same Tool is immediately re-equipped.
All spatial checks remain unchanged; this is discrete sampling, not a swept volume.
The obsolete ImpactDelay/ImpactWindow settings and three-sample scheduler were removed.

## Studio setup

Create this authored asset; do **not** put it in StarterPack or StarterGear:

```text
ServerStorage
+-- Bat (Tool)
    +-- Handle (BasePart)
    +-- BatMesh (MeshPart or visible geometry)
    +-- Hitbox (BasePart)
    +-- IdleAnimation (Animation)
    +-- EquipAnimation (Animation)
    +-- SwingAnimation (Animation)
    +-- UnequipAnimation (Animation)
```

No Tools folder is needed. Weld every visible BasePart and Hitbox to Handle
(WeldConstraints recommended). Keep parts unanchored, noncolliding and massless.
Preserve the authored Tool.Grip and Hitbox dimensions/transform. The current
baseline is approximately **0.867 x 0.597 x 4.703**; these numbers are not hardcoded.
Level 1 preserves that baseline, while levels 2/3 scale parts and local offsets by
1.12/1.25. Make the template, Handle and Hitbox Archivable, and keep embedded
gameplay scripts out of the asset. Runtime changes only cloned parts.

Missing/malformed assets warn and skip granting. Clone configuration failures are
isolated from shared purchase transactions; Sprint/Jump state and upgrade receipts
continue normally. Correcting the asset and refreshing/respawning grants the
already-purchased level. No tags or authored attributes are required.

Runtime attributes `BatLevel`, `BatPurchasedLevel`, `Stunned`, and `StunnedUntil`
are projections/diagnostics, never authorization. Tool `BatLevel` describes its
configuration. Existing plot/session tags and attributes continue unchanged.

## Authority and integration

- `BatController` sends only `GameplayRequest("SwingBat")` on Tool activation.
  The server requires a living active plot member, authoritative purchased level,
  the exact issued equipped Tool, no stun, and an elapsed cooldown.
- After the impact delay, the server rechecks character, Tool, membership revision
  and eligibility. It calls `GetPartBoundsInBox` repeatedly across the active window. Each query follows
  the server-observed issued Tool's actual Hitbox CFrame and Size at impact.
  The server configures the clone's scale; request payloads cannot supply geometry.
  The independent root-distance, forward-facing and
  line-of-sight checks below bound the observed pose's effective reach.
- Only the nearest living enemy whose character intersects the volume qualifies.
  Root distance, forward direction and a line-of-sight ray also gate hits. Self,
  shared plot members, non-neutral Roblox teammates, stunned players and immune
  players are excluded. One swing can apply at most one stun, with no damage.
- `MovementService.SetStunned` owns the server stun flag and jump restriction.
  Its change signal makes SprintService stop sprinting and resolve WalkSpeed.
  Recovery uses current purchased movement/jump values; sprint requires fresh
  input. Both JumpPower and JumpHeight modes are supported.
- Inventory and blend entry points, the gameplay adapter and `WorldUtil.Near`
  reject stunned interactions. This covers pickup, throw, stash, serving and
  nearby blender/customer prompts. Already-thrown physical items continue their
  existing world lifecycle.
- `InventoryService.DropCarriedIngredients(player, reason)` walks authoritative
  held records and uses the existing release/world registry path. All ingredients
  drop unowned and claimable; smoothies survive. Failed materialization retains
  the reservation, and repeated drops do not recreate released items.
- Stun callbacks carry a unique state token and character identity. Already-stunned
  and immune victims cannot be hit. Death/respawn removes stun and immunity;
  removal clears cooldowns, state and connections. Character tokens cancel late
  grants/recovery callbacks. Destroyed Tools recover only while still authorized.
- The optional damage-dealing `Slap`/`GrantHand` placeholder API is replaced by
  `SwingBat`. No production callers used it. Legacy Hand configuration remains
  for compatibility with existing shared data; it does not grant a weapon.

## Changed files

Runtime: `CombatService`, `MovementService`, `SprintService`, `InventoryService`,
`BlendService`, `WorldUtil`, `GameplayService`, `TycoonService`, `PlayerDataService`,
server bootstrap, `BatConfig`, `Upgrades`, shared `Types`, `BatController`, client
bootstrap, `UpgradeDisplay`, and `UpgradesController`.

Validation/documentation: `tests/combat.spec.luau`, `tests/upgrade_sync.spec.luau`, `tests/sprint.spec.luau`,
`tests/server_state.spec.luau` (retired slap tests), `tests/upgrade_ui.spec.luau`,
`tests/run_state_tests.py` (combat suite entry), `tests/README.md`, and this file.
The existing customer-request edits were preserved.

## Validation

### Point-blank hit investigation

The old impact path reconstructed the volume from Handle.CFrame and the template's
cached local offset rather than sampling the equipped Hitbox. This has been
corrected. The subsequent Studio trace confirmed actual overlap at root distance
5.807 was vetoed by the old Level 1 Reach of 5. The strict Reach veto is now replaced
by the scaled sanity bound above; forward, LOS, plot/team and immunity rules remain.
Separate claims generate unique session GUIDs; neutral players are not protected
merely because they share a default Team. Avatar roots are queryable; cosmetic
accessories normalized by CharacterPhysicsService are deliberately not queryable.
Queryable accessory descendants still resolve correctly to their owning player.

After Rojo sync, start a fresh multi-client Studio server. Claim separate plots,
unlock/equip the Bat, and put the enemy at point blank with ingredients and a
smoothie. In the **Server Command Bar**, replace the name and run:

```lua
game:GetService("Players"):FindFirstChild("ATTACKER_NAME"):SetAttribute("BatDebugNextSwing", true)
```

Activate the Tool once from that player's client. Server `[Bat]` output reports
request rejection/acceptance, authoritative level and equipped Tool validation,
impact callback, live Hitbox path/CFrame/Size, overlap count, candidate part/model/
player names, session IDs and protection rejection, root distance, forward dot,
LOS obstruction, selected player, and resulting `Stunned`/`StunnedUntil` attributes.
The flag clears after one request (including adapter throttle/stun rejection),
and logging is disabled outside Studio. Re-arm only when another trace is needed.

The focused combat suite verifies live transform sampling and point-blank body/
nested accessory ownership, stun and drops, smoothie retention, teammate immunity,
behind/reach/wall rejection, one victim, cooldown and immunity using engine doubles.
Actual multi-client contact, an enemy just outside the authored volume, and real
wall rays remain Studio checks. Retest the observed 5.807-stud contact after sync
and restart. Temporary logging remains until this fix is confirmed in Studio;
then remove the client/adapter/combat diagnostic logging and its trace-only tests.

### When a swing produces no `[Bat]` output

Temporary `input-v1` boundary logging is now enabled for Studio only, independent
of `BatDebugNextSwing`. This avoids depending on client attribute replication or
successful CombatService dispatch to see activation/adapter rejection. The flag
still enables the existing one-swing detailed combat trace; the adapter leaves it
intact on dispatch and consumes it through `TraceRejectedSwing` on rejection.

Sync, **stop and restart** the Studio test so cached required modules are replaced.
Look for `[BatInput] BatController initialized trace=input-v1` on the attacker
client and `[BatServer] GameplayRequest adapter ready trace=input-v1` on the server.
Arm the flag as above, then activate once and collect both client and server Output.

| Last boundary observed | What the next output resolves |
|---|---|
| No startup markers | Instrumented modules have not run; check sync, restart and bootstrap errors. |
| Client initialized, no `bound Tool.Activated` | The controller has not bound the equipped Bat. |
| Bound, no `Tool.Activated` | This Tool's activation callback did not run. |
| `Tool.Activated` | `activation rejected` names the local gate; otherwise animation preparation/playback leads to the send. Check errors if neither appears. |
| `sending SwingBat` / `FireServer returned` | Client identifies selected remote path, adapter marker and same-name instance count. Missing server receipt indicates a remote/listener/runtime mismatch; `adapter=nil` or `namedRemotes>1` is evidence to investigate, not proof by itself. |
| Server receipt | Adapter logs acceptance or the exact throttle/stun rejection before dispatch. |
| `calling CombatService SwingBat` | Existing `[Bat]` diagnostics should follow when armed; inspect `debugArmed`, handler errors and returned acceptance. |

Source inspection confirms `FireServer("SwingBat")` has no extra arguments, a
matching server branch, and no return between successful animation playback and
the send. Both animation and networking use the same dynamically bound Activated
callback. The adapter has only the shared 0.15-second throttle and attacker stun
gates before this branch; it does not require a plot/context argument for SwingBat.
Membership/level/equipment checks occur in CombatService. No hit, animation,
cooldown, reach, LOS or upgrade behavior changed in this diagnostic pass.

The captured Studio trace identified the strict Reach veto as the stopping
boundary. Local tests cover activation/send and adapter acceptance,
throttle/stun rejection, and preservation of the flag through combat dispatch.

- Combat integration: **54 behavioral assertions pass**, using real combat,
  inventory, movement, shared purchases and the gameplay request adapter.
- Passing relevant suites: sprint, carry, throw-blender, ingredient-slots,
  carry-selection, carry-input, smoothie-survivors, plot-session,
  plot-session-races, plot-session-progression, plot-session-requests,
  plot-player-flow, and customer-payout-serve.
- Upgrade synchronization: **33 assertions pass**, including unclaimed arrival, missing/malformed assets, all three shared upgrade purchases, receipts and prices.
- Upgrade UI: **116 assertions pass**, including carry integration and delayed BatLevel replication.
- Sprint: **33 assertions pass**, including post-removal deferred notifications.
- Python runner contracts: **5 tests pass**.
- Existing failures reproduced on a separate pre-feature copy that retained the
  user's customer-request edits: throw (unlock-space setup), stash (capacity),
  smoothie (capacity), legacy-state (cash expectation), and requests (name style).
  The legacy-movement suite also fails its outdated baseline speed expectation on both baseline and current code. Those unrelated production systems were not changed to make their tests pass.
- Feature-module Roblox-aware typecheck passes. Bootstrap/full-src typecheck remains
  blocked by pre-existing `CustomerRequests` definitions missing `DisplayText`;
  baseline comparison reproduces these diagnostics.
- StyLua, Rojo build, and `git diff --check`: **PASS**.

## Studio-only verification

CLI tests double Roblox spatial queries, timers and physics. Verify in a
multi-client Studio session: authored Tool grip/welds and modest resizing;
all three purchase levels; respawn and owner promotion; enemies at volume edges
and behind walls; teammate immunity; movement/jump/sprint recovery; ingredient
pickup and return to an enemy stash; smoothie preservation; and behavior under
latency. Test both R6/R15 if both are supported. One optional local swing animation is supported. No sound, particles, camera
effects, floating text or custom combat UI were added.

## Upgrade Loading diagnosis and fix

The initial state is replicated Player attributes, not a snapshot response remote.
UpgradesController waits for `*PurchasedLevel` plus the current stat. PlayerData
initialized `*Level`, and MovementService initialized resolved stats, but only
TycoonService's membership publication initialized shared `*PurchasedLevel`.
With explicit plot claiming, an unassigned player could wait forever. Joining a
plot filled those attributes and resolved the menu; the user confirmed that behavior.
The Studio log showed successful bootstrap completion, not a Bat startup failure.

Bootstrap now invokes TycoonService.RefreshUpgradeAttributes after personal data
initialization and before movement setup. The same authoritative publisher is used
on membership updates. Unassigned players receive the existing base tiers without
allocating a plot or allowing purchases without a session. Values, prices, tier
indexing and transaction ownership are unchanged. No UI fallback was added.

UpgradesController also watches BatLevel separately from BatPurchasedLevel so an
independently delayed stat attribute refreshes the row. The shutdown-only
GetMaxStamina nil access in the Studio log came from deferred MovementService.Changed
notifications after removal. SprintService now skips players whose movement state
has not been initialized or has been removed; it does not invent default stats.

## Swing animation and grip authoring

The template remains `ServerStorage.Bat`. Keep Handle, BatMesh and Hitbox welded
in their authored relationship; do not rotate either geometry part to compensate
for a bad hand grip. Author **Tool.Grip** on the template. Its position is the
hand offset, and its rotation determines the held orientation. Both are copied
unchanged through grants and upgrades. Exact offsets/angles depend on the Handle
axis, mesh origin and avatar rig, so they must be tuned in Studio; the runtime
sets no replacement grip. Preview an equipped clone on the supported avatar rig,
then save the desired Grip back to the template in Edit mode.

Use Animation children named **IdleAnimation**, **EquipAnimation**,
**SwingAnimation** and **UnequipAnimation** directly under the Tool. AnimationIds
must be published and permitted for this experience. All tracks load through the
Humanoid's replicated Animator. Code sets IdleAnimation to Idle priority and
looped; EquipAnimation, SwingAnimation and UnequipAnimation use Action priority
and do not loop. Playback remains at 1x speed.

Equip plays first, then idle loops. Activation interrupts equip/idle for a swing;
when the swing ends, idle resumes only while still equipped. Unequip interrupts
all other tracks and plays the optional outro. Outro completion releases all
tracks; re-equip, another Tool, death, destruction, respawn or Controller.Destroy
can cancel it immediately. Missing optional animations do not block combat.

The authored **bat hit2** animation is unchanged. Server hit authorization uses
the broader active window above. The controller never changes the authored Tool.Grip,
including its **-78, 0, 0 degree orientation**, or the mesh/hitbox relationship.
Animation markers do not authorize hits.

Local input immediately predicts playback, then sends the existing SwingBat
request. The server independently validates the swing and samples its live Hitbox
throughout the active window. Network latency can offset the server contact from local
playback; there is no client-reported timing or hit authority. The controller
shares the existing 1.1-second cooldown and retains it across unequip/re-equip.
A single set of tracks is reused; completed unequip, death, tool destruction and
character removal release it. Missing or unavailable animation assets do not block combat.

Animation-pass checks: `--suite bat-controller` (48 presentation/input assertions)
and `--suite combat` (56 authoritative integration assertions, including authored
Grip preservation). Studio still needs visual verification of the published
animation, grip alignment, contact timestamp, avatar rig and multiplayer latency.

## Native AJU ragdoll integration

After the user verified isolated native AJU ragdoll/recovery in Studio, CombatService
now calls RagdollService through its existing injected dependencies. No bootstrap,
client input, spatial hit detection, level, cooldown, immunity, protection,
MovementService authorization or ingredient scatter rules changed.

A valid hit starts authoritative stun, drops/scatters ingredients, then calls
SetRagdolled(character, true). On success, a one-shot Heartbeat callback checks the
original stun token, character and root identity, living/present player, stun deadline,
MovementService.IsStunned and RagdollService.IsRagdolled before applying knockback.

BatConfig.Knockback holds HorizontalSpeed=7 and UpwardSpeed=4 (studs/sec).
Impulse = (horizontalAway * HorizontalSpeed + Vector3.new(0, UpwardSpeed, 0))
* root.AssemblyMass. Horizontal direction uses victim minus attacker position, falls
back to attacker forward for coincident roots, then world -Z if forward is vertical.
It is captured at impact, independent of Bat level. Anchored or nonfinite-mass
assemblies receive no impulse. Ingredient scatter remains stronger.

The existing duration callback validates the stun token and character, calls ragdoll
OFF, then releases MovementService stun and clears StunnedUntil. Existing immunity
is retained. Lifecycle cleanup invalidates the token and attempts OFF on the stored
original character before clearing stun. Ragdoll false returns and errors are caught
and warned; they cannot abort normal authoritative recovery. Knockback errors are
also contained. RagdollService has no added timer or combat state.

The Studio ON/OFF bridge remains available; see [RAGDOLL.md](RAGDOLL.md).
The floor-collision follow-up enables only UpperTorso/LowerTorso CanCollide during
ragdoll and restores their captured values on OFF/cleanup. AJU joints, native sockets,
exclusions, other body collisions and CharacterPhysicsService remain unchanged.
No recovery teleport, nudge, collision proxy or full-body collision was added.

Validation: Combat integration contracts cover ordering, one-shot mass-aware impulse,
coincident-root fallback, ON/OFF failures, stale token/life callbacks, and existing Bat
rules. The separate AJU contracts still cover physical property restoration. Studio
should verify two-player Bat impact, restrained knockback, normal recovery, immunity,
and reset during stun; automated tests do not simulate physical motion.

Follow-up checks pass: combat (125 assertions), ragdoll (45), bat-controller (49),
Roblox-aware typecheck of changed modules, StyLua and Rojo build. Tests cover late
contact, no hits before startup/after expiry, one victim per swing, missed-swing
cooldown, stale callbacks, and torso collision restoration through lifecycle cleanup.
Studio still needs floor-penetration/recovery and broader-window gameplay verification.


## Customer hits

The existing live Hitbox samples choose one nearest eligible player or customer per
swing, using the same distance, facing and line-of-sight checks. CustomerService
accepts only active, unserved customers in the attacker's current plot session.
Customers use the purchased bat's recovery duration and the shared BatKnockback
impulse, without player stun, inventory drops or damage. Accepted customer hits emit
CustomerHurt (`126967734395019`) through the existing positional audio event.

CustomerService cancels walking and disables both interaction handlers/prompts
while the customer is down or returning. Queue changes still update the assigned
marker. After native ragdoll recovery and one physics step, walking explicitly
restarts toward the latest marker, even when the marker did not change. Only a
post-hit return that exhausts CustomerWalk retries resets the customer to that
marker; the order and payout state survive. Immunity lasts BatConfig.ImmunitySeconds
from return completion. Normal arrival failure behavior is unchanged.

No template or Studio settings are changed. Hittable customer templates must
already satisfy RagdollService's native R15 Avatar Joint Upgrade contract:
a living Humanoid, HumanoidRootPart, enabled kinematic Root AnimationConstraint,
all expected body AnimationConstraints and built-in BallSocketConstraints.
Motor6D-only rigs and generic placeholders are rejected gracefully.

Run `python tests/run_state_tests.py --suite combat --suite customer-bat --luau <luau.exe>`.
Customer lifecycle tests share `tests/fixtures/customer_queue.luau` with the queue
suite; native articulation remains owned by the ragdoll suite. In Studio, verify
an authored compatible NPC stops its walk animation, ragdolls with modest
knockback, stands up and returns after a queue advance. Also obstruct its return
route and confirm fallback preserves its order; reset the plot while down and
confirm no stale recovery. CLI doubles do not verify native physics or animations.
