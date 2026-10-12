--!strict
-- Server output only. Cosmetic clients never choose hits or acknowledge damage.
local Events = game:GetService("ReplicatedStorage").Shared.Events
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.IceGunConfig)
local Service = {}
export type Hit = { Position: Vector3, UserId: number, Frozen: boolean }
local remote: RemoteEvent?

function Service.Init()
    if remote then
        return
    end
    local event = Instance.new("RemoteEvent")
    event.Name = "IceShotgunResult"
    event.Parent = Events
    remote = event
end

function Service.Emit(player: Player, origin: Vector3, direction: Vector3, hits: { Hit })
    if remote then
        remote:FireAllClients({
            ShooterUserId = player.UserId,
            Origin = origin,
            Direction = direction,
            Range = Config.MaximumRange,
            Angle = Config.ConeAngleDegrees,
            Hits = hits,
            ServerTime = workspace:GetServerTimeNow(),
        })
    end
end

return Service
