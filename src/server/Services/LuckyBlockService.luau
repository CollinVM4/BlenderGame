--!strict
-- Session-only rolls, public reward pickups, and buff clocks.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Constants.LuckyBlockConfig)
local Presentation = require(Shared.Constants.LuckyBlockPresentation)
local WorldUtil = require(script.Parent.WorldUtil)
local BillboardStyle = require(Shared.WorldBillboardStyle)
local RewardVisual = require(Shared.LuckyBlockRewardVisual)
local Ingredients = require(Shared.Constants.Ingredients)
local Service = {}
local deps: any
local buffs: { [Player]: { [string]: number } } = {}
local pickupClaim: { [Player]: number } = {}
type Pickup = {
    PickupId: number,
    RewardId: string,
    Position: Vector3,
    PickedUpAt: number,
    ExpiresAt: number,
    Model: Model?,
    LabelAnchor: Attachment?,
}
local pickups: { [number]: Pickup } = {}
local level0Waiting = false
local spawnPickup: (Pickup) -> ()
type Slot = { Level: string, Model: Model?, Previous: BasePart?, Waiting: boolean }
local slots: { Slot } = {}
local populate: (Slot) -> boolean
type Record = { Marker: BasePart, Origin: CFrame, Connections: { RBXScriptConnection }, Slot: Slot }
local markers: { [BasePart]: boolean } = {}
local records: { [Model]: Record } = {}
local levelWarnings: { [string]: boolean } = {}
local markerWarnings: { [BasePart]: boolean } = {}
local schedule: (Slot, number) -> ()
local lastClaim: { [Player]: number } = {}
local folder: Folder
local remote: RemoteEvent
local nearbyRemote: RemoteEvent
local pickupId = 0
local started = false
local assetWarning = false
local rewardWarnings: { [string]: boolean } = {}

function Service.IsBuffActive(player: Player, rewardId: string): boolean
    local state = buffs[player]
    return state ~= nil and (state[rewardId] or 0) > workspace:GetServerTimeNow()
end

function Service.GetCashMultiplier(player: Player): number
    return if Service.IsBuffActive(player, "CashBoost") then 1.5 else 1
end

local function respawn(slot: Slot)
    local seconds = Config.Respawn.MinRespawnSeconds
        + math.random() * (Config.Respawn.MaxRespawnSeconds - Config.Respawn.MinRespawnSeconds)
    if slot.Level ~= "Level0" or not Config.Spawn.Level0Sync then
        schedule(slot, seconds)
    elseif not level0Waiting then
        level0Waiting = true
        task.delay(seconds, function()
            level0Waiting = false
            for _, candidate in slots do
                if candidate.Level == "Level0" and not candidate.Model and not populate(candidate) then
                    schedule(candidate, Config.Spawn.RetrySeconds)
                end
            end
        end)
    end
end

local function retire(model: Model, alreadyDestroying: boolean?)
    local record = records[model]
    if not record then
        return
    end
    -- Commit before Destroy/events: another player or reentrant callback cannot claim.
    records[model] = nil
    for _, connection in record.Connections do
        connection:Disconnect()
    end
    record.Slot.Model = nil
    respawn(record.Slot)
    if not alreadyDestroying then
        model:Destroy()
    end
end

function Service.TryClaim(player: Player, model: Model): boolean
    local record = records[model]
    local now = os.clock()
    if not record or player.Parent ~= Players or not model:IsDescendantOf(folder) then
        return false
    end
    if lastClaim[player] and now - lastClaim[player] < Config.Pickup.PlayerCooldownSeconds then
        return false
    end
    if not WorldUtil.Near(player, model, Config.Pickup.Radius) then
        return false
    end
    lastClaim[player] = now
    -- Config is shared for presentation, but selection uses only the server's copy.
    local total = 0
    for _, reward in Config.Rewards do
        total += reward.Weight
    end
    local roll = math.random() * total
    local selected = Config.Rewards[#Config.Rewards]
    for _, reward in Config.Rewards do
        roll -= reward.Weight
        if roll < 0 then
            selected = reward
            break
        end
    end
    local position = record.Origin.Position
    local character = player.Character
    local pickedUpAt = workspace:GetServerTimeNow()
    pickupId += 1
    retire(model)
    remote:FireClient(player, {
        RewardId = selected.Id,
        DurationSeconds = selected.DurationSeconds,
        Position = position,
        Character = character,
        PickedUpAt = pickedUpAt,
        PickupId = pickupId,
    })
    -- Output only; observers receive one committed reward, never silhouette ticks.
    for _, observer in Players:GetPlayers() do
        local root = observer.Character and observer.Character:FindFirstChild("HumanoidRootPart")
        if
            observer ~= player
            and root
            and root:IsA("BasePart")
            and (root.Position - position).Magnitude <= Presentation.NearbyDistance
        then
            nearbyRemote:FireClient(observer, {
                Position = position,
                UserId = player.UserId,
                Character = character,
                RewardId = selected.Id,
                DurationSeconds = selected.DurationSeconds,
                PickedUpAt = pickedUpAt,
                PickupId = pickupId,
            })
        end
    end
    -- Replicate identity before the deadline. Clients can retain a revealed prize
    -- until this same container's art arrives, or observe a claim before art arrives.
    local container = Instance.new("Model")
    container.Name = "LuckyRewardPickup"
    container:SetAttribute("PickupId", pickupId)
    container:SetAttribute("RewardId", selected.Id)
    container:SetAttribute("PickedUpAt", pickedUpAt)
    container:SetAttribute("PickupPosition", position)
    container:SetAttribute("PickupState", "Pending")
    CollectionService:AddTag(container, Presentation.PickupTag)
    container.Parent = folder
    local pickup: Pickup = {
        PickupId = pickupId,
        RewardId = selected.Id,
        Position = position,
        PickedUpAt = pickedUpAt,
        ExpiresAt = 0,
        Model = container,
        LabelAnchor = nil,
    }
    container.Destroying:Connect(function()
        if pickup.LabelAnchor then
            pickup.LabelAnchor:Destroy()
            pickup.LabelAnchor = nil
        end
    end)
    task.delay(Presentation.RevealSeconds + Presentation.HoldSeconds + Presentation.FadeSeconds, function()
        pickup.ExpiresAt = workspace:GetServerTimeNow() + 60
        container:SetAttribute("ExpiresAt", pickup.ExpiresAt)
        pickups[pickup.PickupId] = pickup
        spawnPickup(pickup)
    end)
    return true
end

local function spawnAt(marker: BasePart, slot: Slot): boolean
    local templates = ServerStorage:FindFirstChild(Config.TemplateFolderName)
    local template = templates and templates:FindFirstChild(Config.ModelName)
    if not template or not template:IsA("Model") or not template.PrimaryPart or not template.Archivable then
        if not assetWarning then
            warn(
                "[LuckyBlock] Add an archivable Model with PrimaryPart at ServerStorage."
                    .. Config.TemplateFolderName
                    .. "."
                    .. Config.ModelName
            )
            assetWarning = true
        end
        return false
    end
    assetWarning = false
    local model = template:Clone()
    -- Authored templates are visual assets, never executable gameplay or inventory.
    local descendants = model:GetDescendants()
    table.insert(descendants, model)
    for _, child in descendants do
        for _, tag in CollectionService:GetTags(child) do
            CollectionService:RemoveTag(child, tag)
        end
        if child:IsA("BaseScript") or child:IsA("ModuleScript") or child:IsA("ProximityPrompt") then
            child:Destroy()
        elseif child:IsA("BasePart") then
            child.Anchored = true
            child.CanCollide = false
            child.CanTouch = false
            child.CanQuery = false
        end
    end
    local origin = marker.CFrame * CFrame.new(0, marker.Size.Y / 2 + Config.Spawn.HeightOffset, 0)
    model:PivotTo(origin)
    model:SetAttribute("LuckyBlockOrigin", origin)
    model:SetAttribute("LuckyBlockSpawnTime", workspace:GetServerTimeNow())
    local blockSlot = slot :: Slot
    model:SetAttribute("Level", blockSlot.Level)
    records[model] = { Marker = marker :: BasePart, Origin = origin, Connections = {}, Slot = blockSlot }
    blockSlot.Model = model
    blockSlot.Previous = marker
    model.Parent = folder
    local connections = records[model].Connections
    table.insert(
        connections,
        model.Destroying:Connect(function()
            retire(model, true)
        end)
    )
    table.insert(
        connections,
        model.AncestryChanged:Connect(function()
            if not model:IsDescendantOf(folder) then
                retire(model)
            end
        end)
    )
    CollectionService:AddTag(model, Config.WorldTag)
    return true
end

local function clearPickupAppearance(pickup: Pickup)
    if pickup.LabelAnchor then
        pickup.LabelAnchor:Destroy()
        pickup.LabelAnchor = nil
    end
    local visual = pickup.Model and pickup.Model:FindFirstChild("RewardVisual")
    if visual then
        visual:Destroy()
    end
end

spawnPickup = function(pickup: Pickup)
    local model = pickup.Model
    if not model or workspace:GetServerTimeNow() >= pickup.ExpiresAt then
        return
    end
    local sourceFolder = game:GetService("ReplicatedStorage"):FindFirstChild(Presentation.VisualFolderName)
    local visualName = Presentation.Rewards[pickup.RewardId].Visual
    local visual = RewardVisual.Clone(sourceFolder and sourceFolder:FindFirstChild(visualName), false)
    local partCount = 0
    if visual then
        visual.Name = "RewardVisual"
        visual:PivotTo(RewardVisual.Pose(pickup.Position))
        for _, object in visual:GetDescendants() do
            if object:IsA("BasePart") then
                partCount += 1
            end
        end
        visual.Parent = model
        rewardWarnings[visualName] = nil
    elseif not rewardWarnings[visualName] then
        rewardWarnings[visualName] = true
        warn(
            "[LuckyBlock] Missing usable "
                .. Presentation.VisualFolderName
                .. "."
                .. visualName
                .. "; label only (Collin asset task)"
        )
    end
    -- An Attachment on Terrain gives the fallback label a world position without
    -- inventing a part/mesh. Pickup proximity uses the original server position.
    local anchor = Instance.new("Attachment")
    anchor.Name = "LuckyRewardLabelAnchor"
    anchor.CFrame = CFrame.new(pickup.Position)
    anchor.Parent = workspace.Terrain
    pickup.LabelAnchor = anchor
    local gui = Instance.new("BillboardGui")
    gui.Name = "LuckyRewardLabel"
    gui.Adornee = anchor
    gui.StudsOffsetWorldSpace = Vector3.new(0, Presentation.HeightOffset + 2, 0)
    BillboardStyle.ApplyBillboard(
        gui,
        { WidthStuds = 5, HeightStuds = 1, MaxDistance = Config.Pickup.LabelMaxDistance }
    )
    local label = Instance.new("TextLabel")
    BillboardStyle.ApplyText(label, { TextScaled = true })
    label.Text = Presentation.Rewards[pickup.RewardId].Name
    label.Parent = gui
    gui.Parent = anchor
    model:SetAttribute("VisualPartCount", partCount)
    model:SetAttribute("PickupState", "Available")
end

local function prepareReward(player: Player, rewardId: string): (() -> boolean)?
    for _, reward in Config.Rewards do
        if reward.Id == rewardId and reward.DurationSeconds then
            return function(): boolean
                buffs[player] = buffs[player] or {}
                buffs[player][rewardId] = workspace:GetServerTimeNow() + (reward.DurationSeconds :: number)
                player:SetAttribute("LuckyBuff" .. rewardId .. "ExpiresAt", buffs[player][rewardId])
                return true
            end
        end
    end
    local tier = deps.TycoonService.GetJumpTier(player)
    local pool: { string } = {}
    -- TODO(LuckyMysteryAnnouncedOnly): catalog has no announced-only flag/set.
    -- Authored announced spawn tags describe markers, not ingredient eligibility.
    for id, definition in Ingredients do
        local eligible = if rewardId == "PantryPack"
            then definition.JumpLocation >= 0 and definition.JumpLocation <= tier
            elseif rewardId == "TopShelf" then definition.JumpLocation == tier
            else id ~= "Player_Head" and id ~= "PlayerHead" and id ~= "Dragon_Fruit"
        if eligible then
            table.insert(pool, id)
        end
    end
    if #pool == 0 then
        return nil
    end
    table.sort(pool)
    local ids = {}
    for _ = 1, if rewardId == "PantryPack" then 3 else 1 do
        table.insert(ids, pool[math.random(1, #pool)])
    end
    return deps.InventoryService.PrepareIngredientReward(player, ids)
end

function Service.TryClaimPickup(player: Player, model: Model): boolean
    local id = model:GetAttribute("PickupId")
    local pickup = if typeof(id) == "number" then pickups[id] else nil
    local now = workspace:GetServerTimeNow()
    if
        not pickup
        or pickup.Model ~= model
        or player.Parent ~= Players
        or now >= pickup.ExpiresAt
        or not model:IsDescendantOf(folder)
        or (pickupClaim[player] and now - pickupClaim[player] < Config.Pickup.PlayerCooldownSeconds)
        or not WorldUtil.NearPosition(player, pickup.Position, Config.Pickup.Radius)
    then
        return false
    end
    local award = prepareReward(player, pickup.RewardId)
    if not award then
        return false
    end
    -- No yields: prepared inventory transaction rolls back the whole batch on failure.
    pickups[pickup.PickupId] = nil
    model:SetAttribute("PickupState", "Claimed")
    clearPickupAppearance(pickup)
    if not award() then
        pickups[pickup.PickupId] = pickup
        spawnPickup(pickup)
        return false
    end
    pickupClaim[player] = now
    if not buffs[player] or not buffs[player][pickup.RewardId] then
        player:SetAttribute("LuckyInstant" .. pickup.RewardId .. "Until", now + Presentation.InstantMessageSeconds)
    end
    -- Keep only replicated terminal identity until original expiry. A client that
    -- receives the claim before the art can still dispose its local reveal.
    task.delay(math.max(0, pickup.ExpiresAt - workspace:GetServerTimeNow()), function()
        model:Destroy()
    end)
    return true
end

local function markerLevel(marker: BasePart): string?
    local attribute = marker:GetAttribute("Level")
    if attribute ~= nil then
        local name = if typeof(attribute) == "number" then "Level" .. tostring(attribute) else attribute
        if typeof(name) == "string" and table.find(Config.Spawn.Levels, name) then
            return name
        end
        if not markerWarnings[marker] then
            warn("[LuckyBlock] Invalid Level attribute on " .. marker:GetFullName() .. "; use 0–3 or Level0–Level3")
            markerWarnings[marker] = true
        end
        return nil
    end
    local ancestor = marker.Parent
    while ancestor and ancestor ~= workspace do
        if table.find(Config.Spawn.Levels, ancestor.Name) then
            local parent = ancestor.Parent
            if
                (ancestor:IsA("Folder") or ancestor:IsA("Model"))
                and parent
                and parent.Name == Config.Spawn.ContainerName
                and (parent:IsA("Folder") or parent:IsA("Model"))
            then
                return ancestor.Name
            end
            return nil
        end
        ancestor = ancestor.Parent
    end
    if not markerWarnings[marker] then
        warn(
            "[LuckyBlock] Unassigned marker "
                .. marker:GetFullName()
                .. "; defaulting to Level0. Set Level or group under "
                .. Config.Spawn.ContainerName
        )
        markerWarnings[marker] = true
    end
    return "Level0"
end

populate = function(slot: Slot): boolean
    if slot.Model then
        return true
    end
    local available: { BasePart } = {}
    local occupied: { [BasePart]: boolean } = {}
    for _, record in records do
        occupied[record.Marker] = true
    end
    local validCount = 0
    for marker in markers do
        if marker:IsDescendantOf(workspace) and markerLevel(marker) == slot.Level then
            validCount += 1
            if not occupied[marker] then
                table.insert(available, marker)
            end
        end
    end
    if validCount < (Config.Spawn.SlotsPerLevel :: { [string]: number })[slot.Level] then
        if not levelWarnings[slot.Level] then
            warn(
                "[LuckyBlock] "
                    .. slot.Level
                    .. " has "
                    .. validCount
                    .. " valid markers; needs "
                    .. (Config.Spawn.SlotsPerLevel :: { [string]: number })[slot.Level]
                    .. "; retrying empty slots"
            )
            levelWarnings[slot.Level] = true
        end
    else
        levelWarnings[slot.Level] = nil
    end
    if #available == 0 then
        return false
    end
    if #available > 1 then
        local previousMarker = slot.Previous
        local previous = if previousMarker then table.find(available, previousMarker) else nil
        if previous then
            table.remove(available, previous)
        end
    end
    return spawnAt(available[math.random(1, #available)], slot)
end

schedule = function(slot: Slot, seconds: number)
    if slot.Waiting or slot.Model then
        return
    end
    slot.Waiting = true
    task.delay(seconds, function()
        slot.Waiting = false
        if not populate(slot) then
            schedule(slot, Config.Spawn.RetrySeconds)
        end
    end)
end

local function tick()
    for id, pickup in pickups do
        if workspace:GetServerTimeNow() >= pickup.ExpiresAt then
            pickups[id] = nil
            clearPickupAppearance(pickup)
            if pickup.Model then
                pickup.Model:SetAttribute("PickupState", "Expired")
                pickup.Model:Destroy()
            end
        elseif pickup.Model then
            for _, player in Players:GetPlayers() do
                -- A failed award can leave recovery waiting for repaired art.
                local model = pickup.Model
                if not model then
                    break
                end
                if Service.TryClaimPickup(player, model) then
                    break
                end
            end
        end
    end
    for model in records do
        for _, player in Players:GetPlayers() do
            if Service.TryClaim(player, model) then
                break
            end
        end
    end
    task.delay(Config.Pickup.PollSeconds, tick)
end

function Service.RemovePlayer(player: Player)
    lastClaim[player] = nil
    pickupClaim[player] = nil
    buffs[player] = nil
    for _, reward in Config.Rewards do
        player:SetAttribute("LuckyBuff" .. reward.Id .. "ExpiresAt", nil)
        player:SetAttribute("LuckyInstant" .. reward.Id .. "Until", nil)
    end
end

function Service.Init(services: any)
    if started then
        return
    end
    started = true
    deps = services
    local existing = workspace:FindFirstChild(Config.WorldFolderName)
    assert(not existing or existing:IsA("Folder"), "LuckyBlocks must be a Folder")
    folder = if existing then existing :: Folder else Instance.new("Folder")
    folder.Name = Config.WorldFolderName
    folder.Parent = workspace
    local event = Shared.Events:FindFirstChild(Config.RewardEventName)
    assert(not event or event:IsA("RemoteEvent"), "LuckyBlockPickedUp must be a RemoteEvent")
    remote = if event then event :: RemoteEvent else Instance.new("RemoteEvent")
    remote.Name = Config.RewardEventName
    remote.Parent = Shared.Events
    local nearby = Shared.Events:FindFirstChild(Presentation.NearbyEventName)
    assert(not nearby or nearby:IsA("RemoteEvent"), "LuckyBlockRevealed must be a RemoteEvent")
    nearbyRemote = if nearby then nearby :: RemoteEvent else Instance.new("RemoteEvent")
    nearbyRemote.Name = Presentation.NearbyEventName
    nearbyRemote.Parent = Shared.Events
    -- Output only: there is deliberately no OnServerEvent pickup endpoint.
    WorldUtil.BindTag(Config.MarkerTag, function(object: Instance): (() -> ())?
        if not object:IsA("BasePart") then
            warn("[LuckyBlock] Tag a BasePart spawn marker")
            return nil
        end
        markers[object] = true
        return function()
            markers[object] = nil
            markerWarnings[object] = nil
            for model, record in records do
                if record.Marker == object then
                    retire(model)
                end
            end
        end
    end)
    for _, level in Config.Spawn.Levels do
        for _ = 1, (Config.Spawn.SlotsPerLevel :: { [string]: number })[level] do
            local slot: Slot = { Level = level, Model = nil, Previous = nil, Waiting = false }
            table.insert(slots, slot)
            if not populate(slot) then
                schedule(slot, Config.Spawn.RetrySeconds)
            end
        end
    end
    tick()
end

return Service
