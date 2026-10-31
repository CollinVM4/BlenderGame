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
local presentationConfig = loadModule("LuckyBlockPresentation")
local rewardFolder = instance("Folder")
for id, entry in presentationConfig.Rewards do
    local asset = instance("Model")
    asset.Name, asset.Parent = entry.Visual, rewardFolder
    local part = instance("BasePart")
    part.Name, part.Parent = id .. "Art", asset
    part.Size = vec(1, 2, 1)
end
services.ReplicatedStorage.FindFirstChild = function(_, name)
    return if name == presentationConfig.VisualFolderName then rewardFolder else nil
end
workspaceFake.Terrain = instance("Part")
workspaceFake.Terrain.Parent = workspaceFake
local frameNew = env.CFrame.new
env.CFrame.new = function(x, y, z)
    if type(x) == "table" then
        return frame(x.X, x.Y, x.Z)
    end
    return frameNew(x, y, z)
end
local total, timed = 0, 0
for _, reward in config.Rewards do
    total += reward.Weight
    if reward.DurationSeconds then
        timed += 1
    end
end
check(#config.Rewards == 7 and timed == 4 and total == 100, "seven prizes, four buffs, total weight 100")
for _, old in { "DoubleCash", "SuperJump", "RainbowRampage", "IngredientMagnet" } do
    check(presentationConfig.Rewards[old] == nil, "obsolete prize removed")
end
local selectedIds, grantedTo, failure = nil, nil, false
local tier = 0
local expectedClaimer = nil
local service = loadModule("LuckyBlockService")
service.Init({
    TycoonService = {
        GetJumpTier = function(player)
            check(player == expectedClaimer, "item pool reads claimer tier")
            return tier
        end,
    },
    InventoryService = {
        PrepareIngredientReward = function(player, ids)
            selectedIds = ids
            return function()
                if failure then
                    return false
                end
                grantedTo = player
                return true
            end
        end,
    },
})
local world = workspaceFake:FindFirstChild(config.WorldFolderName)
local function blocks(level)
    local result = {}
    for _, block in world:GetChildren() do
        if block:GetAttribute("Level") == level then
            table.insert(result, block)
        end
    end
    return result
end
local function prize(id)
    for _, model in world:GetChildren() do
        if model:GetAttribute("PickupId") == id and model:GetAttribute("PickupState") == "Available" then
            return model
        end
    end
end
for level, expected in config.Spawn.SlotsPerLevel do
    check(#blocks(level) == expected, "configured slot count " .. level)
end
local function subject()
    local player = instance("Player")
    player.Parent = services.Players
    player.Character = instance("Model")
    player.Character.Parent = workspaceFake
    local root = instance("BasePart")
    root.Name, root.Parent = "HumanoidRootPart", player.Character
    local humanoid = instance("Humanoid")
    humanoid.Health, humanoid.Parent = 100, player.Character
    return player, root, humanoid
end
local roller, root = subject()
local claimer, claimRoot, health = subject()
expectedClaimer = claimer
local event = shared.Events:FindFirstChild(config.RewardEventName)
local receipts = {}
function event:FireClient(player, payload)
    table.insert(receipts, payload)
end
local rewardRoll = 0
local drawIndex = 1
env.math = table.clone(math)
env.math.random = function(low, high)
    return if low then math.clamp(drawIndex, low, high) else rewardRoll
end
local reveal = presentationConfig.RevealSeconds + presentationConfig.HoldSeconds + presentationConfig.FadeSeconds
local function roll(block, fraction)
    rewardRoll = fraction
    root.Position = block.PrimaryPart.Position
    check(service.TryClaim(roller, block), "server rolls live block")
    return receipts[#receipts].PickupId
end
local cycleStart = now
local initial = blocks("Level0")
local id = roll(initial[1], 0)
check(not prize(id), "no pickup during reveal")
step(1)
local id2 = roll(initial[2], 0.15)
service.RemovePlayer(roller)
roller.Parent = nil
step(reveal - 1 - 0.01)
check(not prize(id), "deadline derives from reveal hold fade constants")
step(0.01)
local pickup = prize(id)
check(pickup ~= nil, "roller leave does not cancel server spawn")
local rewardArt = pickup:FindFirstChild("RewardVisual")
check(
    rewardArt and rewardArt:FindFirstChild(presentationConfig.Rewards.CashBoost.Visual),
    "public collectible resolves authored presentation Visual mapping"
)
check(not services.CollectionService:HasTag(pickup, config.WorldTag), "reward never enters unopened block animation")
check(services.CollectionService:HasTag(pickup, presentationConfig.PickupTag), "public reward registers its own handoff identity")
local visualPose = loadModule("LuckyBlockRewardVisual").Pose(pickup:GetAttribute("PickupPosition"))
check((rewardArt:GetPivot().Position - visualPose.Position).Magnitude < 0.001, "public prize uses settled reveal pose")
for _, part in rewardArt:GetDescendants() do
    if part:IsA("BasePart") then
        check(part.Anchored and not part.CanCollide, "public reward geometry is anchored and inert")
    end
end
check(roller:GetAttribute("LuckyBuffCashBoostExpiresAt") == nil, "roll publishes no timed message")
claimRoot.Position = pickup:GetAttribute("PickupPosition")
health.Health = 0
check(not service.TryClaimPickup(claimer, pickup), "dead claimer rejected")
health.Health = 100
local nearbyBlock = blocks("Level2")[1]
claimRoot.Position = nearbyBlock.PrimaryPart.Position
check(service.TryClaim(claimer, nearbyBlock), "claimer can roll a block immediately before collecting prize")
claimRoot.Position = pickup:GetAttribute("PickupPosition")
check(service.TryClaimPickup(claimer, pickup), "living different player collects")
check(
    claimer:GetAttribute("LuckyBuffCashBoostExpiresAt") == now + 90
        and roller:GetAttribute("LuckyBuffCashBoostExpiresAt") == nil,
    "only successful claimer receives authoritative expiry"
)
check(
    not pickup:FindFirstChild("RewardVisual") and pickup:GetAttribute("PickupState") == "Claimed",
    "successful claim removes prize and publishes terminal identity"
)
check(not service.TryClaimPickup(claimer, pickup), "duplicate claim rejected")
local contender, contenderRoot = subject()
contenderRoot.Position = claimRoot.Position
check(not service.TryClaimPickup(contender, pickup), "competing eligible claimer rejected")
check(
    service.GetCashMultiplier(claimer) == 1.5 and service.GetCashMultiplier(roller) == 1,
    "cash buff belongs to claimer"
)
step(1)
local star = prize(id2)
claimRoot.Position = star:GetAttribute("PickupPosition")
check(service.TryClaimPickup(claimer, star), "different buff coexists")
check(
    service.IsBuffActive(claimer, "StarPower") and service.IsBuffActive(claimer, "CashBoost"),
    "independent buff clocks"
)
step(10)
check(
    not service.IsBuffActive(claimer, "StarPower") and service.IsBuffActive(claimer, "CashBoost"),
    "independent expiration"
)
step(cycleStart + 180 - now - 0.01)
check(#blocks("Level0") == 1 and initial[3].Parent == world, "unclaimed stock remains during shared clock")
step(0.01)
check(
    #blocks("Level0") == 3 and initial[3].Parent == world,
    "first shared deadline fills empties without resetting or replacing stock"
)
roller.Parent = services.Players
local refreshId = roll(blocks("Level0")[1], 0)
step(reveal)
claimRoot.Position = prize(refreshId):GetAttribute("PickupPosition")
check(service.TryClaimPickup(claimer, prize(refreshId)), "cash refresh claim")
check(claimer:GetAttribute("LuckyBuffCashBoostExpiresAt") == now + 90, "refresh publishes replacement server expiry")
step(80)
check(service.IsBuffActive(claimer, "CashBoost"), "refresh starts a new full duration")
step(10)
check(not service.IsBuffActive(claimer, "CashBoost"), "refresh replaces rather than adds duration")
service.RemovePlayer(claimer)
check(not service.IsBuffActive(claimer, "CashBoost"), "leave clears buffs")
-- Item pools are selected for the claimer; failed transactions restore the same identity/lifetime.
for _, sample in { { 0.62, "PantryPack", 3 }, { 0.82, "TopShelf", 1 }, { 0.92, "MysteryBox", 1 } } do
    step(240)
    local itemId = roll(blocks("Level1")[1], sample[1])
    step(reveal)
    local model = prize(itemId)
    check(model:GetAttribute("RewardId") == sample[2], "weighted instant reward")
    claimRoot.Position = model:GetAttribute("PickupPosition")
    local beforeArt = model:FindFirstChild("RewardVisual")
    local beforePose, beforeScale = beforeArt:GetPivot(), beforeArt:GetScale()
    local beforeNotice = claimer:GetAttribute("LuckyInstant" .. sample[2] .. "Until")
    failure = true
    check(not service.TryClaimPickup(claimer, model), "failed grant leaves prize available")
    local restored = prize(itemId)
    check(restored == model and restored:GetAttribute("PickupState") == "Available", "same pickup identity restored")
    local restoredArt = restored:FindFirstChild("RewardVisual")
    check(
        restoredArt
            and restoredArt:GetScale() == beforeScale
            and (restoredArt:GetPivot().Position - beforePose.Position).Magnitude < 0.001,
        "failed grant restores same reward scale and pose"
    )
    check(
        claimer:GetAttribute("LuckyInstant" .. sample[2] .. "Until") == beforeNotice,
        "failed claim cannot display a confirmation"
    )
    failure = false
    check(service.TryClaimPickup(claimer, restored) and grantedTo == claimer, "claimer receives item grant")
    check(#selectedIds == sample[3], "all selected prize units awarded")
    check(
        claimer:GetAttribute("LuckyInstant" .. sample[2] .. "Until") == now + presentationConfig.InstantMessageSeconds
            and roller:GetAttribute("LuckyInstant" .. sample[2] .. "Until") == nil,
        "instant confirmation goes only to successful claimer"
    )
    for _, ingredientId in selectedIds do
        local definition = loadModule("Ingredients")[ingredientId]
        if sample[2] ~= "MysteryBox" then
            check(definition.JumpLocation == 0, "pool uses claimer purchased tier")
        else
            check(ingredientId ~= "Player_Head" and ingredientId ~= "Dragon_Fruit", "mystery exclusions")
        end
    end
end
step(240)
local expiresId = roll(blocks("Level2")[1], 0.62)
step(reveal)
local expires = prize(expiresId)
step(59)
claimRoot.Position = expires:GetAttribute("PickupPosition")
failure = true
check(not service.TryClaimPickup(claimer, expires), "late failure recovers prize")
step(1)
check(not prize(expiresId), "recovery never extends original sixty-second lifetime")
step(240)
local untouchedId = roll(blocks("Level1")[1], 0)
step(reveal)
step(60)
check(not prize(untouchedId), "unclaimed pickups expire without award")
check(not service.IsBuffActive(roller, "CashBoost"), "rolling never applies buff")
print("PASS: Lucky server lifecycle")

-- Independent upper-level clocks and previous-marker avoidance.
failure = false
step(240)
local firstUpper, otherUpper = blocks("Level1")[1], blocks("Level2")[1]
local oldPosition = otherUpper:GetAttribute("LuckyBlockOrigin").Position.X
local upperStart = now
roll(firstUpper, 0)
step(10)
roll(otherUpper, 0)
step(170)
check(#blocks("Level1") == 1 and #blocks("Level2") == 0, "Level1 and Level2 retain independent clocks")
step(10)
check(#blocks("Level2") == 1, "second upper level refills at its own deadline")
check(
    blocks("Level2")[1]:GetAttribute("LuckyBlockOrigin").Position.X ~= oldPosition,
    "slot avoids previous marker when alternatives exist"
)
-- Mystery can reach a tier the claimer has not purchased.
local mysteryPool = {}
for ingredientId in loadModule("Ingredients") do
    if ingredientId ~= "Player_Head" and ingredientId ~= "Dragon_Fruit" then
        table.insert(mysteryPool, ingredientId)
    end
end
table.sort(mysteryPool)
drawIndex = table.find(mysteryPool, "Mystery")
local mysteryId = roll(blocks("Level1")[1], 0.92)
step(reveal)
claimRoot.Position = prize(mysteryId):GetAttribute("PickupPosition")
check(
    service.TryClaimPickup(claimer, prize(mysteryId)) and selectedIds[1] == "Mystery",
    "MysteryBox includes unreachable tier three"
)
drawIndex = 1
-- Purchased tier is evaluated at pickup claim, after the roll.
step(240)
local shelfId = roll(blocks("Level2")[1], 0.82)
step(reveal)
tier = 2
claimRoot.Position = prize(shelfId):GetAttribute("PickupPosition")
check(service.TryClaimPickup(claimer, prize(shelfId)), "claim TopShelf after purchased-tier change")
check(loadModule("Ingredients")[selectedIds[1]].JumpLocation == 2, "TopShelf uses current purchased tier")

-- Missing authored markers retry without inventing replacements or enabling Level3.
for _, marker in authored do
    if marker:GetAttribute("ExpectedLevel") == "Level1" then
        services.CollectionService:RemoveTag(marker, config.MarkerTag)
        services.CollectionService:GetInstanceRemovedSignal(config.MarkerTag):Fire(marker)
    end
end
step(240)
check(#blocks("Level1") == 0, "missing markers never generate fallback locations")
local missingLevel = false
for _, message in warnings do
    missingLevel = missingLevel or string.find(message, "Level1 has 0", 1, true) ~= nil
    check(not string.find(message, "Level3 has", 1, true), "disabled level never warns about markers")
end
check(missingLevel, "enabled level warns when below required marker count")
for _, marker in authored do
    if marker:GetAttribute("ExpectedLevel") == "Level1" then
        services.CollectionService:AddTag(marker, config.MarkerTag)
        services.CollectionService:GetInstanceAddedSignal(config.MarkerTag):Fire(marker)
    end
end
step(config.Spawn.RetrySeconds)
check(#blocks("Level1") == 1, "missing markers recover on five-second retry")

-- Cleanup clears active buffs and both cooldowns without removing public prizes.
step(240)
local cleanupA = roll(blocks("Level0")[1], 0.28)
step(1)
local cleanupB = roll(blocks("Level0")[1], 0.45)
step(reveal)
claimRoot.Position = prize(cleanupA):GetAttribute("PickupPosition")
check(
    service.TryClaimPickup(claimer, prize(cleanupA)) and service.IsBuffActive(claimer, "MegaBat"),
    "MegaBat clock starts at claim"
)
local remaining = prize(cleanupB)
claimRoot.Position = remaining:GetAttribute("PickupPosition")
check(not service.TryClaimPickup(claimer, remaining), "pickup cooldown blocks another prize")
service.RemovePlayer(claimer)
check(
    not service.IsBuffActive(claimer, "MegaBat") and remaining.Parent == world,
    "cleanup clears active buff but preserves prize"
)
check(
    service.TryClaimPickup(claimer, remaining) and service.IsBuffActive(claimer, "Invincibility"),
    "cleanup clears pickup cooldown"
)
service.RemovePlayer(claimer)
check(not service.IsBuffActive(claimer, "Invincibility"), "cleanup clears invincibility")
check(claimer:GetAttribute("LuckyBuffInvincibilityExpiresAt") == nil, "player cleanup clears replicated HUD expiry")

-- Missing authored prize art remains a label-only collectible, never a block.
step(240)
local missingSource = rewardFolder:FindFirstChild(presentationConfig.Rewards.CashBoost.Visual)
missingSource.Parent = nil
local missingId = roll(blocks("Level2")[1], 0)
step(reveal)
local labelOnly = prize(missingId)
check(
    labelOnly
        and not labelOnly:FindFirstChild("RewardVisual")
        and not labelOnly:FindFirstChildWhichIsA("BasePart", true),
    "missing reward creates no substitute geometry"
)
local fallbackLabel
for _, anchor in workspaceFake.Terrain:GetChildren() do
    local gui = anchor:FindFirstChild("LuckyRewardLabel")
    if gui then
        fallbackLabel = gui
    end
end
check(
    fallbackLabel
        and fallbackLabel.MaxDistance == 60
        and fallbackLabel:FindFirstChildOfClass("TextLabel").Text == "Cash Boost",
    "missing art retains readable finite-distance world label"
)
local namedWarning = false
for _, message in warnings do
    namedWarning = namedWarning or string.find(message, "LuckyBlockVisuals.2xCash", 1, true) ~= nil
end
check(namedWarning, "missing asset warning names exact authored visual")
claimRoot.Position = labelOnly:GetAttribute("PickupPosition")
check(service.TryClaimPickup(claimer, labelOnly), "label-only prize preserves server proximity collection")
missingSource.Parent = rewardFolder
