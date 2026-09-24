# Customer routing

## Existing architecture and scope

Previously CustomerService linearly interpolated anchored models with PivotTo at 8 studs/second. CustomerWalk only played walk animations. No Humanoid:MoveTo, pathfinding, PathfindingModifier, or navigation labels existed. CustomerPlacement preserved a measured grounded pivot offset but discarded marker orientation. CustomerService already resolved markers through TycoonService, owned queue advancement, and invalidated movement with per-record tokens and plot sessions. Reset removed both waiting and departing owned models.

The implementation retains that controlled, non-colliding movement style and the existing queue. It does not introduce Humanoid:MoveTo physics: path waypoints drive the existing PivotTo interpolation. Root AlignPosition/AlignOrientation constraints hold the unanchored assembly between server updates and while idle, and server network ownership prevents client simulation of that root. Humanoid.EvaluateStateMachine is disabled on these controlled clones so engine forces and automatic collision changes do not compete with the pose hold; explicit Animator playback remains in use. No HumanoidRootPart tween, animation joint rewrite, or collider is added. Existing explicit walk animation playback and R6/R15 body-only validation remain intact, including AnimationConstraint rigs. Disconnected decorative parts keep their previous preparation behavior. Request assignment, Take Order, serving, dialogue, selection, payout, visibility, and push code are unchanged.

## Route and pose

CustomerService chooses slots; CustomerWalk owns computation, traversal, retries, cancellation, final approach, and facing. New arrivals visit Spawn -> Wait2 -> Wait1 -> Counter, stopping at their assigned slot. Completed entrance legs are retained if a queue shift supersedes an in-progress route. Existing queued customers advance Wait2 -> Wait1 -> Counter, then served customers depart to Exit.

Marker X/Z and horizontal CFrame.LookVector are authoritative. The existing vertical convention is preserved: marker top is ground level, with the measured avatar bottom offset added to the model pivot. This keeps feet grounded rather than putting the avatar pivot inside the floor. Pitch/roll do not tilt the avatar. A vertical LookVector falls back to world -Z.

After a successful path, a short direct final approach reaches the exact queue X/Z; a swept agent-sized volume rejects an obstructed correction. Only the last path segment may be shortened. The walk animation stops, AutoRotate becomes false, and a 0.2-second whole-model rotation keeps the grounded position fixed. AutoRotate becomes true when the next route begins. Exit uses the same settle before cleanup.

Shared Constants/CustomerMovement controls speed (8), turn time (0.2), maximum path attempts (3), final correction distance (3), radius (2), height (5), waypoint spacing (3), and costs. Jumping and climbing are disabled; jump waypoints are rejected defensively.

Upcoming Path.Blocked events cause recomputation from the current position. Compute errors, unsuccessful paths, and inaccessible projected endpoints are bounded by the same attempt limit. There is no blind straight-line fallback through an obstacle after a failed path. Exhaustion destroys the unreachable customer through existing cleanup, removing that queue entry without payout and advancing remaining customers. Normal scheduling supplies replacements. Route tokens are checked after yielding computation, every movement/turn step, and before arrival; blocked connections and path instances are released on completion/cancellation.

## Studio setup

No new setup is required for an existing valid plot. Keep the five existing markers, their tops at walking-surface level, and enough navigable space for the configured radius. Rotate Wait2, Wait1, and Counter to author idle facing. Ordinary solid obstacles participate in Roblox's navigation mesh. Non-colliding decoration may need an optional avoidance volume.

Optional: create an anchored invisible Part covering the picnic-table area, set Transparency=1, CanCollide=false, CanTouch=false, and add a PathfindingModifier child with Label=CustomerAvoid and PassThrough=false. The configured infinite label cost prevents routes through its volume. Leave a sufficiently wide route around it and keep markers outside it. See Roblox's [pathfinding and modifier documentation](https://create.roblox.com/docs/characters/pathfinding).

## Verification

CLI doubles test routing decisions, detour traversal, exact final X/Z/facing, idle/walking transitions, bounded errors/blocks/jump rejection, precision-approach obstruction, cancellation during compute/travel/turn/despawn, entrance order, queue advancement and failed-entry recovery. They do not simulate the navigation mesh, physics constraints, animation assets, or replication.

Studio checklist:

- Rotate CustomerWait1, CustomerWait2, and CustomerCounter separately; each stopped NPC adopts the new horizontal facing.
- Place a solid picnic bench between Spawn and the queue; customers detour without jumping onto benches/tables. Repeat with CustomerAvoid around non-colliding decoration.
- Fill all three slots, then serve repeatedly; Wait2 -> Wait1 -> Counter stays ordered and final turns stay smooth.
- Serve while another customer is entering; its completed entrance legs are not retraced.
- Reset during path computation, walking, and turning; no orphan NPC, movement, or prompt remains. Reclaim the plot and verify new arrivals.
- Test Regular and Special R6/R15/AnimationConstraint rigs: walk animation, idle stability, grounded feet, attachments, and existing push behavior.
- Test with two clients for root jitter or replication drift; CLI validation cannot certify the new unanchored pose constraints.
- Completely block a marker: retries stop, the unreachable NPC is removed without a reward, and repairing the route allows a later arrival.

## CLI validation results

Passed: customer routing, walk/rig animation compatibility, placement, queue integration, customer compatibility, payout state, payout/serve integration, and Python runner contracts. Full-src Roblox-aware typecheck passes with the existing CharacterPhysicsService LoadCharacterAppearance deprecation warning. StyLua checks on all touched Luau files and Rojo build pass.

Two failures reproduce in the workspace before this change and remain untouched: customer-validation's ingredient expectation (Request requirements matched), and requests' presentation assertion (name is secondary and outlined). The requests suite stops there, so later assertions in that suite are not claimed as passing. Queue and payout/serve integration pass independently. No Studio play session was run.

Exact task files: src/server/Services/CustomerService.luau, CustomerWalk.luau, CustomerPlacement.luau; src/shared/Constants/CustomerMovement.luau; tests/customer_routing.spec.luau, customer_walk.spec.luau, customer_placement.spec.luau, customer_requests.spec.luau, customer_queue.spec.luau, fixtures/roblox.luau, run_state_tests.py; docs/CUSTOMER_QUEUE.md and CUSTOMER_ROUTING.md. Existing unrelated working-tree edits were retained.
