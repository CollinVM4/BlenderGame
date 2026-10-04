--!strict
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.Muncher)
local WorldUtil = require(script.Parent.WorldUtil)
local MovementService = require(script.Parent.MovementService)
local Service = {}
local deps: any
type State = { Progress: number, Goal: number, Multiplier: number, ExpiresAt: number }
local states: { [string]: State } = {}
local nextFeed: { [Player]: number } = {}
local random = Random.new()

function Service.Init(services: any)
    deps = services
end

function Service.Reset(player: Player)
    local id = deps.TycoonService.GetSessionId(player)
    if id then
        states[id] = { Progress = 0, Goal = random:NextInteger(1, #Config.Goals), Multiplier = 1, ExpiresAt = 0 }
    end
end

function Service.CleanupSession(id: string)
    states[id] = nil
end

function Service.RemovePlayer(player: Player)
    nextFeed[player] = nil
end

function Service.GetSnapshot(
    player: Player
): { Progress: number, Target: number, Multiplier: number, ExpiresAt: number }?
    local id = deps.TycoonService.GetSessionId(player)
    local state = if id then states[id] else nil
    if not state then
        return nil
    end
    if workspace:GetServerTimeNow() >= state.ExpiresAt then
        state.Multiplier, state.ExpiresAt = 1, 0
    end
    return {
        Progress = state.Progress,
        Target = Config.Goals[state.Goal].Required,
        Multiplier = state.Multiplier,
        ExpiresAt = state.ExpiresAt,
    }
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
    local goal = Config.Goals[state.Goal]
    if state.Progress == goal.Required then
        state.Multiplier = goal.CashMultiplier
        state.ExpiresAt = workspace:GetServerTimeNow() + goal.Duration
        state.Progress = 0
        state.Goal = random:NextInteger(1, #Config.Goals)
    end
end

-- Both intake paths commit synchronously under the plot's existing lifecycle lock.
-- Returns only cosmetic data after authoritative removal has succeeded.
function Service.TryFeed(player: Player, input: BasePart, object: Instance?, context: any): (boolean, string?, CFrame?)
    local id = deps.TycoonService.GetSessionId(player)
    local state = if id then states[id] else nil
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if
        not state
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
