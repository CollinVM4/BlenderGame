-- Ice Ray aim/camera validation: aim and camera data are crosshair intent
-- only. They must still be well-formed when supplied, but they no longer
-- derive a direction, an aim distance, muzzle occlusion or target visibility:
-- the blast is radial around the caster root, so a wall, a blocked muzzle or
-- an off-ray aim point cannot block a target inside the radius.
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
local playerRoot = player.Character:FindFirstChild("HumanoidRootPart")
playerRoot.Position = vec(0, 1, 0)
victim.Character:FindFirstChild("HumanoidRootPart").Position = vec(0, 1, -10)
local cameraOrigin = vec(5, 3, 12)
local wall = instance("Part")
wall.Parent = workspaceFake
-- Every raycast reports a wall: line of sight must not gate a radial blast.
workspaceFake.Raycast = function()
    return { Instance = wall, Position = playerRoot.Position }
end
local cameraDirection = vec(0, 0, -1)
local function fire(aim, origin, direction)
    return shotgun.Fire(player, aim, origin, direction)
end
check(fire(vec(0, 1, -10), cameraOrigin, cameraDirection), "aim on the camera ray fires")
check(victimH.Health == 95, "in-radius victim is hit regardless of aim direction")
advance(config.ShotCooldown)
-- Aim far away, off the camera ray, and behind the camera: all still fire,
-- because aim is intent only and the victim is inside the caster sphere.
check(fire(vec(0, 1, -1000), cameraOrigin, cameraDirection), "far aim point does not block a radial blast")
advance(config.ShotCooldown)
check(fire(vec(100, 50, 100), cameraOrigin, cameraDirection), "aim off the camera ray does not block a radial blast")
advance(config.ShotCooldown)
check(fire(vec(0, 1, 100), cameraOrigin, cameraDirection), "aim behind the caster does not block a radial blast")
advance(0.11)
-- Malformed payloads are still rejected, even though aim no longer gates hits.
check(not fire(vec(0 / 0, 0, -10), cameraOrigin, cameraDirection), "nonfinite aim rejected")
advance(0.11)
check(not fire({ Target = victim.Character }, cameraOrigin, cameraDirection), "client target payload rejected")
advance(0.11)
check(not fire(vec(0, 1, -10), vec(1000, 0, 0), cameraDirection), "distant fabricated camera rejected")
advance(0.11)
check(not fire(vec(0, 1, -10), cameraOrigin, vec(0 / 0, 0, -1)), "nonfinite camera direction rejected")
advance(0.11)
check(not fire(vec(0, 1, -10), cameraOrigin, vec(0, math.huge, -1)), "infinite camera direction rejected")
advance(0.11)
check(not fire(vec(0, 1, -10), cameraOrigin, vec(0, 0, 0)), "zero camera direction rejected")
advance(0.11)
check(not fire(vec(0, 1, -10), cameraOrigin, cameraDirection * 2), "nonunit camera direction rejected")
advance(0.11)
check(not fire(vec(0, 1, -10), cameraOrigin, nil), "partial camera payload rejected")
-- The rejected intents above did not advance the clock past the last
-- successful blast's cooldown, so clear that cooldown before the final shot.
advance(config.ShotCooldown)
check(fire(vec(0, 1, -10), cameraOrigin, cameraDirection), "valid intent fires after rejected intents")
print("PASS: Ice Ray radial aim/camera intent validation")
