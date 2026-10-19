# Multiplayer PC ingredient throw investigation

## Verified defects and limits

The desktop CAS callback returned Pass whenever UserInputService.TouchEnabled was true. That property describes device capability: a touchscreen PC using a physical mouse was disabled before sending any ThrowHeld request. A baseline probe reproduces a pickup followed by a physical mouse click leaving inventory unchanged. This is independent of avatar proportions.

The server also spawned at HRP * CFrame.new(0, 2, -5) for every ingredient and avatar. It checked neither the avatar's forward extent nor the ingredient volume nor world geometry. A baseline regression fails the clearance invariant for a short, wide/deep character. A large forward accessory can cover that fixed origin as well. Existing temporary NoCollisionConstraints prevented some immediate self-collisions but did not make an embedded world spawn valid.

These defects are verified in the implementation and CLI regressions. No trace from the friend's original session was available, so their exact failure cannot honestly be attributed to either defect yet. Real Roblox physics and network replication have not been run in this session.

## Pipeline findings and resulting behavior

| Stage | Finding / fix |
| --- | --- |
| Desktop input | Replaced mouse CAS binding with UIS InputBegan. Accept MouseButton1 on a mouse-capable device even when TouchEnabled is true. Touch gestures and touch-only synthesized mouse are ignored. |
| UI / competing actions | Honor gameProcessedEvent and focused text boxes. The mouse handler does not sink input. Equipped BatLevel/IceGunWeapon Tools retain primary activation. Repository CAS bindings do not otherwise bind MouseButton1; the Studio snapshot lists actual runtime bindings and priorities. |
| Request | Send only ThrowHeld, with no position, aim, ownership, or selected carry identity. Mobile CAS Throw and ButtonR2 still use the shared throw callback. |
| Remote validation | Existing per-player 0.15s gameplay throttle, movement gate and authoritative Bat check remain. No plot ownership/session gate is added to throwing. Input requests prefer the equipped item, with newest available ingredient as fallback on the server; explicit server-selected-ID APIs remain compatible. Equipped smoothies retain their existing selection behavior. |
| Held record | Resolve only the caller's authoritative, available held records. CarryCount and Tools never grant inventory. Dead/missing humanoids or roots reject. |
| Spawn preparation | Prepare the actual world template privately. Calculate a conservative pivot-centered radius, including off-center multipart geometry. Project body/accessory oriented bounds along the server root facing direction. Exclude Tools and IngredientCarryVisuals from body clearance. |
| World clearance | Choose a forward spawn beyond the body's forward extent and ingredient radius, with padding. Prefer the existing five-stud distance where safe; try a closer safe distance when a wall blocks that preference. Reject clearance over 32 studs. Height uses root/item dimensions, never Head height or cursor hits. |
| Queries / collisions | Exclude the whole thrower's current character from vertical ray, swept volume and initial/final overlap checks; respect collidable world geometry. Initial overlap explicitly covers the engine Blockcast limitation. Other players and world geometry remain blockers. Existing 0.2s pairwise collision grace remains, with world/blender/teammate collision groups unchanged. |
| Inventory -> world | Optional PrepareSpawn runs before BeforePublish. Unsafe preparation destroys only the unpublished visual and retains the held reservation. Successful preparation clears exactly one reservation before publication; impulse stays facing * 25 + (0, 18, 0), with server network ownership. |

CharacterPhysicsService still normalizes description scales after appearance loading, sets a standard root size/mass, and makes ordinary cosmetics noncolliding/nonqueryable. It preserves avatar mesh assets and body collision behavior. Throw placement reads the current actual parts, so it does not rely on normalization succeeding or a standard body package. Carry presentation still uses the head for overhead display only; that geometry is excluded from clearance. Neither service needed modification.

Roblox input reference: [UserInputService](https://create.roblox.com/docs/reference/engine/classes/UserInputService) documents the processed-input flag and device capability properties.

## Diagnostics

No new Studio assets or collision-group setup are required. Sync with Rojo and restart Play so the old mouse CAS binding is gone. In Server Command Bar, enable the affected player (or both players):

```luau
for _, player in game:GetService("Players"):GetPlayers() do
    player:SetAttribute("ThrowDebug", true)
end
```

Logs are off by default and can be enabled during Play. Capture Client and Server Output together. Expected sequence:

1. `[ThrowInput] mouse received processed=...` -> ignored reason or request sent.
2. `[ThrowServer] request received` -> throttle/action/Bat rejection or held record ID.
3. Placement result: obstructing instance and failing height/initial volume/path/destination gate, or clear origin/radius/avatarFront/distance.
4. Published world item and remaining CarryCount, or failed preparation/release with inventory retained.

Run `tests/studio_throw_diagnostics.luau` in Server and each Client Command Bar for a read-only snapshot of remotes, input capability, equipped tools, actual body/accessory/carry geometry, and live CAS bindings. This file is not mapped into production. Disable ThrowDebug after capture by setting it to false on the server.

## Regression coverage and validation

Authoritative home: `ingredient_throw.spec.luau` covers standard, short/wide/deep and tall bounds, rotated facing, three-ingredient equipped-preferred release with newest fallback and older equipped ingredient selection, unchanged velocity, actual world publication, accessory clearance, all four obstruction gates, retention on rejection, recovery, safe nearer-wall fallback, and opt-in logging. Carry capacity is fixture setup here rather than testing upgrade purchases in the throw suite.

Input integration: `carry_input.spec.luau` covers hybrid and standard PC clicks without world targets, GUI/CAS-consumed clicks, touch gestures/synthesized mouse, focused text, stun, Begin-only activation, rate limiting, older hotbar selection with equipped-preferred throwing, Bat/Ice Gun conflicts, mobile/gamepad shared action, dead players and forged Tools.

Multiplayer integration: `throw_multiplayer.spec.luau` uses the real shared plot session and inventory services. It covers two teammates' independent ownership, foreign carry identities, simultaneous actor eligibility, loose-world ownership release, teammate obstruction with retained inventory, respawn cleanup, fresh tall-character pickup/throw, current-root use and preservation of the other actor's inventory.

Existing carry, ingredient-slots, carry-selection and throw-to-blender integration suites also pass. Explicit selected identity remains compatible for server calls and stash behavior. Seven focused suites pass. Changed-runtime Roblox-aware typechecking, StyLua, Rojo build and whitespace validation pass. Baseline substitutions leave the working tree unchanged: original desktop input fails the hybrid mouse probe; original server placement fails the short/wide clearance invariant.

The separate Python runner-contract suite has four stale expectations (VFX entry detection, presentation order, smoothie manifest, and state manifest). All four reproduce identically with the baseline runner; they were isolated and not changed.

CLI vectors/instances/query results are engine doubles. Avatar tests exercise geometry contracts, not live R15 animation, Marketplace accessories, touch synthesis, or replication. Physical trajectory and GUI processing acceptance must be checked in Studio:

1. Start a two-client test, join one shared stand, and enable ThrowDebug on both players. Test standard R15, the friend's exact short/wide body package, tall R15, and large forward/back/head accessories. CharacterPhysicsService's final trace and the throw snapshot establish the actual post-normalization geometry.
2. Pick up three different ingredients on each client. Select an older ingredient, left-click clear sky and empty space, then throw repeatedly with more than 0.15s between clicks. Each click must publish the newest ingredient exactly once; each player's inventory is independent. Confirm the item visibly clears their body and enters the world with normal impulse.
3. Repeat near walls, beneath low ceilings, beside blender geometry and with a teammate in front. A safe nearer spawn is allowed; genuinely blocked throws must keep the item and log the obstruction. Never spawn through a wall or inside either avatar.
4. Click menus, hotbar, text boxes and other GUI; carry must not change. Equip Bat and Ice Gun: primary clicks must activate only the weapon. Inspect the runtime CAS list if another action consumes input.
5. Repeat on a touchscreen PC with a physical mouse, mobile Device Emulator plus a physical device, and gamepad R2. Joystick/camera/world touch gestures must not throw; the mobile Throw button must still work.
6. Die and respawn on each client, reacquire ingredients, and repeat with the fresh avatar. Verify no old character/held reservations drive the throw, no duplication/loss, and the teammate's items remain intact.

## Files changed

Runtime: CarryInputController, GameplayService, IngredientService (optional preparation hook), IngredientThrow, InventoryService. Tests: carry_input, ingredient_throw, new throw_multiplayer, shared Roblox query/ancestor/CFrame doubles and character-relative carry fixture, multipart throw-to-blender clearance, runner suite registration, and new Studio snapshot. Existing unrelated Ice Gun and combat working-tree edits were preserved.
