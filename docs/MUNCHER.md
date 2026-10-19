# Muncher ingredient conversion - physical-ingestion corrective pass

Purchased Munchers vacuum authorized loose/thrown ingredients into `InputZone`, then
convert one consumed ingredient into one server-rolled, fresh physical ingredient.
E/controller/touch carried feeding remains a secondary accessibility interaction.
Owner and current teammates may feed through either path; visitors may not.
The former 25-item progress meter and Muncher cash buffs are retired.
`GetCashMultiplier` remains as a compatibility API returning 1. Other upgrades and
temporary powerups are unchanged.

## Interaction and authority

Purchase still uses the authored `PurchasePoint1` touch pad, costs $100,000 from
shared session cash, and preserves the existing 0.95-second, six-stud reveal.
Intake activates after the reveal reaches its authored resting position.

A generated custom `FeedMuncher` prompt on `InputZone` uses E / controller X / the
existing clickable or touch prompt UI. It routes through the existing
`SessionInteractionController` -> `GameplayRequest` -> registered plot interaction
adapter, including captured membership revision and its existing throttle. No new
primary mouse/touch-world listener competes with `CarryInputController`.

The server checks the exact plot/input, session membership, current purchase/reveal,
proximity, living/actionable character, machine availability, and inventory ownership.
Newest-first carried selection is an optional argument on the existing inventory query and
consumption APIs; existing callers retain their selection behavior. Equipped smoothies
and non-ingredient tools are rejected, even with ingredients in the backpack. The
client does not offer FEED while holding them. Loose/thrown items are the primary physical feed inputs; they require authoritative
source attribution and the eligibility rules below. Fresh outputs have per-spawn
immunity, so they cannot accidentally feed themselves back into Muncher.

Feedback uses Fredoka and the shared prompt presentation:

| Situation | Feedback |
| --- | --- |
| Authorized, purchased, idle, carrying ingredient | FEED MUNCHER |
| Empty hands, smoothie, or other tool | NEED INGREDIENT |
| Revealing, processing, spitting, or short output transition | MUNCHER BUSY |
| Unpurchased | Existing MUNCHER / $100K purchase signage |
| Foreign session | NOT YOUR MUNCHER near a purchased machine |

Unavailable states show status text without an actionable FEED button. Server
validation remains authoritative if attributes are delayed or a client bypasses UI.

## Confirmed regression and corrected physical intake

Pass 1 explicitly removed the Muncher component's world-item overlap intake and
made `TryFeed` reject non-nil world objects. InputZone consequently had no active
physical ingestion handler. The earlier intake used overlap consumption, not the
regular blender's attraction helper; Pass 1 supplied neither. This was a code-path
regression, not a diagnosis based on Studio attachment orientation.

`MuncherVacuum` runs inside the existing per-plot component heartbeat. It detects
at most 64 nearby parts in a six-stud radius at 10 Hz, resolves/deduplicates registry
items, and attracts at most one eligible item per machine at a time. It reuses the
blender physics module's bounded exponential velocity-steering approach with a new
3D helper; the regular blender's downward-biased `Steer` behavior is unchanged.
Gravity compensation lets items reach a side-facing opening without anchoring,
teleporting, or adding constraints. The configuration is `Constants.Muncher.Vacuum`.

At 1.4 studs from InputZone's center, or actual overlap within the 2.4-stud jitter
tolerance, the shared conversion entry point can consume. A solid obstruction blocks
pulling/consumption; capture times out after 2.5 seconds and leaves a one-second retry
pause. Leaving the region, lost eligibility, busy/reveal/reset state, component cleanup
or machine destruction stops velocity assistance without consuming or invisibly
queuing the item. Mere detection/pulling never starts hearts, glow, or reward RNG.

The authoritative `MuncherWorldInput.Eligible` predicate is shared by detection,
ongoing attraction, and conversion commit:

| Lifecycle/attribution | Result |
| --- | --- |
| Owner/team-attributed ordinary loose registry item | Eligible |
| Owner/team throw or drop in the current plot session | Eligible |
| FarmManaged, including unanchored/ready crops | FarmCrop |
| Tools, character descendants, or external welded assemblies | CarriedIngredient |
| Under a tagged PlayerStash hierarchy | StashedIngredient |
| Active registry claim | AlreadyReserved |
| Fresh untouched Muncher output | OutputImmune |
| Anonymous public item without authoritative source | MissingAttribution |
| Visitor, conflicting actor/owner, or retired session attribution | UnauthorizedOwner |
| Unregistered visual, smoothie, prop, anchored/frozen/nonclaimable object | InvalidWorldItem |

Actual carried/stored/blender-owned ingredients normally have already left the loose
registry; additional hierarchy/connected-part checks protect malformed registrations.
Farm protection is the existing server-owned `FarmManaged` lifecycle flag, not Anchored
or a client-visible attribute. Normal crop pickup retires that crop spawn; a later
throw produces an ordinary attributed loose item. Farm growth/harvest/cleanup behavior
is not changed.

Throw/drop attribution is separate `FeedingActor` / `FeedingSessionId` registry state,
set only by server spawn callers. Existing loose pickup ownership remains unchanged.
An unattributed public spawn is rejected rather than silently assigned to the machine
owner. An owner-bound world spawn may use its authoritative Owner as attribution.
Current plot membership and captured session are checked again at consumption.

## Per-spawn immunity and shared claims

MuncherOutput passes `MuncherImmune = true` as a server spawn option. It is stored only
on that world's registry record; the cosmetic MuncherReward attribute grants no rights.
Time, contact, failed pickup and moving between machines do not clear immunity.
Successful pickup consumes/retires the spawn and its token; carried IngredientItem
metadata does not inherit it. A later throw registers a new, nonimmune attributed
spawn that can be gambled again. Ordinary destruction/cleanup retires registry and
claim state, including immunity.

IngredientService provides short `Reserve` / `ReleaseReservation` claims. `Consume`
accepts an optional matching opaque token and rejects other consumers while reserved.
The physical conversion revalidates under the session lock, reserves the exact item,
prepares the reward, then consumes with the token. Preparation failure releases it
without input loss. Existing pickup and blender callers already roll back/reject nil
consumption, so they cannot duplicate a claimed unit. There is no persistent claim
while an ingredient is merely being pulled; successful pickup can win that race.

Set ServerStorage attribute `DebugMuncherVacuum = true` in Studio for bounded lifecycle
diagnostics (60 messages by default). Activation/release, distinct rejection reasons,
reservation, commitment and reward publication are logged with plot/item identifiers.
Repeated unchanged rejections are suppressed. Existing gambling telemetry is preserved.

## Transactions and recovery

`MuncherService` owns `Idle -> Processing -> Spitting -> Idle`. Under the existing
session lifecycle lock, it validates the catalog value/pool, rolls exactly once,
captures the mouth transform and result, and consumes exactly one unit. Both
`TryFeed` (carried prompt) and `MuncherVacuum` (physical intake) call the single
`TryStartConversion(player, input, object, source, context)` implementation. The
source is `CarriedPrompt` or `WorldVacuum`; only source-specific identity checks and
consumption differ. Reward selection, commitment, sequence publication, output
settlement and recovery are shared.
Preparation failure preserves the input and releases the lock. The committed reward
is queued independently of presentation, character death, membership changes, and
player removal. Duplicate or simultaneous attempts find the machine busy.

The Heartbeat settlement queue uses the standard `IngredientService.Spawn` pipeline
with a new fresh item, no inherited ripeness, and no source-player metadata. The
machine releases after output publication with a 0.15-second output transition.
Spawn/placement failures retain the same predetermined result: retries are 0.5 seconds
apart for the initial three attempts, then at most once every five seconds. One
warning identifies entry into recovery. The machine remains busy until settlement;
permanent asset/placement failures need correction rather than losing or rerolling
consumed input. Retries are rate bounded; reward debt is not discarded on a timer.

A publication failure destroys the captured candidate before retrying. Successful
output is committed before optional impulse work, so a failed physics effect cannot
cause another output. The service never depends on client animation completion.
Session reset/cleanup detaches the machine state but preserves committed reward debt
at the captured old mouth location. Settlement cannot mutate a replacement session's
purchase/state. Already spawned items use normal loose-world cleanup. Pending debt is
in server memory, not persistent across server shutdown; persistence is outside Pass 1.

`MuncherOutput` checks the short ballistic arc with sphere casts, accepting a floor
hit on descent as its intended landing. A path without a nearby floor or with an
obstruction checks four grounded positions near the mouth/base. Fallback clearance
includes solid Muncher artwork, and drops without impulse. If none are safe, retain
the reward for recovery. Normal outputs use a modest outward/upward mass-scaled
impulse and ordinary pickup, carry, stash, throw, blend, and cleanup behavior.

## Configurable tiers and provisional odds

`src/shared/Constants/Muncher.luau` centralizes thresholds, timing, retry cadence,
telemetry and explicit reward weights. Weights are basis points, totaling 10,000
per tier. Dragon Fruit probabilities are exactly 0.2%, 0.5%, 1%, and 2%.

Tiers use catalog base value, never ripeness or client-supplied metadata:

| Tier | Base value | Initial expected output value |
| --- | --- | ---: |
| Cheap | Positive values below $5,000 | $1,418.50 |
| Standard | $5,000-$19,999 | $4,550 |
| Premium | $20,000-$49,999 | $16,900 |
| High Roller | $50,000+ | $38,050 |

Positive values under the intended $1,000 floor enter Cheap with a development
warning. Invalid/nonpositive values are rejected. Thresholds $5K/$20K/$50K are
inclusive in the next tier.

| Tier | Explicit provisional output weights |
| --- | --- |
| Cheap | Rock 9750; Apple 150; Protein 50; Honey 30; Dragon_Fruit 20 |
| Standard | Apple 6500; Protein 2000; Pear 1200; Honey 250; Dragon_Fruit 50 |
| Premium | Protein 5500; Honey 3000; Crab 1000; Golden_Potato 400; Dragon_Fruit 100 |
| High Roller | Honey 5000; Crab 2500; Golden_Potato 1500; Pizza 800; Dragon_Fruit 200 |

These are inspectable starting distributions, not final economy balance. The spec's
example ingredients do not all match the current catalog: Mushrooms is $3K,
Gummy_Bear is $25K, Honey is $22K, and Dragon_Fruit is $165K. Actual catalog values
win. No pity, adaptive odds, or guaranteed higher-value output is introduced.

**Known balance constraint:** Rock/Worm at $1K have positive expected return with
this pool. Every current catalog output is worth at least $1K, so the requirement to
always return an ingredient plus a nonzero jackpot prevents negative EV at that input
floor. Cheap's EV is below Apple's $1.5K, but repeated $1K feeding can farm expected
value. Pass 3 must explicitly address this constraint (e.g. catalog economics or a
separately agreed cost); do not treat these weights as production-final balance.

PlayerHead prefers an authoritative definition, otherwise uses
`PlayerHeadFallbackBaseValue = 5000`. The current renamed `Player_Head` catalog entry
is $15K, so it remains Tier 2. A lookup-only compatibility alias lets legacy dynamic
`PlayerHead` units use that entry without adding a second enumerable discovery entry
or reverting the authored catalog/prefab name. Both names are forbidden in all pools.
Outputs never transfer `SourceUserId`, `SourceDisplayName`, or `SourceUsername`.

## Presentation and tuning

`MuncherPresentationController` manages local feedback/purchase signage.
`UI/MuncherEffects` produces five short cartoon heart glyphs, a small rhythmic
translation of existing `Visual` parts, a mouth light using the existing ingredient
rarity palette, and a brief highlight pop on the spawned output. All cosmetic
instances are local and bounded; geometry sizes, meshes, textures, and hierarchy are
preserved. Completion/interruption restores captured artwork transforms and removes
effects. The predetermined output rarity drives the glow; no fake higher rarity.

Default consumption-to-output time is 1.65 seconds (`ChewSeconds`), followed by a 0.15-second
output transition (`SpitSeconds`). If repeat feeding feels sluggish in Studio, tune
**chew duration first**, preserving the transaction lock and existing request throttle.
No jackpot fanfare, elaborate reactions, sound redesign, history UI, or special head
animations are included in this pass.

## Studio setup and acceptance

Keep the authored hierarchy under each tagged `PlayerPlot`:

```text
Muncher
  PurchasePoint1  (BasePart; accessible existing purchase touch pad)
  InputZone       (BasePart; close-range feed target)
  MouthOrigin     (BasePart or Attachment; at a clear mouth exit)
  DisplayOrigin   (existing marker may remain; old progress meter is retired)
  FeedSfxOrigin   (existing marker may remain)
  Visual          (all authored artwork; nested parts/models supported)
```

Place `InputZone` at the accessible mouth opening, outside solid artwork. It is the
inward capture target; its orientation does not reverse output. Keep `MouthOrigin`
pointing outward for spit. No new attachment or permanent visible part is required.
A blocked intake ray releases the ingredient and warns once with the InputZone path.
Missing InputZone and a purchased reveal stalled more than three seconds past its
deadline also produce actionable warnings.

No new image assets, authored tags, or remotes are required. The heart is a font
glyph. Position `MouthOrigin` just outside solid mouth geometry and point its
CFrame **LookVector outward**. Keep ground within 24 studs below the local output
area and collectible space around the base. Keep purchase geometry outside the
moving artwork hierarchy. The existing reveal remains server controlled; chew/glow
are local presentation.

Studio acceptance still requires real engine/device testing:

1. Buy normally; verify price, rise, stationary pad, and immediate unlock at rest.
2. Throw an Apple toward the mouth without pressing E: it attracts visibly into
   InputZone, one unit is consumed, hearts/chew/glow begin on commitment, and one
   recognizable output appears approximately 1.65 seconds after consumption.
3. Repeat with the carried E/controller/touch prompt; confirm identical results.
4. Leave fresh output untouched: no attraction/re-ingestion even after time elapses.
   Pick it up, then throw it back: normal deliberate re-gambling must work.
5. Collect, stash, throw, and blend outputs; repeat consecutive feeds.
6. Hold a smoothie and a weapon with ingredients in the backpack: no FEED offer,
   no consumption. Test newest-first selection with an older ingredient equipped.
7. Confirm desktop clicks/touch UI do not throw while feeding; world throws retain
   their existing desktop/mobile/controller routing.
8. Verify owner/teammate contention yields one output and visitors cannot feed.
9. Test multiple active plots, death/respawn, member removal, session release, and
   plot reassignment during the sequence, without duplication or loss.
10. Obstruct the arc; verify accessible fallback. Obstruct every fallback; clear the
   area and verify the same pending result eventually appears exactly once.
11. Judge readability, glyph rendering, mouth orientation, collisions, effect cost,
   and repeat-feed responsiveness. Tune chew duration first if sluggish.
12. Stand beside the mouth carrying three overhead ingredients: none are attracted.
    Put growing and ready-to-harvest farm rows near the mouth: crops remain untouched.
    Stored/protected ingredients must remain untouched too.
13. Throw extras during chewing: they stay intact without an invisible queue. Reset,
    abandon or destroy the machine while pulling: items resume ordinary world physics.
    Repeat during committed conversion and verify exactly one eventual reward.

No Studio play session was available for this pass; CLI doubles do not prove native
physics, replication, rendered layout, or subjective feel.

## Validation and changed files

Focused commands:

```text
python tests/run_state_tests.py --luau <luau.exe> --suite muncher-rewards --suite muncher-vacuum --suite muncher --suite muncher-presentation --suite ingredient-cleanup --suite farm --suite carry-selection --suite carry-input --suite throw --suite throw-blender --suite blender-vacuum --suite player-head
```

All twelve selected suites pass. Reward tables/probabilities and Pass 1 presentation
remain unchanged. `muncher-vacuum` owns physical-feed eligibility, ownership, local
attraction/threshold routing, common registry claims, farm/carry/stash exclusions,
overlapping plots, failed preparation/settlement, timeout/reset release, and the
output pickup/rethrow immunity lifecycle. Existing Muncher tests retain carried
transactions/purchase/recovery coverage; existing carry/farm/ingredient/blender suites
retain their respective contracts. Presentation tests remain separately runnable.

StyLua and Rojo build pass. Roblox-aware full-src typecheck reports the same 216
TypeErrors as the pre-corrective-pass snapshot, with zero added/removed diagnostics.
Changed ingestion, registry, inventory, config, and physics files have no diagnostics.
Logs/sourcemaps/build are in the system temporary directory's
`BlenderGame-luau-tools/muncher-vacuum*` files.

Two additional requested regression checks have baseline failures:

- `--suite world` stops in its fixture because InventoryService dependencies omit
  TycoonService (`refreshStashMetadata` cannot call GetPlot). This reproduces against
  the preserved pre-change source/tests. The focused ingredient-cleanup and actual
  inventory/registry integration suites above pass.
- The legacy `tests/run_blender_vacuum_tests.py` fails parsing its generated bundle:
  `String literal contains malformed escape sequence` at line 76. The same failure
  reproduces on baseline. The **unchanged** `blender_vacuum.spec.luau` now also runs
  as `--suite blender-vacuum` through the current state runner and fixtures; it passes.

Neither unrelated legacy harness was modified to mask its failure. The pre-existing
runner self-test failures documented in Pass 1 remain outside this correction.

Corrective production changes: MuncherService unified entry point; Muncher component
vacuum binding; new MuncherVacuum, MuncherWorldInput and MuncherDiagnostics helpers;
IngredientService registry attribution/reservations/immunity; InventoryService throw/
drop attribution; MuncherOutput's per-spawn immunity flag; bounded 3D steering added
to BlenderVacuumPhysics; Muncher vacuum configuration. The existing blender's steering
and component are unchanged. Focused tests/manifest/source mapping and this guide are
updated. Pre-existing unrelated working-tree edits are preserved.
