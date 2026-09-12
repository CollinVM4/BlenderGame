local distanceChecks = count
workspaceFake.DescendantAdded = signal()
workspaceFake.DescendantRemoving = signal()
services.RunService.RenderStepped = signal()
env.Vector2 = {
    new = function(x, y)
        return { X = x, Y = y }
    end,
}
env.UDim2.fromOffset = function(x, y)
    return { X = { Scale = 0, Offset = x }, Y = { Scale = 0, Offset = y } }
end
env.UDim2.fromScale = function(x, y)
    return { X = { Scale = x, Offset = 0 }, Y = { Scale = y, Offset = 0 } }
end
local function display(name, width, height)
    local marker = instance("Attachment")
    marker.Parent = plots[1]
    marker.WorldPosition = vec(0, 0, 0)
    local gui = instance("BillboardGui")
    gui.Name, gui.Adornee, gui.Parent = name, marker, marker
    gui.Size = env.UDim2.fromOffset(width, height)
    gui.StudsOffsetWorldSpace = vec(0, 0, 0)
    local label = instance("TextLabel")
    label.Name, label.Parent = "Status", gui
    label.TextTransparency, label.TextStrokeTransparency = 0, 0.25
    label.Text, label.TextSize, label.TextScaled = "UNCHANGED", 24, false
    label.Visible = true
    return { Label = label, Gui = gui, Origin = marker, Size = gui.Size, Offset = gui.StudsOffsetWorldSpace }
end
local counter = display("IngredientCountDisplay", 240, 72)
local turbine = display("TurbineStatusDisplay", 380, 80)
function workspaceFake:GetDescendants()
    return { counter.Label }
end
local controller = loadModule("BlenderStatusDistanceController")
controller.Init()
controller.Init()
workspaceFake.DescendantAdded:Fire(turbine.Label)
check(counter.Gui.MaxDistance == 60 and turbine.Gui.MaxDistance == 40, "original visibility ranges retained")
check(counter.Label.AnchorPoint.X == 0.5 and counter.Label.Position.X.Scale == 0.5, "centered count layout retained")
local countPosition, countAnchor = counter.Label.Position, counter.Label.AnchorPoint
for _, distance in { 0, 12, 15, 21, 35, 45, 50, 55, 59.9, 60, 80, 0 } do
    workspaceFake.CurrentCamera = { CFrame = frame(distance, 0, 0) }
    services.RunService.RenderStepped:Fire()
    for _, refs in { counter, turbine } do
        check(
            refs.Gui.Size == refs.Size and refs.Size.X.Scale == 0 and refs.Size.Y.Scale == 0,
            "pixel canvas stays fixed"
        )
        check(
            refs.Gui.Adornee == refs.Origin and refs.Gui.StudsOffsetWorldSpace == refs.Offset,
            "world anchor/offset unchanged"
        )
        check(
            refs.Label.TextSize == 24 and not refs.Label.TextScaled and #refs.Label:GetChildren() == 0,
            "fixed font with no UIScale"
        )
        check(refs.Label.TextTransparency == 0 and refs.Label.TextStrokeTransparency == 0.25, "no distance fade")
        check(
            refs.Label.Text == "UNCHANGED" and refs.Label.Visible,
            "state text untouched; engine handles range culling"
        )
    end
end
check(
    counter.Label.Position == countPosition and counter.Label.AnchorPoint == countAnchor,
    "camera never changes layout"
)
workspaceFake.CurrentCamera = nil
services.RunService.RenderStepped:Fire()
check(counter.Label.Visible, "no camera polling or local text visibility overrides")
workspaceFake.DescendantRemoving:Fire(counter.Label)
workspaceFake.DescendantAdded:Fire(counter.Label)
workspaceFake.DescendantAdded:Fire(counter.Label)
check(
    #counter.Label:GetChildren() == 0 and counter.Gui.MaxDistance == 60,
    "stream-in and repeated registration never add scales"
)
counter.Label.Text = "3 / 3\nLOADING COMPLETE!"
workspaceFake.DescendantAdded:Fire(counter.Label)
check(counter.Label.Text == "3 / 3\nLOADING COMPLETE!", "registration preserves server-updated count text")
print(string.format("PASS: %d client distance assertions (mocked Roblox boundary).", count - distanceChecks))
