-- Extend the shared boundary only here; rotation is explicit, not the fixture's no-op Angles.
local originalFrame = frame
frame = function(...)
    local cf = originalFrame(...)
    getmetatable(cf).__add = function(a, b)
        local result = frame(a.Position + b)
        result.RightVector, result.UpVector, result.LookVector = a.RightVector, a.UpVector, a.LookVector
        return result
    end
    return cf
end
local function cameraFrame(position, yaw)
    local cf = frame(position)
    cf.RightVector = vec(math.cos(yaw or 0), 0, -math.sin(yaw or 0))
    cf.LookVector = vec(-math.sin(yaw or 0), 0, -math.cos(yaw or 0))
    function cf:PointToObjectSpace(point)
        local offset = point - self.Position
        return vec(offset:Dot(self.RightVector), offset.Y, -offset:Dot(self.LookVector))
    end
    return cf
end
local function attributes(object)
    local signals = {}
    function object:GetAttributeChangedSignal(key)
        signals[key] = signals[key] or signal()
        return signals[key]
    end
    function object:SetAttribute(key, value)
        self.Attributes[key] = value
        self:GetAttributeChangedSignal(key):Fire()
    end
    return object
end
local player = attributes(instance("Player"))
services.Players.LocalPlayer = player
local changedCamera = signal()
function workspaceFake:GetPropertyChangedSignal()
    return changedCamera
end
local added, removed = signal(), signal()
function services.CollectionService:GetInstanceAddedSignal()
    return added
end
function services.CollectionService:GetInstanceRemovedSignal()
    return removed
end
local callbacks = {}
function services.RunService:BindToRenderStep(name, priority, callback)
    callbacks[name] = { Priority = priority, Callback = callback }
end
function services.RunService:UnbindFromRenderStep(name)
    callbacks[name] = nil
end
env.Enum.CameraType = { Custom = "Custom", Scriptable = "Scriptable" }
env.Enum.RenderPriority = { Camera = { Value = 200 } }
local moduleScript = instance("ModuleScript")
local chunk = assert(loadstring(sources.TurbineCameraController))
setfenv(chunk, setmetatable({ script = moduleScript }, { __index = env }))
local controller = chunk()
local function newCamera()
    local camera = instance("Camera")
    camera.Parent = workspaceFake
    camera.CameraType = "Custom"
    camera.CFrame = cameraFrame(vec(0, 6, 12))
    camera.Focus = cameraFrame(vec(0, 3, 0))
    return camera
end
local function newCharacter()
    local character = instance("Model")
    character.Parent = workspaceFake
    local root = instance("Part")
    root.Name, root.Parent = "HumanoidRootPart", character
    local human = instance("Humanoid")
    human.Parent, human.Health = character, 100
    player.Character = character
    return character, root, human
end
local function newPlot(session, position)
    local plot = attributes(instance("Model"))
    plot.Name, plot.Parent = "PlayerPlot", workspaceFake
    plot:SetAttribute("PlotSessionId", session)
    services.CollectionService:AddTag(plot, "PlayerPlot")
    local blender = instance("Model")
    blender.Name, blender.Parent = "Blender", plot
    local zone = instance("Part")
    zone.Name, zone.Parent = "TurbineCameraZone", blender
    zone.CFrame, zone.Size = cameraFrame(position, math.pi / 2), vec(4, 6, 10)
    local target = instance("Part")
    target.Name, target.Parent = "TurbineCamera", blender
    target.CFrame = cameraFrame(position + vec(12, 8, 0))
    added:Fire(plot)
    return plot, zone, target
end
local function near(a, b)
    return (a.Position - b.Position).Magnitude < 0.00001
end
local function step(dt, normalUpdate)
    local ordered = {}
    for _, callback in callbacks do
        table.insert(ordered, callback)
    end
    table.insert(ordered, { Priority = 200, Callback = normalUpdate or function() end })
    table.sort(ordered, function(a, b)
        return a.Priority < b.Priority
    end)
    for _, item in ordered do
        item.Callback(dt)
    end
end
local character, root, human = newCharacter()
local camera = newCamera()
workspaceFake.CurrentCamera = camera
local plot, zone, target = newPlot("mine", vec(20, 0, 0))
local otherPlot, otherZone, otherTarget = newPlot("other", vec(50, 0, 0))
player:SetAttribute("PlotSessionId", "mine")
controller.Init()
controller.Init()

-- Axis bounds in a translated, rotated zone, including its inclusive boundary.
for _, localPoint in { vec(0, 0, 0), vec(2, 3, 5), vec(-2, -3, -5) } do
    root.Position = (zone.CFrame * frame(localPoint)).Position
    step(0.3)
    check(camera.CameraType == "Scriptable" and near(camera.CFrame, target.CFrame), "inside local bounds activates")
    controller.Destroy()
    controller.Init()
end
for _, localPoint in
    {
        vec(2.01, 0, 0),
        vec(-2.01, 0, 0),
        vec(0, 3.01, 0),
        vec(0, -3.01, 0),
        vec(0, 0, 5.01),
        vec(0, 0, -5.01),
    }
do
    root.Position = (zone.CFrame * frame(localPoint)).Position
    local before = camera.CFrame
    step(0.3)
    check(camera.CameraType == "Custom" and camera.CFrame == before, "outside each local face leaves camera untouched")
end
root.Position = otherZone.CFrame.Position
step(0.3)
check(camera.CameraType == "Custom", "foreign plot cannot activate")
root.Position = zone.CFrame.Position
local start = camera.CFrame
step(0)
check(camera.CameraType == "Scriptable" and near(camera.CFrame, start), "enter starts without snapping")
step(0.15)
check(near(camera.CFrame, start:Lerp(target.CFrame, 0.5)), "enter has a smooth midpoint")
step(0.15)
target.CFrame = cameraFrame(vec(35, 7, 2))
step(0.1)
check(near(camera.CFrame, target.CFrame), "active camera holds authored position and follows target edits")
root.Position = vec(30, 0, 0)
local fixed = camera.CFrame
local normal = cameraFrame(vec(33, 6, 12))
local function defaultCamera()
    if camera.CameraType == "Custom" then
        camera.CFrame = normal
        camera.Focus = cameraFrame(root.Position)
    end
end
step(0, defaultCamera)
check(
    camera.CameraType == "Custom" and camera.CameraSubject == human and near(camera.CFrame, fixed),
    "exit restores controls without snapping"
)
step(0.15, defaultCamera)
check(near(camera.CFrame, fixed:Lerp(normal, 0.5)), "exit blends toward the live default camera")
step(0.15, function()
    check(near(camera.CFrame, normal), "default camera receives its unblended prior frame")
    defaultCamera()
end)
check(near(camera.CFrame, normal), "exit finishes on default view")
camera.CFrame = cameraFrame(vec(80, 5, 1))
local inactive = camera.CFrame
step(0.1)
check(camera.CFrame == inactive, "inactive controller never overwrites normal view")

root.Position = zone.CFrame.Position
step(0.15)
root.Position = vec(30, 0, 0)
step(0.1, defaultCamera)
local returning = camera.CFrame
root.Position = zone.CFrame.Position
step(0)
check(
    near(camera.CFrame, returning) and camera.CameraType == "Scriptable",
    "rapid reentry starts from displayed exit frame"
)
step(0.3)
target.Parent = nil
step(0.1)
check(camera.CameraType == "Custom" and camera.CameraSubject == human, "missing target restores camera")
target.Parent = zone.Parent
step(0.3)
local replacement = instance("Part")
replacement.Name, replacement.Parent = "TurbineCamera", target.Parent
replacement.CFrame = cameraFrame(vec(37, 8, 3))
target:Destroy()
target = replacement
step(0.1)
check(camera.CameraType == "Custom", "replaced marker releases the old view")
step(0.3)
check(near(camera.CFrame, target.CFrame), "new marker is resolved without a workspace scan")
zone.Parent = nil
step(0.1)
check(camera.CameraType == "Custom", "missing zone restores camera")
zone.Parent = target.Parent
step(0.3)
root:Destroy()
step(0.1)
check(camera.CameraType == "Custom", "missing root restores camera")
root = instance("Part")
root.Name, root.Parent, root.Position = "HumanoidRootPart", character, zone.CFrame.Position
step(0.3)
check(camera.CameraType == "Scriptable", "replacement root is discovered")
human.Health = 0
step(0.1)
check(camera.CameraType == "Custom", "death restores camera")
human.Health = 100
step(0.3)
player.CharacterRemoving:Fire(character)
check(camera.CameraType == "Custom", "character removal immediately releases camera")
step(0.3)
check(camera.CameraType == "Custom", "retiring character cannot reactivate")
character, root, human = newCharacter()
root.Position = zone.CFrame.Position
step(0.3)
controller.Destroy()
check(
    camera.CameraType == "Custom" and camera.CameraSubject == human,
    "respawn and explicit cleanup restore current humanoid"
)
controller.Init()
step(0.3)
local oldCamera = camera
camera = newCamera()
camera.CameraType = "Scriptable" -- A replacement may inherit the outgoing camera's mode.
workspaceFake.CurrentCamera = camera
changedCamera:Fire()
check(
    oldCamera.CameraType == "Custom" and camera.CameraType == "Custom" and camera.CameraSubject == human,
    "camera replacement releases both old and inherited modes"
)
step(0.3)
check(near(camera.CFrame, target.CFrame), "replacement camera can activate")
camera:Destroy()
step(0.1)
check(camera.CameraType == "Custom", "destroyed CurrentCamera releases ownership even before property changes")
camera = newCamera()
workspaceFake.CurrentCamera = camera
changedCamera:Fire()
step(0.3)
workspaceFake.CurrentCamera = nil
changedCamera:Fire()
step(0.1)
check(camera.CameraType == "Custom", "temporary absence of CurrentCamera is safe")
workspaceFake.CurrentCamera = camera
changedCamera:Fire()
step(0.3)
player:SetAttribute("PlotSessionId", nil)
check(camera.CameraType == "Custom", "session reset releases immediately")
step(0.3)
check(camera.CameraType == "Custom", "no membership cannot activate")
player:SetAttribute("PlotSessionId", "other")
step(0.3)
check(camera.CameraType == "Custom", "old plot ignored after reassignment")
root.Position = otherZone.CFrame.Position
step(0.3)
check(near(camera.CFrame, otherTarget.CFrame), "reassignment resolves new plot camera")
services.CollectionService:RemoveTag(otherPlot, "PlayerPlot")
removed:Fire(otherPlot)
check(camera.CameraType == "Custom", "untagging assigned plot releases immediately")
services.CollectionService:AddTag(otherPlot, "PlayerPlot")
added:Fire(otherPlot)
step(0.3)
otherPlot:SetAttribute("PlotSessionId", "reset")
check(camera.CameraType == "Custom", "plot session changes release camera")
player:SetAttribute("PlotSessionId", "reset")
step(0.3)
otherPlot.Parent = nil
otherPlot.AncestryChanged:Fire()
check(camera.CameraType == "Custom", "streamed out plot releases camera")
otherPlot.Parent = workspaceFake
otherPlot.AncestryChanged:Fire()
step(0.3)
moduleScript.Destroying:Fire()
check(camera.CameraType == "Custom", "module teardown restores camera")
local finalFrame = camera.CFrame
step(0.3)
check(camera.CFrame == finalFrame, "destroyed controller no longer writes camera")
print(string.format("PASS: %d turbine camera presentation assertions", count))
