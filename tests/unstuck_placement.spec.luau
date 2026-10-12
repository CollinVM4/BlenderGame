-- Real destination resolver against controlled world bodies/Terrain. No swept-path mocks.
local placement = loadModule("UnstuckPlacement")
local c, h, root = instance("Model"), instance("Humanoid"), instance("Part")
h.Parent, root.Parent = c, c
root.Name, root.Size = "HumanoidRootPart", vec(2, 2, 1)
root.Position, root.CFrame = vec(10, 0.1, 10), frame(10, 0.1, 10)
root.CollisionGroup = "Players"
local objects, queries = {}, {}
workspaceFake.GetPartBoundsInBox = function(_, at, size, params)
    table.insert(queries, { At = at, Size = size })
    local hits = {}
    for _, object in objects do
        local delta = at.Position - object.CFrame.Position
        local total = (size + object.Size) / 2
        if
            math.abs(delta.X) < total.X
            and math.abs(delta.Y) < total.Y
            and math.abs(delta.Z) < total.Z
            and (not params.RespectCanCollide or object.CanCollide)
        then
            table.insert(hits, object)
        end
    end
    return hits
end
workspaceFake.Raycast = function()
    error("primary must not require floor/footprint probes")
end
workspaceFake.Blockcast = function()
    error("primary must not sweep the embedded start")
end
local function obstacle(name, position, size, collidable)
    local p = instance("Part")
    p.Name, p.CFrame, p.Size, p.CanCollide = name, frame(position), size, collidable
    table.insert(objects, p)
    return p
end
local grass = obstacle("Grass", vec(10, -0.5, 10), vec(100, 1, 100), true)
local touch = instance("TouchTransmitter")
touch.Parent = grass
local adjacent = obstacle("AdjacentGrass", vec(12, -0.5, 10), vec(4, 1, 20), true)
for _, size in { vec(2, 2, 1), vec(1, 0.75, 0.75), vec(6, 2, 4) } do
    root.Size = size
    local destination = placement.Find(c, h, root)
    check(
        destination
            and destination.Position.X == root.Position.X
            and destination.Position.Z == root.Position.Z
            and math.abs(destination.Position.Y - root.Position.Y - 10) < 1e-6,
        "normal/small/wide embedded body lifts ten studs despite neighboring grass/touch support"
    )
end
root.Size = vec(2, 2, 1)
local cosmetic = instance("Accessory")
cosmetic.Parent = c
local handle = instance("Part")
handle.Parent, handle.Size, handle.CFrame, handle.CanCollide = cosmetic, vec(200, 200, 200), frame(10, -20, 10), false
local tool = instance("Tool")
tool.Parent = c
local carried = instance("Part")
carried.Parent, carried.Size, carried.CanCollide = tool, vec(100, 100, 100), false
queries = {}
check(placement.Find(c, h, root) ~= nil, "large noncollidable cosmetics and carried visuals do not enlarge clearance")
check(#queries == 2 and queries[1].Size.X < 2, "physical bodies checked separately without empty full-character bounds")
handle.CanCollide, handle.Size, handle.CFrame = true, vec(1, 1, 1), frame(13.5, 0.1, 10)
local physicalBlocker = obstacle("PhysicalAccessoryBlock", vec(13.5, 10.1, 10), vec(1, 1, 1), true)
check(not placement.Find(c, h, root), "collidable gameplay accessories still require physical clearance")
handle.CanCollide = false
check(placement.Find(c, h, root) ~= nil, "same cosmetic is harmless when noncollidable")
local decoration = obstacle("Decoration", vec(10, 10.1, 10), vec(2, 2, 2), false)
local harmless = instance("TouchTransmitter")
harmless.Parent = decoration
check(placement.Find(c, h, root) ~= nil, "harmless destination touch trigger and decoration ignored")
local ceiling = obstacle("Ceiling", vec(10, 10.1, 10), vec(20, 2, 20), true)
check(not placement.Find(c, h, root), "solid ceiling at destination rejects local lift")
ceiling.CanCollide = false
services.CollectionService:AddTag(ceiling, "UnstuckHazard")
check(not placement.Find(c, h, root), "dangerous noncollidable destination volume rejected")
services.CollectionService:RemoveTag(ceiling, "UnstuckHazard")
local ancestor = instance("Folder")
ancestor:SetAttribute("UnstuckUnsafe", true)
ceiling.Parent = ancestor
check(not placement.Find(c, h, root), "ancestor hazard marker is respected")
ceiling.Parent = nil
ceiling.Size = vec(0.1, 0.1, 0.1)
ceiling.CFrame = frame(500, 500, 500)
local wall = obstacle("LockedBarrier", vec(10, 10.1, 10), vec(2, 10, 1), true)
check(not placement.Find(c, h, root), "locked barrier occupying destination rejected")
wall.CFrame = frame(500, 500, 500)
root.CFrame.LookVector, root.CFrame.UpVector, root.CFrame.RightVector = vec(0, 1, 0), vec(0, 0, 1), vec(1, 0, 0)
local oriented = placement.Find(c, h, root)
check(
    oriented and oriented.LookVector.Y == 1 and oriented.UpVector.Z == 1,
    "vertical recovery preserves full root orientation"
)
root.CFrame = frame(root.Position)
local read = workspaceFake.Terrain.ReadVoxelChannels
workspaceFake.Terrain.ReadVoxelChannels = function(self, region, resolution, channels)
    local values = read(self, region, resolution, channels)
    -- Grass exists only beneath the current embedded pose, never at the destination.
    if region.Low.Y < 0 then
        values.SolidOccupancy[1][1][1] = 1
    end
    return values
end
check(placement.Find(c, h, root) ~= nil, "terrain occupancy around starting position is irrelevant")
workspaceFake.Terrain.ReadVoxelChannels = function(self, region, resolution, channels)
    local values = read(self, region, resolution, channels)
    values.SolidOccupancy[1][1][1] = 1
    return values
end
check(not placement.Find(c, h, root), "solid terrain occupying destination rejected")
workspaceFake.Terrain.ReadVoxelChannels = function(self, region, resolution, channels)
    local values = read(self, region, resolution, channels)
    values.LiquidOccupancy[1][1][1] = 1
    return values
end
check(not placement.Find(c, h, root), "water at destination rejected")
workspaceFake.Terrain.ReadVoxelChannels = function()
    error("unavailable terrain query")
end
check(not placement.Find(c, h, root), "failed terrain validation rejects safely")
workspaceFake.Terrain.ReadVoxelChannels = read
local health, initial = h.Health, root.Position.Y
check(placement.IsUsable(c, root, frame(100, 7, 300)), "same physical validation can check a plot spawn")
check(h.Health == health and root.Position.Y == initial, "search never mutates character or health")

workspaceFake.Terrain.ReadVoxelChannels = function(self, region, resolution, channels)
    local values = read(self, region, resolution, channels)
    values.SolidOccupancy[1][1][1] = 0.5
    return values
end
local terrainSurfaceY = 0
workspaceFake.Raycast = function(_, origin, _, params)
    setup(
        params.FilterType == "Include" and params.FilterDescendantsInstances[1] == workspaceFake.Terrain,
        "partial-cell verification queries only Terrain"
    )
    return { Position = vec(origin.X, terrainSurfaceY, origin.Z) }
end
check(placement.IsUsable(c, root, frame(10, 3, 10)), "partial grass voxel below a clear plot spawn is harmless")
terrainSurfaceY = 3
check(
    not placement.IsUsable(c, root, frame(10, 3, 10)),
    "partial terrain surface penetrating destination body rejected"
)

workspaceFake.Terrain.ReadVoxelChannels = read
local kill = instance("Part")
kill.Parent, kill.CFrame, kill.Size, kill.CanCollide, kill.CanQuery =
    workspaceFake, frame(10, 10.1, 10), vec(4, 4, 4), false, false
services.CollectionService:AddTag(kill, "KillZone")
check(not placement.Find(c, h, root), "existing nonqueryable blender KillZone rejected without new Studio objects")
services.CollectionService:RemoveTag(kill, "KillZone")
