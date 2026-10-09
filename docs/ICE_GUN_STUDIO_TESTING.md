# Ice Gun Studio purchase simulation and prompt repair

## Enable testing

Set **StudioGamePassSimulation = true** in **src/shared/Constants/IceGunConfig.luau**, sync Rojo, and start a fresh Studio Server & Clients session. The checked-in default is **false**. The pass remains **2022020489**. No additional Studio Instances are required beyond the existing sanitized assets and EquipmentSpawner setup. Restore false before publishing.

## Security and entitlement design

StudioIceGunEntitlement is a server-only, session-local provider keyed independently by Player. Every gate must pass: RunService:IsServer(), RunService:IsStudio(), explicit configuration, negative UserId, and the configured Ice Gun pass ID. No client ownership flags, admin entitlement remote, or DataStore are involved. Departure clears mock access; a new server starts empty. Death preserves mock access.

IceGunService sets Pending before opening the normal official Roblox purchase dialog. For supported synthetic players, a matching server Marketplace completion consumes Pending; only the boolean true marks mock ownership. Cancel, wrong player/pass, unsolicited completion, and replay cannot create entitlement. PlayerOwns publishes the same IceGunOwnership snapshot and GrantIfOwned issues the same sanitized IcicleGun, enforcing one authorized Tool. Respawn and GetEquipped/firing use this common entitlement path.

Positive IDs and all published servers retain UserOwnsGamePassAsync, confirmed ownership caching, official dialogs, verification retries, and existing fail-closed errors. A success event alone still cannot grant a production nonowner. Accidentally leaving the flag enabled cannot activate simulation in published servers. Artwork, rotation and combat tuning were preserved.

## Invisible prompt root cause

IceGunDisplayController passed PurchaseDistance (8) as BillboardGui.MaxDistance. The interaction distance is measured from the character; BillboardGui.MaxDistance is measured from the camera. A third-person camera can exceed eight studs while the character is close enough for PromptShown and E, leaving a created custom GUI culled. The native prompt does not have this extra cutoff. See [Roblox BillboardGui documentation](https://create.roblox.com/docs/reference/engine/classes/BillboardGui).

The Ice Gun now passes math.huge to the existing InteractionPromptPresentation. Native PromptShown/PromptHidden still controls character proximity, occlusion, and exclusivity. Global prompt styles and unrelated interaction distances are unchanged. Fredoka and shared touch/click input remain in use.

The dedicated renderer was also the last synchronous bootstrap call after menu and remote initialization that can yield. It now starts in an early independent task. The generic interaction controller explicitly leaves IceGunPurchase to its dedicated renderer; Custom-style and Attachment filtering remain.

Server snapshots IceGunOwnership and IceGunEquipped update the existing GUI to BUY, EQUIP or EQUIPPED. Price comes from client GetProductInfoAsync for the current localized price, with a price-unavailable fallback. The code defect and camera semantics are established; an actual Studio playtest must still confirm rendering in this map.

## Diagnostics

Run in the Studio client Command Bar:

```lua
local gui = game:GetService("Players").LocalPlayer.PlayerGui
print("Ice Gun renderer registered:", gui:GetAttribute("IceGunPromptRendererRegistered"))
gui:SetAttribute("DebugIceGunPrompt", true)
```

The registration marker is set after engine listeners connect. A missing marker identifies bootstrap/require failure; inspect client Output. The generic controller warns if it receives Ice Gun PromptShown while the dedicated renderer is unregistered.

Opt-in logs show PromptShown/PromptHidden, GUI creation, and snapshots every five seconds: rejected attribute/parent/style, no engine view and shown count, created-but-hidden GUI, missing ownership, character range, camera occlusion, RequiresLineOfSight, Exclusivity, service enabled/MaxPromptsVisible, and other visible prompts. Occlusion is a diagnostic ray estimate; the engine determines actual visibility. Suppression is reported as a possible cause. Walk out and back in to capture events. Set DebugIceGunPrompt false to stop logs; published clients never emit them.

## Studio acceptance tests

### A: First purchaser

1. Enable simulation, sync Rojo, and start one server with two clients in Server & Clients. Confirm both UserIds are negative.
2. Approach EquipmentSpawner as Player1. Confirm ICE GUN / current localized price / [E] BUY in cyan Fredoka, including with the camera farther than eight studs.
3. Cancel once: no Tool and BUY remains. Retry and complete the normal simulated purchase.
4. Confirm exactly one IcicleGun in Backpack and OWNED / EQUIP. Press E to equip; confirm OWNED / EQUIPPED and normal firing. Repeated E must reuse that Tool.
5. Player2 must remain unowned with no weapon and BUY on their own client.

### B: Second purchaser and combat

1. Player2 independently completes the simulated purchase; confirm exactly one gun each and independent EQUIP/EQUIPPED states.
2. Fight from separate eligible plot sessions without spawn ForceFields: 70 studs/sec, two-second cooldown, 14 HP direct damage, guaranteed 1.6-second freeze, three-second re-freeze immunity, and no splash.
3. Join the same plot session and confirm teammate protection.
4. Check touch in Device Emulator (TAP) and connected gamepad (ButtonX), including purchase/equip and cleanup when leaving range or removing the display. Check nearby ingredient/dispenser/stash/NPC prompts retain their presentation.

### C: Respawn and fresh session

1. Reset Player1. Confirm ownership survives, exactly one gun returns, equip/fire works, and Player2 remains independent.
2. Stop and restart the session; both synthetic players must start unowned without weapons.

### D: Production verification

1. Disable simulation and sync. Confirm real creator ownership still grants and synthetic simulated completion alone does not.
2. Separately test a genuine nonowner purchase in a published game: localized dialog, real ownership verification, one issued gun, equip/fire, and respawn.
3. Automated guards cover IsStudio false even with opt-in true; an optional private published-place test can confirm this boundary. A reported completion must never grant without real ownership.

## Changed files

Source: new src/server/Services/StudioIceGunEntitlement.luau; modified src/server/Services/IceGunService.luau, src/shared/Constants/IceGunConfig.luau, src/client/Controllers/IceGunDisplayController.luau, src/client/Controllers/IceGunShopAdapter.luau, src/client/Controllers/InteractionPromptController.luau, and src/client/init.client.luau.

Tests: modified tests/fixtures/icegun.luau, tests/icegun_entitlement.spec.luau, tests/icegun_presentation.spec.luau, tests/run_state_tests.py; new tests/icegun_simulated_combat.spec.luau. Simulation reuses the existing combat spec so combat contracts retain one authoritative home. The fixture equips into Humanoid.Parent to correctly model transferred respawn characters. Documentation: this guide and docs/ICE_GUN.md.

## Validation results — 2026-10-09

All six focused suites pass: icegun-entitlement (51 behavioral assertions), icegun-combat (34), icegun-simulated-combat (34), freeze-status (17), icegun-display (9), icegun-presentation (29). Presentation runs the real shared renderer rather than a stub. Mobile prompt compatibility passes (68 assertions). Changed-file StyLua check and Rojo build pass.

Full Roblox-aware typechecking remains nonzero with the same 216 TypeError diagnostics reproduced on a snapshot of the pre-change working tree, with no added feature errors. Existing diagnostics include CustomerRequests and unrelated service typing. The standalone interaction prompt suite fails at "stash store retains key and action" identically on that baseline; it was isolated and unrelated production code was left unchanged.

```powershell
.\.venv\Scripts\python.exe tests/run_state_tests.py --luau <luau.exe> --suite icegun-entitlement --suite icegun-combat --suite icegun-simulated-combat --suite freeze-status --suite icegun-display --suite icegun-presentation
.\.venv\Scripts\python.exe tests/run_mobile_prompt_tests.py --luau <luau.exe>
stylua --check <changed Luau files>
rojo sourcemap default.project.json --output <sourcemap.json>
luau-lsp analyze --platform roblox --sourcemap <sourcemap.json> --definitions <globalTypes.d.luau> src
rojo build default.project.json --output <IceGun.rbxlx>
```

CLI suites use mocked engine boundaries. No Studio multiplayer or published-game session was executed. Real dialogs, replication/rendering, mobile/gamepad layout, and a genuine published purchase remain the manual checks above.
