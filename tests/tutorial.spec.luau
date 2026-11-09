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
local queue = {}
local farmRow = { State = "LOCKED", IngredientId = nil, Products = {} }
local function resetOrders()
    orders = {
        { RequestId = "Red", Served = false, OrderTaken = false },
        { RequestId = "Cold", Served = false, OrderTaken = false },
        { RequestId = "Yellow", Served = false, OrderTaken = false },
    }
end
resetOrders()
local progressByPlayer = {}
local function progress(p)
    progressByPlayer[p] = progressByPlayer[p] or { FirstServeRewarded = false, Complete = false }
    return progressByPlayer[p]
end
tutorial.Init({
    PlayerDataService = { GetTutorialState = progress },
    TycoonService = authority,
    FarmService = {
        GetRowSnapshot = function()
            return farmRow
        end,
    },
    CustomerService = {
        GetQueueSnapshot = function()
            return queue
        end,
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
    p:GetAttribute("TutorialStage") == "Stash" and p:GetAttribute("TutorialStashSlot") == 1,
    "accepted red order selects Locked Slot 1"
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
for _, ids in { { "Cherries" }, { "Cherries", "Cherries" }, { "Cherries", "Strawberry" } } do
    carried = ids
    heartbeat:Fire(0.1)
    check(p:GetAttribute("TutorialStage") == "Stash", "incomplete multiset keeps gathering without ladder guidance")
end
carried = { "Apple", "Apple", "Apple" }
heartbeat:Fire(0.1)
check(p:GetAttribute("TutorialStage") == "Ladder", "any three red ingredients satisfy the ladder pickup objective")
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
    p:GetAttribute("TutorialStage") == "Serve" and p:GetAttribute("TutorialStashSlot") == 1,
    "early stored cup reconciles with the first-order slot contract"
)
tutorial.Mark(p, "ServedCustomer")
tutorial.Mark(p, "ServedCustomer")
check(p:GetAttribute("TutorialOrderIndex") == 1, "duplicate generic milestones cannot complete scripted order")
orders[1].Served = true
progress(p).FirstServeRewarded = true
cups = {}
heartbeat:Fire(0.1)
check(p:GetAttribute("TutorialStage") == "Upgrades", "first serve offers both upgrades together")
check(p:GetAttribute("TutorialOrderIndex") == nil, "guide retires first-order targets after serve")
p:SetAttribute("JumpPurchasedLevel", 1)
heartbeat:Fire(0.1)
check(p:GetAttribute("TutorialStage") == "Upgrades", "one purchase cannot strand combined hint")
p:SetAttribute("JumpPurchasedLevel", 0)
authority.SetCash(p, 0)
advance(8)
check(p:GetAttribute("TutorialStage") == "Market", "zero cash and no purchases never block market guidance")
advance(7)
check(p:GetAttribute("TutorialStage") == "MarketJump", "market guidance advances without requiring travel")
advance(7)
check(
    p:GetAttribute("TutorialStage") == "Complete" and progress(p).Complete,
    "first serve and brief guidance complete tutorial"
)
check(not orders[2].Served and not orders[3].Served, "completion never requires introductory customers two and three")
tutorial.ApplyCharacter(p, p.Character)
flush()
check(p:GetAttribute("TutorialStage") == "Complete", "respawn retains completion")
authority.RemovePlayer(p)
check(p:GetAttribute("TutorialStage") == "Complete", "completed tutorial never resets on session loss")
resetOrders()
assignTestSession(p)
heartbeat:Fire(0.1)
check(p:GetAttribute("TutorialStage") == "Complete", "new plot respects existing personal completion")
-- A restored DataStore V1 profile will enter through the same server-owned state boundary.
tutorial.RemovePlayer(p)
tutorial.AddPlayer(p)
tutorial.ApplyCharacter(p, p.Character)
flush()
check(p:GetAttribute("TutorialStage") == "Complete", "reconstructed runtime respects completed profile")
local upgrades = loadModule("Upgrades")
check(upgrades.Jump[2].Cost + upgrades.Bat[2].Cost <= 30000, "guaranteed payout affords Jump 1 and Bat 1")
-- Preowned recommendations retire immediately, and later purchases do not restart them.
progress(p).Complete = false
tutorial.RemovePlayer(p)
tutorial.AddPlayer(p)
p:SetAttribute("JumpPurchasedLevel", 1)
p:SetAttribute("BatPurchasedLevel", 1)
tutorial.ApplyCharacter(p, p.Character)
flush()
check(p:GetAttribute("TutorialStage") == "Market", "both preowned upgrades skip recommendation")
advance(7)
advance(7)
check(progress(p).Complete, "preowned purchases also reach completion")
-- Keep owner-only farm guidance independent of optional upgrade recommendations.
authority.SetCash(p, 19999)
heartbeat:Fire(0.1)
check(p:GetAttribute("FarmTutorialStage") == "", "farm stays idle below its own price")
authority.SetCash(p, 20000)
heartbeat:Fire(0.1)
check(p:GetAttribute("FarmTutorialStage") == "BuyRow", "farm still starts after opening completion")
farmRow.State = "EMPTY"
advance(0.1)
advance(0.81)
check(p:GetAttribute("FarmTutorialStage") == "Plant", "farm planting follows row reveal")
farmRow.State, farmRow.IngredientId = "GROWING", "Banana"
heartbeat:Fire(0.1)
check(p:GetAttribute("FarmTutorialStage") == "", "growth never prematurely requests harvest")
farmRow.State, farmRow.Products = "READY", { instance("Part") }
heartbeat:Fire(0.1)
check(p:GetAttribute("FarmTutorialStage") == "Harvest", "ready production still guides harvest")
farmRow.State, farmRow.Products, farmRow.IngredientId = "EMPTY", {}, nil
heartbeat:Fire(0.1)
check(p:GetAttribute("FarmTutorialStage") == "Done", "farm completes independently")
tutorial.RemovePlayer(p)
