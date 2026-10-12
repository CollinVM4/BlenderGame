-- Controlled lifecycle boundary; real UnstuckService and assigned-spawn resolver.
local event = { OnServerEvent = signal(), Replies = {} }
function event:FireClient(p, result)
    self.Replies[p] = result
end
shared.Events.UnstuckEvents = "UnstuckEvents"
cache.UnstuckEvents = function()
    return event
end
local changed = signal()
local recoveries, destination = {}, env.CFrame.new(10, 12, 10)
local spawnUsable = true
cache.UnstuckPlacement = {
    IsUsable = function()
        return spawnUsable
    end,
    Find = function()
        return destination
    end,
}
services.Players.PlayerRemoving = signal()
local ownership = {}
services.Players.GetPlayerFromCharacter = function(_, c)
    return ownership[c]
end
local recovered = false
local locked = {}
local native = {
    Changed = changed,
    IsRagdolled = function(c)
        return c.Active == true
    end,
    RecoverCharacter = function(c)
        if c.RejectRecovery then
            return false
        end
        c.Active = false
        recoveries[c] = (recoveries[c] or 0) + 1
        recovered = true
        return true
    end,
}
local movement = {
    IsMovementLocked = function(p)
        return locked[p] == true
    end,
    RefreshPlayer = function(p)
        local h = p.Character:FindFirstChildOfClass("Humanoid")
        h.JumpPower = 50
    end,
}
local sprint = {
    ApplySpeed = function(p)
        p.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = 16
    end,
}
local service = loadModule("UnstuckService")
local assignments, contexts, owners = {}, {}, {}
local authority = {
    GetPlot = function(p)
        return assignments[p]
    end,
    GetOwner = function(plot)
        return owners[plot]
    end,
    GetRequestContext = function(p)
        return contexts[p]
    end,
    ValidateActor = function(p, context)
        return contexts[p] == context and assignments[p] ~= nil
    end,
}
local spawn = loadModule("InitialSpawnService")
spawn.Init({ TycoonService = authority })
local fallNotified = {}
service.Init({
    RagdollService = native,
    MovementService = movement,
    SprintService = sprint,
    TycoonService = authority,
    InitialSpawnService = spawn,
    FallDamageService = {
        NotifyRecoveryTeleport = function(p, character)
            fallNotified[p] = character
        end,
    },
})
local loop = coroutine.create(table.remove(deferred))
env.task.wait = function()
    coroutine.yield()
end
setup(coroutine.resume(loop), "start sparse watcher")
local function tick(seconds)
    now += seconds
    local ok, failure = coroutine.resume(loop)
    setup(ok, "sample watcher: " .. tostring(failure))
end
local function subject(x)
    local p, h = player()
    p.Parent = services.Players
    local c = p.Character
    c.Parent = workspaceFake
    ownership[c] = p
    h.State = "Running"
    h.PlatformStand, h.Sit = false, false
    local root = c:FindFirstChild("HumanoidRootPart") or instance("Part")
    root.Name, root.Parent = "HumanoidRootPart", c
    root.Position, root.CFrame = vec(x, 2, 10), env.CFrame.new(x, 2, 10)
    root.Anchored = false
    root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = vec(0, 0, 0), vec(0, 0, 0)
    root.Overlaps = { instance("Part") }
    function c:PivotTo(cf)
        self.Teleported = cf
    end
    return p, h, c, root
end
