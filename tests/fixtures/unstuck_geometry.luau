-- Translation/orientation boundary for recovery tests, without engine simulation.
local oldFrame = frame
frame = function(...)
    local cf = oldFrame(...)
    function cf:PointToWorldSpace(point)
        return self.Position + self.RightVector * point.X + self.UpVector * point.Y - self.LookVector * point.Z
    end
    function cf:Inverse()
        -- Tests use upright, identity-yaw rigs; rotated/scaled engine rigs are Studio checks.
        return frame(-self.Position.X, -self.Position.Y, -self.Position.Z)
    end
    return cf
end
env.CFrame.new = frame
function vector:Min(other)
    return vec(math.min(self.X, other.X), math.min(self.Y, other.Y), math.min(self.Z, other.Z))
end
function vector:Max(other)
    return vec(math.max(self.X, other.X), math.max(self.Y, other.Y), math.max(self.Z, other.Z))
end
local multiply = vector.__mul
vector.__mul = function(a, b)
    if type(b) == "table" then
        return vec(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
    end
    return multiply(a, b)
end
vector.__unm = function(a)
    return vec(-a.X, -a.Y, -a.Z)
end
env.Enum.Material = { Water = "Water", Air = "Air", Concrete = "Concrete" }
workspaceFake.FallenPartsDestroyHeight = -500

-- Destination translation preserves orientation; Terrain queries are controlled cells.
local frameWithMethods = frame
frame = function(...)
    local cf = frameWithMethods(...)
    getmetatable(cf).__add = function(a, delta)
        local moved = frame(a.Position + delta)
        moved.LookVector, moved.RightVector, moved.UpVector = a.LookVector, a.RightVector, a.UpVector
        return moved
    end
    return cf
end
env.CFrame.new = frame
env.Region3 = {
    new = function(low, high)
        local region = { Low = low, High = high, Size = high - low }
        function region:ExpandToGrid(resolution)
            local function down(n)
                return math.floor(n / resolution) * resolution
            end
            local function up(n)
                return math.ceil(n / resolution) * resolution
            end
            return env.Region3.new(vec(down(low.X), down(low.Y), down(low.Z)), vec(up(high.X), up(high.Y), up(high.Z)))
        end
        return region
    end,
}
workspaceFake.Terrain = {}
function workspaceFake.Terrain:ReadVoxelChannels(region, resolution, _)
    local solid, liquid = {}, {}
    local size = region.Size / resolution
    for x = 1, size.X do
        solid[x], liquid[x] = {}, {}
        for y = 1, size.Y do
            solid[x][y], liquid[x][y] = {}, {}
            for z = 1, size.Z do
                solid[x][y][z], liquid[x][y][z] = 0, 0
            end
        end
    end
    return { SolidOccupancy = solid, LiquidOccupancy = liquid }
end

env.Enum.RaycastFilterType.Include = "Include"
