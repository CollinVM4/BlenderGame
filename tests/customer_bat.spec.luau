-- Real queue, session, walk retries and service handlers; physics is an engine boundary.
local physical, pending = {}, {}
local compatible = true
local transitions = 0
deps.RagdollService = {
    PrepareCharacter = function()
        return compatible
    end,
    SetRagdolled = function(model, enabled)
        transitions += 1
        physical[model] = enabled
        return true
    end,
    IsRagdolled = function(model)
        return physical[model] == true
    end,
}
services.RunService.Heartbeat.Once = function(_, callback)
    table.insert(pending, callback)
end
local function heartbeat()
    local callbacks = pending
    pending = {}
    for _, callback in callbacks do
        callback()
    end
    flush()
end
local function spawnRig()
    local model = customer.SpawnForPlayer(owner)
    local root = model.PrimaryPart
    root.Name = "HumanoidRootPart"
    local humanoid = instance("Humanoid")
    humanoid.Health, humanoid.Parent = 100, model
    root.AssemblyMass = 12
    function root:ApplyImpulse(value)
        self.Impulse = value
    end
    return model, root
end
local hitContext = { Direction = vec(0, 0, -1), Duration = 1.5 }
setup(tycoon.AssignPlot(owner, plot) == plot, "claim hit test session")
local first, firstRoot = spawnRig()
check(customer.CanHitCustomer(owner, first), "arriving registered customer is hittable")
flush()
local second = spawnRig()
flush()
check(not customer.CanHitCustomer(foreign, first), "foreign session cannot hit customer")
setup(tycoon.JoinSession(foreign, owner, tycoon.GetRequestContext(owner)), "join shared customer session")
check(customer.CanHitCustomer(foreign, first), "another member of the same session can hit customer")
tycoon.RemovePlayer(foreign)
local foreignPlot = instance("Model")
foreignPlot.Name, foreignPlot.Parent = "ForeignPlot", workspaceFake
for name, marker in refs do
    local copy = instance("Part")
    copy.Name, copy.CFrame, copy.Parent = name, marker.CFrame, foreignPlot
end
tycoon.AutoTagLegacyPlot(foreignPlot)
setup(tycoon.AssignPlot(foreign) == foreignPlot, "claim different plot session")
check(not customer.CanHitCustomer(foreign, first), "another active plot session cannot hit customer")
tycoon.RemovePlayer(foreign)
local stale = instance("Model")
stale.Name, stale.Parent = first.Name, workspaceFake
stale:SetAttribute("PlotSessionId", tycoon.GetSessionId(owner))
check(not customer.CanHitCustomer(owner, stale), "names and session attributes cannot register a customer")
compatible = false
check(not customer.HitCustomer(owner, first, hitContext), "incompatible rig rejects without interrupting order")
compatible = true
check(customer.GetSnapshot(owner).Ready, "rejected hit leaves readiness intact")
setup(customer.TakeOrder(owner, first), "reveal first order")
local request = second:GetAttribute("RequestId")
check(customer.HitCustomer(owner, second, hitContext), "waiting customer accepts hit")
check(not customer.HitCustomer(owner, second, hitContext), "recovering customer rejects repeated hit")
check(not customer.TakeOrder(owner, second), "recovering customer rejects Take Order handler")
check(not second:FindFirstChild("TakeOrderPrompt", true).Enabled, "hit disables Take Order prompt")
local downAt = second:GetPivot()
cup = { Ingredients = { "Strawberry", "Banana", "Ice" }, BlendId = "advance-while-down" }
setup(customer.Serve(owner, first), "serve healthy front customer")
flush()
check(
    second:GetAttribute("QueuePosition") == 1 and second:GetPivot() == downAt,
    "queue advances assigned position without walking while down"
)
check(not customer.Serve(owner, second), "recovering front rejects Serve handler")
check(not second:FindFirstChild("ServePrompt", true).Enabled, "recovering front disables Serve prompt")
local cashBefore, consumedBefore = tycoon.GetCash(owner), consumed
local servedGrade = first:GetAttribute("Grade")
local servedHumanoid = first:FindFirstChildOfClass("Humanoid")
local exitMoveCalls = 0
servedHumanoid.MoveTo = function(humanoid, destination)
    exitMoveCalls += 1
    humanoid.WalkTarget = destination
    if exitMoveCalls > 1 then
        humanoid.MoveToFinished:Fire(true)
    end
end
advance(2)
check(exitMoveCalls == 1 and not first.Destroyed, "served customer starts its original exit walk")
check(customer.CanHitCustomer(owner, first), "registered served customer remains hittable after queue removal")
setup(customer.HitCustomer(owner, first, hitContext), "hit served customer walking to exit")
check(
    not first:FindFirstChild("TakeOrderPrompt", true).Enabled
        and not first:FindFirstChild("ServePrompt", true).Enabled,
    "served customer prompts remain disabled during recovery"
)
local stillQueued = false
for _, entry in customer.GetQueueSnapshot(owner) do
    stillQueued = stillQueued or entry.Model == first
end
check(not stillQueued, "served customer is not reinserted into the ordering queue")
servedHumanoid.MoveToFinished:Fire(true)
check(not first.Destroyed, "cancelled exit walk completion cannot remove a ragdolled customer")
heartbeat()
advance(hitContext.Duration)
heartbeat()
heartbeat()
check(
    first.Destroyed and servedHumanoid.WalkTarget.X == refs.CustomerExit.CFrame.Position.X,
    "recovered served customer starts a fresh exit walk and is removed on completion"
)
check(
    tycoon.GetCash(owner) == cashBefore
        and consumed == consumedBefore
        and first:GetAttribute("Grade") == servedGrade,
    "hitting a served customer does not repeat payout, consumption, or grade"
)
heartbeat()
local secondRoot = second:FindFirstChild("HumanoidRootPart")
check(
    secondRoot.Impulse and secondRoot.Impulse.Z == -84 and secondRoot.Impulse.Y == 48,
    "customer receives configured mass-scaled bat impulse"
)
advance(1.5)
heartbeat()
check(
    not physical[second]
        and second:GetPivot().Position.X == refs.CustomerCounter.CFrame.Position.X
        and customer.GetSnapshot(owner).Ready,
    "recovery explicitly walks to latest counter marker"
)
check(
    second:GetAttribute("RequestId") == request and consumed == consumedBefore and tycoon.GetCash(owner) == cashBefore,
    "hit and recovery preserve request and payout state"
)
check(
    second:FindFirstChild("TakeOrderPrompt", true).Enabled and not second:FindFirstChild("ServePrompt", true).Enabled,
    "untaken order restores Take Order only"
)
check(not customer.CanHitCustomer(owner, second), "short immunity prevents immediate chain hit")
advance(loadModule("BatConfig").ImmunitySeconds)
setup(customer.TakeOrder(owner, second), "reveal recovered order")
setup(customer.HitCustomer(owner, second, hitContext), "hit at unchanged counter marker")
heartbeat()
local savedPath = services.PathfindingService.CreatePath
services.PathfindingService.CreatePath = function(...)
    local path = savedPath(...)
    path.Status = "NoPath"
    return path
end
advance(1.5)
heartbeat()
services.PathfindingService.CreatePath = savedPath
check(
    not second.Destroyed
        and customer.GetSnapshot(owner).Model == second
        and second:GetPivot().Position.X == refs.CustomerCounter.CFrame.Position.X
        and customer.GetSnapshot(owner).Ready,
    "exhausted recovery route safely repositions instead of deleting customer"
)
check(
    second:GetAttribute("RequestId") == request
        and second:GetAttribute("OrderRevealed")
        and second:FindFirstChild("ServePrompt", true).Enabled
        and not second:FindFirstChild("TakeOrderPrompt", true).Enabled,
    "failed return preserves revealed order and restores Serve"
)
check(consumed == consumedBefore and tycoon.GetCash(owner) == cashBefore, "fallback neither consumes nor pays")
advance(loadModule("BatConfig").ImmunitySeconds)
setup(customer.HitCustomer(owner, second, hitContext), "hit before removal")
second:Destroy()
local before = transitions
advance(1.5)
heartbeat()
check(transitions == before and not customer.CanHitCustomer(owner, second), "destroyed customer callbacks no-op")
local old = spawnRig()
setup(customer.HitCustomer(owner, old, hitContext), "hit before session replacement")
tycoon.RemovePlayer(owner)
setup(tycoon.AssignPlot(owner, plot) == plot, "replace session")
local replacement = spawnRig()
before = transitions
advance(1.5)
heartbeat()
check(
    old.Destroyed
        and transitions == before
        and not physical[replacement]
        and customer.GetSnapshot(owner).Model == replacement,
    "old session recovery cannot affect replacement customer"
)
setup(customer.HitCustomer(owner, replacement, hitContext), "hit before same-session flow reset")
customer.DeactivateForPlayer(owner)
customer.ActivateForPlayer(owner)
local resetCustomer = spawnRig()
before = transitions
advance(1.5)
heartbeat()
check(
    replacement.Destroyed and transitions == before and customer.GetSnapshot(owner).Model == resetCustomer,
    "flow reset invalidates recovery even when the plot session id is unchanged"
)
tycoon.RemovePlayer(owner)
