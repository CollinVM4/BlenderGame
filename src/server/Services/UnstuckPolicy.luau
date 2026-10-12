--!strict
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.UnstuckConfig)
local Policy = {}
export type Observation = {
    Recent: boolean,
    Alive: boolean,
    Locked: boolean,
    Cooldown: boolean,
    StationarySeconds: number,
    RecoverySeconds: number,
    Intent: boolean,
    Obstructed: boolean,
    Abnormal: boolean,
}
function Policy.Eligible(o: Observation): boolean
    return o.Recent
        and o.Alive
        and not o.Locked
        and not o.Cooldown
        and o.StationarySeconds >= Config.ObserveSeconds
        and o.RecoverySeconds >= Config.RecoveryGraceSeconds
        and ((o.Intent and o.Obstructed) or (o.Abnormal and o.RecoverySeconds >= Config.AbnormalSeconds))
end
return Policy
