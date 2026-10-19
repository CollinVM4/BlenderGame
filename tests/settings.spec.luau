local timers, warnings, modules = {}, {}, {}
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
                    Parent = { UI = { SettingsGui = "SettingsGui" } },
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
        nodes[node[1]] = instance(node[3], node[4], nodes[node[2]])
    end
    return nodes[1]
end
local root = import()
local gui = load("SettingsGui")
local view = assert(gui.Resolve(playerGui))
check(view.Modes.Open.Name == "All" and view.Modes.FriendsOnly.Name == "Friends", "inspected export mode paths")
check(view.MusicOn.Name == "MusicOn" and view.MusicOff.Name == "MusicOff", "export has separate on/off buttons")
check(not view.Modes.Closed and not view.Track and #view.Issues > 0, "old export reports missing Closed and slider")
local plotFrame = view.Modes.Open.Parent
local rename = plotFrame:FindFirstChild("Rename")
local closed = instance("TextButton", "Closed", plotFrame)
local track = instance("Frame", "VolumeTrack", view.MusicOn.Parent)
track:SetAttribute("BlenderUI", "Music:VolumeTrack")
track.AbsolutePosition, track.AbsoluteSize = { X = 100 }, { X = 200 }
local thumb = instance("Frame", "Thumb", track)
thumb.Position = { Y = { Scale = 0.5, Offset = 0 } }
thumb:SetAttribute("BlenderUI", "Music:VolumeThumb")
view.Status.Text = "PLOT"
view.Status.Text = "PLOT"
load("SettingsController").Init()
load("SettingsController").Init()
view = assert(gui.Resolve(playerGui))
view.Panel.Visible = true
view.Panel:GetPropertyChangedSignal("Visible"):Fire()
check(thumb.Position.X.Scale == 0.6, "open reflects saved volume")
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
check(sent[#sent][3] == "Open", "All sends Open")
local before = #sent
rename.Activated:Fire()
check(#sent == before, "Rename remains unwired")
plot:SetAttribute("OwnerUserId", 202)
view.Modes.Open.Activated:Fire()
check(#sent == before, "teammates cannot send owner settings")
plot:SetAttribute("OwnerUserId", 101)
remote.OnClientEvent:Fire("PlotRequestResult", { success = false })
check(string.find(view.Status.Text, "unavailable") ~= nil, "rejection surfaces feedback")
for _, fn in delays do
    fn()
end
check(view.Status.Text == "PLOT", "failure window restores authored title")
local touch = { UserInputType = "Touch", Position = { X = 200 } }
track.InputBegan:Fire(touch)
check(music.GetVolume() == 0.5, "touch begins volume drag")
touch.Position.X = 400
input.InputChanged:Fire(touch)
check(music.GetVolume() == 1, "touch drag clamps volume")
local decoration = instance("Frame", "DecorativeFX", view.Panel)
playerGui.DescendantAdded:Fire(decoration)
flush()
playerGui.DescendantRemoving:Fire(decoration)
flush()
touch.Position.X = 250
input.InputChanged:Fire(touch)
check(music.GetVolume() == 0.75, "decorative FX churn preserves active drag")
input.InputEnded:Fire(touch)
touch.Position.X = 100
input.InputChanged:Fire(touch)
check(music.GetVolume() == 0.75, "ended touch no longer drags")
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
