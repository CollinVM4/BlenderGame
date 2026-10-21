local t = dependency.TycoonService
local viewer, owner = player(), player()
local plot, occupied = t.GetPlot(viewer), t.GetPlot(owner)
t.RemovePlayer(viewer)
services.CollectionService:AddTag(plot, "PlayerPlot")
part("PlotIdentityOrigin", plot)
part("PlotIdentityOrigin", occupied)
for _, target in { plot, occupied } do
    local identity = instance("Folder")
    identity.Name, identity.Parent = "PlotIdentity", target
    part("ClaimLabelOrigin", identity)
    part("TeammateLabelOrigin", identity)
end
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
env.Enum.ApplyStrokeMode = { Border = "Border" }
env.Enum.TextTruncate = { AtEnd = "AtEnd" }
env.Enum.EasingStyle = { Quad = "Quad" }
env.Enum.EasingDirection = { Out = "Out" }
env.TweenInfo = {
    new = function(...)
        return { ... }
    end,
}
services.TweenService = {
    Create = function(_, object, _info, goal)
        return {
            Play = function()
                for key, value in goal do
                    object[key] = value
                end
            end,
            Cancel = function() end,
        }
    end,
}
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
                if current.Visible == false or current.Enabled == false then
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
check(not findText("Claim an available PLOT!"), "unassigned player has no startup claim instruction")
for _, object in playerGui:GetDescendants() do
    if object.Name == "ClaimZoneLabel" or object.Name == "TeammateZoneLabel" then
        check(object.MaxDistance == 60, "pad labels use explicit landmark culling")
    end
end
check(findText("CLAIM PLOT") and findText("CLAIM PLOT").ClassName == "TextLabel", "claim pad label has no click action")
check(findText("JOIN STAND") and findText("JOIN STAND").ClassName == "TextLabel", "join pad is label only")
local snapshot = t.GetRequestContext(owner)
t.JoinSession(viewer, owner, snapshot)
tick()
check(findText("LEAVE TEAM"), "teammate sees leave, no new claim")
findText("LEAVE TEAM").Activated:Fire()
check(
    requests[1][1] == "LeaveTeam" and requests[1][4].PlotSessionId == t.GetSessionId(viewer),
    "leave submits expected session"
)
viewer.Character:FindFirstChild("HumanoidRootPart").Position = vec(1000, 0, 0)
tick()
check(not findText("LEAVE TEAM"), "teammate leave presentation remains nearby-only")
viewer.Character:FindFirstChild("HumanoidRootPart").Position = vec(0, 0, 0)
t.RemovePlayer(owner)
tick()
check(not findText("MANAGE PLOT") and not findText("LEAVE TEAM"), "owner has no billboard management action")
check(playerGui:FindFirstChild("PlotStatus"), "status-only host retained")
remote.OnClientEvent:Fire("PlotRequestResult", { success = false })
tick()
check(findText("Plot action unavailable. Try again."), "neutral failure feedback retained")
local teammate = player()
t.RemovePlayer(teammate)
t.JoinSession(teammate, viewer, t.GetRequestContext(viewer))
tick()
check(not findText("KICK TEAMMATE"), "kick lives exclusively in Settings")
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
    not findText("Claim an available PLOT!") and not findText("Empty Slot"),
    "departure closes management and returns unassigned"
)
