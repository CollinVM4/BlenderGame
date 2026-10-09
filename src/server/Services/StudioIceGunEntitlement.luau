--!strict
-- Server-only, session-local test provider. Never represents Roblox ownership.
local RunService = game:GetService("RunService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.IceGunConfig)
local Simulator = {}
local owned: { [Player]: boolean } = {}

function Simulator.Supports(player: Player, passId: number): boolean
    return RunService:IsServer()
        and RunService:IsStudio()
        and Config.StudioGamePassSimulation == true
        and player.UserId < 0
        and passId > 0
        and passId == Config.IceGunGamePassId
end

function Simulator.PlayerOwns(player: Player, passId: number): boolean
    return Simulator.Supports(player, passId) and owned[player] == true
end

-- Caller must consume a matching server-tracked pending purchase first.
function Simulator.Complete(player: Player, passId: number): boolean
    if not Simulator.Supports(player, passId) then
        return false
    end
    owned[player] = true
    return true
end

function Simulator.RemovePlayer(player: Player)
    owned[player] = nil
end

return Simulator
