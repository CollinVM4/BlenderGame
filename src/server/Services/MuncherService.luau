--!strict
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.Muncher)
local WorldUtil = require(script.Parent.WorldUtil)
local MovementService = require(script.Parent.MovementService)
local Rewards = require(script.Parent.MuncherRewards)
local Output = require(script.Parent.MuncherOutput)
local WorldInput = require(script.Parent.MuncherWorldInput)
local Diagnostics = require(script.Parent.MuncherDiagnostics)
local Service = {}
local deps: any
local states: { [string]: any } = {}
local pending: { [any]: boolean } = {}
local random = Random.new()
local logCount = 0

local function log(transaction: any, result: string)
    if not Config.DebugLogging or logCount >= Config.LogLimit then
        return
    end
    logCount += 1
    print(
        string.format(
            "[Muncher] time=%.2f plot=%s input=%s value=%g tier=%d output=%s value=%g rarity=%s result=%s",
            workspace:GetServerTimeNow(),
            transaction.SessionId,
            transaction.Input,
            transaction.Value,
            transaction.Tier,
            transaction.Reward,
            transaction.OutputValue,
            transaction.Rarity,
            result
        )
    )
end

function Service.Step()
    local now = workspace:GetServerTimeNow()
    for transaction in pending do
        if now < transaction.NextAt then
            continue
        end
        local state = transaction.State
        state.Phase = "Spitting"
        transaction.Attempts += 1
        local ok, spawned = pcall(Output.Spawn, deps.IngredientService, transaction)
        if ok and spawned then
            pending[transaction] = nil
            log(transaction, "Success")
            Diagnostics.Log("RewardPublished", transaction.InputZone, transaction.Output, nil, transaction.Source)
            if state.Transaction == transaction then
                state.Transaction = nil
                state.Phase = "Idle"
                state.AvailableAt = now + Config.SpitSeconds
            end
        else
            transaction.NextAt = now
                + (if transaction.Attempts < Config.QuickRetries then Config.RetrySeconds else Config.RecoverySeconds)
            log(transaction, "SpawnRetry")
            if transaction.Attempts == Config.QuickRetries then
                warn("[Muncher] Output pending recovery for plot " .. transaction.SessionId)
            end
        end
    end
end

function Service.Init(services: any)
    deps = services
    game:GetService("RunService").Heartbeat:Connect(Service.Step)
end

function Service.Reset(player: Player)
    local id = deps.TycoonService.GetSessionId(player)
    if id then
        -- Detached committed transactions remain in the recovery queue at their captured location.
        states[id] = { Purchased = false, Revealed = false, ReadyAt = 0, Phase = "Idle", AvailableAt = 0, Sequence = 0 }
    end
end
function Service.CleanupSession(id: string)
    states[id] = nil
end
function Service.RemovePlayer(_player: Player)
    -- A consumed ingredient belongs to its committed transaction, not the actor's lifetime.
end
function Service.GetSnapshot(player: Player): any
    local id = deps.TycoonService.GetSessionId(player)
    local state = if id then states[id] else nil
    if not state then
        return nil
    end
    local transaction = state.Transaction
    return {
        Purchased = state.Purchased,
        Active = state.Revealed,
        ReadyAt = state.ReadyAt,
        Phase = state.Phase,
        AvailableAt = state.AvailableAt,
        Sequence = state.Sequence,
        StartedAt = if transaction then transaction.StartedAt else 0,
        OutputRarity = if transaction then transaction.Rarity else nil,
        Multiplier = 1,
        ExpiresAt = 0,
    }
end

-- Reuse the existing shared-cash cost/callback transaction adapter. Its name is
-- historical; it debits the plot session ledger, including for teammates.
function Service.TryPurchase(player: Player, pad: BasePart, context: any): (boolean, string?)
    local plot = deps.TycoonService.GetPlot(player)
    local model = plot and plot:FindFirstChild("Muncher")
    local id = deps.TycoonService.GetSessionId(player)
    local state = if id then states[id] else nil
    if
        not state
        or not model
        or model:FindFirstChild("PurchasePoint1") ~= pad
        or not WorldUtil.Near(player, pad, Config.FeedDistance)
    then
        return false, "InvalidPurchase"
    end
    if state.Purchased then
        return false, "AlreadyPurchased"
    end
    return deps.TycoonService.PurchasePersonalUpgrade(
        player,
        context or deps.TycoonService.GetRequestContext(player),
        Config.PurchaseCost,
        function()
            state.Purchased = true
            state.ReadyAt = workspace:GetServerTimeNow() + Config.RevealSeconds
        end
    )
end

-- Called only by the server assembly presenter after placing every part at rest.
function Service.CompleteReveal(player: Player, model: Instance): boolean
    local plot = deps.TycoonService.GetPlot(player)
    local id = deps.TycoonService.GetSessionId(player)
    local state = if id then states[id] else nil
    if
        not state
        or not plot
        or plot:FindFirstChild("Muncher") ~= model
        or not state.Purchased
        or workspace:GetServerTimeNow() < state.ReadyAt
    then
        return false
    end
    if not state.Revealed then
        local input = model:FindFirstChild("InputZone")
        if input and input:IsA("BasePart") then
            Diagnostics.Log("RevealCompleted", input, nil, nil, "Lifecycle")
        end
    end
    state.Revealed = true
    return true
end

-- Compatibility for customer payout callers; Muncher no longer grants cash buffs.
function Service.GetCashMultiplier(_player: Player): number
    return 1
end

-- UI-independent machine gate; both attraction and conversion use this state.
function Service.CanVacuum(player: Player, input: BasePart): boolean
    local id = deps.TycoonService.GetSessionId(player)
    local state = if id then states[id] else nil
    local plot = deps.TycoonService.GetPlot(player)
    local model = plot and plot:FindFirstChild("Muncher")
    return state ~= nil
        and state.Revealed
        and state.Phase == "Idle"
        and workspace:GetServerTimeNow() >= state.AvailableAt
        and model ~= nil
        and model:FindFirstChild("InputZone") == input
        and input:IsDescendantOf(workspace)
end

-- Exactly one preparation, roll, consume and commitment implementation for both sources.
function Service.TryStartConversion(
    player: Player,
    input: BasePart,
    object: Instance?,
    source: string,
    context: any
): (boolean, string?)
    if
        (source ~= "CarriedPrompt" and source ~= "WorldVacuum")
        or not Service.CanVacuum(player, input)
        or not MovementService.CanPerformGameplayAction(player)
    then
        return false, "MachineBusy"
    end
    local id = deps.TycoonService.GetSessionId(player)
    local state = states[id]
    local model = deps.TycoonService.GetPlot(player):FindFirstChild("Muncher")
    local ingredientId: string?
    if source == "CarriedPrompt" then
        if object or not WorldUtil.Near(player, input, Config.FeedDistance) then
            return false
        end
        local tools: { Instance } = if player.Character then player.Character:GetChildren() else {}
        for _, tool in tools do
            if tool:IsA("Tool") and tool:GetAttribute("IngredientId") == nil then
                return false
            end
        end
        ingredientId = deps.InventoryService.GetHeldIngredientId(player, true)
    else
        if not object then
            return false, "InvalidWorldItem"
        end
        local actor, reason, root = WorldInput.Eligible(deps, input, object)
        if actor ~= player or not root then
            return false, reason or "UnauthorizedOwner"
        end
        local distance = (root.Position - input.Position).Magnitude
        if distance > Config.Vacuum.CaptureTolerance then
            local overlaps = false
            for _, touching in workspace:GetPartsInPart(input) do
                if deps.IngredientService.Resolve(touching) == object then
                    overlaps = true
                    break
                end
            end
            if not overlaps or distance > Config.Vacuum.OverlapTolerance then
                return false, "OutsideIntake"
            end
        end
        ingredientId = deps.IngredientService.GetRecord(object).Id
    end
    if not ingredientId then
        return false, "InvalidWorldItem"
    end
    local value = Rewards.BaseValue(ingredientId, deps.IngredientService.GetDefinition(ingredientId))
    if not value then
        return false
    end
    local token = deps.TycoonService.BeginTransaction(player, context or deps.TycoonService.GetRequestContext(player))
    if not token then
        return false
    end
    local reservation = nil
    if object then
        -- Revalidate under the lifecycle lock, then claim the specific registry identity.
        local actor, reason = WorldInput.Eligible(deps, input, object)
        if actor ~= player then
            deps.TycoonService.EndTransaction(token)
            return false, reason
        end
        reservation = deps.IngredientService.Reserve(object)
        if not reservation then
            deps.TycoonService.EndTransaction(token)
            return false, "AlreadyReserved"
        end
    end
    if object then
        Diagnostics.Log("CandidateReserved", input, object)
    end
    state.Phase = "Processing"
    -- Prepare every fallible decision before removing ownership. No yield under lifecycle lock.
    local ok, transaction = pcall(function()
        local tier = Rewards.Tier(value)
        local reward = Rewards.Roll(tier, random, deps.IngredientService.GetDefinition)
        local definition = deps.IngredientService.GetDefinition(reward)
        return {
            SessionId = id,
            Source = source,
            InputZone = input,
            State = state,
            Model = model,
            At = Output.Location(model, input),
            Input = ingredientId,
            Value = value,
            Tier = tier,
            Reward = reward,
            OutputValue = definition.Value,
            Rarity = definition.Rarity or "Common",
            StartedAt = workspace:GetServerTimeNow(),
            NextAt = workspace:GetServerTimeNow() + Config.ChewSeconds,
            Attempts = 0,
        }
    end)
    if not ok then
        if object and reservation then
            deps.IngredientService.ReleaseReservation(object, reservation)
        end
        state.Phase = "Idle"
        deps.TycoonService.EndTransaction(token)
        warn("[Muncher] Invalid reward configuration: " .. tostring(transaction))
        return false
    end
    local consumed = if object
        then deps.IngredientService.Consume(object, false, reservation)
        else deps.InventoryService.ConsumeHeldIngredient(player, ingredientId, true)
    if object and reservation then
        deps.IngredientService.ReleaseReservation(object, reservation)
    end
    if consumed then
        state.Transaction = transaction
        state.Sequence += 1
        pending[transaction] = true
        if value < Config.TierMinimums[1] then
            warn("[Muncher] Positive input below Tier 1 minimum")
        end
        log(transaction, "Committed")
        if object then
            Diagnostics.Log("ConversionCommitted", input, object)
        end
    else
        state.Phase = "Idle"
    end
    deps.TycoonService.EndTransaction(token)
    return consumed ~= nil, consumed
end
function Service.TryFeed(player: Player, input: BasePart, object: Instance?, context: any): (boolean, string?)
    return Service.TryStartConversion(player, input, object, if object then "WorldVacuum" else "CarriedPrompt", context)
end
return Service
