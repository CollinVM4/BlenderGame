-- Authoritative cone/eligibility integration. Freeze lifecycle lives in freeze-status.
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
check(
    authoredConfig.MaximumRange == 22
        and authoredConfig.ConeAngleDegrees == 50
        and authoredConfig.ShotCooldown == 4.5
        and authoredConfig.DirectDamage == 5,
    "central shotgun range, full cone angle, cooldown and damage defaults"
)
local shooter, shooterHumanoid = fighter("A")
ready(shooter)
ownership[shooter.UserId] = true
gun.AddPlayer(shooter)
flush()
shooterHumanoid:EquipTool(gun.GrantIfOwned(shooter))
local tool = gun.GetEquipped(shooter)
local barrel = tool:FindFirstChild("Handle"):FindFirstChild("GunBarrel")
local muzzle = vec(0, 1, -2)
barrel.WorldPosition = muzzle
local aim = muzzle + vec(0, 0, -100)
local function target(session, distance, angle, vertical)
    local p, h = fighter(session)
    ready(p)
    freeze.ApplyCharacter(p, p.Character)
    flush()
    local r = math.rad(angle or 0)
    local offset = if vertical then vec(0, math.sin(r), -math.cos(r)) else vec(math.sin(r), 0, -math.cos(r))
    p.Character:FindFirstChild("HumanoidRootPart").Position = muzzle + offset * distance
    return p, h
end
local center, centerH = target("B", 10)
local left, leftH = target("C", 15, -24.99)
local right, rightH = target("D", 15, 24.99)
local above, aboveH = target("E", 15, 24.99, true)
local edge, edgeH = target("F", 22)
local beyond, beyondH = target("G", 22.01)
local outside, outsideH = target("H", 15, 25.01)
local below, belowH = target("I", 15, -25.01, true)
local behind, behindH = target("J", 10, 180)
local ally, allyH = target("A", 10)
local teammate, teammateH = target("K", 10)
local team = {}
shooter.Neutral, teammate.Neutral, shooter.Team, teammate.Team = false, false, team, team
local protected, protectedH = target("L", 10)
local forceField = instance("ForceField")
forceField.Parent = protected.Character
local unassigned, unassignedH = target(nil, 10)
local dead, deadH = target("M", 10)
deadH.Health = 0
local removed, removedH = target("N", 10)
removed.Parent = nil
local missingRoot, missingRootH = target("NoRoot", 10)
missingRoot.Character:FindFirstChild("HumanoidRootPart"):Destroy()
local removedCharacter, removedCharacterH = target("NoWorld", 10)
removedCharacter.Character.Parent = nil
local invalidPose, invalidPoseH = target("InvalidPose", 10)
invalidPose.Character:FindFirstChild("HumanoidRootPart").Position = vec(0 / 0, 1, -10)
local npc = instance("Model")
npc.Parent = workspaceFake
local npcRoot, npcH = instance("Part"), instance("Humanoid")
npcRoot.Name, npcRoot.Parent, npcRoot.Position = "HumanoidRootPart", npc, muzzle + vec(0, 0, -10)
npcH.Parent, npcH.Health = npc, 100
local blocked, blockedH = target("O", 10, 10)
local wall = instance("Part")
wall.Parent = workspaceFake
local blockLaunch = false
workspaceFake.Raycast = function(_, origin, direction)
    if blockLaunch then
        return { Instance = wall, Position = muzzle }
    end
    if (origin - muzzle).Magnitude < 0.001 and direction.Magnitude > 1 then
        if (origin + direction - blocked.Character:FindFirstChild("HumanoidRootPart").Position).Magnitude < 0.001 then
            return { Instance = wall, Position = origin + direction * 0.5 }
        end
        if (origin + direction - left.Character:FindFirstChild("HumanoidRootPart").Position).Magnitude < 0.001 then
            return { Instance = left.Character:FindFirstChild("HumanoidRootPart"), Position = origin + direction }
        end
    end
    return nil
end
check(not shotgun.Fire(ally, aim), "nonowner cannot fire")
check(not shotgun.Fire(shooter, { Target = center.Character, Damage = 999 }), "client target/damage payload rejected")
advance(0.11)
check(not shotgun.Fire(shooter, vec(0 / 0, 0, -10)), "nonfinite aim rejected")
advance(0.11)
check(not shotgun.Fire(shooter, muzzle), "zero aim direction rejected")
advance(0.11)
check(shotgun.Fire(shooter, aim), "entitled equipped owner fires cone")
check(
    shooter:GetAttribute("IceGunCooldownEnd") == workspaceFake:GetServerTimeNow() + config.ShotCooldown,
    "accepted shot publishes the 4.5-second server deadline"
)
for _, pair in { { center, centerH }, { left, leftH }, { right, rightH }, { above, aboveH }, { edge, edgeH } } do
    check(
        pair[2].Health == 95 and movement.IsFrozen(pair[1]),
        "one shot damages/freezes every visible in-cone enemy once"
    )
end
for _, pair in
    {
        { beyond, beyondH },
        { outside, outsideH },
        { below, belowH },
        { behind, behindH },
        { ally, allyH },
        { teammate, teammateH },
        { protected, protectedH },
        { unassigned, unassignedH },
        { removed, removedH },
        { blocked, blockedH },
        { missingRoot, missingRootH },
        { removedCharacter, removedCharacterH },
        { invalidPose, invalidPoseH },
    }
do
    check(
        pair[2].Health == 100 and not movement.IsFrozen(pair[1]),
        "ineligible/outside/occluded target remains untouched"
    )
end
check(shooterHumanoid.Health == 100 and deadH.Health == 0, "self and dead targets remain untouched")
check(npcH.Health == 100, "NPC customers are outside player-only ice combat")
advance(2.5)
check(
    centerH.Health == 95 and not movement.IsFrozen(center),
    "shot uses existing freeze and has no delayed damage replay"
)
tool.Parent = shooter:FindFirstChildOfClass("Backpack")
shotgun.ClearPlayer(shooter)
tool.Parent = shooter.Character
advance(config.ShotCooldown - 2.51)
local confirmedBeforeReject = shooter:GetAttribute("IceGunCooldownEnd")
local accepted, reason = shotgun.Fire(shooter, aim)
check(
    not accepted and reason == "shot cooldown",
    "put-away/re-equip cannot bypass 4.5-second cooldown and returns specific rejection"
)
check(
    shooter:GetAttribute("IceGunCooldownEnd") == confirmedBeforeReject,
    "rejected shot never starts or extends UI cooldown"
)
advance(0.11)
check(shotgun.Fire(shooter, aim), "shot eligible after server cooldown")
check(centerH.Health == 90, "next shot deals exactly five damage")
advance(config.ShotCooldown)
config.TeamDamage = true
check(shotgun.Fire(shooter, aim), "server explicitly opts in to friendly fire")
check(
    allyH.Health == 95 and teammateH.Health == 95 and shooterHumanoid.Health == 100,
    "opt-in permits both teammate types, still rejects self"
)
config.TeamDamage = false
check(
    not combat.CanDamagePlayer(shooter, ally) and not combat.CanDamagePlayer(shooter, teammate),
    "bat/default combat retains team protection"
)
advance(config.ShotCooldown)
tool.Parent = shooter:FindFirstChildOfClass("Backpack")
check(not shotgun.Fire(shooter, aim), "owned but unequipped Tool cannot fire")
local forged = template:Clone()
forged:SetAttribute("IceGunWeapon", true)
forged.Parent = shooter.Character
advance(0.11)
check(not shotgun.Fire(shooter, aim), "forged weapon attribute cannot authorize fire")
forged:Destroy()
tool.Parent = shooter.Character
advance(0.11)
movement.SetFrozen(shooter, true)
check(not shotgun.Fire(shooter, aim), "frozen attacker cannot fire")
movement.SetFrozen(shooter, false)
advance(0.11)
movement.SetStunned(shooter, true)
check(not shotgun.Fire(shooter, aim), "bat-stunned attacker cannot fire")
movement.SetStunned(shooter, false)
advance(0.11)
shooterHumanoid.PlatformStand = true
check(not shotgun.Fire(shooter, aim), "physical ragdoll blocks fire")
shooterHumanoid.PlatformStand = false
advance(0.11)
barrel.WorldPosition = vec(0, 1, -100)
check(not shotgun.Fire(shooter, aim), "manipulated muzzle pose rejected")
barrel.WorldPosition = muzzle
advance(0.11)
blockLaunch = true
check(not shotgun.Fire(shooter, aim), "blocked root-to-muzzle path rejected")
blockLaunch = false
advance(0.11)
local oversizedBody = instance("Part")
oversizedBody.Parent, oversizedBody.CanCollide, oversizedBody.Size = shooter.Character, true, vec(20, 20, 20)
oversizedBody.CFrame.PointToObjectSpace = function(_, v)
    return v
end
check(not shotgun.Fire(shooter, aim), "muzzle enclosed in shooter collision geometry rejected")
oversizedBody:Destroy()
advance(0.11)
shooterHumanoid.Health = 0
check(not shotgun.Fire(shooter, aim), "dead shooter cannot fire")
shooterHumanoid.Health = 100
advance(0.11)
sessions[shooter] = nil
local before = centerH.Health
check(shotgun.Fire(shooter, aim) and centerH.Health == before, "pre-claim ownership permits effects but never PvP")
sessions[shooter] = "A"
advance(config.ShotCooldown)
local old = center.Character
center.Character = instance("Model")
check(not combat.DamagePlayer(shooter, center, old, 5), "stale target character cannot receive damage")
center.Character = old
setup(freeze.Apply(center), "immunity test freeze")
advance(config.FreezeSeconds)
check(shotgun.Fire(shooter, aim), "shot during target recovery immunity")
check(
    centerH.Health == before - 5 and not movement.IsFrozen(center),
    "freeze immunity prevents re-freeze without blocking damage"
)
-- Rejection feedback must describe the actual failure even during cooldown.
advance(0.11)
blockLaunch = true
local blockedAccepted, blockedReason = shotgun.Fire(shooter, aim)
check(
    not blockedAccepted and blockedReason ~= "shot cooldown",
    "invalid muzzle during cooldown does not produce cooldown feedback"
)
blockLaunch = false
advance(config.ShotCooldown - 0.11)
check(shotgun.Fire(shooter, aim), "shot fires at exactly the authoritative cooldown deadline")
-- UI authority persists across putting the weapon away and resets only with character lifecycle.
local beforeDeadline = shooter:GetAttribute("IceGunCooldownEnd")
check(typeof(beforeDeadline) == "number", "accepted shots publish a server-time deadline")
shotgun.ClearPlayer(shooter)
check(shooter:GetAttribute("IceGunCooldownEnd") == beforeDeadline, "unequip preserves replicated cooldown")
shotgun.RemovePlayer(shooter)
check(shooter:GetAttribute("IceGunCooldownEnd") == 0, "character lifecycle clears replicated cooldown")
local temporaryShooter = fighter("TemporaryAdminGrant")
ready(temporaryShooter)
gun.AddPlayer(temporaryShooter)
flush()
local temporaryGun = gun.GrantOnce(temporaryShooter)
setup(temporaryGun ~= nil and gun.RequestSelection(temporaryShooter, temporaryGun, true), "equip admin-issued gun")
temporaryGun:FindFirstChild("Handle"):FindFirstChild("GunBarrel").WorldPosition = muzzle
check(
    shotgun.Fire(temporaryShooter, aim) and not gun.PlayerOwns(temporaryShooter),
    "one-life admin grant fires through normal combat without gamepass ownership"
)
print("PASS: Ice Shotgun cone/combat integration")
