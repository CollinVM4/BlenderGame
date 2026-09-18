--!strict
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.BlenderVacuum)
local Physics = {}

local function clampMagnitude(value: Vector3, limit: number): Vector3
    return if value.Magnitude > limit then value.Unit * limit else value
end

function Physics.Steer(velocity: Vector3, position: Vector3, target: Vector3, radius: number, dt: number): Vector3
    local offset = target - position
    local horizontal = Vector3.new(offset.X, 0, offset.Z)
    local proximity = 1 - math.clamp(horizontal.Magnitude / math.max(radius, 0.01), 0, 1)
    local strength = Config.EdgeStrength + (1 - Config.EdgeStrength) * proximity
    local desired =
        clampMagnitude(horizontal * Config.CenteringStrength + Vector3.new(0, -Config.DownwardBias, 0), Config.MaxSpeed)
    local step = math.clamp(dt, 0, Config.MaxStep)
    local delta = (desired - velocity) * (1 - math.exp(-Config.PullStrength * strength * step))
    return velocity + clampMagnitude(delta, Config.MaxAcceleration * step)
end

return Physics
