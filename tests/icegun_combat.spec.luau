local gun = loadModule("IceGunService")
local projectile = loadModule("IceGunProjectileService")
local freeze = loadModule("FreezeStatusService")
local combat = loadModule("CombatService")
deps.IceGunService, deps.IceGunProjectileService, deps.FreezeStatusService, deps.CombatService =
    gun, projectile, freeze, combat
combat.Init(deps)
freeze.Init(deps)
projectile.Init(deps)
gun.Init(deps)
local shooter, shooterHumanoid = fighter("A")
local enemy, enemyHumanoid = fighter("B")
local ally, allyHumanoid = fighter("A")
ready(shooter)
ready(enemy)
ready(ally)
freeze.ApplyCharacter(enemy, enemy.Character)
ownership[shooter.UserId] = true
gun.AddPlayer(shooter)
flush()
if not gun.IsEquipped(shooter) then
    shooterHumanoid:EquipTool(gun.GrantIfOwned(shooter)) -- Normal hotbar selection; no pedestal request.
end
setup(gun.IsEquipped(shooter), "first equipped issued gun")
local tool = gun.GetEquipped(shooter)
local barrel = tool:FindFirstChild("Handle"):FindFirstChild("GunBarrel")
barrel.WorldPosition = vec(0, 1, -2)
local aim = vec(0, 1, -100)
local nextHit = nil
local lastRayLength = 0
workspaceFake.Raycast = function(_, _, direction)
    lastRayLength = direction.Magnitude
    return nextHit
end
check(not projectile.Fire(ally, aim), "nonowner cannot fire")
check(
    not projectile.Fire(shooter, { Target = enemy.Character, Damage = 999 }),
    "client target/damage requests are rejected"
)
advance(0.11)
check(not projectile.Fire(shooter, vec(0 / 0, 1, -10)), "nonfinite aim rejected")
advance(0.11)
check(projectile.Fire(shooter, aim), "owner fires equipped issued tool")
local first = visualProjectiles[#visualProjectiles]
local origin = first.CFrame.Position
check((origin - barrel.WorldPosition).Magnitude < 0.001, "projectile begins at server GunBarrel, not avatar clearance")
advance(0.5)
check(
    math.abs((first.CFrame.Position - origin).Magnitude - 35) < 0.001 and math.abs(lastRayLength - 35) < 0.001,
    "70 studs/sec visible travel uses full swept segment"
)
check(not projectile.Fire(shooter, aim), "server rejects rapid shots")
nextHit = { Instance = enemy.Character:FindFirstChild("HumanoidRootPart"), Position = vec(0, 1, -45) }
advance(0.1)
nextHit = nil
check(enemyHumanoid.Health == 86 and movement.IsFrozen(enemy), "direct enemy hit deals 14 HP and guaranteed freeze")
check(first.Destroyed and #impacts == 1, "direct impact resolves once and removes simulation visual")
advance(0.1)
check(enemyHumanoid.Health == 86, "terminated projectile cannot damage victim twice")
advance(2.65)
check(not movement.IsFrozen(enemy), "direct hit freeze thaws at 2.75 seconds")
check(projectile.Fire(shooter, aim), "two-second cooldown permits next shot")
nextHit = { Instance = enemy.Character:FindFirstChild("HumanoidRootPart"), Position = vec(0, 1, -10) }
advance(0.1)
nextHit = nil
check(enemyHumanoid.Health == 72 and not movement.IsFrozen(enemy), "shots in immunity still damage without re-freeze")
advance(4)
check(projectile.Fire(shooter, aim), "fire after freeze immunity")
nextHit = { Instance = enemy.Character:FindFirstChild("HumanoidRootPart"), Position = vec(0, 1, -10) }
advance(0.1)
nextHit = nil
check(enemyHumanoid.Health == 58 and movement.IsFrozen(enemy), "direct freeze resumes after immunity")
advance(2)
check(projectile.Fire(shooter, aim), "team shot launched")
-- Membership changes after launch must be observed at impact.
sessions[enemy] = "A"
nextHit = { Instance = enemy.Character:FindFirstChild("HumanoidRootPart"), Position = vec(0, 1, -10) }
advance(0.1)
nextHit = nil
check(
    enemyHumanoid.Health == 58 and allyHumanoid.Health == 100,
    "current teammates are protected at impact, no splash damage"
)
sessions[enemy] = "B"
advance(2)
check(projectile.Fire(shooter, aim), "wall shot launched")
local wall = instance("Part")
wall.Parent = workspaceFake
nextHit = { Instance = wall, Position = vec(0, 1, -10) }
advance(0.1)
nextHit = nil
check(
    enemyHumanoid.Health == 58 and visualProjectiles[#visualProjectiles].Destroyed,
    "world obstacle shatters projectile without hitting through wall"
)
advance(2)
check(projectile.Fire(shooter, aim), "NPC shot launched")
local npc = instance("Model")
npc.Parent = workspaceFake
local npcRoot = instance("Part")
npcRoot.Parent = npc
local npcHumanoid = instance("Humanoid")
npcHumanoid.Health, npcHumanoid.Parent = 100, npc
nextHit = { Instance = npcRoot, Position = vec(0, 1, -10) }
advance(0.1)
nextHit = nil
check(npcHumanoid.Health == 100, "nonplayer customers take no ice weapon damage")
advance(2)
check(projectile.Fire(shooter, aim), "range shot launched")
local ranged = visualProjectiles[#visualProjectiles]
local rangeOrigin = ranged.CFrame.Position
advance(config.ProjectileLifetime)
check(
    ranged.Destroyed and (ranged.CFrame.Position - rangeOrigin).Magnitude <= 110.001,
    "projectiles expire at maximum range/lifetime"
)
advance(0.5)
movement.SetFrozen(shooter, true)
check(not projectile.Fire(shooter, aim), "frozen attacker cannot fire")
movement.SetFrozen(shooter, false)
advance(0.11)
barrel.WorldPosition = vec(0, 1, -100)
check(not projectile.Fire(shooter, aim), "server rejects remote manipulated muzzle pose")
barrel.WorldPosition = vec(0, 1, -2)
advance(0.11)
nextHit = { Instance = wall, Position = vec(0, 1, -2) }
check(not projectile.Fire(shooter, aim), "obstructed launch clearance cannot spawn through geometry")
nextHit = nil
advance(0.11)
check(projectile.Fire(shooter, aim), "final lifecycle shot")
local last = visualProjectiles[#visualProjectiles]
shooterHumanoid.Health = 0
advance(0.1)
check(last.Destroyed, "dead shooter leaves no active projectile")
shooterHumanoid.Health = 100
sessions[enemy] = nil
check(
    not combat.CanDamagePlayer(shooter, enemy) and not combat.CanDamagePlayer(shooter, shooter),
    "existing unassigned/self PvP rules apply"
)
sessions[enemy] = "B"
local forceField = instance("ForceField")
forceField.Parent = enemy.Character
check(
    not combat.DamagePlayer(shooter, enemy, enemy.Character, 14) and enemyHumanoid.Health == 58,
    "respawn ForceField blocks damage and freeze"
)
forceField:Destroy()
local oldCharacter = enemy.Character
local replacement = instance("Model")
enemy.Character = replacement
check(not combat.DamagePlayer(shooter, enemy, oldCharacter, 14), "stale character references cannot damage a respawn")
enemy.Character = oldCharacter
advance(2)
local oversizedBody = instance("Part")
oversizedBody.Parent, oversizedBody.CanCollide = shooter.Character, true
oversizedBody.Size = vec(20, 20, 20)
oversizedBody.CFrame.PointToObjectSpace = function(_, v)
    return v
end
check(not projectile.Fire(shooter, aim), "projectile may not originate inside shooter collision geometry")
oversizedBody:Destroy()
advance(0.11)
shooterHumanoid.PlatformStand = true
check(not projectile.Fire(shooter, aim), "physical ragdoll/action block rejects new shots")
shooterHumanoid.PlatformStand = false
advance(0.11)
check(projectile.Fire(shooter, aim), "delayed heartbeat shot")
local delayed = visualProjectiles[#visualProjectiles]
nextHit = { Instance = enemy.Character:FindFirstChild("HumanoidRootPart"), Position = vec(0, 1, -10) }
advance(5)
nextHit = nil
check(
    delayed.Destroyed and enemyHumanoid.Health == 58,
    "long server stall cannot replay an expired damaging projectile"
)
local respawned, respawnHumanoid = fighter("A")
shooter.CharacterRemoving:Fire(shooter.Character)
shooter.Character = respawned.Character
respawned.Character = nil
gun.ApplyCharacter(shooter, shooter.Character)
ready(shooter)
flush()
local respawnTool = gun.GrantIfOwned(shooter)
respawnHumanoid:EquipTool(respawnTool)
respawnTool:FindFirstChild("Handle"):FindFirstChild("GunBarrel").WorldPosition = vec(0, 1, -2)
check(
    guns(shooter) == 1 and projectile.Fire(shooter, aim),
    "respawned gun fires on first hotbar selection without pedestal"
)
print("PASS: Ice Gun projectile/combat integration")
