-- Player-facing contracts above the existing session/progression foundation.
local t = dependency.TycoonService
local started, ended = 0, 0
local owner, peer, visitor = player(), player(), player()
local plot, second = t.GetPlot(owner), t.GetPlot(peer)
t.RemovePlayer(owner)
t.RemovePlayer(peer)
t.RemovePlayer(visitor)
services.CollectionService:AddTag(plot, "PlayerPlot")
services.CollectionService:AddTag(second, "PlayerPlot")
for _, p in { owner, peer, visitor } do
    p.Parent = workspaceFake
end
t.Init({
    SessionStarted = function(p)
        started += 1
        blend.Reset(p)
    end,
    MemberChanged = function(p)
        blend.BindPlayer(p)
    end,
    MemberRemoved = function(p)
        blend.RemovePlayer(p)
    end,
    SessionEnded = function(id)
        ended += 1
        blend.CleanupSession(id)
    end,
})
local function claimContext(target)
    return { ClaimRevision = target:GetAttribute("PlotClaimRevision") or 0 }
end
local function context()
    return t.GetRequestContext(owner)
end
local unassigned = instance("Player")
unassigned.UserId, unassigned.Name = 999, "NewPlayer"
check(t.GetPlot(unassigned) == nil and t.GetSession(unassigned) == nil, "new arrival has no session")
check(not t.ValidateActor(unassigned, context()), "unassigned cannot operate protected session")
local gameService = loadModule("GameService")
gameService.Init(dependency)
gameService.AddPlayer(unassigned)
check(not gameService.StartDay(unassigned) and t.GetPlot(unassigned) == nil, "legacy StartDay cannot auto assign")
local empty = claimContext(plot)
check(t.ClaimPlot(owner, plot, empty), "claim empty plot")
local id = t.GetSessionId(owner)
check(started == 1 and t.GetSession(owner).OwnerUserId == owner.UserId, "claim initializes exactly once")
check(
    not t.ClaimPlot(peer, plot, empty) and not t.ClaimPlot(owner, second, claimContext(second)),
    "racing/assigned claims fail"
)
check(t.GetSession(owner).JoinMode == "FriendsOnly", "safe friend default")
peer.IsFriendsWithAsync = function()
    return false
end
check(not t.RequestJoin(peer, plot, context()), "nonfriend rejected")
peer.IsFriendsWithAsync = function()
    error("lookup unavailable")
end
check(not t.RequestJoin(peer, plot, context()), "lookup failure is closed")
peer.IsFriendsWithAsync = function()
    return true
end
t.SetCash(owner, 3000)
check(t.RequestJoin(peer, plot, context()), "friend joins")
check(
    t.GetSessionId(peer) == id and t.GetCash(peer) == 3000 and started == 1,
    "join preserves progression without startup"
)
check(
    not t.RequestJoin(visitor, plot, context()) and not t.RequestJoin(peer, plot, context()),
    "capacity and duplicate joins rejected"
)
check(
    plot:GetAttribute("PlotOwnerName") == owner.Name
        and plot:GetAttribute("TeammateUserId") == peer.UserId
        and plot:GetAttribute("PlotOccupancy") == 2
        and plot:GetAttribute("PlotCapacity") == 2,
    "identity snapshot"
)
check(
    not t.SetJoinMode(peer, "Open", t.GetRequestContext(peer)) and not t.SetJoinMode(visitor, "Open", context()),
    "owner only policy"
)
check(not t.Kick(peer, owner, t.GetRequestContext(peer)) and not t.Kick(visitor, peer, context()), "owner only kick")
local stale = context()
check(t.SetJoinMode(owner, "Closed", context()), "owner closes joins")
check(not t.Kick(owner, peer, stale) and not t.SetJoinMode(owner, "Open", stale), "old management revision rejected")
local peerContext = t.GetRequestContext(peer)
check(t.LeaveTeam(peer, peerContext) and t.GetPlot(peer) == nil, "leave becomes unassigned")
check(
    not t.ValidateActor(peer, peerContext) and t.GetSessionId(owner) == id and t.GetCash(owner) == 3000,
    "leave revokes access preserves shared state"
)
check(not t.RequestJoin(peer, plot, context()), "closed rejects")
check(t.SetJoinMode(owner, "Open", context()), "open joins")
check(t.RequestJoin(peer, plot, context()), "open allows actor")
check(
    t.Kick(owner, peer, context()) and t.GetPlot(peer) == nil and t.GetCash(owner) == 3000,
    "kick retains session economy"
)
check(t.ClaimPlot(peer, second, claimContext(second)), "departed player can claim elsewhere")
check(not t.RequestJoin(peer, plot, context()), "assigned player cannot join")
t.RemovePlayer(peer)
-- Yield the friendship lookup, then change the exact management context.
t.SetJoinMode(owner, "FriendsOnly", context())
peer.IsFriendsWithAsync = function()
    coroutine.yield()
    return true
end
local joined
local pending = coroutine.create(function()
    joined = t.RequestJoin(peer, plot, context())
end)
check(coroutine.resume(pending), "friend lookup yields")
t.SetJoinMode(owner, "Closed", context())
check(coroutine.resume(pending) and joined == false, "yield revalidates policy revision")
t.SetJoinMode(owner, "FriendsOnly", context())
pending = coroutine.create(function()
    joined = t.RequestJoin(peer, plot, context())
end)
coroutine.resume(pending)
visitor.IsFriendsWithAsync = function()
    return true
end
check(t.RequestJoin(visitor, plot, context()), "competing join wins slot")
check(coroutine.resume(pending) and joined == false, "yield revalidates capacity")
local beforePromotion = context()
t.RemovePlayer(owner)
check(
    t.GetSessionId(visitor) == id
        and t.GetCash(visitor) == 3000
        and plot:GetAttribute("OwnerUserId") == visitor.UserId
        and plot:GetAttribute("PlotOwnerName") == visitor.Name,
    "promotion preserves session and updates identity"
)
check(not t.SetJoinMode(owner, "Open", beforePromotion), "old owner management invalid")
local promotionContext = t.GetRequestContext(visitor)
t.RemovePlayer(visitor)
check(
    not t.ValidateActor(visitor, promotionContext) and plot:GetAttribute("PlotOccupancy") == 0,
    "final departure releases identity"
)
check(not t.ClaimPlot(owner, plot, empty), "old empty claim revision cannot claim replacement occupancy")
check(t.ClaimPlot(owner, plot, claimContext(plot)) and t.GetSessionId(owner) ~= id, "reuse creates fresh session")
-- Owner departs during friendship lookup: never join a replacement lifetime.
pending = coroutine.create(function()
    joined = t.RequestJoin(peer, plot, context())
end)
coroutine.resume(pending)
t.RemovePlayer(owner)
t.ClaimPlot(visitor, plot, claimContext(plot))
check(coroutine.resume(pending) and joined == false, "yield revalidates owner/session lifetime")
check(ended == 3, "one cleanup for each ended session")

-- Exercise the actual network dispatch and physical boundary.
local newInstance = env.Instance.new
env.Instance.new = function(class)
    local object = newInstance(class)
    if class == "RemoteEvent" then
        object.OnServerEvent = signal()
        object.FireClient = function() end
    end
    return object
end
env.typeof = function(value)
    return if type(value) == "table" and value.IsA then "Instance" else type(value)
end
local gameplay = loadModule("GameplayService")
gameplay.Init(dependency)
local remote = shared.Events:FindFirstChild("GameplayRequest")
local marker = part("PlotIdentityOrigin", plot)
local function request(p, action, target, value, captured)
    now += 0.2
    remote.OnServerEvent:Fire(p, action, target, value, captured)
end
request(visitor, "SetJoinMode", plot, "Open", t.GetRequestContext(visitor))
check(t.GetSession(visitor).JoinMode == "Open", "network owner management")
peer.Character:FindFirstChild("HumanoidRootPart").Position = vec(100, 0, 0)
request(peer, "JoinTeam", plot, nil, t.GetRequestContext(visitor))
check(t.GetPlot(peer) == nil, "remote join enforces physical proximity")
peer.Character:FindFirstChild("HumanoidRootPart").Position = vec(0, 0, 0)
request(peer, "JoinTeam", plot, nil, nil)
check(t.GetPlot(peer) == nil, "remote join requires submitted context")
request(peer, "JoinTeam", plot, nil, t.GetRequestContext(visitor))
check(t.GetPlot(peer) == plot, "remote join routes through policy")
request(peer, "KickTeammate", plot, visitor.UserId, t.GetRequestContext(peer))
check(t.GetPlot(visitor) == plot, "remote teammate cannot kick owner")
local oldAccess = t.GetRequestContext(peer)
request(visitor, "KickTeammate", plot, peer.UserId, t.GetRequestContext(visitor))
check(t.GetPlot(peer) == nil and not t.ValidateActor(peer, oldAccess), "remote kick revokes interaction access")
request(peer, "ClaimPlot", second, nil, claimContext(second))
check(t.GetPlot(peer) == nil, "missing marker fails safely")
part("PlotIdentityOrigin", second)
request(peer, "ClaimPlot", second, nil, claimContext(second))
check(t.GetPlot(peer) == second, "remote physical claim succeeds")
