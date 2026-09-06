--!strict
local Economy = require(game:GetService("ReplicatedStorage").Shared.Constants.Economy)
local PhysicsService = {}

function PhysicsService.GetSpinStrength(part: BasePart): number
    if not part or not part:IsA("BasePart") then
        return 0
    end

    local angularVelocity = part.AssemblyAngularVelocity
    return angularVelocity.Magnitude
end

function PhysicsService.GetBlendDelta(part: BasePart, deltaTime: number?): number
    -- Preserve the old one-argument API; dt-aware callers no longer depend on framerate.
    return PhysicsService.GetSpinStrength(part) * Economy.BlendProgressScale * (deltaTime or 1 / 60)
end

-- Display/debugging only; gameplay uses angular speed directly.
function PhysicsService.GetRPM(part: BasePart): number
    return PhysicsService.GetSpinStrength(part) * 60 / (2 * math.pi)
end

return PhysicsService
