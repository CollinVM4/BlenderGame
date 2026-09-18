# Be a Blender!

Roblox game written in Luau and synced with Rojo.

## Architecture

- `src/server/Services`: authoritative server systems.
- `src/server/Components`: Workspace-facing components.
- `src/client`: client controllers and UI.
- `src/shared`: shared types and configuration.
- `default.project.json`: Rojo mappings.

## Core Rules

- Server authoritative for inventory, cash, combat, blending, rewards, stealing, and other gameplay state.
- Never trust client-provided gameplay state.
- Avoid circular service dependencies.
- Preserve working systems unless refactoring has a clear benefit.
- Prefer data-driven ingredient/customer definitions.
- `GameService` orchestrates the gameplay cycle; do not turn it into a god module.
- `BlendService` owns blender/batch state.
- `InventoryService` owns carried/stored item ownership and lifecycle.
- Customer grade and customer reaction are separate systems.

## Workflow

For large or risky changes:

1. Inspect the relevant implementation first.
2. Make the smallest compatible change.
3. Preserve existing APIs where practical.
4. Run focused validation.
5. Report changed files, important behavior changes, and required Studio setup.

Do not broaden scope to unrelated systems unless necessary.

## Testing

Test durable gameplay contracts, not implementation details or raw assertion count.

- Run the smallest relevant focused suites first.
- Run integration tests only when changes cross systems.
- Always run typecheck, StyLua, and Rojo build for code changes.
- Do not run unrelated movement, VFX, presentation, or legacy suites by default.
- Reserve broad regression runs for milestones/stabilization.

Each core behavior should have one authoritative test home. Feature tests should cover only behavior unique to that feature.

Prefer observable invariants over assertions about private tables, connection counts, cleanup order, weld hierarchy, repeated setup state, or internal event sequencing.

Keep tests separated into:
1. Authoritative gameplay/state
2. Cross-system integration
3. Presentation/VFX
4. Studio-only smoke tests

Presentation failures must not block authoritative gameplay tests.

If an unrelated test fails, confirm whether it reproduces on baseline, isolate/report it, and do not change unrelated production code just to make the current feature pass.