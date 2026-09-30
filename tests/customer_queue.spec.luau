setup(tycoon.AssignPlot(owner) == plot, "assign real plot")
check(owner:GetAttribute("CustomerFlowState") == "PLOT_ACTIVE", "plot claim activates without StartDay")
check(#customer.GetQueueSnapshot(owner) == 0, "initial delay does not spawn instantly")
customer.ActivateForPlayer(owner)
local entranceTargets = {}
local originalPathFactory = services.PathfindingService.CreatePath
services.PathfindingService.CreatePath = function(...)
    local path = originalPathFactory(...)
    local compute = path.ComputeAsync
    function path:ComputeAsync(start, finish)
        table.insert(entranceTargets, finish.X)
        compute(self, start, finish)
    end
    return path
end
advance(2)
services.PathfindingService.CreatePath = originalPathFactory
check(table.concat(entranceTargets, ",") == "10", "first arrival routes directly to the counter")
check(#customer.GetQueueSnapshot(owner) == 1, "one initial arrival despite duplicate activation")
advance(35)
advance(35)
local queue = customer.GetQueueSnapshot(owner)
check(#queue == economy.MaxCustomersPerPlot, "three timed arrivals fill queue")
cup = { Ingredients = { "Strawberry", "Banana", "Ice" }, BlendId = "held-during-order" }
local heldCup = cup
check(dialoguePlays == 0, "arrival never plays dialogue audio")
for index, entry in queue do
    check(entry.RequestId == "QueueRed", "every waiting customer has a request")
    check(entry.Model:GetPivot().Position.X == index * 10, "ordered customers reach assigned markers")
    check(entry.Model:GetPivot().LookVector.X > 0.999, "each queue slot respects its marker orientation")
    local bubble = entry.Model:FindFirstChild("OrderBubble", true)
    local take = entry.Model:FindFirstChild("TakeOrderPrompt", true)
    check(take.Enabled and bubble:FindFirstChildOfClass("TextLabel").Text == "", "new request hidden with take prompt")
    take.Triggered:Fire(foreign)
    owner.Near = false
    take.Triggered:Fire(owner)
    check(entry.Model:GetAttribute("OrderRevealed") ~= true, "foreign and distant reveals rejected")
    owner.Near = true
    local beforeSound = dialoguePlays
    take.Triggered:Fire(owner)
    flush()
    check(dialoguePlays == beforeSound + 1, "taking each queued order plays dialogue once")
    check(not take.Enabled and entry.Model:GetAttribute("OrderRevealed"), "order reveals once and disables take prompt")
    beforeSound = dialoguePlays
    take.Triggered:Fire(owner)
    flush()
    check(
        dialoguePlays == beforeSound and not customer.TakeOrder(owner, entry.Model),
        "repeat reveal cannot restart dialogue"
    )
    check(
        consumed == 0
            and tycoon.GetCash(owner) == 0
            and cup == heldCup
            and entry.Model:GetAttribute("RequestId") == entry.RequestId,
        "taking never consumes pays or rerolls"
    )
    check(
        bubble
            and bubble:FindFirstChildOfClass("TextLabel").Text == customer.FormatRequestText(
                requests.Definitions[1],
                loadModule("CustomerPresentation").KeywordColor
            )
            and entry.Model:GetAttribute("OwnerUserId") == owner.UserId,
        "each customer publishes owner-visible order text"
    )
    check(entry.Model:FindFirstChild("ServePrompt", true).Enabled == (index == 1), "only counter enables serving")
end
check(not customer.SpawnForPlayer(owner), "direct spawn cannot exceed capacity")
advance(35)
check(#customer.GetQueueSnapshot(owner) == 3, "full timer cannot create fourth customer")
cup = { Ingredients = { "Strawberry", "Banana", "Ice" }, BlendId = "queue-1" }
check(not customer.Serve(owner, queue[2].Model) and consumed == 0, "waiting model cannot consume cup")
queue[2].Model:FindFirstChild("ServePrompt", true).Triggered:Fire(owner)
check(consumed == 0, "forged waiting prompt cannot serve front customer")
check(not customer.Serve(foreign, queue[1].Model), "foreign player cannot serve queue")
owner.Near = false
check(not customer.Serve(owner) and consumed == 0, "distance rejects without consuming")
owner.Near = true
check(
    customer.Serve(owner, queue[1].Model) and consumed == 1 and tycoon.GetCash(owner) == 750,
    "front consumes and pays once"
)
check(not customer.Serve(owner, queue[1].Model), "served record rejects replay")
check(not customer.TakeOrder(owner, queue[1].Model), "departed order cannot be revealed")
local shifted = customer.GetQueueSnapshot(owner)
check(
    #shifted == 2 and shifted[1].Model == queue[2].Model and shifted[2].Model == queue[3].Model,
    "successful serve immediately shifts ordered queue"
)
check(not shifted[1].Ready, "advance requires counter arrival before serving")
flush()
check(
    shifted[1].Model:GetPivot().Position.X == 10 and shifted[2].Model:GetPivot().Position.X == 20,
    "both waiting customers walk forward"
)
check(shifted[1].Model:FindFirstChild("ServePrompt", true).Enabled, "advanced customer becomes serveable")
advance(5)
check(#customer.GetQueueSnapshot(owner) == 3, "full queue retries shortly after capacity frees")
for turn = 2, 5 do
    cup = { Ingredients = { "Strawberry", "Banana", "Ice" }, BlendId = "queue-" .. turn }
    setup(customer.Serve(owner), "serve beyond third customer")
    flush()
    advance(35)
end
check(
    days.GetSnapshot(owner).Served == 5 and days.IsServing(owner) and tycoon.GetCash(owner) == 3750,
    "serving and payouts continue beyond third customer"
)
-- Destroy an NPC while moving; old callbacks cannot re-enable or reinsert it.
local moving = customer.GetQueueSnapshot(owner)[1].Model
moving:Destroy()
flush()
check(customer.GetQueueSnapshot(owner)[1].Model ~= moving, "destroyed customer removed and queue advances")
local oldModels = customer.GetQueueSnapshot(owner)
tycoon.RemovePlayer(owner)
check(#customer.GetQueueSnapshot(owner) == 0, "release clears queue")
for _, entry in oldModels do
    check(entry.Model.Destroyed, "release removes waiting NPCs")
    check(not customer.TakeOrder(owner, entry.Model), "released customers reject stale take calls")
end
advance(100)
check(#customer.GetQueueSnapshot(owner) == 0 and not customer.SpawnForPlayer(owner), "release cancels future spawns")
setup(tycoon.AssignPlot(owner) == plot, "reclaim plot")
customer.DeactivateForPlayer(owner)
customer.ActivateForPlayer(owner)
advance(2)
check(#customer.GetQueueSnapshot(owner) == 1, "stale initial timer cannot spawn into replacement session")
-- A waiter can change destinations before its initial route finishes.
local incoming = customer.SpawnForPlayer(owner)
local incomingRequest = incoming:GetAttribute("RequestId")
cup = { Ingredients = { "Strawberry", "Banana", "Ice" }, BlendId = "race" }
setup(customer.Serve(owner), "serve while second customer is entering")
flush()
check(
    customer.GetSnapshot(owner).Model == incoming
        and customer.GetSnapshot(owner).Ready
        and incoming:GetPivot().Position.X == 10
        and incoming:GetAttribute("RequestId") == incomingRequest,
    "stale waiting arrival cannot overwrite new counter route or request"
)
plot.Parent = nil
plot.AncestryChanged:Fire()
check(#customer.GetQueueSnapshot(owner) == 0 and incoming.Destroyed, "plot leaving workspace immediately stops flow")
plot.Parent = workspaceFake
customer.ActivateForPlayer(owner)
-- Special cooldown is per owner and survives activation/day compatibility calls.
customer.DeactivateForPlayer(owner)
local folder = instance("Folder")
folder.Name, folder.Parent = "CustomerNPCs", storage
local special = instance("Folder")
special.Name, special.Parent = "Special", folder
local template = instance("Model")
template.Name, template.Parent = "SpecialTest", special
template:SetAttribute("CustomerId", "queue_special")
local humanoid = instance("Humanoid")
humanoid.RigType, humanoid.Parent = { Name = "R15" }, template
local root = instance("Part")
root.Name, root.Parent = "HumanoidRootPart", template
requests.NPCs.queue_special = { Type = "Special", RequestId = "QueueRed", Weight = 1 }
requests.SpecialCustomerChance = 1
customer.ActivateForPlayer(owner)
local first = customer.SpawnForPlayer(owner)
check(first:GetAttribute("CustomerId") == "queue_special", "eligible special spawns without day reset")
customer.DeactivateForPlayer(owner)
customer.BeginDay(owner)
customer.ActivateForPlayer(owner)
local second = customer.SpawnForPlayer(owner)
check(second:GetAttribute("CustomerId") == nil, "reactivation and BeginDay do not bypass cooldown")
customer.DeactivateForPlayer(owner)
now += 300
customer.ActivateForPlayer(owner)
local third = customer.SpawnForPlayer(owner)
check(third:GetAttribute("CustomerId") == "queue_special", "special eligible after continuous cooldown")
tycoon.RemovePlayer(owner)
customer.RemovePlayer(owner)
advance(100)
check(#customer.GetQueueSnapshot(owner) == 0, "player removal invalidates timers")

-- Unreachable arrivals use ordinary queue removal; no readiness or payout is fabricated.
tycoon.AssignPlot(owner)
customer.ActivateForPlayer(owner)
local savedCreatePath = services.PathfindingService.CreatePath
services.PathfindingService.CreatePath = function(...)
    local path = savedCreatePath(...)
    path.Status = "NoPath"
    return path
end
local cashBeforeRouteFailure = tycoon.GetCash(owner)
local unreachable = customer.SpawnForPlayer(owner)
flush()
check(unreachable.Destroyed and #customer.GetQueueSnapshot(owner) == 0, "exhausted route removes blocked queue entry")
check(tycoon.GetCash(owner) == cashBeforeRouteFailure, "route failure does not pay or serve a customer")
services.PathfindingService.CreatePath = savedCreatePath
local recovered = customer.SpawnForPlayer(owner)
flush()
check(
    recovered and not recovered.Destroyed and #customer.GetQueueSnapshot(owner) == 1,
    "queue accepts a reachable arrival after route failure"
)
tycoon.RemovePlayer(owner)
customer.RemovePlayer(owner)
