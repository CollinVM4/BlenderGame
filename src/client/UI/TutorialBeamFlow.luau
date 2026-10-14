--!strict
-- The origin is Attachment0 (player), the destination Attachment1 (stash).
-- Move a soft bright segment from normalized distance 0 to 1, then fade/repeat.
local Flow = {}
function Flow.Transparency(elapsed: number): NumberSequence
    local phase = (elapsed % 2.4) / 2.4
    local fade = math.min(1, phase / 0.12, (1 - phase) / 0.12)
    local points: { NumberSequenceKeypoint } = {}
    for index = 0, 16 do
        local position = index / 16
        local strength = math.max(0, 1 - math.abs(position - phase) / 0.14)
        strength = strength * strength * (3 - 2 * strength)
        table.insert(points, NumberSequenceKeypoint.new(position, 1 - 0.85 * strength * fade))
    end
    return NumberSequence.new(points)
end
return Flow
