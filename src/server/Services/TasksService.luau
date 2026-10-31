--!strict
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.TasksConfig)
local HttpService = game:GetService("HttpService")
local Film = require(script.Parent.FilmingUtil)
local Service = {}
export type State = {
    Serve: {
        TotalServes: number,
        ActiveThreshold: number,
        LockedReward: number,
        LastPaidThreshold: number,
        TutorialTaskPaid: boolean,
    },
    StealProgress: number,
}
type Runtime = {
    State: State,
    Connections: { RBXScriptConnection },
    TutorialComplete: boolean,
    TutorialPending: boolean,
    Queued: boolean,
    Busy: boolean,
    LastServe: any,
}
local deps: any
local players: { [Player]: Runtime } = {}

local function nextThreshold(total: number): number
    return if total < 3 then 3 elseif total < 10 then 10 else (math.floor(total / 10) + 1) * 10
end
local function lockReward(player: Player, threshold: number, previous: number): number
    local block = if threshold == 3 then 3 elseif threshold == 10 then 7 else 10
    return math.max(Config.PerServeRate[deps.TycoonService.GetJumpTier(player)] * block, previous)
end
local function stealReward(player: Player): number
    return math.max(Config.StealMinimumReward, Config.StealCashRate * deps.TycoonService.GetCash(player))
end
local function publish(player: Player, runtime: Runtime)
    local state = runtime.State
    player:SetAttribute("TasksTutorialComplete", runtime.TutorialComplete)
    player:SetAttribute("TasksTutorialReward", Config.TutorialReward)
    player:SetAttribute("TasksServeTotal", state.Serve.TotalServes)
    player:SetAttribute("TasksServeThreshold", state.Serve.ActiveThreshold)
    player:SetAttribute("TasksServeReward", state.Serve.LockedReward)
    player:SetAttribute("TasksStealProgress", state.StealProgress)
    player:SetAttribute("TasksStealTarget", Config.StealTarget)
    player:SetAttribute("TasksStealReward", stealReward(player))
end
-- CreditTransaction returns nil on success and asserts on failure. Treat an
-- explicit false as failure too, so neither guard nor progress can consume it.
local function credit(transaction: string, reward: number): boolean
    local ok, result = pcall(deps.TycoonService.CreditTransaction, transaction, reward)
    if not ok then
        warn("[Tasks] Credit failed: " .. tostring(result))
    end
    return ok and result ~= false
end
local function feedback(player: Player, reward: number)
    Film.Emit(player, "TaskReward", { BlendId = HttpService:GenerateGUID(false), Payout = reward })
end
local function payTutorial(player: Player, runtime: Runtime)
    if not runtime.TutorialPending or runtime.Busy or runtime.State.Serve.TutorialTaskPaid then
        return
    end
    local transaction = deps.TycoonService.BeginTransaction(player, deps.TycoonService.GetRequestContext(player))
    if not transaction then
        return
    end
    runtime.Busy = true
    local paid = credit(transaction, Config.TutorialReward)
    if paid then
        runtime.State.Serve.TutorialTaskPaid = true
        runtime.TutorialPending = false
    end
    deps.TycoonService.EndTransaction(transaction)
    runtime.Busy = false
    if paid then
        feedback(player, Config.TutorialReward)
    end
end
local function queueTutorial(player: Player, runtime: Runtime)
    if runtime.Queued or not runtime.TutorialPending then
        return
    end
    runtime.Queued = true
    -- Tutorial.Mark can publish Complete inside Serve. Never nest a transaction.
    task.defer(function()
        runtime.Queued = false
        if players[player] == runtime then
            payTutorial(player, runtime)
        end
    end)
end
function Service.Init(services: any)
    deps = services
end
-- Optional authoritative session count supports activation/reconciliation only;
-- never read CustomersServed, PlayerData records, or replicated progress here.
function Service.AddPlayer(player: Player, qualifyingCount: number?)
    if players[player] then
        return
    end
    local total = qualifyingCount or 0
    local threshold = nextThreshold(total)
    local runtime: Runtime = {
        State = {
            Serve = {
                TotalServes = total,
                ActiveThreshold = threshold,
                LockedReward = lockReward(player, threshold, 0),
                LastPaidThreshold = if threshold == 3 then 0 elseif threshold == 10 then 3 else threshold - 10,
                TutorialTaskPaid = false,
            },
            StealProgress = 0,
        },
        Connections = {},
        TutorialComplete = player:GetAttribute("TutorialStage") == "Complete",
        TutorialPending = false,
        Queued = false,
        Busy = false,
        LastServe = nil,
    }
    players[player] = runtime
    table.insert(
        runtime.Connections,
        player:GetAttributeChangedSignal("TutorialStage"):Connect(function()
            local complete = player:GetAttribute("TutorialStage") == "Complete"
            if complete and not runtime.TutorialComplete and not runtime.State.Serve.TutorialTaskPaid then
                runtime.TutorialPending = true
                queueTutorial(player, runtime)
            end
            runtime.TutorialComplete = complete
            publish(player, runtime)
        end)
    )
    for _, attribute in { "playerCash", "PlotSessionId" } do
        table.insert(
            runtime.Connections,
            player:GetAttributeChangedSignal(attribute):Connect(function()
                publish(player, runtime)
                queueTutorial(player, runtime)
            end)
        )
    end
    publish(player, runtime)
end
-- event is the server-owned customer record, not the plot transaction ID (which
-- is reused). It also guards reentrant/duplicate observations of the same serve.
function Service.RecordServe(
    player: Player,
    qualifies: boolean,
    freeloader: boolean,
    transaction: string,
    event: any
): number
    local runtime = players[player]
    if not runtime or not qualifies or freeloader or runtime.Busy then
        return 0
    end
    local serve = runtime.State.Serve
    local repeated = event ~= nil and runtime.LastServe == event
    if repeated and serve.TotalServes < serve.ActiveThreshold then
        return 0
    end
    runtime.Busy = true
    if not repeated then
        serve.TotalServes += 1
        runtime.LastServe = event
    end
    local bonus = 0
    -- A failed credit retains the qualifying observation and the unpaid live
    -- crossing. A later observation/retry can settle it without counting twice.
    while serve.TotalServes >= serve.ActiveThreshold and serve.LastPaidThreshold < serve.ActiveThreshold do
        local reward = serve.LockedReward
        if not credit(transaction, reward) then
            break
        end
        bonus += reward
        serve.LastPaidThreshold = serve.ActiveThreshold
        serve.ActiveThreshold = nextThreshold(serve.ActiveThreshold)
        serve.LockedReward = lockReward(player, serve.ActiveThreshold, reward)
    end
    publish(player, runtime)
    runtime.Busy = false
    return bonus
end
function Service.RecordSteal(player: Player)
    local runtime = players[player]
    if not runtime or runtime.Busy then
        return
    end
    local state = runtime.State
    state.StealProgress += 1
    if state.StealProgress < Config.StealTarget then
        publish(player, runtime)
        return
    end
    local transaction = deps.TycoonService.BeginTransaction(player, deps.TycoonService.GetRequestContext(player))
    if not transaction then
        publish(player, runtime)
        return
    end
    runtime.Busy = true
    local paidReward = 0
    while state.StealProgress >= Config.StealTarget do
        local reward = stealReward(player)
        local cashBefore = deps.TycoonService.GetCash(player)
        if not credit(transaction, reward) then
            break
        end
        -- The cash authority applies whole-dollar rounding at credit time.
        paidReward += deps.TycoonService.GetCash(player) - cashBefore
        state.StealProgress -= Config.StealTarget
    end
    deps.TycoonService.EndTransaction(transaction)
    runtime.Busy = false
    publish(player, runtime)
    if paidReward > 0 then
        feedback(player, paidReward)
    end
end
function Service.RemovePlayer(player: Player)
    local runtime = players[player]
    players[player] = nil
    if runtime then
        for _, connection in runtime.Connections do
            connection:Disconnect()
        end
    end
end
return Service
