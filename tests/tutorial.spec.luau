-- Workspace lookup boundary supports authored global scenery in this suite.
workspaceFake.FindFirstChild = function(_, name)
    for _, object in allInstances do
        if object.Parent == workspaceFake and object.Name == name then
            return object
        end
    end
    return nil
end
local timers = {}
shared.TutorialTargets = "TutorialTargets"
env.Enum.HumanoidStateType = { Climbing = "Climbing" }
env.task.delay = function(seconds, fn)
    table.insert(timers, { At = now + seconds, Run = fn })
end
local function advance(seconds)
    local ending = now + seconds
    while true do
        table.sort(timers, function(a, b)
            return a.At < b.At
        end)
        if not timers[1] or timers[1].At > ending then
            break
        end
        local timer = table.remove(timers, 1)
        now = timer.At
        timer.Run()
        flush()
    end
    now = ending
    flush()
    heartbeat:Fire(0.1)
end
local tutorial = loadModule("TutorialService")
local authority = sessionTestAuthority
local orders, batch, ingredient, flight, cups = {}, nil, nil, false, {}
local carried = {}
local farmRow = { State = "LOCKED", IngredientId = nil }
local function resetOrders()
    orders = {
        { RequestId = "Red", Served = false, OrderTaken = false },
        { RequestId = "Cold", Served = false, OrderTaken = false },
        { RequestId = "Yellow", Served = false, OrderTaken = false },
    }
end
resetOrders()
tutorial.Init({
    TycoonService = authority,
    FarmService = {
        GetRowSnapshot = function()
            return farmRow
        end,
    },
    CustomerService = {
        GetTutorialSnapshot = function()
            return orders
        end,
    },
    BlendService = {
        GetSnapshot = function()
            return batch
        end,
    },
    InventoryService = {
        HasCarriedIngredient = function()
            return ingredient ~= nil
        end,
        GetCarriedIngredientIds = function()
            return carried
        end,
        HasIngredientInFlight = function()
            return flight
        end,
        GetSmoothieInventory = function()
            return cups
        end,
    },
})
local counterBase
local function membershipChanged(member)
    local plot = authority.GetPlot(member)
    if plot and not plot:FindFirstChild("Customer Area") then
        local object = plot
        for _, name in { "Customer Area", "Counter", "Base Structure", "Base" } do
            local child = instance(if name == "Base" then "Part" else "Model")
            child.Name, child.Parent = name, object
            object = child
        end
        counterBase = object
        counterBase.Position = vec(100, 0, 0)
    end
    tutorial.MembershipChanged(member)
end
authority.Init({ MemberChanged = membershipChanged, MemberRemoved = tutorial.MembershipChanged })
local p = instance("Player")
p.Name, p.UserId, p.Parent = "Learner", 801, workspaceFake
p.Character = instance("Model")
p.Character.Parent = workspaceFake
p.Character.WaitForChild = p.Character.FindFirstChild
local root = instance("Part")
root.Name, root.Parent = "HumanoidRootPart", p.Character
tutorial.AddPlayer(p)
tutorial.ApplyCharacter(p, p.Character)
flush()
check(
    p:GetAttribute("TutorialStage") == "ClaimPlot" and not p:GetAttribute("TutorialHintReady"),
    "claim hint starts delayed"
)
advance(4.5)
check(p:GetAttribute("TutorialHintReady"), "claim hint becomes active")
advance(60)
check(
    p:GetAttribute("TutorialStage") == "ClaimPlot" and p:GetAttribute("TutorialHintReady"),
    "claim hint persists until membership"
)
local plot = assignTestSession(p)
check(
    p:GetAttribute("TutorialStage") == "Counter" and p:GetAttribute("TutorialHintReady"),
    "claim preserves the environmental counter introduction"
)
root.Position = counterBase.Position
heartbeat:Fire(0.1)
check(p:GetAttribute("TutorialStage") == "Order", "reaching the counter guides to the customer without a timer")
root.Position = vec(0, 0, 0)
orders[1].Model = instance("Model")
heartbeat:Fire(0.1)
check(p:GetAttribute("TutorialStage") == "Order", "spawn alone cannot accept order")
orders[1].OrderTaken = true
heartbeat:Fire(0.1)
check(
    p:GetAttribute("TutorialStage") == "Stash" and p:GetAttribute("TutorialStashSlot") == 3,
    "accepted red order selects slot three"
)
ingredient = "Cherries"
local ladder = instance("Model")
ladder.Name, ladder.Parent = "Ladder", plot
local truss = instance("TrussPart")
truss.Parent, truss.Size = ladder, vec(2, 20, 2)
truss.CFrame.PointToObjectSpace = function(self, point)
    return point - self.Position
end
local humanoid = instance("Humanoid")
humanoid.Parent, humanoid.Health = p.Character, 100
local movement = "Running"
humanoid.GetState = function()
    return movement
end
tutorial.Mark(p, "TookStashItem")
heartbeat:Fire(0.1)
for _, ids in
    { { "Cherries" }, { "Cherries", "Cherries" }, { "Cherries", "Strawberry" }, { "Cherries", "Strawberry", "Banana" } }
do
    carried = ids
    heartbeat:Fire(0.1)
    check(p:GetAttribute("TutorialStage") == "Stash", "incomplete multiset keeps gathering without ladder guidance")
end
carried = { "Strawberry", "Cherries", "Cherries" }
heartbeat:Fire(0.1)
check(p:GetAttribute("TutorialStage") == "Ladder", "full carried multiset targets owned ladder")
tutorial.ApplyCharacter(p, p.Character)
flush()
check(p:GetAttribute("TutorialStage") == "Ladder", "respawn retains unfinished ladder guidance")
movement, root.Position = "Climbing", vec(100, 0, 0)
heartbeat:Fire(0.1)
check(p:GetAttribute("TutorialStage") == "Ladder", "climbing elsewhere cannot complete owned ladder guide")
root.Position = vec(0, 0, 0)
heartbeat:Fire(0.1)
check(p:GetAttribute("TutorialStage") == "Blender", "actual nearby ladder climb advances to Glass")
movement = "Running"
carried = { "Cherries" }
heartbeat:Fire(0.1)
check(p:GetAttribute("TutorialStage") == "Blender", "partial carry after UsedLadder still targets blender")
ingredient, flight = nil, true
heartbeat:Fire(0.1)
check(p:GetAttribute("TutorialStage") == "Blender", "in-flight throw keeps glass guidance")
flight = false
for count = 1, 2 do
    batch = {
        BatchId = 1,
        AcceptedIngredientCount = count,
        State = "LOADING",
        ProgressPercent = 0,
        ReadyToDispense = false,
    }
    heartbeat:Fire(0.1)
    check(p:GetAttribute("TutorialStage") == "Stash", "underfilled batch requires another ingredient")
end
batch.AcceptedIngredientCount, batch.State = 3, "READY"
heartbeat:Fire(0.1)
check(p:GetAttribute("TutorialStage") == "Turbine", "three accepted ingredients enable turbine")
tutorial.Mark(p, "UsedTurbine")
check(p:GetAttribute("TutorialStage") == "Turbine", "turbine activation alone cannot complete blending")
batch.State, batch.ProgressPercent = "BLENDING", 99.9
heartbeat:Fire(0.1)
check(p:GetAttribute("TutorialStage") == "Turbine", "partial progress cannot enable dispenser")
batch.ProgressPercent = 100
heartbeat:Fire(0.1)
check(p:GetAttribute("TutorialStage") == "Turbine", "100 percent without authoritative readiness remains turbine")
batch.State, batch.ReadyToDispense = "COMPLETE", true
heartbeat:Fire(0.1)
check(p:GetAttribute("TutorialStage") == "Dispenser", "completed ready batch enables dispenser")
batch.ProgressPercent = 99
heartbeat:Fire(0.1)
check(p:GetAttribute("TutorialStage") == "Turbine", "readiness without 100 percent cannot enable dispenser")
batch.ProgressPercent = 100
tutorial.Mark(p, "DispensedSmoothie")
check(p:GetAttribute("TutorialStage") == "Dispenser", "dispense telemetry cannot replace actual cup ownership")
cups = { { Data = { BlendId = "red-cup", Ingredients = { "Cherries", "Cherries", "Strawberry" } } } }
batch = { AcceptedIngredientCount = 0, State = "EMPTY", ProgressPercent = 0, ReadyToDispense = false }
heartbeat:Fire(0.1)
check(p:GetAttribute("TutorialStage") == "Serve", "owned dispensed cup directs to customer even after batch reset")
cups[1].Slot = 1
heartbeat:Fire(0.1)
check(
    p:GetAttribute("TutorialStage") == "Serve" and p:GetAttribute("TutorialStashSlot") == 3,
    "early stored cup reconciles without redirecting ingredient gleams to protected slots"
)
tutorial.Mark(p, "ServedCustomer")
tutorial.Mark(p, "ServedCustomer")
check(p:GetAttribute("TutorialOrderIndex") == 1, "duplicate generic milestones cannot complete scripted order")
orders[2].OrderTaken = true
orders[1].Served = true
cups = {}
heartbeat:Fire(0.1)
check(
    p:GetAttribute("TutorialOrderIndex") == 2
        and p:GetAttribute("TutorialStashSlot") == 4
        and p:GetAttribute("TutorialStage") == "Stash",
    "already accepted waiting cold order reconciles immediately"
)
tutorial.ApplyCharacter(p, p.Character)
flush()
check(p:GetAttribute("TutorialOrderIndex") == 2, "respawn preserves current order")
batch = { BatchId = 2, AcceptedIngredientCount = 3, State = "READY", ProgressPercent = 0, ReadyToDispense = false }
heartbeat:Fire(0.1)
check(p:GetAttribute("TutorialStage") == "Turbine", "new batch belongs to current cold order")
orders[2].Served = true
heartbeat:Fire(0.1)
check(
    p:GetAttribute("TutorialOrderIndex") == 3 and p:GetAttribute("TutorialStage") == "Order",
    "third order needs normal acceptance"
)
orders[3].OrderTaken = true
heartbeat:Fire(0.1)
check(p:GetAttribute("TutorialStashSlot") == 5, "yellow uses slot five")
check(
    p:GetAttribute("TutorialStage") == "FinishBatch",
    "old batch count cannot complete the new order's loading objective"
)
batch.ReadyToDispense, batch.ProgressPercent = true, 100
heartbeat:Fire(0.1)
check(p:GetAttribute("TutorialStage") == "DrainBatch", "stale full batches recover through actual dispensing")
batch.Ingredients = { "Banana", "Banana", "Banana" }
heartbeat:Fire(0.1)
check(
    p:GetAttribute("TutorialStage") == "Dispenser",
    "a genuinely prepared next-order recipe reconciles early completion"
)
batch = { BatchId = 3, AcceptedIngredientCount = 0, State = "EMPTY", ReadyToDispense = false, ProgressPercent = 0 }
heartbeat:Fire(0.1)
check(p:GetAttribute("TutorialStage") == "Stash", "cleared previous batch resumes the current recipe")
local market = instance("Model")
market.Name, market.Parent = "Central Market", workspaceFake
local marketBase = instance("Part")
marketBase.Name, marketBase.Parent, marketBase.Position = "CentralMarketBase", market, vec(200, 0, 0)
authority.SetCash(p, 20000)
orders[3].Served = true
heartbeat:Fire(0.1)
check(p:GetAttribute("FarmTutorialStage") == "", "20K cannot start farm before opening completion")
authority.SetCash(p, 19999)
check(
    p:GetAttribute("TutorialStage") == "Market" and p:GetAttribute("TutorialActive"),
    "third serve sends player to the market"
)
root.Position = vec(175, 0, 0)
heartbeat:Fire(0.1)
check(p:GetAttribute("TutorialStage") == "Market", "market milestone waits beyond 24 studs")
root.Position = vec(176, 0, 0)
heartbeat:Fire(0.1)
check(
    p:GetAttribute("TutorialStage") == "Complete"
        and not p:GetAttribute("TutorialActive")
        and not p:GetAttribute("TutorialHintReady"),
    "reaching market completes opening guidance"
)
authority.SetCash(p, 19999)
heartbeat:Fire(0.1)
check(p:GetAttribute("FarmTutorialStage") == "", "farm phase stays idle below 20K")
authority.SetCash(p, 20000)
heartbeat:Fire(0.1)
check(p:GetAttribute("FarmTutorialStage") == "BuyRow", "owner reaching 20K starts row guidance")
authority.SetCash(p, 0)
farmRow.State = "EMPTY"
heartbeat:Fire(0.1)
advance(0.79)
check(p:GetAttribute("FarmTutorialStage") == "BuyRow", "purchase holds through row rise")
advance(0.011)
check(p:GetAttribute("FarmTutorialStage") == "Plant", "row rise completion advances planting guidance")
farmRow.State, farmRow.IngredientId = "GROWING", "Banana"
heartbeat:Fire(0.1)
check(p:GetAttribute("FarmTutorialStage") == "Done", "planted row finishes farm phase")
farmRow.State, farmRow.IngredientId = "EMPTY", nil
authority.SetCash(p, 50000)
advance(1)
check(p:GetAttribute("FarmTutorialStage") == "Done", "farm guidance never repeats within session")
authority.RemovePlayer(p)
check(p:GetAttribute("FarmTutorialStage") == "", "session loss clears farm phase")
check(
    p:GetAttribute("TutorialStage") == "ClaimPlot" and p:FindFirstChild("TutorialCustomerTarget").Value == nil,
    "abandonment clears session target"
)
resetOrders()
assignTestSession(p)
check(
    p:GetAttribute("TutorialOrderIndex") == 1 and p:GetAttribute("TutorialStage") == "Counter",
    "new session starts current orders without retaining old tutorial steps"
)
orders[1].OrderTaken = true
ingredient, carried = "Cherries", { "Cherries" }
tutorial.Mark(p, "TookStashItem")
tutorial.Mark(p, "LoadedBlender")
heartbeat:Fire(0.1)
check(p:GetAttribute("TutorialStage") == "Blender", "partial carry after LoadedBlender still targets blender")
-- Missing scenery fallback, cash already held at completion, and owner-only gating.
marketBase:Destroy()
for _, order in orders do
    order.Served = true
end
authority.SetCash(p, 20000)
heartbeat:Fire(0.1)
check(
    p:GetAttribute("TutorialStage") == "Complete" and tutorial.GetMilestones(p).ReachedMarket,
    "missing market scenery advances without blocking"
)
check(
    p:GetAttribute("FarmTutorialStage") == "BuyRow",
    "new session resets farm and starts immediately with cash held at completion"
)
local teammate = instance("Player")
teammate.Name, teammate.UserId, teammate.Parent = "Teammate", 802, workspaceFake
teammate.Character = p.Character
tutorial.AddPlayer(teammate)
setup(authority.JoinSession(teammate, p, authority.GetRequestContext(p)), "join tutorial session")
tutorial.ApplyCharacter(teammate, teammate.Character)
flush()
heartbeat:Fire(0.1)
check(teammate:GetAttribute("FarmTutorialStage") == "", "teammate with shared 20K never starts farm tutorial")
tutorial.RemovePlayer(teammate)
tutorial.RemovePlayer(p)
p.Parent = nil
advance(5)
