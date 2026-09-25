local t = dependency.TycoonService
local viewer, owner = player(), player()
local plot, occupied = t.GetPlot(viewer), t.GetPlot(owner)
t.RemovePlayer(viewer)
services.CollectionService:AddTag(plot, "PlayerPlot")
part("PlotIdentityOrigin", plot)
part("PlotIdentityOrigin", occupied)
services.Players.LocalPlayer = viewer
local playerGui = instance("PlayerGui")
playerGui.Name, playerGui.Parent = "PlayerGui", viewer
viewer.WaitForChild = viewer.FindFirstChild
shared.Events.WaitForChild = shared.Events.FindFirstChild
local remote = instance("RemoteEvent")
remote.Name, remote.Parent, remote.OnClientEvent = "GameplayRequest", shared.Events, signal()
local requests = {}
remote.FireServer = function(_, ...)
    table.insert(requests, { ... })
end
local thumbnails = 0
services.Players.GetUserThumbnailAsync = function(_, id)
    thumbnails += 1
    return "portrait:" .. id
end
viewer.IsFriendsWithAsync = function()
    return true
end
env.Enum.ThumbnailType, env.Enum.ThumbnailSize = { HeadShot = 1 }, { Size150x150 = 1 }
env.UDim = {
    new = function(a, b)
        return { Scale = a, Offset = b }
    end,
}
env.UDim2.new = function(a, b, c, d)
    return { X = { Scale = a, Offset = b }, Y = { Scale = c, Offset = d } }
end
local original = env.Instance.new
env.Instance.new = function(class, parentObject)
    local object = original(class)
    object.Parent = parentObject
    object.ClearAllChildren = function(self)
        for _, child in self:GetChildren() do
            child:Destroy()
        end
    end
    return object
end
services.RunService.Heartbeat = signal()
local controller = loadModule("PlotIdentityController")
controller.Init()
local function tick()
    services.RunService.Heartbeat:Fire(0.3)
    local work = table.clone(deferred)
    table.clear(deferred)
    for _, callback in work do
        callback()
    end
end
local function findText(text)
    for _, object in playerGui:GetDescendants() do
        if object.Text == text then
            local current, visible = object, true
            while current and current ~= playerGui do
                if current.Visible == false then
                    visible = false
                end
                current = current.Parent
            end
            if visible then
                return object
            end
        end
    end
    return nil
end
tick()
tick()
check(findText("AVAILABLE PLOT") and findText("CLAIM PLOT"), "empty plot exposes nearby claim")
check(findText("JOIN TEAM") ~= nil, "friend visitor sees join")
findText("CLAIM PLOT").Activated:Fire()
check(
    requests[1][1] == "ClaimPlot" and requests[1][2] == plot and requests[1][4].ClaimRevision ~= nil,
    "claim submits plot and captured context"
)
local snapshot = t.GetRequestContext(owner)
t.JoinSession(viewer, owner, snapshot)
tick()
check(findText("LEAVE TEAM") and not findText("CLAIM PLOT"), "teammate sees leave, no new claim")
findText("LEAVE TEAM").Activated:Fire()
check(
    requests[2][1] == "LeaveTeam" and requests[2][4].PlotSessionId == t.GetSessionId(viewer),
    "leave submits expected session"
)
t.RemovePlayer(owner)
tick()
check(findText("MANAGE PLOT") and not findText("LEAVE TEAM"), "promotion changes management action")
findText("MANAGE PLOT").Activated:Fire()
check(findText("Empty Slot") and findText("Open"), "owner management shows slot and policy")
findText("Open").Activated:Fire()
check(requests[3][1] == "SetJoinMode" and requests[3][3] == "Open", "management submits policy")
local fetched = thumbnails
tick()
tick()
check(thumbnails == fetched, "portrait cache reused across refreshes")
viewer.Character:FindFirstChild("HumanoidRootPart").Position = vec(1000, 0, 0)
tick()
check(
    not findText("MANAGE PLOT") or findText("MANAGE PLOT").ClassName == "TextLabel",
    "world action hidden at distance"
)
t.RemovePlayer(viewer)
tick()
check(
    findText("UNASSIGNED - Walk to a plot to claim or join") and not findText("Empty Slot"),
    "departure closes management and returns unassigned"
)
