-- Observe semantic output from real inventory/ingredient action boundaries.
local sfx = loadModule("GameplaySfxService")
sfx.Init()
local remote = shared.Events:FindFirstChild("GameplaySfx")
local events = {}
remote.FireAllClients = function(_, name, position)
    table.insert(events, { Name = name, Position = position })
end
local p = player(1)
local movement = loadModule("MovementService")
local object = ingredients.Spawn("Apple", frame(2, 3, 4), nil, true)
local position = object.Position
setup(inventory.CarryWorldItem(p, object), "normal pickup")
check(
    #events == 1 and events[1].Name == "IngredientPickup" and events[1].Position == position,
    "one pickup event preserves the removed object's world position"
)
table.clear(events)
local extra = ingredients.Spawn("Banana", frame(), nil, true)
local fullPlayer = player(1)
for _ = 1, inventory.GetCarryCapacity(fullPlayer) do
    carry(fullPlayer, "Apple")
end
table.clear(events)
check(not inventory.CarryWorldItem(fullPlayer, extra) and #events == 0, "capacity rejection is silent")
check(not inventory.CarryWorldItem(p, object) and #events == 0, "replayed pickup is silent")
movement.SetStunned(p, true)
check(inventory.ThrowHeld(p) == nil and #events == 0, "stunned intentional throw is silent")
movement.SetStunned(p, false)
local expectedOrigin = loadModule("IngredientThrow").Origin(p.Character:FindFirstChild("HumanoidRootPart")).Position
local thrown = inventory.ThrowHeld(p)
setup(thrown ~= nil, "intentional throw succeeds")
check(
    #events == 1 and events[1].Name == "IngredientThrow" and (events[1].Position - expectedOrigin).Magnitude == 0,
    "intentional ingredient throw emits once at origin"
)
table.clear(events)
check(inventory.ThrowHeld(p) == nil and #events == 0, "empty throw is silent")
setup(inventory.CarryWorldItem(p, thrown), "pick thrown ingredient back up")
check(#events == 1 and events[1].Name == "IngredientPickup", "reacquisition uses canonical pickup event")
table.clear(events)
movement.SetStunned(p, true)
setup(inventory.DropCarriedIngredients(p, "BatStun", vec(1, 0, 0)) == 1, "forced combat drop")
movement.SetStunned(p, false)
check(#events == 0, "forced combat scatter is silent")
ingredients.Consume(extra, true)
ingredients.Spawn("Apple", frame(), nil, true):Destroy()
check(#events == 0, "generic consume and destruction are silent")
carry(p, "Apple")
table.clear(events)
inventory.CleanupCharacter(p)
check(#events == 0, "character cleanup drops are silent")
carry(p, "Apple")
table.clear(events)
setup(inventory.InteractStash(p, 1, p), "store ingredient")
now += 2
setup(inventory.InteractStash(p, 1, p), "take ingredient")
check(#events == 0, "stash store and take are silent")
setup(inventory.ConsumeHeldIngredient(p, "Apple"), "consume carried ingredient")
check(#events == 0, "carried ingredient consumption is silent")
grant(p, "silent-smoothie")
table.clear(events)
inventory.ThrowHeld(p)
check(#events == 0, "existing smoothie release does not emit ingredient throw")
