--!strict
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.JackedNoob)
local Logic = {}

export type State = { [Player]: number }

function Logic.TryReward(
    deadlines: State,
    player: Player,
    now: number,
    hasSpace: () -> boolean,
    grant: () -> boolean
): string
    if now < (deadlines[player] or 0) then
        return "Greedy.. Come back later.."
    end
    if not hasSpace() then
        return "Your hands are full, buddy."
    end
    if not grant() then
        return "Can't grab it right now, buddy."
    end
    deadlines[player] = now + Config.ProteinCooldownSeconds
    return "lil bro, you look like you need this."
end

function Logic.LocalTarget(size: Vector3, margin: number, random: Random): Vector3
    local x = math.max(0, size.X / 2 - margin)
    local z = math.max(0, size.Z / 2 - margin)
    return Vector3.new(random:NextNumber(-x, x), 0, random:NextNumber(-z, z))
end

function Logic.ReturnTarget(localPosition: Vector3, size: Vector3, margin: number): Vector3
    local x = math.max(0, size.X / 2 - margin)
    local z = math.max(0, size.Z / 2 - margin)
    return Vector3.new(math.clamp(localPosition.X, -x, x), 0, math.clamp(localPosition.Z, -z, z))
end

return Logic
