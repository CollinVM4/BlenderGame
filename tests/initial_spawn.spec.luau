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
check(a.Character.Position.X == 0, "death respawn never routes again")
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
