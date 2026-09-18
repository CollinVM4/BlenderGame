# Be a Blender! (Project: BlenderGame)

**Pitch:** Run a giant blender shop, collect and steal ingredients, make smoothies, serve customers, earn cash, and upgrade your plot.

## Current Status

Playable MVP systems are implemented and actively being expanded.

Core systems currently include:
- Physical ingredient pickup, carry, throw, stash, and stealing
- Shared market ingredient spawns
- Blender ingestion and turbine-driven blending
- Three-ingredient smoothies
- Smoothie carry/stash ownership
- Customer requests and server-authoritative serving
- Cash rewards
- Day progression
- Upgrade/progression systems
- Presentation/VFX hooks
- Studio/dev utilities and automated regression coverage

Persistence is currently in-memory.

See [`docs/MVP_ARCHITECTURE.md`](docs/MVP_ARCHITECTURE.md) for architecture, service APIs, tags, Studio setup, filming utilities, and implementation notes.

---

## Core Gameplay Loop

1. Collect ingredients from the shared market.
2. Carry, stash, or steal ingredients.
3. Start the day.
4. Serve three customers.
5. Make each smoothie from exactly three ingredients.
6. Throw ingredients into the blender.
7. Spin the turbine to blend.
8. Dispense the smoothie.
9. Serve it to a customer.
10. Earn cash and continue upgrading/preparing.

Customer requests are based on ingredient tags such as color, sweetness, or temperature traits.

Serving and rewards are validated by the server.

---

## Architecture

The project is written in Luau and synced with Roblox Studio using **Rojo**.

### `src/server/`

Authoritative gameplay code.

- `init.server.luau`
  - Loads services
  - Injects dependencies
  - Initializes player/runtime state
  - Binds Workspace components

- `Services/`
  - Core backend systems
  - Own authoritative state and transactions
  - Examples: `InventoryService`, `BlendService`, `CustomerService`, `TycoonService`

- `Components/`
  - Workspace-facing interactables
  - Examples: turbine, stash, dispenser, market spawners, buttons

### `src/client/`

Client-side presentation and input.

- `init.client.luau`
  - Initializes controllers and UI

- `Controllers/`
  - Input handling
  - Remote/event listeners
  - Presentation coordination

- `UI/`
  - Prompt and interface presentation

### `src/shared/`

Shared definitions used by both server and client.

- `Constants/`
  - Ingredient definitions
  - Customer request definitions
  - Shared tuning/configuration

- Shared types and event definitions

---

## Authority Rules

The server is authoritative for:

- Inventory and carried items
- Stash state
- Blender/batch state
- Smoothie ownership
- Customer validation
- Cash and rewards
- Combat
- Stealing
- Progression

The client sends requests and renders presentation. It must not be trusted for gameplay state.

---

## Development Workflow

### Build in Roblox Studio

Use Studio for:
- Physical models
- Map layout
- Blender/station geometry
- Attachments
- Particle emitters
- Authored UI instances where appropriate
- Tags and attributes

### Script in the repository

Write gameplay logic in the Luau source tree and sync through Rojo.

Avoid placing standalone gameplay scripts directly in Studio when the logic belongs in the repository.

### Before large changes

1. Inspect the existing implementation.
2. Make the smallest compatible change.
3. Preserve working APIs where practical.
4. Run focused validation.
5. Report changed files and any required Studio setup.

---

## Testing

Tests are organized around:

1. Authoritative gameplay/state
2. Cross-system integration
3. Presentation/VFX
4. Studio-only smoke testing

Prefer durable behavioral contracts over implementation-detail assertions.

Run focused suites for the systems being changed, then broader regression only when appropriate.

---

## Project Notes

Important gameplay systems are still evolving. Some Studio-authored assets and presentation details may require manual verification even when automated tests pass.

For detailed implementation notes, use the files under `docs/`.