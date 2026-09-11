local distanceChecks = count
workspaceFake.DescendantAdded = signal()
workspaceFake.DescendantRemoving = signal()
services.RunService.RenderStepped = signal()
env.Vector2 = {
    new = function(x, y)
        return { X = x, Y = y }
    end,
}
local camera = { CFrame = frame() }
workspaceFake.CurrentCamera = camera
local function display(name, attachment)
    local marker = instance(if attachment then "Attachment" else "Part")
    marker.Parent = plots[1]
    marker.WorldPosition = vec(0, 0, 0)
    local gui = instance("BillboardGui")
    gui.Name, gui.Adornee, gui.Parent = name, marker, marker
    local label = instance("TextLabel")
    label.Name, label.Parent = "Status", gui
    label.TextTransparency, label.TextStrokeTransparency = 0, 0.25
    label.Text, label.TextSize = "UNCHANGED", 24
    return label, gui
end
local counter, countGui = display("IngredientCountDisplay", true)
function workspaceFake:GetDescendants()
    return { counter }
end
local controller = loadModule("BlenderStatusDistanceController")
controller.Init()
controller.Init()
check(#counter:GetChildren() == 1, "idempotent client startup creates one UIScale")
local turbine, turbineGui = display("TurbineStatusDisplay", false)
workspaceFake.DescendantAdded:Fire(turbine)
check(countGui.MaxDistance == 60 and turbineGui.MaxDistance == 40, "per-display local visibility limits")
local function at(distance)
    workspaceFake.CurrentCamera.CFrame = frame(distance, 0, 0)
    services.RunService.RenderStepped:Fire()
end
local function near(a, b)
    return math.abs(a - b) < 0.00001
end
at(12)
check(counter:FindFirstChild("CameraDistanceScale").Scale == 1, "near counter full scale")
check(turbine:FindFirstChild("CameraDistanceScale").Scale == 1, "near turbine full scale")
at(21)
check(near(turbine:FindFirstChild("CameraDistanceScale").Scale, 0.70), "turbine stable middle band")
at(30)
check(near(counter:FindFirstChild("CameraDistanceScale").Scale, 0.72), "counter stable middle band")
check(near(turbine:FindFirstChild("CameraDistanceScale").Scale, 0.55), "turbine minimum scale")
check(turbine.TextTransparency == 0, "turbine stays opaque until fade starts")
at(35)
check(
    near(turbine.TextTransparency, 0.5) and near(turbine.TextStrokeTransparency, 0.625),
    "text and outline fade together"
)
at(40)
check(not turbine.Visible and counter.Visible, "turbine hides independently")
at(45)
check(near(counter:FindFirstChild("CameraDistanceScale").Scale, 0.55), "counter minimum scale")
at(50)
check(counter.TextTransparency == 0, "counter fade starts at 50")
at(55)
check(near(counter.TextTransparency, 0.5), "counter fade midpoint")
at(60)
check(not counter.Visible and counter.TextTransparency == 1, "counter fully hidden at 60")
workspaceFake.CurrentCamera = { CFrame = frame() }
at(0)
check(
    counter.Visible and turbine.Visible and counter.TextStrokeTransparency == 0.25,
    "new camera restores nearby appearance"
)
check(
    counter.Text == "UNCHANGED" and counter.TextSize == 24 and not counter.TextScaled,
    "state text and fixed base font preserved"
)
for _, case in
    {
        { Label = counter, Boundaries = { 15, 35 }, Scales = { 1, 0.72, 0.55 } },
        { Label = turbine, Boundaries = { 12, 25 }, Scales = { 1, 0.70, 0.55 } },
    }
do
    at(0)
    local scale = case.Label:FindFirstChild("CameraDistanceScale")
    for index, boundary in case.Boundaries do
        at(boundary + 0.5)
        check(near(scale.Scale, case.Scales[index]), "outbound jitter keeps previous band")
        at(boundary + 1.1)
        check(near(scale.Scale, case.Scales[index + 1]), "crossing outer hysteresis selects smaller band")
        for _, offset in { -0.5, 0.5, -0.9, 0.9 } do
            at(boundary + offset)
            check(near(scale.Scale, case.Scales[index + 1]), "threshold jitter keeps smaller band stable")
        end
        at(boundary - 1.1)
        check(near(scale.Scale, case.Scales[index]), "crossing inner hysteresis restores larger band")
        at(boundary + 2)
    end
end
workspaceFake.CurrentCamera = nil
services.RunService.RenderStepped:Fire()
check(not counter.Visible, "missing camera safely hides text")
workspaceFake.DescendantRemoving:Fire(counter)
check(#counter:GetChildren() == 0, "stream-out cleans local scale")
workspaceFake.CurrentCamera = camera
workspaceFake.DescendantAdded:Fire(counter)
check(#counter:GetChildren() == 1, "stream-in rebinds once")
print(string.format("PASS: %d client distance assertions (mocked Roblox boundary).", count - distanceChecks))
