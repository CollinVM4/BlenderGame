-- Authoritative cross-system onboarding: real stash, queue, blender and serving.
dependency.PlayerDataService.HasEntitlement = dataService.HasEntitlement
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
for count = 1, 3 do
    setup(inventory.Withdraw(p, 1), "take real red ingredient")
end
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
    input.Overlaps = { thrown }
    setup(blend.TryInput(p, thrown, input), "real blender ingestion")
end
heartbeat:Fire(0.1)
check(p:GetAttribute("TutorialStage") == "Turbine", "three real ingredients enable turbine")
setup(blend.AddProgress(p, wheel, loadModule("Economy").RequiredProgress), "complete blend")
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
check(not customer.Serve(p, red), "replayed serve cannot pay twice")
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
advance(70)
check(customer.GetQueueSnapshot(p)[1].TutorialIndex == nil, "fourth arrival returns to normal pool")
-- A teammate may perform the first delivery; cash and the reward guard are shared.
local q = player()
q.Parent, q.Character.WaitForChild = workspaceFake, q.Character.FindFirstChild
tutorial.AddPlayer(q)
tutorial.ApplyCharacter(q, q.Character)
flush()
local teammate = player()
dependency.TycoonService.RemovePlayer(teammate)
setup(
    dependency.TycoonService.JoinSession(teammate, q, dependency.TycoonService.GetRequestContext(q)),
    "join fresh tutorial stand"
)
teammate.Parent, teammate.Character.WaitForChild = workspaceFake, teammate.Character.FindFirstChild
tutorial.AddPlayer(teammate)
tutorial.ApplyCharacter(teammate, teammate.Character)
flush()
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
