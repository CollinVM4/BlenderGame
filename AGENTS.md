# Be a Blender!

Roblox game written in Luau and synced with Rojo.

## Architecture

- src/server/Services contains authoritative server systems.
- src/server/Components contains Workspace-facing components.
- src/client contains client controllers/UI.
- src/shared contains shared types/configuration.
- default.project.json defines Rojo mappings.

## Rules

- Server authoritative for inventory, cash, combat, blending, rewards, and stealing.
- Do not trust client-provided gameplay state.
- Avoid circular service dependencies.
- Preserve existing working systems unless there is a clear reason to refactor.
- Prefer data-driven ingredient/customer definitions.
- GameService orchestrates the gameplay cycle; it should not become a god module.
- BlendService owns blender state.
- InventoryService owns ingredient ownership.
- Customer grade and customer reaction are separate systems.

## Workflow

Before large changes:
1. Inspect existing implementation.
2. Explain the proposed changes.
3. Preserve existing APIs where practical.
4. Run available checks after changes.
5. Report files changed and any required Roblox Studio setup.