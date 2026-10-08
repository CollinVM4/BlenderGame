--!strict
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.Muncher)
local WorldUtil = require(script.Parent.WorldUtil)
local MovementService = require(script.Parent.MovementService)
local Service = {}
local deps: any
type State = {
    Progress: number,
    Multiplier: number,
    ExpiresAt: number,
    ActiveBuff: string?,
    Purchased: boolean,
    Revealed: boolean,
    ReadyAt: number,
}
local states: { [string]: State } = {}
local nextFeed: { [Player]: number } = {}
local random = Random.new()

function Service.Init(services: any)
    deps = services
end

function Service.Reset(player: Player)
    local id = deps.TycoonService.GetSessionId(player)
    if id then
        states[id] = { Progress = 0, Multiplier = 1, ExpiresAt = 0, Purchased = false, Revealed = false, ReadyAt = 0 }
    end
end

function Service.CleanupSession(id: string)
    states[id] = nil
end

function Service.RemovePlayer(player: Player)
    nextFeed[player] = nil
end

local function activate(state: State)
    local buff = Config.Buffs[random:NextInteger(1, #Config.Buffs)]
    state.ActiveBuff = buff.Id
    state.Multiplier = buff.CashMultiplier
    state.ExpiresAt = workspace:GetServerTimeNow() + Config.BuffDuration
    state.Progress = 0
end

local function expire(state: State)
    if state.ActiveBuff and workspace:GetServerTimeNow() >= state.ExpiresAt then
        state.ActiveBuff, state.Multiplier, state.ExpiresAt = nil, 1, 0
        if state.Progress == Config.Required then
            activate(state)
        end
    end
end

function Service.GetSnapshot(player: Player): any
    local id = deps.TycoonService.GetSessionId(player)
    local state = if id then states[id] else nil
    if not state then
        return nil
    end
    expire(state)
    return {
        Progress = state.Progress,
        Target = Config.Required,
        Multiplier = state.Multiplier,
        ExpiresAt = state.ExpiresAt,
        ActiveBuff = state.ActiveBuff,
        BuffExpiresAt = state.ExpiresAt,
        Purchased = state.Purchased,
        Active = state.Revealed,
        ReadyAt = state.ReadyAt,
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
    state.Revealed = true
    return true
end

function Service.GetCashMultiplier(player: Player): number
    local snapshot = Service.GetSnapshot(player)
    return if snapshot then snapshot.Multiplier else 1
end

local function inputFor(player: Player): BasePart?
    local plot = deps.TycoonService.GetPlot(player)
    local muncher = plot and plot:FindFirstChild("Muncher")
    local input = muncher and muncher:FindFirstChild("InputZone")
    return if input and input:IsA("BasePart") then input else nil
end

local function advance(state: State)
    state.Progress += 1
    if state.Progress == Config.Required and not state.ActiveBuff then
        activate(state)
    end
end

-- Both intake paths commit synchronously under the plot's existing lifecycle lock.
-- Returns only cosmetic data after authoritative removal has succeeded.
function Service.TryFeed(player: Player, input: BasePart, object: Instance?, context: any): (boolean, string?, CFrame?)
    local id = deps.TycoonService.GetSessionId(player)
    local state = if id then states[id] else nil
    if state then
        expire(state)
    end
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if
        not state
        or not state.Revealed
        or state.Progress >= Config.Required
        or inputFor(player) ~= input
        or not MovementService.CanPerformGameplayAction(player)
        or not humanoid
        or humanoid.Health <= 0
    then
        return false
    end
    local ingredientId: string?
    local at: CFrame?
    if object then
        local record = deps.IngredientService.GetRecord(object)
        local part = WorldUtil.Part(object)
        if
            not record
            or not part
            or object:GetAttribute("FrozenUntilPickup") == true
            or (record.Owner ~= nil and record.Owner ~= player)
            or (record.Owner == nil and not record.Claimable)
            or not deps.IngredientService.GetDefinition(record.Id)
        then
            return false
        end
        local overlaps = false
        for _, touching in workspace:GetPartsInPart(input) do
            if deps.IngredientService.Resolve(touching) == object then
                overlaps = true
                break
            end
        end
        if not overlaps then
            return false
        end
        ingredientId, at = record.Id, part.CFrame
    else
        if
            not WorldUtil.Near(player, input, Config.FeedDistance)
            or workspace:GetServerTimeNow() < (nextFeed[player] or 0)
        then
            return false
        end
        ingredientId = deps.InventoryService.GetHeldIngredientId(player)
        if not ingredientId or not deps.IngredientService.GetDefinition(ingredientId) then
            return false
        end
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        at = if root and root:IsA("BasePart") then root.CFrame * CFrame.new(0, 4, 0) else input.CFrame
    end
    local token = deps.TycoonService.BeginTransaction(player, context or deps.TycoonService.GetRequestContext(player))
    if not token then
        return false
    end
    local consumed = if object
        then deps.IngredientService.Consume(object)
        else deps.InventoryService.ConsumeHeldIngredient(player, ingredientId)
    if consumed then
        advance(state)
        if not object then
            nextFeed[player] = workspace:GetServerTimeNow() + Config.FeedCooldown
        end
    end
    deps.TycoonService.EndTransaction(token)
    return consumed ~= nil, consumed, at
end

return Service
