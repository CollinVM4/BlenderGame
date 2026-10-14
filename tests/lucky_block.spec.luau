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
local scheduledDelays = {}
env.task.delay = function(seconds, callback)
    table.insert(timers, { At = now + seconds, Callback = callback })
    table.insert(scheduledDelays, seconds)
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
local warnings = {}
env.warn = function(message)
    table.insert(warnings, message)
end
local config = loadModule("LuckyBlockConfig")
local container = instance("Folder")
container.Name, container.Parent = config.Spawn.ContainerName, workspaceFake
local groups = {}
for level = 0, 3 do
    local group = instance(if level % 2 == 0 then "Folder" else "Model")
    group.Name, group.Parent = "Level" .. level, container
    groups[level] = group
end
local authored = {}
for index = 1, 10 do
    local marker = instance("BasePart")
    marker.Name = "Spawn" .. index
    local level = (index - 1) % 4
    marker.Parent = if index <= 8 then groups[level] else container
    if index > 8 then
        marker:SetAttribute("Level", if index == 9 then level else "Level" .. level)
    end
    marker:SetAttribute("ExpectedLevel", "Level" .. level)
    marker.CFrame = frame(index * 20, 0, 0)
    marker.Size = vec(1, 1, 1)
    services.CollectionService:AddTag(marker, config.MarkerTag)
    table.insert(authored, marker)
end
local templates = instance("Folder")
templates.Name, templates.Parent = config.TemplateFolderName, storage
local template = instance("Model")
template.Name, template.Parent = config.ModelName, templates
local root = instance("BasePart")
root.Name, root.Parent = "Root", template
template.PrimaryPart = root
template.Attributes.RBX_ReimportId = "imported-block"
root.Attributes.RBX_ImportedPart = "imported-root"
root:SetAttribute("VisualVariant", "Gold")
-- Engine double: Model:PivotTo also moves its PrimaryPart in Roblox.
local clone = template.Clone
function template:Clone()
    local model = clone(self)
    local objects = model:GetDescendants()
    table.insert(objects, model)
    for _, object in objects do
        local setAttribute = object.SetAttribute
        function object:SetAttribute(name, value)
            if string.sub(name, 1, 4) == "RBX_" then
                error("CoreScript permission required: " .. name)
            end
            setAttribute(self, name, value)
        end
    end
    local pivot = model.PivotTo
    function model:PivotTo(at)
        pivot(self, at)
        self.PrimaryPart.Position = at.Position
    end
    return model
end
local service = loadModule("LuckyBlockService")
service.Init()
local world = workspaceFake:FindFirstChild(config.WorldFolderName)
service.Init()
check(#world:GetChildren() == 4, "ten authored markers start four active blocks; init is idempotent")
check(
    world:GetChildren()[1]:GetAttribute("RBX_ReimportId") == "imported-block"
        and world:GetChildren()[1].PrimaryPart:GetAttribute("VisualVariant") == "Gold"
        and template:GetAttribute("RBX_ReimportId") == "imported-block",
    "server native cloning preserves imported metadata and legitimate attributes without protected writes"
)
local function byLevel(level)
    for _, block in world:GetChildren() do
        if block:GetAttribute("Level") == level then
            return block
        end
    end
end
local function verifyLevels()
    for _, level in config.Spawn.Levels do
        check(byLevel(level) ~= nil, "initial/replenished stock includes " .. level)
    end
    for _, block in world:GetChildren() do
        local origin = block:GetAttribute("LuckyBlockOrigin")
        local matched = false
        for _, marker in authored do
            if marker.CFrame.Position.X == origin.Position.X then
                matched = marker:GetAttribute("ExpectedLevel") == block:GetAttribute("Level")
            end
        end
        check(matched, "random selection stays inside the block's level")
    end
end
verifyLevels()
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
local first = byLevel("Level2")
local otherLevels = { byLevel("Level0"), byLevel("Level1"), byLevel("Level3") }
local previousOrigin = first:GetAttribute("LuckyBlockOrigin")
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
check(#world:GetChildren() == 3 and not byLevel("Level2"), "only Level2 is empty after its claim")
local second = byLevel("Level0")
hrp.Position = second.PrimaryPart.Position
check(not service.TryClaim(p, second), "per-player cooldown prevents rapid claims of distinct blocks")
step(config.Respawn.MinRespawnSeconds - 0.01)
check(#world:GetChildren() == 3, "replacement cannot appear before minimum delay")
step(config.Respawn.MaxRespawnSeconds - config.Respawn.MinRespawnSeconds + 0.01)
check(#world:GetChildren() == 4, "one replacement returns by maximum delay without nearby players")
for _, block in otherLevels do
    check(block.Parent == world, "Level2 cooldown leaves other levels untouched")
end
check(
    byLevel("Level2"):GetAttribute("LuckyBlockOrigin").Position.X ~= previousOrigin.Position.X,
    "replacement avoids its previous location when alternatives exist"
)
verifyLevels()
check(service.TryClaim(p, second), "cooldown expires without blocking future pickups")
step(config.Respawn.MaxRespawnSeconds)
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
step(config.Respawn.MaxRespawnSeconds)
check(#world:GetChildren() == 4, "external destruction also replenishes within the active cap")
for _, marker in authored do
    services.CollectionService:RemoveTag(marker, config.MarkerTag)
    services.CollectionService:GetInstanceRemovedSignal(config.MarkerTag):Fire(marker)
end
check(#world:GetChildren() == 0, "removing markers retires their blocks")
step(config.Respawn.MaxRespawnSeconds)
check(#world:GetChildren() == 0, "stale timers cannot spawn at removed markers")
services.CollectionService:AddTag(authored[1], config.MarkerTag)
services.CollectionService:GetInstanceAddedSignal(config.MarkerTag):Fire(authored[1])
step(config.Spawn.RetrySeconds)
check(#world:GetChildren() == 1, "too few markers cap stock at available authored locations")
local invalidGroup = instance("Part")
invalidGroup.Name, invalidGroup.Parent = "Level3", container
local invalid = instance("BasePart")
invalid.Name, invalid.Parent = "Invalid", invalidGroup
services.CollectionService:AddTag(invalid, config.MarkerTag)
services.CollectionService:GetInstanceAddedSignal(config.MarkerTag):Fire(invalid)
local invalidAttribute = instance("BasePart")
invalidAttribute.Parent = container
invalidAttribute:SetAttribute("Level", 9)
services.CollectionService:AddTag(invalidAttribute, config.MarkerTag)
services.CollectionService:GetInstanceAddedSignal(config.MarkerTag):Fire(invalidAttribute)
step(config.Spawn.RetrySeconds)
check(#world:GetChildren() == 1, "invalid level folders/attributes do not crash or spawn in another level")
local missingWarning = false
for _, message in warnings do
    missingWarning = missingWarning or string.find(message, "Level2 has no valid", 1, true) ~= nil
end
check(missingWarning, "missing level warns clearly")
local stock = world:GetChildren()[1]
stock.Parent = storage
stock.AncestryChanged:Fire()
check(stock.Destroyed and #receipts == 3, "reparented blocks retire without rewards")
step(config.Respawn.MaxRespawnSeconds)
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
    step(config.Respawn.MaxRespawnSeconds)
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

-- Deterministic timer endpoints, retained stock during asset failures, and late authoring.
players = {}
step(config.Respawn.MaxRespawnSeconds)
for _, seconds in scheduledDelays do
    if seconds ~= config.Pickup.PollSeconds and seconds ~= config.Spawn.RetrySeconds then
        check(
            seconds >= config.Respawn.MinRespawnSeconds and seconds <= config.Respawn.MaxRespawnSeconds,
            "every lifecycle cooldown lies within configured limits"
        )
    end
end
for _, roll in { 0, 1 } do
    rewardRoll = roll
    local block = world:GetChildren()[1]
    block:Destroy()
    local expected = config.Respawn.MinRespawnSeconds
        + roll * (config.Respawn.MaxRespawnSeconds - config.Respawn.MinRespawnSeconds)
    step(expected - 0.01)
    check(#world:GetChildren() == 0, "endpoint cooldown does not spawn early")
    step(0.01)
    check(#world:GetChildren() == 1, "endpoint cooldown spawns at the configured deadline")
end
local beforeAssetFailure = #receipts
world:GetChildren()[1]:Destroy()
template.PrimaryPart = nil
step(config.Respawn.MaxRespawnSeconds)
check(#world:GetChildren() == 0, "invalid template preserves empty slot safely")
template.PrimaryPart = root
step(config.Spawn.RetrySeconds)
check(
    #world:GetChildren() == 1 and #receipts == beforeAssetFailure,
    "repaired asset replenishes reserved slot without a pickup or reward"
)
for index = 2, #authored do
    services.CollectionService:AddTag(authored[index], config.MarkerTag)
    services.CollectionService:GetInstanceAddedSignal(config.MarkerTag):Fire(authored[index])
end
step(config.Spawn.RetrySeconds)
check(#world:GetChildren() == 4, "late marker configuration recovers all missing levels")
verifyLevels()
-- Legacy flat markers remain usable as Level0; no implicit cross-level assignment.
for _, marker in authored do
    if marker:GetAttribute("ExpectedLevel") == "Level0" then
        marker.Parent = workspaceFake
        marker:SetAttribute("Level", nil)
    end
end
byLevel("Level0"):Destroy()
step(config.Respawn.MaxRespawnSeconds)
check(#world:GetChildren() == 4 and byLevel("Level0"), "unassigned legacy flat markers retain Level0 compatibility")

-- Run into each level's block through the actual server poll, then replenish
-- that level independently. Client reveal failures cannot reopen a retired claim.
for _, level in config.Spawn.Levels do
    local block = byLevel(level)
    local count = #receipts
    hrp.Position = block.PrimaryPart.Position
    players = { p }
    step(config.Pickup.PollSeconds)
    players = {}
    check(block.Destroyed and not byLevel(level), "server proximity contact collects " .. level)
    check(#receipts == count + 1, "contact publishes exactly one server-selected reward for " .. level)
    check(not service.TryClaim(contender, block), "client reveal cannot make " .. level .. " collectible again")
    step(config.Respawn.MinRespawnSeconds - 0.01)
    check(not byLevel(level), level .. " does not respawn before three minutes")
    step(config.Respawn.MaxRespawnSeconds - config.Respawn.MinRespawnSeconds + 0.01)
    check(byLevel(level) ~= nil and #world:GetChildren() == 4, level .. " respawns by four minutes")
    check(#receipts == count + 1, "respawn itself grants no duplicate reward for " .. level)
end
