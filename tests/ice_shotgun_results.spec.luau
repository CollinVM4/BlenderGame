-- Output-only notification contract; cone authority stays in icegun-combat.
local gun = loadModule("IceGunService")
local shotgun = loadModule("IceGunProjectileService")
local freeze = loadModule("FreezeStatusService")
local combat = loadModule("CombatService")
deps.IceGunService, deps.IceGunProjectileService, deps.FreezeStatusService, deps.CombatService =
    gun, shotgun, freeze, combat
combat.Init(deps)
freeze.Init(deps)
shotgun.Init(deps)
gun.Init(deps)
local remote = shared.Events:FindFirstChild("IceShotgunResult")
local results = {}
function remote:FireAllClients(result)
    table.insert(results, result)
end
local function owner(session)
    local p, h = fighter(session)
    ready(p)
    ownership[p.UserId] = true
    gun.AddPlayer(p)
    flush()
    h:EquipTool(gun.GrantIfOwned(p))
    gun.GetEquipped(p):FindFirstChild("Handle"):FindFirstChild("GunBarrel").WorldPosition = vec(0, 1, -2)
    return p
end
local shooter = owner("A")
local otherShooter = owner("C")
local victim, h = fighter("B")
ready(victim)
victim.Character:FindFirstChild("HumanoidRootPart").Position = vec(0, 1, -12)
freeze.ApplyCharacter(victim, victim.Character)
flush()
workspaceFake.Raycast = function()
    return nil
end
local aim = vec(0, 1, -100)
setup(shotgun.Fire(shooter, aim), "accepted result shot")
check(
    #results == 1 and #results[1].Hits == 1 and results[1].Hits[1].UserId == victim.UserId and results[1].Hits[1].Frozen,
    "accepted notification lists only confirmed damaged players and real freeze result"
)
check(
    results[1].Origin.Z == -2
        and results[1].Range == 22
        and results[1].Angle == 50
        and results[1].ShooterUserId == shooter.UserId,
    "presentation uses authoritative muzzle/direction/geometry/shooter"
)
check(not shotgun.Fire(shooter, aim) and #results == 1, "cooldown-rejected requests emit no predicted blast")
remote.OnServerEvent:Fire(shooter, { Hits = { { UserId = victim.UserId, Frozen = true } } })
check(
    #results == 1 and h.Health == 95,
    "client writes to the presentation remote cannot cause gameplay or presentation"
)
advance(config.FreezeSeconds)
check(
    victim.Character:GetAttribute("FreezeImmuneUntil") == workspaceFake:GetServerTimeNow() + config.ImmunitySeconds,
    "published freeze immunity begins at actual authoritative thaw"
)
setup(shotgun.Fire(otherShooter, aim), "another shooter during immunity")
check(
    #results == 2 and #results[2].Hits == 1 and not results[2].Hits[1].Frozen and h.Health == 90,
    "damage feedback distinguishes immune hits from a new freeze"
)
advance(config.ShotCooldown)
local wall = instance("Part")
wall.Parent = workspaceFake
workspaceFake.Raycast = function(_, _, direction)
    if direction.Magnitude > 8 then
        return { Instance = wall, Position = vec(0, 1, -8) }
    end
    return nil
end
setup(shotgun.Fire(shooter, aim), "accepted miss")
check(
    #results == 3 and #results[3].Hits == 0 and h.Health == 90,
    "accepted misses still broadcast a muzzle/cone, never invented impact feedback"
)
freeze.RemovePlayer(victim)
check(victim.Character:GetAttribute("FreezeImmuneUntil") == nil, "status cleanup removes replicated immunity")
setup(freeze.Apply(victim), "freeze before delayed server frame")
advance(5)
check(
    victim.Character:GetAttribute("FreezeImmuneUntil") == workspaceFake:GetServerTimeNow() + config.ImmunitySeconds,
    "delayed thaw publishes the full actual recovery-immunity window"
)
freeze.RemovePlayer(victim)
print("PASS: Server-confirmed Ice Shotgun presentation output")
