-- The shared Instance double stores attributes without firing their signals.
local function publishStage(p, stage)
    p:SetAttribute("TutorialStage", stage)
    p:GetAttributeChangedSignal("TutorialStage"):Fire()
end
local protection = loadModule("ProtectionService")
local combat = loadModule("CombatService")
local shotgun = loadModule("IceGunProjectileService")
local freeze = loadModule("FreezeStatusService")
local gun = loadModule("IceGunService")
deps.ProtectionService, deps.CombatService, deps.FreezeStatusService, deps.IceGunService =
    protection, combat, freeze, gun
deps.IceGunProjectileService = shotgun
combat.Init(deps)
freeze.Init(deps)
shotgun.Init(deps)
gun.Init(deps)
local shooter, shooterH = fighter("A")
local victim, victimH = fighter("B")
ready(shooter)
ready(victim)
freeze.ApplyCharacter(victim, victim.Character)
protection.Init()
ownership[shooter.UserId] = true
gun.AddPlayer(shooter)
flush()
shooterH:EquipTool(gun.GrantIfOwned(shooter))
shooter.Character:FindFirstChild("HumanoidRootPart").Position = vec(0, 1, 0)
victim.Character:FindFirstChild("HumanoidRootPart").Position = vec(0, 1, -10)
check(shotgun.Fire(shooter, vec(0, 1, -100)), "protected shooter may fire")
check(victimH.Health == 100 and not movement.IsFrozen(victim), "protected victim takes no ice damage or freeze")
check(protection.IsProtected(shooter), "blocked ice hit does not forfeit")
publishStage(victim, "Complete")
local damage = victimH.TakeDamage
victimH.TakeDamage = function() end
advance(config.ShotCooldown)
setup(shotgun.Fire(shooter, vec(0, 1, -100)), "ineffective blast")
check(
    not movement.IsFrozen(victim) and protection.IsProtected(shooter),
    "ineffective damage neither freezes nor forfeits"
)
victimH.TakeDamage = damage
advance(config.ShotCooldown)
setup(shotgun.Fire(shooter, vec(0, 1, -100)), "eligible blast")
-- PROPOSED/UNCONFIRMED: ice-triggered forfeiture awaits Collin's design confirmation.
check(
    victimH.Health == 95 and movement.IsFrozen(victim) and not protection.IsProtected(shooter),
    "successful ice effect forfeits"
)
local environmental = fighter("C")
protection.AddPlayer(environmental)
environmental.Character:FindFirstChildOfClass("Humanoid"):TakeDamage(10)
check(protection.IsProtected(environmental), "environmental damage does not forfeit")
print("PASS: protection ice integration")
