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

function PhysicsService.GetBlendDelta(part: BasePart, deltaTime: number?): number
    -- Preserve the old one-argument API; dt-aware callers no longer depend on framerate.
    return PhysicsService.GetSpinStrength(part) * 3 * (deltaTime or 1 / 60)
end

return PhysicsService
