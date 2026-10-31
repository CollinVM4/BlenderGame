-- The shared Instance double stores attributes without firing their signals.
local function publishStage(p, stage)
    p:SetAttribute("TutorialStage", stage)
    p:GetAttributeChangedSignal("TutorialStage"):Fire()
end
local protection = loadModule("ProtectionService")
dependency.ProtectionService = protection
local attacker, attackerH = fighter(0)
local victim, victimH = fighter(-3)
local teammate = fighter(-2)
protection.Init()
tycoon.RemovePlayer(teammate)
setup(tycoon.JoinSession(teammate, victim, tycoon.GetRequestContext(victim)), "join victim team")
carry(victim, "Banana")
setup(inventory.Deposit(victim, "Banana", 3), "seed hostile slot")
check(not inventory.CanWithdraw(attacker, victim, 3), "protected stash rejects stranger")
check(
    not inventory.Withdraw(attacker, 3, victim) and not inventory.Steal(attacker, victim, 3),
    "direct routes cannot bypass gate"
)
local accepted, reason = press(attacker, "TAKE", 3, victim)
check(not accepted and reason == "PROTECTED!", "existing generic feedback reaches taker")
check(inventory.Withdraw(teammate, 3, victim), "teammate access retained")
check(protection.IsProtected(teammate), "friendly take does not forfeit")
inventory.ClearHeld(teammate)
carry(victim, "Milk")
setup(inventory.Deposit(victim, "Milk", 3), "restore stash")
check(inventory.Withdraw(victim, 3), "self access retained")
check(protection.IsProtected(victim), "self access does not forfeit")
inventory.ClearHeld(victim)
carry(victim, "Milk")
setup(inventory.Deposit(victim, "Milk", 3), "seed NPC theft")
check(
    inventory.RemoveThiefIngredient(victim, tycoon.GetSessionId(victim)) ~= nil,
    "NPC theft bypasses only newbie protection"
)
check(protection.IsProtected(victim), "NPC theft does not forfeit player protection")
tycoon.SetCash(attacker, 1000000)
setup(tycoon.PurchaseUpgrade(attacker, "Bat", 2, tycoon.GetRequestContext(attacker)), "purchase bat")
equip(attacker)
carry(victim, "Banana")
local root = victim.Character:FindFirstChild("HumanoidRootPart")
overlaps = { root }
check(combat.SwingBat(attacker), "protected attacker may swing")
advance(config.HitActiveStart + 0.001)
heartbeat()
check(victimH.Health == 100 and not movement.IsStunned(victim), "protection rejects bat damage and stun")
check(inventory.GetCarryCount(victim) == 1 and not physical[victim.Character], "protection rejects drops and ragdoll")
check(root.ImpulseCount == nil, "protection rejects knockback")
check(protection.IsProtected(attacker), "blocked bat does not forfeit")
-- NPC dispatch is a separate existing application path, with no player effect.
local npc = instance("Model")
npc.Name, npc.Parent = "Customer", workspaceFake
local npcRoot = part("HumanoidRootPart", npc)
npcRoot.Position = vec(0, 0, -3)
local npcHits = 0
local oldCustomer = dependency.CustomerService
dependency.CustomerService = {
    CanHitCustomer = function(_, model)
        return model == npc
    end,
    HitCustomer = function()
        npcHits += 1
        return true
    end,
}
overlaps = { npcRoot }
advance(config.SwingCooldown)
setup(combat.SwingBat(attacker), "NPC swing")
advance(config.HitActiveStart + 0.001)
check(npcHits == 1 and protection.IsProtected(attacker), "successful NPC hit does not forfeit")
dependency.CustomerService = oldCustomer
overlaps = { root }
publishStage(victim, "Complete")
check(not combat.DamagePlayer(attacker, attacker, attacker.Character, 10), "self damage rejected")
local takeDamage = victimH.TakeDamage
victimH.TakeDamage = function() end
check(not combat.DamagePlayer(attacker, victim, victim.Character, 10), "ineffective damage returns false")
check(protection.IsProtected(attacker), "ineffective damage does not forfeit")
victimH.TakeDamage = takeDamage
advance(config.SwingCooldown)
check(combat.SwingBat(attacker), "attack completed tutorial victim")
advance(config.HitActiveStart + 0.001)
check(movement.IsStunned(victim) and not protection.IsProtected(attacker), "successful bat effect forfeits immediately")
check(
    victimH.Health < 100 and inventory.GetCarryCount(victim) == 0 and physical[victim.Character],
    "eligible bat retains damage drop ragdoll"
)
heartbeat()
check(root.ImpulseCount == 1, "eligible victim retains knockback")
-- Recheck at the actual delayed application, independently of initial hit gating.
advance(config.SwingCooldown + config.Levels[1].StunDuration + config.ImmunitySeconds)
local lateVictim = fighter(-3)
local lateRoot = lateVictim.Character:FindFirstChild("HumanoidRootPart")
overlaps = { lateRoot }
setup(combat.SwingBat(attacker), "late physics swing")
advance(config.HitActiveStart + 0.001)
protection.AddPlayer(lateVictim)
heartbeat()
check(lateRoot.ImpulseCount == nil, "delayed callback rechecks protected victim before impulse")
-- Hostile transfers qualify once through Withdraw; existing Tasks hook remains once.
local steals = 0
dependency.TasksService = {
    RecordSteal = function()
        steals += 1
    end,
}
for _, kind in { "Ingredient", "Smoothie" } do
    local taker = fighter(0)
    protection.AddPlayer(taker)
    inventory.ClearHeld(victim)
    if kind == "Ingredient" then
        carry(victim, "Milk")
    else
        grant(victim, "protection-smoothie")
    end
    setup(press(victim, "STORE", 3), "seed transfer")
    local backpack = taker:FindFirstChildOfClass("Backpack")
    backpack.Parent = nil
    check(not inventory.Steal(taker, victim, 3) and protection.IsProtected(taker), "failed equip does not forfeit")
    backpack.Parent = taker
    check(inventory.Steal(taker, victim, 3), "hostile transfer succeeds")
    check(not protection.IsProtected(taker), "successful transfer forfeits")
end
check(steals == 2, "Tasks and protection hooks do not duplicate transfers")
advance(loadModule("Economy").NormalStash.RaidWindowSeconds)
check(not inventory.CanWithdraw(attacker, victim, 3), "raid protection still blocks completed victim's stash")
check(not inventory.CanWithdraw(attacker, victim, 1), "slot protection still applies to completed victim")
dependency.LockBaseService = {
    IsLocked = function()
        return true
    end,
}
check(not inventory.CanWithdraw(attacker, victim, 3), "lock protection retained")
dependency.LockBaseService = nil
local pickup = fighter(0)
protection.AddPlayer(pickup)
carry(pickup, "Banana")
check(protection.IsProtected(pickup), "unclaimed world pickup remains available without forfeiture")
for _, expiry in { "Forfeit", "Timeout" } do
    local owner = fighter(-3)
    protection.AddPlayer(owner)
    protection.Forfeit(pickup)
    check(not combat.CanDamagePlayer(pickup, owner), "new owner starts protected")
    if expiry == "Forfeit" then
        protection.Forfeit(owner)
    else
        advance(480)
    end
    check(
        inventory.CanWithdraw(pickup, owner, 3) and combat.CanDamagePlayer(pickup, owner),
        "expired protection allows hostile gates"
    )
    local forceField = instance("ForceField")
    forceField.Parent = owner.Character
    check(
        not combat.DamagePlayer(pickup, owner, owner.Character, 5),
        "spawn immunity survives newbie protection expiry"
    )
end
attackerH:TakeDamage(5)
check(not protection.IsProtected(attacker), "environmental health changes do not reset forfeiture")
print("PASS: protection stash and bat integration")
