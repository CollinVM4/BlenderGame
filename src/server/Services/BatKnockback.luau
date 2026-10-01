--!strict
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.BatConfig)
local BatKnockback = {}

function BatKnockback.Direction(attackerRoot: BasePart, root: BasePart): Vector3
    local delta = root.Position - attackerRoot.Position
    local away = Vector3.new(delta.X, 0, delta.Z)
    if away.Magnitude < 0.001 then
        local forward = attackerRoot.CFrame.LookVector
        away = Vector3.new(forward.X, 0, forward.Z)
    end
    return if away.Magnitude > 0.001 then away.Unit else Vector3.new(0, 0, -1)
end

function BatKnockback.Apply(
    root: BasePart,
    away: Vector3,
    tuning: { HorizontalKnockback: number, VerticalKnockback: number }?
)
    local mass = root.AssemblyMass
    if not root.Anchored and mass > 0 and mass < math.huge then
        local horizontal = if tuning then tuning.HorizontalKnockback else Config.Knockback.HorizontalSpeed
        local vertical = if tuning then tuning.VerticalKnockback else Config.Knockback.UpwardSpeed
        -- Direction is already a horizontal unit vector; do not normalize the combined launch.
        local velocity = away * horizontal + Vector3.new(0, vertical, 0)
        root:ApplyImpulse(velocity * mass)
    end
end

return BatKnockback
