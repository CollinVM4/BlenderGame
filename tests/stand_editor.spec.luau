-- Real editor/controller, fake engine tween completion and remote replies.
local keyboardChanged = {}
services.UserInputService = {
    InputBegan = signal(),
    GamepadEnabled = true,
    OnScreenKeyboardVisible = false,
    OnScreenKeyboardSize = env.Vector2.new(390, 300),
    OnScreenKeyboardPosition = env.Vector2.new(0, 544),
    GetPropertyChangedSignal = function(_, key)
        keyboardChanged[key] = keyboardChanged[key] or signal()
        return keyboardChanged[key]
    end,
}
services.GuiService = {}
env.Enum.TextXAlignment = { Right = "Right" }
env.Enum.KeyCode = { Escape = "Escape", ButtonB = "ButtonB" }
parent.Parent.UI = { StandNameEditor = "StandNameEditor" }
cache.TurbineCameraController = { ReleaseCamera = function() end }
env.Enum.ApplyStrokeMode = { Border = "Border" }
env.Enum.CameraType = { Custom = "Custom", Scriptable = "Scriptable" }
env.Enum.EasingStyle = { Quad = "Quad" }
env.Enum.EasingDirection = { Out = "Out", InOut = "InOut" }
env.UDim = {
    new = function(a, b)
        return { Scale = a, Offset = b }
    end,
}
env.UDim2.new = function(a, b, c, d)
    return { X = { Scale = a, Offset = b }, Y = { Scale = c, Offset = d } }
end
env.UDim2.fromScale = function(a, b)
    return env.UDim2.new(a, 0, b, 0)
end
env.TweenInfo = {
    new = function(...)
        return { ... }
    end,
}
local oldFrame = frame
frame = function(...)
    local cf = oldFrame(...)
    getmetatable(cf).__add = function(a, b)
        return frame(a.Position + b)
    end
    return cf
end
local function waitingSignal()
    local result = signal()
    function result:Wait()
        local thread = coroutine.running()
        local listener
        listener = self:Connect(function(...)
            listener:Disconnect()
            local ok, err = coroutine.resume(thread, ...)
            assert(ok, err)
        end)
        return coroutine.yield()
    end
    return result
end
services.RunService.Heartbeat = waitingSignal()
env.task.spawn = function(callback)
    local ok, err = coroutine.resume(coroutine.create(callback))
    assert(ok, err)
end
local tweens = {}
services.TweenService = {
    Create = function(_, object, info, goal)
        local tween = { Completed = waitingSignal(), Goal = goal, Object = object }
        function tween:Play() end
        function tween:Cancel()
            self.Completed:Fire("Cancelled")
        end
        function tween:Finish()
            for key, value in self.Goal do
                self.Object[key] = value
            end
            self.Completed:Fire("Completed")
        end
        table.insert(tweens, tween)
        return tween
    end,
}
local original = env.Instance.new
env.Instance.new = function(class, parentObject)
    local object = original(class)
    object.Parent = parentObject
    local changed = signal()
    object.GetPropertyChangedSignal = function()
        return changed
    end
    object.FocusLost = signal()
    object.ReturnPressedFromOnScreenKeyboard = signal()
    object.CursorPosition, object.SelectionStart = -1, -1
    object.AbsoluteSize, object.AbsolutePosition = env.Vector2.new(390, 844), env.Vector2.new(0, 0)
    object.CaptureFocus = function(self)
        self.Focused = true
    end
    object.ReleaseFocus = function(self)
        self.Focused = false
    end
    return object
end
local owner = instance("Player")
owner.UserId, owner.Parent = 7, services.Players
owner.WaitForChild = owner.FindFirstChild
owner.CharacterAdded = signal()
local playerGui = instance("PlayerGui")
playerGui.Name, playerGui.Parent = "PlayerGui", owner
services.Players.LocalPlayer = owner
local function newCharacter()
    local character = instance("Model")
    character.Parent = workspaceFake
    local root = instance("Part")
    root.Name, root.Parent = "HumanoidRootPart", character
    local human = instance("Humanoid")
    human.Health, human.Parent = 100, character
    owner.Character = character
    return root, human
end
local root, human = newCharacter()
local camera = instance("Camera")
camera.Parent, camera.CameraType, camera.CameraSubject = workspaceFake, "Custom", human
camera.CFrame = frame(0, 6, 12)
workspaceFake.CurrentCamera = camera
local cameraChanged = signal()
workspaceFake.GetPropertyChangedSignal = function()
    return cameraChanged
end
local plot = instance("Model")
plot.Parent = workspaceFake
plot:SetAttribute("OwnerUserId", owner.UserId)
plot:SetAttribute("PlotSessionId", "session")
plot:SetAttribute("PlotMembershipRevision", 1)
plot:SetAttribute("StandNameRevision", 1)
plot:SetAttribute("StandName", "Collin's Stand")
owner:SetAttribute("PlotSessionId", "session")
local marker = instance("Part")
marker.Name, marker.Parent, marker.CFrame = "SignCamera", plot, frame(10, 8, 6)
shared.Events.WaitForChild = shared.Events.FindFirstChild
local remote = instance("RemoteFunction")
remote.Name, remote.Parent = "SetStandName", shared.Events
local requests = {}
local response = function()
    return true, "Filtered"
end
remote.InvokeServer = function(_, target, text, context)
    table.insert(requests, { target, text, context })
    return response()
end
local claimed = instance("RemoteEvent")
claimed.Name, claimed.Parent, claimed.OnClientEvent = "PlotClaimed", shared.Events, signal()
local controller = loadModule("StandIdentityController")
controller.Init()
local gui = playerGui:FindFirstChild("StandNameEditor")
local box = gui:FindFirstChild("StandName", true)
local function button(text)
    for _, object in gui:GetDescendants() do
        if object.Text == text then
            return object
        end
    end
end
local function open()
    controller.OpenNameEditor(plot)
    check(camera.CameraType == "Scriptable" and not gui.Enabled, "camera moves before UI appears")
    tweens[#tweens]:Finish()
    check(
        gui.Enabled and box.Focused and box.Text == plot:GetAttribute("StandName"),
        "arrival opens focused editor with authoritative value"
    )
end
open()
local counter = gui:FindFirstChild("CharacterCounter", true)
box.Text = string.rep("👩‍👩‍👧‍👦", 28)
box:GetPropertyChangedSignal("Text"):Fire()
check(
    box.Text == string.rep("👩‍👩‍👧‍👦", 27) and counter.Text == "27/27",
    "live counter truncates complete emoji graphemes"
)
box.Text = ""
box:GetPropertyChangedSignal("Text"):Fire()
check(counter.Text == "0/27", "live counter resets on deletion")
box.Text = "e\u{301}"
box:GetPropertyChangedSignal("Text"):Fire()
check(counter.Text == "1/27", "live counter treats combined accent as one character")
local area = gui:FindFirstChild("UsableArea")
local panel = gui:FindFirstChild("RenameCard", true)
local input = services.UserInputService
for _, viewport in { { 320, 568, 280 }, { 430, 932, 360 }, { 1024, 768, 300 }, { 1920, 1080, 480 } } do
    area.AbsoluteSize = env.Vector2.new(viewport[1], viewport[2])
    input.OnScreenKeyboardVisible = true
    input.OnScreenKeyboardPosition = env.Vector2.new(0, viewport[2] - viewport[3])
    input.OnScreenKeyboardSize = env.Vector2.new(viewport[1], viewport[3])
    keyboardChanged.OnScreenKeyboardVisible:Fire()
    check(
        panel.Position.Y.Offset + area.AbsolutePosition.Y < input.OnScreenKeyboardPosition.Y,
        "phone/tablet/TV panel bottom clears keyboard"
    )
    input.OnScreenKeyboardVisible = false
    keyboardChanged.OnScreenKeyboardVisible:Fire()
    check(panel.Position.Y.Scale == 1 and panel.Position.Y.Offset == -20, "keyboard closure restores desktop position")
end
gui:GetPropertyChangedSignal("Enabled"):Fire()
check(
    services.GuiService.SelectedObject == box
        and box.NextSelectionDown.Text == "SAVE"
        and box.NextSelectionDown.NextSelectionRight.Text == "SKIP"
        and box.NextSelectionUp.Text == "X",
    "controller can reach text entry and every action"
)
box.Text = "  Super Smoothies  "
button("SAVE").Activated:Fire()
check(
    #requests == 1
        and requests[1][2] == "  Super Smoothies  "
        and requests[1][3].StandNameRevision == 1
        and not gui.Enabled
        and box.Text == "Filtered",
    "successful save sends captured context then closes"
)
root.Position = vec(15, 0, 0)
tweens[#tweens]:Finish()
check(camera.CameraType == "Custom" and camera.CameraSubject == human, "save releases camera to current humanoid")
for _, action in { "SKIP", "X" } do
    open()
    button(action).Activated:Fire()
    tweens[#tweens]:Finish()
    check(camera.CameraType == "Custom" and #requests == 1, "skip/close returns without rename")
end
open()
box.Text = ""
button("SAVE").Activated:Fire()
check(gui.Enabled and #requests == 1, "blank client input retains editor")
response = function()
    return false, "Filter unavailable"
end
box.Text = "Name"
button("SAVE").Activated:Fire()
check(gui.Enabled and button("SAVE"), "filter rejection permits retry or skip")
response = function()
    coroutine.yield()
    return true
end
local pendingResponse
remote.InvokeServer = function()
    pendingResponse = coroutine.running()
    return response()
end
button("SAVE").Activated:Fire()
button("SAVING…").Activated:Fire()
controller.Close(true)
open()
coroutine.resume(pendingResponse)
check(gui.Enabled and camera.CameraType == "Scriptable", "stale save completion cannot close newer editor")
controller.OpenNameEditor(plot)
local oldTween = tweens[#tweens]
controller.OpenNameEditor(plot)
oldTween.Completed:Fire("Completed")
check(not gui.Enabled and camera.CameraType == "Scriptable", "old tween callback cannot reopen or restore camera")
tweens[#tweens]:Finish()
for _, invalidate in
    {
        function()
            human.Health = 0
        end,
        function()
            plot:SetAttribute("OwnerUserId", 88)
        end,
        function()
            plot:SetAttribute("PlotMembershipRevision", 2)
        end,
        function()
            marker.Parent = nil
        end,
        function()
            plot.Parent = nil
        end,
    }
do
    invalidate()
    services.RunService.Heartbeat:Fire(0.1)
    check(camera.CameraType == "Custom" and not gui.Enabled, "lifecycle invalidation immediately releases camera")
    human.Health, plot.Parent, marker.Parent = 100, workspaceFake, plot
    plot:SetAttribute("OwnerUserId", owner.UserId)
    plot:SetAttribute("PlotMembershipRevision", 1)
    open()
end
owner.CharacterRemoving:Fire(owner.Character)
check(camera.CameraType == "Custom" and not gui.Enabled, "character removal cancels")
root, human = newCharacter()
owner.CharacterAdded:Fire(owner.Character)
open()
controller.Close()
local replacementRoot, replacementHuman = newCharacter()
owner.CharacterAdded:Fire(owner.Character)
check(
    camera.CameraType == "Custom" and camera.CameraSubject == replacementHuman,
    "respawn during exit restores current subject"
)

open()
services.UserInputService.InputBegan:Fire({ KeyCode = "Escape" })
tweens[#tweens]:Finish()
check(camera.CameraType == "Custom" and not gui.Enabled, "Escape cancels editor")
open()
local savedCamera = camera
workspaceFake.CurrentCamera = instance("Camera")
workspaceFake.CurrentCamera.CameraType = "Custom"
cameraChanged:Fire()
check(savedCamera.CameraType == "Custom" and not gui.Enabled, "camera replacement cancels prior camera ownership")
workspaceFake.CurrentCamera = savedCamera
open()
owner.Parent = nil
owner.AncestryChanged:Fire()
check(camera.CameraType == "Custom" and not gui.Enabled, "player departure releases camera")
owner.Parent = services.Players
open()
gui.Enabled = false
gui:GetPropertyChangedSignal("Enabled"):Fire()
tweens[#tweens]:Finish()
check(camera.CameraType == "Custom", "externally closing UI returns camera")
controller.Close(true)
owner:SetAttribute("PlotSessionId", nil)
plot:SetAttribute("PlotSessionId", nil)
claimed.OnClientEvent:Fire(plot, "session", 1)
check(camera.CameraType == "Custom" and not gui.Enabled, "claim signal waits for replicated context")
owner:SetAttribute("PlotSessionId", "session")
plot:SetAttribute("PlotSessionId", "session")
services.RunService.Heartbeat:Fire(0.1)
check(camera.CameraType == "Scriptable" and not gui.Enabled, "committed claim context starts camera intro")
tweens[#tweens]:Finish()
check(gui.Enabled, "initial claim opens same reusable editor")
for _, platform in { "mobile", "console" } do
    local submissions, waiting = 0, nil
    remote.InvokeServer = function()
        submissions += 1
        waiting = coroutine.running()
        coroutine.yield()
        return true, "Safe Name"
    end
    box.Text = "raw input"
    box.ReturnPressedFromOnScreenKeyboard:Fire()
    box.FocusLost:Fire(true)
    button("SAVING…").Activated:Fire()
    check(
        submissions == 1 and gui.Enabled and plot:GetAttribute("StandName") == "Collin's Stand",
        platform .. " return/focus/save duplicate signals send one request without raw publication"
    )
    coroutine.resume(waiting)
    check(not gui.Enabled and box.Text == "Safe Name", platform .. " displays authoritative response")
    tweens[#tweens]:Finish()
    open()
end
marker:Destroy()
services.RunService.Heartbeat:Fire(0.1)
check(camera.CameraType == "Custom", "destroyed camera marker releases camera")
