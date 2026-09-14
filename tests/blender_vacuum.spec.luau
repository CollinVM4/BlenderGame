env.require = loadModule
workspaceFake.FindFirstChild = function()
    return nil
end
local heartbeat = signal()
services.RunService.Heartbeat = heartbeat
local ingredients = loadModule("IngredientService")
local tycoon = loadModule("TycoonService")
tycoon.Init({})
local function plotFor(id, x)
    local player, plot = instance("Player"), instance("Model")
    player.UserId, player.Name = id, "Player" .. id
    plot.Name, plot.Parent = "Plot" .. id, workspaceFake
    services.CollectionService:AddTag(plot, "PlayerPlot")
    tycoon.AssignPlot(player)
    local input, zone = instance("Part"), instance("Part")
    input.Name, input.Parent, input.Position, input.Size = "InputZone", plot, vec(x, 0, 0), vec(3, 1, 3)
    zone.Name, zone.Parent, zone.Size = "VacuumZone", plot, vec(5, 5, 5)
    services.CollectionService:AddTag(input, "BlenderInput")
    services.CollectionService:AddTag(zone, "BlenderVacuum")
    return player, plot, input, zone
end
local owner, plot, input, zone = plotFor(1, 0)
local other, otherPlot, otherInput, otherZone = plotFor(2, 4)
local deps = { IngredientService = ingredients, TycoonService = tycoon }
local physics, config = loadModule("BlenderVacuumPhysics"), loadModule("BlenderVacuum")
local function component(name)
    local chunk = assert(loadstring(sources[name .. "Component"]))
    setfenv(chunk, setmetatable({ script = { Parent = { Parent = { Services = parent } } } }, { __index = env }))
    return chunk()
end
local function spawn(ownerValue, claimable, id)
    local item = ingredients.Spawn(id or "Banana", frame(2, 4, 0), ownerValue, claimable)
    local root = cache.WorldUtil.Part(item)
    root.Position = vec(2, 4, 0)
    root.AssemblyLinearVelocity = vec(10, 5, 0)
    root.GetConnectedParts = function()
        return {}
    end
    return item, root
end
local function same(a, b)
    return (a - b).Magnitude < 0.00001
end
component("BlenderVacuum").Init(deps)
local item, root = spawn(owner)
zone.Overlaps = { item }
local startPosition, startVelocity = root.Position, root.AssemblyLinearVelocity
heartbeat:Fire(1 / 60)
check(root.AssemblyLinearVelocity.X < startVelocity.X, "valid registered ingredient steers inward")
check(root.AssemblyLinearVelocity.Y < startVelocity.Y, "valid ingredient steers downward")
check(same(root.Position, startPosition), "vacuum never teleports")
check(root.AssemblyLinearVelocity.X > 0, "first update preserves outward throw momentum")
check(
    (root.AssemblyLinearVelocity - startVelocity).Magnitude <= config.MaxAcceleration / 60 + 0.0001,
    "acceleration bounded"
)
check(ingredients.GetRecord(item) ~= nil, "vacuum does not consume")
local simultaneous, simultaneousRoot = spawn(owner)
zone.Overlaps = { item, simultaneous }
heartbeat:Fire(1 / 60)
check(
    simultaneousRoot.AssemblyLinearVelocity.X < startVelocity.X,
    "second simultaneous ingredient steers independently"
)
check(root.AssemblyLinearVelocity.X < simultaneousRoot.AssemblyLinearVelocity.X, "first ingredient continues steering")
ingredients.Consume(simultaneous)
heartbeat:Fire(1 / 60)
check(not ingredients.Resolve(simultaneous), "consumed active item releases safely")
zone.Overlaps = {}
local releasedVelocity = root.AssemblyLinearVelocity
heartbeat:Fire(1 / 60)
check(same(root.AssemblyLinearVelocity, releasedVelocity), "outside zone immediately releases")

local character, npc, tool, accessory = instance("Model"), instance("Model"), instance("Tool"), instance("Accessory")
local unrelated = {}
for _, container in { character, npc, tool, accessory } do
    container.Parent = workspaceFake
    if container == character or container == npc then
        instance("Humanoid").Parent = container
    end
    local part = instance("Part")
    part.Parent, part.AssemblyLinearVelocity = container, vec(1, 2, 3)
    table.insert(unrelated, part)
end
local visual = ingredients.CreateVisual("Banana")
visual.Parent, visual.AssemblyLinearVelocity = workspaceFake, vec(1, 2, 3)
table.insert(unrelated, visual)
zone.Overlaps = unrelated
heartbeat:Fire(1 / 60)
for _, part in unrelated do
    check(same(part.AssemblyLinearVelocity, vec(1, 2, 3)), "characters NPCs tools accessories visuals unaffected")
end
local carried, carriedRoot = spawn(owner)
carried.Parent = tool
zone.Overlaps = { carried }
heartbeat:Fire(1 / 60)
check(same(carriedRoot.AssemblyLinearVelocity, startVelocity), "even registered carried item is rejected")
carried.Parent = workspaceFake
carriedRoot.GetConnectedParts = function()
    return { unrelated[1] }
end
heartbeat:Fire(1 / 60)
check(same(carriedRoot.AssemblyLinearVelocity, startVelocity), "external character weld rejected")

local templates = instance("Folder")
templates.Name, templates.Parent = "Ingredients", storage
local template = instance("Model")
template.Name, template.Parent = "Strawberry", templates
for _, name in { "Fruit", "Leaf" } do
    local part = instance("Part")
    part.Name, part.Parent = name, template
end
local model, modelRoot = spawn(owner, true, "Strawberry")
zone.Overlaps = { model:FindFirstChild("Fruit"), model:FindFirstChild("Leaf"), modelRoot }
local target = vec(0, 1, 0)
local expected = physics.Steer(startVelocity, modelRoot.Position, target, 2.5, 1 / 60)
heartbeat:Fire(1 / 60)
check(same(modelRoot.AssemblyLinearVelocity, expected), "multipart overlap applies exactly one steering step")

local wrong, wrongRoot = spawn(other)
zone.Overlaps, otherZone.Overlaps = { wrong }, {}
heartbeat:Fire(1 / 60)
check(same(wrongRoot.AssemblyLinearVelocity, startVelocity), "wrong owner cannot capture")
otherZone.Overlaps = { wrong }
heartbeat:Fire(1 / 60)
check(wrongRoot.AssemblyLinearVelocity.X > startVelocity.X, "only owning blender steers overlapping zones")
local public, publicRoot = spawn(nil, true)
zone.Overlaps, otherZone.Overlaps = { public }, { public }
heartbeat:Fire(1 / 60)
check(same(publicRoot.AssemblyLinearVelocity, expected), "public tie resolves by owner UserId independent of tag order")
publicRoot.Position, publicRoot.AssemblyLinearVelocity = vec(3, 4, 0), startVelocity
heartbeat:Fire(1 / 60)
check(
    same(
        publicRoot.AssemblyLinearVelocity,
        physics.Steer(startVelocity, publicRoot.Position, vec(4, 1, 0), 2.5, 1 / 60)
    ),
    "nearest valid opening wins for public ingredient"
)
local locked, lockedRoot = spawn(nil, false)
zone.Overlaps, otherZone.Overlaps = { locked }, {}
heartbeat:Fire(1 / 60)
check(same(lockedRoot.AssemblyLinearVelocity, startVelocity), "unowned nonclaimable rejected")

local attachment = instance("Attachment")
attachment.Name, attachment.Parent, attachment.WorldPosition = "VacuumTarget", zone, vec(1, 2, 0)
root.AssemblyLinearVelocity, zone.Overlaps = startVelocity, { item }
heartbeat:Fire(1 / 60)
check(
    same(
        root.AssemblyLinearVelocity,
        physics.Steer(startVelocity, root.Position, attachment.WorldPosition, 2.5, 1 / 60)
    ),
    "zone attachment target supported"
)
attachment.Parent, attachment.WorldPosition = input, vec(-1, 2, 0)
root.AssemblyLinearVelocity = startVelocity
heartbeat:Fire(1 / 60)
check(
    same(
        root.AssemblyLinearVelocity,
        physics.Steer(startVelocity, root.Position, attachment.WorldPosition, 2.5, 1 / 60)
    ),
    "input attachment target supported"
)
attachment:Destroy()
root.Position, root.AssemblyLinearVelocity = vec(2, 0, 0), startVelocity
heartbeat:Fire(1 / 60)
check(same(root.AssemblyLinearVelocity, startVelocity), "below target releases without upward pull")
root.Position, input.Overlaps = startPosition, { item }
heartbeat:Fire(1 / 60)
check(same(root.AssemblyLinearVelocity, startVelocity), "inside input left to ingestion")
input.Overlaps = {}
local duplicate = instance("Part")
duplicate.Parent = plot
services.CollectionService:AddTag(duplicate, "BlenderVacuum")
heartbeat:Fire(1 / 60)
check(same(root.AssemblyLinearVelocity, startVelocity), "ambiguous zone disables safely")
duplicate:Destroy()
services.CollectionService:RemoveTag(zone, "BlenderVacuum")
heartbeat:Fire(1 / 60)
check(
    tycoon.GetReference(owner, "BlenderInput") == input and same(root.AssemblyLinearVelocity, startVelocity),
    "missing vacuum preserves blender setup"
)
services.CollectionService:AddTag(zone, "BlenderVacuum")
local destroyed = spawn(owner)
zone.Overlaps = { destroyed }
destroyed:Destroy()
heartbeat:Fire(1 / 60)
check(not ingredients.Resolve(destroyed), "destroyed capture safely skipped")

local velocity = vec(0, 0, 0)
for _ = 1, 300 do
    local nextVelocity = physics.Steer(velocity, vec(100, 5, 0), target, 2.5, 1 / 60)
    check(nextVelocity.Magnitude <= config.MaxSpeed + 0.0001, "assisted speed clamped")
    check((nextVelocity - velocity).Magnitude <= config.MaxAcceleration / 60 + 0.0001, "assisted acceleration clamped")
    velocity = nextVelocity
end
local fast = vec(100, 0, 0)
local braked = physics.Steer(fast, startPosition, target, 2.5, 1 / 60)
check(
    braked.Magnitude < fast.Magnitude and braked.Magnitude > config.MaxSpeed,
    "fast incoming momentum brakes progressively"
)
check(
    (physics.Steer(fast, startPosition, target, 2.5, 1) - fast).Magnitude
        <= config.MaxAcceleration * config.MaxStep + 0.0001,
    "hitch correction capped"
)

-- Real input and BlendService consume; vacuum never receives a consumption API of its own.
local blend = loadModule("BlendService")
deps.BlendService = blend
blend.Init(deps)
blend.Reset(owner)
cache.WorldUtil.BindTag = function(tag, attach)
    for _, object in services.CollectionService:GetTagged(tag) do
        attach(object)
    end
end
component("BlenderInput").Init(deps)
zone.Overlaps, input.Overlaps = { modelRoot }, { modelRoot, model:FindFirstChild("Fruit") }
heartbeat:Fire(0.1)
check(
    not ingredients.GetRecord(model) and #blend.GetSnapshot(owner).Ingredients == 1,
    "existing BlenderInput consumes model once"
)
heartbeat:Fire(0.1)
check(
    #blend.GetSnapshot(owner).Ingredients == 1 and not blend.TryInput(owner, model, input),
    "repeat overlap cannot double consume"
)
blend.Reset(owner)
heartbeat:Fire(0.1)
check(#blend.GetSnapshot(owner).Ingredients == 0, "reset does not resurrect stale capture")
tycoon.RemovePlayer(owner)
zone.Overlaps, root.AssemblyLinearVelocity = { item }, startVelocity
heartbeat:Fire(1 / 60)
check(same(root.AssemblyLinearVelocity, startVelocity), "plot release stops assistance")
print("PASS: " .. count .. " blender vacuum assertions")
