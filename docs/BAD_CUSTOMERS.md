# Bad customers, dismissal, and REJECT

First pass: Thief and Freeloader extend the existing special-customer pool,
queue, registry, plot sessions, walking, ragdoll, stash, audio, and dialogue.
No parallel spawning service or client-authoritative gameplay state is added.

## Studio setup

Author this hierarchy in **every plot** before starting Play:

```text
Plot#
?? RejectButton             [Model or container]
?  ?? Button                [RED BasePart, interactive surface]
?  ?? BlackBase             [BLACK BasePart, visual geometry]
?  ?? Attachment            [Attachment, REJECT presentation origin]
?? CustomerThiefPoint       [BasePart, manually positioned near this plot's stash]
?? CustomerSpawn            [existing BasePart marker]
?? CustomerCounter          [existing BasePart marker]
?? CustomerWait1            [existing BasePart marker]
?? CustomerWait2            [existing BasePart marker]
?? CustomerExit             [existing BasePart marker]
```

Button, BlackBase, and Attachment are **siblings**. Attachment is not inside
Button. Preserve the authored transforms; code generates/repositions none of
these objects. This pass uses no physical button animation, so rapid input cannot
drift the button, base, attachment, label, or text size.

No manually created ClickDetector, ProximityPrompt, or GUI is needed.
CustomerService generates a Custom RejectPrompt on Button and registers it with
the existing GameplayService/SessionInteractionController adapter. The custom
view uses red, outlined Fredoka `REJECT`, fixed 24px lettering and a 40-stud
MaxDistance. Native proximity input uses the existing 10-stud activation range;
keyboard/gamepad/touch/click operate through the existing prompt architecture.
Only the plot owner sees this interaction view and the server independently
validates owner, membership revision, plot, and proximity.

CustomerThiefPoint participates in TycoonService's existing marker tagging and
unique reference resolution. It never resolves a marker from another plot.
Missing/malformed RejectButton siblings disable only that plot's button.
A missing ThiefPoint prevents theft. Missing Wait2 skips that escape waypoint.
An exit removed during play causes bounded cleanup. Existing spawning still
requires the normal Counter/Wait/Exit markers, as before.

## NPC assets

Supply two archivable, compatible humanoid rig Models in:

```text
ServerStorage
?? CustomerNPCs
   ?? Special
      ?? <suspicious thief rig>       CustomerId = "thief"
      ?? <freeloader rig>            CustomerId = "freeloader"
```

`CustomerId` is a case-sensitive string attribute on each template Model;
model names are not gameplay identity. Provide Humanoid, HumanoidRootPart and
normal supported rig joints/body parts. Use the same customer rig guidance in
CUSTOMER_NPCS.md and RAGDOLL.md. Appearance must be authored in Studio: this
change does not invent or upload NPC templates. Missing templates simply do not
enter the spawn pool. Their display names are Sneaky Steve and Freebie Fred;
there is no BAD CUSTOMER / REJECT ME label.

The initial audio hooks reuse existing project cue IDs. Listen and replace them
in BadCustomers.Audio after verifying asset permissions. No new upload is needed
to exercise the hooks, but their final artistic suitability requires Studio.

## Target and outcome contracts

REJECT first targets an eligible **active revealed Thief**, then the authoritative
front of the queue: CustomerCounter, CustomerWait1, CustomerWait2 (including
approach and temporary Bat recovery). A thief reveals itself when TakeOrder
claims Stealing and releases queue participation; the next legitimate customer
can already be at the counter while the thief approaches the stash or escapes.
The override prevents dismissing that innocent customer during the chase.

The existing per-plot `queue.Records` lifetime registry is the authoritative
association, filtered by Thief metadata, Stealing/Escaping state, session,
original owner, live model and Humanoid. Escaping takes priority over Stealing;
ties select the oldest encounter. This never searches Workspace, uses proximity,
selects another plot's thief, or discovers hidden queued bad customers. Rejected
state clears eligibility immediately; escape completion, destruction, death,
reset or owner departure remove the association through existing cleanup. Normal
queue targeting then resumes. Repeated button presses can intentionally dismiss
subsequent front customers after rejection, but cannot duplicate stolen loot.

**Dismissal:** a legitimate regular or special customer targeted by REJECT gets
an exclusive Dismissed claim, its request/prompts and old movement are invalidated,
and queue occupancy is released immediately. A generic angry typewriter line
and Disgust reaction appear for the owner/session. After a two-second reaction
hold, the customer walks to that plot's current CustomerExit and despawns.
A missing exit cleans immediately. No cash fine, grade, payout, smoothie
consumption, ingredient destruction, or blender modification occurs. Orders
already taken remain dismissible until service claims them.

**Successful rejection:** an explicitly Rejectable Thief/Freeloader gets the
exclusive Rejected claim. The same invalidation/release operation runs before
one rejection cue, native ragdoll, physical sky impulse, falling, landing,
recovery, and walking out. Owner Bat hits call this exact same RejectCustomer
entry through CustomerService.HitCustomer. CombatService already delegates
customer hits there, so no launch/ejection branch is duplicated in combat.

Legitimate Bat hits retain the existing temporary hit/recovery pipeline and
order/queue membership. Existing foreign-session customer-hit ineligibility is
unchanged. A teammate's ordinary permitted hit cannot permanently reject a bad
customer; it resumes special movement after temporary recovery. An owner can
successfully reject their bad customer even during that temporary ragdoll.
Served legitimate customers retain their existing temporary Bat eligibility.

## Claims, queue release, and races

CustomerService owns the record State. Queued/OrderTaken may claim Serving,
Dismissed, or Rejected. Serving is set **before** ConsumeCup can destroy a visual
and emit Immediate signals; a missing cup restores the prior state. Successful
consumption commits Served and the existing normal payout. Dismissed/Rejected
invalidate serving immediately. Terminal claims plus the existing plot session
transaction prevent reentrant Serve/REJECT/Bat requests from claiming twice.

releaseQueue removes the record only if it still participates in the ordered
queue. It clears QueuePosition and refreshes the followers at logical commit.
The registry and SessionId survive until physical destruction. Stealing releases
once; later rejection/destruction cannot remove somebody else's queue position.
RuntimeToken, RecoveryToken and CustomerWalk's existing MoveToken invalidate
old timers, movement completions, and ordinary Bat recovery when outcomes change.

## Thief lifecycle and physical recovery

Only the plot owner can initiate the Thief's order. The record claims Stealing,
invalidates normal serving, releases the queue, reveals suspicious dialogue,
plays the Thief cue and uses CustomerWalk/PathfindingService to reach the
plot's CustomerThiefPoint. After the 1.2-second theft windup, one guarded attempt
calls InventoryService.RemoveThiefIngredient under the existing plot transaction.

The inventory API validates the current stash owner/session and actual accessible
slot fixtures. It samples **individual ingredient entries** uniformly from
unlocked slots (3?5, plus enabled purchased Second Storage slots 6?10).
Protected slots 1/2, protected raid windows, smoothie slots, carry, blender,
world items, farms and other plots are excluded. Slot state changes before
StashChanged updates presentation. Capacity/protection/raid rules are unchanged.

The theft commit is the synchronous table removal from the authoritative slot.
TheftAttempted is claimed first. Inventory freezes ripeness with Item.ExitStash
and passes that exact record into `record.StolenIngredient` before StashChanged
can publish Immediate callbacks. Identity, ingredient type, ripe/fresh state,
accumulated ripeness seconds, visual key, source metadata and announcement
ownership survive. Rarity and value continue to derive from the unchanged
ingredient definition and ripeness; no fresh replacement or reroll is created.
Empty/protected/unavailable stash contents remove nothing; the thief still
escapes. No second attempt or payout is possible.

Escape traverses CustomerWait2 then CustomerExit without regaining occupancy.
The Thief remains rejectable in both Stealing and Escaping, including the final
route from Wait2 to Exit. A queued Thief cannot be served via a direct request.
IngredientService.CreateVisual projects the retained authoritative item onto the
rig as massless, noncollidable/nonqueryable geometry. The projection is not a
second item: no world registry, pickup tag, stash entry or carried inventory
exists while the sole unit is held by the thief.

Before theft: catch/reject the thief, cancel its walk and windup, lose nothing,
and drop nothing. After theft: successful owner REJECT or Bat claims Rejected,
invalidates routes/timers and releases any queue occupancy, takes and clears
StolenIngredient, destroys its attached projection, then calls
InventoryService.ReleaseThiefIngredient. IngredientService.Spawn receives the
original item state and publishes one ordinary claimable loose world ingredient
at root-local `(0, 2, -4)`, before audio, ragdoll or the large impulse. It stays
near the catch location rather than being welded to the launching thief. The
player must pick it up physically; ordinary pickup, carry, throw, stash and
global loose-item cleanup apply. No automatic stash restoration occurs.

Rejected state and the cleared custody reference prevent duplicate drops from
Button/Bat races, repeated hits, stale escape callbacks and NPC cleanup. Failed
visual/spawn preparation never creates a replacement unit or retry duplication.
A successful escape destroys the thief and consumes its held unit. Unexpected
destruction, death, plot reset and owner departure also discard custody without
publishing recovery loot; only committed owner rejection can release it.

## Freeloader service

The fixed Freeloader request accepts any otherwise valid three-ingredient
smoothie, ignoring tag/color/recipe matching. The selected authoritative cup is
validated before consumption. Successful service consumes once, claims Served,
and bypasses CalculateOrderPayout, ingredient value, grade multipliers, rarity
bonuses, payout upgrades, entitlements and Muncher multipliers.

The result is exactly `-$50`, without a letter grade or ingredient-value row.
TycoonService.DebitTransaction applies the centralized nonnegative cash policy:
a $100 balance becomes $50; a $20 balance becomes $0. The nominal result remains
-$50. Rejection before service consumes nothing and debits nothing. Service
first prevents subsequent rejection/dismissal.

## Initial tuning

All new behavior/physics/dialogue/audio tuning is in
`src/shared/Constants/BadCustomers.luau`; NPC identity/fixed request text is in
`src/shared/Constants/CustomerRequests.luau`.

| Setting | Initial value |
| --- | --- |
| Thief special-pool weight | 0.15 |
| Freeloader special-pool weight | 0.15 |
| Existing special selection chance | 0.55, unchanged |
| Existing special cooldown | 300 seconds, unchanged |
| Existing initial spawn delay | 2?5 seconds, unchanged |
| Existing successful spawn cadence | 35?65 seconds, unchanged |
| Existing full/missing-template retry | 5?10 seconds, unchanged |
| Existing queue capacity | 3, unchanged |
| Freeloader nominal outcome | -50 dollars |
| Theft windup | 1.2 seconds |
| Thief runtime failsafe | 35 seconds |
| Exit failsafe | 15 seconds |
| Legitimate reaction hold | 2 seconds |
| Reject upward velocity change | 320 studs/second (previously 115) |
| Reject horizontal velocity change | 12 studs/second |
| Reject tumble angular velocity | (8, 0, 4) radians/second |
| Minimum flight before landing check | 0.6 seconds |
| Grounded recovery hold | 0.75 seconds |
| Landing timeout / polling | 10 seconds / 0.1 seconds |
| Landing clearance | BottomOffset + 1.5 studs |
| Reject cue | rbxassetid://126967734395019, volume 1, speed 0.8 |
| Thief cue | rbxassetid://9113305311, volume 0.8, speed 0.65 |

Weights are relative to eligible, valid authored special templates, not absolute
spawn probabilities. No template means no corresponding bad encounter. Bat
levels/cooldown/ordinary knockback and player fall damage are unchanged.

The server owns physics and applies the mass-scaled impulse one Heartbeat after
ragdoll. A downward collidable-floor ray (excluding the rig), descending/near-zero
vertical speed, and minimum flight identify landing. Recovery uses the existing
RagdollService; locomotion resumes on the next Heartbeat. Timeout, out-of-bounds,
invalid/dead rig, and exhausted walking clean the customer instead of leaking it.
No customer fall-damage logic is introduced. Owner promotion in a surviving team
session destroys the original owner's bad encounters; ordinary customers survive.

Horizontal launch remains 12 studs/second. At default Roblox gravity (196.2),
320 upward speed gives an ideal ballistic rise of about 261 studs and a 3.3-second
return to launch height, with about 39 studs of horizontal drift on flat ground.
The existing 10-second landing failsafe remains well beyond that flight time;
actual collisions, slopes, roofs and ragdoll geometry require Studio verification.

## Changed files and architecture

- CustomerService: metadata, lifecycle claims, central front resolver, dismissal,
  shared rejection, theft transaction boundary, button binding, Bat delegation,
  queue release, and runtime cleanup.
- BadCustomerBehavior (new): focused cancellable Thief routes and rejection physics.
- InventoryService: authoritative ingredient-only NPC stash removal API.
- TycoonService: additive ThiefPoint reference support and transaction debit.
- AudioService: one centralized bad-customer cue hook.
- CustomerPresentation: negative/no-grade result and safe stolen geometry.
- BadCustomers (new) and CustomerRequests: centralized tuning/metadata/dialogue.
- InteractionPromptController and InteractionPromptPresentation: owner-filtered,
  stable red Fredoka REJECT view through the existing interaction framework.
- Tests: bad_customers, bad_customer_stash, bad_customer_presentation; runner
  manifest/source entries; preserved authored definition fixture snapshot.
- Docs: this guide and links in CUSTOMER_NPCS, CUSTOMER_QUEUE and tests/README.

Existing user edits in Muncher presentation/docs/tests were left untouched.

## Validation and Studio-only follow-up

Run the feature boundaries independently:

```powershell
python tests/run_state_tests.py --luau <luau.exe> --suite bad-customers --suite bad-customer-stash
python tests/run_state_tests.py --luau <luau.exe> --suite bad-customer-presentation
```

Recovery/targeting pass: bad-customers (102 behavioral assertions) and
bad-customer-stash (31) pass, covering
priority over Counter/Wait1/Wait2, plot isolation, multiple-thief determinism,
pre/post-commit owner Button/Bat, repeated inputs and reentrant claims, escape,
death/reset/departure cleanup, dedicated launch/landing recovery, and the real
inventory/world/pickup/throw/stash/cleanup path for ripe and partially aged units.
The separate bad-customer-presentation suite also passes.

Nearby customer-queue, customer-bat and ripeness-lifecycle suites fail at the same
assertions in a temporary pre-change copy (this pass's production edits removed,
existing working-tree changes retained). Those failures concern normal payout,
ordinary Bat impulse and ingredient values; unrelated systems were not changed.

Rojo build, changed-module syntax compilation and StyLua pass. Full-src Roblox
luau-lsp typecheck retains the same diagnostics as the pre-change copy, with
**no added diagnostics**. Existing errors include CustomerRequests DisplayText
schema, CombatService, JackedNoobService and CustomerService inference. Global
git diff whitespace checking also reports pre-existing trailing whitespace in
the user's modified `.validation.rbxlx`; this pass builds only to temporary files.

Studio verification remains required: author both compatible rigs and all plot
fixtures; verify sibling Attachment rendering; exercise keyboard/gamepad/touch
interaction and non-owner denial; listen to the configurable cues; tune actual
launch/landing on slopes and under ceilings; catch a Thief before/after its
windup; test two plots and a shared-team owner departure; confirm stolen multipart
visuals stay inert and no duplicate authoritative item appears. Specifically
verify the 320 launch rises high above buildings without excessive horizontal
travel, landing/recovery remains reliable, and caught loot falls nearby before
launch rather than following the NPC upward. Pick up and re-stash a ripe stolen
ingredient and confirm its state/value; let another thief escape and confirm no
item appears at CustomerExit. No additional Studio fixtures are required beyond
the existing setup above.
