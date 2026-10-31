local gui = loadModule("TasksGui")
local registry = loadModule("UIRegistry")
local playerGui = instance("PlayerGui")
check(gui.Resolve(playerGui) == nil and registry.Panels.Tasks == true, "missing authored panel fails soft")
local function child(class, name, parent)
    local item = instance(class)
    item.Name, item.Parent, item.Visible, item.Enabled = name, parent, true, true
    return item
end
local root = child("ScreenGui", "Export", playerGui)
local desktop = child("Frame", "Be a Blender! Desktop", root)
local content = child("Frame", "DesktopContent", desktop)
local panel = child("Frame", "Tasks", content)
for _, name in { "ServeTask", "StealTask" } do
    local row = child("Frame", name, panel)
    for _, label in { "Objective", "Progress", "Reward" } do
        child("TextLabel", label, row)
    end
end
local view = gui.Resolve(playerGui)
check(
    view and view.Serve.Reward == panel:FindFirstChild("ServeTask"):FindFirstChild("Reward"),
    "binds exact exported semantic hierarchy"
)
check(registry.PanelId(panel) == "Tasks", "Tasks participates in existing panel registry")
panel.Name = "Tasks_list"
check(gui.Resolve(playerGui) == nil, "role suffix names are not the binding contract")
panel.Name = "Tasks"
local duplicate = child("Frame", "Tasks", content)
check(gui.Resolve(playerGui) == nil, "ambiguous exports fail soft")
duplicate:Destroy()
root.Enabled = false
check(gui.Resolve(playerGui) == nil, "disabled export cannot bind")
local accept = loadModule("CashRewardState").New()
check(
    accept("TaskReward", 42, { BlendId = "task-1", Payout = 5000 }, 42),
    "standalone task payment reuses existing flying cash acceptance"
)
check(
    not accept("TaskReward", 42, { BlendId = "task-1", Payout = 5000 }, 42),
    "standalone feedback shares duplicate protection"
)
