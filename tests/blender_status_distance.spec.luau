local distanceChecks = count
local pops = {}
env.Enum.EasingStyle = { Quad = "Quad" }
env.Enum.EasingDirection = { Out = "Out" }
env.TweenInfo = {
    new = function(...)
        return { ... }
    end,
}
services.TweenService = {
    Create = function(_, object, info, goal)
        local tween = { Object = object, Info = info, Goal = goal }
        function tween:Play()
            object.Scale = goal.Scale
            table.insert(pops, self)
        end
        function tween:Cancel()
            self.Cancelled = true
        end
        function tween:Finish()
            object.Scale = 1
        end
        return tween
    end,
}
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
    local textChanged = signal()
    label.GetPropertyChangedSignal = function()
        return textChanged
    end
    label.Name, label.Parent = "Status", gui
    label.TextTransparency, label.TextStrokeTransparency = 0, 0.25
    label.Text, label.TextSize, label.TextScaled = "UNCHANGED", 24, false
    label.Visible = true
    return {
        Label = label,
        Gui = gui,
        Origin = marker,
        Size = gui.Size,
        Offset = gui.StudsOffsetWorldSpace,
        TextChanged = textChanged,
    }
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
        check(refs.Label.TextSize == 24 and not refs.Label.TextScaled, "fixed font regardless of camera distance")
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
    #counter.Label:GetChildren() == 1 and counter.Gui.MaxDistance == 60,
    "stream-in and repeated registration retain a single presentation scale"
)
counter.Label.Text = "3 / 3\nLOADING COMPLETE!"
counter.TextChanged:Fire()
check(
    #pops == 1 and pops[1].Goal.Scale == 1.1 and pops[1].Info[1] == 0.12 and pops[1].Info[5],
    "reaching capacity makes one short reversing pop"
)
counter.TextChanged:Fire()
check(#pops == 1, "complete state refresh does not replay pop")
pops[1]:Finish()
check(counter.Label:FindFirstChildOfClass("UIScale").Scale == 1, "pop returns to normal size")
counter.Label.Text = "0 / 3"
counter.TextChanged:Fire()
counter.Label.Text = "3 / 3\nLOADING COMPLETE!"
counter.TextChanged:Fire()
check(#pops == 2, "a new completed batch can pop again")
counter.Label.Text = "0 / 3"
counter.TextChanged:Fire()
check(
    pops[2].Cancelled and counter.Label:FindFirstChildOfClass("UIScale").Scale == 1,
    "reset during pop immediately settles"
)
counter.Label.Text = "3 / 3\nLOADING COMPLETE!"
workspaceFake.DescendantAdded:Fire(counter.Label)
check(counter.Label.Text == "3 / 3\nLOADING COMPLETE!", "registration preserves server-updated count text")
print(string.format("PASS: %d client distance assertions (mocked Roblox boundary).", count - distanceChecks))
