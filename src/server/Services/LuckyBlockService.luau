--!strict
-- Instant world rewards are not inventory items. Only this service owns these clones.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Constants.LuckyBlockConfig)
local Presentation = require(Shared.Constants.LuckyBlockPresentation)
local WorldUtil = require(script.Parent.WorldUtil)
local Service = {}
type Slot = { Level: string, Model: Model?, Previous: BasePart?, Waiting: boolean }
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
    schedule(
        record.Slot,
        Config.Respawn.MinRespawnSeconds
            + math.random() * (Config.Respawn.MaxRespawnSeconds - Config.Respawn.MinRespawnSeconds)
    )
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
        DurationSeconds = selected.DurationSeconds, -- Metadata only; no buff clock starts in Pass 1.
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
    model:SetAttribute("Level", slot.Level)
    records[model] = { Marker = marker, Origin = origin, Connections = {}, Slot = slot }
    slot.Model = model
    slot.Previous = marker
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

local function populate(slot: Slot): boolean
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
    if validCount == 0 then
        if not levelWarnings[slot.Level] then
            warn("[LuckyBlock] " .. slot.Level .. " has no valid LuckyBlockSpawn markers; retrying until configured")
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
end

function Service.Init()
    if started then
        return
    end
    started = true
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
        for _ = 1, Config.Spawn.MaxActivePerLevel do
            local slot: Slot = { Level = level, Model = nil, Previous = nil, Waiting = false }
            if not populate(slot) then
                schedule(slot, Config.Spawn.RetrySeconds)
            end
        end
    end
    Players.PlayerRemoving:Connect(Service.RemovePlayer)
    tick()
end

return Service
