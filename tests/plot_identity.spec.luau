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
local thumbnails = 0
local ownerThumbnailReady = false
services.Players.GetUserThumbnailAsync = function(_, id)
    thumbnails += 1
    return "portrait:" .. id, id ~= owner.UserId or ownerThumbnailReady
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
local function findPortrait(image)
    for _, object in playerGui:GetDescendants() do
        if object.ClassName == "ImageLabel" and object.Image == image and object.Parent.Parent.Enabled then
            return object.Parent
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
check(findText("AVAILABLE PLOT"), "unclaimed plots keep their availability label")
local pendingFallback = findText("S")
check(
    pendingFallback and pendingFallback.Parent.Image == "" and thumbnails == 1,
    "a pending thumbnail has a legible fallback and does not refetch immediately"
)
ownerThumbnailReady = true
now += 10
tick()
tick()
local soloPortrait = findPortrait("portrait:" .. owner.UserId)
check(soloPortrait and soloPortrait.Position.X.Scale == 0.5, "a solo portrait is centered over its plot")
local publicMarker = soloPortrait.Parent
check(
    publicMarker.Size.X.Scale > 0
        and publicMarker.Size.X.Offset == 0
        and publicMarker.MaxDistance == 240
        and not findText("YOUR BASE"),
    "other bases use world-sized portraits and do not display the home caption"
)
check(
    pendingFallback.Parent.Parent == soloPortrait and pendingFallback.Visible and thumbnails == 2,
    "retry fills the existing badge while the headshot image loads"
)
pendingFallback.Parent.IsLoaded = true
tick()
check(not pendingFallback.Visible, "the loaded headshot replaces the fallback")
local snapshot = t.GetRequestContext(owner)
t.JoinSession(viewer, owner, snapshot)
tick()
tick()
local ownerPortrait = findPortrait("portrait:" .. owner.UserId)
local teammatePortrait = findPortrait("portrait:" .. viewer.UserId)
check(ownerPortrait and teammatePortrait, "both player portraits are visible after joining a team")
local marker = ownerPortrait.Parent
check(
    marker == teammatePortrait.Parent and marker.Adornee == occupied:FindFirstChild("PlotIdentityOrigin"),
    "both team portraits share their base's billboard and world origin"
)
local width = marker.Size.X.Offset
local leftSize, rightSize = ownerPortrait.Size.X.Offset / width, teammatePortrait.Size.X.Offset / width
local left, right = ownerPortrait.Position.X.Scale, teammatePortrait.Position.X.Scale
check(
    marker.Size.X.Scale == 0
        and marker.Size.Y.Scale == 0
        and ownerPortrait.Size.X.Offset >= 48
        and ownerPortrait.Size.X.Offset == ownerPortrait.Size.Y.Offset
        and teammatePortrait.Size.X.Offset == ownerPortrait.Size.X.Offset,
    "home portraits stay square and at least 48 screen pixels wide at distance"
)
check(
    left + right == 1
        and left - leftSize / 2 >= 0
        and left + leftSize / 2 < right - rightSize / 2
        and right + rightSize / 2 <= 1
        and ownerPortrait.Position.X.Offset == 0
        and teammatePortrait.Position.X.Offset == 0,
    "the two portraits fit within one centered, proportional row"
)
check(
    marker.MaxDistance >= 360 and marker.AlwaysOnTop and not marker.Active,
    "the home marker is a passive landmark with a longer draw distance"
)
local home = findText("YOUR BASE")
check(
    home and home.Parent == marker and home.TextSize >= 20 and not home.Active,
    "a legible Your Base caption sits under the home portraits"
)
check(
    ownerPortrait.BackgroundColor3 == teammatePortrait.BackgroundColor3
        and ownerPortrait.BackgroundColor3 ~= soloPortrait.BackgroundColor3,
    "both portraits on the viewer's own base share its highlight"
)
check(not findText("TEAMMATE"), "the team role caption is removed")
check(not findText("LEAVE TEAM"), "teammates have no overhead leave button at close range")
viewer.Character:FindFirstChild("HumanoidRootPart").Position = vec(100, 0, 0)
tick()
check(
    findPortrait("portrait:" .. owner.UserId) == ownerPortrait
        and findPortrait("portrait:" .. viewer.UserId) == teammatePortrait
        and ownerPortrait.Position.X.Scale == left
        and teammatePortrait.Position.X.Scale == right,
    "moving away keeps both portraits at the same offsets in their shared marker"
)
viewer.Character:FindFirstChild("HumanoidRootPart").Position = vec(0, 0, 0)
t.RemovePlayer(owner)
tick()
local promotedPortrait = findPortrait("portrait:" .. viewer.UserId)
check(
    promotedPortrait and promotedPortrait.Position.X.Scale == 0.5 and not findPortrait("portrait:" .. owner.UserId),
    "owner departure leaves one centered portrait for the promoted player"
)
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
    not findText("Claim an available PLOT!") and not findText("Empty Slot") and not findText("YOUR BASE"),
    "departure removes the home marker and returns unassigned"
)
local beforeStudio = thumbnails
occupied:SetAttribute("OwnerUserId", -1)
occupied:SetAttribute("PlotOwnerName", "Player1")
occupied:SetAttribute("TeammateUserId", -2)
occupied:SetAttribute("PlotTeammateName", "Player2")
tick()
local studioOne, studioTwo = findText("P1"), findText("P2")
check(
    studioOne and studioTwo and studioOne.Parent.BackgroundColor3 ~= studioTwo.Parent.BackgroundColor3,
    "Studio test players have distinct visible portrait badges"
)
check(thumbnails == beforeStudio, "Studio test players do not request nonexistent account headshots")
