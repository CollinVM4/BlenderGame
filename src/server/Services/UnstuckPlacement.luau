--!strict
-- Destination-only validation: the embedded starting pose is not a teleport path.
local CollectionService = game:GetService("CollectionService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.UnstuckConfig)
local Placement = {}
local bodyNames: { [string]: boolean } = {
    HumanoidRootPart = true,
    Head = true,
    UpperTorso = true,
    LowerTorso = true,
    Torso = true,
    ["Left Arm"] = true,
    ["Right Arm"] = true,
    ["Left Leg"] = true,
    ["Right Leg"] = true,
}
for _, side in { "Left", "Right" } do
    for _, segment in { "UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg", "Foot" } do
        bodyNames[side .. segment] = true
    end
end
local function hazard(object: Instance): boolean
    local current: Instance? = object
    while current and current ~= workspace do
        if
            current:GetAttribute("UnstuckUnsafe") == true
            or current:GetAttribute("KillZoneConnected") == true
            or CollectionService:HasTag(current, "UnstuckHazard")
            or CollectionService:HasTag(current, "KillZone")
        then
            return true
        end
        current = current.Parent
    end
    return false -- Harmless touch triggers are not hazards merely because they have Touched listeners.
end
local function bounds(at: CFrame, size: Vector3): (Vector3, Vector3)
    local low, high = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
    for _, x in { -0.5, 0.5 } do
        for _, y in { -0.5, 0.5 } do
            for _, z in { -0.5, 0.5 } do
                local corner = at:PointToWorldSpace(size * Vector3.new(x, y, z))
                low, high = low:Min(corner), high:Max(corner)
            end
        end
    end
    return low, high
end
local function terrainClear(at: CFrame, size: Vector3): boolean
    -- Spatial part overlap queries do not include Terrain. Query only destination
    -- body cells; grass/solid voxels around the embedded origin are irrelevant.
    local low, high = bounds(at, size)
    local region = Region3.new(low, high):ExpandToGrid(4)
    local ok, channels = pcall(function()
        return workspace.Terrain:ReadVoxelChannels(region, 4, { "SolidOccupancy", "LiquidOccupancy" })
    end)
    if not ok then
        return false
    end
    local partial = false
    local cells = region.Size / 4
    for x = 1, cells.X do
        for y = 1, cells.Y do
            for z = 1, cells.Z do
                local solid, liquid = channels.SolidOccupancy[x][y][z], channels.LiquidOccupancy[x][y][z]
                if solid >= 1 or liquid >= 1 then
                    return false
                end
                partial = partial or solid > 0 or liquid > 0
            end
        end
    end
    -- Grid expansion can include partially filled grass cells BELOW a clear foot.
    -- Confirm actual surfaces inside the body, rather than rejecting that whole voxel.
    if partial then
        local ray = RaycastParams.new()
        ray.FilterType = Enum.RaycastFilterType.Include
        ray.FilterDescendantsInstances = { workspace.Terrain }
        ray.IgnoreWater = false
        for _, x in { -0.45, 0, 0.45 } do
            for _, z in { -0.45, 0, 0.45 } do
                local column = at:PointToWorldSpace(Vector3.new(size.X * x, 0, size.Z * z))
                local hit = workspace:Raycast(
                    Vector3.new(column.X, high.Y + 4, column.Z),
                    Vector3.new(0, -(high.Y - low.Y + 8), 0),
                    ray
                )
                if hit and hit.Position.Y >= low.Y and hit.Position.Y <= high.Y then
                    return false
                end
            end
        end
    end
    return true
end
-- Destination is a root CFrame. Check physical parts individually; noncollidable
-- cosmetics/carried visuals and empty space between articulated limbs do not enlarge clearance.
function Placement.IsUsable(character: Model, root: BasePart, destination: CFrame): boolean
    if destination.Position.Y <= workspace.FallenPartsDestroyHeight + root.Size.Y then
        return false
    end
    local transform = destination * root.CFrame:Inverse()
    local collision = OverlapParams.new()
    collision.FilterDescendantsInstances = { character }
    collision.RespectCanCollide = true
    local volumes = OverlapParams.new()
    volumes.FilterDescendantsInstances = { character }
    -- Existing blender KillZones must remain unsafe even with CanQuery=false or
    -- collision-group exclusions. This scans only explicitly tagged hazard volumes.
    local hazards: { [BasePart]: boolean } = {}
    for _, tag in { "KillZone", "UnstuckHazard" } do
        for _, object in CollectionService:GetTagged(tag) do
            if object:IsA("BasePart") then
                hazards[object] = true
            end
            for _, part in object:GetDescendants() do
                if part:IsA("BasePart") then
                    hazards[part] = true
                end
            end
        end
    end
    local checked = false
    for _, body in character:GetDescendants() do
        if body:IsA("BasePart") and ((body.Parent == character and bodyNames[body.Name]) or body.CanCollide) then
            checked = true
            local at = transform * body.CFrame
            local size = Vector3.new(
                math.max(0.05, body.Size.X - Config.BodyClearanceInset),
                math.max(0.05, body.Size.Y - Config.BodyClearanceInset),
                math.max(0.05, body.Size.Z - Config.BodyClearanceInset)
            )
            collision.CollisionGroup, volumes.CollisionGroup = body.CollisionGroup, body.CollisionGroup
            if #workspace:GetPartBoundsInBox(at, size, collision) > 0 then
                return false
            end
            for _, part in workspace:GetPartBoundsInBox(at, size, volumes) do
                if hazard(part) then
                    return false
                end
            end
            local low, high = bounds(at, size)
            for volume in hazards do
                if volume:IsDescendantOf(workspace) and not volume:IsDescendantOf(character) then
                    local hazardLow, hazardHigh = bounds(volume.CFrame, volume.Size)
                    if
                        low.X < hazardHigh.X
                        and high.X > hazardLow.X
                        and low.Y < hazardHigh.Y
                        and high.Y > hazardLow.Y
                        and low.Z < hazardHigh.Z
                        and high.Z > hazardLow.Z
                    then
                        return false
                    end
                end
            end
            if not terrainClear(at, size) then
                return false
            end
        end
    end
    return checked
end
function Placement.Find(character: Model, _humanoid: Humanoid, root: BasePart): CFrame?
    local destination = root.CFrame + Vector3.yAxis * Config.VerticalLift
    return if Placement.IsUsable(character, root, destination) then destination else nil
end
return Placement
