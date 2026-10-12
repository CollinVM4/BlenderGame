local gun = loadModule("IceGunService")
local shotgun = loadModule("IceGunProjectileService")
local combat = loadModule("CombatService")
deps.IceGunService, deps.IceGunProjectileService, deps.CombatService = gun, shotgun, combat
deps.FreezeStatusService = {
    Apply = function()
        return true
    end,
}
combat.Init(deps)
shotgun.Init(deps)
gun.Init(deps)
local player, h = fighter("A")
local victim, victimH = fighter("B")
ready(player)
ready(victim)
ownership[player.UserId] = true
gun.AddPlayer(player)
flush()
h:EquipTool(gun.GrantIfOwned(player))
local barrel = gun.GetEquipped(player):FindFirstChild("Handle"):FindFirstChild("GunBarrel")
barrel.WorldPosition = vec(1.5, 1, -2)
local cameraHit, launchHit, targetBlocked = nil, nil, false
local cameraOrigin = vec(5, 3, 12)
local wall = instance("Part")
wall.Parent = workspaceFake
workspaceFake.Raycast = function(_, origin, direction)
    if (origin - cameraOrigin).Magnitude < 0.001 then
        return cameraHit
    elseif direction.Magnitude <= 8 then
        return launchHit
    elseif targetBlocked then
        return { Instance = wall, Position = origin + direction * 0.5 }
    end
    return nil
end
local cases = {
    { vec(0, 1, -10), vec(0, 2, 8) },
    { vec(16, 7, -40), vec(5, 3, 12) },
    { vec(-20, -8, -50), vec(-7, 2, 20) },
    { vec(0, 1, -105), vec(0, 2, 3) },
    { vec(0, 1, -40), vec(10, 6, 100) },
}
for _, case in cases do
    local target = case[1]
    cameraOrigin = case[2]
    cameraHit = { Instance = wall, Position = target }
    local direction = (target - cameraOrigin).Unit
    local expected = (target - barrel.WorldPosition).Unit
    victim.Character:FindFirstChild("HumanoidRootPart").Position = barrel.WorldPosition + expected * 10
    local health = victimH.Health
    check(shotgun.Fire(player, target, cameraOrigin, direction), "valid clicked camera ray fires")
    check(victimH.Health == health - 5, "cone converges from actual muzzle toward server-resolved camera intent")
    advance(config.ShotCooldown)
end
cameraOrigin = vec(5, 3, 12)
local target = vec(0, 1, -60)
local direction = (target - cameraOrigin).Unit
-- Server camera occlusion determines the cone's center even when the client reports farther aim.
cameraHit = { Instance = wall, Position = cameraOrigin + direction * 8 }
local expected = (cameraHit.Position - barrel.WorldPosition).Unit
victim.Character:FindFirstChild("HumanoidRootPart").Position = barrel.WorldPosition + expected * 10
local health = victimH.Health
check(shotgun.Fire(player, target, cameraOrigin, direction), "server camera wall resolves aim")
check(victimH.Health == health - 5, "cone direction follows server camera hit rather than untrusted target")
advance(config.ShotCooldown)
cameraHit = { Instance = wall, Position = target }
launchHit = { Instance = wall, Position = barrel.WorldPosition }
check(not shotgun.Fire(player, target, cameraOrigin, direction), "clear camera cannot bypass blocked muzzle")
launchHit = nil
advance(0.11)
check(not shotgun.Fire(player, target, vec(1000, 0, 0), direction), "distant fabricated camera rejected")
advance(0.11)
check(not shotgun.Fire(player, target, cameraOrigin, vec(0 / 0, 0, -1)), "nonfinite direction rejected")
advance(0.11)
check(not shotgun.Fire(player, target, cameraOrigin, vec(0, math.huge, -1)), "infinite direction rejected")
advance(0.11)
check(not shotgun.Fire(player, target, cameraOrigin, vec(0, 0, 0)), "zero camera direction rejected")
advance(0.11)
check(not shotgun.Fire(player, target, cameraOrigin, direction * 2), "nonunit camera direction rejected")
advance(0.11)
check(
    not shotgun.Fire(player, target + vec(10, 0, 0), cameraOrigin, direction),
    "aim inconsistent with camera ray rejected"
)
advance(0.11)
check(not shotgun.Fire(player, target, cameraOrigin, nil), "partial camera payload rejected")
advance(0.11)
check(not shotgun.Fire(player, vec(0, 0, -1000)), "excessive legacy aim distance rejected")
advance(0.11)
victim.Character:FindFirstChild("HumanoidRootPart").Position = barrel.WorldPosition
    + (target - barrel.WorldPosition).Unit * 10
targetBlocked = true
health = victimH.Health
check(shotgun.Fire(player, target, cameraOrigin, direction), "valid shot after rejected intents")
check(victimH.Health == health, "clear camera ray cannot bypass muzzle-to-target wall")
print("PASS: Ice Shotgun camera/muzzle convergence and aim validation")
