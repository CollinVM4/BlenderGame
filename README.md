# Be a Blender! (Project: BlenderGame)

**Pitch:** You are running a giant smoothie station take orders from customers and serve for $
**Category:** Tycoon, Time Management. 

## Core Gameplay Loop

**Take Order** 
A person walks up to the counter edge with a speech bubble
 e.g. 1/3 Strawberry + 1/3 Ice Cube + 1/3 banana 
Button to dispense ingredients
Fill a % based on recipe 

**The Spinning Wheel**
Run down to a turbine. spinning the wheel turns the blades, blending the fruit, and progressing the blend meter.

**Dispense Smoothie**
Jump on a hanging rope pulled down by your weight to open the valve and fill the cup.

**Serve Customer and Payout**
Hand off the smoothie, collect massive stacks of cash and buy upgrades

[END LOOP]

---

## Technical Architecture & Workflow

This project uses a modular, scalable architecture synced via **Rojo**. Code is strictly separated into Client, Server, and Shared boundaries to prevent exploitation and keep features decoupled. 

### File Structure Guide

* **`src/server/` (ServerScriptService)**
  * **`init.server.luau`**: The server bootstrapper. This script loops through all Services and Components to initialize them on game start.
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