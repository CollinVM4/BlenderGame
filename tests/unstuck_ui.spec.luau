local p, h = player()
services.Players.LocalPlayer = p
p.CharacterAdded = signal()
local changedSignals = {}
function p:GetAttributeChangedSignal(name)
    changedSignals[name] = changedSignals[name] or signal()
    return changedSignals[name]
end
local playerGui = instance("PlayerGui")
function p:WaitForChild(_)
    return playerGui
end
local root = p.Character:FindFirstChild("HumanoidRootPart")
root.Position = vec(0, 3, 0)
h.MoveDirection = vec(1, 0, 0)
local panel = nil
cache.PanelManager = {
    GetActive = function()
        return panel
    end,
}
local remote = { OnClientEvent = signal(), Sent = {} }
function remote:FireServer(action)
    table.insert(self.Sent, action)
end
cache.UnstuckEvents = function()
    return remote
end
shared.Events.UnstuckEvents = "UnstuckEvents"
local bindings = {}
services.ContextActionService = {
    BindAction = function(_, name, fn, touch, key, gamepad)
        bindings[name] = { fn = fn, touch = touch, key = key, gamepad = gamepad }
    end,
    UnbindAction = function(_, name)
        bindings[name] = nil
    end,
}
env.UDim = {
    new = function(scale, offset)
        return { Scale = scale, Offset = offset }
    end,
}
env.UDim2.new = function(...)
    return { ... }
end
env.Enum.KeyCode = { U = "U", DPadUp = "DPadUp" }
env.Enum.UserInputState = { Begin = "Begin" }
env.Enum.ContextActionResult = { Sink = "Sink" }
loadModule("UnstuckController").Init()
local button, hint, feedback
for _, object in allInstances do
    if object.Name == "Unstuck" then
        button = object
    end
    if object.Name == "RecoveryFeedback" then
        feedback = object
    end
    if object.Name == "Eligibility" then
        hint = object
    end
end
setup(button and hint, "controller creates contextual UI")
local loop = coroutine.create(table.remove(deferred))
env.task.wait = function()
    coroutine.yield()
end
setup(coroutine.resume(loop), "start UI loop")
local function tick()
    now += 0.4
    local ok, error = coroutine.resume(loop)
    setup(ok, tostring(error))
end
check(not button.Visible and not bindings.UnstuckRecovery, "healthy character has no button or recovery binding")
p:SetAttribute("UnstuckWatching", true)
p:SetAttribute("UnstuckEligible", true)
tick()
check(
    button.Visible and button.Font == "FredokaOne" and button.Selectable,
    "eligible UI is Fredoka and console selectable"
)
check(
    bindings.UnstuckRecovery.key == "U"
        and bindings.UnstuckRecovery.gamepad == "DPadUp"
        and not bindings.UnstuckRecovery.touch,
    "PC/console shortcut uses its own binding and touch uses the button"
)
check(remote.Sent[#remote.Sent] == true, "client sends movement intent only")
button.Activated:Fire()
check(remote.Sent[#remote.Sent] == "Recover", "touch/click activation requests no destination")
local requests = #remote.Sent
button.Activated:Fire()
check(#remote.Sent == requests, "rapid duplicate activation throttled locally")
panel = "Upgrades"
tick()
check(not button.Visible and not bindings.UnstuckRecovery, "Framewisp panel suppresses UI and shortcuts")
panel = nil
tick()
root.Position += vec(1, 0, 0)
tick()
check(not button.Visible, "movement resumption hides the button locally")
tick()
now += 1
bindings.UnstuckRecovery.fn("UnstuckRecovery", "Begin")
check(remote.Sent[#remote.Sent] == "Recover", "console shortcut dispatches recovery request")
remote.OnClientEvent:Fire("Unable to find a safe recovery position.")
check(hint.Text == "Unable to find a safe recovery position.", "failed placement feedback stays contextual")
remote.OnClientEvent:Fire("Unstuck!", p.Character)
check(not button.Visible and h.State == "GettingUp", "success hides UI and transitions owning humanoid")
check(feedback.Visible and feedback.Text == "Unstuck!", "local success remains visible after button hides")
remote.OnClientEvent:Fire("Returned to your plot!", p.Character)
check(feedback.Visible and feedback.Text == "Returned to your plot!", "fallback has distinct visible feedback")
panel = "Upgrades"
tick()
check(not feedback.Visible, "success feedback respects panel suppression")
panel = nil
now += 4
tick()
check(not feedback.Visible, "success feedback expires")
p:SetAttribute("UnstuckEligible", false)
changedSignals.UnstuckEligible:Fire()
check(not button.Visible and not bindings.UnstuckRecovery, "server withdrawal releases contextual input")
p.CharacterAdded:Fire(instance("Model"))
check(not button.Visible, "respawn hides stale UI")

h.State = "Running"
remote.OnClientEvent:Fire("Unstuck!", instance("Model"))
check(h.State == "Running", "late success from an old character never interrupts healthy respawn")
