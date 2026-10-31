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
for _, order in config do
    local state = slot(p, order.Slot)
    check(state.Count == 3 and state.ItemType == "Ingredient", "starter stash has actual ingredient records")
    for index, id in order.Ingredients do
        check(
            state.Ingredients[index].IngredientId == id and state.Ingredients[index].ItemId ~= nil,
            "canonical starter unit retains identity"
        )
    end
end
check(slot(p, 1).Count == 0 and slot(p, 2).Count == 0, "protected slots untouched")
inventory.InitializeTutorialStash(p)
tutorial.AddPlayer(p)
customer.ActivateForPlayer(p, true)
flush()
check(
    slot(p, 3).Count == 3 and #customer.GetQueueSnapshot(p) == 1,
    "repeat initialization cannot duplicate inventory or customers"
)
local red = customer.GetQueueSnapshot(p)[1].Model
check(
    customer.GetQueueSnapshot(p)[1].RequestId == "Red",
    "first tutorial arrival is immediate and fixed despite wildcard chance"
)
advance(7.5)
check(#customer.GetQueueSnapshot(p) == 1, "normal customers cannot preempt tutorial schedule")
advance(0.5)
check(
    #customer.GetQueueSnapshot(p) == 2 and customer.GetQueueSnapshot(p)[2].RequestId == "Cold",
    "cold inserted at eight seconds"
)
advance(8)
local queue = customer.GetQueueSnapshot(p)
check(#queue == 3 and queue[3].RequestId == "Yellow", "yellow inserted at sixteen seconds within capacity")
check(
    queue[1].Ready and queue[2].Ready and queue[3].Ready,
    "all tutorial customers use normal queue movement and positions"
)
local cold, yellow = queue[2].Model, queue[3].Model
setup(customer.TakeOrder(p, red), "accept red")
setup(customer.TakeOrder(p, cold), "accept waiting cold early")
setup(customer.TakeOrder(p, yellow), "accept waiting yellow early")
heartbeat:Fire(0.1)
check(
    p:GetAttribute("TutorialStage") == "Stash" and p:GetAttribute("TutorialStashSlot") == 3,
    "red acceptance starts relevant stash"
)
local input, wheel = references[p].BlenderInput, references[p].TurbineWheel
local starterEarnings = 0
for orderIndex, order in config do
    local beforeCash = dependency.TycoonService.GetCash(p)
    loadModule("Upgrades").CarryCapacity[1].Value = if orderIndex == 1 then 3 else 1
    capacities[p] = if orderIndex == 2 then 2 else 1
    if orderIndex <= 2 then
        for count = 1, 3 do
            setup(inventory.Withdraw(p, order.Slot), "multi-carry starter TAKE")
            if orderIndex == 1 then
                heartbeat:Fire(0.1)
                check(
                    p:GetAttribute("TutorialStage") == (if count == 3 then "Ladder" else "Stash"),
                    "real red TAKE waits for all three fruits"
                )
            end
        end
    end
    for count, expectedId in order.Ingredients do
        if orderIndex > 2 then
            setup(inventory.Withdraw(p, order.Slot), "normal starter TAKE")
        end
        check(
            (
                if orderIndex == 1
                    then table.find(order.Ingredients, inventory.GetHeldIngredientId(p)) ~= nil
                    else inventory.GetHeldIngredientId(p) == expectedId
            ),
            "mixed slot withdraws each real ingredient normally"
        )
        heartbeat:Fire(0.1)
        if orderIndex == 1 and count == 1 then
            check(p:GetAttribute("TutorialStage") == "Ladder", "real stash TAKE gleams ladder next")
            movement = "Climbing"
            heartbeat:Fire(0.1)
            movement = "Running"
        end
        check(p:GetAttribute("TutorialStage") == "Blender", "carrying points at glass")
        advance(0.4)
        local thrown = inventory.ThrowHeld(p)
        setup(thrown, "throw carried ingredient")
        heartbeat:Fire(0.1)
        check(p:GetAttribute("TutorialStage") == "Blender", "throw in flight does not prematurely switch back")
        input.Overlaps = {}
        check(not blend.TryInput(p, thrown, input), "a missed throw is not an accepted ingredient")
        input.Overlaps = { thrown }
        setup(blend.TryInput(p, thrown, input), "real overlapping ingestion")
        heartbeat:Fire(0.1)
        check(
            blend.GetSnapshot(p).AcceptedIngredientCount == count,
            "batch snapshot reports authoritative accepted count"
        )
        check(
            p:GetAttribute("TutorialStage")
                == (if count == 3 then "Turbine" elseif orderIndex <= 2 then "Blender" else "Stash"),
            "only three accepted ingredients enable turbine"
        )
    end
    setup(blend.AddProgress(p, wheel, loadModule("Economy").RequiredProgress - 1), "partial blend")
    heartbeat:Fire(0.1)
    check(
        p:GetAttribute("TutorialStage") == "Turbine" and not blend.GetSnapshot(p).ReadyToDispense,
        "partial progress keeps turbine active"
    )
    setup(blend.AddProgress(p, wheel, 1), "finish batch")
    heartbeat:Fire(0.1)
    local finished = blend.GetSnapshot(p)
    check(
        finished.ReadyToDispense and finished.ProgressPercent == 100 and p:GetAttribute("TutorialStage") == "Dispenser",
        "100 percent COMPLETE enables dispenser"
    )
    local request
    for _, definition in definitions.Definitions do
        if definition.Id == order.RequestId then
            request = definition
        end
    end
    local evaluation = customer.EvaluateOrder(finished.Result, request)
    local payout = customer.CalculateOrderPayout(p, finished.Result, request, evaluation)
    check(
        evaluation.IsValid and evaluation.IsFulfilled and payout > 0,
        "exact starter combination fulfills canonical request with positive payout"
    )
    setup(blend.Dispense(p, input), "dispense real smoothie")
    flush()
    heartbeat:Fire(0.1)
    check(p:GetAttribute("TutorialStage") == "Serve", "dispensed cup guides to current customer")
    check(#inventory.GetCarriedIngredientIds(p) == 0, "carried smoothie does not count as an ingredient")
    local model = ({ red, cold, yellow })[orderIndex]
    setup(customer.Serve(p, model), "normal committed tutorial serve")
    heartbeat:Fire(0.1)
    check(
        dependency.TycoonService.GetCash(p)
            == beforeCash + math.max(payout, order.PayoutFloor or 0) + (if orderIndex == 3 then 9000 else 0),
        "payout includes tutorial floor and the locked third-serve milestone"
    )
    local earned = dependency.TycoonService.GetCash(p) - beforeCash
    starterEarnings += earned
    print(string.format("STARTER %s: $%d (cumulative $%d)", order.RequestId, earned, starterEarnings))
    if orderIndex == 1 then
        local catalog = loadModule("Upgrades")
        check(
            starterEarnings >= catalog.MovementSpeed[2].Cost + catalog.SprintStamina[2].Cost,
            "first real tutorial serve funds both first stat purchases"
        )
    end
    check(not customer.Serve(p, model), "duplicate serve cannot pay twice")
    if orderIndex < 3 then
        local track = if orderIndex == 1 then "Jump" else "Bat"
        check(p:GetAttribute("TutorialStage") == "Buy" .. track, "real serve enables funded upgrade guidance")
        setup(
            dependency.TycoonService.PurchaseUpgrade(p, track, 2, dependency.TycoonService.GetRequestContext(p)),
            "purchase tutorial upgrade through session authority"
        )
        heartbeat:Fire(0.1)
    end
    if orderIndex < 3 then
        check(
            p:GetAttribute("TutorialOrderIndex") == orderIndex + 1 and p:GetAttribute("TutorialStage") == "Stash",
            "already accepted waiting order needs no respawn"
        )
    end
end
check(
    p:GetAttribute("TutorialStage") == "NextCustomer" and p:GetAttribute("TutorialActive"),
    "all three fulfilled serves wait for next regular order"
)
check(
    p:GetAttribute("TasksServeTotal") == 3 and p:GetAttribute("TasksServeThreshold") == 10,
    "three real tutorial serves activate cumulative 3/10"
)
inventory.InitializeTutorialStash(p)
check(
    slot(p, 3).Count == 0 and slot(p, 4).Count == 0 and slot(p, 5).Count == 0,
    "depleted starters are never infinitely replenished"
)
advance(70)
check(
    #customer.GetQueueSnapshot(p) > 0
        and customer.GetQueueSnapshot(p)[1].Model:GetAttribute("TutorialOrderIndex") == nil,
    "normal always-on arrivals resume after tutorial insertion"
)
local nextCustomer = customer.GetQueueSnapshot(p)[1]
heartbeat:Fire(0.1)
check(
    p:FindFirstChild("TutorialCustomerTarget").Value == nextCustomer.Model,
    "real queue publishes next regular customer"
)
p.Character:FindFirstChild("HumanoidRootPart").Position = nextCustomer.Model:GetPivot().Position
setup(customer.TakeOrder(p, nextCustomer.Model), "take next regular order")
heartbeat:Fire(0.1)
check(p:GetAttribute("TutorialStage") == "Complete", "real order acceptance completes send-off with missing scenery")
local beforeTutorialReward = dependency.TycoonService.GetCash(p)
flush()
check(
    dependency.TycoonService.GetCash(p) == beforeTutorialReward + 5000,
    "tutorial completion pays separately on its observed transition"
)
-- First regular serves use the live payout formula with no tutorial floors.
loadModule("Upgrades").CarryCapacity[1].Value = 3
capacities[p] = 1
for serveIndex = 1, 2 do
    local regular = customer.GetQueueSnapshot(p)[1]
    setup(regular and not regular.Model:GetAttribute("TutorialOrderIndex"), "regular customer after starters")
    local ids = { "Banana", "Banana", "Banana" }
    local beforeCash = dependency.TycoonService.GetCash(p)
    setup(
        inventory.GrantSmoothie(p, { BlendId = "first-regular-" .. serveIndex, Ingredients = ids }),
        "regular smoothie"
    )
    setup(customer.Serve(p, regular.Model), "first regular serve")
    local earned = dependency.TycoonService.GetCash(p) - beforeCash
    check(earned > 0, "first regular order pays through live serving")
    print(string.format("REGULAR %d (%s): $%d", serveIndex, regular.RequestId, earned))
    flush()
end
-- Loss/rejection is recoverable and never masquerades as a successful serve.
local q = player()
q.Parent = workspaceFake
q.Character.WaitForChild = q.Character.FindFirstChild
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
check(not customer.GetTutorialSnapshot(q)[1].Served, "disappearance cannot complete tutorial")
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
check(
    slot(q, 3).Ingredients[1].ItemId ~= itemId,
    "released session retires old units before fresh tutorial initialization"
)
local teammate = player()
dependency.TycoonService.RemovePlayer(teammate)
local queueCount = #customer.GetQueueSnapshot(q)
local stashCount = slot(q, 3).Count
setup(
    dependency.TycoonService.JoinSession(teammate, q, dependency.TycoonService.GetRequestContext(q)),
    "join existing shared plot"
)
inventory.InitializeTutorialStash(teammate)
customer.ActivateForPlayer(teammate, true)
flush()
check(
    #customer.GetQueueSnapshot(q) == queueCount and slot(q, 3).Count == stashCount,
    "teammate join cannot inject more customers or starters"
)
check(
    dependency.TycoonService.GetSessionId(teammate) == dependency.TycoonService.GetSessionId(q),
    "teammate retains normal shared plot authority"
)
local outsider = player()
customer.DeactivateForPlayer(outsider)
setup(customer.ActivateForPlayer(outsider), "activate non-tutorial flow")
advance(5)
check(
    customer.GetTutorialSnapshot(outsider) == nil
        and customer.GetQueueSnapshot(outsider)[1].Model:GetAttribute("TutorialOrderIndex") == nil,
    "non-tutorial queue retains normal random arrivals"
)
tutorial.AddPlayer(outsider)
outsider.Parent = workspaceFake
outsider.Character.WaitForChild = outsider.Character.FindFirstChild
tutorial.ApplyCharacter(outsider, outsider.Character)
flush()
check(outsider:GetAttribute("TutorialStage") == "Complete", "non-tutorial plot has no onboarding gleams")
local recoverable = customer.GetQueueSnapshot(q)[1].Model
local cashBeforeDismiss = dependency.TycoonService.GetCash(q)
check(not customer.DismissCustomer(q, recoverable), "retired dismiss interaction cannot complete an order")
check(not customer.GetTutorialSnapshot(q)[1].Served, "invalid interaction preserves active tutorial request")
check(dependency.TycoonService.GetCash(q) == cashBeforeDismiss, "invalid interaction grants no payout")
setup(customer.TakeOrder(q, recoverable), "accept current replacement")
setup(inventory.Withdraw(q, 3), "take replacement recipe ingredient")
advance(0.4)
local missedThrow = inventory.ThrowHeld(q)
setup(missedThrow, "throw that will miss")
advance(4)
check(
    inventory.HasIngredientInFlight(q) and q:GetAttribute("TutorialStage") == "Blender",
    "moving throw keeps glass guidance beyond a fixed timeout"
)
missedThrow.AssemblyLinearVelocity = vec(0, 0, 0)
advance(0.5)
check(
    not inventory.HasIngredientInFlight(q) and q:GetAttribute("TutorialStage") == "Stash",
    "settled missed throw returns to ingredient gathering without acceptance"
)
setup(inventory.CarryWorldItem(q, missedThrow), "recover missed world ingredient normally")
heartbeat:Fire(0.1)
check(q:GetAttribute("TutorialStage") == "Blender", "normal pickup recovers guide without granting replacement items")

-- Guidance never locks real serving or discards a prepared next-order cup.
local bypass = player()
bypass.Parent = workspaceFake
bypass.Character.WaitForChild = bypass.Character.FindFirstChild
tutorial.AddPlayer(bypass)
tutorial.ApplyCharacter(bypass, bypass.Character)
flush()
advance(16)
local bypassQueue = customer.GetQueueSnapshot(bypass)
for index = 1, 2 do
    flush()
    setup(customer.TakeOrder(bypass, bypassQueue[index].Model), "accept order through outstanding upgrade guidance")
    setup(
        inventory.GrantSmoothie(
            bypass,
            { BlendId = "upgrade-bypass-" .. index, Ingredients = config[index].Ingredients }
        ),
        "prepare next tutorial cup normally"
    )
    local cash = dependency.TycoonService.GetCash(bypass)
    local served, reason = customer.Serve(bypass, bypassQueue[index].Model)
    setup(served, "serve succeeds during outstanding BuyJump: " .. tostring(reason))
    heartbeat:Fire(0.1)
    check(
        customer.GetTutorialSnapshot(bypass)[index].Served
            and dependency.TycoonService.GetCash(bypass) >= cash + config[index].PayoutFloor
            and #inventory.GetSmoothieInventory(bypass) == 0,
        "successful serve commits the cup and floored payout without losing the delivery"
    )
    check(bypass:GetAttribute("TutorialStage") == "BuyJump", "outstanding Jump still takes guidance priority")
end
setup(
    dependency.TycoonService.PurchaseUpgrade(bypass, "Jump", 2, dependency.TycoonService.GetRequestContext(bypass)),
    "buy Jump after both serves"
)
heartbeat:Fire(0.1)
check(bypass:GetAttribute("TutorialStage") == "BuyBat", "real Jump purchase hands guidance to funded Bat")
setup(
    dependency.TycoonService.PurchaseUpgrade(bypass, "Bat", 2, dependency.TycoonService.GetRequestContext(bypass)),
    "buy Bat after both serves"
)
heartbeat:Fire(0.1)
check(
    bypass:GetAttribute("TutorialStage") == "Order" and bypass:GetAttribute("TutorialOrderIndex") == 3,
    "real Bat purchase resumes Yellow"
)
