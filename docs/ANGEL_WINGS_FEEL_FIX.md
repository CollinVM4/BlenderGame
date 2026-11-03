# Angel Wings feel correction - 2026-11-02

**IN PROGRESS / PENDING Studio acceptance. Do not treat this diff as release sign-off.**

## Step-0 findings and attachment repair

All requested implementation paths are unchanged. `angelWings.rbxmx` and the generated default-project place both contain `ServerStorage.AngelWingsTemplate` as an Accessory with one Part named Handle, its BodyBackAttachment, and one SpecialMesh. Width animation uses SpecialMesh.Scale; the existing asset, mesh ID, Handle dimensions and scaling metadata are preserved.

Collin's Studio client inspection confirmed `Workspace/Eatandpoop/AngelWings/Handle` contains AccessoryRigidConstraint, BodyBackAttachment, OriginalSize and SpecialMesh, **with no WingMotor**. The former controller returned immediately unless it found WingMotor with a WingRestC0 CFrame attribute. This explains why even mesh narrowing never ran. The source did create that motor under Handle before parenting the Accessory; it was not located elsewhere in the tree. No repository path besides lifecycle teardown was found removing that motor after creation. Native rig/appearance rebuilding is consistent with the observed replacement, but the precise engine removal event was not traced.

Roblox's [Motor6D migration notes](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/Motor6D.yaml) document that upgraded avatars do not retain the traditional joint assumptions. A [RigidConstraint](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/RigidConstraint.yaml) supports an offset through its attachments. The supplied single mesh supports whole-pair pitch/bank/bob and width posing; independent left/right articulation still requires new art and is outside this pass.

The server now uses Humanoid:AddAccessory so Roblox owns attachment creation and accessory scaling. It no longer inserts a custom motor before the native attachment path. If a custom/R6 torso lacks BodyBackAttachment, the server adds the same back-origin fallback used previously. Template scripts/remotes/joints/constraints are sanitized before native attachment; scaling metadata is retained.

SetWingPose now resolves the actual rigid constraint by its endpoint attachments. On each client it creates a dedicated WingPoseAttachment under Handle and redirects only the handle endpoint to it. Its CFrame is derived from the live, unchanged native BodyBackAttachment every frame, with the inverse pose offset. The torso anchor and original handle anchor remain untouched. Rebuilt constraints, reversed endpoints and late attachment replication can be resolved on subsequent frames. Legacy AccessoryWeld is also supported; the former WingMotor path remains as compatibility fallback. No second connection is placed over the native rigid constraint.

The mesh base scale is captured after native attachment/scaling, then adjusted by changes in Handle.Size. Posing does not resize Handle or alter OriginalSize/AvatarPartScaleType, disable AutomaticScalingEnabled, replace the accessory, or modify CharacterPhysicsService.

The repaired native/legacy grounded path passed focused tests **before** adding the width flap. The suite now covers scaled initial grants, later size/anchor updates, rebuilt constraints, grounded fold and Powered/Gliding posing. CLI geometry and attachment doubles do not establish live engine appearance; the post-fix Studio fold check is still PENDING.

## Completed behavior changes

- Server lift writes and wings network-ownership leases removed. BatKnockback itself is unchanged.
- LocalPlayer-only RenderStepped lift reads server WingState, preserves X/Z and faster upward momentum, approaches the Powered target using frame dt, and floors each Powered entry exactly once. Inactive states and missing character/root write nothing. Gliding only caps excessive downward speed.
- Server entitlement, boolean-only JumpHeld input, energy drain, Powered/Gliding decisions, movement eligibility, sustained recharge, and fall-episode coordination remain authoritative. No client energy/altitude/state payload or detector was introduced.
- WingState publishes only on state changes. New characters start with an unpublished sentinel so first Airborne initialization is not skipped.
- Ground evidence immediately publishes a non-lifting Airborne state during the existing 0.2-second confirmation window, then Grounded at confirmation. This is necessary because simply returning on the server would leave client lift active on the floor. Landing evidence is captured before revoking lift; focused reverse-order landing tests pass. Grounded ticks do not repeatedly publish.
- Glide overspeed accumulation and airborne lockout removed, including obsolete InvalidGlide checks in landing protection. The two legacy overspeed config constants remain untouched.
- Native accessory attachment and scaling now use Humanoid:AddAccessory; posing supports AccessoryRigidConstraint, legacy AccessoryWeld, and older WingMotor grants.
- Powered pose pulses mesh width between 0.55 and 1 at 6 Hz, with -10-degree pitch, +/-6-degree bank and +/-0.05-stud bob. Grounded, airborne and steady glide poses are unchanged.
- Per-character render state blends the previous Powered pose into Gliding over 0.25 seconds, including width and transform.
- Hotbar sorts present items Bat, Ice, Ingredient, Smoothie. Ingredients still use CarryItemId and other items retain Sequence. Selection, keybind implementation and Classify fourth returns are unchanged. Missing weapons leave no reserved gaps.

Current tuning:

| Setting | Value |
| --- | ---: |
| PoweredAscentVelocity | 45 |
| PoweredApproachAccel | 300 |
| PoweredEngageBurstVelocity | 30 |
| FlightDurationSeconds | 1.75 |
| GlideDescentVelocity | 20 |
| GroundedConfirmSeconds | 0.2 |
| PoweredFlapWidthMin | 0.55 |
| PoweredFlapHz | 6 |

No duration trim has been applied because no live reach/gate measurement is available. The requested 0.55 minimum width and 0.25-second visual transition are now implemented.

## Validation

PASS: wings-flight, wings-ownership, fall-damage, wings-input (including actual local RenderStepped lift), wings-pose (native/legacy posing, scale preservation, width pulse and actual RenderStepped transition timing), wings-shop against both authored/prepared exports, and hotbar (including weapon key selection and missing-weapon compaction). Updated old ordering expectations rather than bypassing them.

PASS: StyLua checks all changed Luau files; Rojo default-project build and sourcemap generation.

Full-source Roblox-aware typecheck is **not clean**: 212 TypeError headers. An isolated git archive of HEAD produces the same 212 normalized diagnostic headers; no new diagnostic was introduced. Versions used: Luau 0.745, StyLua 2.6.0, luau-lsp 1.70.1, Rojo 7.7.0; Roblox definitions from luau-lsp's official globalTypes file. Downloaded tools and temporary baseline/build files are not part of the requested diff.

## Required Studio results

| Jump tier | Unaided measured apex | Wings measured apex |
| --- | --- | --- |
| 0 (60 JumpPower) | PENDING | PENDING |
| 1 (85 JumpPower) | PENDING | PENDING |
| 2 (95 JumpPower) | PENDING | PENDING |
| 3 (116 JumpPower) | PENDING | PENDING |

- Sustained Powered climb rate: **PENDING** (target 45 studs/s; not a measured result).
- Jump 0 total reach from flat ground: **PENDING**.
- Tier-gated / Cloud Garden destination heights and accessibility: **PENDING**. If reachable, report measured values, trim FlightDurationSeconds first and repeat the measurement. Do not invent an entry gate or reduce the target to 22 without Collin's call.
- Two-client smoothness / rubber-banding: **PENDING**.
- Post-fix grounded fold, behind-camera flap visibility, Powered-to-Gliding blend: **PENDING**. The original missing-motor failure is repaired in code and covered at the CLI boundary; no post-fix Studio result is claimed.
- Two-client release/re-hold with remaining/exhausted energy, actual fall protection and bat overlap: **PENDING**. Automated state/lift tests do not establish engine/network behavior.

Use the default Rojo mapping and actual entitled accounts; no Studio ownership bypass was added. **Sync the changes, then stop and restart Play** so the server grants through the new native attachment path. In the Studio client view, Handle should retain BodyBackAttachment, SpecialMesh and scaling data, and its native AccessoryRigidConstraint should use the locally created WingPoseAttachment on the Handle side after posing begins. WingMotor and WingRestC0 are no longer required on native grants. WingPoseAttachment is client presentation state, so inspect the client rather than the server for it. Confirm grounded fold, visible Powered pulse and smooth glide transition on both clients, plus R6/R15 fitting and scaling. No Studio joint-upgrade setting change is required.

## Changed files

- `src/server/Services/WingsService.luau`: server state-only flight, native accessory setup/scaling, change-guarded publishing, immediate ground lift revocation and glide-latch removal.
- `src/client/Controllers/WingsController.luau`: independent local lift render callback; native/legacy joint posing, scale-aware mesh pulse and per-character visual transition.
- `src/shared/Constants/WingsConfig.luau`: 45 target, 300 acceleration, new 30 entry floor and 0.55 width minimum; unchanged duration and glide cap.
- `src/client/Controllers/HotbarController.luau`: rank table only.
- `tests/wings_flight.spec.luau`: server state/publish/dive/re-hold contracts, no server motion/ownership writes, sustained-ground cancellation.
- `tests/wings_input.spec.luau`: local lift gating, dt approach, entry burst, momentum/descent and local-player-only contracts.
- `tests/wings_pose.spec.luau`: separate native/legacy attachment pose, scale preservation, rebuild, width pulse and render-transition checks.
- `tests/fixtures/wings.luau`: native AddAccessory boundary with selectable rigid/weld attachment and supplied-style SpecialMesh.
- `tests/hotbar.spec.luau`: reordered expectations, preserved selection/key behavior and weapon compaction checks.
- `tests/run_state_tests.py`: independent presentation wings-pose suite registration.
- `tests/README.md`: updated suite descriptions and pending-work link.
- `docs/ANGEL_WINGS.md`: current lift-channel and tuning notes, pose blocker link.
- `docs/ANGEL_WINGS_FEEL_FIX.md`: this diff summary and pending acceptance record.

Preserved rules: no changes to JumpPower, purchased jump tiers, WalkSpeed/stamina, ownership/purchase flow, persistence, FallDamageService math/thresholds, hold sensor, separate controls/equip toggle, hotbar selection/keybind code, Backpack handoff, UI exports or art. Modified clients ignoring WingState remain outside this pass, as specified.
