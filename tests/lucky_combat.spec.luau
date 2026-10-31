local active = {}
dependency.LuckyBlockService = {
    IsBuffActive = function(p, id)
        return active[p] == id
    end,
}
local attacker = fighter(0)
local victim, humanoid = fighter(-3)
tycoon.SetCash(attacker, 1000000)
setup(tycoon.PurchaseUpgrade(attacker, "Bat", 2, tycoon.GetRequestContext(attacker)), "purchase bat")
equip(attacker)
local root = victim.Character:FindFirstChild("HumanoidRootPart")
overlaps = { root }
for _, buff in { "StarPower", "Invincibility" } do
    active[victim] = buff
    check(not combat.DamagePlayer(attacker, victim, victim.Character, 20), "immune victim rejects player damage")
    check(combat.SwingBat(attacker), "immune target does not alter attack eligibility")
    advance(config.HitActiveStart + 0.001)
    heartbeat()
    check(humanoid.Health == 100 and not movement.IsStunned(victim), "immune bat hit skips damage and stun")
    check(root.AssemblyLinearVelocity.Magnitude == 0, "immune bat hit skips impulse")
    advance(config.SwingCooldown)
end
active[victim] = nil
active[attacker] = "MegaBat"
check(combat.SwingBat(attacker), "MegaBat swing accepted")
advance(config.HitActiveStart + 0.001)
heartbeat()
local tuning = config.Levels[1]
check(
    math.abs(root.Impulse.Z / root.AssemblyMass + tuning.HorizontalKnockback * 2) < 0.001,
    "MegaBat doubles slap impulse"
)
advance(config.SwingCooldown * 0.5 - config.HitActiveStart)
check(combat.SwingBat(attacker), "MegaBat halves swing cooldown")
advance(config.SwingCooldown)
active[attacker] = nil
check(combat.SwingBat(attacker), "normal swing accepted")
advance(config.SwingCooldown * 0.5)
check(not combat.SwingBat(attacker), "normal cooldown preserved")
-- Immunity acquired between hit and deferred physics also suppresses launch.
advance(config.SwingCooldown + config.Levels[1].StunDuration + config.ImmunitySeconds)
check(combat.SwingBat(attacker), "later normal attack")
advance(config.HitActiveStart + 0.001)
local before = root.ImpulseCount
active[victim] = "Invincibility"
heartbeat()
check(root.ImpulseCount == before, "deferred impulse rechecks immunity")
print("PASS: Lucky combat gates")
