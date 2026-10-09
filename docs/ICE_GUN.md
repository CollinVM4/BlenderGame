# Ice Gun Game Pass and world display

The supplied Creator Store artwork is integrated through sanitized Rojo assets. IceGunService owns account entitlement and issued Tools; CombatService owns shared PvP eligibility/damage; FreezeStatusService adds a separate lock to MovementService. IceGunProjectileService runs one swept-ray simulation only while a projectile exists. No cash charge, SharedCash change, entitlement DataStore, ProcessReceipt handler or replacement shop UI was added.

**Purchases/grants remain disabled until you enter a real pass ID.** No Studio or published purchase/multiplayer play session was performed. Automated tests double MarketplaceService and engine physics.

## Required setup

1. In Creator Hub, select this published experience under Creations, then Monetization > Passes. Create an ICE GUN pass with an icon, description and category. Select its Sales settings, enable Item for Sale, set Price in Robux to **199**, and save. Copy the pass Asset ID from its thumbnail menu. Use this experience's own pass. [Roblox pass setup](https://create.roblox.com/docs/production/monetization/passes).
2. Set **IceGunGamePassId** in **src/shared/Constants/IceGunConfig.luau** to that pass ID. The configured pass is 2022020489; invalid IDs fail closed and print a server diagnostic. Sync/publish the configuration change. Model and mesh IDs are not pass IDs.
3. Sync default.project.json through Rojo. It supplies the safe gun, extracted original effects and safe pedestal template to ServerStorage; unrelated authored assets follow the existing ignore-unknown convention.
4. **Stop Play.** If the raw models were imported previously, copy and run **tools/studio_prepare_icegun.luau** in the **server Command Bar in Edit mode** after syncing. This removes executable legacy scripts before they can race startup. It retains the anchored union's CFrame and PointLight, removes its unassigned terrain weld and removes old IcicleGun copies while retaining the sanitized template.
5. Keep the existing Workspace EquipmentSpawner at its authored position. Startup binds all EquipmentSpawner BaseParts. For additional/differently named pedestals, add the **IceGunPurchaseDisplay** tag. If no existing display is present, startup clones the supplied sanitized union at its original exported CFrame.
6. Verify the runtime hierarchy below, save the sanitized place and run the manual checklist before publishing gameplay changes.

199 is the intended default Creator Hub price. Local UI calls GetProductInfoAsync(passId, Enum.InfoType.GamePass) and displays returned PriceInRobux. Regional/managed pricing can vary by player. Failed price lookup shows PRICE UNAVAILABLE; unknown ownership shows LOADING/UNAVAILABLE, never OWNED. Roblox's official purchase dialog remains the transaction authority. [Dynamic/regional pricing](https://create.roblox.com/docs/production/monetization/regional-pricing).

## Expected Explorer hierarchy

After Rojo sync and server startup:

~~~text
ServerStorage
├── Weapons [Folder]
│   └── IcicleGun [Tool; CanBeDropped=false]
│       ├── Handle [Part; Anchored=false, Massless=true, collision/touch/query=false]
│       │   ├── Mesh [original SpecialMesh]
│       │   ├── Launch [original Sound]
│       │   │   └── Mesh [original projectile SpecialMesh]
│       │   └── GunBarrel [original Attachment]
│       │       └── Smoke [original ParticleEmitter; continuous emission off]
│       ├── Animations [original Folder]
│       │   ├── R6 [empty in supplied export]
│       │   └── R15 [empty in supplied export]
│       └── ThumbnailCamera [original Camera]
├── IceGunEffects [Folder]
│   ├── Projectile [inert Part with original projectile Mesh]
│   ├── IceBlock [inert Part with original ice Mesh; transparency 0.4]
│   ├── SnowBullet [original ParticleEmitter]
│   ├── SnowSplosion [original ParticleEmitter]
│   ├── Shatter [original Sound]
│   └── FreezeEffects [Folder]
│       ├── IceCrack [original Sound]
│       ├── Puff [original ParticleEmitter]
│       ├── Shatter [original Sound]
│       └── FrostSparkles [original ParticleEmitter]
└── IceGunPedestalTemplate [original anchored UnionOperation]
    ├── PointLight [original, unchanged]
    └── Configurations
        └── SpawnCooldown [original IntValue; retained but unused]

Workspace
└── EquipmentSpawner [existing anchored UnionOperation, preserved position]
    ├── PointLight [original]
    ├── Configurations [may remain; ignored]
    ├── IceGunDisplay [runtime cosmetic Part; NOT a Tool]
    │   ├── Mesh [original gun mesh/texture]
    │   └── GunBarrel [original Attachment with inactive Smoke]
    └── PurchaseAttachment [runtime Attachment]
        └── IceGunPurchase [runtime ProximityPrompt]

ReplicatedStorage
├── Shared/Constants/IceGunConfig [Rojo ModuleScript]
├── IceGunRequest [runtime RemoteEvent: Purchase, Equip, Refresh]
└── IceGunFire [runtime RemoteEvent: aim Vector3 only]
~~~

An authorized owner's single runtime IcicleGun moves between Backpack and Character. Temporary projectiles, ice blocks and residue live in Workspace as inert effects and expire. They have no ingredient identity or IngredientWorldItem tag and are never registered with ingredient lifetime, farm, stash, theft, blender or Muncher systems. Ingredient cleanup protections were not relaxed.

## Original imports and removed scripts

Keep icegun.rbxmx and icegunspawner.rbxmx as source exports. They are **not mapped** into the live DataModel. Do not import raw exports into a running place; use assets/icegun files, already mapped through Rojo.

The preparation tool extracts original particles/sounds before deleting the legacy script hierarchy. Projectile and ice-block Parts were originally generated inside GunMain/Freeze; the tool retains that source's original mesh/texture IDs, scale, dimensions and ice transparency. It does not invent replacement artwork. Union Properties and PointLight are unchanged.

Removed from the generated gun: GunClient, GunMain, BulletScript, Freeze, DisableBackpack, EnableBackpack, MouseInput, Remote and TeamAttack. Removed from the generated pedestal: Script (the old free-tool loop) and the unused ManualWeld with null Part0. Its independent Anchored property was confirmed before removing the weld. Configurations.SpawnCooldown has no gameplay effect.

Regenerate and verify after updating raw exports:

~~~powershell
.\.venv\Scripts\python.exe tools\prepare_icegun_assets.py
.\.venv\Scripts\python.exe tests\test_icegun_assets.py
~~~

The Edit-mode setup utility is required for existing raw imports: runtime sanitization alone cannot guarantee an enabled legacy Script never runs before bootstrap. Required effect instances are already extracted into the safe Rojo mapping before removing the original hierarchy.

## Exact prompt placement and properties

The server creates Workspace.EquipmentSpawner.PurchaseAttachment.IceGunPurchase. An existing PurchaseAttachment is reused when it is an Attachment. A new attachment has local Position (0, 2.5, 0); adjust an authored attachment for the map if needed. Do not parent the prompt to the display gun.

| Property | Value |
|---|---|
| Style | Custom |
| KeyboardKeyCode | E |
| GamepadKeyCode | ButtonX |
| HoldDuration | 0 |
| MaxActivationDistance | 8 |
| RequiresLineOfSight | true |
| ClickablePrompt | true |
| ObjectText | ICE GUN |
| ActionText on server | LOADING, neutral fallback |
| IceGunPurchase attribute | true |

The existing InteractionPromptPresentation supplies touch/click input. IceGunDisplayController formats Fredoka text locally as ICE GUN / localized ROBUX price / BUY, or ICE GUN / OWNED / EQUIP. Server ActionText never changes to one player's ownership. Proximity, life, movement eligibility and line of sight are validated on the server and rechecked after yielded ownership lookups.

Original display height is retained: pedestal CFrame plus world Y of Handle.Size.Z / 2 + 1, followed by the original -90-degree X orientation. One local animator spins all displays around their original local Z axis at 35 degrees/second. Purchases and cancellation leave the display intact. It has no Tool activation, remotes, live scripts or touch pickup.

## Entitlement and future Framewisp shop

IceGunService.PlayerOwns(player) returns true, false or nil for unknown/unavailable ownership and may yield to Roblox. Confirmed ownership is cached for the server session; negative/failed checks are throttled for 15 seconds; concurrent checks coalesce. Purchase-finished handling forces a server recheck with bounded retries. Departure invalidates pending results.

RequestPurchase(player, optionalProximityValidator) checks entitlement, opens the official Game Pass dialog for verified nonowners or grants/equips for owners. Pending prompts prevent duplicate dialogs. The world point supplies its validator; the shop entry does not require proximity. Canceling leaves state unchanged.

GrantIfOwned(player) returns one issued Tool only when server-cached ownership is confirmed; it does not perform another yielding lookup. RequestEquip(player) uses that grant and the existing action gate. Death/removal clean old Tool/projectile state, respawn restores access, and joining rechecks account ownership. Plot changes neither transfer nor remove personal paid access.

The authored Framewisp Shop contains only an existing 2x Money entry with a 95 price label; no Ice Gun entry exists. It was preserved. Bind a later imported entry to src/client/Controllers/IceGunShopAdapter.luau:

~~~lua
Adapter.Init()
local function refresh()
    local state = Adapter.GetSnapshot()
    -- Update imported labels/buttons using Ownership, PriceText, CanBuy, CanEquip.
end
Adapter.Changed:Connect(refresh)
button.Activated:Connect(function()
    local state = Adapter.GetSnapshot()
    if state.CanEquip then
        Adapter.RequestEquip()
    elseif state.CanBuy then
        Adapter.RequestPurchase()
    else
        Adapter.Refresh()
    end
end)
refresh()
~~~

The UI caller owns its connections and teardown through the existing Framewisp lifecycle. Changed updates an open entry after ownership/price changes. The adapter only sends intent; it never grants or subtracts cash. No client success/target/damage remote exists.

## Combat, freeze and physics

IceGunConfig owns defaults: 70 studs/sec, 2-second cooldown, 14 HP direct damage, 0 splash, guaranteed direct-hit freeze, 1.6-second total freeze including 0.2-second formation, 3-second immunity after actual thaw, 110-stud range and 110/70-second projectile lifetime. One projectile per player is active at once. Server stalls cannot replay expired damage; a small final-frame scheduling tolerance applies.

The server requires a living current character, exact issued equipped Tool, confirmed entitlement, plot session, existing action gate and no PlatformStand. It bounds finite aim intent, rate-limits requests, validates barrel/root distance and determines launch clearance from server geometry. Obstructed/body-intersecting launches are rejected. Shots visibly travel and use swept raycasts rather than hitscan. Direct impact terminates once; world/NPC/friendly impacts shatter without damage. Current plot membership and the existing non-neutral Roblox Team check are shared with bat PvP at impact. Unassigned players retain the existing no-combat eligibility; ForceFields are respected.

MovementService tracks bat stun and freeze separately. Their aggregate lock controls speed, upgraded jump and gameplay actions and drives the existing client Stunned input attribute. SprintService observes it and does not drain attempted sprint during freeze. Existing bat and inventory/throw requests already use that action gate. Freeze does not clear carried inventory, forcibly unequip Tools, change ownership, hard-reset movement, anchor limbs, teleport or modify velocity. Thaw uses current upgrades; bat recovery cannot clear freeze, and thaw cannot clear bat stun.

The original cartoon block is noncolliding, nontouching, nonquerying and massless, welded to the torso outside the character descendant tree so CharacterPhysicsService does not retune it as a body part. It grows for 0.2 seconds and shatters at thaw with original frost/sounds and inert mesh shards. Airborne gravity/fall tracking remain intact. FallDamageService still reads the resolved jump upgrade, rather than temporary zero JumpPower. Humanoid.TakeDamage lets HealthRegenService observe weapon damage normally. RagdollService retains ownership of ragdoll physics/recovery.

Desktop Tool.Activated uses pointer/camera aim; mobile and gamepad use camera-center aim. CarryInputController passes primary weapon input through for Bat and IcicleGun; no new large mobile button was added.

## Automated validation

~~~powershell
.\.venv\Scripts\python.exe tests\run_state_tests.py --luau <luau.exe> --suite icegun-entitlement --suite freeze-status --suite icegun-combat --suite icegun-display
.\.venv\Scripts\python.exe tests\run_state_tests.py --luau <luau.exe> --suite icegun-presentation
.\.venv\Scripts\python.exe tests\test_icegun_assets.py
~~~

The gameplay suites cover verified/unknown/error entitlement, cancellation, concurrency, single grants, join/respawn, teammate independence, disabled IDs, proximity/LOS, current teams, swept movement, cooldown, direct-only damage, freeze/immunity, lock composition and cleanup. Presentation separately checks localized live text and desktop/touch/gamepad intent. Asset checks verify idempotence, unchanged union/light/mesh/sound/particle data and removal of legacy authority.

Feature suites and existing carry-input, fall-damage and health-regen suites pass. Roblox-aware analysis of new feature modules and touched movement/input/prompt modules passes. Full-src analysis retains the same 14 unique error signatures as a pre-feature snapshot: CustomerRequests, existing bat optional typing, CustomerService and JackedNoobService. There are no new signatures. StyLua and Rojo build pass.

Baseline-reproduced failures are isolated: sprint fails StandIdentity default-name fixture setup; bat fails upgrade setup; shared interaction prompts fail an existing stash text expectation; runner self-tests retain four stale manifest/bundle expectations. Unrelated production systems were not changed to satisfy them.

## Studio/manual acceptance checklist

CLI doubles do not prove replication, Creator Store permissions or physical behavior. These checks remain manual:

- ID 0: diagnostic, UNAVAILABLE display, no prompt/grant. Then test owner/nonowner accounts with the real pass in the published experience. Edited attributes and Studio simulated purchases are not proof of actual entitlement.
- Test cancellation, verified purchase, slow/failed ownership lookup, existing-owner equip, repeated E, simultaneous shoppers, death/respawn, rejoin, joining an owner's plot and switching plots. SharedCash must stay unchanged.
- Compare pedestal CFrame, union/light appearance, height and original-axis rotation. Verify display persists after purchases/cancels; no free Tool pickup or old 5-second loop exists. Wait through ingredient cleanup and attempt stash/theft/throw/blender/Muncher interactions with the display.
- With two enemy plot sessions, fire at walls, moving/dodging players and direct targets. Confirm readable 70-stud travel, 2-second cooldown, 14 HP, no splash, 110-stud cutoff and original sound/smoke/trail/shatter. NPC customers must ignore Ice Gun while bat behavior remains intact.
- Check 0.2-second formation and 1.6-second total freeze. During the next 3 seconds, direct hits damage without another block. Lethal hits/death/reset clean the block. Change team membership between launch/impact and verify protection.
- Freeze players with upgraded Jump/Sprint and carried ingredients: block move/jump/attacks/throw, retain inventory, avoid stamina drain and restore controls/upgrades. Hit airborne/ragdolled targets; verify normal falling/recovery, no extra/duplicate fall damage, no anchored parts/solid platforms and normal health-regen delay.
- Isolated status smoke test in the Studio Play server Command Bar after bootstrap: game.ServerStorage.StudioServiceCalls:Invoke("FreezeStatusService", "Apply", game.Players:GetPlayers()[1]). This exercises live freeze without changing entitlement. Use verified account ownership for gun/grant tests.
- Test desktop mouse/click, touch camera/activation alongside Throw/Sprint in Device Emulator, console R2/camera aim and R6/R15 torso visuals. Supplied animation folders are empty, so default Tool pose remains. Confirm original mesh/texture/audio permissions and real rendering in this experience.

## Changed and new files

New assets: assets/icegun/IcicleGun.rbxmx, EquipmentSpawner.rbxmx, IceGunEffects.rbxmx.

New runtime files: src/shared/Constants/IceGunConfig.luau; src/server/Services/IceGunService.luau, IceGunProjectileService.luau, IceGunEffects.luau, FreezeStatusService.luau; src/server/Components/IceGunDisplay.luau; src/client/Controllers/IceGunController.luau, IceGunDisplayController.luau, IceGunShopAdapter.luau.

New setup/tests/docs: tools/prepare_icegun_assets.py, tools/studio_prepare_icegun.luau; tests/fixtures/icegun.luau; tests/icegun_entitlement.spec.luau, freeze_status.spec.luau, icegun_combat.spec.luau, icegun_display.spec.luau, icegun_presentation.spec.luau, test_icegun_assets.py; docs/ICE_GUN.md.

Changed: default.project.json; src/server/init.server.luau; src/client/init.client.luau; src/server/Services/MovementService.luau, SprintService.luau, CombatService.luau; src/client/Controllers/CarryInputController.luau; src/client/UI/InteractionPromptPresentation.luau (optional local text formatter); tests/run_state_tests.py (suite/source registration).

Raw exports and pre-existing/concurrent farm, Framewisp, initial-spawn and validation-place changes are not edits made for this feature.

See [Studio simulation and prompt repair](ICE_GUN_STUDIO_TESTING.md) for the opt-in setting, security boundaries, validation, diagnostics, and two-client acceptance tests.
