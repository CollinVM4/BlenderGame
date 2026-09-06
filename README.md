# Be a Blender! (Project: BlenderGame)

**Pitch:** Run a giant blender, collect and steal ingredients, serve customers with loose preferences, earn cash, and upgrade your plot.

**Current status:** Executable architecture skeleton. See [MVP architecture and Studio setup](docs/MVP_ARCHITECTURE.md) for service APIs, tags, filming commands, validation, and intentionally unfinished features. Data is in memory; a complete playable release still requires Studio assets and client interaction work.

## Core Gameplay Loop

Prepare at the shared market and stash ingredients → Start Day → serve three customers → receive a Day grade → upgrade/prepare and repeat.

Each smoothie uses 1–3 owned physical units thrown into the blender opening. Turn the turbine, dispense the finished cup, and serve any combination. Customer preferences use ingredient tags; special recipes unlock discoveries. Customer grade affects payout, while reaction selection is independent.

---

## Technical Architecture & Workflow

This project uses a modular, scalable architecture synced via **Rojo**. Code is strictly separated into Client, Server, and Shared boundaries to prevent exploitation and keep features decoupled. 

### File Structure Guide

* **`src/server/` (ServerScriptService)**
  * **`init.server.luau`**: The server bootstrapper. This script explicitly loads services, injects dependencies, initializes player state, and then binds Workspace components.
  * **`Services/`**: Singleton modules that handle core backend game logic (e.g., `TycoonService.luau`, `CustomerService.luau`). Services manage state, validate transactions, and communicate with the client.
  * **`Components/`**: Object-oriented modules bound to physical Workspace parts (e.g., `TurbineWheel.luau`, `Dispenser.luau`). These handle localized logic for interactables.

* **`src/client/` (StarterPlayerScripts)**
  * **`init.client.luau`**: The client bootstrapper. Initializes all Controllers and UI logic as soon as the player joins.
  * **`Controllers/`**: Singleton modules that handle client-side input, remote event listening, and visual effects (e.g., `UIController.luau`).
  * **`UI/`**: Modules dedicated to rendering and managing screen elements (e.g., `ScreenGuis.luau`), keeping presentation separate from logic.

* **`src/shared/` (ReplicatedStorage)**
  * **`Constants/`**: Static data tables shared between the server and client (e.g., `Recipes.luau`). Changing a recipe here updates it everywhere.
  * **`Events/`**: RemoteEvents and RemoteFunctions (e.g., `Hello.luau`) used for secure client-server communication.

### Development Guidelines
1. **Never build in VSCode:** Use Roblox Studio to build physical models (blenders, workstations) and place UI elements.
2. **Never script in Studio:** Write all logic inside VSCode. Rojo will sync it into the DataModel automatically.
3. **Trust the Server:** The client only sends requests (e.g., "I clicked Serve"). The server verifies the recipe and awards the cash.
