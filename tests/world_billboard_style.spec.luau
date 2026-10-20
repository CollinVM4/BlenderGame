local style = loadModule("WorldBillboardStyle")
local gui = instance("BillboardGui")
style.ApplyBillboard(gui, { WidthStuds = 7, HeightStuds = 1.4, MaxDistance = 25 })
check(gui.Size.X.Scale == 7 and gui.Size.Y.Scale == 1.4, "billboard dimensions are world studs")
check(gui.Size.X.Offset == 0 and gui.Size.Y.Offset == 0, "no screen pixel canvas")
check(gui.MaxDistance == 25 and gui.AlwaysOnTop and not gui.ResetOnSpawn, "explicit culling and legacy defaults")
style.ApplyBillboard(
    gui,
    { WidthStuds = 4, HeightStuds = 0.8, MaxDistance = 45, AlwaysOnTop = false, ResetOnSpawn = true }
)
check(not gui.AlwaysOnTop and gui.ResetOnSpawn, "direct callers can preserve authored visibility flags")
local originalStudio = services.RunService.IsStudio
services.RunService.IsStudio = function()
    return true
end
for _, settings in
    {
        { WidthStuds = 7, HeightStuds = 1.4 },
        { Width = 300, Height = 56, MaxDistance = 25 },
        { WidthStuds = 7, HeightStuds = 1.4, MaxDistance = math.huge },
        { WidthStuds = 7, HeightStuds = 1.4, MaxDistance = 0 },
        { WidthStuds = -1, HeightStuds = 1.4, MaxDistance = 25 },
        { WidthStuds = 7, HeightStuds = 0 / 0, MaxDistance = 25 },
    }
do
    check(not pcall(style.ApplyBillboard, gui, settings), "invalid or legacy fields fail loudly in Studio")
end
services.RunService.IsStudio = function()
    return false
end
local warnings = 0
local originalWarn = env.warn
env.warn = function()
    warnings += 1
end
local invalid = instance("BillboardGui")
check(pcall(style.ApplyBillboard, invalid, { WidthStuds = 7, HeightStuds = 1.4 }), "production warns without throwing")
check(
    warnings == 1 and invalid.Enabled == false and invalid.MaxDistance == 0,
    "production invalid configuration fails closed"
)
env.warn = originalWarn
services.RunService.IsStudio = originalStudio
local text = instance("TextLabel")
style.ApplyText(text, { TextSize = 21 })
check(text.TextSize == 21 and not text.TextScaled, "legacy text default remains pixel sizing")
style.ApplyText(text, { TextScaled = true })
check(text.TextScaled, "stud containers can opt into proportional text")
style.ApplyText(text, { TextScaled = false })
check(not text.TextScaled, "explicit fixed text opt-out works")
print("PASS: world billboard style contracts")

local canvas = instance("BillboardGui")
style.ApplyBillboard(canvas, { WidthStuds = 8, HeightStuds = 2, MaxDistance = 30 })
canvas.AbsoluteSize = vec(800, 200, 0)
local lettering = instance("TextLabel")
local stop = style.ApplyWorldStroke(lettering, canvas, { Color = env.Color3.new(1, 0, 0), Transparency = 0.3 })
local stroke = lettering:FindFirstChild("WorldOutline")
check(stroke.Thickness == 5 and stroke.Transparency == 0.3, "world stroke attaches using stud dimensions and style")
canvas.AbsoluteSize = vec(1600, 400, 0)
canvas:GetPropertyChangedSignal("AbsoluteSize"):Fire()
check(stroke.Thickness == 10, "doubling rendered lettering doubles outline weight")
canvas.AbsoluteSize = vec(10, 2, 0)
canvas:GetPropertyChangedSignal("AbsoluteSize"):Fire()
check(stroke.Thickness == 1, "distant outline clamps to one pixel")
stop()
canvas.AbsoluteSize = vec(1600, 400, 0)
canvas:GetPropertyChangedSignal("AbsoluteSize"):Fire()
check(stroke.Thickness == 1, "cleanup stops size updates")
local stopAgain = style.ApplyWorldStroke(lettering, canvas, { ThicknessStuds = 0.1 })
check(
    lettering:FindFirstChild("WorldOutline") == stroke and stroke.Thickness == 20,
    "rebind reuses existing stroke with per-style studs"
)
stopAgain()
print("PASS: world stroke attach, scale, clamp, reuse and cleanup")

-- Replicated and cloned server views bind in the client's camera context.
local world = instance("Folder")
world.DescendantAdded, world.DescendantRemoving = signal(), signal()
local oldWorld = env.workspace
env.workspace = world
local replicated = instance("BillboardGui")
replicated.Parent = world
style.ApplyBillboard(replicated, { WidthStuds = 8, HeightStuds = 2, MaxDistance = 30 })
replicated.AbsoluteSize = vec(800, 200, 0)
local caption = instance("TextLabel")
caption.Parent = replicated
local replicatedStroke = instance("UIStroke")
replicatedStroke.Name, replicatedStroke.Parent = "DialogueOutline", caption
replicatedStroke.Color, replicatedStroke.Transparency = env.Color3.new(0, 1, 0), 0.4
replicatedStroke:SetAttribute("WorldThicknessStuds", 0.05)
loadModule("WorldStrokeController").Init()
check(
    replicatedStroke.Thickness == 5 and replicatedStroke.Transparency == 0.4,
    "client binds preexisting replicated stroke without changing opacity"
)
replicated.AbsoluteSize = vec(1600, 400, 0)
replicated:GetPropertyChangedSignal("AbsoluteSize"):Fire()
check(replicatedStroke.Thickness == 10, "replicated view follows client screen size")
local lateStroke = instance("UIStroke")
lateStroke.Name, lateStroke.Parent = "LateOutline", caption
world.DescendantAdded:Fire(lateStroke)
lateStroke:SetAttribute("WorldThicknessStuds", 0.1)
lateStroke:GetAttributeChangedSignal("WorldThicknessStuds"):Fire()
check(lateStroke.Thickness == 20, "late replicated metadata binds arriving view")
world.DescendantRemoving:Fire(lateStroke)
replicated.AbsoluteSize = vec(800, 200, 0)
replicated:GetPropertyChangedSignal("AbsoluteSize"):Fire()
check(lateStroke.Thickness == 20, "removed replicated view stops receiving updates")
env.workspace = oldWorld
print("PASS: client world stroke replication, late arrival and teardown")
