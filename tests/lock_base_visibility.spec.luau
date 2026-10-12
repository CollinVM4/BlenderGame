-- Two isolated client worlds run the real controller against replicated presentation.
local plot = lockObject("Model", "Plot", workspaceFake)
local button, _, visual, attachment = securityAssets(plot)
local display = loadModule("LockBasePresentation").Bind(button, attachment, visual)
display.Update(true, now + 60, now)
local serverGui = attachment:FindFirstChild("LockBaseDisplay")
local function client()
    local world = lockObject("Model", "Workspace")
    local localPlayer = lockObject("Player", "LocalPlayer")
    local character = lockObject("Model", "Character", world)
    local root = lockObject("Part", "HumanoidRootPart", character)
    localPlayer.Character = character
    local anchor = lockObject("Attachment", "LockAttachment", world)
    anchor.WorldPosition = vec(10, 0, 0)
    local gui = lockObject("BillboardGui", "LockBaseDisplay", anchor)
    gui.Adornee, gui.MaxDistance = anchor, serverGui.MaxDistance
    local label = lockObject("TextLabel", "State", gui)
    local function replicate()
        gui:SetAttribute("LockBaseOccupied", serverGui:GetAttribute("LockBaseOccupied"))
        label.Text = serverGui:FindFirstChildOfClass("TextLabel").Text
    end
    replicate()
    local thread
    local function step()
        local ok, interval = coroutine.resume(thread)
        assert(ok, interval)
        check(interval == 0.2, "visibility checks use a bounded periodic interval")
    end
    local chunk = assert(loadstring(sources.LockBaseVisibilityController))
    setfenv(
        chunk,
        setmetatable({
            workspace = world,
            game = {
                GetService = function()
                    return { LocalPlayer = localPlayer }
                end,
            },
            task = {
                spawn = function(fn)
                    thread = coroutine.create(fn)
                    step()
                end,
                wait = function(interval)
                    coroutine.yield(interval)
                end,
            },
        }, { __index = env })
    )
    local controller = chunk()
    root.Position = vec(30, 0, 0)
    controller.Init()
    return {
        World = world,
        Player = localPlayer,
        Character = character,
        Root = root,
        Anchor = anchor,
        Gui = gui,
        Label = label,
        Step = step,
        Replicate = replicate,
    }
end
local a, b = client(), client()
check(not a.Gui.Enabled and not b.Gui.Enabled and not serverGui.Enabled, "distant clients and server start hidden")
a.Root.Position = vec(16, 0, 0)
a.Step()
check(
    a.Gui.Enabled and not b.Gui.Enabled and not serverGui.Enabled,
    "one client entering six studs does not show another client's display or mutate server visibility"
)
a.Root.Position = vec(16.5, 0, 0)
b.Root.Position = vec(16.5, 0, 0)
a.Step()
b.Step()
check(a.Gui.Enabled and not b.Gui.Enabled, "six-to-seven stud margin retains each client's previous visibility")
a.Root.Position = vec(17.01, 0, 0)
a.Step()
check(not a.Gui.Enabled, "moving beyond seven studs hides the display")
display.Update(true, now + 60, now + 23)
a.Replicate()
b.Replicate()
check(not a.Gui.Enabled and a.Label.Text == "LOCKED\n0:37", "countdown replication continues while out of range")
a.Root.Position = vec(15, 0, 0)
b.Root.Position = vec(15, 0, 0)
a.Step()
b.Step()
check(
    a.Gui.Enabled and b.Gui.Enabled and a.Label.Text == "LOCKED\n0:37",
    "both nearby players see the current timer when returning"
)
a.World.CurrentCamera = { CFrame = env.CFrame.new(50, 20, 0) }
a.Step()
check(a.Gui.Enabled and a.Gui.MaxDistance >= 65, "normal third-person camera offset does not control proximity")
display.Update(false, 0, now + 23)
a.Replicate()
b.Replicate()
a.Step()
b.Step()
check(not a.Gui.Enabled and not b.Gui.Enabled, "plot release hides every client's UI")
display.Update(true, 0, now + 23)
a.Replicate()
a.Step()
check(a.Gui.Enabled and a.Label.Text == "LOCK BASE", "reclaim restores plain unlocked text in range")
a.Player.CharacterRemoving:Fire(a.Character)
a.Player.Character = nil
check(not a.Gui.Enabled, "character removal immediately hides local UI")
a.Step()
local replacement = lockObject("Model", "Replacement", a.World)
local newRoot = lockObject("Part", "HumanoidRootPart", replacement)
newRoot.Position = vec(16.5, 0, 0)
a.Player.Character = replacement
a.Step()
check(not a.Gui.Enabled, "respawn resets hysteresis and cannot inherit previous visible state")
newRoot.Position = vec(15, 0, 0)
a.Step()
check(a.Gui.Enabled, "replacement character can show UI within six studs")
a.Anchor.WorldPosition = vec(40, 0, 0)
a.Step()
check(not a.Gui.Enabled, "proximity follows live authored attachment world position")
a.Gui.Parent = nil
a.World.DescendantRemoving:Fire(a.Gui)
a.Step()
check(not a.Gui.Enabled, "streamed or removed display remains hidden after removal")
a.Anchor.WorldPosition = vec(10, 0, 0)
local lateGui = lockObject("BillboardGui", "LockBaseDisplay", a.Anchor)
lateGui.Adornee = a.Anchor
lateGui:SetAttribute("LockBaseOccupied", true)
a.World.DescendantAdded:Fire(lateGui)
a.Step()
check(lateGui.Enabled, "late replicated or restored plot display becomes visible to a nearby character")
a.World.DescendantRemoving:Fire(lateGui)
lateGui.Parent = nil
a.Step()
check(not lateGui.Enabled, "restored display also cleans up when its plot leaves the client world")
display.Destroy()
print("PASS LockBase local visibility", count, "contracts")
