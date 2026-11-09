-- Authoritative cross-system onboarding: real stash, queue, blender and serving.
dependency.PlayerDataService.HasEntitlement = dataService.HasEntitlement
dependency.PlayerDataService.IsDoubleCashActive = dataService.IsDoubleCashActive
dependency.CustomerService = customer
shared.TutorialTargets = "TutorialTargets"
env.Enum.HumanoidStateType = { Climbing = "Climbing" }
local timers = {}
env.task.delay = function(seconds, fn)
    table.insert(timers, { At = now + seconds, Run = fn })
end
env.math = table.clone(math)
env.math.random = function(low)
    return low or 0
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
local tasks = loadModule("TasksService")
tasks.Init(dependency)
dependency.TasksService = tasks
local tutorial = loadModule("TutorialService")
dependency.TutorialService = tutorial
dependency.FarmService = {
    GetRowSnapshot = function()
        return nil
    end,
}
tutorial.Init(dependency)
dependency.TycoonService.Init({
    SessionStarted = function(p)
        blend.Reset(p)
        inventory.InitializeTutorialStash(p)
        customer.ActivateForPlayer(p, true)
    end,
    MemberChanged = tutorial.MembershipChanged,
    MemberRemoved = tutorial.MembershipChanged,
    SessionEnded = function(id)
        inventory.CleanupSession(id)
        customer.CleanupSession(id)
        blend.CleanupSession(id)
    end,
})
local definitions = loadModule("CustomerRequests")
definitions.RegularWildcardChance, definitions.SpecialWildcardChance = 1, 1
local p, humanoid = player()
local ladder = instance("Model")
ladder.Name, ladder.Parent = "Ladder", dependency.TycoonService.GetPlot(p)
local truss = instance("TrussPart")
truss.Parent, truss.Size = ladder, vec(2, 20, 2)
truss.CFrame.PointToObjectSpace = function(self, point)
    return point - self.Position
end
local movement = "Running"
humanoid.GetState = function()
    return movement
end
p.Parent = workspaceFake
p.Character.WaitForChild = p.Character.FindFirstChild
tutorial.AddPlayer(p)
local setAttribute = p.SetAttribute
p.SetAttribute = function(self, name, value)
    local previous = self:GetAttribute(name)
    setAttribute(self, name, value)
    if previous ~= value then
        self:GetAttributeChangedSignal(name):Fire()
    end
end
tasks.AddPlayer(p)
tutorial.ApplyCharacter(p, p.Character)
flush()
local config = loadModule("TutorialOrders")
local order = config[1]
check(order.Slot == 1 and slot(p, 1).Count == 3, "first recipe uses Locked Slot 1 contract")
local queue = customer.GetQueueSnapshot(p)
check(#queue == 1 and queue[1].RequestId == "Red", "first arrival is simple Red despite wildcard chance")
local red = queue[1].Model
setup(customer.TakeOrder(p, red), "take first red order")
heartbeat:Fire(0.1)
check(
    p:GetAttribute("TutorialStage") == "Stash" and p:GetAttribute("TutorialStashSlot") == 1,
    "first order guides Locked Slot 1"
)
local starterIds = {}
for _, unit in slot(p, 1).Ingredients do
    starterIds[unit.ItemId] = unit.IngredientId
end
inventory.AddPlayer(p)
setup(inventory.InitializeTutorialStash(p), "repeat starter initialization")
setup(customer.ActivateForPlayer(p, true), "repeat queue initialization")
check(
    #customer.GetQueueSnapshot(p) == 1 and customer.GetQueueSnapshot(p)[1].Model == red,
    "ordinary initialization preserves the current customer"
)
for count = 1, 3 do
    setup(press(p, "TAKE", 1), "take real red ingredient through stash interaction")
    heartbeat:Fire(0.1)
    check(
        slot(p, 1).Count == 3 - count and #inventory.GetCarriedIngredientIds(p) == count,
        "TAKE moves one starter unit into actual inventory"
    )
    check(
        p:GetAttribute("TutorialStage") == (if count == 3 then "Ladder" else "Stash"),
        "ladder guidance waits for all three valid red ingredients"
    )
end
inventory.InitializeTutorialStash(p)
check(slot(p, 1).Count == 0, "initialization cannot replace withdrawn tutorial ingredients")
movement = "Climbing"
heartbeat:Fire(0.1)
movement = "Running"
local input, wheel = references[p].BlenderInput, references[p].TurbineWheel
for count = 1, 3 do
    advance(0.4)
    local thrown = inventory.ThrowHeld(p)
    setup(thrown, "throw ingredient")
    heartbeat:Fire(0.1)
    check(p:GetAttribute("TutorialStage") == "Blender", "in-flight guidance stays on blender")
    input.Overlaps = {}
    check(
        not blend.TryInput(p, thrown, input) and blend.GetSnapshot(p).AcceptedIngredientCount == count - 1,
        "missed throw cannot advance authoritative batch"
    )
    local unit = ingredients.GetRecord(thrown)
    check(starterIds[unit.Item.ItemId] == unit.Id, "thrown unit retains canonical starter identity")
    input.Overlaps = { thrown }
    setup(blend.TryInput(p, thrown, input), "real blender ingestion")
    heartbeat:Fire(0.1)
    check(blend.GetSnapshot(p).AcceptedIngredientCount == count, "each real ingestion advances batch once")
    check(not blend.TryInput(p, thrown, input), "consumed world unit cannot enter batch twice")
    check(
        p:GetAttribute("TutorialStage") == (if count == 3 then "Turbine" else "Blender"),
        "only three accepted units enable turbine"
    )
end
heartbeat:Fire(0.1)
check(p:GetAttribute("TutorialStage") == "Turbine", "three real ingredients enable turbine")
setup(blend.AddProgress(p, wheel, loadModule("Economy").RequiredProgress - 1), "partial blend")
heartbeat:Fire(0.1)
check(
    p:GetAttribute("TutorialStage") == "Turbine" and not blend.GetSnapshot(p).ReadyToDispense,
    "partial blending cannot unlock dispenser"
)
setup(blend.AddProgress(p, wheel, 1), "complete blend")
heartbeat:Fire(0.1)
check(p:GetAttribute("TutorialStage") == "Dispenser", "finished blend enables dispenser")
setup(blend.Dispense(p, input), "dispense real cup")
flush()
heartbeat:Fire(0.1)
check(p:GetAttribute("TutorialStage") == "Serve", "real cup enables serve guidance")
local before = dependency.TycoonService.GetCash(p)
setup(customer.Serve(p, red), "serve red")
heartbeat:Fire(0.1)
check(
    dependency.TycoonService.GetCash(p) - before == 30000,
    "first successful red serve totals exactly floor at base economy"
)
local afterServe = dependency.TycoonService.GetCash(p)
check(
    not customer.Serve(p, red) and dependency.TycoonService.GetCash(p) == afterServe,
    "replayed serve cannot pay twice"
)
check(p:GetAttribute("TasksServeTotal") == 1, "first tutorial serve counts once for serve task")
check(#inventory.GetSmoothieInventory(p) == 0, "successful serve consumes the actual dispensed cup")
check(p:GetAttribute("TutorialStage") == "Upgrades", "first serve offers optional combined upgrades")
advance(8)
check(p:GetAttribute("TutorialStage") == "Market", "no purchases needed for Market")
queue = customer.GetQueueSnapshot(p)
check(
    queue[1].RequestId == "Cold" and queue[1].Model:GetAttribute("CustomerId") == nil,
    "second position is easy standard Cold"
)
advance(7)
check(p:GetAttribute("TutorialStage") == "MarketJump", "Market proceeds to higher-ingredient guidance")
advance(7)
check(p:GetAttribute("TutorialStage") == "Complete", "opening completes without serving second or third")
queue = customer.GetQueueSnapshot(p)
check(
    queue[2].RequestId == "Caseoh" and queue[2].Model:GetAttribute("CustomerId") == "caseoh",
    "third position uses canonical special despite unpurchased Jump"
)
check(queue[2].Model:FindFirstChild("Head") ~= nil, "CaseOh retains imported avatar art")
-- Both waiting introductory customers keep computed payouts, without floors.
for index, ids in { { "Ice", "Ice", "Ice" }, { "Hamburger", "Chili_Pepper", "Hamburger" } } do
    local entry = queue[index]
    flush()
    setup(customer.TakeOrder(p, entry.Model), "take waiting introductory order")
    local cupData = { BlendId = "normal-intro-" .. index, Ingredients = ids }
    setup(inventory.GrantSmoothie(p, cupData), "grant prepared introductory cup")
    local request
    for _, definition in definitions.Definitions do
        if definition.Id == entry.RequestId then
            request = definition
        end
    end
    local result = loadModule("SmoothieItem").Result(cupData)
    local evaluation = customer.EvaluateOrder(result, request)
    local expected = customer.CalculateOrderPayout(p, result, request, evaluation)
    before = dependency.TycoonService.GetCash(p)
    setup(customer.Serve(p, entry.Model), "serve waiting introductory customer")
    check(
        dependency.TycoonService.GetCash(p) - before == expected + (if index == 2 then 9000 else 0),
        "intro two and three retain computed payout and independent third-serve task reward"
    )
end
check(
    p:GetAttribute("TasksServeTotal") == 3 and p:GetAttribute("TasksServeThreshold") == 10,
    "three ordinary serves progress the task to 3/10 without gating tutorial completion"
)
advance(70)
check(customer.GetQueueSnapshot(p)[1].TutorialIndex == nil, "fourth arrival returns to normal pool")
-- A teammate may perform the first delivery; cash and the reward guard are shared.
local q = player()
q.Parent, q.Character.WaitForChild = workspaceFake, q.Character.FindFirstChild
tutorial.AddPlayer(q)
tutorial.ApplyCharacter(q, q.Character)
flush()
local missing = customer.GetQueueSnapshot(q)[1].Model
missing:Destroy()
advance(0.5)
local replacement = customer.GetQueueSnapshot(q)[1]
check(
    replacement and replacement.Model ~= missing and replacement.RequestId == "Red",
    "destroyed tutorial customer replaced through normal queue"
)
check(
    not customer.GetTutorialSnapshot(q)[1].Served and not dataService.GetTutorialState(q).Complete,
    "disappearance cannot complete tutorial"
)
local cashBeforeStale = dependency.TycoonService.GetCash(q)
check(
    not customer.TakeOrder(q, missing)
        and not customer.Serve(q, missing)
        and dependency.TycoonService.GetCash(q) == cashBeforeStale,
    "disappeared customer rejects stale interactions without payout"
)
setup(customer.TakeOrder(q, replacement.Model), "accept replacement")
inventory.GrantSmoothie(q, { BlendId = "bad-red", Ingredients = { "Banana", "Banana", "Banana" } })
setup(customer.Serve(q, replacement.Model), "normal unfulfilled delivery")
advance(0.5)
check(
    customer.GetQueueSnapshot(q)[1].RequestId == "Red" and not customer.GetTutorialSnapshot(q)[1].Served,
    "unfulfilled serve recovers same request without advancing"
)
local sessionBefore = dependency.TycoonService.GetSessionId(q)
local itemId = slot(q, 3).Ingredients[1].ItemId
inventory.CleanupCharacter(q)
local respawned = instance("Model")
part("HumanoidRootPart", respawned)
local respawnHumanoid = instance("Humanoid")
respawnHumanoid.Parent, respawnHumanoid.Health = respawned, 100
respawned.WaitForChild = respawned.FindFirstChild
q.Character = respawned
tutorial.ApplyCharacter(q, q.Character)
customer.ActivateForPlayer(q, true)
flush()
check(
    dependency.TycoonService.GetSessionId(q) == sessionBefore
        and slot(q, 3).Ingredients[1].ItemId == itemId
        and #customer.GetQueueSnapshot(q) == 1,
    "respawn and reconstruction preserve session items and queue"
)
local ownPlot = dependency.TycoonService.GetPlot(q)
dependency.TycoonService.RemovePlayer(q)
check(p:GetAttribute("TutorialStage") == "Complete", "other plot progress remains independent")
setup(dependency.TycoonService.AssignPlot(q, ownPlot), "reclaim plot")
flush()
check(
    dependency.TycoonService.GetSessionId(q) ~= sessionBefore and #customer.GetQueueSnapshot(q) == 1,
    "reassignment creates exactly one fresh tutorial queue"
)
check(slot(q, 3).Ingredients[1].ItemId == itemId, "reclaimed session restores persisted units without another grant")
check(
    not dataService.GetTutorialState(q).Complete and not dataService.GetTutorialState(q).FirstServeRewarded,
    "membership publication before queue setup cannot spend completion or first-serve state"
)
local teammate = player()
dependency.TycoonService.RemovePlayer(teammate)
local sharedCustomer = customer.GetQueueSnapshot(q)[1].Model
local sharedItem = slot(q, 1).Ingredients[1].ItemId
setup(
    dependency.TycoonService.JoinSession(teammate, q, dependency.TycoonService.GetRequestContext(q)),
    "join fresh tutorial stand"
)
teammate.Parent, teammate.Character.WaitForChild = workspaceFake, teammate.Character.FindFirstChild
tutorial.AddPlayer(teammate)
tutorial.ApplyCharacter(teammate, teammate.Character)
flush()
check(not inventory.InitializeTutorialStash(teammate), "teammate cannot reseed owner stash")
setup(customer.ActivateForPlayer(teammate, true), "teammate activation reuses queue")
check(
    #customer.GetQueueSnapshot(q) == 1
        and customer.GetQueueSnapshot(q)[1].Model == sharedCustomer
        and slot(q, 1).Ingredients[1].ItemId == sharedItem,
    "teammate join preserves shared customer and starter units"
)
local first = customer.GetQueueSnapshot(q)[1].Model
setup(customer.TakeOrder(teammate, first), "teammate takes first order")
setup(
    inventory.GrantSmoothie(teammate, { BlendId = "shared-first", Ingredients = order.Ingredients }),
    "teammate holds red smoothie"
)
before = dependency.TycoonService.GetCash(q)
setup(customer.Serve(teammate, first), "teammate serves first order")
heartbeat:Fire(0.1)
check(
    dependency.TycoonService.GetCash(q) == before + 30000
        and dependency.TycoonService.GetCash(teammate) == before + 30000,
    "one floor credited to shared balance"
)
check(not customer.Serve(q, first), "owner cannot repeat teammate reward")
check(
    dataService.GetTutorialState(q).FirstServeRewarded and dataService.GetTutorialState(teammate).FirstServeRewarded,
    "both profiles retain first-serve state for future persistence"
)
check(
    q:GetAttribute("TutorialStage") == "Upgrades" and teammate:GetAttribute("TutorialStage") == "Upgrades",
    "both teammates receive optional recommendations"
)
setup(
    dependency.TycoonService.PurchaseUpgrade(teammate, "Bat", 2, dependency.TycoonService.GetRequestContext(teammate)),
    "teammate buys Bat first"
)
advance(8)
check(
    q:GetAttribute("TutorialStage") == "Market" and teammate:GetAttribute("TutorialStage") == "Market",
    "one purchase never blocks either teammate"
)
advance(7)
advance(7)
check(
    dataService.GetTutorialState(q).Complete and dataService.GetTutorialState(teammate).Complete,
    "both complete while customers two and three remain unserved"
)
-- Runtime reinitialization respects an already-completed memory profile.
dataService.AddPlayer(teammate)
check(dataService.GetTutorialState(teammate).Complete, "duplicate data initialization preserves completed tutorial")
local snapshot = dataService.GetSnapshot(teammate)
snapshot.Tutorial.Complete = false
check(dataService.GetTutorialState(teammate).Complete, "snapshots cannot mutate authoritative completion")
tutorial.RemovePlayer(teammate)
tutorial.AddPlayer(teammate)
tutorial.ApplyCharacter(teammate, teammate.Character)
flush()
check(teammate:GetAttribute("TutorialStage") == "Complete", "returning runtime never resets a completed tutorial")

-- Loss and an unfulfilled delivery retry Red without completing or paying the floor.
local retry = player()
retry.Parent, retry.Character.WaitForChild = workspaceFake, retry.Character.FindFirstChild
tutorial.AddPlayer(retry)
tutorial.ApplyCharacter(retry, retry.Character)
flush()
local lost = customer.GetQueueSnapshot(retry)[1].Model
lost:Destroy()
advance(0.5)
local replacement = customer.GetQueueSnapshot(retry)[1]
check(replacement.Model ~= lost and replacement.RequestId == "Red", "lost first customer is replaced with Red")
setup(customer.TakeOrder(retry, replacement.Model), "take replacement Red")
setup(
    inventory.GrantSmoothie(retry, { BlendId = "wrong-red", Ingredients = { "Banana", "Banana", "Banana" } }),
    "wrong red cup"
)
setup(customer.Serve(retry, replacement.Model), "deliver unfulfilled order")
advance(0.5)
check(
    not dataService.GetTutorialState(retry).FirstServeRewarded and not dataService.GetTutorialState(retry).Complete,
    "unfulfilled first serve never spends reward or completion"
)
replacement = customer.GetQueueSnapshot(retry)[1]
check(replacement.RequestId == "Red", "unfulfilled Red is retried")
setup(customer.TakeOrder(retry, replacement.Model), "take retry Red")
setup(inventory.GrantSmoothie(retry, { BlendId = "valid-retry", Ingredients = order.Ingredients }), "valid retry cup")
before = dependency.TycoonService.GetCash(retry)
setup(customer.Serve(retry, replacement.Model), "fulfill retry Red")
check(dependency.TycoonService.GetCash(retry) - before == 30000, "first successful retry still receives floor once")

-- Serving keeps working while optional recommendations are visible.
advance(7)
local waitingCold
for _, entry in customer.GetQueueSnapshot(retry) do
    if entry.RequestId == "Cold" then
        waitingCold = entry.Model
    end
end
setup(waitingCold and customer.TakeOrder(retry, waitingCold), "take Cold during optional recommendations")
setup(
    inventory.GrantSmoothie(retry, { BlendId = "optional-cold", Ingredients = { "Ice", "Ice", "Ice" } }),
    "prepare Cold during recommendations"
)
check(retry:GetAttribute("TutorialStage") == "Upgrades", "recommendations remain visible before timeout")
setup(customer.Serve(retry, waitingCold), "serve Cold through optional guidance")
check(
    retry:GetAttribute("TutorialStage") == "Upgrades" and #inventory.GetSmoothieInventory(retry) == 0,
    "guidance never blocks serving or discards a prepared delivery"
)
