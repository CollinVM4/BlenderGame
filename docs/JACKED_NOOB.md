# Jacked Noob Protein NPC

In Studio, set the R6 NPC Model's `NPCId` attribute to `JackedNoob`. Keep the authored model in Workspace with its `Humanoid`, `HumanoidRootPart`, `Head`, and existing `Animate` controller. Add an anchored rectangular `NoobRoam` BasePart to Workspace. Its X/Z size and rotation define the roam area. The existing `ServerStorage/Ingredients/Protein` model is used by the normal ingredient geometry path when present.

The server disables NPC-local scripts named `Move` and `Respawn` when it binds the model, including in respawn clones. They can also be removed from the Studio rig. `Animate` remains active. The service clones the original rig at its authored pivot roughly five seconds after death.

The head gets a custom `[E] TALK` prompt. The server checks the live player, distance, cooldown, and carry capacity, then calls `InventoryService.GrantIngredient`. Successful grants create a normal per-item ID and held ingredient visual and start a personal 90-second cooldown. Failure leaves that timer unchanged. The response appears above the NPC only for the player who talked.

The NPC waits two to six seconds between Humanoid `MoveTo` walks. Destinations are sampled in `NoobRoam` local X/Z coordinates with a 2.5-stud inset, then transformed to world space. When displaced beyond the area, it walks toward a clamped point inside. Its cooldown table lives in the service and persists across NPC death.

Focused tests: `py tests/run_state_tests.py --suite jacked-noob --suite jacked-noob-inventory --luau <luau executable>`. Studio smoke check: confirm walking and idle animations, roaming inside a rotated zone, prompt while walking, owner-only response, per-player cooldown, full carry behavior, and respawn at the authored pivot.
