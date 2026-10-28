-- Focused Ice Ray radial contracts: boundary, movement, caster exclusion,
-- exactly-once-per-blast, and NPC customer reaction through the radius query.
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
local shooter, shooterHumanoid = fighter("A")
ready(shooter)
ownership[shooter.UserId] = true
gun.AddPlayer(shooter)
flush()
shooterHumanoid:EquipTool(gun.GrantIfOwned(shooter))
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
-- Every compass direction plus straight up and straight down, all in radius.
local north, northH = target("B", vec(0, 0, -12))
local south, southH = target("C", vec(0, 0, 12))
local east, eastH = target("D", vec(12, 0, 0))
local west, westH = target("E", vec(-12, 0, 0))
local up, upH = target("F", vec(0, 12, 0))
local down, downH = target("G", vec(0, -12, 0))
local nearEdge, nearEdgeH = target("H", vec(21.9, 0, 0))
local atEdge, atEdgeH = target("I", vec(0, 0, -22))
local pastEdge, pastEdgeH = target("J", vec(0, 0, 22.01))
-- A target that moves between blasts: position at fire time is what counts.
local mover, moverH = target("K", vec(30, 0, 0))
check(shotgun.Fire(shooter, aim), "radial blast fires")
for _, pair in
    {
        { north, northH },
        { south, southH },
        { east, eastH },
        { west, westH },
        { up, upH },
        { down, downH },
        { nearEdge, nearEdgeH },
        { atEdge, atEdgeH },
    }
do
    check(pair[2].Health == 95, "in-radius target in every direction takes exactly five damage once")
end
check(pastEdgeH.Health == 100, "target 0.01 studs past the radius is unaffected")
check(moverH.Health == 100, "target outside the radius at fire time is unaffected")
check(shooterHumanoid.Health == 100, "caster is never damaged by its own blast")
advance(config.FreezeSeconds + config.ImmunitySeconds + config.ShotCooldown)
-- The mover walks into the blast before the next activation.
mover.Character:FindFirstChild("HumanoidRootPart").Position = shooterRoot.Position + vec(10, 0, 0)
check(shotgun.Fire(shooter, aim), "second blast fires after cooldown and immunity")
check(moverH.Health == 95, "target that moved inside the radius before firing is hit")
check(northH.Health == 90, "repeat blast deals exactly five more damage, never a double hit per blast")
advance(config.FreezeSeconds + config.ImmunitySeconds + config.ShotCooldown)
-- The mover walks out before the next activation.
mover.Character:FindFirstChild("HumanoidRootPart").Position = shooterRoot.Position + vec(30, 0, 0)
check(shotgun.Fire(shooter, aim), "third blast fires")
check(moverH.Health == 95, "target that moved outside the radius before firing is unaffected")
-- Caster exclusion survives the friendly-fire opt-in.
config.TeamDamage = true
advance(config.ShotCooldown)
check(shotgun.Fire(shooter, aim), "opt-in blast fires")
check(shooterHumanoid.Health == 100, "caster stays excluded even with friendly fire opted in")
config.TeamDamage = false
-- NPC customers: a stubbed customer system, a radius query that returns two
-- parts of one in-radius model and the root of a model outside the radius.
local npcHits = {}
deps.CustomerService = {
    CanHitCustomer = function(_, model)
        return model.Name == "CustomerIn"
    end,
    HitCustomer = function(_, model, context)
        npcHits[model] = (npcHits[model] or 0) + 1
        check(
            context.Direction.Magnitude > 0.99 and context.Direction.Magnitude < 1.01,
            "NPC reaction direction is a unit away-from-caster vector"
        )
        return true
    end,
}
local npcIn = instance("Model")
npcIn.Name, npcIn.Parent = "CustomerIn", workspaceFake
local npcInRoot = instance("Part")
npcInRoot.Name, npcInRoot.Parent, npcInRoot.Position = "HumanoidRootPart", npcIn, shooterRoot.Position + vec(5, 0, 0)
local npcInLimb = instance("Part")
npcInLimb.Name, npcInLimb.Parent = "Limb", npcIn
local npcOut = instance("Model")
npcOut.Name, npcOut.Parent = "CustomerOut", workspaceFake
local npcOutRoot = instance("Part")
npcOutRoot.Name, npcOutRoot.Parent, npcOutRoot.Position =
    "HumanoidRootPart", npcOut, shooterRoot.Position + vec(30, 0, 0)
workspaceFake.GetPartBoundsInRadius = function(_, origin, radius)
    check(radius == config.BlastRadius, "NPC query uses the same authoritative blast radius")
    return { npcInRoot, npcInLimb, npcOutRoot }
end
advance(config.ShotCooldown)
check(shotgun.Fire(shooter, aim), "blast with NPC customers in range fires")
check(npcHits[npcIn] == 1, "in-radius NPC customer reacts exactly once per blast despite two queried parts")
check(npcHits[npcOut] == nil, "NPC customer outside the radius does not react")
print("PASS: Ice Ray radial boundary, movement, caster exclusion and NPC reaction")
