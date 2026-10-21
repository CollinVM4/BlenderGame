--!strict
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Orders = require(Shared.Constants.TutorialOrders)
local Requests = require(Shared.Constants.CustomerRequests)
local Evaluation = require(script.Parent.CustomerOrderEvaluation)
local SmoothieItem = require(script.Parent.SmoothieItem)
local Targets = require(Shared.TutorialTargets)
local FarmConfig = require(Shared.Constants.FarmConfig)
local Tutorial = {}
local deps: any
type State = {
    Milestones: { [string]: boolean },
    Started: boolean,
    Stage: string,
    Plot: Instance?,
    SessionId: string?,
    Version: number,
    OrderIndex: number?,
    BatchOrders: { [number]: number },
    FarmStep: number,
    RowPurchasedAt: number?,
}
local states: { [Player]: State } = {}
local function climbedOwnLadder(player: Player, plot: Instance?): boolean
    local character = player.Character
    local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
    local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
    if
        not humanoid
        or humanoid.Health <= 0
        or not root
        or not root:IsA("BasePart")
        or humanoid:GetState() ~= Enum.HumanoidStateType.Climbing
    then
        return false
    end
    for _, ladder in Targets.Resolve(plot, "Ladder") do
        local parts = ladder:GetDescendants()
        table.insert(parts, ladder)
        for _, part in parts do
            if part:IsA("TrussPart") then
                local point = part.CFrame:PointToObjectSpace(root.Position)
                local half = part.Size * 0.5
                local distance = (point - Vector3.new(
                    math.clamp(point.X, -half.X, half.X),
                    math.clamp(point.Y, -half.Y, half.Y),
                    math.clamp(point.Z, -half.Z, half.Z)
                )).Magnitude
                if distance <= 6 then
                    return true
                end
            end
        end
    end
    return false
end
local function currentTarget(player: Player, state: State, plot: Instance): (string, number?, number?)
    local orders = deps.CustomerService.GetTutorialSnapshot(player)
    if not orders then
        return "Complete", nil, nil
    end
    for index, order in orders do
        if order.Served then
            continue
        end
        local slot = Orders[index].Slot
        if not order.OrderTaken then
            if index == 1 and not state.Milestones.ReachedCounter then
                local character = player.Character
                local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
                local counter = Targets.Resolve(plot, "Counter")[1]
                if counter and counter:IsA("BasePart") and root and root:IsA("BasePart") then
                    if (root.Position - counter.Position).Magnitude <= 16 then
                        state.Milestones.ReachedCounter = true
                    end
                elseif #Targets.Resolve(plot, "Counter") == 0 then
                    -- Missing scenery must not block the real order interaction.
                    state.Milestones.ReachedCounter = true
                end
                if not state.Milestones.ReachedCounter then
                    return "Counter", index, slot
                end
            end
            return "Order", index, slot
        end
        -- Reconcile early dispensing and stored cups from actual ownership.
        local request
        for _, definition in Requests.Definitions do
            if definition.Id == order.RequestId then
                request = definition
                break
            end
        end
        local batch = deps.BlendService.GetSnapshot(player)
        if
            batch
            and batch.BatchId
            and batch.AcceptedIngredientCount > 0
            and state.BatchOrders[batch.BatchId] == nil
        then
            state.BatchOrders[batch.BatchId] = index
        end
        if request then
            for _, cup in deps.InventoryService.GetSmoothieInventory(player) do
                local evaluation = Evaluation.Evaluate(SmoothieItem.Result(cup.Data), request)
                if evaluation.IsValid and evaluation.IsFulfilled then
                    return "Serve", index, slot
                end
            end
        end
        if batch and batch.BatchId and batch.AcceptedIngredientCount > 0 then
            local batchOrder = state.BatchOrders[batch.BatchId]
            if batchOrder ~= index then
                local prepared = if request and batch.Ingredients
                    then Evaluation.Evaluate(
                        SmoothieItem.Result({ BlendId = tostring(batch.BatchId), Ingredients = batch.Ingredients }),
                        request
                    )
                    else nil
                if prepared and prepared.IsValid and prepared.IsFulfilled then
                    state.BatchOrders[batch.BatchId] = index
                else
                    -- Clear an old full batch through normal gameplay without crediting
                    -- its ingredients to the new order or stranding a full blender.
                    if batch.State ~= "DISPENSED" then
                        if batch.ReadyToDispense and batch.ProgressPercent >= 100 then
                            return "DrainBatch", index, slot
                        elseif batch.AcceptedIngredientCount >= 3 then
                            return "FinishBatch", index, slot
                        end
                    end
                    batch = nil
                end
            end
        end
        if batch and batch.ReadyToDispense and batch.ProgressPercent >= 100 then
            return "Dispenser", index, slot
        end
        if batch and batch.AcceptedIngredientCount >= 3 and batch.State ~= "DISPENSED" then
            return "Turbine", index, slot
        end
        if deps.InventoryService.HasIngredientInFlight(player) then
            return "Blender", index, slot
        end
        if deps.InventoryService.HasCarriedIngredient(player) then
            if
                state.Milestones.TookStashItem
                and not state.Milestones.UsedLadder
                and not state.Milestones.LoadedBlender
                and (not batch or batch.AcceptedIngredientCount == 0)
                and #Targets.Resolve(plot, "Ladder") > 0
            then
                local carried: { [string]: number } = {}
                for _, id in deps.InventoryService.GetCarriedIngredientIds(player) do
                    carried[id] = (carried[id] or 0) + 1
                end
                for _, id in Orders[index].Ingredients do
                    if (carried[id] or 0) == 0 then
                        return "Stash", index, slot
                    end
                    carried[id] -= 1
                end
                return "Ladder", index, slot
            end
            return "Blender", index, slot
        end
        return "Stash", index, slot
    end
    if not state.Milestones.ReachedMarket then
        local market = Targets.Resolve(plot, "Market")[1]
        local root = if player.Character then player.Character:FindFirstChild("HumanoidRootPart") else nil
        if not market then
            state.Milestones.ReachedMarket = true -- Missing scenery must never block progress.
        elseif market:IsA("BasePart") and root and root:IsA("BasePart") then
            state.Milestones.ReachedMarket = (root.Position - market.Position).Magnitude <= 24
        end
        if not state.Milestones.ReachedMarket then
            return "Market", nil, nil
        end
    end
    return "Complete", nil, nil
end
-- Ordered, server-owned follow-up steps. Opening presentation completion is independent.
local farmSteps = {
    {
        Stage = "BuyRow",
        Complete = function(state: State, row: any): boolean
            if not row or row.State == "LOCKED" then
                return false
            end
            state.RowPurchasedAt = state.RowPurchasedAt or os.clock()
            return os.clock() - (state.RowPurchasedAt :: number) >= FarmConfig.RevealSeconds
        end,
    },
    {
        Stage = "Plant",
        Complete = function(_state: State, row: any): boolean
            return row ~= nil and row.IngredientId ~= nil
        end,
    },
}
local function refreshFarm(player: Player, state: State, plot: Instance?, stage: string)
    if not plot or not state.SessionId or deps.TycoonService.GetSessionOwner(state.SessionId) ~= player then
        player:SetAttribute("FarmTutorialStage", "")
        return
    end
    if state.FarmStep == 0 and stage == "Complete" and deps.TycoonService.GetCash(player) >= 20000 then
        state.FarmStep = 1
    end
    local step = farmSteps[state.FarmStep]
    if step then
        local row = deps.FarmService.GetRowSnapshot(plot, 1)
        if step.Complete(state, row) then
            state.FarmStep += 1
        end
    end
    local current = farmSteps[state.FarmStep]
    player:SetAttribute(
        "FarmTutorialStage",
        if current then current.Stage elseif state.FarmStep > 0 then "Done" else ""
    )
end
local function refresh(player: Player, state: State)
    if not state.Started then
        return
    end
    local plot = deps.TycoonService.GetPlot(player)
    local sessionId = deps.TycoonService.GetSessionId(player)
    if state.SessionId ~= sessionId then
        state.Milestones = {}
        state.BatchOrders = {}
        state.FarmStep, state.RowPurchasedAt = 0, nil
        state.SessionId = sessionId
        player:SetAttribute("TutorialTookStashItem", false)
    end
    local stage: string = "ClaimPlot"
    local order: number? = nil
    local slot: number? = nil
    if plot then
        if state.Stage == "Ladder" and climbedOwnLadder(player, plot) then
            state.Milestones.UsedLadder = true
        end
        stage, order, slot = currentTarget(player, state, plot)
    end
    refreshFarm(player, state, plot, stage)
    player:SetAttribute("TutorialOrderIndex", order)
    player:SetAttribute("TutorialStashSlot", slot)
    local target = player:FindFirstChild("TutorialCustomerTarget")
    if not target then
        local created = Instance.new("ObjectValue")
        created.Name = "TutorialCustomerTarget"
        created.Parent = player
        target = created
    end
    if target and target:IsA("ObjectValue") then
        local orders = if plot then deps.CustomerService.GetTutorialSnapshot(player) else nil
        target.Value = if orders and order then orders[order].Model else nil
    end
    if state.Stage == stage and state.Plot == plot and state.OrderIndex == order then
        return
    end
    state.Stage, state.Plot = stage, plot
    state.OrderIndex = order
    state.Version += 1
    local version = state.Version
    if stage == "ClaimPlot" or stage == "Complete" then
        player:SetAttribute("TutorialHintReady", false)
    end
    player:SetAttribute("TutorialStage", stage)
    player:SetAttribute("TutorialActive", stage ~= "Complete")
    if stage == "ClaimPlot" then
        task.delay(4.5, function()
            if states[player] == state and state.Version == version and player.Parent ~= nil then
                refresh(player, state)
                if state.Version == version then
                    player:SetAttribute("TutorialHintReady", true)
                end
            end
        end)
    elseif stage ~= "Complete" then
        player:SetAttribute("TutorialHintReady", true)
    end
end
function Tutorial.AddPlayer(player: Player)
    if states[player] then
        return
    end
    states[player] = {
        Milestones = {},
        Started = false,
        Stage = "",
        Plot = nil,
        SessionId = nil,
        Version = 0,
        OrderIndex = nil,
        BatchOrders = {},
        FarmStep = 0,
        RowPurchasedAt = nil,
    }
    player:SetAttribute("FarmTutorialStage", "")
    player:SetAttribute("TutorialActive", false)
    player:SetAttribute("TutorialStage", "ClaimPlot")
    player:SetAttribute("TutorialTookStashItem", false)
    player:SetAttribute("TutorialHintReady", false)
end
-- Compatibility telemetry only. Progress comes from live gameplay state.
function Tutorial.Mark(player: Player, milestone: string)
    local state = states[player]
    if not state then
        return
    end
    state.Milestones[milestone] = true
    if milestone == "TookStashItem" then
        player:SetAttribute("TutorialTookStashItem", true)
    end
    refresh(player, state)
end
function Tutorial.GetMilestones(player: Player): { [string]: boolean }
    local state = states[player]
    return if state then table.clone(state.Milestones) else {}
end
function Tutorial.MembershipChanged(player: Player)
    local state = states[player]
    if state then
        refresh(player, state)
    end
end
function Tutorial.ApplyCharacter(player: Player, character: Model)
    task.spawn(function()
        local root = character:WaitForChild("HumanoidRootPart", 10)
        if root and player.Character == character and player.Parent ~= nil then
            local state = states[player]
            if state then
                state.Started = true
                refresh(player, state)
            end
        end
    end)
end
function Tutorial.RemovePlayer(player: Player)
    states[player] = nil
end
function Tutorial.Init(services: any)
    deps = services
    local elapsed = 0
    RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed < 0.1 then
            return
        end
        elapsed = 0
        for player, state in states do
            refresh(player, state)
        end
    end)
end
return Tutorial
