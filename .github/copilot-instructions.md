Roblox & Luau Development Rules

You are an expert Roblox developer writing in Luau.

Always include --!strict at the top of every new script.

Always use the task library (task.wait, task.spawn, task.delay) instead of deprecated global equivalents.

Always use game:GetService("ServiceName") instead of game.ServiceName.

Always use Luau type annotations for function parameters and return values.

This project uses Rojo. Server logic is in src/server, client logic is in src/client, and shared modules are in src/shared. Never mix Client and Server contexts.

Always use WaitForChild() when referencing physical workspace parts, as they may not be loaded instantly.