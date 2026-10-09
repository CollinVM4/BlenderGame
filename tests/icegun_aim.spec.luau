local gun = loadModule("IceGunService")
local projectile = loadModule("IceGunProjectileService")
deps.IceGunService, deps.IceGunProjectileService = gun, projectile
projectile.Init(deps)
gun.Init(deps)
local player, h = fighter("A")
ready(player)
ownership[player.UserId] = true
gun.AddPlayer(player)
flush()
h:EquipTool(gun.GrantIfOwned(player))
local barrel = gun.GetEquipped(player):FindFirstChild("Handle"):FindFirstChild("GunBarrel")
barrel.WorldPosition = vec(1.5, 1, -2)
local cameraHit, launchHit, sweptHit = nil, nil, nil
local cameraOrigin = vec(5, 3, 12)
local wall = instance("Part")
wall.Parent = workspaceFake
workspaceFake.Raycast = function(_, origin, direction)
    if (origin - cameraOrigin).Magnitude < 0.001 then
        return cameraHit
    elseif direction.Magnitude <= 8 then
        return launchHit
    end
    return sweptHit
end
local cases = {
    { vec(0, 1, -10), vec(0, 2, 8) }, -- near center
    { vec(16, 7, -40), vec(5, 3, 12) }, -- off-center, elevated, third-person
    { vec(-20, -8, -50), vec(-7, 2, 20) }, -- left/lower
    { vec(0, 1, -105), vec(0, 2, 3) }, -- far/zoomed in
    { vec(0, 1, -70), vec(10, 6, 100) }, -- zoomed out
}
for _, case in cases do
    local target = case[1]
    cameraOrigin = case[2]
    cameraHit = { Instance = wall, Position = target }
    local direction = (target - cameraOrigin).Unit
    check(projectile.Fire(player, target, cameraOrigin, direction), "valid clicked camera ray launches")
    local visual = visualProjectiles[#visualProjectiles]
    local muzzle = barrel.WorldPosition
    check((visual.CFrame.Position - muzzle).Magnitude < 0.001, "visible projectile starts at actual muzzle")
    local expected = (target - muzzle).Unit
    check((visual.CFrame.LookVector - expected).Magnitude < 0.001, "mesh forward axis matches convergent trajectory")
    advance(0.2)
    check(
        (visual.CFrame.Position - (muzzle + expected * 14)).Magnitude < 0.001,
        "70 studs/sec follows clicked target trajectory"
    )
    projectile.ClearPlayer(player)
    advance(2)
end
cameraOrigin = vec(5, 3, 12)
local target = vec(0, 1, -60)
local direction = (target - cameraOrigin).Unit
cameraHit = { Instance = wall, Position = cameraOrigin + direction * 20 }
check(projectile.Fire(player, target, cameraOrigin, direction), "camera wall resolves on server")
local wallVisual = visualProjectiles[#visualProjectiles]
check(
    (wallVisual.CFrame.LookVector - (cameraHit.Position - barrel.WorldPosition).Unit).Magnitude < 0.001,
    "client target beyond camera wall cannot choose trajectory through it"
)
projectile.ClearPlayer(player)
advance(2)
cameraHit = { Instance = wall, Position = target }
launchHit = { Instance = wall, Position = barrel.WorldPosition }
check(not projectile.Fire(player, target, cameraOrigin, direction), "clear camera cannot bypass blocked muzzle")
launchHit = nil
advance(0.11)
check(not projectile.Fire(player, target, vec(1000, 0, 0), direction), "distant fabricated camera rejected")
advance(0.11)
check(not projectile.Fire(player, target, cameraOrigin, vec(0 / 0, 0, -1)), "nonfinite camera direction rejected")
advance(0.11)
check(not projectile.Fire(player, target, cameraOrigin, direction * 2), "nonunit camera direction rejected")
advance(0.11)
check(
    not projectile.Fire(player, target + vec(10, 0, 0), cameraOrigin, direction),
    "target inconsistent with clicked ray rejected"
)
advance(0.11)
check(not projectile.Fire(player, vec(0, 0, -1000)), "legacy arbitrary excessive aim distance rejected")
advance(0.11)
check(projectile.Fire(player, target, cameraOrigin, direction), "valid shot after rejected intents")
sweptHit = { Instance = wall, Position = vec(0, 1, -8) }
advance(0.5)
check(
    visualProjectiles[#visualProjectiles].Destroyed and #impacts == 1,
    "muzzle-to-target swept path collides with world walls"
)
print("PASS: Ice Gun camera/muzzle convergence and geometry validation")
