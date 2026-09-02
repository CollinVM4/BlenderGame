--!strict
local PhysicsService = {}

local MAX_SPIN_SPEED = 50

function PhysicsService.GetSpinStrength(part: BasePart): number
    if not part or not part:IsA("BasePart") then
        return 0
    end

    local angularVelocity = part.AssemblyAngularVelocity
    return math.clamp(angularVelocity.Magnitude, 0, MAX_SPIN_SPEED)
end

function PhysicsService.GetBlendDelta(part: BasePart): number
    return PhysicsService.GetSpinStrength(part) * 0.05
end

return PhysicsService
