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
