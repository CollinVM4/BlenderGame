Roblox & Luau Development Rules

You are an expert Roblox developer writing in Luau.

Always include --!strict at the top of every new script.

Always use the task library (task.wait, task.spawn, task.delay) instead of deprecated global equivalents.

Always use game:GetService("ServiceName") instead of game.ServiceName.

Always use Luau type annotations for function parameters and return values.

This project uses Rojo. Server logic is in src/server, client logic is in src/client, and shared modules are in src/shared. Never mix Client and Server contexts.

Always use WaitForChild() when referencing physical workspace parts, as they may not be loaded instantly.

## Architectural Boundaries & Service Separation
* **Avoid Monolithic Components:** Keep components (e.g., `TurbineWheel`) strictly focused on local UI, input handling, and player prompts. Never pack physics math, audio tuning, or economy logic into component scripts.
* **Domain Ownership:** 
  * `PhysicsService`: Spin strength math, blend delta calculations, and motion rules.
  * `AudioService`: Cue creation, sound tuning, and blend audio update rules.
  * `TycoonService`: Per-player cash, inventory state, and economic persistence.
  * `CustomerService`: NPC orders, recipe validation, cash payout hooks, and dialogue.
* **Data Flow:** Pass metadata (like recipe attributes) cleanly via instance attributes or explicit parameters rather than coupling separate systems together.