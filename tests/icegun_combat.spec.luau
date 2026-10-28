-- Authoritative radial blast / eligibility integration. Freeze lifecycle lives in freeze-status.
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
    authoredConfig.BlastRadius == 22
        and authoredConfig.ConeAngleDegrees == nil
        and authoredConfig.ShotCooldown == 4.5
        and authoredConfig.DirectDamage == 5,
    "central radial blast radius, cooldown and damage defaults, with no leftover cone angle"
)
local shooter, shooterHumanoid = fighter("A")
ready(shooter)
ownership[shooter.UserId] = true
gun.AddPlayer(shooter)
flush()
shooterHumanoid:EquipTool(gun.GrantIfOwned(shooter))
local tool = gun.GetEquipped(shooter)
local barrel = tool:FindFirstChild("Handle"):FindFirstChild("GunBarrel")
barrel.WorldPosition = vec(0, 1, -2)
-- The blast is centered on the caster root, so every target offset below is
-- measured from the root, not from the muzzle, and in every direction: a
-- radial blast has no forward, angle or line-of-sight condition.
local shooterRoot = shooter.Character:FindFirstChild("HumanoidRootPart")
shooterRoot.Position = vec(0, 1, 0)
local aim = vec(0, 1, -100)
local function target(session, offset)
    local p, h = fighter(session)
    ready(p)
    freeze.ApplyCharacter(p, p.Character)
    flush()
    p.Character:FindFirstChild("HumanoidRootPart").Position = shooterRoot.Position + offset
    return p, h
end
local center, centerH = target("B", vec(0, 0, -10))
local left, leftH = target("C", vec(-15, 0, 0))
local right, rightH = target("D", vec(15, 0, 0))
local above, aboveH = target("E", vec(0, 15, 0))
local below, belowH = target("I", vec(0, -10, 0))
local edge, edgeH = target("F", vec(22, 0, 0))
local beyond, beyondH = target("G", vec(0, 0, 22.01))
local far, farH = target("H", vec(-22.01, 0, 0))
local behind, behindH = target("J", vec(0, 0, 15))
local ally, allyH = target("A", vec(-7, 0, -7))
local teammate, teammateH = target("K", vec(7, 0, 7))
local team = {}
shooter.Neutral, teammate.Neutral, shooter.Team, teammate.Team = false, false, team, team
local protected, protectedH = target("L", vec(10, 0, 10))
local forceField = instance("ForceField")
forceField.Parent = protected.Character
local unassigned, unassignedH = target(nil, vec(-10, 0, -10))
local dead, deadH = target("M", vec(10, 0, -10))
deadH.Health = 0
local removed, removedH = target("N", vec(-15, 0, 5))
removed.Parent = nil
local missingRoot, missingRootH = target("NoRoot", vec(5, 0, -15))
missingRoot.Character:FindFirstChild("HumanoidRootPart"):Destroy()
local removedCharacter, removedCharacterH = target("NoWorld", vec(-5, 0, 15))
removedCharacter.Character.Parent = nil
local invalidPose, invalidPoseH = target("InvalidPose", vec(15, 0, 5))
invalidPose.Character:FindFirstChild("HumanoidRootPart").Position = vec(0 / 0, 1, -10)
local npc = instance("Model")
npc.Parent = workspaceFake
local npcRoot, npcH = instance("Part"), instance("Humanoid")
npcRoot.Name, npcRoot.Parent, npcRoot.Position = "HumanoidRootPart", npc, shooterRoot.Position + vec(0, 0, -10)
npcH.Parent, npcH.Health = npc, 100
-- A target behind a wall. The old cone raycast would have blocked it; the
-- radial blast must not consult line of sight at all, so this raycast always
-- reports a wall and the target must still be hit.
local walled, walledH = target("O", vec(0, 0, 10))
local wall = instance("Part")
wall.Parent = workspaceFake
workspaceFake.Raycast = function()
    return { Instance = wall, Position = shooterRoot.Position }
end
check(not shotgun.Fire(ally, aim), "nonowner cannot fire")
check(not shotgun.Fire(shooter, { Target = center.Character, Damage = 999 }), "client target/damage payload rejected")
advance(0.11)
check(not shotgun.Fire(shooter, vec(0 / 0, 0, -10)), "nonfinite aim rejected")
advance(0.11)
check(shotgun.Fire(shooter, aim), "entitled equipped owner fires radial blast")
check(
    shooter:GetAttribute("IceGunCooldownEnd") == workspaceFake:GetServerTimeNow() + config.ShotCooldown,
    "accepted blast publishes the 4.5-second server deadline"
)
for _, pair in
    {
        { center, centerH },
        { left, leftH },
        { right, rightH },
        { above, aboveH },
        { below, belowH },
        { edge, edgeH },
        { behind, behindH },
        { walled, walledH },
    }
do
    check(
        pair[2].Health == 95 and movement.IsFrozen(pair[1]),
        "one blast damages/freezes every in-radius enemy once, in every direction, through walls"
    )
end
for _, pair in
    {
        { beyond, beyondH },
        { far, farH },
        { ally, allyH },
        { teammate, teammateH },
        { protected, protectedH },
        { unassigned, unassignedH },
        { removed, removedH },
        { missingRoot, missingRootH },
        { removedCharacter, removedCharacterH },
        { invalidPose, invalidPoseH },
    }
do
    check(
        pair[2].Health == 100 and not movement.IsFrozen(pair[1]),
        "ineligible/outside-radius target remains untouched"
    )
end
check(shooterHumanoid.Health == 100 and deadH.Health == 0, "self and dead targets remain untouched")
check(npcH.Health == 100, "NPC models without a wired customer system are untouched by player combat")
advance(config.FreezeSeconds)
check(
    centerH.Health == 95 and not movement.IsFrozen(center),
    "blast uses existing freeze and has no delayed damage replay"
)
tool.Parent = shooter:FindFirstChildOfClass("Backpack")
shotgun.ClearPlayer(shooter)
tool.Parent = shooter.Character
advance(config.ShotCooldown - config.FreezeSeconds - 0.01)
local confirmedBeforeReject = shooter:GetAttribute("IceGunCooldownEnd")
local accepted, reason = shotgun.Fire(shooter, aim)
check(
    not accepted and reason == "shot cooldown",
    "put-away/re-equip cannot bypass 4.5-second cooldown and returns specific rejection"
)
check(
    shooter:GetAttribute("IceGunCooldownEnd") == confirmedBeforeReject,
    "rejected blast never starts or extends UI cooldown"
)
advance(0.11)
check(shotgun.Fire(shooter, aim), "blast eligible after server cooldown")
check(centerH.Health == 90, "next blast deals exactly five damage")
check(not movement.IsFrozen(center), "damage during freeze immunity does not re-freeze")
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
-- Muzzle pose is no longer a hit origin, so a far or enclosed muzzle cannot
-- block a radial blast centered on the caster root.
barrel.WorldPosition = vec(0, 1, -100)
check(shotgun.Fire(shooter, aim), "manipulated muzzle pose cannot block a radial blast")
barrel.WorldPosition = vec(0, 1, -2)
advance(0.11)
shooterHumanoid.Health = 0
check(not shotgun.Fire(shooter, aim), "dead shooter cannot fire")
shooterHumanoid.Health = 100
advance(0.11)
-- The muzzle-pose blast above reset the shooter's cooldown, so clear it
-- before the pre-claim shot, which must be accepted to test its no-damage rule.
advance(config.ShotCooldown)
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
check(shotgun.Fire(shooter, aim), "blast during target recovery immunity")
check(
    centerH.Health == before - 5 and not movement.IsFrozen(center),
    "freeze immunity prevents re-freeze without blocking damage"
)
-- An invalid caster root must be rejected on its own merits, not as cooldown.
advance(0.11)
shooterRoot.Position = vec(0 / 0, 1, 0)
local invalidAccepted, invalidReason = shotgun.Fire(shooter, aim)
check(
    not invalidAccepted and invalidReason == "invalid character root",
    "invalid caster root rejected even during cooldown"
)
shooterRoot.Position = vec(0, 1, 0)
advance(config.ShotCooldown)
check(shotgun.Fire(shooter, aim), "blast fires at exactly the authoritative cooldown deadline")
-- UI authority persists across putting the weapon away and resets only with character lifecycle.
local beforeDeadline = shooter:GetAttribute("IceGunCooldownEnd")
check(typeof(beforeDeadline) == "number", "accepted blasts publish a server-time deadline")
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
check(
    shotgun.Fire(temporaryShooter, aim) and not gun.PlayerOwns(temporaryShooter),
    "one-life admin grant fires through normal combat without gamepass ownership"
)
print("PASS: Ice Ray radial blast/combat integration")
