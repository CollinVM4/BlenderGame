# Character physics

The existing CharacterAdded callback in `init.server.luau` calls
`CharacterPhysicsService.ApplyCharacter`. Cosmetic physics are applied immediately
and to new descendants. R15 scaling waits for CharacterAppearanceLoaded (or an
already loaded appearance), then applies the existing description at most once.
LoadCharacterAppearance=false skips the appearance wait. Removal disconnects
listeners and invalidates pending spawn work.

HeightScale, WidthScale, DepthScale and HeadScale are **1**. BodyTypeScale and
ProportionScale are **0**. The head's scale is normalized because the head remains
a collidable body part and affects height/clearance; its asset and face are retained.
Body asset IDs, clothing (including layered clothing), accessories, face, colors
and animations are preserved. R6 skips description scaling and retains its rig.

The previous service already waited for CharacterAppearanceLoaded before reading
GetAppliedDescription and applying scales. Its bug was preserving the body morphs
and checking only height/width/depth to decide whether to apply. BodyTypeScale=1
selects the taller/slender morph even when those three dimensions are 1. The new
change predicate includes all six scales. ApplyDescriptionAsync (the current API)
is awaited once, followed by a Heartbeat and a fresh GetAppliedDescription readback.
The event connection is installed before checking HasAppearanceLoaded; a per-spawn
guard prevents duplicate event/check applications. No other source script applies
an avatar description. There is no reapplication loop or delayed appearance fallback.

HumanoidRootPart is 2 x 2 x 1 studs, non-massless, RootPriority 127,
non-colliding, non-touching and queryable. PhysicalProperties are density 4,
friction 0.3, elasticity 0, friction weight 1, elasticity weight 1.
The root supplies **16 mass units** to an ordinary connected character.
Standard named body parts are massless, RootPriority 0, with density 0.7,
friction 0.3, elasticity 0 and both weights 1. Roblox retains control of body
collisions and Humanoid state transitions. No collision groups, anchors, movement
stats, joints or network ownership are changed.

BaseParts inside avatar Accessories become massless, non-colliding,
non-touching and non-queryable, with RootPriority -127. Current gameplay uses
character roots/body for targeting; cosmetic queries are unnecessary. Tools and
non-body gameplay parts are excluded. A server-authored Accessory can explicitly
opt out with `PreserveGameplayPhysics = true` set before parenting. Such exceptions
and non-massless tools can still contribute mass; ordinary welded cosmetics cannot.
Detached parts no longer share character mass. This is spawn normalization, not
ongoing enforcement against subsequent scripts changing properties.

TurbineWheel continues to measure actual AssemblyAngularVelocity via PhysicsService.
Massless body parts still collide and transfer forces through the connected root.
CombatService already scales knockback impulse by AssemblyMass. Neither is changed.

Avatar packages retain different mesh silhouettes even at equal scale/morph values.
This reduces scale and mass advantages without promising
identical collision envelopes. Concentrated root mass also changes rotational
inertia; check the 16-unit target against the actual blade assembly in Studio.

## Studio verification

No new objects or tags are required; sync with Rojo. Local `DEBUG = true` is enabled
for Studio only; set it false after validation. Each completed spawn prints its
appearance lifecycle source, all six FINAL applied-description values, all six live
Humanoid scale NumberValues, character GetBoundingBox size, root mass, root assembly
mass and cosmetic part count. R6 description scales print n/a.
Bounding size is measured, not inferred from scales: it includes accessories/tools
and depends on the current pose, so large cosmetic bounds do not imply collision.
Actual player dimensions cannot be measured by the CLI tests; read the Studio log.

Use server Play with two players and test:

1. Small/large R15 scale settings and different body packages, including layered
   clothing and large accessories, especially Body Type 100% with H/W/D already 1:
   verify avatar identity remains and final H/W/D/Head are 1, Type/Proportion are 0.
   Root mass and unencumbered connected assembly mass should be 16.
2. Walk into turbine blades with each avatar. Confirm rotation and blend progress,
   comparing equal movement upgrades. Check blender walls and narrow gaps.
3. Slap/stun at equal upgrades and compare displacement/recovery. Confirm jump,
   sprint, ingredient carrying and serving cups still work.
4. Add an Accessory after spawn with a collidable, non-massless Handle and nested
   parts. Verify normalized flags. Equip a Tool and verify its physics are unchanged.
5. Respawn repeatedly, including during appearance loading. Verify one diagnostic
   per completed character and no old-character changes or errors.
6. If R6 is enabled, verify movement and turbine pushing with no rig conversion.
   Also test LoadCharacterAppearance=false if used.

CLI checks do not simulate Roblox character loading, collisions or network physics;
these checks require Studio.

## Turbine collision investigation (no behavior changes)

`docs/studio/CreateReferencePlot.luau` creates a collidable rectangular blade sized
6 x 0.5 x 1 at Y=3, rotating around a vertical hinge. Its horizontal upper face at
Y=3.25 is a potential floor/landing surface. Side contact pushes; top contact supports
the player. Walking/stepping onto that surface does not require the Humanoid Climbing
state. TurbineWheel neither creates nor filters collisions; it samples actual spin.
The checked-in test-place.rbxlx does not contain the live turbine geometry, so the
current Studio blade mesh/hull, position and contact normals still need inspection.

Recommended smallest geometry fix: retain the existing hinge and spinning assembly,
but replace only blade collision geometry with simple welded, massless push proxies.
Use vertical side faces for torque and steep beveled/roof-shaped upper faces (steeper
than the Humanoid's MaxSlopeAngle), without low flat shelves. Make corresponding
visual blades non-colliding only after these proxies provide the pushing contact.
For an already simple blade, first trial a beveled replacement collision shape.
Keep the spin-sampling tag on the same assembly and leave ownership unchanged.

This reduces footholds rather than guaranteeing a player can never balance on an
edge. Validate pushing, jumps onto the top, coasting and contact at all rotations
in a duplicate fixture before adopting it. Collision groups filter entire part pairs,
not contact direction: disabling character/blade collision would remove pushing too.
Lowering MaxSlopeAngle alone cannot reject a horizontal top, and changing friction
alone does not remove support. Neither is an adequate fix for a flat blade platform.
