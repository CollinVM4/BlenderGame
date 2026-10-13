-- Real service + existing WorldUtil marker lifecycle/proximity boundary.
cache.WorldUtil = nil
cache.MovementService = {
    CanPerformGameplayAction = function(player)
        return not player.Locked
    end,
}
local added, removed = {}, {}
function services.CollectionService:GetInstanceAddedSignal(tag)
    added[tag] = added[tag] or signal()
    return added[tag]
end
function services.CollectionService:GetInstanceRemovedSignal(tag)
    removed[tag] = removed[tag] or signal()
    return removed[tag]
end
local workspaceMethods = instance("Workspace")
workspaceFake.FindFirstChild = workspaceMethods.FindFirstChild
workspaceFake.GetChildren = workspaceMethods.GetChildren
workspaceFake.Children = {}
services.Players.PlayerRemoving = signal()
local players = {}
function services.Players:GetPlayers()
    return players
end
local timers = {}
env.task.delay = function(seconds, callback)
    table.insert(timers, { At = now + seconds, Callback = callback })
end
local function step(seconds)
    now += seconds
    local queued = timers
    timers = {}
    for _, timer in queued do
        if timer.At <= now then
            timer.Callback()
        else
            table.insert(timers, timer)
        end
    end
end
local config = loadModule("LuckyBlockConfig")
local authored = {}
for index = 1, 10 do
    local marker = instance("BasePart")
    marker.Name = "Spawn" .. index
    marker.Parent = workspaceFake
    marker.CFrame = frame(index * 20, 0, 0)
    marker.Size = vec(1, 1, 1)
    services.CollectionService:AddTag(marker, config.MarkerTag)
    table.insert(authored, marker)
end
local service = loadModule("LuckyBlockService")
service.Init()
local world = workspaceFake:FindFirstChild(config.WorldFolderName)
check(#world:GetChildren() == 0, "missing template leaves safe empty world")
local templates = instance("Folder")
templates.Name, templates.Parent = config.TemplateFolderName, storage
local template = instance("Model")
template.Name, template.Parent = config.ModelName, templates
local root = instance("BasePart")
root.Name, root.Parent = "Root", template
template.PrimaryPart = root
-- Engine double: Model:PivotTo also moves its PrimaryPart in Roblox.
local clone = template.Clone
function template:Clone()
    local model = clone(self)
    local pivot = model.PivotTo
    function model:PivotTo(at)
        pivot(self, at)
        self.PrimaryPart.Position = at.Position
    end
    return model
end
step(0.2)
service.Init()
check(#world:GetChildren() == 5, "ten authored markers start five active blocks; init is idempotent")
local origins = {}
for _, model in world:GetChildren() do
    local origin = model:GetAttribute("LuckyBlockOrigin")
    check(not origins[origin.Position.X], "active blocks occupy distinct authored locations")
    origins[origin.Position.X] = true
end
local event = shared.Events:FindFirstChild(config.RewardEventName)
local receipts = {}
function event:FireClient(player, payload)
    table.insert(receipts, { Player = player, Payload = payload })
    -- Reentrant contender must see an already committed removal.
    if self.Contender then
        check(
            not service.TryClaim(self.Contender, self.ClaimedModel),
            "publication cannot reenter an already claimed block"
        )
    end
end
local function subject()
    local player = instance("Player")
    player.UserId = #allInstances
    player.Parent = services.Players
    local character = instance("Model")
    character.Parent, player.Character = workspaceFake, character
    local hrp = instance("BasePart")
    hrp.Name, hrp.Parent = "HumanoidRootPart", character
    local h = instance("Humanoid")
    h.Health, h.Parent = 100, character
    return player, hrp, h
end

local p, hrp, humanoid = subject()
local contender, contenderRoot = subject()
local first = world:GetChildren()[1]
hrp.Position = first.PrimaryPart.Position + vec(100, 0, 0)
check(not service.TryClaim(p, first), "far player cannot claim")
hrp.Position = first.PrimaryPart.Position
humanoid.Health = 0
check(not service.TryClaim(p, first), "dead player cannot claim")
humanoid.Health, p.Locked = 100, true
check(not service.TryClaim(p, first), "existing gameplay action lock is respected")
p.Locked = false
local foreign = instance("Model")
foreign.Parent = world
check(not service.TryClaim(p, foreign), "unregistered models cannot grant rewards")
foreign:Destroy()
contenderRoot.Position = hrp.Position
event.Contender, event.ClaimedModel = contender, first
check(service.TryClaim(p, first), "near living player claims")
event.Contender = nil
check(not service.TryClaim(contender, first), "simultaneous contender loses single claim")
check(#receipts == 1 and first.Parent == nil, "one receipt and world removal per claim")
local second = world:GetChildren()[1]
hrp.Position = second.PrimaryPart.Position
check(not service.TryClaim(p, second), "per-player cooldown prevents rapid claims of distinct blocks")
step(0.8)
check(service.TryClaim(p, second), "cooldown expires without blocking future pickups")
check(#world:GetChildren() == 3, "each claim reserves one delayed replacement")
step(24)
check(#world:GetChildren() == 3, "replacement cannot appear before minimum delay")
step(17)
check(#world:GetChildren() == 5, "all replacements return by maximum delay plus polling")
for _, receipt in receipts do
    local reward
    for _, definition in config.Rewards do
        if definition.Id == receipt.Payload.RewardId then
            reward = definition
        end
    end
    check(
        reward and receipt.Payload.DurationSeconds == reward.DurationSeconds,
        "reward ID and duration come from server config"
    )
end
-- Automatic proximity pickup, without any client intent or prompt.
players = { contender }
local third = world:GetChildren()[1]
contenderRoot.Position = third.PrimaryPart.Position
step(0.2)
check(third.Parent == nil and #receipts == 3, "server proximity poll collects without a client request")
players = {}
local fourth = world:GetChildren()[1]
fourth:Destroy()
check(#receipts == 3, "external removal grants no reward")
step(41)
check(#world:GetChildren() == 5, "external destruction also replenishes within the active cap")
for _, marker in authored do
    services.CollectionService:RemoveTag(marker, config.MarkerTag)
    services.CollectionService:GetInstanceRemovedSignal(config.MarkerTag):Fire(marker)
end
check(#world:GetChildren() == 0, "removing markers retires their blocks")
step(41)
check(#world:GetChildren() == 0, "stale timers cannot spawn at removed markers")
services.CollectionService:AddTag(authored[1], config.MarkerTag)
services.CollectionService:GetInstanceAddedSignal(config.MarkerTag):Fire(authored[1])
step(0.2)
check(#world:GetChildren() == 1, "too few markers cap stock at available authored locations")
local stock = world:GetChildren()[1]
stock.Parent = storage
stock.AncestryChanged:Fire()
check(stock.Destroyed and #receipts == 3, "reparented blocks retire without rewards")
step(41)
check(#world:GetChildren() == 1, "reparenting cannot duplicate active world stock")
env.math = table.clone(math)
local rewardRoll = 0
env.math.random = function(low, high)
    return if low then low else rewardRoll
end
for _, sample in
    {
        { 0, "DoubleCash", 30 },
        { 0.18, "SuperJump", 12 },
        { 0.40, "RainbowRampage", 10 },
        { 0.48, "MegaBat", 15 },
        { 0.63, "IngredientMagnet", 15 },
        { 0.83, "Invincibility", 8 },
        { 0.999, "Invincibility", 8 },
    }
do
    rewardRoll = sample[1]
    local block = world:GetChildren()[1]
    hrp.Position = block.PrimaryPart.Position
    check(service.TryClaim(p, block), "weighted boundary sample claims a live block")
    check(receipts[#receipts].Payload.RewardId == sample[2], "configured weight boundary selects " .. sample[2])
    check(
        receipts[#receipts].Payload.DurationSeconds == sample[3],
        "LuckyBlockPickedUp reports the expected duration metadata for " .. sample[2]
    )
    step(41)
end

local nearby = shared.Events:FindFirstChild("LuckyBlockRevealed")
local notifications = {}
function nearby:FireClient(player, payload)
    table.insert(notifications, { Player = player, Payload = payload })
end
local closePlayer, closeRoot = subject()
local farPlayer, farRoot = subject()
local finalBlock = world:GetChildren()[1]
hrp.Position = finalBlock.PrimaryPart.Position
closeRoot.Position = hrp.Position + vec(70, 0, 0)
farRoot.Position = hrp.Position + vec(70.1, 0, 0)
players = { p, closePlayer, farPlayer }
check(service.TryClaim(p, finalBlock), "valid claim publishes nearby final reward")
check(
    #notifications == 1 and notifications[1].Player == closePlayer,
    "only nearby observers receive a reveal; collector and distant players are excluded"
)
local published = notifications[1].Payload
local collected = receipts[#receipts].Payload
check(
    published.RewardId == collected.RewardId and published.DurationSeconds == collected.DurationSeconds,
    "nearby reveal matches the server-selected reward and duration"
)
check(
    published.Character == p.Character
        and published.Position == collected.Position
        and published.UserId == p.UserId
        and published.PickupId == collected.PickupId
        and published.PickedUpAt == collected.PickedUpAt,
    "nearby identity and timing match the committed pickup"
)
check(
    not service.TryClaim(closePlayer, finalBlock) and #notifications == 1,
    "replayed claims cannot publish nearby presentation"
)
nearby.OnServerEvent = signal()
nearby.OnServerEvent:Fire(closePlayer, { RewardId = "FakeReward", Character = p.Character })
check(#notifications == 1, "client submissions to the output-only reveal remote have no effect")
