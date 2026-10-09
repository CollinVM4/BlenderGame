local spawn = loadModule("InitialSpawnService")
local authority = sessionTestAuthority
spawn.Init({ TycoonService = authority })
authority.Init({ MemberChanged = spawn.ClearReservation })
local timers = {}
env.task.delay = function(_, fn)
    table.insert(timers, fn)
end
local function plot(name, order, x, withMarker)
    local result = instance("Model")
    result.Name, result.Parent = name, workspaceFake
    result:SetAttribute("SpawnOrder", order)
    services.CollectionService:AddTag(result, "PlayerPlot")
    if withMarker ~= false then
        local identity = instance("Folder")
        identity.Name, identity.Parent = "PlotIdentity", result
        local marker = instance("Attachment")
        marker.Name, marker.Parent, marker.WorldCFrame = "PlayerSpawnOrigin", identity, frame(x, 4, 0)
    end
    return result
end
local last = plot("Plot1", 3, 30)
local first = plot("Plot20", 1, 10)
local second = plot("Plot3", 2, 20)
local function join()
    local p = instance("Player")
    p.Name, p.UserId, p.Parent = "Arrival", #allInstances, workspaceFake
    p.Character = instance("Model")
    p.Character.WaitForChild = p.Character.FindFirstChild
    local root = instance("Part")
    root.Name, root.Parent = "HumanoidRootPart", p.Character
    local humanoid = instance("Humanoid")
    humanoid.Parent, humanoid.Health = p.Character, 100
    spawn.ApplyCharacter(p, p.Character)
    return p
end
local a, b = join(), join()
flush()
check(
    a.Character.Position.X == 10 and b.Character.Position.X == 20,
    "concurrent arrivals reserve different plots in authored order"
)
check(not authority.GetPlot(a) and not authority.GetOwner(first), "spawn routing does not grant ownership")
local c = join()
flush()
check(c.Character.Position.X == 30, "third arrival routes to remaining plot")
local d = join()
flush()
check(d.Character.Position.X == 0, "all reserved retains default spawn")
check(authority.ClaimPlot(d, first, { ClaimRevision = 0 }), "reservation never blocks normal claims")
spawn.RemovePlayer(b)
local e = join()
flush()
check(e.Character.Position.X == 20, "leaving releases reservation")
for _, fn in timers do
    fn()
end
local f = join()
flush()
check(f.Character.Position.X == 20, "timeout releases unclaimed reservations while claimed plots stay excluded")
a.Character = instance("Model")
a.Character.WaitForChild = a.Character.FindFirstChild
spawn.ApplyCharacter(a, a.Character)
flush()
check(a.Character.Position.X == 0, "unclaimed respawn retains the default spawn")
spawn.ClearReservation(f)
local marker = second:FindFirstChild("PlotIdentity"):FindFirstChild("PlayerSpawnOrigin")
marker:Destroy()
local g = join()
flush()
check(g.Character.Position.X == 30, "missing marker skipped safely")

check(authority.JoinSession(g, d, authority.GetRequestContext(d)), "arrival may join existing stand")
check(g:FindFirstChild("TutorialSpawnTarget").Value == nil, "joining releases arrival target")
local h = join()
flush()
check(h.Character.Position.X == 30, "join release makes target available to next arrival")
check(authority.ClaimPlot(h, last, { ClaimRevision = 0 }), "arrival may claim reserved target")
check(h:FindFirstChild("TutorialSpawnTarget").Value == nil, "claim releases arrival target")

-- Tutorial target rerouting remains separate from reservation/ownership/teleport.
local occupiedLater = plot("Plot4", 4, 40)
local replacementPlot = plot("Plot5", 5, 50)
local learner, reservedPeer = join(), join()
flush()
learner:SetAttribute("TutorialActive", true)
learner:SetAttribute("TutorialStage", "ClaimPlot")
local intruder = instance("Player")
intruder.Name, intruder.UserId, intruder.Parent = "Intruder", #allInstances, workspaceFake
setup(authority.ClaimPlot(intruder, occupiedLater, { ClaimRevision = 0 }), "another player claims intended target")
heartbeat:Fire(0.25)
check(learner:FindFirstChild("TutorialSpawnTarget").Value == nil, "replacement respects other arrival reservation")
for _, fn in timers do
    fn()
end
heartbeat:Fire(0.25)
check(
    learner:FindFirstChild("TutorialSpawnTarget").Value == replacementPlot,
    "unavailable intended plot reroutes deterministically after another reservation expires"
)
check(
    learner.Character.Position.X == 40 and not authority.GetPlot(learner),
    "hint reroute never teleports or assigns membership"
)
local arriving = join()
flush()
check(arriving.Character.Position.X == 50, "tutorial retarget does not reserve or block next arrival")

-- Every replacement character uses the current authoritative session, not the arrival hint.
local function replacement(p)
    local character = instance("Model")
    character.Parent = workspaceFake
    character.WaitForChild = character.FindFirstChild
    local root = instance("Part")
    root.Name, root.Parent = "HumanoidRootPart", character
    root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = vec(12, -80, 5), vec(1, 2, 3)
    local humanoid = instance("Humanoid")
    humanoid.Parent, humanoid.Health = character, 100
    p.Character = character
    return character, root, humanoid
end
local function respawn(p)
    local previous = p.Character:FindFirstChildOfClass("Humanoid")
    if previous then
        previous.Health = 0
    end
    local character, root = replacement(p)
    spawn.ApplyCharacter(p, character)
    flush()
    return character, root
end
for _ = 1, 3 do
    local character, root = respawn(d)
    check(
        character.Position.X == 10 and character.Position.Y == 7,
        "repeated owner deaths return above assigned marker"
    )
    check(
        root.AssemblyLinearVelocity.Magnitude == 0 and root.AssemblyAngularVelocity.Magnitude == 0,
        "respawn clears launch velocity"
    )
end
local teammate = respawn(g)
check(teammate.Position.X == 14 and teammate.Position.Y == 7, "teammate resets use team plot with horizontal clearance")
check(authority.GetPlot(g) == first, "respawn preserves team membership")
local unclaimed = respawn(a)
check(
    unclaimed.Position.X == 0 and unclaimed.Position.Y == 0,
    "unclaimed resets keep default placement despite old arrival hint"
)

local rotatedMarker = first:FindFirstChild("PlotIdentity"):FindFirstChild("PlayerSpawnOrigin")
local originalFrame = rotatedMarker.WorldCFrame
rotatedMarker.WorldCFrame = frame(100, 20, 200)
rotatedMarker.WorldCFrame.RightVector = vec(0, 0, -1)
rotatedMarker.WorldCFrame.LookVector = vec(-1, 0, 0)
local rotatedOwner = respawn(d)
local rotatedTeammate = respawn(g)
check(
    rotatedOwner.Position.X == 100 and rotatedOwner.Position.Y == 23 and rotatedOwner.Position.Z == 200,
    "owner uses current attachment world transform plus height"
)
check(
    rotatedTeammate.Position.X == 100 and rotatedTeammate.Position.Y == 23 and rotatedTeammate.Position.Z == 196,
    "teammate clearance follows authored spawn orientation"
)
check(rotatedOwner:GetPivot().LookVector.X == -1, "respawn preserves marker facing")
rotatedMarker.WorldCFrame = originalFrame

-- Suspend precisely at the root wait to exercise membership changes during loading.
local function waitForRoot(p)
    local character = replacement(p)
    character.WaitForChild = function(self, name)
        coroutine.yield()
        return self:FindFirstChild(name)
    end
    local thread
    local spawnTask = env.task.spawn
    env.task.spawn = function(fn)
        thread = coroutine.create(fn)
        setup(coroutine.resume(thread), "respawn waits for root")
    end
    spawn.ApplyCharacter(p, character)
    env.task.spawn = spawnTask
    setup(coroutine.status(thread) == "suspended", "root loading suspended")
    return character, thread
end
local pendingCharacter, pending = waitForRoot(g)
setup(authority.LeaveTeam(g, authority.GetRequestContext(g)), "teammate leaves while loading")
setup(
    authority.ClaimPlot(g, replacementPlot, { ClaimRevision = replacementPlot:GetAttribute("PlotClaimRevision") or 0 }),
    "teammate claims a new plot while loading"
)
setup(coroutine.resume(pending), "new assignment resumes")
check(
    pendingCharacter.Position.X == 50 and pendingCharacter.Position.Y == 7,
    "root wait resolves reassigned plot instead of old team"
)

pendingCharacter, pending = waitForRoot(g)
authority.RemovePlayer(g)
setup(coroutine.resume(pending), "released assignment resumes")
check(
    pendingCharacter.Position.X == 0 and pendingCharacter.Position.Y == 0,
    "release during root wait retains default spawn"
)
setup(
    authority.ClaimPlot(g, replacementPlot, { ClaimRevision = replacementPlot:GetAttribute("PlotClaimRevision") or 0 }),
    "reclaim for stale character checks"
)
pendingCharacter, pending = waitForRoot(g)
local currentCharacter = replacement(g)
setup(coroutine.resume(pending), "obsolete character resumes")
check(
    pendingCharacter.Position.X == 0 and currentCharacter.Position.X == 0,
    "obsolete respawn cannot move either character"
)
local deadCharacter, _, deadHumanoid = replacement(g)
deadHumanoid.Health = 0
spawn.ApplyCharacter(g, deadCharacter)
flush()
check(deadCharacter.Position.X == 0, "already dead character cannot be teleported")
local missingRoot = replacement(g)
missingRoot:FindFirstChild("HumanoidRootPart"):Destroy()
spawn.ApplyCharacter(g, missingRoot)
flush()
check(missingRoot.Position.X == 0, "missing root retains default placement")
local assignedMarker = replacementPlot:FindFirstChild("PlotIdentity"):FindFirstChild("PlayerSpawnOrigin")
assignedMarker:Destroy()
local noMarker = respawn(g)
check(noMarker.Position.X == 0, "assigned plot without marker never routes to an unrelated available plot")
