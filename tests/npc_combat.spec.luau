-- Authoritative NPC dispatch through real CombatService; spatial queries are an engine boundary.
cache.StudioServices = {
    Wrap = function(_, service)
        return service
    end,
}
local config = loadModule("BatConfig")
local attacker = instance("Player")
attacker.Parent, attacker.Name = services.Players, "Attacker"
attacker.Character = instance("Model")
attacker.Character.Parent = workspaceFake
local human = instance("Humanoid")
human.Health, human.Parent = 100, attacker.Character
local root = instance("Part")
root.Name, root.Parent = "HumanoidRootPart", attacker.Character
local backpack = instance("Backpack")
backpack.Parent = attacker
local bat = instance("Tool")
bat.Name, bat.Parent = "Bat", storage
for _, name in { "Handle", "Hitbox" } do
    local part = instance("Part")
    part.Name, part.Parent = name, bat
end
local target = instance("Model")
target.Name, target.Parent = "JackedNoob", workspaceFake
local targetRoot = instance("Part")
targetRoot.Name, targetRoot.Position, targetRoot.Parent = "HumanoidRootPart", vec(0, 0, -2), target
local targetHead = instance("Part")
targetHead.Name, targetHead.Parent = "Head", target
services.Players.GetPlayerFromCharacter = function(_, model)
    return if model == attacker.Character then attacker else nil
end
local timers = {}
env.task.delay = function(seconds, callback)
    table.insert(timers, { At = now + seconds, Run = callback })
end
local function advance(seconds)
    now += seconds
    local pending = timers
    timers = {}
    for _, timer in pending do
        if timer.At <= now then
            timer.Run()
        else
            table.insert(timers, timer)
        end
    end
end
local overlaps = { targetRoot, targetHead, targetRoot }
workspaceFake.GetPartBoundsInBox = function()
    return overlaps
end
local eligible, hits = true, 0
local received
local combat = loadModule("CombatService")
combat.Init({
    TycoonService = {
        GetUpgrade = function()
            return 2
        end,
        GetSessionId = function()
            return "Plot"
        end,
        GetRequestContext = function()
            return {}
        end,
        ValidateActor = function()
            return true
        end,
    },
    MovementService = {
        CanPerformGameplayAction = function()
            return true
        end,
    },
    CustomerService = {
        CanHitCustomer = function()
            return false
        end,
    },
    JackedNoobService = {
        CanHit = function(actor, model)
            return actor == attacker and model == target and eligible
        end,
        Hit = function(actor, model, context)
            setup(actor == attacker and model == target, "dispatch registered Noob")
            hits += 1
            received = context
            return true
        end,
    },
})
combat.RefreshPlayer(attacker)
local issued = backpack:FindFirstChild("Bat")
setup(issued ~= nil, "server issued bat")
issued.Parent = attacker.Character
check(hits == 0, "mere bat proximity cannot dispatch a reaction")
for _, rejection in { "authority", "distance", "behind", "wall", "none" } do
    advance(config.SwingCooldown)
    eligible = rejection ~= "authority"
    targetRoot.Position = if rejection == "distance"
        then vec(0, 0, -100)
        elseif rejection == "behind" then vec(0, 0, 2)
        else vec(0, 0, -2)
    workspaceFake.Raycast = function()
        return if rejection == "wall" then { Instance = instance("Part") } else nil
    end
    setup(combat.SwingBat(attacker), "start NPC swing")
    check(not combat.SwingBat(attacker), "bat cooldown rejects repeated intent")
    advance(config.HitActiveStart + 0.000001)
    check(hits == (if rejection == "none" then 1 else 0), rejection .. " enforces authoritative NPC geometry")
end
advance(config.HitSampleInterval)
advance(config.HitSampleInterval)
check(hits == 1, "duplicate NPC parts and later samples register once per swing")
check(
    received.Duration == config.Levels[1].StunDuration and received.Direction.Z == -1,
    "Noob receives server duration and knockback"
)
