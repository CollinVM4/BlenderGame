--!strict
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Orders = require(Shared.Constants.TutorialOrders)
local Requests = require(Shared.Constants.CustomerRequests)
local Evaluation = require(script.Parent.CustomerOrderEvaluation)
local SmoothieItem = require(script.Parent.SmoothieItem)
local Targets = require(Shared.TutorialTargets)
local Tutorial = {}
local deps: any
type State = {
    Milestones: { [string]: boolean },
    Started: boolean,
    Stage: string,
    Plot: Instance?,
    SessionId: string?,
    Version: number,
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
local function currentTarget(player: Player, state: State): (string, number?, number?)
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
            return "Counter", index, slot
        end
        -- Reconcile early dispensing and stored cups from actual ownership.
        local request
        for _, definition in Requests.Definitions do
            if definition.Id == order.RequestId then
                request = definition
                break
            end
        end
        if request then
            for _, cup in deps.InventoryService.GetSmoothieInventory(player) do
                local evaluation = Evaluation.Evaluate(SmoothieItem.Result(cup.Data), request)
                if evaluation.IsValid and evaluation.IsFulfilled then
                    return "Serve", index, slot
                end
            end
        end
        local batch = deps.BlendService.GetSnapshot(player)
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
                and #Targets.Resolve(state.Plot, "Ladder") > 0
            then
                return "Ladder", index, slot
            end
            return "Blender", index, slot
        end
        return "Stash", index, slot
    end
    return "Complete", nil, nil
end
local function refresh(player: Player, state: State)
    if not state.Started then
        return
    end
    local plot = deps.TycoonService.GetPlot(player)
    local sessionId = deps.TycoonService.GetSessionId(player)
    if state.SessionId ~= sessionId then
        state.Milestones = {}
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
        stage, order, slot = currentTarget(player, state)
    end
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
    if state.Stage == stage and state.Plot == plot then
        return
    end
    state.Stage, state.Plot = stage, plot
    state.Version += 1
    local version = state.Version
    player:SetAttribute("TutorialHintReady", false)
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
    states[player] = { Milestones = {}, Started = false, Stage = "", Plot = nil, SessionId = nil, Version = 0 }
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
