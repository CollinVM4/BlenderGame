-- Independent presentation suite. Engine CFrame/Http/UI boundaries are doubles.
shared.FilmCamPath = "FilmCamPath"
shared.Constants.FilmCam = "FilmCam"
shared.Constants.FilmTakes = "FilmTakes"
env.Enum.KeyCode = { F6 = "F6", F7 = "F7", W = "W", A = "A", S = "S", D = "D", Q = "Q", E = "E" }
env.Enum.CameraType = { Custom = "Custom", Scriptable = "Scriptable" }
env.Enum.ContextActionPriority = { High = { Value = 3000 } }
env.Enum.ContextActionResult = { Pass = "Pass", Sink = "Sink" }
env.Enum.RenderPriority = { Camera = { Value = 200 } }
env.Enum.MouseBehavior = { Default = "Default", LockCurrentPosition = "Locked" }
env.Enum.UserInputType = { MouseButton1 = "Left", MouseButton2 = "Right", MouseMovement = "Move", MouseWheel = "Wheel" }
env.Vector3.zAxis = vec(0, 0, 1)
env.UDim2.new = function(xs, xo, ys, yo)
    return { X = { Scale = xs, Offset = xo }, Y = { Scale = ys, Offset = yo } }
end
env.UDim = {
    new = function(scale, offset)
        return { Scale = scale, Offset = offset }
    end,
}

local Path = loadModule("FilmCamPath")
local Config = loadModule("FilmCam")
local function close(a, b, epsilon)
    return math.abs(a - b) < (epsilon or 1e-6)
end
local function key(t, x, y, z, angle, fov)
    return {
        Time = t,
        Position = { x or 0, y or 0, z or 0 },
        Rotation = { 0, math.sin((angle or 0) / 2), 0, math.cos((angle or 0) / 2) },
        Fov = fov or 70,
    }
end
local function take(keys)
    return { Version = 1, Name = "Test", Duration = keys[#keys].Time, Keys = keys }
end
check(Path.Allowed(true, 99, {}), "Studio access")
check(Path.Allowed(false, 66554216, Config.AllowedUserIds), "Collin live access")
check(not Path.Allowed(false, 99, Config.AllowedUserIds), "ordinary live user denied")
check(not Path.Allowed(false, 0, {}), "empty allowlist fails closed")
local origin = key(0)
local function sampled(k)
    return Path.ShouldSample(origin, k, 0.05, math.rad(0.5))
end
check(not sampled(key(1, 0.049)), "subthreshold position filtered")
check(sampled(key(1, 0.051)), "position threshold")
check(not sampled(key(1, 0, 0, 0, math.rad(0.49))), "subthreshold rotation filtered")
check(sampled(key(1, 0, 0, 0, math.rad(0.51))), "rotation threshold")
check(sampled(key(1, 0, 0, 0, 0, 75)), "stationary FOV changes retained")
local opposite = key(1)
opposite.Rotation[4] = -1
check(not sampled(opposite), "quaternion sign does not create phantom movement")

local curve = take({ key(0, 0, 0), key(1, 1, 2), key(2, 2, 0), key(3, 3, 2) })
local track = Path.Compile(curve)
local x, y = Path.Evaluate(track, 1.5)
check(close(x, 1.5) and close(y, 1), "known Catmull-Rom interior midpoint")
x, y = Path.Evaluate(track, 1.25)
check(close(x, 1.25) and close(y, 1.6875), "known Catmull-Rom curved quarter point")
check(close(Path.Evaluate(track, -1), 0) and close(Path.Evaluate(track, 10), 3), "endpoint clamping")
local unequal = Path.Compile(take({ key(0, 0), key(0.1, 1), key(2, 4), key(3, 5) }))
local h = 0.00001
local left = (Path.Evaluate(unequal, 0.1) - Path.Evaluate(unequal, 0.1 - h)) / h
local right = (Path.Evaluate(unequal, 0.1 + h) - Path.Evaluate(unequal, 0.1)) / h
check(close(left, right, 0.003), "delta-filtered timestamps retain continuous position velocity")
local held = Path.Compile(take({ key(0, 0), key(1, 10), key(3, 10), key(4, 20) }))
check(close(Path.Evaluate(held, 2), 10), "explicit stationary hold has no spline overshoot")
local turn = Path.Compile(take({ key(0), key(1, 10, 0, 0, math.pi, 90) }))
local _, _, _, qx, qy, qz, qw, fov = Path.Evaluate(turn, 0.5)
check(
    close(qx, 0) and close(qz, 0) and close(qy, math.sqrt(0.5)) and close(qw, math.sqrt(0.5)),
    "slerp 180 degree turn midpoint"
)
check(close(fov, 80), "FOV lerp")
local signed = key(1, 0, 0, 0, math.rad(270))
local short = Path.Compile(take({ key(0), signed }))
_, _, _, qx, qy, qz, qw = Path.Evaluate(short, 0.5)
check(close(qy, math.sin(-math.pi / 8)) and close(qw, math.cos(math.pi / 8)), "slerp follows shortest arc")
local identity = Path.Compile(take({ key(0), opposite }))
_, _, _, qx, qy, qz, qw = Path.Evaluate(identity, 0.5)
check(close(qw, 1), "antipodal identity remains finite")
for _, duration in { 0.1, 1, 5, 20 } do
    check(
        Path.EasedTime(0, duration, true) == 0 and Path.EasedTime(duration, duration, true) == duration,
        "easing exact endpoints"
    )
    local previous = -1
    for i = 0, 100 do
        local t = Path.EasedTime(duration * i / 100, duration, true)
        assert(t >= previous and t <= duration)
        previous = t
    end
    check(close(Path.EasedTime(duration / 2, duration, true), duration / 2), "easing symmetric and monotonic")
end
check(Path.EasedTime(0.25, 5, false) == 0.25, "easing bypass")
check(Path.EasedTime(0.001, 5, true) < 0.000001, "easing starts at rest")
check(Path.Validate(curve), "valid take accepted")
for _, bad in { 0 / 0, math.huge, -1, 301 } do
    local invalid = take({ key(0), key(1) })
    invalid.Duration = bad
    check(not Path.Validate(invalid), "invalid duration rejected")
end
local invalid = take({ key(0), key(1) })
invalid.Keys[2].Rotation = { 0, 0, 0, 0 }
check(not Path.Validate(invalid), "invalid quaternion rejected")
invalid = take({ key(0), key(1) })
invalid.Keys[2].Time = 0
check(not Path.Validate(invalid), "duplicate timestamps rejected")

-- Yaw-aware CFrame boundary for actual preset geometry, including look direction.
local rawFrame = frame
frame = function(x, y, z, qx, qy, qz, qw)
    local cf = rawFrame(x, y, z)
    cf.X, cf.Y, cf.Z = cf.Position.X, cf.Position.Y, cf.Position.Z
    local yaw = if qw then 2 * math.atan2(qy, qw) else 0
    cf.RightVector = vec(math.cos(yaw), 0, -math.sin(yaw))
    cf.LookVector = vec(-math.sin(yaw), 0, -math.cos(yaw))
    function cf:ToAxisAngle()
        return vec(0, 1, 0), math.atan2(-self.LookVector.X, -self.LookVector.Z)
    end
    function cf:ToOrientation()
        local _, angle = self:ToAxisAngle()
        return 0, angle, 0
    end
    function cf:VectorToWorldSpace(v)
        return self.RightVector * v.X + self.UpVector * v.Y - self.LookVector * v.Z
    end
    getmetatable(cf).__add = function(a, b)
        local result = frame(a.Position + b)
        result.LookVector, result.RightVector, result.UpVector = a.LookVector, a.RightVector, a.UpVector
        return result
    end
    return cf
end
env.CFrame.new = frame
env.CFrame.Angles = function(_, yaw)
    return frame(0, 0, 0, 0, math.sin(yaw / 2), 0, math.cos(yaw / 2))
end
env.CFrame.fromOrientation = env.CFrame.Angles
local Takes = loadModule("FilmCamTakes")
for _, kind in { "Push-in", "Pull-out", "Orbit" } do
    local cf = frame(4, 6, 20)
    local center = vec(4, 6, 0)
    local generated = Takes.Preset(kind, cf, 70, center)
    check(Path.Validate(generated), kind .. " produces a valid take")
    check(generated.Duration == (if kind == "Orbit" then 8 else 5), kind .. " duration")
    local first, last = generated.Keys[1], generated.Keys[#generated.Keys]
    check(close(first.Position[1], 4) and close(first.Position[3], 20), kind .. " starts at framing")
    if kind == "Orbit" then
        check(close(last.Position[1], 4) and close(last.Position[3], 20), "orbit closes its circle")
        for _, k in generated.Keys do
            local position = vec(unpack(k.Position))
            assert(close((position - center).Magnitude, 20))
            local expected = (center - position).Unit
            local angle = 2 * math.atan2(k.Rotation[2], k.Rotation[4])
            assert((vec(-math.sin(angle), 0, -math.cos(angle)) - expected).Magnitude < 1e-6)
        end
        check(true, "orbit keeps radius and faces target throughout")
    else
        check(close(last.Position[3], if kind == "Push-in" then 10 else 30), kind .. " moves 10 studs")
    end
end
check(Path.Validate(Takes.Preset("Orbit", frame(), 70)), "orbit target fallback")
check(Path.Validate(Takes.Preset("Orbit", frame(), 70, vec(0, 0, 0))), "degenerate target fallback")

-- HttpService mock round-trips deep values. Native JSON escaping is a Studio test.
local wire = {}
local function copy(v)
    if type(v) ~= "table" then
        return v
    end
    local result = {}
    for k, item in v do
        result[k] = copy(item)
    end
    return result
end
services.HttpService.JSONEncode = function(_, value)
    wire = copy(value)
    return "encoded-json"
end
services.HttpService.JSONDecode = function(_, json)
    assert(json == "encoded-json", "invalid JSON")
    return copy(wire)
end
local encoded = Takes.Encode(curve)
local decoded = Takes.Decode(encoded)
check(decoded and decoded.Name == curve.Name and decoded.Keys[2].Position[2] == 2, "JSON adapter value round-trip")
local tx, ty = Path.Evaluate(Path.Compile(decoded), 1.25)
check(close(tx, x) and close(ty, y), "round-trip preserves sampled camera track")
check(Takes.Decode("broken") == nil, "malformed JSON handled")
wire = { Version = 9 }
check(Takes.Decode(encoded) == nil, "malformed decoded take handled")

-- Controller boundary: real controller + real paths/takes; minimal event-driven UI.
local player = instance("Player")
player.UserId = 99
local playerGui = instance("PlayerGui")
playerGui.DescendantAdded = signal()
function player:WaitForChild()
    return playerGui
end
services.Players.LocalPlayer = player
local changedCamera = signal()
function workspaceFake:GetPropertyChangedSignal()
    return changedCamera
end
local callbacks = {}
function services.RunService:BindToRenderStep(name, _, fn)
    callbacks[name] = fn
end
function services.RunService:UnbindFromRenderStep(name)
    callbacks[name] = nil
end
local input = {
    InputBegan = signal(),
    InputEnded = signal(),
    InputChanged = signal(),
    WindowFocusReleased = signal(),
    MouseBehavior = "Default",
    MouseIconEnabled = true,
    Down = {},
}
function input:GetFocusedTextBox()
    return self.Focused
end
function input:IsKeyDown(k)
    return self.Down[k]
end
services.UserInputService = input
local action
services.ContextActionService = {
    BindActionAtPriority = function(_, _, fn)
        action = fn
    end,
    UnbindAction = function()
        action = nil
    end,
}
local turbineState, standState = false, true -- An already-suspended owner must remain suspended.
cache.TurbineCameraController = {
    SetSuspended = function(value)
        local old = turbineState
        turbineState = value
        return old
    end,
}
cache.StandIdentityController = {
    SetSuspended = function(value)
        local old = standState
        standState = value
        return old
    end,
}
cache.FilmTakes = {}
local function control()
    local c = instance("TextButton")
    c.MouseButton1Click = signal()
    c.InputBegan = signal()
    c.Text = ""
    function c:CaptureFocus()
        input.Focused = self
    end
    return c
end
local ui
local panelCreates = 0
cache.FilmCamPanel = {
    Create = function()
        panelCreates += 1
        ui = {}
        for _, name in
            {
                "Gui",
                "Frame",
                "Name",
                "Select",
                "Hide",
                "HidePanel",
                "Record",
                "Stop",
                "Play",
                "Speed",
                "Ease",
                "Copy",
                "Push",
                "Pull",
                "Orbit",
                "Letterbox",
                "Scrub",
                "Fill",
                "Status",
                "Export",
            }
        do
            ui[name] = control()
        end
        ui.Gui.Enabled = false
        ui.Speed.Text = "1"
        ui.Bars = { control(), control() }
        ui.Scrub.AbsolutePosition = vec(0, 0, 0)
        ui.Scrub.AbsoluteSize = vec(100, 10, 0)
        return ui
    end,
}
local scriptFake = instance("ModuleScript")
scriptFake.Parent = parent
local chunk = assert(loadstring(sources.FilmCamController))
setfenv(chunk, setmetatable({ script = scriptFake }, { __index = env }))
local controller = chunk()
local cam = instance("Camera")
cam.CameraType = "Custom"
cam.CFrame, cam.Focus, cam.FieldOfView = frame(1, 2, 3), frame(1, 2, -10), 75
cam.CameraSubject = instance("Humanoid")
workspaceFake.CurrentCamera = cam
local initialFrame, initialFocus, initialSubject = cam.CFrame, cam.Focus, cam.CameraSubject
check(not controller.Play(curve, 1), "public Play is inert before authorization")
studio = false
controller.Init()
input.InputBegan:Fire({ KeyCode = "F6" }, false)
check(panelCreates == 0 and cam.CFrame == initialFrame and action == nil, "ordinary live client fully inert")
player.UserId = 66554216
controller.Init()
check(panelCreates == 1 and not ui.Gui.Enabled, "allowlisted Init creates hidden panel")
local function press(k)
    input.InputBegan:Fire({ KeyCode = k }, false)
end
local function click(name)
    ui[name].Activated:Fire()
end
local function step(dt)
    if callbacks.FilmCamRender then
        callbacks.FilmCamRender(dt)
    end
end
local function docked(text, inBar)
    local button = ui.HidePanel
    local position, anchor = button.Position, button.AnchorPoint
    check(button.Text == text, "panel toggle reads " .. text)
    if inBar then
        check(
            position.X.Scale == 0.5
                and position.Y.Scale == 0.06
                and position.X.Offset == 0
                and position.Y.Offset == 0
                and anchor.X == 0.5
                and anchor.Y == 0.5,
            "Show pill is centered inside top black bar"
        )
    else
        check(
            position.X.Scale == 1
                and position.X.Offset == -12
                and position.Y.Scale == 0
                and position.Y.Offset == 12
                and anchor.X == 1
                and anchor.Y == 0,
            "panel toggle docks at viewport top-right"
        )
    end
end
local function hidePanelWithFocus(context)
    ui.Export:CaptureFocus()
    ui.HidePanel.MouseButton1Click:Fire()
    check(not ui.Frame.Visible, "Hide button hides focused panel " .. context)
    docked("Show", false)
    ui.HidePanel.MouseButton1Click:Fire()
    check(ui.Frame.Visible, "Hide button restores focused panel " .. context)
    docked("Hide", false)
    input.Focused = nil
end
press("F6")
check(
    ui.Gui.Enabled and cam.CameraType == "Scriptable" and turbineState and standState,
    "film mode borrows camera and suspends owners"
)
check(action() == "Sink", "framing consumes movement input")
hidePanelWithFocus("while framing")
for _, name in { "Name", "Speed", "Export" } do
    ui[name]:CaptureFocus()
    press("F7")
    check(not ui.Frame.Visible, "F7 hides panel with " .. name .. " focused")
    press("F7")
    check(ui.Frame.Visible, "F7 shows panel with " .. name .. " focused")
    input.InputBegan:Fire({ KeyCode = "F7" }, true)
    check(ui.Frame.Visible, "processed F7 remains ignored with " .. name .. " focused")
    press("F6")
    check(ui.Gui.Enabled and cam.CameraType == "Scriptable", "focused F6 does not exit film mode")
    check(action() == "Pass", "focused text input passes movement through")
    local before = cam.CFrame
    input.Down.W = true
    step(0.5)
    input.Down.W = false
    check(cam.CFrame == before, "typing does not move the freecam")
end
input.Focused = nil
input.Down.W = true
step(0.5)
input.Down.W = false
check(close(cam.CFrame.Position.Z, 3 - Config.FlySpeed * 0.5), "fly camera moves independently of character")
click("Record")
hidePanelWithFocus("while recording")
step(0.05)
click("Copy")
check(ui.Export.Text == "", "recording does not create a premature session take")
step(0.05)
input.Down.D = true
for _ = 1, 10 do
    step(0.1)
end
input.Down.D = false
click("Stop")
click("Copy")
local recorded = copy(wire)
check(input.Focused == ui.Export, "Copy Take focuses the export box")
press("F7")
check(not ui.Frame.Visible, "F7 hides panel immediately after Copy Take")
press("F7")
check(ui.Frame.Visible, "F7 restores panel after Copy Take")
input.Focused = nil
check(
    Path.Validate(recorded) and recorded.Keys[1].Time == 0 and close(recorded.Duration, 1.1),
    "recording saves a playable timed session take"
)
check(#recorded.Keys <= 12, "10Hz sampling stays bounded")
check(close(recorded.Keys[2].Time, 0.1), "stationary hold boundary retained before moving")
check(
    close(Path.Evaluate(Path.Compile(recorded), 0.05), recorded.Keys[1].Position[1]),
    "recording preserves initial stationary hold"
)
local framing = cam.CFrame
click("Play")
hidePanelWithFocus("during playback")
check(action() == "Pass", "playback allows live character performance")
step(0.3)
check(cam.CFrame.Position.X < framing.Position.X, "playback replays prior framing")
ui.Scrub.InputBegan:Fire({ UserInputType = "Left", Position = vec(75, 0, 0) })
check(close(ui.Fill.Size.X.Scale, 0.75), "click seek updates progress immediately")
click("Stop")
check(cam.CFrame == framing and cam.FieldOfView == 75, "Stop restores pre-playback camera")
ui.Speed.Text = "99"
click("Play")
check(ui.Speed.Text == "2", "playback speed clamped")
step(10)
check(cam.CFrame == framing, "natural completion restores framing")

-- Stationary recordings keep only mandatory endpoints and stop at five minutes.
click("Record")
for _ = 1, 3001 do
    step(0.1)
end
click("Copy")
input.Focused = nil
check(wire.Duration == 300 and #wire.Keys == 2, "stationary track is compact and hard capped")
check(string.find(ui.Status.Text, "cap") ~= nil, "cap warning shown")

local function hud(enabled, dev)
    local object = instance("ScreenGui")
    object.Enabled = enabled
    object.Parent = playerGui
    object:SetAttribute("FilmCamDevUI", dev)
    local changed = signal()
    function object:GetPropertyChangedSignal()
        return changed
    end
    local isA = object.IsA
    function object:IsA(class)
        return class == "LayerCollector" or isA(self, class)
    end
    return object
end
local visible, disabled, dev = hud(true), hud(false), hud(true, true)
click("Hide")
check(not visible.Enabled and not disabled.Enabled and dev.Enabled, "hide HUD preserves dev UI")
local late = hud(true)
playerGui.DescendantAdded:Fire(late)
check(not late.Enabled, "new HUD hidden during capture")
click("Letterbox")
press("F7")
check(not ui.Frame.Visible and ui.Bars[1].Visible, "clean capture hides panel while keeping letterbox")
docked("Show", true)
ui.Export:CaptureFocus()
ui.HidePanel.MouseButton1Click:Fire()
check(ui.Frame.Visible and ui.Bars[1].Visible, "Show restores panel without removing letterbox")
docked("Hide", false)
ui.HidePanel.MouseButton1Click:Fire()
check(not ui.Frame.Visible and not visible.Enabled, "Hide preserves hidden HUD and letterbox")
docked("Show", true)
click("Letterbox")
docked("Show", false)
click("Letterbox")
docked("Show", true)
press("F7")
docked("Hide", false)
press("F7")
docked("Show", true)
input.Focused = nil
press("F6")
check(
    visible.Enabled and not disabled.Enabled and late.Enabled and dev.Enabled,
    "exit restores exact HUD enabled states"
)
check(
    cam.CameraType == "Custom"
        and cam.CFrame == initialFrame
        and cam.Focus == initialFocus
        and cam.CameraSubject == initialSubject
        and cam.FieldOfView == 75,
    "exit restores complete borrowed camera state"
)
check(not turbineState and standState, "exit restores each controller's previous suspension state")
check(not ui.Gui.Enabled and not ui.Bars[1].Visible and action == nil, "exit removes filming presentation/input")
press("F6")
input.InputBegan:Fire({ UserInputType = "Right" }, false)
check(input.MouseBehavior == "Locked", "mouse drag locks pointer")
input.WindowFocusReleased:Fire()
check(input.MouseBehavior == "Default" and input.MouseIconEnabled, "focus loss restores pointer")
local replacement = instance("Camera")
replacement.CameraType = "Custom"
workspaceFake.CurrentCamera = replacement
changedCamera:Fire()
check(
    not ui.Gui.Enabled and replacement.CameraType == "Custom" and cam.CFrame == initialFrame,
    "camera replacement exits without modifying new camera"
)
controller.Destroy()
check(not turbineState and standState, "teardown preserves owner suspension states")
check(not controller.Play(curve, 1), "public Play is inert after teardown")
studio = true
player.UserId = 99
workspaceFake.CurrentCamera = cam
controller.Init()
press("F6")
check(ui.Gui.Enabled and cam.CameraType == "Scriptable", "non-allowlisted Studio client can film")
controller.Destroy()
-- The real view leaves its restore control reachable while its content is hidden.
cache.FilmCamPanel = nil
env.Enum.Font.Code = "Code"
local panel = loadModule("FilmCamPanel").Create(playerGui)
panel.Gui.Enabled, panel.Frame.Visible = true, false
check(
    panel.HidePanel:IsA("TextButton") and panel.HidePanel.Text == "Hide" and panel.HidePanel.Parent == panel.Gui,
    "real Hide button remains reachable when panel content is hidden"
)
check(panel.HidePanel ~= panel.Hide, "panel toggle is separate from the Hide UI control")
check(
    panel.HidePanel.Size.X.Offset == 64
        and panel.HidePanel.Size.Y.Offset == 28
        and panel.HidePanel.TextSize == 12
        and panel.HidePanel.Position.X.Scale == 1
        and panel.HidePanel.Position.Y.Scale == 0,
    "real panel creates a compact pill at viewport top-right"
)
panel.Gui:Destroy()
print(string.format("PASS: %d FilmCam presentation/math contracts", count))
