local logic = loadModule("JackedNoobLogic")
local config = loadModule("JackedNoob")
local deadlines = {}
local a, b = instance("Player"), instance("Player")
local grants = { [a] = 0, [b] = 0 }
local space = true
local grantSucceeds = true
local function talk(player, now)
    return logic.TryReward(deadlines, player, now, function()
        return space
    end, function()
        if not grantSucceeds then
            return false
        end
        grants[player] += 1
        return true
    end)
end

check(config.ProteinIngredientId == "Protein" and config.ProteinCooldownSeconds == 90, "authored reward and cooldown")
check(
    talk(a, 100) == "lil bro, you look like you need this." and grants[a] == 1 and deadlines[a] == 190,
    "eligible grant"
)
check(
    talk(a, 101) == "Greedy.. Come back later.." and grants[a] == 1 and deadlines[a] == 190,
    "cooldown does not extend"
)
check(talk(b, 101) == "lil bro, you look like you need this." and grants[b] == 1, "players are independent")
check(talk(a, 190) == "lil bro, you look like you need this." and grants[a] == 2, "expiry is inclusive")

space = false
check(talk(a, 280) == "Your hands are full, buddy." and deadlines[a] == 280, "full carry does not consume cooldown")
space = true
grantSucceeds = false
check(
    talk(a, 280) == "Can't grab it right now, buddy." and deadlines[a] == 280,
    "failed commit does not consume cooldown"
)
grantSucceeds = true
check(talk(a, 280) == "lil bro, you look like you need this." and deadlines[a] == 370, "retry commits one reward")

local rng = {
    NextNumber = function(_, low, high)
        return high
    end,
}
local size = vec(20, 1, 14)
local edge = logic.LocalTarget(size, config.RoamEdgeMargin, rng)
check(edge.X == 7.5 and edge.Z == 4.5, "local roam target respects inset")
local returned = logic.ReturnTarget(vec(50, 0, -30), size, config.RoamEdgeMargin)
check(returned.X == 7.5 and returned.Z == -4.5, "outside rig walks toward bounded local point")

-- Exercise the real server prompt handler independently of reward logic.
env.Enum.KeyCode = { E = "E" }
env.Random = {
    new = function()
        return rng
    end,
}
services.Players.PlayerRemoving = signal()
workspaceFake.DescendantAdded = signal()
local rig = instance("Model")
rig:SetAttribute("NPCId", config.NPCId)
local human = instance("Humanoid")
human.Health, human.Died, human.Parent = 100, signal(), rig
local root = instance("Part")
root.Name, root.Parent = "HumanoidRootPart", rig
local head = instance("Part")
head.Name, head.Parent = "Head", rig
local zone = instance("Part")
workspaceFake.FindFirstChild = function(_, name)
    return if name == "NoobRoam" then zone else nil
end
workspaceFake.GetDescendants = function()
    return { rig }
end
local replies = {}
local originalInstance = env.Instance.new
env.Instance.new = function(class)
    local object = originalInstance(class)
    if class == "RemoteEvent" then
        object.FireClient = function(_, player, _, line)
            table.insert(replies, { Player = player, Line = line })
        end
    end
    return object
end
local reactionCount, clearCount = 0, 0
cache.JackedNoobHitReaction = {
    Play = function(target)
        setup(target == head or target:IsDescendantOf(workspaceFake), "reaction uses live NPC head")
        reactionCount += 1
    end,
    Clear = function()
        clearCount += 1
    end,
}
env.Enum.HumanoidRigType = { R6 = "R6", R15 = "R15" }
rig.Parent, human.RigType = workspaceFake, env.Enum.HumanoidRigType.R6
local originalClone = rig.Clone
local function cloneRig(source)
    local copy = originalClone(source)
    local h = copy:FindFirstChildOfClass("Humanoid")
    h.Health, h.Died = 100, signal()
    copy.Clone = cloneRig
    return copy
end
rig.Clone = cloneRig
local hitTimers = {}
env.task.delay = function(seconds, callback)
    table.insert(hitTimers, { At = now + seconds, Run = callback })
end
local serviceGrants = 0
local full = false
local fail = false
local reenter
local ragdolled = {}
local pendingPhysics = {}
services.RunService.Heartbeat.Once = function(_, callback)
    table.insert(pendingPhysics, callback)
end
local noob = loadModule("JackedNoobService")
noob.Init({
    RagdollService = {
        PrepareCharacter = function()
            return true
        end,
        SetRagdolled = function(model, enabled)
            ragdolled[model] = enabled
            return true
        end,
        IsRagdolled = function(model)
            return ragdolled[model] == true
        end,
    },
    TycoonService = {
        GetSessionId = function(player)
            return if player == a or player == b then "Plot" else nil
        end,
    },
    InventoryService = {
        GetCarryCount = function()
            return if full then 3 else 0
        end,
        GetCarryCapacity = function()
            return 3
        end,
        GrantIngredient = function()
            if reenter then
                reenter()
            end
            if fail then
                error("grant unavailable")
            end
            serviceGrants += 1
            return true
        end,
    },
})
local prompt = head:FindFirstChild("JackedNoobTalk")
a.Parent, b.Parent = services.Players, services.Players
a.Near, b.Near = false, true
now = 500
prompt.Triggered:Fire(a)
check(#replies == 0, "out-of-range Talk is rejected")
a.Near = true
reenter = function()
    prompt.Triggered:Fire(a)
end
prompt.Triggered:Fire(a)
reenter = nil
check(#replies == 1 and serviceGrants == 1, "accepted Talk blocks duplicate events during reward processing")
for _, elapsed in { 0, 0.1, 0.999 } do
    now = 500 + elapsed
    prompt.Triggered:Fire(a)
end
check(#replies == 1, "rapid repeated Talk events cannot restart dialogue within one second")
prompt.Triggered:Fire(b)
check(#replies == 2 and replies[2].Player == b, "Talk debounce is independent per player")
now = 501
prompt.Triggered:Fire(a)
check(
    #replies == 3 and replies[3].Line == "Greedy.. Come back later.." and serviceGrants == 2,
    "Talk resumes at one second while the ninety-second reward cooldown remains active"
)
prompt.Triggered:Fire(a)
check(#replies == 3, "reward-cooldown dialogue is also debounced")
now = 590
full = true
prompt.Triggered:Fire(a)
prompt.Triggered:Fire(a)
check(#replies == 4 and replies[4].Line == "Your hands are full, buddy.", "full-hands conversation is debounced")
now = 591
full, fail = false, true
prompt.Triggered:Fire(a)
prompt.Triggered:Fire(a)
check(#replies == 5 and replies[5].Line == "Can't grab it right now, buddy.", "failed reward conversation is debounced")
now = 592
fail = false
prompt.Triggered:Fire(a)
check(
    #replies == 6 and replies[6].Line == "lil bro, you look like you need this.",
    "debounce does not consume or extend reward eligibility"
)
services.Players.PlayerRemoving:Fire(a)
prompt.Triggered:Fire(a)
check(
    #replies == 7 and replies[7].Line == "lil bro, you look like you need this.",
    "player departure clears personal interaction and reward cooldowns"
)

local hitContext = { Direction = vec(0, 0, -1), Duration = 1.5 }
check(noob.CanHit(a, rig), "live registered Noob can be hit from a plot")
check(noob.Hit(a, rig, hitContext) and reactionCount == 1, "validated Noob hit dispatches one reaction")
check(not noob.Hit(b, rig, hitContext) and reactionCount == 1, "other player respects shared Noob hit immunity")
now += hitContext.Duration + loadModule("BatConfig").ImmunitySeconds
check(noob.Hit(b, rig, hitContext) and reactionCount == 2, "hit after immunity refreshes reaction")
local impostor = cloneRig(rig)
impostor.Parent = workspaceFake
check(not noob.CanHit(a, impostor), "copied NPC attribute does not register a Noob")
now += hitContext.Duration + loadModule("BatConfig").ImmunitySeconds
local forceField = instance("ForceField")
forceField.Parent = rig
check(not noob.Hit(a, rig, hitContext), "protected Noob cannot react")
forceField:Destroy()
root.Anchored = true
check(not noob.CanHit(a, rig), "anchored Noob is ineligible")
root.Anchored = false
human.Health = 0
human.Died:Fire()
check(not noob.Hit(a, rig, hitContext) and clearCount >= 2, "death rejects hits and clears reaction")
now += config.RespawnSeconds
for _, timer in hitTimers do
    if timer.At <= now then
        timer.Run()
    end
end
local replacement
for _, object in allInstances do
    if
        object.ClassName == "Model"
        and object ~= rig
        and object ~= impostor
        and object.Parent == workspaceFake
        and object:GetAttribute("NPCId") == config.NPCId
    then
        replacement = object
    end
end
setup(replacement ~= nil, "Noob respawned")
local replacementHumanoid = replacement:FindFirstChildOfClass("Humanoid")
local replacementRoot = replacement:FindFirstChild("HumanoidRootPart")
replacementHumanoid.RigType = env.Enum.HumanoidRigType.R15
replacementRoot.AssemblyMass = 12
replacementRoot.ApplyImpulse = function(self, impulse)
    self.Impulse = impulse
end
check(noob.Hit(a, replacement, hitContext), "respawn resets hit eligibility")
for _, callback in pendingPhysics do
    callback()
end
check(ragdolled[replacement] and replacementRoot.Impulse ~= nil, "supported Noob rig uses normal ragdoll knockback")
now += hitContext.Duration
hitTimers[#hitTimers].Run()
check(not ragdolled[replacement] and not noob.CanHit(b, replacement), "Noob ragdoll recovers while immunity remains")
replacement.Parent = nil
replacement.AncestryChanged:Fire()
check(not noob.CanHit(a, replacement), "removed Noob rejects hits")
