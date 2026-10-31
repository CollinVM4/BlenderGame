local timers, warnings, modules = {}, {}, {}
local editorPlots, closedPanels = {}, 0
modules.PanelManager = {
    CloseAll = function()
        closedPanels += 1
    end,
}
modules.StandIdentityController = {
    OpenNameEditor = function(plot)
        check(closedPanels == #editorPlots + 1, "Settings closes before editor opens")
        table.insert(editorPlots, plot)
    end,
}
local playerGui = instance("PlayerGui", "PlayerGui")
local player = instance("Player", "LocalPlayer")
player.UserId = 101
table.insert(player.children, playerGui)
local workspace = instance("Workspace", "Workspace")
local folder = instance("Folder", "Plots", workspace)
local plot = instance("Model", "Plot", folder)
plot:SetAttribute("OwnerUserId", 101)
plot:SetAttribute("JoinMode", "Open")
plot:SetAttribute("PlotSessionId", "session")
plot:SetAttribute("PlotMembershipRevision", 7)
local sent = {}
local remote = instance("RemoteEvent", "GameplayRequest")
remote.OnClientEvent = signal()
function remote:FireServer(...)
    table.insert(sent, { ... })
end
local events = instance("Folder", "Events")
table.insert(events.children, remote)
local shared = instance("Folder", "Shared")
shared.Constants = { MusicPresentation = "MusicPresentation" }
table.insert(shared.children, events)
local storage = instance("ReplicatedStorage", "ReplicatedStorage")
storage.Shared = shared
table.insert(storage.children, shared)
local tagged = {}
local collection = { added = signal(), removed = signal() }
function collection:GetTagged()
    return table.clone(tagged)
end
function collection:HasTag(target)
    return table.find(tagged, target) ~= nil
end
function collection:GetInstanceAddedSignal()
    return self.added
end
function collection:GetInstanceRemovedSignal()
    return self.removed
end
local input = { InputChanged = signal(), InputEnded = signal() }
local sounds = instance("SoundService", "SoundService")
local createdSounds = {}
local services = {
    Players = { LocalPlayer = player },
    ReplicatedStorage = storage,
    Workspace = workspace,
    CollectionService = collection,
    UserInputService = input,
    SoundService = sounds,
    RunService = {
        IsStudio = function()
            return true
        end,
    },
}
local function flush()
    while #timers > 0 do
        table.remove(timers, 1)()
    end
end
local delays = {}
local function load(name)
    if modules[name] then
        return modules[name]
    end
    local fn = assert(loadstring(sources[name], name))
    setfenv(
        fn,
        setmetatable({
            game = {
                GetService = function(_, name)
                    return assert(services[name], name)
                end,
            },
            script = {
                Parent = {
                    UIRegistry = "UIRegistry",
                    MusicController = "MusicController",
                    StandIdentityController = "StandIdentityController",
                    Parent = { UI = { SettingsGui = "SettingsGui", PanelManager = "PanelManager" } },
                },
            },
            require = load,
            task = {
                spawn = function(fn)
                    fn()
                end,
                defer = function(fn)
                    table.insert(timers, fn)
                end,
                delay = function(_, fn)
                    table.insert(delays, fn)
                end,
            },
            warn = function(message)
                table.insert(warnings, message)
            end,
            Color3 = {
                fromRGB = function(r, g, b)
                    return tostring(r) .. ":" .. tostring(g) .. ":" .. tostring(b)
                end,
            },
            UDim2 = {
                new = function(x, ox, y, oy)
                    return { X = { Scale = x, Offset = ox }, Y = { Scale = y, Offset = oy } }
                end,
            },
            Enum = {
                UserInputType = { Touch = "Touch", MouseButton1 = "MouseButton1", MouseMovement = "MouseMovement" },
            },
            Instance = {
                new = function(class)
                    local result = instance(class, class)
                    if class == "Sound" then
                        table.insert(createdSounds, result)
                    end
                    return result
                end,
            },
        }, { __index = getfenv() })
    )
    modules[name] = fn()
    return modules[name]
end

local music = load("MusicController")
player:SetAttribute("MusicEnabled", false)
player:SetAttribute("MusicVolume", 0.25)
music.Init()
music.Init()
check(not music.IsEnabled() and music.GetVolume() == 0.25, "read session preferences")
check(#createdSounds == 0 and #warnings == 1, "empty playlist creates no Sound and logs once")
music.SetVolume(2)
check(music.GetVolume() == 1 and player:GetAttribute("MusicVolume") == 1, "upper volume clamp persists")
music.SetVolume(-2)
check(music.GetVolume() == 0, "lower volume clamp")
music.SetVolume(0 / 0)
check(music.GetVolume() == 0, "NaN cannot corrupt playback")
music.SetEnabled(true)
check(music.IsEnabled() and player:GetAttribute("MusicEnabled"), "enable persists with empty playlist")

-- A fresh module simulates a session with configured tracks.
modules.MusicController = nil
load("MusicPresentation").TrackIds = { "rbxassetid://1", "rbxassetid://2" }
music = load("MusicController")
music.Init()
local sound = createdSounds[1]
check(sound.Playing and sound.Looped and sound.SoundId == "rbxassetid://1", "configured playlist starts")
music.SetVolume(0.6)
check(sound.Volume == 0.6, "volume applies live")
music.SetEnabled(false)
check(not sound.Playing, "disable pauses")
music.SetEnabled(true)
check(sound.Playing and #createdSounds == 1, "enable resumes same sound")
sound.DidLoop:Fire()
check(sound.SoundId == "rbxassetid://2", "loop boundary advances sequential playlist")
sound.Ended:Fire()
check(sound.SoundId == "rbxassetid://1", "Ended wraps playlist")

local function import()
    local nodes = { [0] = playerGui }
    for _, node in exportNodes do
        local object = instance(node[3], node[4], nodes[node[2]])
        nodes[node[1]] = object
        local function dimension(values)
            return { X = { Scale = values[1], Offset = values[2] }, Y = { Scale = values[3], Offset = values[4] } }
        end
        if #node[5] > 0 then
            object.Position = dimension(node[5])
        end
        if #node[6] > 0 then
            object.Size = dimension(node[6])
        end
        if #node[7] > 0 then
            object.AnchorPoint = { X = node[7][1], Y = node[7][2] }
        end
    end
    return nodes[1]
end
local root = import()
local gui = load("SettingsGui")
local view = assert(gui.Resolve(playerGui))
check(
    view.Modes.Open.Name == "Open" and view.Modes.FriendsOnly.Name == "Friends" and view.Modes.Closed.Name == "Closed",
    "verified export sanitizes all three mode names"
)
check(view.Rename.Name == "Rename" and view.Kick.Name == "Kick", "verified export rename and kick names")
check(
    view.Track.Name == "Slider" and view.Thumb.Name == "Knob" and view.Fill.Name == "ProgressBar",
    "verified slider hierarchy"
)
check(#view.Issues == 0, "complete export has no PLOT/MUSIC issues and no declined labels")
local plotFrame = view.Modes.Open.Parent
local rename, kick, closed = view.Rename, view.Kick, view.Modes.Closed
local track, thumb, fill = view.Track, view.Thumb, view.Fill
local outer, inner = view.Outer, view.Track:FindFirstChild("InnerSlider")
local outerPosition, outerSize, innerPosition, innerSize = outer.Position, outer.Size, inner.Position, inner.Size
local thumbY, fillY, fillHeight, fillAnchor = thumb.Position.Y, fill.Position.Y, fill.Size.Y, fill.AnchorPoint
track.AbsolutePosition, track.AbsoluteSize = { X = 100 }, { X = 200 }
outer.AbsolutePosition, outer.AbsoluteSize = { X = 100 }, { X = 200 }
thumb.AbsoluteSize = { X = 20 }
plot:SetAttribute("StandName", "Fresh Stand")
plot:SetAttribute("TeammateUserId", 303)
view.Status.Text = "PLOT"
view.Status.Text = "PLOT"
load("SettingsController").Init()
load("SettingsController").Init()
view = assert(gui.Resolve(playerGui))
view.Panel.Visible = true
view.Panel:GetPropertyChangedSignal("Visible"):Fire()
check(thumb.Position.X.Scale == 0.6 and fill.Size.X.Scale == 0.6, "open reflects saved volume in knob and fill")
check(
    fill.Position.X.Scale + (1 - fill.AnchorPoint.X) * fill.Size.X.Scale == thumb.Position.X.Scale,
    "centered fill anchor ends at knob"
)
view.Modes.FriendsOnly.Activated:Fire()
local request = sent[#sent]
check(
    request[1] == "SetJoinMode" and request[2] == plot and request[3] == "FriendsOnly",
    "friends sends owner plot and canonical action"
)
check(
    request[4].PlotSessionId == "session" and request[4].MembershipRevision == 7 and request[4].ClaimRevision == 0,
    "capture exact revision fields with claim fallback"
)
local allBackground = view.Modes.Open:FindFirstChild("BuyBackground")
local friendsBackground = view.Modes.FriendsOnly:FindFirstChild("BuyBackground")
check(
    allBackground.BackgroundColor3 == "45:159:123" and friendsBackground.BackgroundColor3 == "43:56:70",
    "request does not change replicated highlight"
)
plot:SetAttribute("JoinMode", "FriendsOnly")
check(friendsBackground.BackgroundColor3 == "45:159:123", "replicated mode changes selection live")
closed.Activated:Fire()
check(sent[#sent][3] == "Closed", "Closed mode remains reachable with updated export")
view.Modes.Open.Activated:Fire()
check(sent[#sent][3] == "Open", "Open sends Open")
local before = #sent
rename.Activated:Fire()
rename.Activated:Fire()
check(
    #sent == before and #editorPlots == 2 and editorPlots[2] == plot,
    "repeated rename opens existing editor each time"
)
check(kick.Active, "owner can kick the current teammate")
kick.Activated:Fire()
check(
    sent[#sent][1] == "KickTeammate" and sent[#sent][3] == 303 and sent[#sent][4].MembershipRevision == 7,
    "kick submits teammate and captured context"
)
before = #sent
plot:SetAttribute("TeammateUserId", 101)
player:SetAttribute("PlotSessionId", "session")
plot:SetAttribute("OwnerUserId", 202)
view.Modes.Open.Activated:Fire()
kick.Activated:Fire()
rename.Activated:Fire()
check(#sent == before and #editorPlots == 2, "teammate controls cannot send or open editor")
check(not view.Modes.Open.Active and not rename.Visible and not kick.Visible, "teammate plot is read-only")
check(friendsBackground.BackgroundColor3 == "45:159:123", "session teammate sees mode")
local teammateTouch = { UserInputType = "Touch", Position = { X = 200 } }
track.InputBegan:Fire(teammateTouch)
input.InputEnded:Fire(teammateTouch)
check(
    music.GetVolume() == 0.5 and fill.Size.X.Scale == 0.5 and #sent == before,
    "teammate slider changes personal music without a plot action"
)
player:SetAttribute("PlotSessionId", nil)
view.Modes.Open.Activated:Fire()
check(#sent == before and not view.Modes.Open.Active, "teammate fallback is inert")
plot:SetAttribute("TeammateUserId", nil)
view.Modes.Open.Activated:Fire()
check(#sent == before and friendsBackground.BackgroundColor3 == "43:56:70", "no plot is unselected and inert")
plot:SetAttribute("OwnerUserId", 101)
remote.OnClientEvent:Fire("PlotRequestResult", { success = false })
check(string.find(view.Status.Text, "unavailable") ~= nil, "rejection surfaces feedback")
for _, fn in delays do
    fn()
end
check(view.Status.Text == "PLOT", "failure window restores authored title")
local function checkEdges(range)
    local trackLeft, trackWidth = track.AbsolutePosition.X, track.AbsoluteSize.X
    local knobCenter = trackLeft + thumb.Position.X.Scale * trackWidth + thumb.Position.X.Offset
    local knobLeft = knobCenter - thumb.AbsoluteSize.X / 2
    local knobRight = knobCenter + thumb.AbsoluteSize.X / 2
    local fillWidth = fill.Size.X.Scale * trackWidth + fill.Size.X.Offset
    local fillLeft = trackLeft
        + fill.Position.X.Scale * trackWidth
        + fill.Position.X.Offset
        - fill.AnchorPoint.X * fillWidth
    local fillRight = fillLeft + fillWidth
    check(knobLeft >= range.AbsolutePosition.X, "knob left stays inside range")
    check(knobRight <= range.AbsolutePosition.X + range.AbsoluteSize.X, "knob right stays inside range")
    check(math.abs(fillLeft - range.AbsolutePosition.X) < 0.000001, "fill left stays at range left")
    check(math.abs(fillRight - knobCenter) < 0.000001, "fill right meets knob center in pixels")
    return knobLeft, knobRight
end
local function display(value, message)
    check(music.GetVolume() == value and fill.Size.X.Scale == value and thumb.Position.X.Scale == value, message)
    check(fill.Position.X.Scale - fill.AnchorPoint.X * fill.Size.X.Scale == 0, "fill stays left-aligned")
    checkEdges(track)
end
for _, value in { 0, 0.25, 0.5, 0.75, 1 } do
    music.SetVolume(value)
    display(value, "volume refresh keeps scale and pixel geometry aligned")
    local inset = (0.5 - value) * 20
    check(thumb.Position.X.Offset == inset and fill.Size.X.Offset == inset, "knob and fill use half-width inset")
end
-- AbsoluteSize can become available after the first render; layout refreshes it.
thumb.AbsoluteSize = { X = 0 }
music.SetVolume(0)
local authoredInset = (thumb.Size.X.Scale * track.AbsoluteSize.X + thumb.Size.X.Offset) / 2
check(thumb.Position.X.Offset == authoredInset, "pre-layout knob uses authored width")
thumb.AbsoluteSize = { X = 20 }
thumb:GetPropertyChangedSignal("AbsoluteSize"):Fire()
check(thumb.Position.X.Offset == 10 and fill.Size.X.Offset == 10, "knob layout refresh uses resolved width")
local touch = { UserInputType = "Touch", Position = { X = 100 } }
thumb.InputBegan:Fire(touch)
display(0, "touch at left seeks zero")
touch.Position.X = 200
input.InputChanged:Fire(touch)
display(0.5, "touch center seeks half")
local knobDuringDrag, fillDuringDrag = thumb.Position, fill.Size
player:SetAttribute("MusicVolume", 0.25)
check(
    thumb.Position == knobDuringDrag and fill.Size == fillDuringDrag,
    "external refresh leaves active drag display alone"
)
touch.Position.X = 300
input.InputChanged:Fire(touch)
display(1, "touch right seeks full")
touch.Position.X = 400
input.InputChanged:Fire(touch)
display(1, "drag clamps above track")
local _, rightEdge = checkEdges(track)
check(rightEdge == 300, "drag beyond right pins knob edge to track right")
touch.Position.X = 0
input.InputChanged:Fire(touch)
display(0, "drag clamps below track")
local leftEdge = checkEdges(track)
check(leftEdge == 100, "drag beyond left pins knob edge to track left")
local decoration = instance("Frame", "DecorativeFX", view.Panel)
playerGui.DescendantAdded:Fire(decoration)
flush()
playerGui.DescendantRemoving:Fire(decoration)
flush()
touch.Position.X = 250
input.InputChanged:Fire(touch)
display(0.75, "decorative FX churn preserves active drag")
input.InputEnded:Fire(touch)
touch.Position.X = 100
input.InputChanged:Fire(touch)
display(0.75, "ended touch no longer drags")
local mouse = { UserInputType = "MouseButton1", Position = { X = 200 } }
outer.InputBegan:Fire(mouse)
display(0.5, "mouse seeks on decorative track")
input.InputChanged:Fire({ UserInputType = "MouseMovement", Position = { X = 300 } })
display(1, "mouse movement updates live")
view.Panel.Visible = false
check(not view.Dragging and not track.Active, "closing ends drag and restores authored Active")
input.InputChanged:Fire({ UserInputType = "MouseMovement", Position = { X = 100 } })
check(music.GetVolume() == 1, "closed panel ignores mouse movement")
music.SetVolume(0.4)
view.Panel.Visible = true
display(0.4, "reopening shows current volume")
track.AbsoluteSize = { X = 0 }
local fallbackTouch = { UserInputType = "Touch", Position = { X = 200 } }
track.InputBegan:Fire(fallbackTouch)
check(
    music.GetVolume() == 0.5 and thumb.Position.X.Offset == 100 and fill.Size.X.Offset == 100,
    "OuterSlider bounds work before group layout"
)
for _, value in { 0, 0.5, 1 } do
    fallbackTouch.Position.X = 100 + value * 200
    input.InputChanged:Fire(fallbackTouch)
    local expectedOffset = value * 200 + (0.5 - value) * 20
    check(
        music.GetVolume() == value
            and thumb.Position.X.Scale == value
            and fill.Size.X.Scale == value
            and thumb.Position.X.Offset == expectedOffset
            and fill.Size.X.Offset == expectedOffset,
        "fallback range offsets include knob inset"
    )
    checkEdges(outer)
end
input.InputEnded:Fire(fallbackTouch)
track.AbsoluteSize = { X = 200 }
music.SetVolume(0.75)
display(0.75, "external volume refresh updates both parts")
check(
    thumb.Position.Y.Scale == thumbY.Scale
        and thumb.Position.Y.Offset == thumbY.Offset
        and fill.Position.Y.Scale == fillY.Scale
        and fill.Size.Y.Scale == fillHeight.Scale
        and fill.AnchorPoint == fillAnchor,
    "slider preserves authored Y geometry and anchor"
)
check(
    outer.Position == outerPosition
        and outer.Size == outerSize
        and inner.Position == innerPosition
        and inner.Size == innerSize,
    "decorative sliders never move or resize"
)
-- Synthetic missing-part fixtures are separate from the shipped artwork.
local function remove(object)
    for i, child in object.Parent.children do
        if child == object then
            table.remove(object.Parent.children, i)
            break
        end
    end
    object.Parent = nil
end
for _, part in { fill, thumb, track } do
    local parent = part.Parent
    playerGui.DescendantRemoving:Fire(part)
    remove(part)
    flush()
    local incomplete = assert(gui.Resolve(playerGui))
    local beforeVolume = music.GetVolume()
    track.InputBegan:Fire({ UserInputType = "Touch", Position = { X = 100 } })
    check(music.GetVolume() == beforeVolume and #incomplete.Issues > 0, "missing slider part makes input inert")
    incomplete.MusicOff.Activated:Fire()
    check(not music.IsEnabled(), "music off works without complete slider")
    incomplete.MusicOn.Activated:Fire()
    check(music.IsEnabled(), "music on works without complete slider")
    part.Parent = parent
    table.insert(parent.children, part)
    playerGui.DescendantAdded:Fire(part)
    flush()
end
view = assert(gui.Resolve(playerGui))
-- Sanitized names and original Figma button names are both accepted.
for _, control in { view.Modes.Open, view.Modes.FriendsOnly, view.Modes.Closed, rename, kick } do
    local name = control.Name
    control.Name = name .. "_button_smooth"
    check(#gui.Resolve(playerGui).Issues == 0, "original Figma button fallback resolves")
    control.Name = name
end
local duplicate = instance("TextButton", "All", plotFrame)
check(gui.Resolve(playerGui).Modes.Open == nil, "ambiguous buttons fail closed")
table.remove(plotFrame.children, #plotFrame.children)
-- Reimport replaces all controls, then old activation is disconnected.
playerGui.DescendantRemoving:Fire(root)
root.Parent = nil
table.clear(playerGui.children)
import()
playerGui.DescendantAdded:Fire(root)
flush()
before = #sent
view.Modes.Open.Activated:Fire()
check(#sent == before, "removed export no longer sends")
gui.Resolve(playerGui).Modes.Open.Activated:Fire()
check(#sent == before + 1, "replacement export rebinds")
print("PASS settings/music contracts: " .. count)
