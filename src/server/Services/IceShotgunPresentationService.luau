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

-- Origin is the caster root and Radius is the authoritative hit radius, so
-- clients render a pulse whose size is exactly the server hit sphere. No
-- direction or angle is broadcast: there is no cone to draw anymore.
function Service.Emit(player: Player, origin: Vector3, hits: { Hit })
    if remote then
        remote:FireAllClients({
            ShooterUserId = player.UserId,
            Origin = origin,
            Radius = Config.BlastRadius,
            Hits = hits,
            ServerTime = workspace:GetServerTimeNow(),
        })
    end
end

return Service
